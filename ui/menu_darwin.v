// vfmt off
// The macOS menu bar and status area item. Like the NSAlert in
// message_box_darwin.v these are Objective-C runtime objects rather than
// views, so this file stays outside the appkit/ backend and only needs the
// bridge — which also lets a custom-rendered macOS build fall back to the
// drawn bar without a second copy of the declaration handling.
module ui2

import macos

#flag darwin -framework AppKit

// NSEventModifierFlags, the subset a menu accelerator can carry.
const ns_event_modifier_shift = u64(1) << 17
const ns_event_modifier_control = u64(1) << 18
const ns_event_modifier_option = u64(1) << 19
const ns_event_modifier_command = u64(1) << 20

// NSVariableStatusItemLength: the item is as wide as its title and image need.
const ns_variable_status_item_length = f64(-1)

const ns_control_state_on = i64(1)
const ns_control_state_off = i64(0)

// Status area images are drawn at the menu bar's own height.
const macos_status_image_size = f64(18)

@[heap]
struct MacosMenuState {
mut:
	handler     macos.Id
	status_item macos.Id
	// bar_ids and tray_ids map an NSMenuItem — or the status item's button — to
	// the id it emits. The menu owns the item, so the pointer identifies it for
	// as long as it can be chosen.
	bar_ids  map[u64]string
	tray_ids map[u64]string
}

const macos_menu_state_singleton = &MacosMenuState{
	bar_ids: map[u64]string{}
	tray_ids: map[u64]string{}
}

fn macos_menu_state() &MacosMenuState {
	return unsafe { macos_menu_state_singleton }
}

fn native_menu_bar_supported() bool {
	return true
}

fn native_tray_supported() bool {
	// The custom renderer draws inside its own window and owns nothing outside
	// it, so a macOS build using it has no status area to dock into.
	$if ui2_custom_rendering ? {
		return false
	} $else {
		return true
	}
}

fn native_set_menu_bar(menus []Menu) {
	$if ui2_custom_rendering ? {
		// The drawn bar is rebuilt from the declaration every frame; all that
		// has to happen is that a menu left open by the previous one cannot
		// outlive it.
		close_menu_bar()
	} $else {
		macos_install_menu_bar(menu_app_name(), menus)
	}
}

fn native_set_tray(cfg TrayConfig) {
	$if !ui2_custom_rendering ? {
		macos_install_status_item(cfg)
	}
}

fn native_remove_tray() {
	$if !ui2_custom_rendering ? {
		macos_remove_status_item()
	}
}

// macos_install_menu_bar rebuilds the whole main menu. The application menu
// with its "Quit <app>" item always comes first — macOS reads the first
// submenu as the application one, and without it AppKit has nothing to handle
// the Cmd+Q key equivalent, so a ui2 window could not be quit from the
// keyboard. The Quit item has no explicit target, so its terminate: action
// travels the responder chain to NSApp, honoring any applicationShouldTerminate:
// the app's delegate installs.
fn macos_install_menu_bar(app_name string, menus []Menu) {
	mut ids := map[u64]string{}
	main_menu := macos.msg_id(macos.alloc('NSMenu'), 'init')
	macos.msg_void_bool(main_menu, 'setAutoenablesItems:', false)

	app_menu_item := macos.msg_id(macos.alloc('NSMenuItem'), 'init')
	macos.msg_void1(main_menu, 'addItem:', app_menu_item)
	app_menu := macos.msg_id(macos.alloc('NSMenu'), 'init')
	macos.msg_void1(app_menu, 'setTitle:', macos.nsstring(app_name))
	quit_item := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:', macos.nsstring('Quit ${app_name}'), macos.Id(voidptr(macos.sel('terminate:'))), macos.nsstring('q'))
	macos.msg_void1(app_menu, 'addItem:', quit_item)
	macos.release(quit_item)
	macos.msg_void1(app_menu_item, 'setSubmenu:', app_menu)
	macos.release(app_menu)
	macos.release(app_menu_item)

	for m in menus {
		title := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:', macos.nsstring(m.title), macos.Id(unsafe { nil }), macos.nsstring(''))
		rows := macos_build_menu(m.title, m.items, mut ids)
		macos.msg_void1(title, 'setSubmenu:', rows)
		macos.release(rows)
		macos.msg_void1(main_menu, 'addItem:', title)
		macos.release(title)
	}

	macos.msg_void1(macos_shared_application(), 'setMainMenu:', main_menu)
	macos.release(main_menu)
	mut st := macos_menu_state()
	st.bar_ids = ids.move()
}

