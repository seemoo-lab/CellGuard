# RotateKeysDaemon

A daemon for jailbroken iPhones distributing a token used by CellGuard and CapturePacketsTweak to secure their communication.

The daemon writes a random token every 5 minutes to CellGuard's keychain and to a file consumed by the CapturePacketsTweak.

## Development

```sh
# Clean build cache
gmake clean
# Apply CellGuard's signing configuration to daemon
gmake signing
# Create .deb package (rootful)
gmake package
# Or create .deb package (rootless)
THEOS_PACKAGE_SCHEME=rootless gmake package
# Install .deb on connected iPhone
gmake install
```

### Daemon Documentation

- https://www.launchd.info
- https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
- https://developer.apple.com/library/archive/technotes/tn2083/_index.html
- https://github.com/uroboro/iOS-daemon/tree/Objective-C
- https://github.com/frida/frida-core/blob/524fa7c68a50c8322b627d6d38e5e3ca193cf60c/tools/package-server-fruity.sh#L120

## Deployment

```sh
# Apply CellGuard's signing configuration to daemon
gmake signing

# Clean build cache
gmake clean
# Create .deb package (rootful)
FINALPACKAGE=1 gmake package

# Clean build cache
gmake clean
# Or create .deb package (rootless)
FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless gmake package
```
