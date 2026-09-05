V ?= v

.PHONY: test check-macos check-ios check-android check-windows check-backends

test:
	$(V) test .

check-macos:
	$(V) -shared -os macos -check .

check-ios:
	$(V) -enable-globals -shared -os ios -check .

check-android:
	$(V) -enable-globals -shared -os android -check .

check-windows:
	$(V) -enable-globals -shared -os windows -check .
	$(V) -enable-globals -os windows -check ui_windows_test.v

check-backends: check-macos check-ios check-android check-windows
