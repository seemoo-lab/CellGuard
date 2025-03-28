import dataclasses
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import pandas as pd
import requests
from bs4 import BeautifulSoup, Tag


# Country and territories: Mobile country code	Country	ISO 3166	Mobile network codes	National MNC authority	Remarks
# Operator: MCC	MNC	Brand	Operator	Status	Bands (MHz)	References and notes

@dataclass
class Country:
    mnc: str
    name: str
    iso: str
    operators_ref: str
    authority: str
    remarks: str

@dataclass
class Operator:
    mcc: str
    mnc: str
    brand: str
    company: str
    bands: str
    remarks: str

WIKI_URL = 'https://en.wikipedia.org/wiki/Mobile_country_code'
WIKI_URL_REGIONS = [
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_2xx_(Europe)',
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_3xx_(North_America)',
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_4xx_(Asia)',
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_5xx_(Oceania)',
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_6xx_(Africa)',
  'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_7xx_(South_America)'
]

def fetch_countries() -> tuple[list[Country], list[Operator]]:
    print('Fetching countries from Wikipedia...')

    # r = requests.get(WIKI_URL)
    # if not r.ok:
    #     print(f'Request to Wikipedia failed with status code {r.status_code}:\n{r.text}')
    #     exit(1)

    # soup = BeautifulSoup(r.text, 'html.parser')
    # tables = soup.find_all('table', attrs={'class': 'wikitable'})
    #
    # table_test_operators = tables[0]
    # table_countries_territories = tables[1]
    # table_international_operators = tables[2]
    # table_io_operators = tables[3]
    #
    # parse_countries(table_countries_territories)

    # https://stackoverflow.com/a/55010551

    # Extract all tables from the wikipage
    dfs = pd.read_html(WIKI_URL, attrs={'class': 'wikitable'})
    print(dfs)
    # The table referenced above is the 7th on the wikipage
    # df = dfs[6]
    # The last row is just the date of the last update
    # df = df.iloc[:-1]

    # TODO: Clean DFs
    # TODO: Merge DFs
    # Output two CSVs (one for countries, one for operators)

    return [], []

def fetch_regions(url: str) -> list[Operator]:
    region = url.split('_')[-1].strip('()')
    print(f'Fetching operators for region {region} from Wikipedia...')

    dfs = pd.read_html(WIKI_URL, attrs={'class': 'wikitable'})
    print(dfs)

    r = requests.get(url)
    if not r.ok:
        print(f'Request to Wikipedia failed with status code {r.status_code}:\n{r.text}')
        exit(1)

    return []

def parse_operators(df: pd.DataFrame) -> list[Operator]:


    return []

def parse_countries(df: pd.DataFrame) -> list[Country]:
    # Verify that we found the correct table
    headers = table.find_all('th')
    headers_text = [h.text.strip('\n') for h in headers]
    assert len(headers) == 6
    assert headers_text[0] == 'Mobile country code'
    assert headers_text[1] == 'Country'
    assert headers_text[2] == 'ISO 3166'
    assert headers_text[3] == 'Mobile network codes'
    assert headers_text[4] == 'National MNC authority'
    assert headers_text[5] == 'Remarks'

    # Skip the first header row
    rows = table.find_all('tr')[1:]
    countries = []
    for row in rows:
        columns = row.find_all('td')
        countries.append(Country(
            mnc=columns[0].string,
            name=columns[1].string,
            iso=columns[2].string,
            operators_ref=columns[3].string,
            authority=columns[4].string,
            remarks=columns[5].string,
        ))

    print(countries)

    return countries

def strip_or_none(text: Optional[str]):
    return text.strip() if text else text


def parse_html(html: str) -> list[Operator]:
    soup = BeautifulSoup(html, 'html.parser')
    operators = []
    for row in soup.find_all('tr'):
        row: Tag
        data: list[Tag] = row.find_all('td')

        if len(data) < 6:
            row_html_single_line = str(row).replace('\n', '')
            print(f'Skipping the row: {row_html_single_line}')
            continue

        operators.append(Operator(
            mcc=int(data[0].string),
            mnc=int(data[1].string),
            country_iso=strip_or_none(data[2].string),
            country_name=strip_or_none(data[3].string),
            country_code=int(data[4].string) if data[4].string else None,
            network_name=strip_or_none(data[5].string),
        ))
    return operators


def write_to_json(operators: list[Operator]) -> Path:
    path = Path('CellGuard', 'Cells', 'operator-definitions.json')
    with open(path, 'w') as file:
        json.dump([dataclasses.asdict(o) for o in operators], file)
    return path


def main():
    fetch_countries()
    # operators = parse_html(html)
    # path = write_to_json(operators)
    # print(f'Wrote {len(operators)} operators to {path}')


if __name__ == '__main__':
    main()
