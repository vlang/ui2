module main

import ui2

// A small project-tracker shell: a navigation sidebar on the left (it folds
// into an icon rail), an inspector sidebar on the right (it collapses off the
// canvas), and, in the page between them, a preview of a collapsed rail.
@[heap]
struct App {
mut:
	dark   bool
	status string = 'Click, hover and use the arrow keys in the left sidebar; every action is reported here.'
	// The navigation sidebar starts on "Mobile App", under Projects.
	nav                 ui2.SidebarState = ui2.SidebarState{
		active:   'mobile'
		expanded: ['projects']
	}
	nav_collapsed       bool
	nav_offset          f64
	inspector           ui2.SidebarState = ui2.SidebarState{
		active:        'layers'
		closed_groups: ['review']
	}
	inspector_collapsed bool
	rail                ui2.SidebarState = ui2.SidebarState{
		active: 'rail-inbox'
	}
	notifications       bool   = true
	organization        string = 'Acme Inc'
	// Menus opened from the sidebars: the organization switcher (header), the
	// account menu (footer), an item's ⋯ menu and a rail item's flyout.
	org_menu     ui2.DropdownMenuState
	account_menu ui2.DropdownMenuState
	item_menu    ui2.DropdownMenuState
	item_menu_of string
	flyout       ui2.DropdownMenuState
	flyout_of    string
	flyout_from  string // Which sidebar the flyout belongs to.
}

const app_state = &App{}

fn app() &App {
	return unsafe { app_state }
}

const nav_width = 264.0
const inspector_width = 248.0
const toolbar_height = 52.0
const preview_status_height = 28.0

// ── Sidebars ────────────────────────────────────────────────────────

fn nav_groups(app &App, theme ui2.ComponentTheme) []ui2.SidebarGroup {
	return [
		ui2.SidebarGroup{
			label: 'Platform'
			items: [
				ui2.SidebarItem{
					id:    'dashboard'
					label: 'Dashboard'
					icon:  'house'
				},
				ui2.SidebarItem{
					id:    'inbox'
					label: 'Inbox'
					icon:  'tray'
					badge: '12'
				},
				ui2.SidebarItem{
					id:       'projects'
					label:    'Projects'
					icon:     'folder'
					more:     true
					menu:     item_entries('projects')
					children: [
						ui2.SidebarItem{
							id:    'web'
							label: 'Web App'
							more:  true
							menu:  item_entries('web')
						},
						ui2.SidebarItem{
							id:    'mobile'
							label: 'Mobile App'
							more:  true
							menu:  item_entries('mobile')
						},
						ui2.SidebarItem{
							id:    'desktop'
							label: 'Desktop App'
							more:  true
							menu:  item_entries('desktop')
						},
					]
				},
				ui2.SidebarItem{
					id:         'analytics'
					label:      'Analytics'
					icon:       'chart.bar'
					dot:        true
					badge_tone: .danger
				},
				ui2.SidebarItem{
					id:     'calendar'
					label:  'Calendar'
					icon:   'calendar'
					suffix: '3 today'
				},
			]
		},
		ui2.SidebarGroup{
			id:          'workspace'
			label:       'Workspace'
			collapsible: true
			items:       [
				ui2.SidebarItem{
					id:    'documents'
					label: 'Documents'
					icon:  'doc'
					more:  true
					menu:  item_entries('documents')
				},
				ui2.SidebarItem{
					id:     'team'
					label:  'Team'
					icon:   'person.2'
					suffix: '1,234'
				},
				ui2.SidebarItem{
					id:    'messages'
					label: 'Messages'
					icon:  'bubble.left'
					badge: '3'
				},
				ui2.SidebarItem{
					id:      'archive'
					label:   'Archive'
					icon:    'tray'
					enabled: false
				},
			]
		},
		ui2.SidebarGroup{
			id:          'settings'
			label:       'Settings'
			collapsible: true
			items:       [
				ui2.SidebarItem{
					id:    'general'
					label: 'General'
					icon:  'gearshape'
				},
				ui2.SidebarItem{
					id:              'notifications'
					label:           'Notifications'
					icon:            'bell'
					accessory:       [
						ui2.switch_control(
							id:     'notifications-switch'
							frame:  ui2.rect(0, 6, 34, 20)
							active: app.notifications
							style:  ui2.SwitchStyle{
								active_track_color:   theme.primary
								inactive_track_color: theme.border
							}
						),
					]
					accessory_width: 34
				},
				ui2.SidebarItem{
					id:    'security'
					label: 'Security'
					icon:  'lock'
				},
				ui2.SidebarItem{
					id:    'billing'
					label: 'Billing'
					icon:  'creditcard'
				},
			]
		},
		ui2.SidebarGroup{
			id:          'favorites'
			label:       'Favorites'
			collapsible: true
			items:       [
				ui2.SidebarItem{
					id:    'design-system'
					label: 'Design system'
					icon:  'paintpalette'
				},
				ui2.SidebarItem{
					id:    'roadmap'
					label: 'Roadmap'
					icon:  'map'
				},
				ui2.SidebarItem{
					id:    'launch'
					label: 'Launch checklist'
					icon:  'checkmark.circle'
				},
			]
		},
	]
}

