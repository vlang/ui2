#ifndef UI2_NATIVE_HELPERS_WINDOWS_H
#define UI2_NATIVE_HELPERS_WINDOWS_H

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#ifndef WINVER
#define WINVER _WIN32_WINNT
#endif
#ifndef _WIN32_IE
#define _WIN32_IE 0x0600
#endif

#include <windows.h>
#include <windowsx.h>
#include <commctrl.h>
#include <shellapi.h>
#include <stdint.h>
#include <wchar.h>

#define UI2_WM_REFRESH (WM_APP + 77)

enum {
	UI2_WIN_VIEW = 1,
	UI2_WIN_SCROLL = 2,
	UI2_WIN_LABEL = 3,
	UI2_WIN_IMAGE = 4,
	UI2_WIN_BUTTON = 5,
	UI2_WIN_DROPDOWN = 6,
	UI2_WIN_TEXT_FIELD = 7,
	UI2_WIN_TEXT_AREA = 8,
	UI2_WIN_CHECKBOX = 9
};

extern intptr_t ui2_windows_window_proc(void *hwnd, unsigned int message,
		uintptr_t wparam, intptr_t lparam);
extern int ui2_windows_edit_submit(void *hwnd);
extern int ui2_windows_control_key(void *hwnd, unsigned int virtual_key);
extern int ui2_windows_context_menu(void *hwnd, int screen_x, int screen_y);
extern int ui2_windows_cursor(void *hwnd);
extern void ui2_windows_control_pointer(void *hwnd, unsigned int message, int x, int y);

static inline void ui2_win_refresh_text_font(HWND hwnd);

static const wchar_t *ui2_win_placeholder_property(void) {
	return L"ui2.placeholder";
}

static inline void ui2_win_store_placeholder(HWND hwnd, const wchar_t *placeholder) {
	wchar_t *previous = (wchar_t *)GetPropW(hwnd, ui2_win_placeholder_property());
	const wchar_t *value = placeholder == NULL ? L"" : placeholder;
	if (previous != NULL && wcscmp(previous, value) == 0) return;
	if (previous != NULL) {
		RemovePropW(hwnd, ui2_win_placeholder_property());
		HeapFree(GetProcessHeap(), 0, previous);
	}
	if (value[0] == 0) return;
	size_t bytes = (wcslen(value) + 1) * sizeof(wchar_t);
	wchar_t *copy = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, bytes);
	if (copy == NULL) return;
	CopyMemory(copy, value, bytes);
	if (!SetPropW(hwnd, ui2_win_placeholder_property(), (HANDLE)copy)) {
		HeapFree(GetProcessHeap(), 0, copy);
	}
}

static inline void ui2_win_draw_placeholder(HWND hwnd) {
	const wchar_t *placeholder = (const wchar_t *)GetPropW(
		hwnd, ui2_win_placeholder_property());
	if (placeholder == NULL || placeholder[0] == 0 || GetFocus() == hwnd
		|| GetWindowTextLengthW(hwnd) != 0) return;
	HDC dc = GetDC(hwnd);
	if (dc == NULL) return;
	RECT rect;
	SendMessageW(hwnd, EM_GETRECT, 0, (LPARAM)&rect);
	HFONT font = (HFONT)SendMessageW(hwnd, WM_GETFONT, 0, 0);
	HGDIOBJ previous_font = font == NULL ? NULL : SelectObject(dc, font);
	int previous_mode = SetBkMode(dc, TRANSPARENT);
	COLORREF previous_color = SetTextColor(dc, GetSysColor(COLOR_GRAYTEXT));
	DrawTextW(dc, placeholder, -1, &rect,
		DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX);
	SetTextColor(dc, previous_color);
	SetBkMode(dc, previous_mode);
	if (previous_font != NULL) SelectObject(dc, previous_font);
	ReleaseDC(hwnd, dc);
}

static inline void ui2_win_release_placeholder(HWND hwnd) {
	wchar_t *placeholder = (wchar_t *)RemovePropW(hwnd, ui2_win_placeholder_property());
	if (placeholder != NULL) HeapFree(GetProcessHeap(), 0, placeholder);
}

static inline int ui2_win_apply_cursor(void *hwnd) {
	int cursor = ui2_windows_cursor(hwnd);
	LPCWSTR identifier = NULL;
	switch (cursor) {
	case 1: identifier = IDC_HAND; break;
	case 2: identifier = IDC_SIZENWSE; break;
	case 3: identifier = IDC_SIZENESW; break;
	case 4: identifier = IDC_SIZEWE; break;
	case 5: identifier = IDC_SIZENS; break;
	default: break;
	}
	if (identifier == NULL) return 0;
	SetCursor(LoadCursorW(NULL, identifier));
	return 1;
}

static LRESULT CALLBACK ui2_win_control_subclass(HWND hwnd, UINT message, WPARAM wparam,
		LPARAM lparam, UINT_PTR subclass_id, DWORD_PTR reference_data) {
	(void)subclass_id;
	(void)reference_data;
	if (message == WM_KEYDOWN && wparam == VK_RETURN && ui2_windows_edit_submit(hwnd)) {
		return 0;
	}
	if (message == WM_KEYDOWN && ui2_windows_control_key(hwnd, (unsigned int)wparam)) {
		return 0;
	}
	if (message == WM_KEYDOWN && !IsWindow(hwnd)) return 0;
	if (message == WM_SETCURSOR && LOWORD(lparam) == HTCLIENT && ui2_win_apply_cursor(hwnd)) {
		return TRUE;
	}
	if (message == WM_CONTEXTMENU
		&& ui2_windows_context_menu(hwnd, GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam))) {
		return 0;
	}
	if (message == WM_LBUTTONDOWN || message == WM_MOUSEMOVE || message == WM_LBUTTONUP) {
		ui2_windows_control_pointer(hwnd, message, GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
		if (!IsWindow(hwnd)) return 0;
	}
	if (message == WM_PAINT) {
		LRESULT result = DefSubclassProc(hwnd, message, wparam, lparam);
		ui2_win_draw_placeholder(hwnd);
		return result;
	}
	if (message == WM_SETFOCUS || message == WM_KILLFOCUS || message == WM_SETTEXT) {
		LRESULT result = DefSubclassProc(hwnd, message, wparam, lparam);
		if (message == WM_SETTEXT && IsWindow(hwnd)) ui2_win_refresh_text_font(hwnd);
		InvalidateRect(hwnd, NULL, TRUE);
		return result;
	}
	if (message == WM_CHAR || message == WM_PASTE || message == EM_REPLACESEL) {
		LRESULT result = DefSubclassProc(hwnd, message, wparam, lparam);
		if (IsWindow(hwnd)) ui2_win_refresh_text_font(hwnd);
		return result;
	}
	if (message == WM_MOUSEWHEEL) {
		HWND parent = GetParent(hwnd);
		wchar_t class_name[64];
		while (parent != NULL) {
			class_name[0] = 0;
			GetClassNameW(parent, class_name, 64);
			if (wcscmp(class_name, L"UI2Container") == 0
				&& (GetWindowLongPtrW(parent, GWL_STYLE) & WS_VSCROLL) != 0) {
				SendMessageW(parent, message, wparam, lparam);
				return 0;
			}
			parent = GetParent(parent);
		}
	}
	if (message == WM_NCDESTROY) {
		ui2_win_release_placeholder(hwnd);
		RemoveWindowSubclass(hwnd, ui2_win_control_subclass, 1);
	}
	return DefSubclassProc(hwnd, message, wparam, lparam);
}

