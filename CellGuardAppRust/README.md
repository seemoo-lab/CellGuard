# CellGuard (Rust Library)

A Rust library used by [CellGuardAppSwift](../CellGuardAppSwift) for reading logarchives from sysdiagnoses.
Refer to the build instructions in the respective directory.

Learn more about the bridge between Rust and Swift at [chinedufn/swift-bridge](https://github.com/chinedufn/swift-bridge).

## Setup

You'll need a Rust toolchain on your system to build the app's native libraries.
```sh
# Install Rust using rustup (https://www.rust-lang.org/tools/install)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# Install additional iOS targets (64 bit for real device & simulator):
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
# Install cargo-lipo
cargo install cargo-lipo cargo-bundle-licenses
```

## Update Dependencies

To update the Rust dependencies run the following commands from this directory (i.e., `/CellGuardAppRust/`).
```sh
# Update Rust dependencies with cargo package manager
cargo update

# Update generated license file, might require some manual edits
# See: https://github.com/sstadick/cargo-bundle-licenses?tab=readme-ov-file#usage
gunzip ../CellGuardAppSwift/cargo-licenses.json
cargo bundle-licenses --format json --output ../CellGuardAppSwift/cargo-licenses.json --previous ../CellGuardAppSwift/cargo-licenses.json
gzip ../CellGuardAppSwift/cargo-licenses.json
```