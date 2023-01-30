# Capture Cells

An iPhone tweak which captures the cellular base stations you've connected to and provides a TCP interface to query them.

iOS Versions: 14.0 - 15.7 (?)

## Building

### Release

```bash
FINALPACKAGE=1 gmake package
```

### Development
1. Install [Theos](https://theos.dev/docs/) and setup its respective environment variables
2. Proxy the SSH port of your iPhone
```bash
iproxy 2222 22
```
3. Build and install the tweak
```bash
gmake do
```
