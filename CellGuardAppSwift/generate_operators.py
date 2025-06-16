from enum import Enum
from os import path
from typing import Optional
from urllib.parse import urlparse

import pandas as pd


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
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_2xx_(Europe)',
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_3xx_(North_America)',
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_4xx_(Asia)',
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_5xx_(Oceania)',
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_6xx_(Africa)',
    'https://en.wikipedia.org/wiki/Mobile_Network_Codes_in_ITU_region_7xx_(South_America)'
]


def fetch_countries() -> tuple[pd.DataFrame, pd.DataFrame]:
    print('Fetching countries and global operators from Wikipedia...')
    p = urlparse(WIKI_URL).path

    # Extract all operator tables from the webpage
    # https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_csv.html
    operators = pd.read_html(WIKI_URL, attrs={'class': 'wikitable'}, extract_links='body')
    operators_df = pd.concat([strip_operator_table(p, op) for op in operators])

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
        # We only allow Wikipedia URLs that start with /
        if t[1].startswith('/'):
            return replace_nbsp(t[0]), t[1]
        # Or Wikipedia URLs that link to the page itself
        elif t[1].startswith('#'):
            return replace_nbsp(t[0]), p + t[1]

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

    df = df.drop(columns=['National MNC authority', 'Remarks'])
    df = df.rename(columns={
        'Mobile country code': 'mcc',
        'Country': 'name',
        'ISO 3166': 'iso',
        'Mobile network codes': 'mnc_urls',
    })
    df['mcc'] = df['mcc'].map(lambda x: x[0])
    df['name'] = df['name'].map(lambda x: filter_index_char(x[0]))
    df['iso'] = df['iso'].map(lambda x: x[0])
    df['mnc_urls'] = df['mnc_urls'].map(lambda x: filter_urls(p, x)[1])

    return df


def fetch_regions(url: str) -> pd.DataFrame:
    p = urlparse(url).path
    region = url.split('_')[-1].strip('()')
    print(f'Fetching operators for region {region} from Wikipedia...')

    operators = pd.read_html(url, attrs={'class': 'wikitable'}, extract_links='body')
    return pd.concat([strip_operator_table(p, op) for op in operators])


def filter_mcc_names(mcc: str) -> str:
    if len(mcc) == 3:
        return mcc

    return mcc.split(' ')[-1]


def map_operator_status(status_tuple: Optional[tuple[str, str]]) -> OperatorStatus:
    if status_tuple is None:
        return OperatorStatus.UNKNOWN

    return OperatorStatus.from_string(status_tuple[0])


def strip_operator_table(p: str, df: pd.DataFrame) -> pd.DataFrame:
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
        regional_operators = fetch_regions(region_url)
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
