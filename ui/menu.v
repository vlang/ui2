module ui2

// Application menus: the window's top level menu bar and the status area
// ("system tray") icon with its own menu.
//
// Both are declared with the same rows and both emit through the window's
// event handler — the one passed to run_window — so a menu row and a button
// can share an action id and run the same code.
//
// MenuEntry, further up in ui.v, stays the flat right-click list attached to
// one element; MenuItem below is the richer row a menu bar and a tray menu are
// built from.

// MenuItem is one row of a menu bar menu, a submenu, or a tray menu.
//
// A row with `items` is a submenu and emits nothing itself. A row with
// `separator` set draws the divider between two groups and carries no title.
// Every other row emits `id` through the window's event handler when it is
// chosen.
pub struct MenuItem {
pub:
	id    string
	title string
	// shortcut is a normalized accelerator such as 'cmd+n' or 'cmd+shift+s'.
	// `cmd` names the platform's primary modifier: Command on macOS, Control
	// on Windows and Linux. Keys are single characters or 'f1'..'f12'.
	shortcut  string
	separator bool
	checked   bool
	enabled   bool = true
	items     []MenuItem
}

// Menu is one top level menu bar title and the rows under it. macOS puts them
// in the system menu bar after the application menu, Windows in the window's
// own menu bar, and the custom renderer draws a bar across the top of the
// window.
pub struct Menu {
pub:
	title string
	items []MenuItem
}

// TrayConfig describes the status area icon and the menu it opens. macOS puts
// it in the menu bar's status area, Windows in the notification area.
pub struct TrayConfig {
pub:
	// id is emitted when the icon is clicked and `menu` is empty. A tray icon
	// with a menu opens that menu instead.
	id string
	// title is the text drawn beside the icon; on its own it is enough to make
	// the item visible, so an icon-less tray is still usable.
	title string
	// icon is an image path, or 'symbol:<name>' for an SF Symbol on macOS.
	// Status area icons are small: 16x16 up to 22x22. An SF Symbol, or any
	// image marked as a template, is recolored to suit a light or dark menu
	// bar; any other image is drawn as it is.
	icon    string
	tooltip string
	menu    []MenuItem
}

// MenuShortcut is a parsed accelerator. `cmd` is the platform's primary
// modifier, kept apart from `ctrl` so macOS can bind Command and the other
// backends can fold both onto Control.
pub struct MenuShortcut {
pub:
	cmd   bool
	ctrl  bool
	alt   bool
	shift bool
	key   string
}

@[heap]
struct MenuState {
mut:
	menus        []Menu
	tray         TrayConfig
	tray_visible bool
	// dispatch, app_name and window are published by the backend's run_window.
	// Menus hang off the application rather than off the element tree, so this
	// is how the per-platform menu code reaches the window's event handler, the
	// name to build a macOS application menu from, and the native handle a
	// Win32 menu bar attaches to — without depending on one backend's state.
	dispatch EventFn = EventFn(unsafe { nil })
	app_name string = 'App'
	window   voidptr
}

const menu_state_singleton = &MenuState{}

fn menu_state() &MenuState {
	return unsafe { menu_state_singleton }
}

// publish_menu_context is called by each backend's run_window before the first
// menu is built.
fn publish_menu_context(handler EventFn, app_name string, window voidptr) {
	mut st := menu_state()
	st.dispatch = handler
	if app_name.len > 0 {
		st.app_name = app_name
	}
	st.window = window
}

// emit_menu_event sends a chosen row to the window's event handler, the same
// channel a button tap arrives on.
fn emit_menu_event(id string) {
	st := menu_state()
	if id.len > 0 && voidptr(st.dispatch) != unsafe { nil } {
		st.dispatch(id)
	}
}

fn menu_app_name() string {
	return menu_state().app_name
}

fn menu_window() voidptr {
	return menu_state().window
}

// install_declared_menus applies what was declared before the window existed.
// Backends call it once there is something to attach a menu to. The menu bar
// is installed even when nothing was declared, because macOS still needs its
// application menu.
fn install_declared_menus() {
	st := menu_state()
	native_set_menu_bar(st.menus)
	if st.tray_visible {
		native_set_tray(st.tray)
	}
}

// menu_item builds a plain row that emits `id` when chosen.
pub fn menu_item(id string, title string) MenuItem {
	return MenuItem{
		id: id
		title: title
	}
}

// menu_item_with_shortcut builds a row with a keyboard accelerator, e.g.
// menu_item_with_shortcut('new', 'New', 'cmd+n').
pub fn menu_item_with_shortcut(id string, title string, shortcut string) MenuItem {
	return MenuItem{
		id: id
		title: title
		shortcut: shortcut
	}
}

