// Shared MCI + GDI helpers for ui2 media on Windows (winmm/gdi32 only).
//
// Playback, recording and screenshots all go through APIs that ship with
// Windows itself: MCI (winmm.dll) for audio/video, GDI for the screen grab.
// No third-party media library is ever needed.
#ifndef UI2_MEDIA_WINDOWS_H
#define UI2_MEDIA_WINDOWS_H

#include <windows.h>
#include <mmsystem.h>
#include <stdio.h>

static inline unsigned int ui2_mci_send(const wchar_t *command, wchar_t *result,
		unsigned int result_len) {
	return (unsigned int)mciSendStringW(command, result, result_len, NULL);
}

static inline int ui2_mci_error_text(unsigned int code, wchar_t *text, unsigned int text_len) {
	return mciGetErrorStringW((MCIERROR)code, text, text_len) ? 1 : 0;
}

// ui2_media_screenshot saves the primary display as a BMP. BMP needs no
// encoder: headers plus the raw DIB bits straight out of GDI.
static inline int ui2_media_screenshot(const wchar_t *path) {
	if (path == NULL || path[0] == 0) return 0;
	int width = GetSystemMetrics(SM_CXSCREEN);
	int height = GetSystemMetrics(SM_CYSCREEN);
	if (width <= 0 || height <= 0) return 0;
	HDC screen = GetDC(NULL);
	if (screen == NULL) return 0;
	HDC memory = CreateCompatibleDC(screen);
	if (memory == NULL) {
		ReleaseDC(NULL, screen);
		return 0;
	}
	HBITMAP bitmap = CreateCompatibleBitmap(screen, width, height);
	if (bitmap == NULL) {
		DeleteDC(memory);
		ReleaseDC(NULL, screen);
		return 0;
	}
	HGDIOBJ previous = SelectObject(memory, bitmap);
	int stride = ((width * 3 + 3) / 4) * 4;
	unsigned long image_size = (unsigned long)stride * (unsigned long)height;
	unsigned char *bits = (unsigned char *)HeapAlloc(GetProcessHeap(), 0, image_size);
	int ok = 0;
	if (bits != NULL) {
		BITMAPINFO info;
		ZeroMemory(&info, sizeof(info));
		info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
		info.bmiHeader.biWidth = width;
		info.bmiHeader.biHeight = -height;
		info.bmiHeader.biPlanes = 1;
		info.bmiHeader.biBitCount = 24;
		info.bmiHeader.biCompression = BI_RGB;
		BitBlt(memory, 0, 0, width, height, screen, 0, 0, SRCCOPY);
		if (GetDIBits(memory, bitmap, 0, (UINT)height, bits, &info, DIB_RGB_COLORS) != 0) {
			FILE *file = _wfopen(path, L"wb");
			if (file != NULL) {
				BITMAPFILEHEADER head;
				ZeroMemory(&head, sizeof(head));
				head.bfType = 0x4d42;
				head.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
				head.bfSize = head.bfOffBits + image_size;
				BITMAPINFOHEADER body = info.bmiHeader;
				body.biHeight = height;
				ok = fwrite(&head, 1, sizeof(head), file) == sizeof(head)
					&& fwrite(&body, 1, sizeof(body), file) == sizeof(body)
					&& fwrite(bits, 1, image_size, file) == image_size;
				fclose(file);
				if (!ok) DeleteFileW(path);
			}
		}
		HeapFree(GetProcessHeap(), 0, bits);
	}
	SelectObject(memory, previous);
	DeleteObject(bitmap);
	DeleteDC(memory);
	ReleaseDC(NULL, screen);
	return ok;
}

#endif
