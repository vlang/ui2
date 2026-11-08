module main

import math
import time
import ui2

// An editor window drawn the way GPUI Kit apps draw theirs: an application
// title bar in place of the platform's, a toolbar under it, the document, and a
// status bar along the bottom. The panel on the right shows the bars in their
// other sizes and styles.

@[heap]
struct Demo {
mut:
	dark          bool
	chrome_hidden bool // set_window_chrome(.hidden_titlebar) succeeded
	last_click    ui2.TitleBarClick
	hover         map[string]string // Bar id -> the command under the pointer.
	tool_focus    string            // Keyboard focus in the main toolbar (F6 enters it).
	gallery_focus string = 'crop'
	align         string = 'left'
	preview       bool
	show_toolbar  bool = true
	show_status   bool = true
	search        string
	status        string = 'Ready'
	file_menu     ui2.DropdownMenuState
	edit_menu     ui2.DropdownMenuState
	view_menu     ui2.DropdownMenuState
	insert_menu   ui2.DropdownMenuState
	more_menu     ui2.DropdownMenuState
}

const demo_state = &Demo{}

fn demo() &Demo {
	return unsafe { demo_state }
}

const gallery_width = 460.0

fn theme_of(app &Demo) ui2.ComponentTheme {
	return ui2.component_theme(app.dark)
}

fn hover_of(app &Demo, bar string) string {
	return app.hover[bar] or { '' }
}

// ── Layout ──────────────────────────────────────────────────────────

struct Layout {
	width     f64
	height    f64
	title_h   f64
	toolbar_y f64
	toolbar_h f64
	content_y f64
	status_y  f64
	status_h  f64
}

fn layout_of(app &Demo) Layout {
	win := ui2.bounds()
	title_h := ui2.bar_metrics(.title_bar, .medium).height
	toolbar_h := if app.show_toolbar { 40.0 } else { 0.0 }
	status_h := if app.show_status { ui2.bar_metrics(.status_bar, .medium).height } else { 0.0 }
	return Layout{
		width:     win.width
		height:    win.height
		title_h:   title_h
		toolbar_y: title_h
		toolbar_h: toolbar_h
		content_y: title_h + toolbar_h
		status_y:  win.height - status_h
		status_h:  status_h
	}
}

// ── Menus ───────────────────────────────────────────────────────────

const menu_ids = ['menu-file', 'menu-edit', 'menu-view', 'menu-insert', 'menu-more']

fn menu_state(app &Demo, id string) ui2.DropdownMenuState {
	return match id {
		'menu-file' { app.file_menu }
		'menu-edit' { app.edit_menu }
		'menu-view' { app.view_menu }
		'menu-insert' { app.insert_menu }
		else { app.more_menu }
	}
}

fn (mut app Demo) set_menu(id string, value ui2.DropdownMenuState) {
	match id {
		'menu-file' { app.file_menu = value }
		'menu-edit' { app.edit_menu = value }
		'menu-view' { app.view_menu = value }
		'menu-insert' { app.insert_menu = value }
		else { app.more_menu = value }
	}
}

