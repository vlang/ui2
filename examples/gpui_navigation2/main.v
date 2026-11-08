module main

import os
import ui2

// A gallery of the tab bar and the themed tree view after GPUI Kit's Tabs and
// Tree: every tab variant and size, icons, badges, prefix and suffix
// elements, closable and reorderable tabs, a bar that overflows into a scroll
// and a tab menu, themed tabbed panels, and trees with multiple selection,
// check boxes, lazily loaded folders, dragging, filtering and ten thousand
// virtualized nodes. The application owns every state: events go to each
// component's decoder, keys to its key helper, scroll positions come from
// on_scroll. GPUI_NAVIGATION2_PAGE=tree opens the tree page and
// GPUI_NAVIGATION2_DARK=1 the dark theme.

const window_width = 1280
const window_height = 860
const top = 140.0

struct Doc {
	id   string
	name string
	icon string
}

@[heap]
struct Gallery {
mut:
	dark     bool
	page     string = 'tabs'
	status   string = 'Click a tab bar, then use the arrow keys, Home and End, or Ctrl+Tab.'
	focus    string = 'variant-tab'
	bars     map[string]ui2.TabBarState
	offsets  map[string]f64
	docs     []Doc = [
		Doc{'main', 'main.v', 'doc.text.fill'},
		Doc{'readme', 'README.md', 'doc'},
		Doc{'tabs', 'tab_bar.v', 'curlybraces'},
		Doc{'makefile', 'Makefile', 'gearshape'},
	]
	untitled int
	// Themed tabbed panels.
	side_current int
	side_hovered int = -1
	top_current  int = 1
	top_hovered  int = -1
	// Trees.
	files        []ui2.TreeViewNode
	files_state  ui2.TreeViewState
	files_offset f64
	query        string
	checks       []ui2.TreeViewNode
	checks_state ui2.TreeViewState
	big          []ui2.TreeViewNode
	big_state    ui2.TreeViewState
	big_offset   f64
	big_built    ui2.VirtualListRange
	legacy       []ui2.TreeViewNode
	// Work for after the rebuild.
	scroll_id         string
	scroll_to         f64
	scroll_horizontal bool
}

const gallery_state = &Gallery{}

fn gallery() &Gallery {
	return unsafe { gallery_state }
}

// ── Layout ──────────────────────────────────────────────────────────

struct Layout {
	width  f64
	height f64
	half   f64
	left   f64
	right  f64
	third  f64
}

fn layout() Layout {
	win := ui2.bounds()
	return layout_for(win.width, win.height)
}

fn layout_for(width f64, height f64) Layout {
	half := (width - 72) / 2
	return Layout{
		width:  width
		height: height
		half:   half
		left:   24
		right:  48 + half
		third:  (width - 96) / 3
	}
}

fn text_style(theme ui2.ComponentTheme, size f64, bold bool, muted bool) ui2.TextStyle {
	return ui2.TextStyle{
		color: if muted { theme.muted_foreground } else { theme.foreground }
		size:  size
		bold:  bold
	}
}

fn heading(theme ui2.ComponentTheme, caption string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', caption, ui2.rect(x, y, width, 24), text_style(theme, 16, true, false))
}

fn caption(theme ui2.ComponentTheme, words string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', words, ui2.rect(x, y, width, 18), text_style(theme, 12, false, true))
}

fn note(theme ui2.ComponentTheme, words string, frame ui2.Rect) ui2.Element {
	return ui2.label('', words, frame, ui2.TextStyle{
		color:  theme.muted_foreground
		size:   13
		lines:  2
		valign: .top
	})
}

fn icon_button(id string, icon string, tip string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.Element{
		...ui2.styled_button(
			id:                  id
			frame:               frame
			icon:                icon
			variant:             .ghost
			size:                .small
			accessibility_label: tip
			theme:               theme
		) or { panic(err) }
		tooltip: tip
	}
}

// ── Tab bars ────────────────────────────────────────────────────────

fn (app &Gallery) bar_state(id string, fallback string) ui2.TabBarState {
	return app.bars[id] or {
		ui2.TabBarState{
			selected: fallback
		}
	}
}

fn account_items() []ui2.TabBarItem {
	return [
		ui2.tab_bar_item('account', 'Account'),
		ui2.tab_bar_item('profile', 'Profile'),
		ui2.tab_bar_item('documents', 'Documents'),
		ui2.tab_bar_item('mail', 'Mail'),
		ui2.TabBarItem{
			id:      'billing'
			label:   'Billing'
			enabled: false
		},
	]
}

const variants = [ui2.TabVariant.tab, .outline, .pill, .segmented, .underline, .folder]

fn variant_name(variant ui2.TabVariant) string {
	return match variant {
		.tab { 'tab' }
		.outline { 'outline' }
		.pill { 'pill' }
		.segmented { 'segmented' }
		.underline { 'underline' }
		.folder { 'folder' }
	}
}

fn variant_top(index int) f64 {
	return top + 32 + f64(index) * 62
}