// nav_collapsed folds the sidebar into its rail when the user asked for it or
// the window is too narrow for it, as GPUI Kit's responsive sidebar does.
fn nav_collapsed(app &App) bool {
	return ui2.sidebar_auto_collapsed(ui2.bounds().width, ui2.sidebar_breakpoint, app.nav_collapsed)
}

// nav_open_menu is the item whose menu is open: its ⋯ button, or in the rail
// the item itself, is drawn pressed.
fn nav_open_menu(app &App) string {
	if app.item_menu.open {
		return app.item_menu_of
	}
	if app.flyout.open && app.flyout_from == 'nav' {
		return app.flyout_of
	}
	return ''
}

fn nav_config(app &App) ui2.SidebarConfig {
	theme := ui2.component_theme(app.dark)
	win := ui2.bounds()
	return ui2.SidebarConfig{
		id:          'nav'
		frame:       ui2.rect(0, 0, ui2.sidebar_width(nav_width, nav_collapsed(app), .icon,
			.medium), win.height)
		groups:      nav_groups(app, theme)
		header:      ui2.SidebarHeader{
			title:    app.organization
			subtitle: 'Enterprise'
			icon:     'bolt'
			menu:     true
		}
		footer:      ui2.SidebarFooter{
			title:    'Ada Lovelace'
			subtitle: 'ada@acme.dev'
			avatar:   'Ada Lovelace'
			menu:     true
		}
		state:       app.nav
		collapsed:   nav_collapsed(app)
		offset:      app.nav_offset
		open_menu:   nav_open_menu(app)
		header_open: app.org_menu.open
		footer_open: app.account_menu.open
		theme:       theme
	}
}

fn inspector_config(app &App) ui2.SidebarConfig {
	theme := ui2.component_theme(app.dark)
	win := ui2.bounds()
	width := ui2.sidebar_width(inspector_width, app.inspector_collapsed, .offcanvas,
		.medium)
	return ui2.SidebarConfig{
		id:          'inspector'
		frame:       ui2.rect(win.width - width, 0, width, win.height)
		side:        .right
		collapsible: .offcanvas
		collapsed:   app.inspector_collapsed
		header:      ui2.SidebarHeader{
			title:    'Inspector'
			subtitle: page_title(app)
			icon:     'slider.horizontal.3'
		}
		groups:      [
			ui2.SidebarGroup{
				label: 'Tools'
				items: [
					ui2.SidebarItem{
						id:    'layers'
						label: 'Layers'
						icon:  'square.2.layers.3d.top.filled'
					},
					ui2.SidebarItem{
						id:     'search'
						label:  'Search'
						icon:   'magnifyingglass'
						suffix: '⌘F'
					},
					ui2.SidebarItem{
						id:         'console'
						label:      'Console'
						icon:       'curlybraces'
						badge:      '2'
						badge_tone: .danger
					},
					ui2.SidebarItem{
						id:    'history'
						label: 'History'
						icon:  'clock'
					},
				]
			},
			ui2.SidebarGroup{
				id:          'review'
				label:       'Review'
				collapsible: true
				items:       [
					ui2.SidebarItem{
						id:         'comments'
						label:      'Comments'
						icon:       'text.bubble'
						badge:      '4'
						badge_tone: .neutral
					},
					ui2.SidebarItem{
						id:    'bookmarks'
						label: 'Bookmarks'
						icon:  'bookmark'
					},
				]
			},
			ui2.SidebarGroup{
				label: 'Share'
				items: [
					ui2.SidebarItem{
						id:    'link'
						label: 'Copy link'
						icon:  'link'
					},
					ui2.SidebarItem{
						id:    'export'
						label: 'Export'
						icon:  'square.and.arrow.up'
					},
				]
			},
		]
		state:       app.inspector
		theme:       theme
	}
}