fn macos_install_status_item(cfg TrayConfig) {
	mut st := macos_menu_state()
	if st.status_item == unsafe { nil } {
		bar := macos.msg_id(macos.get_class('NSStatusBar'), 'systemStatusBar')
		if bar == unsafe { nil } {
			return
		}
		item := macos.msg_id_f64(bar, 'statusItemWithLength:', ns_variable_status_item_length)
		if item == unsafe { nil } {
			return
		}
		// The status bar hands the item back without transferring ownership;
		// hold it, or it leaves the menu bar as soon as the pool drains.
		st.status_item = macos.retain(item)
	}
	mut ids := map[u64]string{}
	if cfg.menu.len > 0 {
		menu := macos_build_menu(cfg.title, cfg.menu, mut ids)
		macos.msg_void1(st.status_item, 'setMenu:', menu)
		macos.release(menu)
	} else {
		macos.msg_void1(st.status_item, 'setMenu:', macos.Id(unsafe { nil }))
	}
	status_button := macos.msg_id(st.status_item, 'button')
	if status_button != unsafe { nil } {
		macos.msg_void1(status_button, 'setTitle:', macos.nsstring(cfg.title))
		macos.msg_void1(status_button, 'setToolTip:', macos.nsstring(cfg.tooltip))
		macos.msg_void1(status_button, 'setImage:', macos_status_image(cfg.icon))
		// A status item with a menu opens it on either mouse button, so the
		// button's own action is only wired up for the menu-less case.
		if cfg.menu.len == 0 && cfg.id.len > 0 {
			macos.msg_void1(status_button, 'setTarget:', macos_menu_handler())
			macos.msg_void1(status_button, 'setAction:', macos.sel('handleMenuItem:'))
			ids[u64(voidptr(status_button))] = cfg.id
		} else {
			macos.msg_void1(status_button, 'setTarget:', macos.Id(unsafe { nil }))
			macos.msg_void1(status_button, 'setAction:', macos.Id(unsafe { nil }))
		}
	}
	st.tray_ids = ids.move()
}

fn macos_remove_status_item() {
	mut st := macos_menu_state()
	if st.status_item == unsafe { nil } {
		return
	}
	bar := macos.msg_id(macos.get_class('NSStatusBar'), 'systemStatusBar')
	if bar != unsafe { nil } {
		macos.msg_void1(bar, 'removeStatusItem:', st.status_item)
	}
	macos.release(st.status_item)
	st.status_item = macos.Id(unsafe { nil })
	st.tray_ids = map[u64]string{}
}

// macos_status_image resolves an SF Symbol name or an image file into an icon
// the status bar can draw, sized to the menu bar's height.
fn macos_status_image(icon string) macos.Id {
	if icon.len == 0 {
		return macos.Id(unsafe { nil })
	}
	mut source := macos.Id(unsafe { nil })
	if icon.starts_with('symbol:') {
		image_class := macos.get_class('NSImage')
		if macos.responds_to(image_class, 'imageWithSystemSymbolName:accessibilityDescription:') {
			source = macos.msg_id2(image_class, 'imageWithSystemSymbolName:accessibilityDescription:', macos.nsstring(icon['symbol:'.len..]), macos.Id(unsafe { nil }))
		}
	} else {
		from_file := macos.msg_id1(macos.alloc('NSImage'), 'initWithContentsOfFile:', macos.nsstring(icon))
		if from_file != unsafe { nil } {
			source = macos.msg_id(from_file, 'autorelease')
		} else {
			source = macos.msg_id1(macos.get_class('NSImage'), 'imageNamed:', macos.nsstring(icon))
		}
	}
	if source == unsafe { nil } {
		return source
	}
	sized := macos.msg_id(macos.msg_id(source, 'copy'), 'autorelease')
	macos.msg_void_point(sized, 'setSize:', macos.point(macos_status_image_size, macos_status_image_size))
	// Carry the source's own template flag rather than forcing one: a template
	// image is recolored by the system, which is what keeps an SF Symbol
	// legible in both the light and the dark menu bar, while an icon the app
	// drew in color stays the color it drew.
	macos.msg_void_bool(sized, 'setTemplate:', macos.msg_bool(source, 'isTemplate'))
	return sized
}

fn macos_build_menu(title string, items []MenuItem, mut ids map[u64]string) macos.Id {
	menu := macos.msg_id1(macos.alloc('NSMenu'), 'initWithTitle:', macos.nsstring(title))
	// ui2 declares whether a row is enabled, so AppKit must not decide for
	// itself by asking the responder chain about each action.
	macos.msg_void_bool(menu, 'setAutoenablesItems:', false)
	for item in items {
		macos_add_menu_item(menu, item, mut ids)
	}
	return menu
}