// menu_check_item builds a row with a check mark. The state is declared, not
// remembered: rebuild the menu bar with the new value after handling the event.
pub fn menu_check_item(id string, title string, checked bool) MenuItem {
	return MenuItem{
		id: id
		title: title
		checked: checked
	}
}

pub fn menu_separator() MenuItem {
	return MenuItem{
		separator: true
	}
}

// submenu builds a row that opens a nested menu.
pub fn submenu(title string, items []MenuItem) MenuItem {
	return MenuItem{
		title: title
		items: items
	}
}

// disabled greys a row out so it is visible but cannot be chosen.
pub fn disabled(item MenuItem) MenuItem {
	return MenuItem{
		...item
		enabled: false
	}
}

// set_menu_bar installs the application's top level menu bar, replacing any
// previous one. Call it before or after run_window: menus declared before the
// window exists are installed as the application finishes launching.
pub fn set_menu_bar(menus []Menu) {
	mut st := menu_state()
	st.menus = menus.clone()
	native_set_menu_bar(st.menus)
}

// menu_bar reports the menu bar last passed to set_menu_bar.
pub fn menu_bar() []Menu {
	return menu_state().menus
}

// menu_bar_supported reports whether set_menu_bar reaches a real menu bar.
// iOS and Android have no menu bar, so it does nothing there.
pub fn menu_bar_supported() bool {
	return native_menu_bar_supported()
}

// set_tray shows the status area icon, replacing any previous one.
pub fn set_tray(cfg TrayConfig) {
	mut st := menu_state()
	st.tray = cfg
	st.tray_visible = true
	native_set_tray(cfg)
}

// remove_tray takes the status area icon away again.
pub fn remove_tray() {
	mut st := menu_state()
	st.tray = TrayConfig{}
	st.tray_visible = false
	native_remove_tray()
}

// tray reports the configuration last passed to set_tray.
pub fn tray() TrayConfig {
	return menu_state().tray
}

// tray_visible reports whether a tray icon is currently declared.
pub fn tray_visible() bool {
	return menu_state().tray_visible
}

// tray_supported reports whether set_tray reaches a real status area. The
// custom renderer draws inside its own window and has none, and neither do
// iOS and Android.
pub fn tray_supported() bool {
	return native_tray_supported()
}

// validate_menus rejects rows a backend cannot build before one of them tries.
pub fn validate_menus(menus []Menu) ! {
	mut ids := map[string]bool{}
	for index, m in menus {
		if m.title.trim_space().len == 0 {
			return error('menu ${index} has no title')
		}
		validate_menu_items(m.items, m.title, mut ids)!
	}
}

// validate_menu_items checks one menu's rows; tray menus have no title above
// them, so they are validated through this entry point directly.
pub fn validate_menu_items(items []MenuItem, path string, mut ids map[string]bool) ! {
	for index, item in items {
		here := '${path}/${index}'
		if item.separator {
			if item.id.len > 0 || item.title.len > 0 || item.items.len > 0 {
				return error('separator at ${here} cannot carry a title, id or submenu')
			}
			continue
		}
		if item.title.trim_space().len == 0 {
			return error('menu item at ${here} has no title')
		}
		if item.items.len > 0 {
			if item.id.len > 0 {
				return error('submenu `${item.title}` at ${here} cannot also emit an id')
			}
			validate_menu_items(item.items, here, mut ids)!
			continue
		}
		if item.id.len == 0 {
			return error('menu item `${item.title}` at ${here} emits no id')
		}
		if item.id in ids {
			return error('duplicate menu item id `${item.id}` at ${here}')
		}
		ids[item.id] = true
	}
}

// parse_menu_shortcut splits 'cmd+shift+s' into its modifiers and key. An
// unparseable string yields an empty key, which every backend reads as "no
// accelerator".
pub fn parse_menu_shortcut(shortcut string) MenuShortcut {
	trimmed := shortcut.trim_space().to_lower()
	if trimmed.len == 0 {
		return MenuShortcut{}
	}
	mut cmd := false
	mut ctrl := false
	mut alt := false
	mut shift := false
	// '+' is both the separator and a bindable key, so a trailing one is the
	// key rather than an empty part.
	mut key := if trimmed.ends_with('++') { '+' } else { '' }
	for part in trimmed.split('+') {
		p := part.trim_space()
		match p {
			'' {}
			'cmd', 'command', 'super', 'meta' { cmd = true }
			'ctrl', 'control' { ctrl = true }
			'alt', 'option', 'opt' { alt = true }
			'shift' { shift = true }
			else { key = p }
		}
	}
	return MenuShortcut{
		cmd: cmd
		ctrl: ctrl
		alt: alt
		shift: shift
		key: key
	}
}