static LRESULT CALLBACK ui2_win_window_proc(HWND hwnd, UINT message, WPARAM wparam,
		LPARAM lparam) {
	if (message == WM_MOUSEWHEEL
		&& (GetWindowLongPtrW(hwnd, GWL_STYLE) & WS_VSCROLL) == 0) {
		HWND parent = GetParent(hwnd);
		while (parent != NULL) {
			if ((GetWindowLongPtrW(parent, GWL_STYLE) & WS_VSCROLL) != 0) {
				SendMessageW(parent, message, wparam, lparam);
				return 0;
			}
			parent = GetParent(parent);
		}
	}
	if (message == WM_CONTEXTMENU
		&& ui2_windows_context_menu(hwnd, GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam))) {
		return 0;
	}
	if (message == WM_SETCURSOR && LOWORD(lparam) == HTCLIENT && ui2_win_apply_cursor(hwnd)) {
		return TRUE;
	}
	if (message == WM_LBUTTONDOWN || message == WM_MOUSEMOVE || message == WM_LBUTTONUP) {
		ui2_windows_control_pointer(hwnd, message, GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
		if (!IsWindow(hwnd)) return 0;
	}
	return (LRESULT)ui2_windows_window_proc(hwnd, message, (uintptr_t)wparam,
		(intptr_t)lparam);
}

static inline COLORREF ui2_win_color(unsigned int rgb) {
	return RGB((rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff);
}

static HANDLE ui2_win_visual_styles_context = INVALID_HANDLE_VALUE;
static ULONG_PTR ui2_win_visual_styles_cookie = 0;
static int ui2_win_visual_styles_initialized = 0;

static inline int ui2_win_enable_visual_styles(void) {
	if (ui2_win_visual_styles_initialized) {
		return ui2_win_visual_styles_context != INVALID_HANDLE_VALUE;
	}
	ui2_win_visual_styles_initialized = 1;

	wchar_t directory[MAX_PATH + 1];
	wchar_t path[MAX_PATH + 1];
	DWORD directory_length = GetTempPathW(MAX_PATH, directory);
	if (directory_length == 0 || directory_length > MAX_PATH
		|| GetTempFileNameW(directory, L"ui2", 0, path) == 0) {
		return 0;
	}

	static const char manifest[] =
		"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
		"<assembly xmlns=\"urn:schemas-microsoft-com:asm.v1\" manifestVersion=\"1.0\">"
		"<assemblyIdentity name=\"ui2.runtime\" processorArchitecture=\"*\" "
			"version=\"1.0.0.0\" type=\"win32\"/>"
		"<dependency><dependentAssembly><assemblyIdentity type=\"win32\" "
			"name=\"Microsoft.Windows.Common-Controls\" version=\"6.0.0.0\" "
			"processorArchitecture=\"*\" publicKeyToken=\"6595b64144ccf1df\" "
			"language=\"*\"/></dependentAssembly></dependency></assembly>";

	HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
		FILE_ATTRIBUTE_TEMPORARY, NULL);
	if (file == INVALID_HANDLE_VALUE) {
		DeleteFileW(path);
		return 0;
	}
	DWORD written = 0;
	BOOL wrote_manifest = WriteFile(file, manifest, (DWORD)(sizeof(manifest) - 1),
		&written, NULL);
	CloseHandle(file);
	if (!wrote_manifest || written != sizeof(manifest) - 1) {
		DeleteFileW(path);
		return 0;
	}

	ACTCTXW activation;
	ZeroMemory(&activation, sizeof(activation));
	activation.cbSize = sizeof(activation);
	activation.lpSource = path;
	ui2_win_visual_styles_context = CreateActCtxW(&activation);
	DeleteFileW(path);
	if (ui2_win_visual_styles_context == INVALID_HANDLE_VALUE) return 0;
	if (!ActivateActCtx(ui2_win_visual_styles_context, &ui2_win_visual_styles_cookie)) {
		ReleaseActCtx(ui2_win_visual_styles_context);
		ui2_win_visual_styles_context = INVALID_HANDLE_VALUE;
		return 0;
	}
	return 1;
}

static inline int ui2_win_visual_styles_enabled(void) {
	return ui2_win_visual_styles_context != INVALID_HANDLE_VALUE;
}

static inline HFONT ui2_win_system_font(void) {
	static HFONT font = NULL;
	if (font != NULL) return font;
	NONCLIENTMETRICSW metrics;
	ZeroMemory(&metrics, sizeof(metrics));
	metrics.cbSize = sizeof(metrics);
	if (SystemParametersInfoW(SPI_GETNONCLIENTMETRICS, sizeof(metrics), &metrics, 0)) {
		// The message font is reported with the locale charset, which switches
		// GDI font association off and paints a box for anything the face is
		// missing. DEFAULT_CHARSET lets GDI link to other installed fonts.
		metrics.lfMessageFont.lfCharSet = DEFAULT_CHARSET;
		font = CreateFontIndirectW(&metrics.lfMessageFont);
	}
	return font == NULL ? (HFONT)GetStockObject(DEFAULT_GUI_FONT) : font;
}

