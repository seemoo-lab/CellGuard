import urllib
from dataclasses import dataclass
from enum import Enum
from os import path
from typing import Optional
from urllib.parse import urlparse

import pandas as pd
import requests
from bs4 import BeautifulSoup


class OperatorStatus(Enum):
    NOT_OPERATIONAL = -1
    UNKNOWN = 0
    OPERATIONAL = 1

    @staticmethod
    def from_string(status: str):
        if status == 'Not operational' or status == 'Not Operational':
            return OperatorStatus.NOT_OPERATIONAL
        elif status == 'Reserved':
            return OperatorStatus.NOT_OPERATIONAL
        elif status in ['Operational', 'operational', 'Ongoing', 'Implement / Design', 'Operational[citation needed]',
                        'Upcoming', 'Test Network', 'Allocated', 'Testing', 'Building Network', 'Planned',
                        'Temporary operational']:
            return OperatorStatus.OPERATIONAL
        elif status == 'Unknown' or status == 'UNKNOWN':
            return OperatorStatus.UNKNOWN
        else:
            print(f'Unexpected status string: {status}')
            return OperatorStatus.UNKNOWN


WIKI_URL = 'https://en.wikipedia.org/wiki/Mobile_country_code'
WIKI_URL_REGIONS = [
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_2xx_(Europe)',
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_3xx_(North_America)',
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_4xx_(Asia)',
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_5xx_(Oceania)',
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_6xx_(Africa)',
    'https://en.wikipedia.org/wiki/Mobile_network_codes_in_ITU_region_7xx_(South_America)'
]


def fetch_countries() -> tuple[pd.DataFrame, pd.DataFrame]:
    print('Fetching countries and global operators from Wikipedia...')
    p = urlparse(WIKI_URL).path

    # Extract all operator tables from the webpage
    # https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_csv.html
    operators = pd.read_html(WIKI_URL, attrs={'class': 'wikitable'}, extract_links='body')
    # We've hard coded this data as it's challenging to parse
    operator_countries = [
        OperatorCountryInfo('Test', None, None, '/wiki/Mobile_country_code#Test_networks'),
        OperatorCountryInfo('International', None, None, '/wiki/Mobile_country_code#International_operators'),
        OperatorCountryInfo('British Indian Ocean Territory (United Kingdom)', 'IO', None, '/wiki/Mobile_country_code#British_Indian_Ocean_Territory_%28United_Kingdom%29_%E2%80%93_IO')
    ]
    assert len(operators) == len(operator_countries)
    operators_df = pd.concat([strip_operator_table(p, op, operator_countries[idx]) for idx, op in enumerate(operators)])

    # Extract the country MCC table
    countries = pd.read_html(WIKI_URL, attrs={'class': 'wikitable sortable mw-collapsible'}, extract_links='body')
    countries_df = strip_country_table(p, countries[0])

    return countries_df, operators_df


def replace_nbsp(s: str) -> str:
    return s.replace(' ', '')


def filter_urls(p: str, t: Optional[tuple[str, Optional[str]]]) -> Optional[tuple[str, Optional[str]]]:
    if t is None:
        return None

    if t[1] is not None:
        # We only allow Wikipedia URLs that start with '/wiki'.
        # Some links '/w/index.php?title=Citymesh_Connect&action=edit&redlink=1' point to non-existent articles.
        if t[1].startswith('/wiki'):
            return replace_nbsp(t[0]), t[1]
        # Or Wikipedia URLs that link to the page itself
        elif t[1].startswith('#'):
            # We require URL encoding, otherwise iOS 14 won't accept those URLs
            return replace_nbsp(t[0]), p + '#' + urllib.parse.quote(t[1][1:])

    return replace_nbsp(t[0]), None


def filter_index_char(name: Optional[str]) -> Optional[str]:
    if name is None:
        return None

    split = name.split(' ', maxsplit=1)
    if len(split) == 2 and len(split[0]) == 1:
        return split[1]

    return name


def strip_country_table(p: str, df: pd.DataFrame) -> pd.DataFrame:
    column_names = df.columns.values.tolist()
    assert column_names == [
        'Mobile country code', 'Country', 'ISO 3166',
        'Mobile network codes', 'National MNC authority', 'Remarks'
    ]

    df = df.drop(columns=['Mobile network codes', 'National MNC authority', 'Remarks'])
    df = df.rename(columns={
        'Mobile country code': 'mcc',
        'Country': 'name',
        'ISO 3166': 'iso',
    })
    df['mcc'] = df['mcc'].map(lambda x: x[0])
    df['name'] = df['name'].map(lambda x: filter_index_char(x[0]))
    df['iso'] = df['iso'].map(lambda x: x[0])

    return df

