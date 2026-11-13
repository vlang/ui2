#ifndef UI2_PLATFORM_WINDOWS_H
#define UI2_PLATFORM_WINDOWS_H

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
#include <shellapi.h>

// ui2_win_open_url opens a validated http(s) or mailto URL with its default
// handler. ShellExecuteW answers above 32 when it took the URL.
static inline int ui2_win_open_url(const wchar_t *url) {
	if (url == NULL || url[0] == 0) return 0;
	HINSTANCE opened = ShellExecuteW(NULL, L"open", url, NULL, NULL, SW_SHOWNORMAL);
	return (INT_PTR)opened > 32;
}

#endif
