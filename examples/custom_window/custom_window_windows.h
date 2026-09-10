#ifndef UI2_EXAMPLE_CUSTOM_WINDOW_WINDOWS_H
#define UI2_EXAMPLE_CUSTOM_WINDOW_WINDOWS_H

#include <windows.h>

static HWND ui2_example_custom_window = NULL;

static BOOL CALLBACK ui2_example_find_custom_window(HWND window, LPARAM output) {
	wchar_t class_name[32];
	DWORD process_id = 0;
	GetWindowThreadProcessId(window, &process_id);
	if (process_id != GetCurrentProcessId()) return TRUE;
	if (GetClassNameW(window, class_name, 32) <= 0) return TRUE;
	if (lstrcmpW(class_name, L"UI2Window") != 0) return TRUE;
	*((HWND *)output) = window;
	return FALSE;
}

static HWND ui2_example_find_main_window(void) {
	HWND window = NULL;
	EnumWindows(ui2_example_find_custom_window, (LPARAM)&window);
	return window;
}

static inline bool ui2_example_configure_custom_window(int width, int height) {
	HWND window = ui2_example_find_main_window();
	if (window == NULL) return false;
	ui2_example_custom_window = window;
	SetWindowLongPtrW(window, GWL_STYLE, WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS);
	SetWindowLongPtrW(window, GWL_EXSTYLE,
		GetWindowLongPtrW(window, GWL_EXSTYLE) | WS_EX_LAYERED | WS_EX_APPWINDOW);
	// ui2 paints #010203 outside the cards. The layered host removes precisely
	// those pixels, leaving the independent rounded surfaces visible.
	SetLayeredWindowAttributes(window, RGB(1, 2, 3), 0, LWA_COLORKEY);
	SetWindowPos(window, NULL, 0, 0, width, height,
		SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
	return true;
}

static inline void ui2_example_drag_custom_window(void) {
	if (ui2_example_custom_window == NULL) {
		ui2_example_custom_window = ui2_example_find_main_window();
	}
	if (ui2_example_custom_window == NULL) return;
	ReleaseCapture();
	SendMessageW(ui2_example_custom_window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

#endif
