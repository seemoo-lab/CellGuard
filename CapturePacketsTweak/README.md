# CapturePackets

An iOS tweak which captures the packets iOS and your iPhone's baseband exchange and provides a TCP interface on port 33067 to query them.
It supports iPhones with Qualcomm (QMI) and Intel (ARI) modems.

iOS Versions: 14.0 - 16.4

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
