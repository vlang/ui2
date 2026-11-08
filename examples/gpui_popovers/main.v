module main

import ui2

// A card's state machine and the timer it is waiting on.
@[heap]
struct CardSlot {
mut:
	state ui2.HoverCardState
	timer ui2.TimerId
}

@[heap]
struct Gallery {
mut:
	dark   bool
	status string = 'Hover, click and use the arrow keys; every action is reported here.'
	// The details popover is open below its first trigger to begin with.
	popover_open bool            = true
	popover_side ui2.PopoverSide = .bottom
	// The profile card starts open; the fast one opens and closes quickly.
	profile &CardSlot = &CardSlot{
		state: ui2.HoverCardState{
			open: true
		}
	}
	fast    &CardSlot = &CardSlot{
		state: ui2.HoverCardState{
			open_delay:  0.2
			close_delay: 0.1
		}
	}
	// The edit menu starts open with its "Sort by" submenu showing.
	edit_menu ui2.DropdownMenuState = ui2.DropdownMenuState{
		open: true
		path: [6, 0]
	}
	save_menu ui2.DropdownMenuState
	more_menu ui2.DropdownMenuState
	word_wrap bool   = true
	sort      string = 'name'
}

const gallery_state = &Gallery{}

fn gallery() &Gallery {
	return unsafe { gallery_state }
}

const popover_sides = [ui2.PopoverSide.bottom, .top, .right, .left]

fn side_name(side ui2.PopoverSide) string {
	return match side {
		.top { 'Top' }
		.bottom { 'Bottom' }
		.left { 'Left' }
		.right { 'Right' }
	}
}

// Layout, in window coordinates. Everything is a direct child of the screen,
// so a trigger's frame is also the anchor of the overlay it opens.
struct Layout {
	width   f64
	height  f64
	left_x  f64
	right_x f64
	column  f64
}

fn layout() Layout {
	win := ui2.bounds()
	column := win.width / 2 - 36
	return Layout{
		width:   win.width
		height:  win.height
		left_x:  24
		right_x: win.width / 2 + 12
		column:  column
	}
}

fn side_trigger_frame(l Layout, index int) ui2.Rect {
	return ui2.rect(l.left_x + f64(index) * 84, 156, 76, 32)
}

fn profile_trigger_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x + 78, 154, 112, 24)
}

fn fast_trigger_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x + 290, 150, 150, 32)
}

fn edit_button_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x, 384, ui2.dropdown_button_width('Edit', 'pencil', false, .medium), 32)
}

fn save_button_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x + 120, 384, ui2.dropdown_button_width('Save', 'square.and.arrow.down',
		true, .medium), 32)
}

fn more_button_frame(l Layout) ui2.Rect {
	return ui2.rect(l.right_x + 260, 384, 52, 32)
}

fn edit_items(app &Gallery) []ui2.DropdownMenuItem {
	return [
		ui2.dropdown_menu_heading('Clipboard'),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('cut', 'Cut')
			icon:     'scissors'
			shortcut: 'cmd+x'
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('copy', 'Copy')
			icon:     'doc.on.doc'
			shortcut: 'cmd+c'
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('paste', 'Paste')
			icon:     'list.bullet.clipboard'
			shortcut: 'cmd+v'
			enabled:  false
		},
		ui2.dropdown_menu_separator(),
		ui2.dropdown_menu_checkbox('wrap', 'Word wrap', app.word_wrap),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_submenu('Sort by', [
				ui2.dropdown_menu_radio('name', 'Name', app.sort == 'name'),
				ui2.dropdown_menu_radio('date', 'Date modified', app.sort == 'date'),
				ui2.dropdown_menu_radio('size', 'Size', app.sort == 'size'),
			])
			icon: 'arrow.up.arrow.down'
		},
		ui2.dropdown_menu_separator(),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('delete', 'Delete')
			icon:     'trash'
			shortcut: 'cmd+backspace'
		},
	]
}

// The save menu reuses rows declared the way a menu bar declares them.
fn save_items() []ui2.DropdownMenuItem {
	return ui2.dropdown_menu_items_from_menu([
		ui2.menu_item_with_shortcut('save_as', 'Save As…', 'cmd+shift+s'),
		ui2.menu_item('save_all', 'Save All'),
		ui2.menu_separator(),
		ui2.submenu('Export', [
			ui2.menu_item('export_pdf', 'PDF'),
			ui2.menu_item('export_png', 'PNG'),
		]),
	])
}

// The overflow menu reuses an element's right-click entries.
fn more_items() []ui2.DropdownMenuItem {
	return ui2.dropdown_menu_items_from_entries([
		ui2.MenuEntry{
			id:    'rename'
			title: 'Rename'
		},
		ui2.MenuEntry{
			id:    'duplicate'
			title: 'Duplicate'
		},
		ui2.MenuEntry{
			id:    'archive'
			title: 'Archive'
		},
	])
}

