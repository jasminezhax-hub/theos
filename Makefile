export THEOS = /opt/theos
export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

INSTALL_TARGET_PROCESSES = 
TWEAK_NAME = CardKeyPlugin

CardKeyPlugin_FILES = Tweak.xm
CardKeyPlugin_CFLAGS = -fobjc-arc
CardKeyPlugin_FRAMEWORKS = UIKit Foundation

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
