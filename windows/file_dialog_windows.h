#ifndef UI2_FILE_DIALOG_WINDOWS_H
#define UI2_FILE_DIALOG_WINDOWS_H

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

#include <windows.h>
#include <commdlg.h>
#include <shlobj.h>
#include <wchar.h>

enum {
	UI2_FILE_DIALOG_OPEN = 0,
	UI2_FILE_DIALOG_SAVE = 1,
	UI2_FILE_DIALOG_FOLDER = 2
};

static inline HWND ui2_win_file_dialog_owner(void) {
	HWND owner = GetActiveWindow();
	return owner == NULL ? GetForegroundWindow() : owner;
}

static inline int ui2_win_file_dialog_append(wchar_t *output, size_t capacity,
		size_t *used, const wchar_t *value) {
	size_t value_length = value == NULL ? 0 : wcslen(value);
	if (capacity == 0 || *used + value_length >= capacity) return 0;
	if (value_length > 0) wmemcpy(output + *used, value, value_length);
	*used += value_length;
	output[*used] = 0;
	return 1;
}

static inline void ui2_win_file_dialog_filter(wchar_t *output, size_t capacity,
		const wchar_t *spec) {
	size_t index = 0;
	if (spec != NULL) {
		while (*spec != 0 && index + 2 < capacity) {
			output[index++] = *spec == L'|' ? 0 : *spec;
			spec++;
		}
	}
	if (index == 0) {
		const wchar_t fallback[] = L"All files\0*.*\0\0";
		for (size_t i = 0; i < sizeof(fallback) / sizeof(fallback[0]) && i < capacity; i++) output[i] = fallback[i];
		return;
	}
	output[index++] = 0;
	output[index] = 0;
}

static int CALLBACK ui2_win_file_dialog_folder_callback(HWND window, UINT message,
		LPARAM lparam, LPARAM data) {
	if (message == BFFM_INITIALIZED && data != 0) {
		SendMessageW(window, BFFM_SETSELECTIONW, TRUE, data);
	}
	return 0;
}

static inline int ui2_win_file_dialog_folder(wchar_t *output, unsigned int capacity,
		const wchar_t *title, const wchar_t *directory) {
	HRESULT com_result = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
	BROWSEINFOW info;
	ZeroMemory(&info, sizeof(info));
	info.hwndOwner = ui2_win_file_dialog_owner();
	info.lpszTitle = title == NULL ? L"" : title;
	info.ulFlags = BIF_RETURNONLYFSDIRS;
	if (SUCCEEDED(com_result)) info.ulFlags |= BIF_NEWDIALOGSTYLE;
	if (directory != NULL && directory[0] != 0) {
		info.lpfn = ui2_win_file_dialog_folder_callback;
		info.lParam = (LPARAM)directory;
	}
	PIDLIST_ABSOLUTE item = SHBrowseForFolderW(&info);
	BOOL ok = item != NULL && SHGetPathFromIDListW(item, output);
	if (item != NULL) CoTaskMemFree(item);
	if (SUCCEEDED(com_result)) CoUninitialize();
	return ok && output[0] != 0;
}

// ui2_win_file_dialog writes selected paths as newline-separated UTF-16. A
// multi-select result keeps Windows' compact folder-plus-filenames form; the
// V bridge expands that form without risking a truncated final path.
static inline int ui2_win_file_dialog(wchar_t *output, unsigned int output_capacity,
		const wchar_t *title, const wchar_t *directory, const wchar_t *filename,
		const wchar_t *filter_spec, int kind, int multiple) {
	if (output == NULL || output_capacity < 2) return 0;
	output[0] = 0;
	if (kind == UI2_FILE_DIALOG_FOLDER) return ui2_win_file_dialog_folder(output, output_capacity, title, directory);

	wchar_t selected[32768];
	wchar_t filter[8192];
	ZeroMemory(selected, sizeof(selected));
	ZeroMemory(filter, sizeof(filter));
	if (filename != NULL) wcsncpy(selected, filename, (sizeof(selected) / sizeof(selected[0])) - 1);
	ui2_win_file_dialog_filter(filter, sizeof(filter) / sizeof(filter[0]), filter_spec);

	OPENFILENAMEW info;
	ZeroMemory(&info, sizeof(info));
	info.lStructSize = sizeof(info);
	info.hwndOwner = ui2_win_file_dialog_owner();
	info.lpstrFilter = filter;
	info.lpstrFile = selected;
	info.nMaxFile = sizeof(selected) / sizeof(selected[0]);
	info.lpstrInitialDir = directory != NULL && directory[0] != 0 ? directory : NULL;
	info.lpstrTitle = title != NULL && title[0] != 0 ? title : NULL;
	info.Flags = OFN_EXPLORER | OFN_NOCHANGEDIR | OFN_PATHMUSTEXIST;
	if (kind == UI2_FILE_DIALOG_OPEN) info.Flags |= OFN_FILEMUSTEXIST;
	if (kind == UI2_FILE_DIALOG_SAVE) info.Flags |= OFN_OVERWRITEPROMPT;
	if (kind == UI2_FILE_DIALOG_OPEN && multiple) info.Flags |= OFN_ALLOWMULTISELECT;
	if (!(kind == UI2_FILE_DIALOG_SAVE ? GetSaveFileNameW(&info) : GetOpenFileNameW(&info))) return 0;

	wchar_t *next = selected + wcslen(selected) + 1;
	if (*next == 0) {
		size_t used = 0;
		return ui2_win_file_dialog_append(output, output_capacity, &used, selected) && output[0] != 0;
	}
	size_t used = 0;
	if (!ui2_win_file_dialog_append(output, output_capacity, &used, selected)) return 0;
	while (*next != 0) {
		if (used + 1 >= output_capacity) return 0;
		output[used++] = L'\n';
		output[used] = 0;
		if (!ui2_win_file_dialog_append(output, output_capacity, &used, next)) return 0;
		next += wcslen(next) + 1;
	}
	return output[0] != 0;
}

#endif
