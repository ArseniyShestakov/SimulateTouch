#export THEOS_DEVICE_IP = 192.168.101.245
TARGET := iphone:clang:latest:15.0
include $(THEOS)/makefiles/common.mk

zxtouchb_ARCH = arm64
TOOL_NAME = zxtouchb

zxtouchb_FILES = main.mm
zxtouchb_FRAMEWORKS = CoreFoundation UIKit CoreGraphics
zxtouchb_CFLAGS = -fobjc-arc -Wno-error -Wno-module-import-in-extern-c -O2 -s -DNDEBUG

include $(THEOS_MAKE_PATH)/tool.mk
