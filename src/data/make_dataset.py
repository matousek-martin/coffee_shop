import os
import scrapy
import requests
from abc import ABCMeta
from typing import List, NoReturn
from pathlib import Path
from tinydb import TinyDB
from utils import get_project_root
from scrapy.crawler import CrawlerProcess
from scrapy.exceptions import CloseSpider


class StoryousSpider(scrapy.Spider, metaclass=ABCMeta):
    # custom_settings = {
    #     'DOWNLOAD_DELAY': 0.25,
    #     'CONCURRENT_REQUESTS': 2
    # }

    def __init__(self):
        super(StoryousSpider, self).__init__()
        # API Docs: https://apistoryouscom.docs.apiary.io
        self._source_id = f"{os.environ['MERCHANT_ID']}-{os.environ['PLACE_ID']}"
        self._authorization = {'Authorization': f'Bearer {self.__get_token()}'}

    def errback(self, response):
        if response.value.response.status == 401:
            raise CloseSpider('Session  limit reached')

    @staticmethod
    def _get_database(path: str) -> TinyDB:
        db_path = get_project_root() / Path(path)
        db = TinyDB(db_path)
        return db

    @staticmethod
    def __get_token() -> str:
        # Retrieve API token to authenticate get requests for bills and their details
        url = 'https://login.storyous.com/api/auth/authorize'
        header = {'Content-Type': 'application/x-www-form-urlencoded'}
        data = {
            'client_id': os.environ['CLIENT_ID'],
            'client_secret': os.environ['SECRET'],
            'grant_type': 'client_credentials'
        }
        response = requests.post(url=url, data=data, headers=header)
        token = response.json()['access_token']
        return token


class BillsSpider(StoryousSpider):
    name = 'bills_spider'

    def __init__(self):
        super(BillsSpider, self).__init__()
        self._database = self._get_database('data/raw/bills.json')
        self._scraped_ids = [bill['billId'] for bill in self._database.all()]

    def start_requests(self):
        url = f"https://api.storyous.com/bills/{self._source_id}"
        yield scrapy.Request(
            url=url,
            headers=self._authorization,
            callback=self.parse,
            errback=self.errback
        )

    def parse(self, response):
        # Add bills to database
        bills = response.json()
        self._database.insert_multiple(bills['data'])

        # Stop when we encounter an already scraped bill id
        last_bill_id = bills['data'][-1]['billId']
        stop_spider = last_bill_id in self._scraped_ids
        if 'nextPage' in bills and stop_spider is False:
            next_page = bills['nextPage'][1:]
            yield response.follow(
                url=next_page,
                headers=self._authorization,
                callback=self.parse,
                errback=self.errback
            )


class BillDetailsSpider(StoryousSpider):
    name = 'bill_details'

    def __init__(self):
        super(BillDetailsSpider, self).__init__()
        self._database = self._get_database('data/raw/bill_details.json')

    def start_requests(self) -> scrapy.Request:
        urls = self.__get_urls()
        for url in urls:
            yield scrapy.Request(
                url=url,
                headers=self._authorization,
                callback=self.parse,
                errback=self.errback
            )

    def parse(self, response) -> NoReturn:
        # Save raw data to TinyDB
        bill_detail = response.json()
        self._database.insert(bill_detail)

    def __get_urls(self) -> List:
        # Load bills databases
        bills_db = self._get_database('data/raw/bills.json')

        # All bill ids in either database
        available_bill_ids = [bill['billId'] for bill in bills_db]
        scraped_bill_ids = [bill['billId'] for bill in self._database]

        # Construct URLs for bill ids that have not yet been scraped
        urls = [
            f"https://api.storyous.com/bills/{self._source_id}/{bill_id}"
            for bill_id in available_bill_ids
            if bill_id not in scraped_bill_ids
        ]
        # Invert to scrape the newest bills
        return urls[::-1]


if __name__ == '__main__':
    process = CrawlerProcess()
    # process.crawl(BillsSpider)
    process.crawl(BillDetailsSpider)
    process.start()
