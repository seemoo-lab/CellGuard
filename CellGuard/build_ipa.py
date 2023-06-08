import re
import subprocess
import zipfile
from pathlib import Path

from yaspin import yaspin


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
        process = subprocess.run(
            ['xcodebuild', 'archive', '-scheme', 'CellGuard', '-archivePath', 'build/CellGuard.xcarchive',
             '-configuration', 'Release', 'CODE_SIGN_IDENTITY=', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SINGIN_ALLOWED=NO'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if process.returncode == 0:
            spinner.ok("🟢")
        else:
            spinner.fail("🔴")
            print(process.stderr)
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


def main():
    version, build = get_build_settings()
    archive_path = build_archive()
    create_ipa(archive_path, Path('build', f'CellGuard-{version}-{build}.ipa'))


if __name__ == '__main__':
    main()