fn menu_items(app &Demo, id string) []ui2.DropdownMenuItem {
	return match id {
		'menu-file' {
			[
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('new', 'New')
					icon:     'doc.badge.plus'
					shortcut: 'cmd+n'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('open', 'Open…')
					icon:     'folder'
					shortcut: 'cmd+o'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('save', 'Save')
					icon:     'square.and.arrow.down'
					shortcut: 'cmd+s'
				},
				ui2.dropdown_menu_separator(),
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('quit', 'Quit')
					icon:     'power'
					shortcut: 'cmd+q'
				},
			]
		}
		'menu-edit' {
			[
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('undo', 'Undo')
					shortcut: 'cmd+z'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('redo', 'Redo')
					shortcut: 'cmd+shift+z'
				},
				ui2.dropdown_menu_separator(),
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
			]
		}
		'menu-view' {
			[
				ui2.dropdown_menu_checkbox('show-toolbar', 'Show toolbar', app.show_toolbar),
				ui2.dropdown_menu_checkbox('show-status', 'Show status bar', app.show_status),
				ui2.dropdown_menu_separator(),
				ui2.dropdown_menu_radio('light', 'Light', !app.dark),
				ui2.dropdown_menu_radio('dark', 'Dark', app.dark),
			]
		}
		'menu-insert' {
			[
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('image', 'Image…')
					icon: 'photo'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('table', 'Table')
					icon: 'tablecells'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('link', 'Link')
					icon:     'link'
					shortcut: 'cmd+k'
				},
			]
		}
		else {
			[
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('export', 'Export as PDF')
					icon: 'doc.badge.arrow.up'
				},
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('print', 'Print…')
					icon:     'printer'
					shortcut: 'cmd+p'
				},
				ui2.dropdown_menu_separator(),
				ui2.DropdownMenuItem{
					...ui2.dropdown_menu_item('info', 'Document info')
					icon: 'info.circle'
				},
			]
		}
	}
}

// A menu-bar button: a command whose action opens a dropdown menu, drawn
// pressed while the menu is open.
fn menu_button(app &Demo, id string, caption string, menu string) ui2.BarItem {
	return ui2.BarItem{
		...ui2.bar_command(id, caption, '')
		action_id: ui2.dropdown_menu_toggle_action(menu)
		selected:  menu_state(app, menu).open
	}
}

// ── Bars ────────────────────────────────────────────────────────────

fn title_config(app &Demo) ui2.TitleBarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	m := ui2.bar_metrics(.title_bar, .medium)
	logo := ui2.view('', ui2.rect(0, 1, 22, 22), ui2.BoxStyle{
		bg:     theme.primary
		radius: 6
	}, [
		ui2.Element{
			...ui2.image('', 'symbol:bolt', ui2.rect(4, 4, 14, 14))
			text_style: ui2.TextStyle{
				color: theme.primary_foreground
			}
		},
	])
	search := ui2.input_group(search_config(app, m.control)) or { panic(err) }
	return ui2.TitleBarConfig{
		id:       'titlebar'
		frame:    ui2.rect(0, 0, l.width, l.title_h)
		title:    'Quarterly report.md'
		leading:  [ui2.bar_custom('logo', 22, [logo]), menu_button(app, 'file', 'File', 'menu-file'),
			menu_button(app, 'edit', 'Edit', 'menu-edit'),
			menu_button(app, 'view', 'View', 'menu-view')]
		trailing: [ui2.bar_custom('search', 200, [search]),
			ui2.bar_icon_command('notifications', 'bell', 'Notifications'),
			ui2.bar_icon_command('settings', 'gearshape', 'Settings'), ui2.bar_icon_command('theme', if app.dark {
				'sun.max'
			} else {
				'moon'
			}, if app.dark {
				'Light theme'
			} else {
				'Dark theme'
			})]
		window:   ui2.title_bar_window(app.chrome_hidden)
		hovered:  hover_of(app, 'titlebar')
		theme:    theme
	}
}

fn search_config(app &Demo, height f64) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:          'search'
		frame:       ui2.rect(0, 0, 200, height)
		text:        app.search
		placeholder: 'Search'
		addons:      [
			ui2.InputGroupAddon{
				id:                  'icon'
				kind:                .icon
				icon:                'magnifyingglass'
				accessibility_label: 'Search'
			},
		]
		size:        .small
		theme:       theme_of(app)
	}
}

fn align_command(app &Demo, value string, icon string, tooltip string) ui2.BarItem {
	return ui2.BarItem{
		...ui2.bar_icon_command('align-${value}', icon, tooltip)
		selected: app.align == value
	}
}

