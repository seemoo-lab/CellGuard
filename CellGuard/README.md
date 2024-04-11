# CellGuard (App)

Monitor and visualize cellular base stations collected by the accompanying tweak.

iOS Versions: 14.0 - 17.2

## Build
The app can either be distributed as a .deb package for jailbroken devices with Cydia or as an .ipa file which can be installed using TrollStore.

You'll need a Rust toolchain on your system to build the app's native libraries.
```sh
# Install Rust using rustup (https://www.rust-lang.org/tools/install)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Install additional iOS targets (64 bit for real device & simulator):
rustup target add aarch64-apple-ios x86_64-apple-ios
# Install cargo-lipo
cargo install cargo-lipo
```

The first time after cloning, you have to compile the libraries yourself by executing the following command:
```sh
PROJECT_DIR=. ./build-rust.sh
```
For release builds required for TestFlight uploads, also run the following command:
```sh
PROJECT_DIR=. CONFIGURATION=Release ./build-rust.sh
```
If you're using XCode to build an app archive for TestFlight distribution, you should switch the *Build Configuration* setting to *Release* in the *Archive* section. 

Upon changes, XCode will rebuild the libraries automatically. 

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
5. Right click the latest archive and select *Show in Finder*
6. In Finder right click on the *.xcarchive* file and select *Show package content*
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
pipenv run python3 build_ipa.py
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