// The rail preview sits in a card of the page; it is placed in window
// coordinates, over the card, so that its anchors are window coordinates too.
fn rail_config(app &App) ui2.SidebarConfig {
	theme := ui2.component_theme(app.dark)
	card := preview_card(layout())
	return ui2.SidebarConfig{
		id:        'rail'
		frame:     ui2.rect(card.x + 1, card.y + 41, ui2.sidebar_rail_width(.medium), card.height - 41 - preview_status_height)
		collapsed: true
		header:    ui2.SidebarHeader{
			title: 'Acme Inc'
			icon:  'bolt'
		}
		footer:    ui2.SidebarFooter{
			title:  'Ada Lovelace'
			avatar: 'Ada Lovelace'
		}
		groups:    [
			ui2.SidebarGroup{
				items: [
					ui2.SidebarItem{
						id:    'rail-home'
						label: 'Home'
						icon:  'house'
					},
					ui2.SidebarItem{
						id:    'rail-inbox'
						label: 'Inbox'
						icon:  'tray'
						badge: '3'
					},
					ui2.SidebarItem{
						id:       'rail-projects'
						label:    'Projects'
						icon:     'folder'
						children: [
							ui2.SidebarItem{
								id:    'rail-web'
								label: 'Web App'
								icon:  'globe'
							},
							ui2.SidebarItem{
								id:    'rail-mobile'
								label: 'Mobile App'
								icon:  'phone'
							},
						]
					},
				]
			},
			ui2.SidebarGroup{
				items: [
					ui2.SidebarItem{
						id:    'rail-calendar'
						label: 'Calendar'
						icon:  'calendar'
					},
					ui2.SidebarItem{
						id:    'rail-settings'
						label: 'Settings'
						icon:  'gearshape'
					},
				]
			},
		]
		state:     app.rail
		open_menu: if app.flyout.open && app.flyout_from == 'rail' { app.flyout_of } else { '' }
		theme:     theme
	}
}

// ── Menus ───────────────────────────────────────────────────────────

fn org_items(app &App) []ui2.DropdownMenuItem {
	return [
		ui2.dropdown_menu_heading('Organizations'),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_radio('Acme Inc', 'Acme Inc', app.organization == 'Acme Inc')
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_radio('Globex', 'Globex', app.organization == 'Globex')
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_radio('Initech', 'Initech', app.organization == 'Initech')
		},
		ui2.dropdown_menu_separator(),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('new-org', 'Create organization')
			icon: 'plus'
		},
	]
}

fn account_items() []ui2.DropdownMenuItem {
	return [
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('profile', 'Profile')
			icon: 'person'
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('account-billing', 'Billing')
			icon: 'creditcard'
		},
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('account-notifications', 'Notifications')
			icon: 'bell'
		},
		ui2.dropdown_menu_separator(),
		ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item('sign-out', 'Sign out')
			icon: 'rectangle.portrait.and.arrow.right'
		},
	]
}

const item_actions = [
	['open', 'Open in new window', 'arrow.up.right.square'],
	['rename', 'Rename', 'pencil'],
	['share', 'Share', 'square.and.arrow.up'],
	['delete', 'Delete', 'trash'],
]

// item_entries is an item's native right-click menu (AppKit and Windows). Its
// entries emit their own ids, so each names the item it acts on.
fn item_entries(item_id string) []ui2.MenuEntry {
	return item_actions.map(ui2.MenuEntry{
		id:    'item-menu:${it[0]}:${item_id}'
		title: it[1]
	})
}

// The ⋯ menu holds the same actions, on every renderer.
fn item_menu_items() []ui2.DropdownMenuItem {
	mut rows := []ui2.DropdownMenuItem{}
	for index, action in item_actions {
		if index == item_actions.len - 1 {
			rows << ui2.dropdown_menu_separator()
		}
		rows << ui2.DropdownMenuItem{
			...ui2.dropdown_menu_item(action[0], action[1])
			icon: action[2]
		}
	}
	return rows
}

fn flyout_config(app &App) ui2.SidebarConfig {
	return if app.flyout_from == 'rail' { rail_config(app) } else { nav_config(app) }
}