fn text_style(theme ui2.ComponentTheme, size f64, bold bool, muted bool) ui2.TextStyle {
	return ui2.TextStyle{
		color: if muted { theme.muted_foreground } else { theme.foreground }
		size:  size
		bold:  bold
	}
}

fn plain_button(id string, title string, frame ui2.Rect, theme ui2.ComponentTheme, pressed bool) ui2.Element {
	return ui2.button(id, title, frame, ui2.BoxStyle{
		bg:     if pressed { theme.border } else { theme.muted }
		radius: 6
	}, ui2.TextStyle{
		color: theme.foreground
		size:  14
		align: .center
	})
}

fn details_content(theme ui2.ComponentTheme) []ui2.Element {
	return [
		ui2.label('', 'Dimensions', ui2.rect(0, 0, 236, 20), text_style(theme, 15, true, false)),
		ui2.label('', 'Set the dimensions for the layer.', ui2.rect(0, 22, 236, 18),
			text_style(theme, 13, false, true)),
		ui2.label('', 'Width', ui2.rect(0, 50, 90, 20), text_style(theme, 13, false, false)),
		ui2.label('', '100%', ui2.rect(90, 50, 146, 20), text_style(theme, 13, true, false)),
		ui2.label('', 'Height', ui2.rect(0, 72, 90, 20), text_style(theme, 13, false, false)),
		ui2.label('', '25 px', ui2.rect(90, 72, 146, 20), text_style(theme, 13, true, false)),
		ui2.with_action(plain_button('details-close', 'Close', ui2.rect(156, 98, 80, 28),
			theme, false), ui2.popover_dismiss_action('details')),
	]
}

fn profile_content(theme ui2.ComponentTheme) []ui2.Element {
	return [
		ui2.avatar(
			id:    'profile-avatar'
			name:  'Ada Lovelace'
			frame: ui2.rect(0, 0, 44, 44)
			theme: theme
		) or {
			panic(err)
		},
		ui2.label('', 'Ada Lovelace', ui2.rect(56, 0, 220, 20), text_style(theme, 15, true, false)),
		ui2.label('', '@ada_lovelace', ui2.rect(56, 20, 220, 18), text_style(theme, 13, false,
			true)),
		ui2.label('', 'Wrote the first program for the Analytical Engine.', ui2.rect(56,
			42, 220, 36), ui2.TextStyle{
			color:  theme.foreground
			size:   13
			lines:  2
			valign: .top
		}),
	]
}

// Static popovers on all four sides of one anchor, and one that flips because
// the side it prefers has no room. They have no backdrop, so they stay open.
fn placement_demo(l Layout, theme ui2.ComponentTheme) []ui2.Element {
	panel := ui2.rect(l.left_x, 404, l.column, l.height - 404 - 24)
	mut children := [
		ui2.view('', panel, ui2.BoxStyle{
			bg:     theme.muted
			radius: 8
		}, []ui2.Element{}),
	]
	edge := ui2.rect(l.left_x + 12, panel.y + panel.height - 52, 92, 32)
	// The cross of four popovers sits centered above the edge demo.
	anchor := ui2.rect(panel.x + panel.width / 2 - 50, panel.y + (edge.y - panel.y) / 2 - 18,
		100, 36)
	children << ui2.view('', anchor, ui2.BoxStyle{
		bg:     theme.primary
		radius: 6
	}, [
		ui2.label('', 'Anchor', ui2.rect(0, 0, 100, 36), ui2.TextStyle{
			color: theme.primary_foreground
			size:  14
			bold:  true
			align: .center
		}),
	])
	for side in popover_sides {
		children << ui2.popover(
			id:                     'demo-${side_name(side).to_lower()}'
			open:                   true
			anchor:                 anchor
			window:                 ui2.rect(0, 0, l.width, l.height)
			width:                  84
			height:                 32
			side:                   side
			align:                  .center
			arrow:                  true
			padding:                0
			close_on_outside_click: false
			theme:                  theme
			children:               [
				ui2.label('', side_name(side), ui2.rect(0, 0, 84, 32), ui2.TextStyle{
					color: theme.foreground
					size:  13
					align: .center
				}),
			]
		) or { panic(err) }
	}
	children << ui2.view('', edge, ui2.BoxStyle{
		bg:     theme.foreground
		radius: 6
	}, [
		ui2.label('', 'Near the edge', ui2.rect(0, 0, 92, 32), ui2.TextStyle{
			color: theme.background
			size:  12
			align: .center
		}),
	])
	children << ui2.popover(
		id:                     'demo-flip'
		open:                   true
		anchor:                 edge
		window:                 ui2.rect(0, 0, l.width, l.height)
		width:                  220
		height:                 32
		side:                   .left
		align:                  .center
		arrow:                  true
		padding:                0
		close_on_outside_click: false
		theme:                  theme
		children:               [
			ui2.label('', 'Prefers the left; flipped right', ui2.rect(0, 0, 220, 32), ui2.TextStyle{
				color: theme.foreground
				size:  13
				align: .center
			}),
		]
	) or { panic(err) }
	return children
}

