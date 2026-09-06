// vfmt off
// The window's menu bar and the notification area icon. Both are built from
// the declaration in one go rather than reconciled: a menu is small, and
// rebuilding it is what keeps the declared rows and the HMENU in step.
module ui2

$if !ui2_custom_rendering ? {

fn C.ui2_win_menubar_create() voidptr

fn C.ui2_win_menu_add_item(menu voidptr, command u32, title &u16, enabled int, checked int)

fn C.ui2_win_menu_add_separator(menu voidptr)

fn C.ui2_win_menu_add_submenu(menu voidptr, submenu voidptr, title &u16)

fn C.ui2_win_set_menubar(hwnd voidptr, menu voidptr)

fn C.ui2_win_accel_reset()

fn C.ui2_win_accel_add(virtual_key int, control int, alt int, shift int, command u32)

fn C.ui2_win_accel_install(hwnd voidptr)

fn C.ui2_win_tray_set(hwnd voidptr, tooltip &u16, icon_path &u16)

fn C.ui2_win_tray_remove()

fn C.ui2_win_tray_popup(hwnd voidptr, menu voidptr) u32

const win_wm_tray = u32(0x8000 + 78)
const win_wm_rbutton_up = u32(0x0205)
const win_wm_contextmenu = u32(0x007b)

// Menu bar commands start well above the small ordinals the right-click menus
// hand to TrackPopupMenu, so a stray command can never be read as one of them.
const win_menu_command_base = u32(0x1000)

@[heap]
struct WindowsMenuState {
mut:
	bar_commands map[u32]string
	tray_active  bool
}

const windows_menu_state_singleton = &WindowsMenuState{
	bar_commands: map[u32]string{}
}

fn windows_menu_state() &WindowsMenuState {
	return unsafe { windows_menu_state_singleton }
}

fn menu_win32_set_menu_bar(menus []Menu) {
	mut st := windows_menu_state()
	st.bar_commands = map[u32]string{}
	root := menu_window()
	if root == unsafe { nil } {
		// Declared before the window exists; run_window installs it again once
		// there is something to attach it to.
		return
	}
	C.ui2_win_accel_reset()
	if menus.len == 0 {
		C.ui2_win_set_menubar(root, unsafe { nil })
		C.ui2_win_accel_install(root)
		return
	}
	menubar := C.ui2_win_menubar_create()
	if menubar == unsafe { nil } {
		return
	}
	mut commands := map[u32]string{}
	mut next := win_menu_command_base
	for m in menus {
		popup := C.ui2_win_menu_create()
		if popup == unsafe { nil } {
			continue
		}
		next = windows_fill_menu(popup, m.items, true, mut commands, next)
		wide_title := m.title.to_wide()
		C.ui2_win_menu_add_submenu(menubar, popup, wide_title)
		unsafe { free(wide_title) }
	}
	st.bar_commands = commands.move()
	C.ui2_win_set_menubar(root, menubar)
	C.ui2_win_accel_install(root)
}

fn menu_win32_set_tray(cfg TrayConfig) {
	mut st := windows_menu_state()
	root := menu_window()
	if root == unsafe { nil } {
		return
	}
	// Windows has no room for a text-only notification area item, so the
	// title falls back into the tooltip when none was given.
	tooltip := if cfg.tooltip.len > 0 { cfg.tooltip } else { cfg.title }
	wide_tooltip := tooltip.to_wide()
	wide_icon := cfg.icon.to_wide()
	C.ui2_win_tray_set(root, wide_tooltip, wide_icon)
	unsafe {
		free(wide_tooltip)
		free(wide_icon)
	}
	st.tray_active = true
}

fn menu_win32_remove_tray() {
	mut st := windows_menu_state()
	if !st.tray_active {
		return
	}
	C.ui2_win_tray_remove()
	st.tray_active = false
}

// windows_fill_menu appends one level of rows, numbering each emitting one
// into `commands`. Only the menu bar registers accelerators; a notification
// area menu is tracked with TPM_RETURNCMD and its commands never reach the
// window, so binding keys to them would be a lie.
fn windows_fill_menu(menu voidptr, items []MenuItem, register_accelerators bool, mut commands map[u32]string, first_command u32) u32 {
	mut next := first_command
	for item in items {
		if item.separator {
			C.ui2_win_menu_add_separator(menu)
			continue
		}
		if item.items.len > 0 {
			child := C.ui2_win_menu_create()
			if child == unsafe { nil } {
				continue
			}
			next = windows_fill_menu(child, item.items, register_accelerators, mut commands, next)
			wide_title := item.title.to_wide()
			C.ui2_win_menu_add_submenu(menu, child, wide_title)
			unsafe { free(wide_title) }
			continue
		}
		command := next
		next++
		commands[command] = item.id
		shortcut := parse_menu_shortcut(item.shortcut)
		// Win32 draws whatever follows a tab right-aligned in the row, which
		// is how a menu shows its accelerator.
		row_label := if shortcut.key.len > 0 {
			'${item.title}\t${menu_shortcut_label(item.shortcut)}'
		} else {
			item.title
		}
		wide_label := row_label.to_wide()
		C.ui2_win_menu_add_item(menu, command, wide_label, windows_bool(item.enabled),
			windows_bool(item.checked))
		unsafe { free(wide_label) }
		if register_accelerators && item.enabled && menu_shortcut_bindable(shortcut) {
			virtual_key := windows_virtual_key(shortcut.key)
			if virtual_key != 0 {
				C.ui2_win_accel_add(virtual_key, windows_bool(shortcut.cmd || shortcut.ctrl),
					windows_bool(shortcut.alt), windows_bool(shortcut.shift), command)
			}
		}
	}
	return next
}

// windows_handle_menu_command runs a WM_COMMAND that carried no control
// handle, which is what a menu bar row and an accelerator both send.
fn windows_handle_menu_command(command u32) {
	st := windows_menu_state()
	emit_menu_event(st.bar_commands[command] or { return })
}

// windows_handle_tray_message answers a click on the notification area icon.
// The menu is built on demand so it always shows the current declaration.
fn windows_handle_tray_message(mouse_message u32) {
	cfg := tray()
	if mouse_message !in [win_wm_lbutton_up, win_wm_rbutton_up, win_wm_contextmenu] {
		return
	}
	if cfg.menu.len == 0 {
		if mouse_message == win_wm_lbutton_up {
			emit_menu_event(cfg.id)
		}
		return
	}
	root := menu_window()
	if root == unsafe { nil } {
		return
	}
	menu := C.ui2_win_menu_create()
	if menu == unsafe { nil } {
		return
	}
	// The tray rows are numbered into their own table, so building the menu
	// cannot renumber the menu bar's.
	mut commands := map[u32]string{}
	_ := windows_fill_menu(menu, cfg.menu, false, mut commands, win_menu_command_base)
	chosen := commands[C.ui2_win_tray_popup(root, menu)] or { '' }
	C.ui2_win_menu_destroy(menu)
	emit_menu_event(chosen)
}

// windows_virtual_key maps a shortcut key onto the VK_ code an accelerator
// table needs. Letters and digits are their uppercase ASCII values.
fn windows_virtual_key(key string) int {
	if key.len == 1 {
		code := key[0]
		if code >= `a` && code <= `z` {
			return int(code) - 32
		}
		if code >= `0` && code <= `9` {
			return int(code)
		}
	}
	if key.len > 1 && key[0] == `f` {
		number := key[1..].int()
		if number >= 1 && number <= 12 {
			// VK_F1 is 0x70 and the rest follow it.
			return 0x6f + number
		}
	}
	return match key {
		'left' { 0x25 }
		'up' { 0x26 }
		'right' { 0x27 }
		'down' { 0x28 }
		'space' { 0x20 }
		'tab' { 0x09 }
		'enter', 'return' { 0x0d }
		'escape', 'esc' { 0x1b }
		'delete' { 0x2e }
		'backspace' { 0x08 }
		// The punctuation an accelerator commonly uses has no ASCII VK code of
		// its own; these are the layout-independent OEM ones.
		'=' { 0xbb }
		'-' { 0xbd }
		',' { 0xbc }
		'.' { 0xbe }
		'/' { 0xbf }
		else { 0 }
	}
}

}
