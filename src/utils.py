from pathlib import Path


def get_project_root() -> Path:
    # https://stackoverflow.com/questions/25389095/python-get-path-of-root-project-structure
    return Path(__file__).parent.parent