fn page_bar(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TabBarConfig {
	return ui2.TabBarConfig{
		id:                  'pages'
		frame:               ui2.rect(24, 84, l.width - 48, ui2.tab_bar_height(.underline,
			.medium))
		items:               [
			ui2.TabBarItem{
				id:    'tabs'
				label: 'Tabs'
				icon:  'rectangle.3.group'
			},
			ui2.TabBarItem{
				id:    'tree'
				label: 'Tree'
				icon:  'list.bullet'
			},
		]
		state:               app.bar_state('pages', app.page)
		variant:             .underline
		accessibility_label: 'Gallery pages'
		theme:               theme
	}
}

fn tab_page_bars(app &Gallery, theme ui2.ComponentTheme, l Layout) []ui2.TabBarConfig {
	mut bars := []ui2.TabBarConfig{}
	for index, variant in variants {
		id := 'variant-${variant_name(variant)}'
		bars << ui2.TabBarConfig{
			id:                  id
			frame:               ui2.rect(l.left, variant_top(index) + 20, l.half, ui2.tab_bar_height(variant,
				.medium))
			items:               account_items()
			state:               app.bar_state(id, 'account')
			variant:             variant
			accessibility_label: '${variant_name(variant)} tabs'
			theme:               theme
		}
	}
	sizes := [ui2.ComponentSize.small, .medium, .large]
	mut y := variant_top(variants.len) + 32
	for size in sizes {
		id := 'size-${size}'
		height := ui2.tab_bar_height(.outline, size)
		bars << ui2.TabBarConfig{
			id:      id
			frame:   ui2.rect(l.left, y, l.half, height)
			items:   [
				ui2.TabBarItem{
					id:    'home'
					label: 'Home'
					icon:  'house'
				},
				ui2.TabBarItem{
					id:    'search'
					label: 'Search'
					icon:  'magnifyingglass'
				},
				ui2.TabBarItem{
					id:    'alerts'
					label: 'Alerts'
					icon:  'bell'
					badge: '4'
				},
			]
			state:   app.bar_state(id, 'home')
			variant: .pill
			size:    size
			theme:   theme
		}
		y += height + 10
	}
	x := l.right
	w := l.half
	bars << ui2.TabBarConfig{
		id:                  'icons'
		frame:               ui2.rect(x, top + 32, 420, ui2.tab_bar_height(.segmented, .medium))
		items:               [
			ui2.TabBarItem{
				id:                  'person'
				icon:                'person'
				accessibility_label: 'People'
			},
			ui2.TabBarItem{
				id:                  'calendar'
				icon:                'calendar'
				accessibility_label: 'Calendar'
			},
			ui2.TabBarItem{
				id:                  'map'
				icon:                'map'
				accessibility_label: 'Map'
			},
			ui2.tab_bar_item('settings', 'Settings'),
			ui2.tab_bar_item('about', 'About'),
		]
		state:               app.bar_state('icons', 'calendar')
		variant:             .segmented
		fill:                true
		accessibility_label: 'Views'
		theme:               theme
	}
	mail_height := ui2.tab_bar_height(.tab, .medium)
	bars << ui2.TabBarConfig{
		id:                  'mail'
		frame:               ui2.rect(x, top + 80, w, mail_height)
		items:               [
			ui2.TabBarItem{
				id:    'inbox'
				label: 'Inbox'
				icon:  'tray'
				badge: '12'
			},
			ui2.TabBarItem{
				id:         'flagged'
				label:      'Flagged'
				icon:       'flag'
				badge:      '3'
				badge_tone: .danger
			},
			ui2.TabBarItem{
				id:    'sent'
				label: 'Sent'
				icon:  'paperplane.fill'
			},
			ui2.TabBarItem{
				id:    'trash'
				label: 'Trash'
				icon:  'trash'
			},
		]
		state:               app.bar_state('mail', 'inbox')
		prefix:              [
			icon_button('mail-back', 'chevron.left', 'Back', ui2.rect(4, (mail_height - 24) / 2,
				24, 24), theme),
			icon_button('mail-forward', 'chevron.right', 'Forward', ui2.rect(30, (mail_height - 24) / 2,
				24, 24), theme),
		]
		prefix_size:         58
		suffix:              [
			icon_button('mail-new', 'square.and.pencil', 'New message', ui2.rect(0, (mail_height - 24) / 2,
				24, 24), theme),
			icon_button('mail-more', 'ellipsis', 'More', ui2.rect(26, (mail_height - 24) / 2,
				24, 24), theme),
		]
		suffix_size:         54
		accessibility_label: 'Mailboxes'
		theme:               theme
	}
	doc_height := ui2.tab_bar_height(.folder, .medium)
	mut docs := []ui2.TabBarItem{}
	for doc in app.docs {
		docs << ui2.TabBarItem{
			id:       doc.id
			label:    doc.name
			icon:     doc.icon
			closable: true
		}
	}
	bars << ui2.TabBarConfig{
		id:                  'docs'
		frame:               ui2.rect(x, top + 164, w, doc_height)
		items:               docs
		state:               app.bar_state('docs', 'main')
		variant:             .folder
		max_tab_width:       150
		suffix:              [
			icon_button('doc-new', 'plus', 'New tab', ui2.rect(4, (doc_height - 24) / 2 + 2,
				24, 24), theme),
		]
		suffix_size:         32
		reorderable:         true
		offset:              app.offsets['docs'] or { 0.0 }
		accessibility_label: 'Open files'
		theme:               theme
	}
	mut many := []ui2.TabBarItem{}
	for index, name in ['Overview', 'Analytics', 'Reports', 'Notifications', 'Integrations', 'Billing',
		'Team members', 'Security', 'API keys', 'Webhooks', 'Audit log', 'Preferences'] {
		many << ui2.TabBarItem{
			id:      'm${index}'
			label:   name
			enabled: index != 5
		}
	}
	bars << ui2.TabBarConfig{
		id:                  'many'
		frame:               ui2.rect(x, top + 330, w, ui2.tab_bar_height(.underline, .medium))
		items:               many
		state:               app.bar_state('many', 'm0')
		variant:             .underline
		menu:                true
		max_tab_width:       110
		offset:              app.offsets['many'] or { 0.0 }
		accessibility_label: 'Sections'
		theme:               theme
	}
	return bars
}

fn find_bar(bars []ui2.TabBarConfig, id string) ?ui2.TabBarConfig {
	for bar in bars {
		if bar.id == id {
			return bar
		}
	}
	return none
}

// ── Tabbed panels ───────────────────────────────────────────────────

fn panel_page(theme ui2.ComponentTheme, title string, body string) ui2.Element {
	return ui2.view('', ui2.rect(0, 0, 10, 10), ui2.BoxStyle{
		transparent: true
	}, [
		ui2.label('', title, ui2.rect(16, 14, 240, 22), text_style(theme, 15, true, false)),
		ui2.label('', body, ui2.rect(16, 40, 240, 40), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			lines:  2
			valign: .top
		}),
	])
}

