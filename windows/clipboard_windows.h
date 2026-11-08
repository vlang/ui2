#ifndef UI2_CLIPBOARD_WINDOWS_H
#define UI2_CLIPBOARD_WINDOWS_H

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

#include <windows.h>
#include <stdlib.h>
#include <string.h>

// SetClipboardData fails when the clipboard was opened without an owner, and
// this file serves custom-rendered windows too, which have no HWND it can
// reach. A message-only window, made once, owns what ui2 copies.
static HWND ui2_win_clipboard_owner(void) {
	static HWND owner = NULL;
	if (owner == NULL) {
		owner = CreateWindowExW(0, L"STATIC", L"ui2 clipboard", 0, 0, 0, 0, 0,
			HWND_MESSAGE, NULL, GetModuleHandleW(NULL), NULL);
	}
	return owner;
}

static int ui2_win_set_clipboard_text(const wchar_t *text, int units) {
	if (text == NULL || units < 0) return 0;
	HWND owner = ui2_win_clipboard_owner();
	if (owner == NULL || !OpenClipboard(owner)) return 0;
	EmptyClipboard();
	HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, ((size_t)units + 1) * sizeof(wchar_t));
	if (memory == NULL) {
		CloseClipboard();
		return 0;
	}
	wchar_t *copy = (wchar_t *)GlobalLock(memory);
	if (copy == NULL) {
		GlobalFree(memory);
		CloseClipboard();
		return 0;
	}
	memcpy(copy, text, (size_t)units * sizeof(wchar_t));
	copy[units] = 0;
	GlobalUnlock(memory);
	if (SetClipboardData(CF_UNICODETEXT, memory) == NULL) {
		GlobalFree(memory);
		CloseClipboard();
		return 0;
	}
	// The clipboard owns the memory once SetClipboardData has taken it.
	CloseClipboard();
	return 1;
}

// Returns a malloc'd copy of the clipboard's text, or NULL when it has none.
static wchar_t *ui2_win_clipboard_text(void) {
	if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) return NULL;
	if (!OpenClipboard(ui2_win_clipboard_owner())) return NULL;
	wchar_t *result = NULL;
	HANDLE data = GetClipboardData(CF_UNICODETEXT);
	if (data != NULL) {
		const wchar_t *text = (const wchar_t *)GlobalLock(data);
		if (text != NULL) {
			size_t units = wcslen(text);
			result = (wchar_t *)malloc((units + 1) * sizeof(wchar_t));
			if (result != NULL) memcpy(result, text, (units + 1) * sizeof(wchar_t));
			GlobalUnlock(data);
		}
	}
	CloseClipboard();
	return result;
}

#endif