static inline int ui2_win_register_classes(void) {
	// Common Controls v6 supplies the current Windows button bezel and native
	// hover/pressed states. Activate it before registering or creating controls.
	ui2_win_enable_visual_styles();
	INITCOMMONCONTROLSEX controls;
	ZeroMemory(&controls, sizeof(controls));
	controls.dwSize = sizeof(controls);
	controls.dwICC = ICC_STANDARD_CLASSES | ICC_WIN95_CLASSES;
	InitCommonControlsEx(&controls);

	HINSTANCE instance = GetModuleHandleW(NULL);
	WNDCLASSEXW cls;
	ZeroMemory(&cls, sizeof(cls));
	cls.cbSize = sizeof(cls);
	cls.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
	cls.lpfnWndProc = ui2_win_window_proc;
	cls.hInstance = instance;
	cls.hCursor = LoadCursorW(NULL, IDC_ARROW);
	cls.lpszClassName = L"UI2Window";
	if (RegisterClassExW(&cls) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
		return 0;
	}
	cls.lpszClassName = L"UI2Container";
	if (RegisterClassExW(&cls) == 0 && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
		return 0;
	}
	return 1;
}

static inline void *ui2_win_create_main_window(const wchar_t *title, int width, int height) {
	RECT frame = {0, 0, width, height};
	AdjustWindowRectEx(&frame, WS_OVERLAPPEDWINDOW, FALSE, 0);
	HWND hwnd = CreateWindowExW(0, L"UI2Window", title == NULL ? L"App" : title,
		WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN, CW_USEDEFAULT, CW_USEDEFAULT,
		frame.right - frame.left, frame.bottom - frame.top, NULL, NULL,
		GetModuleHandleW(NULL), NULL);
	if (hwnd != NULL) {
		DragAcceptFiles(hwnd, TRUE);
	}
	return hwnd;
}

static inline void ui2_win_set_window_title(void *hwnd, const wchar_t *title) {
	if (hwnd != NULL) SetWindowTextW((HWND)hwnd, title == NULL ? L"" : title);
}

static inline DWORD ui2_win_label_style(int alignment) {
	if (alignment == 1) return SS_CENTER | SS_CENTERIMAGE;
	if (alignment == 2) return SS_RIGHT | SS_CENTERIMAGE;
	return SS_LEFT | SS_CENTERIMAGE;
}

static inline DWORD ui2_win_edit_style(int alignment) {
	if (alignment == 1) return ES_CENTER;
	if (alignment == 2) return ES_RIGHT;
	return ES_LEFT;
}

static inline void *ui2_win_create_widget(int kind, void *parent_ptr, int x, int y,
		int width, int height, const wchar_t *text, int alignment, int secure,
		int readonly, int disable_scroll) {
	HWND parent = (HWND)parent_ptr;
	DWORD style = WS_CHILD | WS_VISIBLE;
	DWORD ex_style = 0;
	const wchar_t *class_name = L"STATIC";
	switch (kind) {
	case UI2_WIN_VIEW:
		class_name = L"UI2Container";
		style |= WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
		ex_style = WS_EX_CONTROLPARENT;
		break;
	case UI2_WIN_SCROLL:
		class_name = L"UI2Container";
		style |= WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_VSCROLL;
		ex_style = WS_EX_CONTROLPARENT;
		break;
	case UI2_WIN_LABEL:
		class_name = L"STATIC";
		style |= ui2_win_label_style(alignment) | SS_NOTIFY;
		ex_style = WS_EX_TRANSPARENT;
		break;
	case UI2_WIN_IMAGE:
		class_name = L"STATIC";
		style |= SS_BITMAP | SS_CENTERIMAGE | SS_NOTIFY;
		break;
	case UI2_WIN_BUTTON:
		class_name = L"BUTTON";
		style |= BS_PUSHBUTTON | BS_CENTER | BS_VCENTER | WS_TABSTOP;
		break;
	case UI2_WIN_CHECKBOX:
		class_name = L"BUTTON";
		style |= BS_AUTOCHECKBOX | BS_LEFT | BS_VCENTER | WS_TABSTOP;
		break;
	case UI2_WIN_DROPDOWN:
		class_name = L"COMBOBOX";
		style |= CBS_DROPDOWNLIST | CBS_HASSTRINGS | WS_VSCROLL | WS_TABSTOP;
		ex_style = WS_EX_CLIENTEDGE;
		break;
	case UI2_WIN_TEXT_FIELD:
		class_name = L"EDIT";
		style |= ui2_win_edit_style(alignment) | ES_AUTOHSCROLL | WS_TABSTOP;
		if (secure) style |= ES_PASSWORD;
		if (readonly) style |= ES_READONLY;
		ex_style = WS_EX_CLIENTEDGE;
		break;
	case UI2_WIN_TEXT_AREA:
		class_name = L"EDIT";
		style |= ui2_win_edit_style(alignment) | ES_MULTILINE | ES_AUTOVSCROLL
			| ES_WANTRETURN | WS_TABSTOP;
		if (!disable_scroll) style |= WS_VSCROLL;
		if (readonly) style |= ES_READONLY;
		ex_style = WS_EX_CLIENTEDGE;
		break;
	default:
		return NULL;
	}
	HWND hwnd = CreateWindowExW(ex_style, class_name, text == NULL ? L"" : text, style,
		x, y, width, height, parent, NULL, GetModuleHandleW(NULL), NULL);
	if (hwnd != NULL && kind != UI2_WIN_VIEW && kind != UI2_WIN_SCROLL) {
		SendMessageW(hwnd, WM_SETFONT, (WPARAM)ui2_win_system_font(), TRUE);
		SetWindowSubclass(hwnd, ui2_win_control_subclass, 1, 0);
	}
	return hwnd;
}

static inline void ui2_win_show_main_window(void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	ShowWindow(hwnd, SW_SHOWDEFAULT);
	UpdateWindow(hwnd);
}

