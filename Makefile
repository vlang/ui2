V ?= v

.PHONY: test check-macos check-ios check-android check-linux check-windows check-custom-macos check-custom-windows check-custom check-backends

test:
	$(V) test .

check-macos:
	$(V) -shared -os macos -check .

check-ios:
	$(V) -enable-globals -shared -os ios -check .

check-android:
	$(V) -shared -os android -check .

check-linux:
	$(V) -shared -os linux -check .
	$(V) -os linux -check ui_linux_test.v

check-windows:
	$(V) -enable-globals -shared -os windows -check .
	$(V) -enable-globals -os windows -check ui_windows_test.v

check-custom-macos:
	$(V) -d ui2_custom_rendering -shared -os macos -check .
	$(V) -d ui2_custom_rendering -os macos -check ui_custom_test.v

check-custom-windows:
	$(V) -d ui2_custom_rendering -shared -os windows -check .
	$(V) -d ui2_custom_rendering -os windows -check ui_custom_test.v

check-custom: check-custom-macos check-custom-windows

check-backends: check-macos check-ios check-android check-linux check-windows check-custom
