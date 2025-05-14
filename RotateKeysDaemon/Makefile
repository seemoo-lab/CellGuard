TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = rotatekeysd

RotateKeysDaemon_FILES = file.swift keychain.swift main.swift
RotateKeysDaemon_CODESIGN_FLAGS = -Sentitlements.plist
RotateKeysDaemon_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk

# update signing & developer configuration
signing:
	set -e ;\
	cp ../CellGuardAppSwift/Config/Developer.xcconfig layout/usr/local/bin/RotateKeysDaemon.config ;\
	DEVELOPMENT_TEAM=$$(grep -e 'DEVELOPMENT_TEAM' ../CellGuardAppSwift/Config/Developer.xcconfig | awk -F" = "  '{print $$2}') ;\
	PRODUCT_BUNDLE_IDENTIFIER=$$(grep -e 'PRODUCT_BUNDLE_IDENTIFIER' ../CellGuardAppSwift/Config/Developer.xcconfig | awk -F" = "  '{print $$2}') ;\
	defaults write "$$(pwd)/entitlements.plist" "com.apple.developer.team-identifier" "$$DEVELOPMENT_TEAM" ;\
	defaults write "$$(pwd)/entitlements.plist" "application-identifier" "$$DEVELOPMENT_TEAM.$$PRODUCT_BUNDLE_IDENTIFIER" ;\
	plutil -convert xml1 entitlements.plist ;\
