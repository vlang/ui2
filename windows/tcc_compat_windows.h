/* windows/tcc_compat_windows.h -- the Win32 declarations ui2's Windows helpers take
 * from commctrl.h, commdlg.h, shlobj.h and oleacc.h, for V's bundled tcc, whose
 * winapi header set carries none of those four (it has windows.h, windowsx.h,
 * shellapi.h, oleauto.h, oaidl.h, objbase.h and unknwn.h; the tray icon comes
 * from its own shellapi.h, included below). Read only under
 * __TINYC__; every other compiler reads the real headers through the helpers'
 * own includes. The structures are laid out as the SDK lays them out and the
 * constants are the SDK's values (taken from mingw-w64's headers, 2026-10-28);
 * only what the helpers use is declared, so a new use of one of those four
 * headers adds its names here, or tcc says "undeclared" and the build falls back
 * to another C compiler, as it did for every ui2 build before this header.
 *
 * IAccessible's vtable is spelled whole, because the helpers call slots in the
 * middle of it (get_accName and the rest sit after IDispatch's four); the slots
 * the helpers never call are plain pointers that keep the layout. */
#ifndef UI2_TCC_COMPAT_WINDOWS_H
#define UI2_TCC_COMPAT_WINDOWS_H
#ifdef __TINYC__

#include <windows.h>
#include <objbase.h>
#include <unknwn.h>
#include <oaidl.h>
#include <oleauto.h>

/* ---- winuser.h: newer than tcc's copy ---- */
#ifndef SM_CXPADDEDBORDER
#define SM_CXPADDEDBORDER 92
#endif
#ifndef WM_MOUSEHWHEEL
#define WM_MOUSEHWHEEL 0x020e
#endif

/* ---- shellapi.h ----
 * tcc's shellapi.h (copied from mingw-w64) carries the tray icon: the
 * NOTIFYICONDATAW structure, the NIM_/NIF_ flags and Shell_NotifyIconW. It is
 * included here so the wrapper below sees those types; the fallbacks cover a
 * tcc whose shellapi.h predates them. The struct must not be redefined
 * unconditionally: a second definition of the tag, even identical, is a tcc
 * error ("struct/union/enum already defined") the moment shellapi.h is
 * included too. */
#include <shellapi.h>
#ifndef NOTIFYICONDATAW_V1_SIZE
typedef struct _NOTIFYICONDATAW {
	DWORD cbSize;
	HWND hWnd;
	UINT uID;
	UINT uFlags;
	UINT uCallbackMessage;
	HICON hIcon;
	WCHAR szTip[128];
	DWORD dwState;
	DWORD dwStateMask;
	WCHAR szInfo[256];
	union {
		UINT uTimeout;
		UINT uVersion;
	};
	WCHAR szInfoTitle[64];
	DWORD dwInfoFlags;
	GUID guidItem;
	HICON hBalloonIcon;
} NOTIFYICONDATAW, *PNOTIFYICONDATAW;
#endif
#ifndef NIM_ADD
#define NIM_ADD 0x0
#define NIM_MODIFY 0x1
#define NIM_DELETE 0x2
#endif
#ifndef NIF_MESSAGE
#define NIF_MESSAGE 0x1
#define NIF_ICON 0x2
#define NIF_TIP 0x4
#endif

/* ---- commctrl.h ---- */
#define TBS_HORZ 0x0
#define TBS_VERT 0x2
typedef struct tagINITCOMMONCONTROLSEX {
	DWORD dwSize;
	DWORD dwICC;
} INITCOMMONCONTROLSEX, *LPINITCOMMONCONTROLSEX;
#define ICC_WIN95_CLASSES 0xff
#define ICC_STANDARD_CLASSES 0x4000
WINBOOL WINAPI InitCommonControlsEx(const INITCOMMONCONTROLSEX *);

#define TRACKBAR_CLASSW L"msctls_trackbar32"
#define TBM_GETPOS (WM_USER)
#define TBM_SETPOS (WM_USER + 5)
#define TBM_SETRANGEMIN (WM_USER + 7)
#define TBM_SETRANGEMAX (WM_USER + 8)
#define TBM_SETPAGESIZE (WM_USER + 21)

