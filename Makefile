.PHONY: clean data lint requirements sync_data_to_s3 sync_data_from_s3 environment

#################################################################################
# GLOBALS                                                                       #
#################################################################################
PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_ENV = $(PROJECT_DIR)/.venv
PYTHON_INTERPRETER = python3
POST_MERGE_HOOK_PATH = $$PWD/.git/hooks/post-merge

#################################################################################
# COMMANDS                                                                      #
#################################################################################
## Set up conda environment and install dependencies
environment: install_conda install_poetry add_post_merge_hook
	@echo ">>> Creating conda environment."
	@conda create --yes --prefix $(PROJECT_ENV) python=3
	@echo ">>> Conda env activated."
	@source $$(conda info --base)/bin/activate; conda activate $(PROJECT_ENV); source $$HOME/.poetry/env; poetry install --no-root      
	@echo ">>> Created conda environment and installed its dependencies."

## Make Dataset
data: requirements
	$(PYTHON_INTERPRETER) src/data/make_dataset.py data/raw data/processed

## Delete all compiled Python files
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete

## Lint using flake8
lint:
	flake8 src

## Upload Data to S3
sync_data_to_s3:
ifeq (default,$(PROFILE))
	aws s3 sync data/ s3://$(BUCKET)/data/
else
	aws s3 sync data/ s3://$(BUCKET)/data/ --profile $(PROFILE)
endif

## Download Data from S3
sync_data_from_s3:
ifeq (default,$(PROFILE))
	aws s3 sync s3://$(BUCKET)/data/ data/
else
	aws s3 sync s3://$(BUCKET)/data/ data/ --profile $(PROFILE)
endif

## Test python environment is setup correctly
test_environment:
	$(PYTHON_INTERPRETER) test_environment.py

#################################################################################
# HELPER COMMANDS                                                               #
#################################################################################
### make environment
## Download and install Miniconda
install_conda:
ifeq (False,$(HAS_CONDA))
	@echo ">>> Did not detect conda. Downloading and installing Miniconda."
	@wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
	@chmod +x Miniconda3-latest-Linux-x86_64.sh
	@./Miniconda3-latest-Linux-x86_64.sh
else
	@echo ">>> Conda detected."
endif

## Install Poetry in $HOME dir 
ifeq (,$(wildcard $$HOME/.poetry))
HAS_POETRY=True
else
HAS_POETRY=False
endif
install_poetry:
ifeq (False, $(HAS_POETRY))
	@curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python
else	
	@echo ">>> Poetry detected."
endif

## Post merge depdency update using poetry
add_post_merge_hook:
	@if [ ! -f $(POST_MERGE_HOOK_PATH) ]; then echo "#!/bin/sh\n" > $(POST_MERGE_HOOK_PATH); fi
	@if ! grep -q "poetry install" $(POST_MERGE_HOOK_PATH); \
	then echo "poetry install --no-root" >> $(POST_MERGE_HOOK_PATH); fi
	@echo ">>> Added poetry install to post-merge git hook."

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')