static inline void ui2_win_set_checked(void *hwnd_ptr, int checked) {
	if (hwnd_ptr != NULL) {
		SendMessageW((HWND)hwnd_ptr, BM_SETCHECK,
			checked ? BST_CHECKED : BST_UNCHECKED, 0);
	}
}

static inline int ui2_win_message_loop(void) {
	MSG message;
	while (GetMessageW(&message, NULL, 0, 0) > 0) {
		TranslateMessage(&message);
		DispatchMessageW(&message);
	}
	return (int)message.wParam;
}

static inline intptr_t ui2_win_default_proc(void *hwnd, unsigned int message,
		uintptr_t wparam, intptr_t lparam) {
	return (intptr_t)DefWindowProcW((HWND)hwnd, message, (WPARAM)wparam, (LPARAM)lparam);
}

static inline void ui2_win_post_quit(int code) {
	PostQuitMessage(code);
}

static inline void ui2_win_post_refresh(void *hwnd) {
	if (hwnd != NULL) PostMessageW((HWND)hwnd, UI2_WM_REFRESH, 0, 0);
}

static inline void ui2_win_close(void *hwnd) {
	if (hwnd != NULL) PostMessageW((HWND)hwnd, WM_CLOSE, 0, 0);
}

static inline void ui2_win_destroy(void *hwnd) {
	if (hwnd != NULL && IsWindow((HWND)hwnd)) DestroyWindow((HWND)hwnd);
}

static inline int ui2_win_is_window(void *hwnd) {
	return hwnd != NULL && IsWindow((HWND)hwnd);
}

static inline void *ui2_win_parent(void *hwnd) {
	return hwnd == NULL ? NULL : GetParent((HWND)hwnd);
}

static inline void ui2_win_set_parent(void *hwnd, void *parent) {
	if (hwnd != NULL) SetParent((HWND)hwnd, (HWND)parent);
}

static inline void ui2_win_set_frame(void *hwnd, int x, int y, int width, int height) {
	if (hwnd != NULL) {
		SetWindowPos((HWND)hwnd, NULL, x, y, width, height,
			SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOCOPYBITS);
	}
}

static inline void ui2_win_set_widget_frame(void *hwnd, int kind, int x, int y,
		int width, int height) {
	// Win32 uses the combo box window height for both the closed control and its
	// drop-down list. Give the list room without changing the visible row height.
	ui2_win_set_frame(hwnd, x, y, width,
		kind == UI2_WIN_DROPDOWN ? height + 240 : height);
}

