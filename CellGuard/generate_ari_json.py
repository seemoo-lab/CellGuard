import json
import sys
from pathlib import Path
from typing import Optional

from luaparser import ast
from luaparser.astnodes import Return, Statement, Table, Number, String, Field, Name
from yaspin import yaspin


# Sources:
# - https://github.com/seemoo-lab/aristoteles/blob/master/tools/ghidra_scripts/ari-structure-extractor.py
# - https://github.com/seemoo-lab/aristoteles/blob/master/types/structure/libari_dylib.lua

class ARIAppDefinitions:
    """
    A class used to generate the ARI definition files used by the CellGuard app
    based on the provided libari_dylib.lua file.
    """

    data_file_path: Path
    build_file_path: Path

    def __init__(self, data_file: Path, build_file: Path) -> None:
        self.data_file_path = data_file
        self.build_file_path = build_file

    @staticmethod
    def process_group(group_field: Field) -> Optional[dict]:
        if not isinstance(group_field.key, Number) or not isinstance(group_field.value, Table):
            print(f'Skipping group {group_field} as it does not have a number as key or a table as body')
            return None

        key: Number = group_field.key
        value: Table = group_field.value

        group_id = key.n
        group_name: Optional[str] = None
        types: list[dict] = []

        for type_field in value.fields:
            if isinstance(type_field.key, String) and isinstance(type_field.value, String) \
                    and type_field.key.s == 'name':
                group_name = type_field.value.s
            elif isinstance(type_field.key, Number) and isinstance(type_field.value, Table):
                type_id = type_field.key.n
                name_field = type_field.value.fields[0]
                if isinstance(name_field.key, Name) and isinstance(name_field.value, String) \
                        and name_field.key.id == 'name':
                    type_name = name_field.value.s
                    types.append({
                        'identifier': type_id,
                        'name': type_name
                    })
                else:
                    print(f'Skipping type {type_id} of group {group_id} because we couldn\'t extract the type\'s name')
            else:
                print(f'Skipping type field {type_field} of group {group_id} because its malformed')

        if not group_name:
            print(f'Couldn\'t extract name for group {group_id}')
            return None

        return {
            'identifier': group_id,
            'name': group_name,
            'types': types,
        }

    def generate(self) -> bool:
        """ Generate a JSON definition file based on the class properties and return its location. """
        with yaspin(text=f"Reading {self.data_file_path.name}..."):
            with open(self.data_file_path, "r") as data_file:
                tree = ast.parse(data_file.read())

        first_statement: Statement = tree.body.body[0]
        if not isinstance(first_statement, Return):
            print('The first statement of the lua file is not a return statement.')
            return False

        return_statement: Return = first_statement
        group_table: Table = return_statement.values[0]
        json_group_list: list[dict] = []

        for group_field in group_table.fields:
            group_data = self.process_group(group_field)
            if group_data:
                json_group_list.append(group_data)

        if not self.build_file_path.parent.exists():
            self.build_file_path.parent.mkdir()

        with open(self.build_file_path, "w") as output_file:
            json.dump(json_group_list, output_file)

        print(f'Collected {len(json_group_list)} ARI groups')

        return True


def main():
    """ The main function composing all the work. """
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: generate_ari_json.py <path/libari_dylib.lua>\n")
        sys.exit(1)

    data_file = Path(sys.argv[1])
    build_file = Path("CellGuard", "Tweaks", "Capture Packets", "ari-definitions.json")

    if not data_file.is_file() or data_file.name != 'libari_dylib.lua':
        sys.stderr.write("Specified libari_dylib.lua has the wrong name or is not a file!\n")
        sys.exit(1)

    definitions = ARIAppDefinitions(data_file, build_file)
    definitions.generate()

    print(f"Successfully generated CellGuard JSON definition file {build_file.name}")


if __name__ == "__main__":
    main()
