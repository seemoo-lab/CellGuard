import argparse
import json
import tempfile
import zipfile
from dataclasses import dataclass
from datetime import datetime, time, timedelta
from pathlib import Path

import pandas as pd
from matplotlib import pyplot as plt
from matplotlib.dates import DateFormatter


def extract_cells2(cells2_file: Path, destination: Path):
    with zipfile.ZipFile(cells2_file, 'r') as zip_ref:
        zip_ref.extractall(destination)


@dataclass(eq=True, frozen=True)
class DeviceJSON:
    system_name: str
    model: str
    localized_model: str
    name: str
    identifier_for_vendor: str
    system_version: str
    cellguard_version: str
    data: dict[str, int]

    def simple_string(self):
        return f'{self.name} ({self.model} on {self.system_name} {self.system_version})'

    @staticmethod
    def from_json(data: dict):
        return DeviceJSON(
            system_name=data.get('systemName'),
            model=data.get('model'),
            localized_model=data.get('localizedModel'),
            name=data.get('name'),
            identifier_for_vendor=data.get('identifierForVendor'),
            system_version=data.get('systemVersion'),
            cellguard_version=data.get('cellguardVersion', '< 1.3.0'),
            data=data.get('data')
        )


def load_info(extracted_cells2: Path) -> DeviceJSON:
    with extracted_cells2.joinpath('info.json').open('r') as read_file:
        return DeviceJSON.from_json(json.load(read_file))


def process_info(dirs: list[Path]):
    info_series = pd.Series([load_info(d).simple_string() for d in dirs])
    device_count: pd.Series = info_series.to_frame(name='device').groupby(['device'])['device'].count()

    print('Dataset(s) from:')
    for device, count in device_count.items():
        print(f'  {count}x {device}')
    print()


def process_als_cells(dirs: list[Path]) -> int:
    dfs = [pd.read_csv(d.joinpath('als-cells.csv')) for d in dirs]
    df = pd.concat(dfs)
    df.drop_duplicates(subset=['technology', 'country', 'network', 'area', 'cell'], inplace=True)

    als_cell_count = len(df.index)

    print('ALS Cell Cache:')
    print(f'  Count: {als_cell_count}')
    print()

    return als_cell_count


def process_locations(dirs: list[Path]) -> int:
    dfs = [pd.read_csv(d.joinpath('locations.csv')) for d in dirs]
    df = pd.concat(dfs)

    location_count = len(df.index)

    print('Locations:')
    print(f'  Count: {location_count}')
    print(f'  Start: {datetime.fromtimestamp(df["collected"].min())}')
    print(f'  End: {datetime.fromtimestamp(df["collected"].max())}')
    print()

    return location_count


def process_packets(dirs: list[Path]):
    dfs = [pd.read_csv(d.joinpath('packets.csv'), usecols=['collected', 'direction', 'proto']) for d in dirs]
    df = pd.concat(dfs)

    packet_count = len(df.index)

    proto_series: pd.Series = df.groupby(['proto'])['proto'].count()
    proto_string = ', '.join([f'{proto} ({count})' for proto, count in proto_series.items()])

    print('Packets:')
    print(f'  Proto: {proto_string}')
    print(f'  Count: {packet_count}')
    print(f'  Start: {datetime.fromtimestamp(df["collected"].min())}')
    print(f'  End: {datetime.fromtimestamp(df["collected"].max())}')
    print()

    return packet_count


def load_user_cells(dirs: list[Path]) -> pd.DataFrame:
    # https://stackoverflow.com/a/63002444/4106848
    columns = ['collected', 'status', 'score', 'technology', 'country', 'network', 'area', 'cell']
    dfs = [pd.read_csv(d.joinpath('user-cells.csv'), usecols=lambda x: x in columns) for d in dirs]
    df = pd.concat(dfs)

    # Only consider cells whose verification is complete
    return df[df['status'] == 'verified']


def cell_score_category(score: int) -> str:
    if score < 50:
        return 'Untrusted'
    elif score < 95:
        return 'Suspicious'
    else:
        return 'Trusted'


def process_user_cells(df: pd.DataFrame) -> tuple[int, int, int, int]:
    cell_count = len(df.index)
    score_series = df['score'].apply(cell_score_category)
    category_count: dict[str, int] = score_series.groupby(score_series).count().to_dict()

    print('User Cells:')
    print(f'  Start: {datetime.fromtimestamp(df["collected"].min())}')
    print(f'  End: {datetime.fromtimestamp(df["collected"].max())}')
    print(f'  Measurements:')
    print(f'    Untrusted: {category_count.get("Untrusted", 0)}')
    print(f'    Suspicious: {category_count.get("Suspicious", 0)}')
    print(f'    Trusted: {category_count.get("Trusted", 0)}')
    print(f'    = Sum: {cell_count}')

    print(f'  Unique Cells:')
    if 'technology' in df:
        unique_df = df.groupby(['technology', 'country', 'network', 'area', 'cell']).min()
        unique_cell_count = len(unique_df.index)

        unique_score_series = unique_df['score'].apply(cell_score_category)
        unique_category_count: dict[str, int] = unique_score_series.groupby(unique_score_series).count().to_dict()

        unique_untrusted = unique_category_count.get("Untrusted", 0)
        unique_suspicious = unique_category_count.get("Suspicious", 0)
        unique_trusted = unique_category_count.get("Trusted", 0)

        print(f'    Untrusted: {unique_category_count.get("Untrusted", 0)}')
        print(f'    Suspicious: {unique_category_count.get("Suspicious", 0)}')
        print(f'    Trusted: {unique_category_count.get("Trusted", 0)}')
        print(f'    = Sum: {unique_cell_count}')
    else:
        print(f'    Missing data, please re-export datasets with CellGuard >= 1.3.4')
        unique_untrusted = 0
        unique_suspicious = 0
        unique_trusted = 0

    print()

    return cell_count, unique_untrusted, unique_suspicious, unique_trusted


