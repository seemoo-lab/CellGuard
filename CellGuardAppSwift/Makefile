# The SDK and iOS version to target. This is specifying the iOS 14.4 SDK and minimum build target as iOS 13.0
# Otherwise: iphone:clang:latest:7.0
TARGET = iphone:clang:latest:14.0
# The architectures to compile for, arm64 is fine for most apps
ARCHS = arm64

# For now we just building CellGuard for Dopamine as it crashes on unc0ver
export INSTALL_PREFIX = /var/jb

# The name of the process to kill upon install, the name of your app
INSTALL_TARGET_PROCESSES = CellGuard

include $(THEOS)/makefiles/common.mk
# The name of your Xcode project/workspace
XCODEPROJ_NAME = CellGuard
# The scheme of your app to compile 
CellGuard_XCODE_SCHEME = CellGuard (Jailbreak)
# The ldid flag to sign your app with, we will make this next
# CellGuard_CODESIGN_FLAGS = -ScellGuardEntitlements.xml

# https://github.com/hbang/NewTerm/blob/main/Makefile
CellGuard_XCODEFLAGS = INSTALL_PREFIX=$(INSTALL_PREFIX)
CellGuard_CODESIGN_FLAGS = -Sentitlements.plist
CellGuard_INSTALL_PATH = $(INSTALL_PREFIX)/Applications

include $(THEOS_MAKE_PATH)/xcodeproj.mk
