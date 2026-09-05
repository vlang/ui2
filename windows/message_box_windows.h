#ifndef UI2_MESSAGE_BOX_WINDOWS_H
#define UI2_MESSAGE_BOX_WINDOWS_H

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

// ui2_win_message_box shows the standard Win32 alert. It owns the box with the
// calling thread's active window so the dialog is centred on the app and stays
// modal to it; without one it falls back to task-modal behaviour.
static inline int ui2_win_message_box(const wchar_t *title, const wchar_t *text,
		unsigned int flags) {
	HWND owner = GetActiveWindow();
	if (owner == NULL) owner = GetForegroundWindow();
	UINT resolved = (UINT)flags | MB_SETFOREGROUND;
	if (owner == NULL) resolved |= MB_TASKMODAL;
	return MessageBoxW(owner, text == NULL ? L"" : text, title == NULL ? L"" : title,
		resolved);
}

#endif