static inline void ui2_win_place_after(void *hwnd, void *previous) {
	if (hwnd == NULL) return;
	(void)previous;
	// Rendering visits siblings from back to front. Moving each visited child to
	// the top gives later declarative siblings the same stacking priority used
	// by the other backends.
	SetWindowPos((HWND)hwnd, HWND_TOP,
		0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

static inline void ui2_win_show(void *hwnd, int visible) {
	if (hwnd != NULL) ShowWindow((HWND)hwnd, visible ? SW_SHOWNA : SW_HIDE);
}

static inline void ui2_win_enable(void *hwnd, int enabled) {
	if (hwnd != NULL) EnableWindow((HWND)hwnd, enabled);
}

typedef struct ui2_win_tooltip_binding {
	HWND tooltip;
	wchar_t *text;
} ui2_win_tooltip_binding;

static inline void *ui2_win_create_tooltip(void *target_ptr, const wchar_t *text) {
	HWND target = (HWND)target_ptr;
	if (target == NULL || text == NULL || text[0] == 0) return NULL;
	ui2_win_tooltip_binding *binding = (ui2_win_tooltip_binding *)HeapAlloc(
		GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(ui2_win_tooltip_binding));
	if (binding == NULL) return NULL;
	size_t bytes = (wcslen(text) + 1) * sizeof(wchar_t);
	binding->text = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, bytes);
	if (binding->text == NULL) {
		HeapFree(GetProcessHeap(), 0, binding);
		return NULL;
	}
	CopyMemory(binding->text, text, bytes);
	HWND owner = GetAncestor(target, GA_ROOT);
	binding->tooltip = CreateWindowExW(WS_EX_TOPMOST, TOOLTIPS_CLASSW, NULL,
		WS_POPUP | TTS_ALWAYSTIP | TTS_NOPREFIX, CW_USEDEFAULT, CW_USEDEFAULT,
		CW_USEDEFAULT, CW_USEDEFAULT, owner, NULL, GetModuleHandleW(NULL), NULL);
	if (binding->tooltip == NULL) {
		HeapFree(GetProcessHeap(), 0, binding->text);
		HeapFree(GetProcessHeap(), 0, binding);
		return NULL;
	}
	TOOLINFOW tool;
	ZeroMemory(&tool, sizeof(tool));
	tool.cbSize = sizeof(tool);
	tool.uFlags = TTF_IDISHWND | TTF_SUBCLASS;
	tool.hwnd = owner;
	tool.uId = (UINT_PTR)target;
	tool.lpszText = binding->text;
	if (!SendMessageW(binding->tooltip, TTM_ADDTOOLW, 0, (LPARAM)&tool)) {
		DestroyWindow(binding->tooltip);
		HeapFree(GetProcessHeap(), 0, binding->text);
		HeapFree(GetProcessHeap(), 0, binding);
		return NULL;
	}
	SendMessageW(binding->tooltip, TTM_SETMAXTIPWIDTH, 0, 480);
	SetWindowPos(binding->tooltip, HWND_TOPMOST, 0, 0, 0, 0,
		SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
	return binding;
}

static inline void ui2_win_destroy_tooltip(void *binding_ptr) {
	ui2_win_tooltip_binding *binding = (ui2_win_tooltip_binding *)binding_ptr;
	if (binding == NULL) return;
	if (binding->tooltip != NULL && IsWindow(binding->tooltip)) {
		DestroyWindow(binding->tooltip);
	}
	if (binding->text != NULL) HeapFree(GetProcessHeap(), 0, binding->text);
	HeapFree(GetProcessHeap(), 0, binding);
}

static inline void ui2_win_focus(void *hwnd) {
	if (hwnd != NULL) SetFocus((HWND)hwnd);
}

static inline void *ui2_win_focus_handle(void) {
	return GetFocus();
}

static inline void ui2_win_clear_focus(void *root) {
	if (root != NULL) SetFocus((HWND)root);
}

static inline int ui2_win_client_width(void *hwnd) {
	RECT rect;
	if (hwnd == NULL || !GetClientRect((HWND)hwnd, &rect)) return 0;
	return rect.right - rect.left;
}

static inline int ui2_win_client_height(void *hwnd) {
	RECT rect;
	if (hwnd == NULL || !GetClientRect((HWND)hwnd, &rect)) return 0;
	return rect.bottom - rect.top;
}

static inline int ui2_win_text_length(void *hwnd) {
	return hwnd == NULL ? 0 : GetWindowTextLengthW((HWND)hwnd);
}

static inline int ui2_win_get_text(void *hwnd, wchar_t *buffer, int capacity) {
	if (hwnd == NULL || buffer == NULL || capacity <= 0) return 0;
	return GetWindowTextW((HWND)hwnd, buffer, capacity);
}

static inline void ui2_win_set_text(void *hwnd, const wchar_t *text) {
	if (hwnd != NULL) SetWindowTextW((HWND)hwnd, text == NULL ? L"" : text);
}

static inline void ui2_win_set_edit_options(void *hwnd, const wchar_t *placeholder,
		int readonly, int padding_left) {
	if (hwnd == NULL) return;
	SendMessageW((HWND)hwnd, EM_SETREADONLY, readonly ? TRUE : FALSE, 0);
#ifdef EM_SETCUEBANNER
	// Draw cue text in the control subclass. This remains reliable under Wine,
	// where EM_SETCUEBANNER may report support without painting anything.
	SendMessageW((HWND)hwnd, EM_SETCUEBANNER, TRUE, (LPARAM)L"");
#endif
	ui2_win_store_placeholder((HWND)hwnd, placeholder);
	SendMessageW((HWND)hwnd, EM_SETMARGINS, EC_LEFTMARGIN,
		MAKELPARAM(padding_left < 0 ? 0 : padding_left, 0));
	InvalidateRect((HWND)hwnd, NULL, TRUE);
}

static inline int ui2_win_placeholder_matches(void *hwnd, const wchar_t *expected) {
	if (hwnd == NULL) return 0;
	const wchar_t *placeholder = (const wchar_t *)GetPropW(
		(HWND)hwnd, ui2_win_placeholder_property());
	const wchar_t *value = expected == NULL ? L"" : expected;
	return placeholder != NULL && wcscmp(placeholder, value) == 0;
}

static inline uintptr_t ui2_win_widget_style(void *hwnd) {
	return hwnd == NULL ? 0 : (uintptr_t)GetWindowLongPtrW((HWND)hwnd, GWL_STYLE);
}

static inline void ui2_win_get_selection(void *hwnd, unsigned int *start, unsigned int *end) {
	DWORD from = 0;
	DWORD to = 0;
	if (hwnd != NULL) SendMessageW((HWND)hwnd, EM_GETSEL, (WPARAM)&from, (LPARAM)&to);
	if (start != NULL) *start = from;
	if (end != NULL) *end = to;
}

static inline void ui2_win_set_selection(void *hwnd, unsigned int start, unsigned int end,
		int focus) {
	if (hwnd == NULL) return;
	if (focus) SetFocus((HWND)hwnd);
	SendMessageW((HWND)hwnd, EM_SETSEL, start, end);
	SendMessageW((HWND)hwnd, EM_SCROLLCARET, 0, 0);
}

static inline void ui2_win_replace_selection(void *hwnd, const wchar_t *text) {
	if (hwnd != NULL) SendMessageW((HWND)hwnd, EM_REPLACESEL, TRUE,
		(LPARAM)(text == NULL ? L"" : text));
}

static inline void ui2_win_combo_reset(void *hwnd) {
	if (hwnd != NULL) SendMessageW((HWND)hwnd, CB_RESETCONTENT, 0, 0);
}

static inline void ui2_win_combo_add(void *hwnd, const wchar_t *text) {
	if (hwnd != NULL) SendMessageW((HWND)hwnd, CB_ADDSTRING, 0,
		(LPARAM)(text == NULL ? L"" : text));
}

static inline void ui2_win_combo_select_text(void *hwnd, const wchar_t *text) {
	if (hwnd == NULL) return;
	LRESULT index = SendMessageW((HWND)hwnd, CB_FINDSTRINGEXACT, (WPARAM)-1,
		(LPARAM)(text == NULL ? L"" : text));
	SendMessageW((HWND)hwnd, CB_SETCURSEL, index == CB_ERR ? (WPARAM)-1 : (WPARAM)index, 0);
}

// Segoe UI, the Windows UI font, has no dingbats, no arrows and no emoji, so
// GDI paints a .notdef box for a check mark or a smiley. These families cover
// those ranges and keep the Segoe design for the rest of the string.
typedef struct {
	const wchar_t *family;
	int covers_astral;
} ui2_win_font_fallback;

static const ui2_win_font_fallback ui2_win_font_fallbacks[] = {
	{L"Segoe UI Symbol", 0},
	{L"Segoe UI Emoji", 1},
	{L"Segoe UI Historic", 0},
};

#define UI2_WIN_FONT_FALLBACK_COUNT \
	((int)(sizeof(ui2_win_font_fallbacks) / sizeof(ui2_win_font_fallbacks[0])))
// Control text is short; stop scanning long text area documents.
#define UI2_WIN_GLYPH_SCAN_LIMIT 1024

// Missing from some of the leaner Windows headers shipped with C compilers.
#ifndef GGI_MARK_NONEXISTING_GLYPHS
#define GGI_MARK_NONEXISTING_GLYPHS 1
#endif

// Characters that carry no glyph of their own, such as the variation selector
// that follows an emoji, are missing from every font by design.
static inline int ui2_win_glyph_optional(unsigned int unit) {
	if (unit < 0x20 || unit == 0x7f) return 1;
	if (unit >= 0x200b && unit <= 0x200f) return 1;
	if (unit >= 0x202a && unit <= 0x202e) return 1;
	if (unit >= 0xfe00 && unit <= 0xfe0f) return 1;
	return unit == 0xfeff;
}

// Counts the characters of `text` that `font` has no glyph for, or -1 when the
// font is unusable. `family`, when given, rejects a font the GDI mapper
// substituted because the requested family is not installed. `astral` reports
// characters above the BMP: GDI resolves glyphs per UTF-16 unit, so it always
// reports the surrogate halves of an emoji as missing.
static int ui2_win_font_gaps(HFONT font, const wchar_t *text, const wchar_t *family,
		int *astral) {
	if (astral != NULL) *astral = 0;
	if (font == NULL) return -1;
	HDC dc = CreateCompatibleDC(NULL);
	if (dc == NULL) return -1;
	HGDIOBJ previous = SelectObject(dc, font);
	int gaps = 0;
	if (family != NULL) {
		wchar_t face[LF_FACESIZE];
		face[0] = 0;
		if (GetTextFaceW(dc, LF_FACESIZE, face) == 0 || wcscmp(face, family) != 0) gaps = -1;
	}
	int index = 0;
	while (gaps >= 0 && text != NULL && text[index] != 0 && index < UI2_WIN_GLYPH_SCAN_LIMIT) {
		WORD glyphs[64];
		int count = 0;
		while (count < 64 && text[index + count] != 0) count++;
		if (GetGlyphIndicesW(dc, text + index, count, glyphs, GGI_MARK_NONEXISTING_GLYPHS)
			== GDI_ERROR) break;
		for (int i = 0; i < count; i++) {
			unsigned int unit = (unsigned int)text[index + i];
			if (unit >= 0xd800 && unit <= 0xdfff) {
				if (astral != NULL) *astral = 1;
			} else if (!ui2_win_glyph_optional(unit) && glyphs[i] == 0xffff) {
				gaps++;
			}
		}
		index += count;
	}
	SelectObject(dc, previous);
	DeleteDC(dc);
	return gaps;
}

static HFONT ui2_win_font_with_family(const LOGFONTW *base, const wchar_t *family) {
	LOGFONTW description = *base;
	description.lfCharSet = DEFAULT_CHARSET;
	lstrcpynW(description.lfFaceName, family, LF_FACESIZE);
	return CreateFontIndirectW(&description);
}

// Returns the family that can draw all of `text`, or NULL when `font` already
// can. A family is only picked when it has a glyph for every character, so the
// emoji font, which carries no letters, never takes over a mixed string.
static const wchar_t *ui2_win_fallback_family(HFONT font, const wchar_t *text) {
	if (text == NULL || text[0] == 0) return NULL;
	int astral = 0;
	int gaps = ui2_win_font_gaps(font, text, NULL, &astral);
	if (gaps <= 0 && !astral) return NULL;
	LOGFONTW base;
	if (GetObjectW(font, sizeof(base), &base) == 0) return NULL;
	const wchar_t *best = NULL;
	for (int i = 0; i < UI2_WIN_FONT_FALLBACK_COUNT; i++) {
		const ui2_win_font_fallback *candidate = &ui2_win_font_fallbacks[i];
		HFONT probe = ui2_win_font_with_family(&base, candidate->family);
		if (probe == NULL) continue;
		int probe_gaps = ui2_win_font_gaps(probe, text, candidate->family, NULL);
		DeleteObject(probe);
		if (probe_gaps != 0) continue;
		if (!astral || candidate->covers_astral) return candidate->family;
		if (gaps > 0 && best == NULL) best = candidate->family;
	}
	return best;
}

static inline void *ui2_win_create_font(void *hwnd, double point_size,
		const wchar_t *family, int bold, int italic, int underline, int strikeout,
		const wchar_t *text) {
	UINT dpi = 96;
	if (hwnd != NULL) {
		HDC dc = GetDC((HWND)hwnd);
		if (dc != NULL) {
			dpi = (UINT)GetDeviceCaps(dc, LOGPIXELSY);
			ReleaseDC((HWND)hwnd, dc);
		}
	}
	double size = point_size > 0 ? point_size : 15.0;
	int height = -MulDiv((int)(size * 10.0), (int)dpi, 720);
	HFONT font = CreateFontW(height, 0, 0, 0, bold ? FW_BOLD : FW_NORMAL,
		italic ? TRUE : FALSE, underline ? TRUE : FALSE, strikeout ? TRUE : FALSE,
		DEFAULT_CHARSET,
		OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
		DEFAULT_PITCH | FF_DONTCARE,
		family == NULL || family[0] == 0 ? L"Segoe UI" : family);
	if (font == NULL) return NULL;
	const wchar_t *fallback = ui2_win_fallback_family(font, text);
	if (fallback == NULL) return font;
	LOGFONTW base;
	if (GetObjectW(font, sizeof(base), &base) == 0) return font;
	HFONT replacement = ui2_win_font_with_family(&base, fallback);
	if (replacement == NULL) return font;
	DeleteObject(font);
	return replacement;
}

// Reports how many characters of `text` the font cannot draw, so tests can
// assert that a control ended up with a font that covers its text.
static inline int ui2_win_font_missing_glyphs(void *font, const wchar_t *text) {
	return ui2_win_font_gaps((HFONT)font, text, NULL, NULL);
}

static inline void ui2_win_font_family(void *font, wchar_t *buffer, int capacity) {
	if (buffer == NULL || capacity <= 0) return;
	buffer[0] = 0;
	LOGFONTW description;
	if (font == NULL || GetObjectW((HFONT)font, sizeof(description), &description) == 0) return;
	lstrcpynW(buffer, description.lfFaceName, capacity);
}

static inline void *ui2_win_widget_font(void *hwnd) {
	return hwnd == NULL ? NULL : (void *)SendMessageW((HWND)hwnd, WM_GETFONT, 0, 0);
}

static inline void ui2_win_apply_font(void *hwnd, void *font) {
	if (hwnd != NULL && font != NULL) SendMessageW((HWND)hwnd, WM_SETFONT, (WPARAM)font, TRUE);
}

// Fallbacks are shared by every control that borrows them and are never
// destroyed, so a control can keep one for as long as it lives.
#define UI2_WIN_FONT_VARIANT_LIMIT 32

static HFONT ui2_win_font_variant(HFONT base, const wchar_t *family) {
	static LOGFONTW descriptions[UI2_WIN_FONT_VARIANT_LIMIT];
	static HFONT fonts[UI2_WIN_FONT_VARIANT_LIMIT];
	static int count = 0;
	LOGFONTW description;
	if (base == NULL || GetObjectW(base, sizeof(description), &description) == 0) return NULL;
	description.lfCharSet = DEFAULT_CHARSET;
	ZeroMemory(description.lfFaceName, sizeof(description.lfFaceName));
	lstrcpynW(description.lfFaceName, family, LF_FACESIZE);
	for (int i = 0; i < count; i++) {
		if (memcmp(&descriptions[i], &description, sizeof(LOGFONTW)) == 0) return fonts[i];
	}
	if (count == UI2_WIN_FONT_VARIANT_LIMIT) return NULL;
	HFONT font = CreateFontIndirectW(&description);
	if (font == NULL) return NULL;
	descriptions[count] = description;
	fonts[count] = font;
	count++;
	return font;
}

// Keeps the native system font on controls that render with the platform look,
// switching to a fallback family only for text the message font cannot draw.
static inline void ui2_win_apply_text_font(void *hwnd_ptr, const wchar_t *text) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (hwnd == NULL) return;
	HFONT font = ui2_win_system_font();
	const wchar_t *family = ui2_win_fallback_family(font, text);
	if (family != NULL) {
		HFONT variant = ui2_win_font_variant(font, family);
		if (variant != NULL) font = variant;
	}
	if ((HFONT)SendMessageW(hwnd, WM_GETFONT, 0, 0) != font) {
		SendMessageW(hwnd, WM_SETFONT, (WPARAM)font, TRUE);
	}
}

// Text typed or pasted into an edit control never passes through the element
// tree, so the control picks its own fallback family for what it now holds.
static inline void ui2_win_refresh_text_font(HWND hwnd) {
	int length = GetWindowTextLengthW(hwnd);
	if (length <= 0 || length > UI2_WIN_GLYPH_SCAN_LIMIT) return;
	wchar_t text[UI2_WIN_GLYPH_SCAN_LIMIT + 1];
	if (GetWindowTextW(hwnd, text, length + 1) <= 0) return;
	HFONT base = (HFONT)SendMessageW(hwnd, WM_GETFONT, 0, 0);
	if (base == NULL) base = ui2_win_system_font();
	const wchar_t *family = ui2_win_fallback_family(base, text);
	if (family == NULL) return;
	HFONT variant = ui2_win_font_variant(base, family);
	if (variant != NULL && variant != base) {
		SendMessageW(hwnd, WM_SETFONT, (WPARAM)variant, TRUE);
	}
}

static inline void *ui2_win_create_brush(unsigned int color) {
	return CreateSolidBrush(ui2_win_color(color));
}

static inline void ui2_win_delete_object(void *object) {
	if (object != NULL) DeleteObject((HGDIOBJ)object);
}

static inline intptr_t ui2_win_apply_control_colors(void *dc_ptr, unsigned int foreground,
		unsigned int background, int transparent, void *brush) {
	HDC dc = (HDC)dc_ptr;
	if (dc == NULL) return 0;
	SetTextColor(dc, ui2_win_color(foreground));
	if (transparent) {
		SetBkMode(dc, TRANSPARENT);
		return (intptr_t)GetStockObject(HOLLOW_BRUSH);
	}
	SetBkMode(dc, OPAQUE);
	SetBkColor(dc, ui2_win_color(background));
	return (intptr_t)brush;
}

static inline void ui2_win_paint_background(void *hwnd_ptr, unsigned int background,
		double radius, int transparent) {
	HWND hwnd = (HWND)hwnd_ptr;
	PAINTSTRUCT paint;
	HDC dc = BeginPaint(hwnd, &paint);
	if (dc != NULL && !transparent) {
		RECT rect;
		GetClientRect(hwnd, &rect);
		HBRUSH brush = CreateSolidBrush(ui2_win_color(background));
		if (radius > 0.5) {
			HPEN pen = CreatePen(PS_NULL, 0, ui2_win_color(background));
			HGDIOBJ old_brush = SelectObject(dc, brush);
			HGDIOBJ old_pen = SelectObject(dc, pen);
			int diameter = (int)(radius * 2.0);
			RoundRect(dc, rect.left, rect.top, rect.right, rect.bottom, diameter, diameter);
			SelectObject(dc, old_pen);
			SelectObject(dc, old_brush);
			DeleteObject(pen);
		} else {
			FillRect(dc, &rect, brush);
		}
		DeleteObject(brush);
	}
	EndPaint(hwnd, &paint);
}

static inline void ui2_win_invalidate(void *hwnd) {
	if (hwnd != NULL) InvalidateRect((HWND)hwnd, NULL, TRUE);
}

static inline void ui2_win_invalidate_parent(void *hwnd) {
	if (hwnd != NULL) {
		HWND parent = GetParent((HWND)hwnd);
		if (parent != NULL) InvalidateRect(parent, NULL, TRUE);
	}
}

static inline void *ui2_win_set_bitmap(void *hwnd_ptr, const wchar_t *path,
		int width, int height) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (hwnd == NULL) return NULL;
	HBITMAP image = NULL;
	if (path != NULL && path[0] != 0) {
		image = (HBITMAP)LoadImageW(NULL, path, IMAGE_BITMAP,
			width > 0 ? width : 0, height > 0 ? height : 0,
			LR_LOADFROMFILE | LR_CREATEDIBSECTION);
	}
	HBITMAP old = (HBITMAP)SendMessageW(hwnd, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)image);
	if (old != NULL && old != image) DeleteObject(old);
	return image;
}

