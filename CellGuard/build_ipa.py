import argparse
import os.path
import re
import subprocess
import zipfile
from distutils import spawn
from pathlib import Path

from yaspin import yaspin


def build_rust_src():
    with yaspin(text="Building Native Libraries...") as spinner:
        env = os.environ.copy()
        env['CONFIGURATION'] = 'Release'
        env['PROJECT_DIR'] = os.path.dirname(__file__)

        process = subprocess.run(
            './build-rust.sh',
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True,
        )
        if process.returncode == 0:
            spinner.ok("🟢")
        else:
            spinner.fail("🔴")
            print(str(process.stderr).replace('\\n', '\n').replace('\\t', '\t'))
            print("Hint: Make sure that the Rust toolchain is installed and run "
                  "\"CONFIGURATION=Release PROJECT_DIR=. ./build-rust.sh\" to debug the error")
            exit(1)


@yaspin(text="Getting Build Settings...")
def get_build_settings() -> tuple[str, str]:
    # https://stackoverflow.com/a/59671351
    # https://stackoverflow.com/a/4760517

    with yaspin(text="Getting Build Settings...") as spinner:
        process = subprocess.run(
            ['xcodebuild', '-showBuildSettings'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if process.returncode == 0:
            spinner.ok("🟢")
        else:
            spinner.fail("🔴")

        settings = process.stdout.decode('utf-8')

        version_matches = re.findall(r'MARKETING_VERSION = ([\d.]+)', settings)
        version = version_matches[0]

        version_matches = re.findall(r'CURRENT_PROJECT_VERSION = (\d+)', settings)
        build = version_matches[0]

        return version, build


def build_archive() -> Path:
    # https://github.com/MrKai77/Export-unsigned-ipa-files

    with yaspin(text="Building CellGuard...") as spinner:
        process = subprocess.run([
            'xcodebuild', 'archive',
            '-scheme', 'CellGuard (Jailbreak)',
            '-archivePath', 'build/CellGuard.xcarchive',
            '-configuration', 'Release',
            'CODE_SIGN_IDENTITY=', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SINGING_ALLOWED=NO'
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if process.returncode == 0:
            spinner.ok("🟢")
        else:
            spinner.fail("🔴")
            print(str(process.stderr).replace('\\n', '\n').replace('\\t', '\t'))
            print("Hint: Run \"Product -> Archive\" in XCode to debug the issue, then run this command again")
            exit(1)

    return Path('build', 'CellGuard.xcarchive')


def create_ipa(archive_path: Path, ipa_path: Path):
    # https://github.com/MrKai77/Export-unsigned-ipa-files
    # https://stackoverflow.com/a/1855122
    # https://realpython.com/python-zipfile/#creating-a-zip-file-from-multiple-regular-files

    with yaspin(text="Creating IPA file...") as spinner:
        app_path = archive_path.joinpath('Products', 'Applications', 'CellGuard.app')
        with zipfile.ZipFile(ipa_path, 'w') as ipa_file:
            for file_path in app_path.rglob('*'):
                file_zip_path = Path.joinpath(Path('Payload'), file_path.relative_to(app_path.parent))
                ipa_file.write(filename=file_path, arcname=file_zip_path)

        spinner.ok("🟢")
        print(f'Successfully created {ipa_path}')


def airdrop(ipa_path: Path):
    # https://github.com/vldmrkl/airdrop-cli
    if spawn.find_executable("airdrop") is None:
        print("Please install 'airdrop' from https://github.com/vldmrkl/airdrop-cli")
        return

    with yaspin(text='Opening AirDrop UI...'):
        subprocess.run(["airdrop", ipa_path.absolute().__str__()])


def main():
    arg_parser = argparse.ArgumentParser(
        prog='build_ipa',
        description='Automatically build a IPA file for CellGuard using XCode command-line tools.'
    )
    arg_parser.add_argument(
        '-tipa', action='store_true',
        help='Build a .tipa file which can be AirDropped to an iPhone with TrollStore.'
    )
    arg_parser.add_argument(
        '-airdrop', action='store_true',
        help='Open the AirDrop UI to send the final .tipa file to your phone.'
    )
    args = arg_parser.parse_args()

    version, build = get_build_settings()
    build_rust_src()
    archive_path = build_archive()
    ipa_extension = '.tipa' if args.tipa else '.ipa'
    ipa_path = Path('build', f'CellGuard-{version}-{build}{ipa_extension}')
    create_ipa(archive_path, ipa_path)

    if args.airdrop:
        if args.tipa:
            airdrop(ipa_path)
        else:
            print("You can't AirDrop a .ipa file to TrollStore, please append the '-tipa' argument")


if __name__ == '__main__':
    main()
