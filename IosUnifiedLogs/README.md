# iOS Unified Logs

Bridging the [macos-unifiedlogs](https://github.com/mandiant/macos-UnifiedLogs/tree/main) project to Swift.

Resources:
* https://chinedufn.github.io/swift-bridge/building/xcode-and-cargo/index.html

Run the commands before building anything:
```sh
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios
```

Build the rusty stuff:
```sh
# Build for real iPhones
PROJECT_DIR="${PWD}/IosUnifiedLogs" ./IosUnifiedLogs/build-rust.sh
# Build for iPhone simulators
PROJECT_DIR="${PWD}/IosUnifiedLogs" PLATFORM_NAME="iphonesimulator" ./IosUnifiedLogs/build-rust.sh
```
