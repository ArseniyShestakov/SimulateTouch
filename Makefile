# lipoplastic setup for armv6 + arm64 compilation
export ARCHS = arm64
#export THEOS_DEVICE_IP = 192.168.0.3
TARGET := iphone:clang:latest:15.0
SUBPROJECTS = appdelegate zxtouch-binary
#SUBPROJECTS = appdelegate zxtouch-binary pccontrol

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/aggregate.mk

# Foundation.h 默认不需要导入，放在$(theos)/include下面，也可以将其它头文件放在那里

after-install::
	install.exec "chown -R mobile:mobile /var/mobile/Library/ZXTouch && killall -9 SpringBoard;"

