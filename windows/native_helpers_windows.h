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

static inline int ui2_win_register_classes(void) {
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

static inline DWORD ui2_win_label_style(int alignment) {
	if (alignment == 1) return SS_CENTER;
	if (alignment == 2) return SS_RIGHT;
	return SS_LEFT;
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
		style |= BS_PUSHBUTTON | BS_MULTILINE | BS_CENTER | WS_TABSTOP;
		break;
	case UI2_WIN_CHECKBOX:
		class_name = L"BUTTON";
		style |= BS_AUTOCHECKBOX | BS_MULTILINE | BS_LEFT | WS_TABSTOP;
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
		SendMessageW(hwnd, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE);
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
	SendMessageW((HWND)hwnd, EM_SETCUEBANNER, TRUE,
		(LPARAM)(placeholder == NULL ? L"" : placeholder));
#endif
	SendMessageW((HWND)hwnd, EM_SETMARGINS, EC_LEFTMARGIN,
		MAKELPARAM(padding_left < 0 ? 0 : padding_left, 0));
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

static inline void *ui2_win_create_font(void *hwnd, double point_size,
		const wchar_t *family, int bold, int italic, int underline, int strikeout) {
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
	return CreateFontW(height, 0, 0, 0, bold ? FW_BOLD : FW_NORMAL,
		italic ? TRUE : FALSE, underline ? TRUE : FALSE, strikeout ? TRUE : FALSE,
		DEFAULT_CHARSET,
		OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
		DEFAULT_PITCH | FF_DONTCARE,
		family == NULL || family[0] == 0 ? L"Segoe UI" : family);
}

static inline void ui2_win_apply_font(void *hwnd, void *font) {
	if (hwnd != NULL && font != NULL) SendMessageW((HWND)hwnd, WM_SETFONT, (WPARAM)font, TRUE);
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
