TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e
THEOS_PACKAGE_SCHEME := rootless

INSTALL_TARGET_PROCESSES := SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := CSpeed
CSpeed_FILES := Tweak.xm CSpeedMath.c
CSpeed_CFLAGS := -fobjc-arc -Wall -Wextra
CSpeed_FRAMEWORKS := Foundation UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
