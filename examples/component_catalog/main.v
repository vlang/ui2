module main

import ui2

@[heap]
struct CatalogState {
mut:
	page       int = 5
	dark       bool
	open       bool   = true
	show_alert bool   = true
	show_tag   bool   = true
	message    string = 'Use the controls to exercise their action IDs.'
}

const catalog_state = &CatalogState{}

fn build_catalog() ui2.Element {
	state := unsafe { catalog_state }
	theme := ui2.component_theme(state.dark)
	mut children := [ui2.label('', 'Portable component catalog', ui2.rect(24, 16, 680, 32),
		ui2.TextStyle{ color: theme.foreground, size: 22, bold: true })]
	children << ui2.link(
		id:    'theme'
		text:  'Toggle light / dark'
		frame: ui2.rect(24, 56, 140, 32)
		theme: theme
	) or { panic(err) }
	children << ui2.breadcrumb(
		id:    'breadcrumb'
		frame: ui2.rect(24, 100, 640, 32)
		theme: theme
		items: [ui2.BreadcrumbItem{ id: 'home', label: 'Home' },
			ui2.BreadcrumbItem{ id: 'components', label: 'Components' },
			ui2.BreadcrumbItem{ id: 'catalog', label: 'Catalog' }]
	) or { panic(err) }
	children << ui2.avatar(
		id:    'avatar'
		name:  'Ada Lovelace'
		frame: ui2.rect(24, 152, 48, 48)
		theme: theme
	) or { panic(err) }
	children << ui2.badge(id: 'badge', count: 127, frame: ui2.rect(88, 164, 56, 28), theme: theme) or { panic(err) }
	children << ui2.kbd(
		id:    'shortcut'
		keys:  ['Ctrl', 'K']
		frame: ui2.rect(160, 160, 112, 32)
		theme: theme
	) or { panic(err) }
	if state.show_tag {
		children << ui2.tag(
			id:           'tag'
			text:         'Removable'
			close_action: 'remove-tag'
			frame:        ui2.rect(292, 160, 150, 32)
			theme:        theme
		) or { panic(err) }
	}
	children << ui2.separator(frame: ui2.rect(24, 220, 640, 4), theme: theme) or { panic(err) }
	if state.show_alert {
		children << ui2.inline_alert(
			id:             'alert'
			title:          'Declarative components'
			description:    'The app owns all state. Dismiss this message to remove it.'
			dismiss_action: 'dismiss-alert'
			frame:          ui2.rect(24, 244, 640, 88)
			theme:          theme
		) or { panic(err) }
	}
	children << ui2.group_box(
		id:       'profile'
		title:    'Profile'
		frame:    ui2.rect(24, 352, 304, 140)
		theme:    theme
		children: [ui2.description_list(
			frame: ui2.rect(0, 0, 288, 76)
			theme: theme
			items: [ui2.DescriptionItem{'Name', 'Ada Lovelace'},
				ui2.DescriptionItem{'Status', 'Active'}]
		) or { panic(err) }]
	) or { panic(err) }
	children << ui2.empty_state(
		id:          'empty'
		title:       'No attachments'
		description: 'Add your first attachment.'
		action_text: 'Add attachment'
		action_id:   'add'
		frame:       ui2.rect(352, 352, 312, 140)
		theme:       theme
	) or { panic(err) }
	children << ui2.collapsible(
		id:       'details'
		title:    'Loading placeholders'
		open:     state.open
		frame:    ui2.rect(24, 516, 640, 100)
		theme:    theme
		children: [
			ui2.skeleton(frame: ui2.rect(8, 8, 40, 40), circle: true, theme: theme) or { panic(err) },
			ui2.skeleton(frame: ui2.rect(64, 8, 300, 16), theme: theme) or { panic(err) },
			ui2.skeleton(frame: ui2.rect(64, 32, 220, 16), theme: theme) or { panic(err) },
		]
	) or { panic(err) }
	children << ui2.pagination(
		id:    'pages'
		state: ui2.pagination_state(state.page, 20)
		frame: ui2.rect(24, 640, 640, 40)
		theme: theme
	) or { panic(err) }
	children << ui2.label('', state.message, ui2.rect(24, 696, 640, 40), ui2.TextStyle{ color: theme.foreground, lines: 0 })
	return ui2.screen(theme.background, children)
}

fn on_event(event string) {
	mut state := unsafe { catalog_state }
	if page := ui2.pagination_page_from_action('pages', ui2.pagination_state(state.page, 20), event) {
		state.page = page
		state.message = 'Selected page ${page}.'
	} else {
		match event {
			'theme' { state.dark = !state.dark }
			'details' { state.open = !state.open }
			'dismiss-alert' { state.show_alert = false }
			'remove-tag' { state.show_tag = false }
			'add' { state.message = 'The application handles attachment selection here.' }
			'home', 'components' { state.message = 'Navigate to ${event}.' }
			else { return }
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('UI2 Component Catalog', 700, 760, build_catalog, on_event)
}