fn macos_add_menu_item(menu macos.Id, item MenuItem, mut ids map[u64]string) {
	if item.separator {
		macos.msg_void1(menu, 'addItem:', macos.msg_id(macos.get_class('NSMenuItem'), 'separatorItem'))
		return
	}
	if item.items.len > 0 {
		parent := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:', macos.nsstring(item.title), macos.Id(unsafe { nil }), macos.nsstring(''))
		child := macos_build_menu(item.title, item.items, mut ids)
		macos.msg_void1(parent, 'setSubmenu:', child)
		macos.release(child)
		macos.msg_void_bool(parent, 'setEnabled:', item.enabled)
		macos.msg_void1(menu, 'addItem:', parent)
		macos.release(parent)
		return
	}
	shortcut := parse_menu_shortcut(item.shortcut)
	row := macos.msg_id3(macos.alloc('NSMenuItem'), 'initWithTitle:action:keyEquivalent:', macos.nsstring(item.title), macos.Id(voidptr(macos.sel('handleMenuItem:'))), macos.nsstring(macos_key_equivalent(shortcut)))
	macos.msg_void_u64(row, 'setKeyEquivalentModifierMask:', macos_modifier_mask(shortcut))
	macos.msg_void1(row, 'setTarget:', macos_menu_handler())
	macos.msg_void_bool(row, 'setEnabled:', item.enabled)
	macos.msg_void_i64(row, 'setState:', if item.checked { ns_control_state_on } else { ns_control_state_off })
	// Bind by sender pointer rather than by a positional tag, so a retained
	// item from an earlier declaration can never dispatch through this one.
	ids[u64(voidptr(row))] = item.id
	macos.msg_void1(menu, 'addItem:', row)
	macos.release(row)
}

// macos_key_equivalent turns a parsed shortcut into the single-character
// string NSMenuItem wants. Shift lives in the modifier mask rather than in the
// case of the character, so the letter stays lowercase.
fn macos_key_equivalent(shortcut MenuShortcut) string {
	if shortcut.key.len == 0 {
		return ''
	}
	if shortcut.key.len > 1 && shortcut.key[0] == `f` {
		number := shortcut.key[1..].int()
		if number >= 1 && number <= 12 {
			// NSF1FunctionKey and its successors sit in the Unicode private
			// use area, one code point apart.
			return rune(0xf704 + number - 1).str()
		}
	}
	return match shortcut.key {
		'left' { rune(0xf702).str() }
		'right' { rune(0xf703).str() }
		'up' { rune(0xf700).str() }
		'down' { rune(0xf701).str() }
		'space' { ' ' }
		'tab' { '\t' }
		'enter', 'return' { '\r' }
		'escape', 'esc' { '\x1b' }
		'delete', 'backspace' { '\x08' }
		else { if shortcut.key.runes().len == 1 { shortcut.key } else { '' } }
	}
}

fn macos_modifier_mask(shortcut MenuShortcut) u64 {
	mut mask := u64(0)
	if shortcut.cmd {
		mask |= ns_event_modifier_command
	}
	if shortcut.ctrl {
		mask |= ns_event_modifier_control
	}
	if shortcut.alt {
		mask |= ns_event_modifier_option
	}
	if shortcut.shift {
		mask |= ns_event_modifier_shift
	}
	return mask
}

fn macos_shared_application() macos.Id {
	return macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
}

fn macos_menu_handler() macos.Id {
	mut st := macos_menu_state()
	if st.handler != unsafe { nil } {
		return st.handler
	}
	if macos.get_class('UI2MenuHandler') == unsafe { nil } {
		cls := macos.allocate_class_pair(macos.get_class('NSObject'), 'UI2MenuHandler')
		macos.add_method(cls, 'handleMenuItem:', voidptr(ui2_menu_item_chosen), 'v@:@')
		macos.register_class_pair(cls)
	}
	st.handler = macos.msg_id(macos.alloc('UI2MenuHandler'), 'init')
	return st.handler
}

@[export: 'ui2_menu_item_chosen']
fn ui2_menu_item_chosen(_self voidptr, _cmd voidptr, sender voidptr) {
	st := macos_menu_state()
	pointer := u64(sender)
	emit_menu_event(st.bar_ids[pointer] or { st.tray_ids[pointer] or { '' } })
}