// menu_shortcut_label renders an accelerator the way the platform writes it:
// '⇧⌘S' on macOS, 'Ctrl+Shift+S' elsewhere. Backends whose menus are drawn by
// the system never need it; the custom renderer draws its own rows.
pub fn menu_shortcut_label(shortcut string) string {
	parsed := parse_menu_shortcut(shortcut)
	if parsed.key.len == 0 {
		return ''
	}
	key := menu_shortcut_key_label(parsed.key)
	$if macos {
		mut symbols := ''
		if parsed.ctrl {
			symbols += '⌃'
		}
		if parsed.alt {
			symbols += '⌥'
		}
		if parsed.shift {
			symbols += '⇧'
		}
		if parsed.cmd {
			symbols += '⌘'
		}
		return symbols + key
	} $else {
		mut parts := []string{}
		if parsed.cmd || parsed.ctrl {
			parts << 'Ctrl'
		}
		if parsed.alt {
			parts << 'Alt'
		}
		if parsed.shift {
			parts << 'Shift'
		}
		parts << key
		return parts.join('+')
	}
}

fn menu_shortcut_key_label(key string) string {
	return match key {
		'left' { '←' }
		'right' { '→' }
		'up' { '↑' }
		'down' { '↓' }
		'space' { 'Space' }
		'tab' { 'Tab' }
		'enter', 'return' { 'Enter' }
		'escape', 'esc' { 'Esc' }
		'delete', 'backspace' { 'Del' }
		else { key.to_upper() }
	}
}

// menu_shortcut_bindable reports whether an accelerator is safe to match
// against a bare key press. Anything without a modifier would fire while the
// user types, so only the function keys qualify on their own.
pub fn menu_shortcut_bindable(shortcut MenuShortcut) bool {
	if shortcut.key.len == 0 {
		return false
	}
	if shortcut.cmd || shortcut.ctrl || shortcut.alt {
		return true
	}
	return shortcut.key.len > 1 && shortcut.key[0] == `f` && shortcut.key[1..].int() > 0
}

// menu_shortcut_matches compares a declared accelerator with a pressed key.
// Off macOS the primary modifier is Control, so a declaration asking for `cmd`
// and one asking for `ctrl` describe the same chord there.
pub fn menu_shortcut_matches(declared MenuShortcut, pressed MenuShortcut) bool {
	if declared.key.len == 0 || declared.key != pressed.key {
		return false
	}
	if declared.shift != pressed.shift || declared.alt != pressed.alt {
		return false
	}
	$if macos {
		return declared.cmd == pressed.cmd && declared.ctrl == pressed.ctrl
	} $else {
		return (declared.cmd || declared.ctrl) == (pressed.cmd || pressed.ctrl)
	}
}

// find_menu_shortcut looks up the enabled row a key press should run.
pub fn find_menu_shortcut(items []MenuItem, pressed MenuShortcut) ?MenuItem {
	for item in items {
		if item.items.len > 0 {
			if found := find_menu_shortcut(item.items, pressed) {
				return found
			}
			continue
		}
		if item.separator || !item.enabled || item.id.len == 0 {
			continue
		}
		if menu_shortcut_matches(parse_menu_shortcut(item.shortcut), pressed) {
			return item
		}
	}
	return none
}

// menu_item_ids lists every emitting row of a menu tree, in order. Backends
// build their command tables from it and tests use it to check a declaration.
pub fn menu_item_ids(items []MenuItem) []string {
	mut ids := []string{}
	collect_menu_item_ids(items, mut ids)
	return ids
}

fn collect_menu_item_ids(items []MenuItem, mut ids []string) {
	for item in items {
		if item.separator {
			continue
		}
		if item.items.len > 0 {
			collect_menu_item_ids(item.items, mut ids)
			continue
		}
		if item.id.len > 0 {
			ids << item.id
		}
	}
}

// find_menu_item looks one emitting row up by id, following submenus.
pub fn find_menu_item(items []MenuItem, id string) ?MenuItem {
	for item in items {
		if item.items.len > 0 {
			if found := find_menu_item(item.items, id) {
				return found
			}
			continue
		}
		if !item.separator && item.id == id {
			return item
		}
	}
	return none
}