fn toolbar_config(app &Demo) ui2.ToolbarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	return ui2.ToolbarConfig{
		id:      'toolbar'
		frame:   ui2.rect(0, l.toolbar_y, l.width, l.toolbar_h)
		label:   'Document'
		items:   [
			ui2.bar_command('new', 'New', 'plus'),
			ui2.bar_command('open', 'Open', 'folder'),
			ui2.bar_icon_command('save', 'square.and.arrow.down', 'Save'),
			ui2.bar_separator(),
			ui2.toolbar_group('history', 'History', [
				ui2.bar_icon_command('undo', 'arrow.uturn.backward', 'Undo'),
				ui2.bar_icon_command('redo', 'arrow.uturn.forward', 'Redo'),
			]),
			ui2.bar_separator(),
			ui2.toolbar_group('clipboard', 'Clipboard', [
				ui2.bar_icon_command('cut', 'scissors', 'Cut'),
				ui2.bar_icon_command('copy', 'doc.on.doc', 'Copy'),
				ui2.BarItem{
					...ui2.bar_icon_command('paste', 'doc.on.clipboard', 'Paste')
					enabled: false
				},
			]),
			ui2.bar_separator(),
			ui2.toolbar_group('alignment', 'Alignment', [
				align_command(app, 'left', 'text.alignleft', 'Align left'),
				align_command(app, 'center', 'align.horizontal.center', 'Center'),
				align_command(app, 'right', 'text.alignright', 'Align right'),
			]),
			ui2.bar_separator(),
			ui2.BarItem{
				...ui2.bar_command('insert', 'Insert', 'plus.rectangle')
				dropdown:  true
				action_id: ui2.dropdown_menu_toggle_action('menu-insert')
				selected:  app.insert_menu.open
			},
			ui2.BarItem{
				...ui2.bar_command('preview', 'Preview', 'eye')
				selected: app.preview
			},
			ui2.bar_spacer(),
			ui2.BarItem{
				...ui2.bar_label('Saved')
				icon:  'checkmark.circle'
				muted: true
			},
			ui2.bar_separator(),
			ui2.bar_command('share', 'Share', 'square.and.arrow.up'),
			ui2.BarItem{
				...ui2.bar_icon_command('more', 'ellipsis', 'More options')
				action_id: ui2.dropdown_menu_toggle_action('menu-more')
				selected:  app.more_menu.open
			},
		]
		hovered: hover_of(app, 'toolbar')
		focused: app.tool_focus
		style:   ui2.BarStyle{
			background: theme.background
			edges:      .bottom
		}
		size:    .medium
		theme:   theme
	}
}

fn status_config(app &Demo) ui2.StatusBarConfig {
	l := layout_of(app)
	return ui2.StatusBarConfig{
		id:       'status'
		frame:    ui2.rect(0, l.status_y, l.width, l.status_h)
		leading:  [
			ui2.bar_command('branch', 'main', 'arrow.triangle.2.circlepath'),
			ui2.bar_separator(),
			ui2.BarItem{
				...ui2.bar_label('0 problems')
				icon: 'checkmark.circle'
			},
		]
		center:   [
			ui2.BarItem{
				...ui2.bar_label(app.status)
				muted: true
			},
		]
		trailing: [
			ui2.BarItem{
				...ui2.bar_command('position', 'Ln 12, Col 4', '')
				tooltip: 'Go to Line/Column'
			},
			ui2.bar_separator(),
			ui2.bar_label('UTF-8'),
			ui2.bar_label('Markdown'),
			ui2.bar_icon_command('feedback', 'bubble.left', 'Send feedback'),
		]
		hovered:  hover_of(app, 'status')
		theme:    theme_of(app)
	}
}

// ── Gallery: the bars in other sizes and styles ─────────────────────

fn gallery_x(l Layout) f64 {
	return l.width - gallery_width + 20
}