fn side_panel(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TabbedPanelConfig {
	pages := [
		['General', 'gearshape', 'Name, language and region.'],
		['Appearance', 'paintbrush', 'Theme, accent and density.'],
		['Privacy', 'lock', 'Who can see what you share.'],
		['Shortcuts', 'key', 'Keys for common actions.'],
	]
	mut tabs := []ui2.TabbedPanelTab{}
	for index, page in pages {
		tabs << ui2.TabbedPanelTab{
			title:   page[0]
			icon:    page[1]
			enabled: index != 3
			content: panel_page(theme, page[0], page[2])
		}
	}
	return ui2.TabbedPanelConfig{
		id:                  'side-panel'
		frame:               ui2.rect(l.right, top + 470, (l.half - 16) / 2 + 40, l.height - top - 494)
		current:             app.side_current
		tab_position:        .left_top
		variant:             .pill
		theme:               theme
		bar_size:            136
		hovered:             app.side_hovered
		tabs:                tabs
		accessibility_label: 'Settings'
	}
}

fn top_panel(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TabbedPanelConfig {
	x := l.right + (l.half - 16) / 2 + 56
	mut tabs := []ui2.TabbedPanelTab{}
	for title in ['Code', 'Issues', 'Pulls'] {
		tabs << ui2.TabbedPanelTab{
			title:   title
			badge:   if title == 'Issues' { '8' } else { '' }
			content: panel_page(theme, title, 'The ${title.to_lower()} of the repository.')
		}
	}
	return ui2.TabbedPanelConfig{
		id:           'top-panel'
		frame:        ui2.rect(x, top + 470, l.right + l.half - x, l.height - top - 494)
		current:      app.top_current
		tab_position: .top_left
		variant:      .tab
		theme:        theme
		hovered:      app.top_hovered
		tabs:         tabs
	}
}

// ── Trees ───────────────────────────────────────────────────────────

fn file_menu(id string) []ui2.MenuEntry {
	return [ui2.MenuEntry{
		id:    'delete:${id}'
		title: 'Delete'
	}]
}

fn file(id string, name string, size string) ui2.TreeViewNode {
	icon := if name.ends_with('.v') {
		'curlybraces'
	} else if name.ends_with('.md') {
		'doc.text.fill'
	} else if name.ends_with('.png') {
		'photo'
	} else {
		'doc'
	}
	return ui2.TreeViewNode{
		id:       id
		text:     name
		icon:     icon
		trailing: size
		menu:     file_menu(id)
	}
}

fn folder(id string, name string, expanded bool, children []ui2.TreeViewNode) ui2.TreeViewNode {
	return ui2.TreeViewNode{
		id:            id
		text:          name
		icon:          'folder'
		expanded_icon: 'folder.fill'
		expanded:      expanded
		children:      children
		menu:          file_menu(id)
	}
}

fn initial_files() []ui2.TreeViewNode {
	return [
		folder('src', 'src', true, [
			folder('src/ui', 'ui', true, [
				file('src/ui/tab_bar.v', 'tab_bar.v', '18 KB'),
				ui2.TreeViewNode{
					...file('src/ui/tree_view.v', 'tree_view.v', '24 KB')
					selected: true
				},
				file('src/ui/symbols.v', 'symbols.v', '6 KB'),
			]),
			file('src/main.v', 'main.v', '2 KB'),
		]),
		ui2.TreeViewNode{
			id:            'remote'
			text:          'remote (loads lazily)'
			icon:          'cloud'
			expanded_icon: 'cloud'
			has_children:  true
		},
		folder('docs', 'docs', false, [
			file('docs/guide.md', 'guide.md', '9 KB'),
			file('docs/logo.png', 'logo.png', '31 KB'),
		]),
		ui2.TreeViewNode{
			...folder('vendor', 'vendor (locked)', false, [
				file('vendor/lib.v', 'lib.v', '1 KB'),
			])
			enabled: false
		},
		file('readme', 'README.md', '4 KB'),
		file('license', 'LICENSE', '1 KB'),
	]
}

fn leaf(id string, name string, checked bool) ui2.TreeViewNode {
	return ui2.TreeViewNode{
		id:      id
		text:    name
		checked: checked
	}
}

fn initial_checks() []ui2.TreeViewNode {
	return [
		ui2.TreeViewNode{
			id:       'files'
			text:     'Files'
			icon:     'folder'
			expanded: true
			children: [
				leaf('files.read', 'Read', true),
				leaf('files.write', 'Write', true),
				leaf('files.delete', 'Delete', false),
			]
		},
		ui2.TreeViewNode{
			id:       'admin'
			text:     'Administration'
			icon:     'shield'
			expanded: true
			children: [
				leaf('admin.users', 'Manage users', true),
				leaf('admin.billing', 'Billing', true),
			]
		},
		ui2.TreeViewNode{
			id:       'notify'
			text:     'Notifications'
			icon:     'bell'
			expanded: true
			children: [
				leaf('notify.email', 'Email', false),
				ui2.TreeViewNode{
					id:       'notify.push'
					text:     'Push'
					expanded: true
					children: [
						leaf('notify.push.mobile', 'Mobile', false),
						leaf('notify.push.desktop', 'Desktop', false),
					]
				},
				ui2.TreeViewNode{
					...leaf('notify.sms', 'SMS (unavailable)', false)
					enabled: false
				},
			]
		},
	]
}

const big_folders = 100
const big_files = 100

fn initial_big() []ui2.TreeViewNode {
	mut folders := []ui2.TreeViewNode{cap: big_folders}
	for f in 0 .. big_folders {
		mut files := []ui2.TreeViewNode{cap: big_files}
		for i in 0 .. big_files {
			files << ui2.TreeViewNode{
				id:       'b${f}/${i}'
				text:     'record_${f:03}_${i:03}.json'
				icon:     'doc'
				trailing: '${(f * 7 + i * 13) % 97 + 1} KB'
			}
		}
		folders << ui2.TreeViewNode{
			id:            'b${f}'
			text:          'batch ${f:03}'
			icon:          'folder'
			expanded_icon: 'folder.fill'
			expanded:      true
			children:      files
		}
	}
	return folders
}

fn initial_legacy() []ui2.TreeViewNode {
	return [
		ui2.TreeViewNode{
			id:               'l-docs'
			text:             'Documentation'
			expanded:         true
			toggle_action_id: 'legacy-toggle:l-docs'
			action_id:        'legacy-select:l-docs'
			children:         [
				ui2.TreeViewNode{
					id:        'l-guide'
					text:      'Guide'
					action_id: 'legacy-select:l-guide'
					selected:  true
				},
				ui2.TreeViewNode{
					id:        'l-api'
					text:      'API'
					action_id: 'legacy-select:l-api'
				},
			]
		},
	]
}

fn files_config(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TreeViewConfig {
	return ui2.TreeViewConfig{
		id:                  'files'
		frame:               ui2.rect(l.left, top + 108, l.third, l.height - top - 132)
		nodes:               ui2.tree_view_filter(app.files, app.query)
		theme:               theme
		selection:           .multiple
		state:               app.files_state
		offset:              app.files_offset
		reorderable:         app.query.len == 0
		accessibility_label: 'Files'
	}
}

fn checks_config(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TreeViewConfig {
	return ui2.TreeViewConfig{
		id:                  'checks'
		frame:               ui2.rect(l.left + l.third + 24, top + 64, l.third, 380)
		nodes:               app.checks
		theme:               theme
		checkable:           true
		selection:           .none
		state:               app.checks_state
		accessibility_label: 'Permissions'
	}
}

fn big_config(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TreeViewConfig {
	return ui2.TreeViewConfig{
		id:                  'big'
		frame:               ui2.rect(l.left + 2 * (l.third + 24), top + 64, l.third, l.height - top - 88)
		nodes:               app.big
		theme:               theme
		size:                .small
		state:               app.big_state
		offset:              app.big_offset
		virtualize:          true
		overscan:            4
		row_content:         fn [theme] (node ui2.TreeViewNode, frame ui2.Rect, selected bool) []ui2.Element {
			return record_row(theme, node, frame)
		}
		accessibility_label: 'Records'
	}
}

// record_row is the virtualized tree's own row content, as GPUI Kit's
// render_item draws one: an icon, the name and, for a record, a meter of its
// size.
fn record_row(theme ui2.ComponentTheme, node ui2.TreeViewNode, frame ui2.Rect) []ui2.Element {
	h := frame.height
	is_folder := node.children.len > 0
	icon := if is_folder {
		if node.expanded { 'folder.fill' } else { 'folder' }
	} else {
		'doc'
	}
	mut out := [
		ui2.Element{
			...ui2.image('', 'symbol:' + icon, ui2.rect(0, (h - 14) / 2, 14, 14))
			text_style: ui2.TextStyle{
				color: if is_folder { theme.primary } else { theme.muted_foreground }
			}
		},
	]
	meter := 56.0
	name_width := frame.width - 20 - if is_folder { 0.0 } else { meter + 52 }
	out << ui2.label('', node.text, ui2.rect(20, 0, name_width, h), ui2.TextStyle{
		color: theme.foreground
		size:  12
	})
	if is_folder {
		return out
	}
	size := node.trailing.all_before(' ').int()
	x := frame.width - meter - 44
	out << ui2.view('', ui2.rect(x, (h - 4) / 2, meter, 4), ui2.BoxStyle{
		bg:     theme.muted
		radius: 2
	}, [
		ui2.view('', ui2.rect(0, 0, meter * f64(size) / 97, 4), ui2.BoxStyle{
			bg:     theme.primary
			radius: 2
		}, []ui2.Element{}),
	])
	out << ui2.label('', node.trailing, ui2.rect(frame.width - 40, 0, 40, h), ui2.TextStyle{
		color: theme.muted_foreground
		size:  11
		align: .right
	})
	return out
}

// legacy_config is a tree_view without a theme: the application styles its
// rows, as before the GPUI Kit look existed.
fn legacy_config(app &Gallery, theme ui2.ComponentTheme, l Layout) ui2.TreeViewConfig {
	return ui2.TreeViewConfig{
		id:                    'legacy'
		frame:                 ui2.rect(l.left + l.third + 24, top + 524, l.third, 116)
		box:                   ui2.BoxStyle{
			transparent: true
		}
		row_height:            34
		spacing:               2
		indent:                22
		disclosure_width:      26
		row_box:               ui2.BoxStyle{
			bg:     theme.muted
			radius: 4
		}
		selected_row_box:      ui2.BoxStyle{
			bg:     theme.primary
			radius: 4
		}
		disclosure_box:        ui2.BoxStyle{
			bg:     theme.muted
			radius: 4
		}
		text_style:            ui2.TextStyle{
			color: theme.foreground
			size:  14
		}
		selected_text_style:   ui2.TextStyle{
			color: theme.primary_foreground
			size:  14
			bold:  true
		}
		disclosure_text_style: ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}
		nodes:                 app.legacy
	}
}

fn checked_leaves(nodes []ui2.TreeViewNode, mut out []string) {
	for node in nodes {
		if node.children.len == 0 && node.checked {
			out << node.text
		}
		checked_leaves(node.children, mut out)
	}
}

// ── Building ────────────────────────────────────────────────────────

fn build_tabs_page(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme, l Layout) []ui2.Element {
	bars := tab_page_bars(app, theme, l)
	children << heading(theme, 'Variants', l.left, top, l.half)
	for index, variant in variants {
		children << caption(theme, '.${variant_name(variant)}', l.left, variant_top(index), l.half)
	}
	children << heading(theme, 'Sizes', l.left, variant_top(variants.len), l.half)
	children << heading(theme, 'Icons, badges, prefix and suffix', l.right, top, l.half)
	children << heading(theme, 'Closable tabs: drag to reorder, + to add', l.right, top + 132,
		l.half)
	// The folder bar's selected tab joins the content below it.
	docs := find_bar(bars, 'docs') or { panic('no docs bar') }
	current := docs.state.selected
	mut current_name := 'No file open'
	for doc in app.docs {
		if doc.id == current {
			current_name = 'Editing ${doc.name}'
		}
	}
	children << ui2.view('', ui2.rect(docs.frame.x, docs.frame.y + docs.frame.height, docs.frame.width,
		76), ui2.BoxStyle{
		bg:            theme.background
		border_color:  theme.border
		border_left:   1
		border_right:  1
		border_bottom: 1
	}, [
		ui2.label('', current_name, ui2.rect(16, 12, docs.frame.width - 32, 20), text_style(theme,
			14, true, false)),
		ui2.label('', '${app.docs.len} files open. Close one with its ×; the selection moves to the next tab.',
			ui2.rect(16, 36, docs.frame.width - 32, 18), text_style(theme, 12, false, true)),
	])
	children << heading(theme, 'Overflow: scrolling and the tab menu', l.right, top + 298, l.half)
	children << heading(theme, 'Themed tabbed panels', l.right, top + 410, l.half)
	children << note(theme, 'tabbed_panel with a variant: tabs beside the content (pill), or above it (tab).',
		ui2.rect(l.right, top + 436, l.half, 20))
	for bar in bars {
		children << ui2.tab_bar(bar) or { panic(err) }
	}
	children << ui2.tabbed_panel(side_panel(app, theme, l)) or { panic(err) }
	children << ui2.tabbed_panel(top_panel(app, theme, l)) or { panic(err) }
	// The tab menu is drawn last, over everything it may cover.
	many := find_bar(bars, 'many') or { panic('no menu bar') }
	if many.state.menu.open {
		children << ui2.tab_bar_menu(many, ui2.tab_bar_menu_anchor(many), ui2.bounds()) or {
			panic(err)
		}
	}
	return children
}

fn build_tree_page(mut children []ui2.Element, mut app Gallery, theme ui2.ComponentTheme, l Layout) []ui2.Element {
	x2 := l.left + l.third + 24
	x3 := l.left + 2 * (l.third + 24)
	children << heading(theme, 'File tree', l.left, top, l.third)
	children << note(theme, 'Cmd/Ctrl-click toggles, Shift-click extends. Drag rows to move them; right-click to delete.',
		ui2.rect(l.left, top + 26, l.third, 36))
	children << ui2.input_group(
		id:          'filter'
		frame:       ui2.rect(l.left, top + 66, l.third, 32)
		text:        app.query
		placeholder: 'Filter files…'
		addons:      [
			ui2.InputGroupAddon{
				id:   'search'
				kind: .icon
				icon: 'magnifyingglass'
			},
		]
		clearable:   true
		theme:       theme
	) or { panic(err) }
	children << ui2.tree_view(files_config(app, theme, l)) or { panic(err) }
	children << heading(theme, 'Check boxes', x2, top, l.third)
	children << note(theme, 'A folder shows whether all, some or none of what is in it is checked.',
		ui2.rect(x2, top + 26, l.third, 36))
	children << ui2.tree_view(checks_config(app, theme, l)) or { panic(err) }
	mut granted := []string{}
	checked_leaves(app.checks, mut granted)
	children << note(theme, 'Granted: ${granted.join(', ')}', ui2.rect(x2, top + 452, l.third,
		36))
	children << heading(theme, 'Application-styled tree_view', x2, top + 492, l.third)
	children << ui2.tree_view(legacy_config(app, theme, l)) or { panic(err) }
	big := big_config(app, theme, l)
	span := ui2.tree_view_visible_range(big) or { panic(err) }
	app.big_built = span
	children << heading(theme, '10,100 nodes, virtualized, own row content', x3, top, l.third)
	children << note(theme, 'Only the rows in view are built: ${span.len()} now, from row ${span.start + 1}.',
		ui2.rect(x3, top + 26, l.third, 36))
	children << ui2.tree_view(big) or { panic(err) }
	return children
}

fn build() ui2.Element {
	mut app := gallery()
	theme := ui2.component_theme(app.dark)
	l := layout()
	mut children := [
		ui2.label('', 'Tabs and tree', ui2.rect(24, 16, 560, 30), text_style(theme, 22, true,
			false)),
		ui2.link(
			id:    'theme'
			text:  'Light / dark'
			frame: ui2.rect(l.width - 124, 18, 100, 28)
			theme: theme
		) or { panic(err) },
		ui2.label('', app.status, ui2.rect(24, 52, l.width - 48, 20), text_style(theme, 13,
			false, true)),
		ui2.tab_bar(page_bar(app, theme, l)) or { panic(err) },
	]
	if app.page == 'tree' {
		children = build_tree_page(mut children, mut app, theme, l)
	} else {
		children = build_tabs_page(mut children, app, theme, l)
	}
	return ui2.screen(theme.background, children)
}

// ── Events ──────────────────────────────────────────────────────────

fn (mut app Gallery) scroll_later(id string, offset f64, horizontal bool) {
	app.scroll_id = id
	app.scroll_to = offset
	app.scroll_horizontal = horizontal
}

fn tab_label(bar ui2.TabBarConfig, id string) string {
	for item in bar.items {
		if item.id == id {
			return if item.label.len > 0 { item.label } else { item.accessibility_label }
		}
	}
	return id
}

fn (mut app Gallery) bar_step(bar ui2.TabBarConfig, step ui2.TabBarStep) {
	app.bars[bar.id] = step.state
	app.focus = bar.id
	if bar.id == 'pages' && step.selected {
		app.page = step.state.selected
		app.focus = if app.page == 'tree' { 'files' } else { 'variant-tab' }
	}
	if step.selected {
		app.status = '${bar.accessibility_label}: ${tab_label(bar, step.state.selected)}.'
	}
	if step.closed.len > 0 {
		app.close_doc(bar, step.closed)
		return
	}
	if step.moved {
		app.docs = ui2.tab_bar_reorder(app.docs, step.from, step.to)
		app.status = 'Moved ${tab_label(bar, bar.items[step.from].id)} to place ${step.to + 1}.'
	}
	if step.reveal {
		moved := ui2.TabBarConfig{
			...bar
			state: step.state
		}
		if offset := ui2.tab_bar_reveal_offset(moved, step.state.selected) {
			app.offsets[bar.id] = offset
			app.scroll_later(ui2.tab_bar_scroll_id(bar.id), offset, true)
		}
	}
}

fn (mut app Gallery) close_doc(bar ui2.TabBarConfig, closed string) {
	state := app.bars[bar.id] or { ui2.TabBarState{} }
	next := ui2.tab_bar_after_close(bar.items, state.selected, closed)
	name := tab_label(bar, closed)
	app.docs = app.docs.filter(it.id != closed)
	app.bars[bar.id] = ui2.TabBarState{
		...state
		selected: next
	}
	app.status = 'Closed ${name}.'
}

fn (mut app Gallery) panel_step(which string, step ui2.TabbedPanelStep) {
	app.focus = which
	if which == 'side-panel' {
		app.side_current = step.current
		app.side_hovered = step.hovered
	} else {
		app.top_current = step.current
		app.top_hovered = step.hovered
	}
	if step.selected {
		app.status = 'Showing tab ${step.current + 1} of the ${which}.'
	}
}

fn (mut app Gallery) tree_step(which string, step ui2.TreeViewStep) {
	app.focus = which
	theme := ui2.component_theme(app.dark)
	l := layout()
	match which {
		'files' {
			app.files_state = step.state
			app.files = ui2.tree_view_apply(app.files, step)
			if step.moved {
				if moved := ui2.tree_view_move_nodes(app.files, step.move) {
					app.files = moved
					app.status = 'Moved ${step.move.node} ${step.move.position} ${step.move.target}.'
				}
			}
			if step.load.len > 0 {
				app.status = 'Loading ${step.node.text}…'
				id := step.load
				ui2.after(0.9, fn [id] () {
					mut g := gallery()
					g.files = ui2.tree_view_with_children(g.files, id, [
						file('${id}/api.v', 'api.v', '3 KB'),
						file('${id}/client.v', 'client.v', '5 KB'),
						folder('${id}/cache', 'cache', false, [
							file('${id}/cache/index.v', 'index.v', '2 KB'),
						]),
					])
					g.status = 'Loaded the remote folder.'
				})
			}
		}
		'checks' {
			app.checks_state = step.state
			app.checks = ui2.tree_view_apply(app.checks, step)
		}
		else {
			app.big_state = step.state
			app.big = ui2.tree_view_apply(app.big, step)
		}
	}
	if step.selection && step.selected.len > 0 {
		app.status = 'Selected ${step.selected.len}: ${step.selected.join(', ')}.'
	} else if step.confirmed {
		app.status = 'Opened ${step.node.text}.'
	} else if step.checked.len > 0 || step.unchecked.len > 0 {
		app.status = '${if step.checked.len > 0 { 'Checked' } else { 'Unchecked' }} ${step.node.text}.'
	}
	if step.reveal {
		config := match which {
			'files' { files_config(app, theme, l) }
			'checks' { checks_config(app, theme, l) }
			else { big_config(app, theme, l) }
		}
		if offset := ui2.tree_view_reveal_offset(config, step.state.active) {
			if which == 'files' {
				app.files_offset = offset
			} else if which == 'big' {
				app.big_offset = offset
			}
			app.scroll_later(ui2.tree_view_scroll_id(which), offset, false)
		}
	}
}

fn remove_node(nodes []ui2.TreeViewNode, id string) []ui2.TreeViewNode {
	mut out := []ui2.TreeViewNode{}
	for node in nodes {
		if node.id == id {
			continue
		}
		out << ui2.TreeViewNode{
			...node
			children: remove_node(node.children, id)
		}
	}
	return out
}

fn (mut app Gallery) handle_tabs_page(event string, theme ui2.ComponentTheme, l Layout) bool {
	for bar in tab_page_bars(app, theme, l) {
		if step := ui2.tab_bar_update(bar, event) {
			app.bar_step(bar, step)
			return true
		}
	}
	for which in ['side-panel', 'top-panel'] {
		panel := if which == 'side-panel' {
			side_panel(app, theme, l)
		} else {
			top_panel(app, theme, l)
		}
		if step := ui2.tabbed_panel_update(panel, event) {
			app.panel_step(which, step)
			return true
		}
	}
	match event {
		'doc-new' {
			app.untitled++
			id := 'untitled-${app.untitled}'
			app.docs << Doc{id, 'Untitled ${app.untitled}', 'doc'}
			app.bars['docs'] = ui2.TabBarState{
				...app.bar_state('docs', 'main')
				selected: id
			}
			app.status = 'Opened Untitled ${app.untitled}.'
			bars := tab_page_bars(app, theme, l)
			docs := find_bar(bars, 'docs') or { return true }
			if offset := ui2.tab_bar_reveal_offset(docs, id) {
				app.offsets['docs'] = offset
				app.scroll_later(ui2.tab_bar_scroll_id('docs'), offset, true)
			}
		}
		'mail-back', 'mail-forward', 'mail-new', 'mail-more' {
			app.status = 'Pressed ${event}.'
		}
		else {
			return false
		}
	}
	return true
}

fn (mut app Gallery) handle_tree_page(event string, theme ui2.ComponentTheme, l Layout) bool {
	modifiers := ui2.list_held_modifiers()
	for which in ['files', 'checks', 'big'] {
		config := match which {
			'files' { files_config(app, theme, l) }
			'checks' { checks_config(app, theme, l) }
			else { big_config(app, theme, l) }
		}
		if step := ui2.tree_view_update(config, event, modifiers) {
			app.tree_step(which, step)
			return true
		}
	}
	filter := ui2.InputGroupConfig{
		id:        'filter'
		text:      app.query
		clearable: true
	}
	if change := ui2.input_group_event(filter, event) {
		match change.kind {
			.change {
				app.query = ui2.text(ui2.input_group_field_id('filter'))
			}
			.clear {
				app.query = ''
				ui2.set_text(ui2.input_group_field_id('filter'), '')
			}
			else {}
		}
		return true
	}
	if event.starts_with('delete:') {
		id := event['delete:'.len..]
		app.files = remove_node(app.files, id)
		app.status = 'Deleted ${id}.'
		return true
	}
	if event.starts_with('legacy-') {
		id := event.all_after(':')
		if event.starts_with('legacy-toggle:') {
			app.legacy = app.legacy.map(ui2.TreeViewNode{
				...it
				expanded: if it.id == id { !it.expanded } else { it.expanded }
			})
		} else {
			app.legacy = ui2.tree_view_apply(app.legacy, ui2.TreeViewStep{
				selection: true
				selected:  [id]
			})
		}
		app.status = 'Application-styled tree: ${event}.'
		return true
	}
	return false
}

fn (mut app Gallery) handle(event string) bool {
	theme := ui2.component_theme(app.dark)
	l := layout()
	if event == 'theme' {
		app.dark = !app.dark
		return true
	}
	if step := ui2.tab_bar_update(page_bar(app, theme, l), event) {
		app.bar_step(page_bar(app, theme, l), step)
		return true
	}
	return if app.page == 'tree' {
		app.handle_tree_page(event, theme, l)
	} else {
		app.handle_tabs_page(event, theme, l)
	}
}

fn (mut app Gallery) settle() {
	ui2.refresh()
	if app.scroll_id.len > 0 {
		if app.scroll_horizontal {
			ui2.scroll_to_horizontal_offset(app.scroll_id, app.scroll_to)
		} else {
			ui2.scroll_to_offset(app.scroll_id, app.scroll_to)
		}
		app.scroll_id = ''
	}
}

fn on_event(event string) {
	mut app := gallery()
	if app.handle(event) {
		app.settle()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut app := gallery()
	theme := ui2.component_theme(app.dark)
	l := layout()
	if ui2.focused_id() == ui2.input_group_field_id('filter') {
		return
	}
	match app.focus {
		'files', 'checks', 'big' {
			config := match app.focus {
				'files' { files_config(app, theme, l) }
				'checks' { checks_config(app, theme, l) }
				else { big_config(app, theme, l) }
			}
			step := ui2.tree_view_key(config, event) or { return }
			app.tree_step(app.focus, step)
		}
		'side-panel', 'top-panel' {
			panel := if app.focus == 'side-panel' {
				side_panel(app, theme, l)
			} else {
				top_panel(app, theme, l)
			}
			step := ui2.tabbed_panel_key(panel, event) or { return }
			app.panel_step(app.focus, step)
		}
		else {
			bars := tab_page_bars(app, theme, l)
			bar := if app.focus == 'pages' {
				page_bar(app, theme, l)
			} else {
				find_bar(bars, app.focus) or { return }
			}
			step := ui2.tab_bar_key(bar, event) or { return }
			app.bar_step(bar, step)
		}
	}
	ui2.consume_key()
	app.settle()
}

fn on_scroll(id string) {
	mut app := gallery()
	match id {
		ui2.tab_bar_scroll_id('docs') {
			app.offsets['docs'] = ui2.scroll_horizontal_offset(id)
		}
		ui2.tab_bar_scroll_id('many') {
			app.offsets['many'] = ui2.scroll_horizontal_offset(id)
		}
		ui2.tree_view_scroll_id('files') {
			app.files_offset = ui2.scroll_offset(id)
		}
		ui2.tree_view_scroll_id('big') {
			app.big_offset = ui2.scroll_offset(id)
			next := ui2.tree_view_visible_range(big_config(app, ui2.component_theme(app.dark),
				layout())) or { return }
			if next.start != app.big_built.start || next.end != app.big_built.end {
				ui2.request_refresh()
			}
		}
		else {}
	}
}

fn main() {
	mut app := gallery()
	app.files = initial_files()
	app.checks = initial_checks()
	app.big = initial_big()
	app.legacy = initial_legacy()
	app.files_state = ui2.TreeViewState{
		active: 'src/ui/tree_view.v'
		anchor: 'src/ui/tree_view.v'
	}
	app.bars['many'] = ui2.TabBarState{
		selected: 'm7'
	}
	app.bars['variant-pill'] = ui2.TabBarState{
		selected: 'profile'
		hovered:  'documents'
	}
	app.bars['variant-folder'] = ui2.TabBarState{
		selected: 'documents'
		hovered:  'account'
	}
	if os.getenv('GPUI_NAVIGATION2_PAGE') == 'tree' {
		app.page = 'tree'
		app.focus = 'files'
		app.bars['pages'] = ui2.TabBarState{
			selected: 'tree'
		}
	}
	app.dark = os.getenv('GPUI_NAVIGATION2_DARK') == '1'
	// Open the overflowing bar scrolled to its selected tab; the offset is
	// taken up when the strip is first laid out.
	start := layout_for(window_width, window_height)
	if many := find_bar(tab_page_bars(app, ui2.component_theme(app.dark), start), 'many') {
		if offset := ui2.tab_bar_reveal_offset(many, many.state.selected) {
			app.offsets['many'] = offset
			ui2.scroll_to_horizontal_offset(ui2.tab_bar_scroll_id('many'), offset)
		}
	}
	ui2.on_key_event(on_key)
	ui2.on_scroll(on_scroll)
	ui2.run_window('GPUI Kit tabs and tree', window_width, window_height, build, on_event)
}
