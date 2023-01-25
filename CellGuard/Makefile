# The SDK and iOS version to target. This is specifying the iOS 14.4 SDK and minimum build target as iOS 13.0
# Otherwise: iphone:clang:latest:7.0
TARGET = iphone:16.2:14.2
# The archiectures to compile for, arm64 is fine for most apps
ARCHS = arm64

# The name of the process to kill upon install, the name of your app
INSTALL_TARGET_PROCESSES = CellGuard

include $(THEOS)/makefiles/common.mk
# The name of your Xcode project/workspace
XCODEPROJ_NAME = CellGuard
# The scheme of your app to compile 
CellGuard_XCODE_SCHEME = CellGuard
# The ldid flag to sign your app with, we will make this next
# CellGuard_CODESIGN_FLAGS = -ScellGuardEntitlements.xml

include $(THEOS_MAKE_PATH)/xcodeproj.mk