#define TOOLTIPS_CLASSW L"tooltips_class32"
#define TTS_ALWAYSTIP 0x1
#define TTS_NOPREFIX 0x2
#define TTF_IDISHWND 0x1
#define TTF_SUBCLASS 0x10
#define TTM_SETMAXTIPWIDTH (WM_USER + 24)
#define TTM_ADDTOOLW (WM_USER + 50)
typedef struct tagTOOLINFOW {
	UINT cbSize;
	UINT uFlags;
	HWND hwnd;
	UINT_PTR uId;
	RECT rect;
	HINSTANCE hinst;
	LPWSTR lpszText;
	LPARAM lParam;
	void *lpReserved;
} TOOLINFOW, *LPTOOLINFOW;

#define ECM_FIRST 0x1500
#define EM_SETCUEBANNER (ECM_FIRST + 1)

typedef LRESULT (CALLBACK *SUBCLASSPROC)(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);
WINBOOL WINAPI SetWindowSubclass(HWND, SUBCLASSPROC, UINT_PTR, DWORD_PTR);
WINBOOL WINAPI RemoveWindowSubclass(HWND, SUBCLASSPROC, UINT_PTR);
LRESULT WINAPI DefSubclassProc(HWND, UINT, WPARAM, LPARAM);

/* ---- commdlg.h ---- */
typedef UINT_PTR (CALLBACK *LPOFNHOOKPROC)(HWND, UINT, WPARAM, LPARAM);
typedef struct tagOFNW {
	DWORD lStructSize;
	HWND hwndOwner;
	HINSTANCE hInstance;
	LPCWSTR lpstrFilter;
	LPWSTR lpstrCustomFilter;
	DWORD nMaxCustFilter;
	DWORD nFilterIndex;
	LPWSTR lpstrFile;
	DWORD nMaxFile;
	LPWSTR lpstrFileTitle;
	DWORD nMaxFileTitle;
	LPCWSTR lpstrInitialDir;
	LPCWSTR lpstrTitle;
	DWORD Flags;
	WORD nFileOffset;
	WORD nFileExtension;
	LPCWSTR lpstrDefExt;
	LPARAM lCustData;
	LPOFNHOOKPROC lpfnHook;
	LPCWSTR lpTemplateName;
	void *pvReserved;
	DWORD dwReserved;
	DWORD FlagsEx;
} OPENFILENAMEW, *LPOPENFILENAMEW;
#define OFN_OVERWRITEPROMPT 0x2
#define OFN_NOCHANGEDIR 0x8
#define OFN_ALLOWMULTISELECT 0x200
#define OFN_PATHMUSTEXIST 0x800
#define OFN_FILEMUSTEXIST 0x1000
#define OFN_EXPLORER 0x80000
WINBOOL WINAPI GetOpenFileNameW(LPOPENFILENAMEW);
WINBOOL WINAPI GetSaveFileNameW(LPOPENFILENAMEW);

/* ---- shlobj.h (with shtypes.h's item-id lists, opaque here) ---- */
typedef struct _ITEMIDLIST ITEMIDLIST_ABSOLUTE;
typedef ITEMIDLIST_ABSOLUTE *PIDLIST_ABSOLUTE;
typedef const ITEMIDLIST_ABSOLUTE *PCIDLIST_ABSOLUTE;
typedef int (CALLBACK *BFFCALLBACK)(HWND, UINT, LPARAM, LPARAM);
typedef struct _browseinfoW {
	HWND hwndOwner;
	PCIDLIST_ABSOLUTE pidlRoot;
	LPWSTR pszDisplayName;
	LPCWSTR lpszTitle;
	UINT ulFlags;
	BFFCALLBACK lpfn;
	LPARAM lParam;
	int iImage;
} BROWSEINFOW, *LPBROWSEINFOW;
#define BIF_RETURNONLYFSDIRS 0x1
#define BIF_NEWDIALOGSTYLE 0x40
#define BFFM_INITIALIZED 1
#define BFFM_SETSELECTIONW (WM_USER + 103)
PIDLIST_ABSOLUTE WINAPI SHBrowseForFolderW(LPBROWSEINFOW);
WINBOOL WINAPI SHGetPathFromIDListW(PCIDLIST_ABSOLUTE, LPWSTR);