fn gallery_toolbar(app &Demo, id string, y f64, size ui2.ComponentSize) ui2.ToolbarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	return ui2.ToolbarConfig{
		id:      id
		frame:   ui2.rect(gallery_x(l), y, gallery_width - 40, ui2.bar_metrics(.toolbar,
			size).height)
		items:   [
			ui2.BarItem{
				...ui2.bar_icon_command('pointer', 'cursorarrow', 'Select')
				selected: true
			},
			ui2.bar_icon_command('crop', 'crop', 'Crop'),
			ui2.bar_icon_command('brush', 'paintbrush', 'Brush'),
			ui2.bar_separator(),
			ui2.BarItem{
				...ui2.bar_command('zoom', '100%', '')
				dropdown: true
			},
			ui2.bar_spacer(),
			ui2.BarItem{
				...ui2.bar_label(match size {
					.small { 'Small' }
					.medium { 'Medium' }
					.large { 'Large' }
				})
				muted: true
			},
			ui2.bar_icon_command('adjust', 'slider.horizontal.3', 'Adjust'),
		]
		hovered: hover_of(app, id)
		focused: if size == .medium { app.gallery_focus } else { '' }
		style:   ui2.BarStyle{
			background: theme.background
			edges:      .all
			radius:     8
		}
		size:    size
		theme:   theme
	}
}

fn gallery_vertical(app &Demo, y f64) ui2.ToolbarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	return ui2.ToolbarConfig{
		id:          'tb-vertical'
		frame:       ui2.rect(gallery_x(l), y, 40, 196)
		orientation: .vertical
		items:       [
			ui2.BarItem{
				...ui2.bar_icon_command('v-pointer', 'cursorarrow', 'Select')
				selected: true
			},
			ui2.bar_icon_command('v-pencil', 'pencil', 'Draw'),
			ui2.bar_icon_command('v-text', 'textformat', 'Text'),
			ui2.bar_separator(),
			ui2.bar_icon_command('v-photo', 'photo', 'Image'),
			ui2.bar_spacer(),
			ui2.bar_icon_command('v-trash', 'trash', 'Delete'),
		]
		hovered:     hover_of(app, 'tb-vertical')
		label:       'Tools'
		style:       ui2.BarStyle{
			background: theme.background
			edges:      .all
			radius:     8
		}
		theme:       theme
	}
}

fn gallery_status(app &Demo, index int, y f64) ui2.StatusBarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	x := gallery_x(l) + 56
	width := gallery_width - 40 - 56
	card := ui2.BarStyle{
		edges:  .all
		radius: 6
	}
	return match index {
		0 {
			ui2.StatusBarConfig{
				id:       'sb-small'
				frame:    ui2.rect(x, y, width, ui2.bar_metrics(.status_bar, .small).height)
				leading:  [ui2.bar_label('Ready')]
				trailing: [ui2.bar_label('Spaces: 4'), ui2.bar_label('UTF-8'), ui2.bar_label('LF')]
				style:    card
				size:     .small
				theme:    theme
			}
		}
		1 {
			ui2.StatusBarConfig{
				id:     'sb-medium'
				frame:  ui2.rect(x, y, width, ui2.bar_metrics(.status_bar, .medium).height)
				center: [
					ui2.BarItem{
						...ui2.bar_label('Indexing')
						icon: 'clock'
					},
					ui2.bar_custom('progress', 96, [
						ui2.view('', ui2.rect(0, 7, 96, 6), ui2.BoxStyle{
							bg:     theme.border
							radius: 3
						}, [
							ui2.view('', ui2.rect(0, 0, 58, 6), ui2.BoxStyle{
								bg:     theme.primary
								radius: 3
							}, []ui2.Element{}),
						]),
					]),
					ui2.BarItem{
						...ui2.bar_label('60%')
						muted: true
					},
				]
				style:  card
				theme:  theme
			}
		}
		else {
			ui2.StatusBarConfig{
				id:      'sb-large'
				frame:   ui2.rect(x, y, width, ui2.bar_metrics(.status_bar, .large).height)
				leading: [ui2.bar_command('sync', 'Sync', 'arrow.clockwise')]
				center:  [
					ui2.BarItem{
						...ui2.bar_label('All changes saved')
						icon: 'icloud.and.arrow.up'
					},
				]
				hovered: hover_of(app, 'sb-large')
				style:   ui2.BarStyle{
					...card
					background: theme.primary
					foreground: theme.primary_foreground
					border:     theme.primary
				}
				size:    .large
				theme:   theme
			}
		}
	}
}