static inline void ui2_win_clear_bitmap(void *hwnd_ptr) {
	HWND hwnd = (HWND)hwnd_ptr;
	if (hwnd == NULL) return;
	HBITMAP old = (HBITMAP)SendMessageW(hwnd, STM_SETIMAGE, IMAGE_BITMAP, 0);
	if (old != NULL) DeleteObject(old);
}

static inline int ui2_win_set_scroll(void *hwnd_ptr, int content_height, int position) {
	HWND hwnd = (HWND)hwnd_ptr;
	RECT rect;
	GetClientRect(hwnd, &rect);
	SCROLLINFO info;
	ZeroMemory(&info, sizeof(info));
	info.cbSize = sizeof(info);
	info.fMask = SIF_RANGE | SIF_PAGE | SIF_POS;
	info.nMin = 0;
	info.nMax = content_height > 0 ? content_height - 1 : 0;
	info.nPage = (UINT)(rect.bottom - rect.top);
	info.nPos = position;
	SetScrollInfo(hwnd, SB_VERT, &info, TRUE);
	info.fMask = SIF_POS;
	GetScrollInfo(hwnd, SB_VERT, &info);
	return info.nPos;
}

static inline int ui2_win_scroll_message(void *hwnd_ptr, uintptr_t wparam) {
	HWND hwnd = (HWND)hwnd_ptr;
	SCROLLINFO info;
	ZeroMemory(&info, sizeof(info));
	info.cbSize = sizeof(info);
	info.fMask = SIF_ALL;
	GetScrollInfo(hwnd, SB_VERT, &info);
	int position = info.nPos;
	switch (LOWORD(wparam)) {
	case SB_TOP: position = info.nMin; break;
	case SB_BOTTOM: position = info.nMax; break;
	case SB_LINEUP: position -= 24; break;
	case SB_LINEDOWN: position += 24; break;
	case SB_PAGEUP: position -= (int)info.nPage; break;
	case SB_PAGEDOWN: position += (int)info.nPage; break;
	case SB_THUMBTRACK:
	case SB_THUMBPOSITION: position = info.nTrackPos; break;
	default: break;
	}
	info.fMask = SIF_POS;
	info.nPos = position;
	SetScrollInfo(hwnd, SB_VERT, &info, TRUE);
	GetScrollInfo(hwnd, SB_VERT, &info);
	return info.nPos;
}

