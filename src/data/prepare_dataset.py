from pathlib import Path
import pandas as pd
from tinydb import TinyDB
from utils import get_project_root


def read_tinydb(path: str) -> pd.DataFrame:
    db = TinyDB(path)
    tinydb_to_pandas = []
    for bill in db.all():
        for item in bill['items']:
            row = [
                bill['billId'], bill['sessionCreated'], bill['createdAt'], bill['paidAt'],
                bill['finalPrice'], bill['finalPriceWithoutTax'], bill['paymentMethod'],
                bill['createdBy']['userName'], item['name'], item['amount'], item['price'],
                item['vatRate'], item['productId']
            ]
            tinydb_to_pandas.append(row)

    columns = [
        'billId', 'sessionCreated', 'createdAt', 'paidAt', 'finalPrice',
        'finalPriceWithoutTax', 'paymentMethod', 'createdBy_userName',
        'items_name', 'items_amount', 'items_price', 'items_vatRate', 'items_productId'
    ]

    dataframe = pd.DataFrame(data=tinydb_to_pandas, columns=columns)
    return dataframe


if __name__ == '__main__':
    source_path = str(get_project_root() / Path('data/raw/bill_details.json'))
    target_path = str(get_project_root() / Path('data/interim/bill_details.xlsx'))
    bill_details = read_tinydb(source_path)
    bill_details.to_excel(target_path)