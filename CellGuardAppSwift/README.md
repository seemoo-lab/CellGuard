# CellGuard (Swift App)

Monitor and visualize cellular base stations collected by the accompanying tweak.

iOS Versions: 14.0 - 18.5

## Setup

Clone this repo and navigate to this directory:
```sh
$ git clone git@github.com:seemoo-lab/CellGuard.git
$ cd CellGuard/CellGuardAppSwift
```

Rename and populate the developer team ID file:
```sh
$ cp Config/Developer.xcconfig.template Config/Developer.xcconfig
$ open Config/Developer.xcconfig
```

Complete the [initial set up](../CellGuardAppRust/README.md) for the native library written in Rust and compile the libraries once:
```sh
PROJECT_DIR=. ./build-rust.sh
```

Open the project in Xcode:
```sh
$ open CellGuard.xcodeproj
```

Initially, the first XCode build will fail, but the second ones should be successful as all required files have been generated. 

## Build
The app can either be distributed as a .deb package for jailbroken devices with Cydia or as an .ipa file which can be installed using TrollStore.

Upon changes, XCode will rebuild the native libraries automatically.
However, if this does not work you can resort to building them manually:
```sh
PROJECT_DIR=. ./build-rust.sh
```
If you're using XCode to build an app archive for TestFlight distribution, you should switch the *Build Configuration* setting to *Release* in the *Archive* section.
You can also manually build the library in release mode:
```sh
PROJECT_DIR=. CONFIGURATION=Release ./build-rust.sh
```

### XCode

You can connect your device to your Mac and install the app via XCode.
If you don't have a paid developer account, the app will only be available for seven days.
After which you have to reinstall it.
On jailbroken devices, you can use [Unified AppSync](https://cydia.akemi.ai/?page/ai.akemi.appsyncunified) for an infinite validity period.

### .ipa

A .ipa file can be installed using [TrollStore](https://github.com/opa334/TrollStore).

1. Open the project in XCode
2. Select as build configuration *CellGuard > Any iOS Device (arm64)*
3. Click *Product -> Archive*
4. Wait for the *Archives* window to open
5. Right-click the latest archive and select *Show in Finder*
6. In Finder right-click on the *.xcarchive* file and select *Show package content*
7. Navigate to *Products -> Applications -> CellGuard.app*
8. Copy the *CellGuard.app* file to a new folder outside named *Payload*
9. Compress the *Payload* folder
10. Rename the created *Payload.zip* file to *CellGuard-X_X_X.ipa*

Copy the final .ipa file via iCloud to iPhone and install it using TrollStore.

References:
- [GeneXus](https://wiki.genexus.com/commwiki/servlet/wiki?34616,HowTo%3A+Create+an+.ipa+file+from+XCode): Requires paid Apple Developer Account
- https://stackoverflow.com/a/72724017: Doesn't require an Apple Developer Account

The [`build-ipa.py`](./build_ipa.py) script automates all of these steps:
```sh
# Build .ipa 
uv run build_ipa.py
# Build .tipa (TrollStore-friendly IPA)
uv run build_ipa.py -tipa
```

### .deb

A .deb file can be installed on jailbroken iPhones using the included dpkg package manager or alternative app stores like Cydia, Zebra, or Sileo.

First, install [Theos](https://theos.dev/docs/) and setup its environment variables.
Then you can run of one of the following commands:

```bash
# Only build the Debian package (.deb) containing the app
THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 gmake package

# Build the .deb and install it on your local device
THEOS_PACKAGE_SCHEME=rootless gmake do
```

To read more on how to build jailbroken apps, see
- https://github.com/elihwyma/ExampleXcodeApp
- https://github.com/elihwyma/SignalReborn

⛔️ Currently, a bug assumed to be caused by Swift concurrency prevents the app from starting if it is installed using a .deb file. Read more on [GitHub](https://github.com/utmapp/UTM/issues/3628#issuecomment-1144471721).

Thus, we recommend the other way of installing the app.

## Development

### Code Format

We use [SwiftLint](https://github.com/realm/SwiftLint) to ensure a consistent code format.
The linter [integrates](https://github.com/realm/SwiftLint?tab=readme-ov-file#xcode-projects) with XCode, but you might have to trust its plugin upon the first build you perform.
The file [`.swiftlint.yml`](./.swiftlint.yml) defines linter's rules.

### Privacy Manifest

**Apple requires apps to include a [privacy manifest](./PrivacyInfo.xcprivacy).
Remember to expand the manifest if you use new APIs or collect new types of data.**

Read more:
- https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- https://developer.apple.com/app-store/user-privacy-and-data-use/
- https://developer.apple.com/app-store/app-privacy-details/

### ARI Definitions

```sh
# Clone aristoteles
git clone https://github.com/seemoo-lab/aristoteles.git

# Generate JSON file
uv run generate_ari_json.py aristoteles/types/structure/libari_dylib.lua

# Minimize JSON file
cd CellGuard/Tweaks/Capture\ Packets/ari-definitions.json
jq -r tostring ari-definitions.json > ari-definitions-min.json
mv ari-definitions-min.json file.json
gzip file.json
```

### Network Operators

```sh
# Generate CSV files
uv run generate_operators.py

# Minimize CSV files
gzip CellGuard/Cells/countries.csv
gzip CellGuard/Cells/operators.csv
```

### JSON files

We include minimized and gzipped JSON files in CellGuard to reduce the app's final size.

You can create a new optimized JSON files as follows:
```sh
# Minimize JSON file (optional)
jq -r tostring file.json > file-min.json
mv file-min.json file.json
# Gzip JSON file 
gzip file.json
```