/* ---- oleacc.h ---- */
#ifndef ROLE_SYSTEM_PUSHBUTTON
#define ROLE_SYSTEM_PUSHBUTTON 0x2b
#endif
#ifndef STATE_SYSTEM_UNAVAILABLE
#define STATE_SYSTEM_UNAVAILABLE 0x1
#endif
#ifndef STATE_SYSTEM_FOCUSABLE
#define STATE_SYSTEM_FOCUSABLE 0x100000
#endif
#ifndef EVENT_OBJECT_INVOKED
#define EVENT_OBJECT_INVOKED 0x8013
#endif
typedef struct IAccessible IAccessible;
typedef struct IAccessibleVtbl {
	/* IUnknown */
	HRESULT (STDMETHODCALLTYPE *QueryInterface)(IAccessible *, REFIID, void **);
	ULONG (STDMETHODCALLTYPE *AddRef)(IAccessible *);
	ULONG (STDMETHODCALLTYPE *Release)(IAccessible *);
	/* IDispatch */
	void *GetTypeInfoCount;
	void *GetTypeInfo;
	void *GetIDsOfNames;
	void *Invoke;
	/* IAccessible */
	void *get_accParent;
	void *get_accChildCount;
	void *get_accChild;
	HRESULT (STDMETHODCALLTYPE *get_accName)(IAccessible *, VARIANT, BSTR *);
	void *get_accValue;
	void *get_accDescription;
	HRESULT (STDMETHODCALLTYPE *get_accRole)(IAccessible *, VARIANT, VARIANT *);
	HRESULT (STDMETHODCALLTYPE *get_accState)(IAccessible *, VARIANT, VARIANT *);
	void *get_accHelp;
	void *get_accHelpTopic;
	void *get_accKeyboardShortcut;
	void *get_accFocus;
	void *get_accSelection;
	HRESULT (STDMETHODCALLTYPE *get_accDefaultAction)(IAccessible *, VARIANT, BSTR *);
	void *accSelect;
	void *accLocation;
	void *accNavigate;
	void *accHitTest;
	HRESULT (STDMETHODCALLTYPE *accDoDefaultAction)(IAccessible *, VARIANT);
	void *put_accName;
	void *put_accValue;
} IAccessibleVtbl;
struct IAccessible {
	CONST_VTBL IAccessibleVtbl *lpVtbl;
};
HRESULT WINAPI AccessibleObjectFromWindow(HWND, DWORD, REFIID, void **);
LRESULT WINAPI LresultFromObject(REFIID, WPARAM, IUnknown *);
HRESULT WINAPI CreateStdAccessibleProxyW(HWND, LPCWSTR, LONG, REFIID, void **);

/* ---- exports missing from V's tcc import lists ----
 * tcc links gdi32 and kernel32 through the hand-listed gdi32.def and kernel32.def in
 * V's thirdparty/tcc/lib (every other library it reads from the DLL's own export
 * table). Five calls the helpers make are absent from those lists —
 * GetGlyphIndicesW, GetTickCount64 and the activation context's three — and one
 * call from V, AddFontResourceExW, is absent too; they are fetched from the
 * DLLs at first use, behind macros of their own names. */
typedef DWORD (WINAPI *ui2_tcc_GetGlyphIndicesW_t)(HDC, LPCWSTR, int, LPWORD, DWORD);
typedef ULONGLONG (WINAPI *ui2_tcc_GetTickCount64_t)(void);
typedef HANDLE (WINAPI *ui2_tcc_CreateActCtxW_t)(PCACTCTXW);
typedef WINBOOL (WINAPI *ui2_tcc_ActivateActCtx_t)(HANDLE, ULONG_PTR *);
typedef VOID (WINAPI *ui2_tcc_ReleaseActCtx_t)(HANDLE);
typedef int (WINAPI *ui2_tcc_AddFontResourceExW_t)(LPCWSTR, DWORD, PVOID);
typedef PIDLIST_ABSOLUTE (WINAPI *ui2_tcc_SHBrowseForFolderW_t)(LPBROWSEINFOW);
typedef WINBOOL (WINAPI *ui2_tcc_SHGetPathFromIDListW_t)(PCIDLIST_ABSOLUTE, LPWSTR);
typedef WINBOOL (WINAPI *ui2_tcc_Shell_NotifyIconW_t)(DWORD, PNOTIFYICONDATAW);
static FARPROC ui2_tcc_import(const wchar_t *dll, const char *name) {
	HMODULE module = GetModuleHandleW(dll);
	if (module == NULL) module = LoadLibraryW(dll);
	return module == NULL ? NULL : GetProcAddress(module, name);
}
static DWORD WINAPI ui2_tcc_GetGlyphIndicesW(HDC dc, LPCWSTR text, int count, LPWORD glyphs, DWORD flags) {
	static ui2_tcc_GetGlyphIndicesW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_GetGlyphIndicesW_t)ui2_tcc_import(L"gdi32.dll", "GetGlyphIndicesW");
	return f == NULL ? GDI_ERROR : f(dc, text, count, glyphs, flags);
}
static ULONGLONG WINAPI ui2_tcc_GetTickCount64(void) {
	static ui2_tcc_GetTickCount64_t f = NULL;
	if (f == NULL) f = (ui2_tcc_GetTickCount64_t)ui2_tcc_import(L"kernel32.dll", "GetTickCount64");
	return f == NULL ? 0 : f();
}
static HANDLE WINAPI ui2_tcc_CreateActCtxW(PCACTCTXW context) {
	static ui2_tcc_CreateActCtxW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_CreateActCtxW_t)ui2_tcc_import(L"kernel32.dll", "CreateActCtxW");
	return f == NULL ? INVALID_HANDLE_VALUE : f(context);
}
static WINBOOL WINAPI ui2_tcc_ActivateActCtx(HANDLE context, ULONG_PTR *cookie) {
	static ui2_tcc_ActivateActCtx_t f = NULL;
	if (f == NULL) f = (ui2_tcc_ActivateActCtx_t)ui2_tcc_import(L"kernel32.dll", "ActivateActCtx");
	return f == NULL ? FALSE : f(context, cookie);
}
static VOID WINAPI ui2_tcc_ReleaseActCtx(HANDLE context) {
	static ui2_tcc_ReleaseActCtx_t f = NULL;
	if (f == NULL) f = (ui2_tcc_ReleaseActCtx_t)ui2_tcc_import(L"kernel32.dll", "ReleaseActCtx");
	if (f != NULL) f(context);
}
/* called from V (windows/ui_windows.v's `fn C.AddFontResourceExW`), not from the
 * helpers; the macro renames that emitted call too, since this header precedes it */
