import dataclasses
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import requests
from bs4 import BeautifulSoup, Tag


@dataclass
class Operator:
    mcc: int
    mnc: int
    country_iso: str
    country_name: str
    country_code: Optional[str]
    network_name: str


def request_html() -> str:
    print('Fetching operators from mcc-mnc.com...')
    r = requests.get('https://mcc-mnc.com')
    if not r.ok:
        print(f'Request to https://mcc-mnc.com failed with status code {r.status_code}:\n{r.text}')
        exit(1)
    return r.text


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
    html = request_html()
    operators = parse_html(html)
    path = write_to_json(operators)
    print(f'Wrote {len(operators)} operators to {path}')


if __name__ == '__main__':
    main()
