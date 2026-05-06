# 移除硬编码的 THEOS 路径，让 GitHub 自动读取环境变量
# 固定 TARGET 版本，避免 latest 导致的不兼容
export TARGET = iphone:clang:15.0:14.0
# 同时支持 arm64 和 arm64e 架构
export ARCHS = arm64 arm64e

# 目标 App 的 Bundle ID（这里可以先空着，不影响编译）
INSTALL_TARGET_PROCESSES = 

# 你的插件名，和 .plist 文件名必须完全一致
TWEAK_NAME = CardKeyPlugin

# 源文件
CardKeyPlugin_FILES = Tweak.xm
# 启用 ARC + 关闭不兼容警告
CardKeyPlugin_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
# 依赖的系统框架
CardKeyPlugin_FRAMEWORKS = UIKit Foundation
# 依赖的库（substrate 是越狱插件必须的）
CardKeyPlugin_LIBRARIES = substrate

# 引入 Theos 编译规则
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
