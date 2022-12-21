TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = 'CommCenter'


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CaptureCells

CaptureCells_FILES = Tweak.x
CaptureCells_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