# https://stackoverflow.com/a/1060330/4106848
def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + timedelta(n)


def process_time(df: pd.DataFrame, graph: bool) -> tuple[int, int]:
    df['day'] = df['collected'].apply(lambda x: datetime.combine(datetime.fromtimestamp(x), time.min).timestamp())

    start = datetime.fromtimestamp(df['day'].min())
    end = datetime.fromtimestamp(df['day'].max())

    days_total = (end - start).days + 1

    # Think about timezones
    df['day'] = df['collected'].apply(lambda x: datetime.combine(datetime.fromtimestamp(x), time.min))
    day_series: pd.Series = df.groupby(['day'])['day'].count()
    days_active = len(day_series.drop_duplicates().index)

    print('Time:')
    print(f'  Days Active: {days_active}')
    print(f'  Days Total: {days_total}')
    print()

    if graph:
        # https://pandas.pydata.org/pandas-docs/version/0.13.1/visualization.html
        # https://stackoverflow.com/a/64920221/4106848

        # Add missing day with zero cells to the graph
        for date in daterange(start, end):
            if date not in day_series.index:
                day_series[date] = 0

        fig, ax = plt.subplots()
        ax.set_ylabel("Cell Measurements")

        ax.xaxis.set_major_formatter(DateFormatter("%d-%m-%Y"))
        ax.bar(day_series.index, day_series)

        plt.xticks(day_series.index, rotation=90)
        plt.tight_layout()
        plt.show()

    return days_active, days_total


def process_latex(
        days_active: int, days_total: int,
        untrusted_cells: int, suspicious_cells: int, trusted_cells: int,
        cell_measurements: int, packets: int, locations: int
):
    def n(value: int):
        return f'\\num{{{value}}}'

    print('LaTeX Table Row:')
    print(
        f'  '
        f'number & model & baseband & {n(days_active)} & {n(days_total)} & '
        f'{n(untrusted_cells)} & {n(suspicious_cells)} & {n(trusted_cells)} & '
        f'{n(cell_measurements)} & {n(packets)} & {n(locations)} \\\\'
    )
    print()


def main():
    parser = argparse.ArgumentParser(
        prog='analyze_cells2.py',
        description='Analyzes .cells2 files exported from CellGuard'
    )
    parser.add_argument('path', type=Path)
    parser.add_argument('-t', '--latex-table', action='store_true')
    parser.add_argument('-g', '--graph', action='store_true')

    args = parser.parse_args()
    path: Path = args.path
    latex_table: bool = args.latex_table
    graph: bool = args.graph

    cells2_files = []
    if path.is_dir():
        print(f'Processing all cells2 files in the directory {path}:')
        cells2_files = list(path.glob('*.cells2'))
        for file in cells2_files:
            print(f'  {file.name}')
    else:
        if path.suffix != '.cells2':
            print(f'The file my have the .cells2 extensions')
            return
        print(f'Processing the cells2 file {path}')
        cells2_files = [path]
    print()

    tmp_dir = tempfile.TemporaryDirectory()
    tmp_dir_path = Path(tmp_dir.name)
    print(f'Created temporary directory at {tmp_dir.name}')
    print()

    # Extracting the files
    tmp_name_dirs: dict[str, Path] = {}
    for file in cells2_files:
        destination = tmp_dir_path.joinpath(file.stem)
        extract_cells2(file, destination)
        tmp_name_dirs[file.name] = destination

    tmp_dirs = list(tmp_name_dirs.values())

    process_info(tmp_dirs)
    location_count = process_locations(tmp_dirs)
    packet_count = process_packets(tmp_dirs)
    process_als_cells(tmp_dirs)

    user_cells_df = load_user_cells(tmp_dirs)
    cell_measurements, unique_untrusted, unique_suspicious, unique_trusted = process_user_cells(user_cells_df)
    days_active, days_total = process_time(user_cells_df, graph)
    if latex_table:
        process_latex(
            days_active, days_total,
            unique_untrusted, unique_suspicious, unique_trusted,
            cell_measurements, packet_count, location_count
        )

    # Deleting the temporary directory
    tmp_dir.cleanup()


if __name__ == '__main__':
    main()
