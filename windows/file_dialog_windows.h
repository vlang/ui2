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

static inline size_t ui2_win_file_dialog_append(wchar_t *output, size_t capacity,
		size_t used, const wchar_t *value) {
	if (value == NULL || capacity == 0 || used >= capacity) return used;
	while (*value != 0 && used + 1 < capacity) output[used++] = *value++;
	output[used] = 0;
	return used;
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

static inline int ui2_win_file_dialog_folder(wchar_t *output, unsigned int capacity,
		const wchar_t *title) {
	BROWSEINFOW info;
	ZeroMemory(&info, sizeof(info));
	info.hwndOwner = ui2_win_file_dialog_owner();
	info.lpszTitle = title == NULL ? L"" : title;
	info.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
	PIDLIST_ABSOLUTE item = SHBrowseForFolderW(&info);
	if (item == NULL) return 0;
	BOOL ok = SHGetPathFromIDListW(item, output);
	CoTaskMemFree(item);
	return ok && output[0] != 0;
}

// ui2_win_file_dialog writes selected paths as newline-separated UTF-16. A
// newline is not legal in Windows path components, so it is an unambiguous
// bridge representation for V while keeping all native selection parsing here.
static inline int ui2_win_file_dialog(wchar_t *output, unsigned int output_capacity,
		const wchar_t *title, const wchar_t *directory, const wchar_t *filename,
		const wchar_t *filter_spec, int kind, int multiple) {
	if (output == NULL || output_capacity < 2) return 0;
	output[0] = 0;
	if (kind == UI2_FILE_DIALOG_FOLDER) return ui2_win_file_dialog_folder(output, output_capacity, title);

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
	if (kind == UI2_FILE_DIALOG_OPEN && multiple) info.Flags |= OFN_ALLOWMULTISELECT;
	if (!(kind == UI2_FILE_DIALOG_SAVE ? GetSaveFileNameW(&info) : GetOpenFileNameW(&info))) return 0;

	wchar_t *next = selected + wcslen(selected) + 1;
	if (*next == 0) {
		ui2_win_file_dialog_append(output, output_capacity, 0, selected);
		return output[0] != 0;
	}
	size_t used = 0;
	const size_t folder_length = wcslen(selected);
	while (*next != 0) {
		if (used > 0 && used + 1 < output_capacity) output[used++] = L'\n';
		used = ui2_win_file_dialog_append(output, output_capacity, used, selected);
		if (folder_length > 0 && selected[folder_length - 1] != L'\\' && used + 1 < output_capacity) output[used++] = L'\\';
		used = ui2_win_file_dialog_append(output, output_capacity, used, next);
		next += wcslen(next) + 1;
	}
	return output[0] != 0;
}

#endif