static inline int ui2_win_scroll_wheel(void *hwnd_ptr, uintptr_t wparam) {
	HWND hwnd = (HWND)hwnd_ptr;
	SCROLLINFO info;
	ZeroMemory(&info, sizeof(info));
	info.cbSize = sizeof(info);
	info.fMask = SIF_ALL;
	GetScrollInfo(hwnd, SB_VERT, &info);
	int delta = GET_WHEEL_DELTA_WPARAM(wparam);
	info.fMask = SIF_POS;
	info.nPos -= (delta / WHEEL_DELTA) * 48;
	SetScrollInfo(hwnd, SB_VERT, &info, TRUE);
	GetScrollInfo(hwnd, SB_VERT, &info);
	return info.nPos;
}

static inline int ui2_win_scroll_to_rect(void *hwnd_ptr, int top, int bottom) {
	HWND hwnd = (HWND)hwnd_ptr;
	SCROLLINFO info;
	ZeroMemory(&info, sizeof(info));
	info.cbSize = sizeof(info);
	info.fMask = SIF_ALL;
	GetScrollInfo(hwnd, SB_VERT, &info);
	int position = info.nPos;
	if (top < position) position = top;
	if (bottom > position + (int)info.nPage) position = bottom - (int)info.nPage;
	info.fMask = SIF_POS;
	info.nPos = position;
	SetScrollInfo(hwnd, SB_VERT, &info, TRUE);
	GetScrollInfo(hwnd, SB_VERT, &info);
	return info.nPos;
}

