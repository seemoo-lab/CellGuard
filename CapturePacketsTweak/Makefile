TARGET := iphone:clang:latest:14.0
# INSTALL_TARGET_PROCESSES = CommCenter


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CapturePackets

CapturePackets_FILES = Tweak.x CPTManager.m CPTBaseTweakManager.m
CapturePackets_CFLAGS = -fobjc-arc

ifeq ($(FINALPACKAGE), 1)
CapturePackets_CFLAGS += -DFINALPACKAGE
endif

# The dynamic_lookup flag is very important, otherwise the tweak won't compile
# $ man ld
#      -undefined treatment
#             Specifies how undefined symbols are to be treated. Options are:
#             error, warning, suppress, or dynamic_lookup.  The default is
#             error. Note: dynamic_lookup that depends on lazy binding will not
#             work with chained fixups.
# CapturePackets_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