@dataclass
class OperatorCountryInfo:
    name: str
    # May be empty (international networks) or contain multiple ISOs separated with '/'
    iso: Optional[str]
    # If there are multiple ISOs defined, then this contains more for information about them separated with '##'
    include_info: Optional[str]
    # Links to the section of the operator on Wikipedia
    heading_url: str

def fetch_country_names(url: str) -> list[OperatorCountryInfo]:
    p = urlparse(url).path
    region = url.split('_')[-1].strip('()')
    print(f'Fetching coutry names for operators of region {region} from Wikipedia...')

    infos: list[OperatorCountryInfo] = []

    page = requests.get(url)
    soup = BeautifulSoup(page.text, 'lxml')
    headings = soup.find_all('div', attrs={'class': 'mw-heading mw-heading4'})
    for heading in headings:
        text_h4 = heading.find('h4', recursive=False)
        name, iso = text_h4.text.split(" – ")
        heading_url = p
        if text_h4.get('id') is not None:
            heading_url += '#' + urllib.parse.quote(text_h4.get('id'))
        else:
            print(f'Operator country {name} without reference id')
        include_info = None
        if '/' in iso:
            include_p = heading.next_sibling.next_sibling
            if 'includes' in include_p.text.lower():
                include_list = include_p.next_sibling.next_sibling
                include_info = include_list.text.strip().replace('\n', '##')
            else:
                print(f'Multiple ISO Codes for {name} but without include text!')

        # print(f"{name}: {iso} [{include_info}]\n -> {heading_url}")
        infos.append(OperatorCountryInfo(name, iso, include_info, heading_url))

    return infos

def fetch_region(url: str) -> pd.DataFrame:
    p = urlparse(url).path
    region = url.split('_')[-1].strip('()')
    print(f'Fetching operators for region {region} from Wikipedia...')

    country_names = fetch_country_names(url)
    operators = pd.read_html(url, attrs={'class': 'wikitable'}, extract_links='body')

    assert len(operators) == len(country_names)

    return pd.concat([strip_operator_table(p, op, country_names[idx]) for idx, op in enumerate(operators)])


def filter_mcc_names(mcc: str) -> str:
    if len(mcc) == 3:
        return mcc

    return mcc.split(' ')[-1]


def map_operator_status(status_tuple: Optional[tuple[str, str]]) -> OperatorStatus:
    if status_tuple is None:
        return OperatorStatus.UNKNOWN

    return OperatorStatus.from_string(status_tuple[0])


def strip_operator_table(p: str, df: pd.DataFrame, country_info: OperatorCountryInfo) -> pd.DataFrame:
    column_names = df.columns.values.tolist()
    assert column_names == ['MCC', 'MNC', 'Brand', 'Operator', 'Status', 'Bands (MHz)', 'References and notes']

    df = df.drop(columns=['Bands (MHz)', 'References and notes'])
    df = df.rename(columns={
        'MCC': 'mcc',
        'MNC': 'mnc',
        'Brand': 'brand',
        'Operator': 'operator',
        'Status': 'status',
    })

    df['mcc'] = df['mcc'].map(lambda x: filter_mcc_names(x[0]))
    # Sometimes 100 - 190
    df['mnc'] = df['mnc'].map(lambda x: x[0])
    df[['brand', 'brand_url']] = df.apply(lambda b: filter_urls(p, b['brand']), axis='columns', result_type='expand')
    df[['operator', 'operator_url']] = df.apply(lambda o: filter_urls(p, o['operator']), axis='columns',
                                                result_type='expand')
    df['status'] = df['status'].map(lambda x: map_operator_status(x).value)

    # Add country information to each operator
    df['country_name'] = country_info.name
    df['iso'] = country_info.iso
    df['country_include'] = country_info.include_info
    df['country_url'] = country_info.heading_url

    return df


def print_country_duplicates(countries: pd.DataFrame) -> None:
    mcc_count: pd.Series = countries['mcc'].value_counts()
    mcc_duplicates: pd.Series = mcc_count[mcc_count > 1]
    if len(mcc_duplicates) > 0:
        duplicates_str = ' '.join(mcc_duplicates.index.to_series().apply(str))
        print(f'There are duplicate entries for MCCs: {duplicates_str}')


def main():
    # Output two CSVs (one for countries, one for operators)
    countries, operators = fetch_countries()

    for region_url in WIKI_URL_REGIONS:
        regional_operators = fetch_region(region_url)
        operators = pd.concat([operators, regional_operators])

    directory = path.join(path.dirname(__file__), 'CellGuard', 'Cells')

    print_country_duplicates(countries)

    countries_path = path.join(directory, 'countries.csv')
    countries.to_csv(countries_path, index=False)
    print(f'Wrote {len(countries.index)} operators to {countries_path}')

    operators_path = path.join(directory, 'operators.csv')
    operators.to_csv(operators_path, index=False)
    print(f'Wrote {len(operators.index)} operators to {operators_path}')


if __name__ == '__main__':
    main()