fn build() ui2.Element {
	app := gallery()
	theme := ui2.component_theme(app.dark)
	l := layout()
	win := ui2.rect(0, 0, l.width, l.height)
	mut children := [
		ui2.label('', 'Popovers, hover cards and menus', ui2.rect(24, 16, 520, 30),
			text_style(theme, 22, true, false)),
		ui2.link(
			id:    'theme'
			text:  'Light / dark'
			frame: ui2.rect(l.width - 124, 18, 100, 28)
			theme: theme
		) or { panic(err) },
		ui2.label('', app.status, ui2.rect(24, 52, l.width - 48, 20), text_style(theme, 13,
			false, true)),
		ui2.label('', 'Popover', ui2.rect(l.left_x, 92, l.column, 24), text_style(theme, 17,
			true, false)),
		ui2.label('', 'Each button opens the same controlled popover on its side. Click outside or press Escape to close it.',
			ui2.rect(l.left_x, 114, l.column, 34), ui2.TextStyle{
				color:  theme.muted_foreground
				size:   13
				lines:  2
				valign: .top
			}),
	]
	for index, side in popover_sides {
		children << plain_button('side-${side_name(side).to_lower()}', side_name(side), side_trigger_frame(l,
			index), theme, app.popover_open && app.popover_side == side)
	}
	children << ui2.label('', 'Placement, arrows and flipping', ui2.rect(l.left_x, 374,
		l.column, 24), text_style(theme, 17, true, false))
	children << placement_demo(l, theme)

	// Hover cards.
	children << ui2.label('', 'Hover card', ui2.rect(l.right_x, 92, l.column, 24), text_style(theme,
		17, true, false))
	children << ui2.label('', 'Rest the pointer on a trigger; move onto the card to keep it open.',
		ui2.rect(l.right_x, 114, l.column, 34), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   13
			lines:  2
			valign: .top
		})
	children << ui2.label('', 'Hover over', ui2.rect(l.right_x, 154, 76, 24), text_style(theme,
		14, false, false))
	children << ui2.hover_card_trigger('profile', ui2.link(
		id:        'profile-link'
		text:      '@ada_lovelace'
		action_id: 'open-profile'
		frame:     profile_trigger_frame(l)
		theme:     theme
	) or { panic(err) }) or { panic(err) }
	children << ui2.hover_card_trigger('fast', ui2.with_action(plain_button('fast-button',
		'Fast card (200 ms)', fast_trigger_frame(l), theme, app.fast.state.open), 'fast-clicked')) or {
		panic(err)
	}

	// Dropdown menus and buttons.
	children << ui2.label('', 'Dropdown menu and dropdown button', ui2.rect(l.right_x, 326,
		l.column, 24), text_style(theme, 17, true, false))
	children << ui2.label('', 'Arrow keys move, Right and Left enter and leave submenus, Enter chooses.',
		ui2.rect(l.right_x, 348, l.column, 34), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   13
			lines:  2
			valign: .top
		})
	children << ui2.dropdown_button(
		id:      'edit-button'
		menu_id: 'edit-menu'
		label:   'Edit'
		icon:    'pencil'
		open:    app.edit_menu.open
		frame:   edit_button_frame(l)
		theme:   theme
	) or { panic(err) }
	children << ui2.dropdown_button(
		id:        'save-button'
		menu_id:   'save-menu'
		label:     'Save'
		icon:      'square.and.arrow.down'
		split:     true
		action_id: 'save'
		open:      app.save_menu.open
		tone:      .primary
		frame:     save_button_frame(l)
		theme:     theme
	) or { panic(err) }
	children << ui2.dropdown_button(
		id:      'more-button'
		menu_id: 'more-menu'
		icon:    'ellipsis'
		outline: true
		open:    app.more_menu.open
		frame:   more_button_frame(l)
		theme:   theme
	) or { panic(err) }

	// Overlays last, so they are drawn over everything else.
	children << ui2.hover_card(
		id:       'profile'
		state:    app.profile.state
		anchor:   profile_trigger_frame(l)
		window:   win
		width:    300
		height:   104
		arrow:    true
		label:    'Ada Lovelace'
		children: profile_content(theme)
		theme:    theme
	) or { panic(err) }
	children << ui2.hover_card(
		id:       'fast'
		state:    app.fast.state
		anchor:   fast_trigger_frame(l)
		window:   win
		width:    220
		height:   64
		align:    .end
		children: [
			ui2.label('', 'Opens after 200 ms and closes 100 ms after the pointer leaves.',
				ui2.rect(0, 0, 196, 40), ui2.TextStyle{
					color:  theme.foreground
					size:   13
					lines:  2
					valign: .top
				}),
		]
		theme:    theme
	) or { panic(err) }
	side_index := popover_sides.index(app.popover_side)
	children << ui2.popover(
		id:       'details'
		open:     app.popover_open
		anchor:   side_trigger_frame(l, side_index)
		window:   win
		width:    260
		height:   150
		side:     app.popover_side
		arrow:    true
		label:    'Dimensions'
		children: details_content(theme)
		theme:    theme
	) or { panic(err) }
	children << ui2.dropdown_menu(
		id:     'edit-menu'
		state:  app.edit_menu
		items:  edit_items(app)
		anchor: edit_button_frame(l)
		window: win
		label:  'Edit'
		theme:  theme
	) or { panic(err) }
	children << ui2.dropdown_menu(
		id:     'save-menu'
		state:  app.save_menu
		items:  save_items()
		anchor: save_button_frame(l)
		window: win
		align:  .end
		label:  'Save options'
		theme:  theme
	) or { panic(err) }
	children << ui2.dropdown_menu(
		id:     'more-menu'
		state:  app.more_menu
		items:  more_items()
		anchor: more_button_frame(l)
		window: win
		align:  .end
		label:  'More'
		theme:  theme
	) or { panic(err) }
	return ui2.screen(theme.background, children)
}