fn flyout_items(app &App) []ui2.DropdownMenuItem {
	if app.flyout_of.len == 0 {
		return []ui2.DropdownMenuItem{}
	}
	return ui2.sidebar_flyout_items(flyout_config(app), app.flyout_of)
}

// ── Page ────────────────────────────────────────────────────────────

struct Layout {
	width   f64
	height  f64
	left    f64 // The page between the sidebars.
	right   f64
	padding f64
}

fn layout() Layout {
	model := app()
	win := ui2.bounds()
	left := ui2.sidebar_width(nav_width, nav_collapsed(model), .icon, .medium)
	right := win.width - ui2.sidebar_width(inspector_width, model.inspector_collapsed,
		.offcanvas, .medium)
	return Layout{
		width:   win.width
		height:  win.height
		left:    left
		right:   right
		padding: 28
	}
}

fn preview_card(l Layout) ui2.Rect {
	x := l.left + l.padding
	y := toolbar_height + 236
	return ui2.rect(x, y, l.right - l.padding - x, l.height - y - l.padding)
}

fn page_title(app &App) string {
	labels := {
		'dashboard':     'Dashboard'
		'inbox':         'Inbox'
		'projects':      'Projects'
		'web':           'Web App'
		'mobile':        'Mobile App'
		'desktop':       'Desktop App'
		'analytics':     'Analytics'
		'calendar':      'Calendar'
		'documents':     'Documents'
		'team':          'Team'
		'messages':      'Messages'
		'general':       'General'
		'notifications': 'Notifications'
		'security':      'Security'
		'billing':       'Billing'
		'design-system': 'Design system'
		'roadmap':       'Roadmap'
		'launch':        'Launch checklist'
	}
	return labels[app.nav.active] or { 'Home' }
}

fn text_style(color u32, size f64, bold bool) ui2.TextStyle {
	return ui2.TextStyle{
		color: color
		size:  size
		bold:  bold
	}
}

fn icon_button(id string, symbol string, frame ui2.Rect, tip string, theme ui2.ComponentTheme) ui2.Element {
	return ui2.with_tooltip(ui2.button_view(id, frame, ui2.BoxStyle{
		bg:            theme.background
		radius:        6
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.Element{
			...ui2.image('', 'symbol:' + symbol, ui2.rect((frame.width - 16) / 2, (frame.height - 16) / 2,
				16, 16))
			text_style: ui2.TextStyle{
				color: theme.foreground
			}
		},
	]), tip)
}

fn stat_card(frame ui2.Rect, title string, value string, note string, theme ui2.ComponentTheme) ui2.Element {
	return ui2.view('', frame, ui2.BoxStyle{
		bg:            theme.background
		radius:        10
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.label('', title, ui2.rect(16, 14, frame.width - 32, 18), text_style(theme.muted_foreground,
			13, false)),
		ui2.label('', value, ui2.rect(16, 36, frame.width - 32, 32), text_style(theme.foreground,
			24, true)),
		ui2.label('', note, ui2.rect(16, 70, frame.width - 32, 18), text_style(theme.muted_foreground,
			12, false)),
	])
}

fn toolbar(app &App, l Layout, theme ui2.ComponentTheme) []ui2.Element {
	width := l.right - l.left
	mut children := []ui2.Element{}
	children << ui2.sidebar_toggle_button(
		id:         'nav-toggle'
		sidebar_id: 'nav'
		frame:      ui2.rect(12, 10, 32, 32)
		collapsed:  nav_collapsed(app)
		hovered:    ui2.sidebar_toggle_hovered(app.nav, 'nav')
		theme:      theme
	) or { panic(err) }
	children << ui2.view('', ui2.rect(52, 16, 1, 20), ui2.BoxStyle{ bg: theme.border }, []ui2.Element{})
	children << ui2.breadcrumb(
		id:    'trail'
		frame: ui2.rect(62, 10, 320, 32)
		items: [
			ui2.BreadcrumbItem{
				id:    'org'
				label: app.organization
			},
			ui2.BreadcrumbItem{
				id:    'page'
				label: page_title(app)
			},
		]
		theme: theme
	) or { panic(err) }
	children << icon_button('theme', if app.dark { 'sun.max' } else { 'moon' }, ui2.rect(width - 84,
		10, 32, 32), if app.dark { 'Light mode' } else { 'Dark mode' }, theme)
	children << ui2.sidebar_toggle_button(
		id:         'inspector-toggle'
		sidebar_id: 'inspector'
		frame:      ui2.rect(width - 44, 10, 32, 32)
		collapsed:  app.inspector_collapsed
		side:       .right
		hovered:    ui2.sidebar_toggle_hovered(app.inspector, 'inspector')
		label:      if app.inspector_collapsed { 'Show inspector' } else { 'Hide inspector' }
		theme:      theme
	) or { panic(err) }
	return [
		ui2.view('toolbar', ui2.rect(l.left, 0, width, toolbar_height), ui2.BoxStyle{
			bg: theme.background
		}, children),
		ui2.view('', ui2.rect(l.left, toolbar_height - 1, width, 1), ui2.BoxStyle{
			bg: ui2.sidebar_colors(theme).border
		}, []ui2.Element{}),
	]
}

