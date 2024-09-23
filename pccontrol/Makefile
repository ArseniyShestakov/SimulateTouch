#export THEOS_DEVICE_IP = 192.168.0.6
TARGET := iphone:clang:latest:15.0
export ARCHS = arm64 
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = pccontrol

pccontrol_FILES = Tweak.xm SocketServer.xm Touch.xm Screen.xm Task.xm Process.xm AlertBox.xm Common.xm Record.xm Play.xm Window.xm Popup.xm TemplateMatch.xm ScreenMatch.xm Toast.xm Image.xm ColorPicker.xm UIKeyboard.xm DeviceInfo.xm TouchIndicator/TouchIndicatorWindow.xm TouchIndicator/TouchIndicatorView.xm TouchIndicator/TouchIndicatorCoordinateView.xm TouchIndicator/TouchIndicatorViewList.xm ScriptPlayer.xm Activator/ActivatorListener.xm TextRecognization/VKOcrManager.xm TextRecognization/TextRecognizer.xm UpdateCache.xm
pccontrol_CFLAGS = -Wno-error -Wno-module-import-in-extern-c -fobjc-arc
pccontrol_FRAMEWORKS = UIKit AssetsLibrary AVFoundation CoreMedia CoreVideo IOSurface
pccontrol_EXTRA_FRAMEWORKS = opencv2
#pccontrol_LDFLAGS += -L./libjpeg.a
pccontrol_ARCHS =  arm64
pccontrol_CCFLAGS = -std=c++11
#使用opencv 4.x
pccontrol_PRIVATE_FRAMEWORKS = IOKit
pccontrol_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "chown -R mobile:mobile /var/mobile/Library/ZXTouch && killall -9 SpringBoard;"