fn gallery_title(app &Demo, styled bool, y f64) ui2.TitleBarConfig {
	theme := theme_of(app)
	l := layout_of(app)
	size := if styled { ui2.ComponentSize.medium } else { ui2.ComponentSize.small }
	id := if styled { 'tt-styled' } else { 'tt-linux' }
	mut config := ui2.TitleBarConfig{
		id:       id
		frame:    ui2.rect(gallery_x(l), y, gallery_width - 40, ui2.bar_metrics(.title_bar,
			size).height)
		title:    if styled { 'Styled title bar' } else { 'Inbox — Mail' }
		leading:  [ui2.bar_icon_command('${id}-menu', 'line.3.horizontal', 'Menu')]
		trailing: [ui2.bar_icon_command('${id}-find', 'magnifyingglass', 'Search')]
		window:   ui2.TitleBarWindow{
			controls:  true
			maximized: styled
		}
		hovered:  hover_of(app, id)
		style:    ui2.BarStyle{
			edges:  .all
			radius: 8
		}
		size:     size
		theme:    theme
	}
	if styled {
		config = ui2.TitleBarConfig{
			...config
			style: ui2.BarStyle{
				background: theme.primary
				foreground: theme.primary_foreground
				border:     theme.primary
				edges:      .all
				radius:     8
			}
		}
	}
	return config
}

fn caption(text string, frame ui2.Rect, theme ui2.ComponentTheme, bold bool) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: if bold { theme.foreground } else { theme.muted_foreground }
		size:  if bold { 13 } else { 12 }
		bold:  bold
	})
}

fn gallery_elements(app &Demo, l Layout) []ui2.Element {
	theme := theme_of(app)
	x := gallery_x(l)
	width := gallery_width - 40
	mut c := []ui2.Element{}
	mut y := l.content_y + 18
	c << caption('Toolbar sizes', ui2.rect(x, y, width, 18), theme, true)
	y += 24
	for size in [ui2.ComponentSize.small, .medium, .large] {
		cfg := gallery_toolbar(app, 'tb-${size}', y, size)
		c << ui2.toolbar(cfg) or { panic(err) }
		y += cfg.frame.height + 10
	}
	c << caption('Medium shows keyboard focus; press F6 to focus the main toolbar.',
		ui2.rect(x, y - 4, width, 18), theme, false)
	y += 26
	c << caption('Vertical toolbar and status bars', ui2.rect(x, y, width, 18), theme, true)
	y += 24
	c << ui2.toolbar(gallery_vertical(app, y)) or { panic(err) }
	mut sy := y
	for index in 0 .. 3 {
		cfg := gallery_status(app, index, sy)
		c << ui2.status_bar(cfg) or { panic(err) }
		sy += cfg.frame.height + 8
	}
	c << ui2.label('', 'Small: items at both ends. Medium: center items only, from the start. Large: leading items only, so the center goes to the end.',
		ui2.rect(x + 56, sy, width - 56, 196 - (sy - y)), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			lines:  0
			valign: .top
		})
	y += 196 + 22
	c << caption('Title bars with drawn window buttons', ui2.rect(x, y, width, 18), theme,
		true)
	y += 24
	linux := gallery_title(app, false, y)
	c << ui2.title_bar(linux) or { panic(err) }
	y += linux.frame.height + 10
	c << ui2.title_bar(gallery_title(app, true, y)) or { panic(err) }
	return c
}

fn gallery_toolbar_ids() []string {
	return ['tb-small', 'tb-medium', 'tb-large']
}

// ── Document ────────────────────────────────────────────────────────

