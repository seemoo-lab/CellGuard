# CapturePackets

An iOS tweak which captures the packets iOS and your iPhone's baseband exchange and provides a TCP interface on port 33067 to query them.
It supports iPhones with Qualcomm (QMI) and Intel (ARI) modems.

iOS Versions: 14.0 - 18.0

TCP Port: 33067

## Building

### Release

You can either build the tweak for rootfull or rootless tweak injectors.
MobileSubstrate used for the unc0ver jailbreak on iOS 14 is a rootfull tweak injector.
ElleKit used for the Dopamine jailbreak on iOS 15 is a rootless tweak injector.

```bash
# Rootfull (iOS 14)
gmake clean
FINALPACKAGE=1 gmake package

# Rootless (iOS 15)
gmake clean
THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1 gmake package
```

### Installation

Transfer the resulting package `.deb` to your device and install it using its package manager (Cydia, Sileo, or Zebra).

If you're running the [Dopamine](https://ellekit.space/dopamine/) jailbreak, don't forget to install [ElleKit](https://ellekit.space) beforehand.

### Development
1. Install [Theos](https://theos.dev/docs/) and set up its respective environment variables
2. Proxy the SSH port of your iPhone
```bash
iproxy 2222 22
```
3. Build and install the tweak
```bash
gmake do
```