fn page(app &App, l Layout, theme ui2.ComponentTheme) []ui2.Element {
	x := l.left + l.padding
	width := l.right - l.padding - x
	mut children := []ui2.Element{}
	children << ui2.label('', page_title(app), ui2.rect(x, toolbar_height + 24, width, 34),
		text_style(theme.foreground, 26, true))
	children << ui2.label('', app.status, ui2.rect(x, toolbar_height + 60, width, 20),
		text_style(theme.muted_foreground, 13, false))
	gap := 16.0
	card_width := (width - 2 * gap) / 3
	stats := [
		['Open issues', '24', '6 assigned to you'],
		['Pull requests', '7', '2 waiting for review'],
		['Deploys this week', '12', 'Last one 2 hours ago'],
	]
	for index, stat in stats {
		children << stat_card(ui2.rect(x + f64(index) * (card_width + gap), toolbar_height +
			100, card_width, 96), stat[0], stat[1], stat[2], theme)
	}
	children << ui2.label('', 'Keys: ↑ ↓ move through the left sidebar, ← → fold and unfold, Enter opens, Esc hides the cursor.',
		ui2.rect(x, toolbar_height + 208, width, 18), text_style(theme.muted_foreground,
			12, false))
	// The rail preview: a window frame whose rail is built separately (rail_config).
	card := preview_card(l)
	colors := ui2.sidebar_colors(theme)
	mut lines := []ui2.Element{}
	content_x := ui2.sidebar_rail_width(.medium) + 24
	content_width := card.width - content_x - 24
	lines << ui2.label('', 'Collapsed to an icon rail', ui2.rect(content_x, 64, content_width,
		24), text_style(theme.foreground, 17, true))
	lines << ui2.label('', 'Rest the pointer on an icon for its label. Projects has sub-items, so it opens them in a flyout menu.',
		ui2.rect(content_x, 92, content_width, 36), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   13
			lines:  2
			valign: .top
		})
	for index, fraction in [0.92, 0.78, 0.86, 0.6] {
		lines << ui2.view('', ui2.rect(content_x, 146 + f64(index) * 22, content_width * fraction,
			10), ui2.BoxStyle{
			bg:     theme.muted
			radius: 5
		}, []ui2.Element{})
	}
	children << ui2.view('preview', card, ui2.BoxStyle{
		bg:            theme.background
		radius:        10
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.view('', ui2.rect(1, 1, card.width - 2, 40), ui2.BoxStyle{
			bg:     colors.background
			radius: 9
		}, [
			ui2.view('', ui2.rect(14, 15, 10, 10), ui2.BoxStyle{
				bg:     0xef4444
				radius: 5
			}, []ui2.Element{}),
			ui2.view('', ui2.rect(30, 15, 10, 10), ui2.BoxStyle{
				bg:     0xf59e0b
				radius: 5
			}, []ui2.Element{}),
			ui2.view('', ui2.rect(46, 15, 10, 10), ui2.BoxStyle{
				bg:     0x22c55e
				radius: 5
			}, []ui2.Element{}),
			ui2.label('', 'Preview', ui2.rect(0, 0, card.width - 2, 40), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
				align: .center
			}),
		]),
		ui2.view('', ui2.rect(1, 40, card.width - 2, 1), ui2.BoxStyle{ bg: colors.border },
			[]ui2.Element{}),
		ui2.view('', ui2.rect(0, 41, card.width, card.height - 41), ui2.BoxStyle{
			transparent: true
		}, lines),
		// A status bar, which keeps the rail clear of the card's rounded corners.
		ui2.view('', ui2.rect(1, card.height - preview_status_height, card.width - 2, 1),
			ui2.BoxStyle{ bg: colors.border }, []ui2.Element{}),
		ui2.label('', 'Synced · 5 items', ui2.rect(16, card.height - preview_status_height + 1,
			card.width - 32, preview_status_height - 2), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
	])
	return children
}