fn document_elements(app &Demo, l Layout) []ui2.Element {
	theme := theme_of(app)
	// A narrow window leaves the page no room rather than a negative one.
	page := ui2.rect(28, l.content_y + 24, math.max(l.width - gallery_width - 56, 0), math.max(l.status_y - l.content_y - 48,
		0))
	align := match app.align {
		'center' { ui2.Align.center }
		'right' { ui2.Align.right }
		else { ui2.Align.left }
	}
	inner := math.max(page.width - 64, 0)
	body := ui2.TextStyle{
		color:  theme.foreground
		size:   14
		lines:  0
		valign: .top
		align:  align
	}
	paragraphs := [
		'Revenue grew 18% over the quarter, driven by the new subscription plans and a stronger renewal rate among teams of more than fifty seats.',
		'Support volume fell for the second quarter in a row. Most of the remaining tickets concern data import, which the next release addresses.',
		'Next quarter we focus on onboarding: a guided setup, templates for common workflows, and in-product tips that disappear once used.',
	]
	mut children := [
		ui2.label('', 'Quarterly report', ui2.rect(32, 28, inner, 32), ui2.TextStyle{
			color: theme.foreground
			size:  24
			bold:  true
			align: align
		}),
		ui2.label('', 'Draft · Edited 2 minutes ago', ui2.rect(32, 62, inner, 20), ui2.TextStyle{
			color: theme.muted_foreground
			size:  13
			align: align
		}),
		ui2.view('', ui2.rect(32, 96, inner, 1), ui2.BoxStyle{
			bg: theme.border
		}, []ui2.Element{}),
	]
	mut y := 112.0
	for paragraph in paragraphs {
		children << ui2.label('', paragraph, ui2.rect(32, y, inner, 64), body)
		y += 76
	}
	if app.preview {
		children << ui2.tag(
			id:    'preview-tag'
			text:  'Preview'
			frame: ui2.rect(math.max(page.width - 100, 0), 28, 72, 24)
			tone:  .primary
			size:  .small
			theme: theme
		) or { panic(err) }
	}
	return [
		ui2.view('page', page, ui2.BoxStyle{
			bg:            theme.background
			radius:        10
			border_color:  theme.border
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			shadow:        ui2.component_card_shadow()
		}, children),
	]
}

// ── Build ───────────────────────────────────────────────────────────

fn build() ui2.Element {
	app := demo()
	theme := theme_of(app)
	l := layout_of(app)
	canvas := if app.dark { theme.background } else { u32(0xf6f7f9) }
	mut children := []ui2.Element{}
	children << ui2.view('', ui2.rect(0, l.content_y, l.width, math.max(l.status_y - l.content_y, 0)),
		ui2.BoxStyle{
			bg: canvas
		}, []ui2.Element{})
	children << document_elements(app, l)
	children << ui2.view('', ui2.rect(l.width - gallery_width, l.content_y, gallery_width,
		math.max(l.status_y - l.content_y, 0)), ui2.BoxStyle{
		bg:           theme.background
		border_color: theme.border
		border_left:  1
	}, gallery_shift(gallery_elements(app, l), l))
	title := title_config(app)
	children << ui2.title_bar(title) or { panic(err) }
	if app.show_toolbar {
		children << ui2.toolbar(toolbar_config(app)) or { panic(err) }
	}
	if app.show_status {
		children << ui2.status_bar(status_config(app)) or { panic(err) }
	}
	// Menus last, so they open over everything else.
	win := ui2.rect(0, 0, l.width, l.height)
	for id in menu_ids {
		state := menu_state(app, id)
		if !state.open {
			continue
		}
		anchor := menu_anchor(app, id) or { continue }
		children << ui2.dropdown_menu(
			id:     id
			state:  state
			items:  menu_items(app, id)
			anchor: anchor
			window: win
			align:  if id == 'menu-more' { ui2.PopoverAlign.end } else { ui2.PopoverAlign.start }
			label:  id['menu-'.len..].capitalize()
			theme:  theme
		) or { panic(err) }
	}
	return ui2.screen(canvas, children)
}