static int WINAPI ui2_tcc_AddFontResourceExW(LPCWSTR name, DWORD flags, PVOID reserved) {
	static ui2_tcc_AddFontResourceExW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_AddFontResourceExW_t)ui2_tcc_import(L"gdi32.dll", "AddFontResourceExW");
	return f == NULL ? 0 : f(name, flags, reserved);
}
/* shell32: V's shell32.def lacks these three */
static PIDLIST_ABSOLUTE WINAPI ui2_tcc_SHBrowseForFolderW(LPBROWSEINFOW info) {
	static ui2_tcc_SHBrowseForFolderW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_SHBrowseForFolderW_t)ui2_tcc_import(L"shell32.dll", "SHBrowseForFolderW");
	return f == NULL ? NULL : f(info);
}
static WINBOOL WINAPI ui2_tcc_SHGetPathFromIDListW(PCIDLIST_ABSOLUTE item, LPWSTR path) {
	static ui2_tcc_SHGetPathFromIDListW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_SHGetPathFromIDListW_t)ui2_tcc_import(L"shell32.dll", "SHGetPathFromIDListW");
	return f == NULL ? FALSE : f(item, path);
}
static WINBOOL WINAPI ui2_tcc_Shell_NotifyIconW(DWORD message, PNOTIFYICONDATAW data) {
	static ui2_tcc_Shell_NotifyIconW_t f = NULL;
	if (f == NULL) f = (ui2_tcc_Shell_NotifyIconW_t)ui2_tcc_import(L"shell32.dll", "Shell_NotifyIconW");
	return f == NULL ? FALSE : f(message, data);
}
#define GetGlyphIndicesW ui2_tcc_GetGlyphIndicesW
#define GetTickCount64 ui2_tcc_GetTickCount64
#define AddFontResourceExW ui2_tcc_AddFontResourceExW
#define SHBrowseForFolderW ui2_tcc_SHBrowseForFolderW
#define SHGetPathFromIDListW ui2_tcc_SHGetPathFromIDListW
#define Shell_NotifyIconW ui2_tcc_Shell_NotifyIconW
#define CreateActCtxW ui2_tcc_CreateActCtxW
#define ActivateActCtx ui2_tcc_ActivateActCtx
#define ReleaseActCtx ui2_tcc_ReleaseActCtx

/* tcc's rpcndr.h, which the COM headers above pull in, defines `small` as a type
 * (`#define small char`, unconditionally; mingw-w64's does it only under
 * RC_INVOKED, for the resource compiler), and V emits struct fields under their V
 * names: ui2's `small` fields became `double char` ("too many basic types"). The
 * helpers never use the macro. */
#undef small

#endif /* __TINYC__ */
#endif /* UI2_TCC_COMPAT_WINDOWS_H */