// apply_card stores a hover card's next state and runs the timer work it asks
// for. A firing feeds the card its generation back; a stale one changes nothing.
fn apply_card(which string, step ui2.HoverCardStep) {
	mut app := gallery()
	mut slot := if which == 'profile' { app.profile } else { app.fast }
	slot.state = step.state
	if step.cancel {
		ui2.cancel_timer(slot.timer)
	}
	if step.schedule {
		generation := step.state.generation
		slot.timer = ui2.after(step.delay, fn [which, generation] () {
			latest := gallery()
			current := if which == 'profile' { latest.profile.state } else { latest.fast.state }
			apply_card(which, current.timer_fired(generation))
		})
	}
}

fn (mut app Gallery) chose(item ui2.DropdownMenuItem) {
	match item.id {
		'wrap' { app.word_wrap = !app.word_wrap }
		'name', 'date', 'size' { app.sort = item.id }
		else {}
	}
	app.status = 'Chose “${item.label}”.'
}

// handle returns whether the event changed anything.
fn (mut app Gallery) handle(event string) bool {
	if step := ui2.hover_card_step('profile', app.profile.state, event) {
		apply_card('profile', step)
		return true
	}
	if step := ui2.hover_card_step('fast', app.fast.state, event) {
		apply_card('fast', step)
		return true
	}
	if step := ui2.dropdown_menu_update('edit-menu', edit_items(app), app.edit_menu, event) {
		app.edit_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
		return true
	}
	if step := ui2.dropdown_menu_update('save-menu', save_items(), app.save_menu, event) {
		app.save_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
		return true
	}
	if step := ui2.dropdown_menu_update('more-menu', more_items(), app.more_menu, event) {
		app.more_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
		return true
	}
	if open := ui2.popover_open_from_action('details', app.popover_open, event) {
		app.popover_open = open
		return true
	}
	for side in popover_sides {
		if event == 'side-${side_name(side).to_lower()}' {
			app.popover_side = side
			app.popover_open = true
			return true
		}
	}
	match event {
		'theme' { app.dark = !app.dark }
		'save' { app.status = 'Saved.' }
		'open-profile' { app.status = 'Opened the profile of @ada_lovelace.' }
		'fast-clicked' { app.status = 'Clicked the fast card trigger.' }
		else { return false }
	}
	return true
}

fn on_event(event string) {
	mut app := gallery()
	if app.handle(event) {
		ui2.refresh()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut app := gallery()
	if step := ui2.dropdown_menu_key(edit_items(app), app.edit_menu, event) {
		app.edit_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
	} else if step := ui2.dropdown_menu_key(save_items(), app.save_menu, event) {
		app.save_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
	} else if step := ui2.dropdown_menu_key(more_items(), app.more_menu, event) {
		app.more_menu = step.state
		if step.chosen {
			app.chose(step.item)
		}
	} else if ui2.popover_dismiss_key(app.popover_open, event) {
		app.popover_open = false
	} else if event.code == .escape && app.profile.state.open {
		apply_card('profile', app.profile.state.dismissed())
	} else {
		return
	}
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	ui2.on_key_event(on_key)
	ui2.run_window('GPUI Kit popovers', 1040, 740, build, on_event)
}