fn build() ui2.Element {
	model := app()
	theme := ui2.component_theme(model.dark)
	l := layout()
	win := ui2.bounds()
	mut children := []ui2.Element{}
	children << toolbar(model, l, theme)
	children << page(model, l, theme)
	nav := nav_config(model)
	inspector := inspector_config(model)
	rail := rail_config(model)
	children << ui2.sidebar(nav) or { panic(err) }
	children << ui2.sidebar(inspector) or { panic(err) }
	children << ui2.sidebar(rail) or { panic(err) }

	// Menus last, over everything else.
	rail_mode := nav_collapsed(model)
	children << ui2.dropdown_menu(
		id:     'org-menu'
		state:  model.org_menu
		items:  org_items(model)
		anchor: ui2.sidebar_header_anchor(nav) or { ui2.rect(0, 0, 0, 0) }
		window: win
		side:   if rail_mode { ui2.PopoverSide.right } else { .bottom }
		label:  'Organizations'
		theme:  theme
	) or { panic(err) }
	children << ui2.dropdown_menu(
		id:     'account-menu'
		state:  model.account_menu
		items:  account_items()
		anchor: ui2.sidebar_footer_anchor(nav) or { ui2.rect(0, 0, 0, 0) }
		window: win
		side:   if rail_mode { ui2.PopoverSide.right } else { .top }
		align:  if rail_mode { ui2.PopoverAlign.end } else { .start }
		width:  if rail_mode { 0 } else { nav_width - 16 }
		label:  'Account'
		theme:  theme
	) or { panic(err) }
	children << ui2.dropdown_menu(
		id:     'item-menu'
		state:  model.item_menu
		items:  item_menu_items()
		anchor: ui2.sidebar_more_anchor(nav, model.item_menu_of) or { ui2.rect(0, 0, 0, 0) }
		window: win
		side:   .right
		label:  'Item actions'
		theme:  theme
	) or { panic(err) }
	flyout_source := flyout_config(model)
	children << ui2.dropdown_menu(
		id:     'flyout'
		state:  model.flyout
		items:  flyout_items(model)
		anchor: ui2.sidebar_item_anchor(flyout_source, model.flyout_of) or { ui2.rect(0, 0, 0, 0) }
		window: win
		side:   .right
		offset: 6
		label:  'Sub-items'
		theme:  theme
	) or { panic(err) }
	return ui2.screen(theme.background, children)
}

// ── Events ──────────────────────────────────────────────────────────

fn (mut app App) apply_nav(step ui2.SidebarStep) {
	app.nav = step.state
	match step.event {
		.activate {
			app.status = 'Opened ${step.item.label}.'
		}
		.expand {
			app.status = '${if step.item.id in app.nav.expanded { 'Expanded' } else { 'Collapsed' }} ${step.item.label}.'
		}
		.group {
			app.status = '${if step.group.id in app.nav.closed_groups {
				'Folded'
			} else {
				'Unfolded'
			}} ${step.group.label}.'
		}
		.collapse {
			app.nav_collapsed = step.collapsed
			app.nav_offset = 0
			app.status = if step.collapsed {
				'Collapsed the sidebar to icons.'
			} else {
				'Expanded the sidebar.'
			}
		}
		.header {
			app.org_menu = app.org_menu.toggled()
		}
		.footer {
			app.account_menu = app.account_menu.toggled()
		}
		.more {
			app.item_menu_of = step.item.id
			app.item_menu = app.item_menu.opened()
		}
		.flyout {
			app.flyout_of = step.item.id
			app.flyout_from = 'nav'
			app.flyout = app.flyout.opened()
		}
		else {}
	}
}

fn (mut app App) chose_flyout(item ui2.DropdownMenuItem) {
	if app.flyout_from == 'rail' {
		if next := ui2.sidebar_select(rail_config(app), item.id) {
			app.rail = next
		}
	} else if next := ui2.sidebar_select(nav_config(app), item.id) {
		app.nav = next
	}
	app.status = 'Opened ${item.label} from the flyout.'
}

