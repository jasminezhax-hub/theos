# 关键修改：用 latest 代替固定的 15.0，让 Theos 自动找可用的 SDK
export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = 

TWEAK_NAME = CardKeyPlugin
CardKeyPlugin_FILES = Tweak.xm
CardKeyPlugin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
CardKeyPlugin_FRAMEWORKS = UIKit Foundation
CardKeyPlugin_LIBRARIES = substrate

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