// gallery_shift makes the gallery's window-coordinate frames relative to the
// panel that holds them, which keeps every frame function in window space.
fn gallery_shift(elements []ui2.Element, l Layout) []ui2.Element {
	dx := l.width - gallery_width
	dy := l.content_y
	return elements.map(ui2.Element{
		...it
		frame: ui2.rect(it.frame.x - dx, it.frame.y - dy, it.frame.width, it.frame.height)
	})
}

fn menu_anchor(app &Demo, id string) ?ui2.Rect {
	return match id {
		'menu-file' { ui2.title_bar_item_frame(title_config(app), 'file') }
		'menu-edit' { ui2.title_bar_item_frame(title_config(app), 'edit') }
		'menu-view' { ui2.title_bar_item_frame(title_config(app), 'view') }
		'menu-insert' { ui2.toolbar_item_frame(toolbar_config(app), 'insert') }
		else { ui2.toolbar_item_frame(toolbar_config(app), 'more') }
	}
}

// ── Events ──────────────────────────────────────────────────────────

fn (mut app Demo) run(id string) {
	app.status = match id {
		'new' { 'New document' }
		'open' { 'Open a document…' }
		'save' { 'Saved' }
		'undo' { 'Undid typing' }
		'redo' { 'Redid typing' }
		'cut' { 'Cut the selection' }
		'copy' { 'Copied the selection' }
		'share' { 'Sharing link copied' }
		'branch' { 'On branch main' }
		'position' { 'Go to line…' }
		'feedback' { 'Thanks for the feedback' }
		'notifications' { 'No new notifications' }
		'settings' { 'Settings' }
		else { 'Ran ${id}' }
	}
	match id {
		'align-left', 'align-center', 'align-right' {
			app.align = id['align-'.len..]
			app.status = 'Aligned ${app.align}'
		}
		'preview' {
			app.preview = !app.preview
			app.status = if app.preview { 'Preview on' } else { 'Preview off' }
		}
		'theme' {
			app.dark = !app.dark
			app.status = if app.dark { 'Dark theme' } else { 'Light theme' }
		}
		else {}
	}
}

fn (mut app Demo) chose(item ui2.DropdownMenuItem) {
	match item.id {
		'quit' {
			ui2.quit()
		}
		'show-toolbar' {
			app.show_toolbar = !app.show_toolbar
			app.tool_focus = ''
		}
		'show-status' {
			app.show_status = !app.show_status
		}
		'light', 'dark' {
			app.dark = item.id == 'dark'
		}
		else {
			app.status = 'Chose “${item.label}”'
		}
	}
}

fn (mut app Demo) hover_bar(id string, next ?string) bool {
	value := next or { return false }
	app.hover[id] = value
	return true
}

// handle returns whether the event changed anything.
fn (mut app Demo) handle(event string) bool {
	for id in menu_ids {
		state := menu_state(app, id)
		if step := ui2.dropdown_menu_update(id, menu_items(app, id), state, event) {
			// Opening one menu closes the others, as in a menu bar.
			if step.state.open && !state.open {
				for other in menu_ids {
					app.set_menu(other, ui2.DropdownMenuState{})
				}
			}
			app.set_menu(id, step.state)
			if step.chosen {
				app.chose(step.item)
			}
			return true
		}
	}
	title := title_config(app)
	if app.hover_bar('titlebar', ui2.title_bar_hover_from_event(title, event)) {
		return true
	}
	if ev := ui2.title_bar_event(title, event, app.last_click, time.ticks()) {
		match ev.kind {
			.drag {
				app.last_click = ev.click
				ui2.start_window_drag()
				return false
			}
			.toggle_maximize {
				app.last_click = ev.click
				ui2.toggle_maximize_window()
			}
			.minimize {
				ui2.minimize_window()
			}
			.close {
				ui2.quit()
			}
			.command {
				app.run(ev.item.id)
			}
		}
		return true
	}
	if app.show_toolbar {
		tools := toolbar_config(app)
		if app.hover_bar('toolbar', ui2.toolbar_hover_from_event(tools, event)) {
			return true
		}
		if item := ui2.toolbar_item_from_action(tools, event) {
			app.tool_focus = ''
			app.run(item.id)
			return true
		}
	}
	if app.show_status {
		status := status_config(app)
		if app.hover_bar('status', ui2.status_bar_hover_from_event(status, event)) {
			return true
		}
		if item := ui2.status_bar_item_from_action(status, event) {
			app.run(item.id)
			return true
		}
	}
	return app.handle_gallery(event)
}