// handle returns whether the event changed anything.
fn (mut app App) handle(event string) bool {
	if step := ui2.dropdown_menu_update('org-menu', org_items(app), app.org_menu, event) {
		app.org_menu = step.state
		if step.chosen {
			if step.item.id == 'new-org' {
				app.status = 'Create an organization.'
			} else {
				app.organization = step.item.id
				app.status = 'Switched to ${step.item.id}.'
			}
		}
		return true
	}
	if step := ui2.dropdown_menu_update('account-menu', account_items(), app.account_menu,
		event)
	{
		app.account_menu = step.state
		if step.chosen {
			app.status = 'Chose “${step.item.label}” from the account menu.'
		}
		return true
	}
	if step := ui2.dropdown_menu_update('item-menu', item_menu_items(), app.item_menu, event) {
		app.item_menu = step.state
		if step.chosen {
			app.status = 'Chose “${step.item.label}” for ${app.item_menu_of}.'
		}
		return true
	}
	if step := ui2.dropdown_menu_update('flyout', flyout_items(app), app.flyout, event) {
		app.flyout = step.state
		if step.chosen {
			app.chose_flyout(step.item)
		}
		return true
	}
	if step := ui2.sidebar_update(nav_config(app), event) {
		app.apply_nav(step)
		return true
	}
	if step := ui2.sidebar_update(inspector_config(app), event) {
		app.inspector = step.state
		match step.event {
			.activate { app.status = 'Inspector: ${step.item.label}.' }
			.collapse { app.inspector_collapsed = step.collapsed }
			else {}
		}
		return true
	}
	if step := ui2.sidebar_update(rail_config(app), event) {
		app.rail = step.state
		match step.event {
			.activate {
				app.status = 'Rail: opened ${step.item.label}.'
			}
			.flyout {
				app.flyout_of = step.item.id
				app.flyout_from = 'rail'
				app.flyout = app.flyout.opened()
			}
			else {}
		}
		return true
	}
	// A native right-click menu entry: item-menu:<action>:<item>.
	if event.starts_with('item-menu:') {
		parts := event.split_nth(':', 3)
		for action in item_actions {
			if parts.len == 3 && parts[1] == action[0] {
				app.status = 'Chose “${action[1]}” for ${parts[2]} from its context menu.'
				return true
			}
		}
		return false
	}
	match event {
		'theme' {
			app.dark = !app.dark
		}
		'notifications-switch' {
			app.notifications = !app.notifications
			app.status = 'Notifications ${if app.notifications { 'on' } else { 'off' }}.'
		}
		else {
			return false
		}
	}
	return true
}

fn on_event(event string) {
	mut model := app()
	if model.handle(event) {
		ui2.refresh()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut model := app()
	if step := ui2.dropdown_menu_key(org_items(model), model.org_menu, event) {
		model.org_menu = step.state
		if step.chosen && step.item.id != 'new-org' {
			model.organization = step.item.id
		}
	} else if step := ui2.dropdown_menu_key(account_items(), model.account_menu, event) {
		model.account_menu = step.state
	} else if step := ui2.dropdown_menu_key(item_menu_items(), model.item_menu, event) {
		model.item_menu = step.state
	} else if step := ui2.dropdown_menu_key(flyout_items(model), model.flyout, event) {
		model.flyout = step.state
		if step.chosen {
			model.chose_flyout(step.item)
		}
	} else if step := ui2.sidebar_key(nav_config(model), event) {
		model.apply_nav(step)
		ui2.consume_key()
		ui2.refresh()
		if step.reveal {
			// After the refresh, so the scroll has its new range.
			if offset := ui2.sidebar_reveal_offset(nav_config(model), model.nav.focused) {
				model.nav_offset = offset
				ui2.scroll_to_offset(ui2.sidebar_scroll_id('nav'), offset)
			}
		}
		return
	} else {
		return
	}
	ui2.consume_key()
	ui2.refresh()
}

fn on_scroll(id string) {
	if id == ui2.sidebar_scroll_id('nav') {
		mut model := app()
		model.nav_offset = ui2.scroll_offset(id)
	}
}

fn main() {
	ui2.on_key_event(on_key)
	ui2.on_scroll(on_scroll)
	ui2.run_window('GPUI Kit sidebar', 1280, 800, build, on_event)
}