static inline void ui2_win_capture_mouse(void *hwnd) {
	if (hwnd != NULL) SetCapture((HWND)hwnd);
}

static inline void ui2_win_release_mouse(void) {
	ReleaseCapture();
}

static inline unsigned long long ui2_win_ticks(void) {
	return GetTickCount64();
}

static inline void ui2_win_point_to_root(void *hwnd_ptr, void *root_ptr, int *x, int *y) {
	POINT point;
	point.x = x == NULL ? 0 : *x;
	point.y = y == NULL ? 0 : *y;
	MapWindowPoints((HWND)hwnd_ptr, (HWND)root_ptr, &point, 1);
	if (x != NULL) *x = point.x;
	if (y != NULL) *y = point.y;
}

static inline void *ui2_win_menu_create(void) {
	return CreatePopupMenu();
}

static inline void ui2_win_menu_add(void *menu, unsigned int command, const wchar_t *title,
		int enabled) {
	if (menu != NULL) AppendMenuW((HMENU)menu, MF_STRING | (enabled ? 0 : MF_GRAYED),
		command, title == NULL ? L"" : title);
}

static inline unsigned int ui2_win_menu_track(void *menu, void *hwnd, int x, int y) {
	if (menu == NULL || hwnd == NULL) return 0;
	if (x == -1 && y == -1) {
		RECT rect;
		GetWindowRect((HWND)hwnd, &rect);
		x = rect.left + (rect.right - rect.left) / 2;
		y = rect.top + (rect.bottom - rect.top) / 2;
	}
	return TrackPopupMenu((HMENU)menu, TPM_RETURNCMD | TPM_RIGHTBUTTON,
		x, y, 0, (HWND)hwnd, NULL);
}

static inline void ui2_win_menu_destroy(void *menu) {
	if (menu != NULL) DestroyMenu((HMENU)menu);
}

static inline unsigned int ui2_win_drop_count(void *drop) {
	return DragQueryFileW((HDROP)drop, 0xffffffff, NULL, 0);
}

static inline unsigned int ui2_win_drop_path_length(void *drop, unsigned int index) {
	return DragQueryFileW((HDROP)drop, index, NULL, 0);
}

static inline void ui2_win_drop_path(void *drop, unsigned int index, wchar_t *buffer,
		unsigned int capacity) {
	DragQueryFileW((HDROP)drop, index, buffer, capacity);
}

static inline void ui2_win_drop_point(void *drop, int *x, int *y) {
	POINT point;
	point.x = 0;
	point.y = 0;
	DragQueryPoint((HDROP)drop, &point);
	if (x != NULL) *x = point.x;
	if (y != NULL) *y = point.y;
}

static inline void ui2_win_drop_finish(void *drop) {
	DragFinish((HDROP)drop);
}

static inline int ui2_win_key_down(int virtual_key) {
	return (GetKeyState(virtual_key) & 0x8000) != 0;
}

#endif
