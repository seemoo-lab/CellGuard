TARGET := iphone:clang:latest:14.0

# https://theos.dev/docs/packaging
# https://theos.dev/docs/rootless
# https://theos.dev/docs/variables
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
  THEOS_LAYOUT_DIR = $(THEOS_PROJECT_DIR)/layout-arm64/
  THEOS_LAYOUT_DIR_NAME = layout-arm64
else
  THEOS_LAYOUT_DIR = $(THEOS_PROJECT_DIR)/layout-arm/
  THEOS_LAYOUT_DIR_NAME = layout-arm
endif

include $(THEOS)/makefiles/common.mk

TOOL_NAME = rotatekeysd

rotatekeysd_FILES = file.swift keychain.swift main.swift
rotatekeysd_CODESIGN_FLAGS = -Sentitlements.plist
rotatekeysd_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk

# update signing & developer configuration
# https://theos.dev/docs/configuration
signing:
	set -e ;\
	DEVELOPMENT_TEAM=$$(grep -e 'DEVELOPMENT_TEAM' ../CellGuardAppSwift/Config/Developer.xcconfig | awk -F" = "  '{print $$2}') ;\
	PRODUCT_BUNDLE_IDENTIFIER=$$(grep -e 'PRODUCT_BUNDLE_IDENTIFIER' ../CellGuardAppSwift/Config/Developer.xcconfig | awk -F" = "  '{print $$2}') ;\
	defaults write "$$(pwd)/entitlements.plist" "com.apple.developer.team-identifier" "$$DEVELOPMENT_TEAM" ;\
	defaults write "$$(pwd)/entitlements.plist" "application-identifier" "$$DEVELOPMENT_TEAM.$$PRODUCT_BUNDLE_IDENTIFIER" ;\
	plutil -convert xml1 entitlements.plist ;\