fn (mut app Demo) handle_gallery(event string) bool {
	l := layout_of(app)
	mut y := l.content_y + 42
	for index, size in [ui2.ComponentSize.small, .medium, .large] {
		cfg := gallery_toolbar(app, gallery_toolbar_ids()[index], y, size)
		y += cfg.frame.height + 10
		if app.hover_bar(cfg.id, ui2.toolbar_hover_from_event(cfg, event)) {
			return true
		}
		if item := ui2.toolbar_item_from_action(cfg, event) {
			if size == .medium {
				app.gallery_focus = item.id
			}
			app.status = '${item.id} in the ${size} toolbar'
			return true
		}
	}
	vertical := gallery_vertical(app, 0)
	if app.hover_bar(vertical.id, ui2.toolbar_hover_from_event(vertical, event)) {
		return true
	}
	if item := ui2.toolbar_item_from_action(vertical, event) {
		app.status = '${item.tooltip} tool'
		return true
	}
	large := gallery_status(app, 2, 0)
	if app.hover_bar(large.id, ui2.status_bar_hover_from_event(large, event)) {
		return true
	}
	if _ := ui2.status_bar_item_from_action(large, event) {
		app.status = 'Syncing…'
		return true
	}
	for styled in [false, true] {
		cfg := gallery_title(app, styled, 0)
		if app.hover_bar(cfg.id, ui2.title_bar_hover_from_event(cfg, event)) {
			return true
		}
		// These bars only show what a title bar reports; they leave the window alone.
		if ev := ui2.title_bar_event(cfg, event, ui2.TitleBarClick{}, time.ticks()) {
			if ev.kind != .drag {
				app.status = '${cfg.title}: ${ev.kind}'
				return true
			}
		}
	}
	return false
}

fn on_event(event string) {
	mut app := demo()
	if app.handle(event) {
		ui2.refresh()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut app := demo()
	for id in menu_ids {
		state := menu_state(app, id)
		if step := ui2.dropdown_menu_key(menu_items(app, id), state, event) {
			app.set_menu(id, step.state)
			if step.chosen {
				app.chose(step.item)
			}
			ui2.consume_key()
			ui2.refresh()
			return
		}
	}
	if !app.show_toolbar {
		return
	}
	tools := toolbar_config(app)
	if event.code == .f6 && !event.cmd && !event.ctrl && !event.alt {
		order := ui2.toolbar_focus_order(tools)
		if order.len > 0 {
			app.tool_focus = if app.tool_focus.len > 0 { '' } else { order[0] }
			ui2.consume_key()
			ui2.refresh()
		}
		return
	}
	step := ui2.toolbar_key(tools, event) or { return }
	app.tool_focus = step.focused
	if step.activated {
		// A command run from the keyboard does what its click does.
		app.handle(if step.item.action_id.len > 0 {
			step.item.action_id
		} else {
			ui2.bar_item_action(tools.id, step.item.id)
		})
		app.tool_focus = step.focused
	}
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	// The window does not exist until run_window starts, so hide its title bar
	// from the first build: a zero-second timer runs at the start of that build.
	ui2.after(0, fn () {
		mut app := demo()
		app.chrome_hidden = ui2.set_window_chrome(.hidden_titlebar)
	})
	ui2.on_key_event(on_key)
	ui2.run_window('Quarterly report', 1180, 780, build, on_event)
}
