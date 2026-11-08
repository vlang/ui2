module main

import ui2

// A preferences window built with ui2.settings: five pages of grouped
// settings with every kind of control, a search across all of them, values
// that can be reset to their defaults, and a light/dark switch that is itself
// a setting. The application owns the values and the settings state; every
// action goes through settings_update and every key through settings_key.

const window_width = 1040
const window_height = 720

const accent_colors = ['#2563eb', '#7c3aed', '#db2777', '#ea580c', '#16a34a', '#0891b2']

@[heap]
struct Prefs {
mut:
	values       map[string]ui2.SettingValue
	state        ui2.SettingsState
	last_checked string = 'Last checked today at 09:41.'
	transfer     string = 'Back up your preferences or move them to another computer.'
	show_tips    bool
	// Work to do once the tree has been rebuilt.
	sync_id   string
	sync_text string
	focus_id  string
	scroll_id string
	scroll_to f64
}

const prefs_state = &Prefs{}

fn prefs() &Prefs {
	return unsafe { prefs_state }
}

// ── Theme ───────────────────────────────────────────────────────────

fn parse_hex(source string) u32 {
	digits := source.trim_left('#')
	mut out := u32(0)
	for ch in digits.bytes() {
		nibble := if ch >= `0` && ch <= `9` {
			ch - `0`
		} else if ch >= `a` && ch <= `f` {
			ch - `a` + 10
		} else if ch >= `A` && ch <= `F` {
			ch - `A` + 10
		} else {
			u8(0)
		}
		out = out * 16 + u32(nibble)
	}
	return out
}

fn blend(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(from + (to - from) * t + 0.5) << shift
	}
	return out
}

// app_theme follows the Dark mode and Accent color settings.
fn app_theme(app &Prefs) ui2.ComponentTheme {
	dark := ui2.setting_bool(app.values, 'appearance.dark')
	base := ui2.component_theme(dark)
	accent := parse_hex(ui2.setting_string(app.values, 'appearance.accent'))
	return ui2.ComponentTheme{
		...base
		primary: if dark { blend(accent, 0xffffff, 0.42) } else { accent }
	}
}

// ── Pages ───────────────────────────────────────────────────────────

fn opt(value string, caption string) ui2.SettingOption {
	return ui2.SettingOption{
		value: value
		label: caption
	}
}

fn general_page(app &Prefs) ui2.SettingPage {
	return ui2.SettingPage{
		id:     'general'
		title:  'General'
		icon:   'gearshape'
		groups: [
			ui2.SettingGroup{
				title: 'Startup'
				items: [
					ui2.SettingItem{
						key:           'general.open_at_login'
						title:         'Open at login'
						description:   'Start the app when you sign in to your computer.'
						default_value: false
					},
					ui2.SettingItem{
						key:           'general.restore_session'
						title:         'Restore previous session'
						description:   'Reopen the windows and tabs that were open when you quit.'
						default_value: true
					},
					ui2.SettingItem{
						key:           'general.projects'
						title:         'Projects folder'
						description:   'Where new projects are created.'
						kind:          .input
						placeholder:   '~/Projects'
						default_value: '~/Projects'
						keywords:      ['directory', 'path', 'workspace']
					},
				]
			},
			ui2.SettingGroup{
				title: 'Language and region'
				items: [
					ui2.SettingItem{
						key:           'general.language'
						title:         'Language'
						kind:          .dropdown
						options:       [opt('en', 'English'), opt('de', 'Deutsch'),
							opt('es', 'Español'), opt('fr', 'Français'), opt('pt', 'Português')]
						default_value: 'en'
						keywords:      ['locale', 'translation']
					},
					ui2.SettingItem{
						key:           'general.week_start'
						title:         'First day of the week'
						kind:          .dropdown
						options:       [opt('monday', 'Monday'), opt('sunday', 'Sunday'),
							opt('saturday', 'Saturday')]
						default_value: 'monday'
						keywords:      ['calendar']
					},
					ui2.SettingItem{
						key:           'general.clock_24h'
						title:         'Use a 24-hour clock'
						kind:          .checkbox
						default_value: true
						keywords:      ['time']
					},
				]
			},
			ui2.SettingGroup{
				title:  'Updates'
				footer: 'Updates are downloaded from GitHub Releases and verified before they are installed.'
				items:  [
					ui2.SettingItem{
						key:           'general.auto_update'
						title:         'Check for updates automatically'
						default_value: true
					},
					ui2.SettingItem{
						key:           'general.channel'
						title:         'Update channel'
						description:   'Beta and Nightly builds get features first, and bugs too.'
						kind:          .dropdown
						options:       [opt('stable', 'Stable'), opt('beta', 'Beta'),
							opt('nightly', 'Nightly')]
						default_value: 'stable'
					},
					ui2.SettingItem{
						key:         'general.check_now'
						title:       'Software update'
						description: app.last_checked
						kind:        .button
						button_text: 'Check now'
					},
				]
			},
		]
	}
}

fn accent_swatches(app &Prefs) ui2.SettingContentFn {
	return fn [app] (options ui2.SettingContentOptions) []ui2.Element {
		current := ui2.setting_string(app.values, 'appearance.accent')
		side := 22.0
		gap := 10.0
		count := accent_colors.len
		mut x := options.width - f64(count) * side - f64(count - 1) * gap
		y := (options.height - side) / 2
		mut swatches := []ui2.Element{}
		for color in accent_colors {
			chosen := color == current
			mut ring := []ui2.Element{}
			if chosen {
				ring << ui2.view('', ui2.rect(6, 6, side - 12, side - 12), ui2.BoxStyle{
					bg:     0xffffff
					radius: (side - 12) / 2
				}, []ui2.Element{})
			}
			swatches << ui2.Element{
				...ui2.button_view('accent:${color}', ui2.rect(x, y, side, side), ui2.BoxStyle{
					bg:     parse_hex(color)
					radius: side / 2
				}, ring)
				enabled:             !options.disabled
				cursor:              ui2.cursor_pointing_hand
				accessibility_label: 'Accent ${color}'
				accessibility_value: if chosen { 'selected' } else { '' }
			}
			x += side + gap
		}
		return swatches
	}
}

fn appearance_page(app &Prefs) ui2.SettingPage {
	return ui2.SettingPage{
		id:                 'appearance'
		title:              'Appearance'
		icon:               'paintbrush'
		description:        if app.show_tips {
			'Dark mode and the accent color apply to this window right away. Use **Reset all** to go back to the defaults.'
		} else {
			''
		}
		title_suffix:       fn (options ui2.SettingContentOptions) []ui2.Element {
			return [
				ui2.styled_button(
					id:                  'appearance-help'
					frame:               ui2.rect(0, (options.height - 24) / 2, 24, 24)
					icon:                'questionmark.circle'
					variant:             .ghost
					size:                .small
					accessibility_label: 'About these settings'
					theme:               options.theme
				) or { panic(err) },
			]
		}
		title_suffix_width: 24
		groups:             [
			ui2.SettingGroup{
				title: 'Theme'
				items: [
					ui2.SettingItem{
						key:           'appearance.dark'
						title:         'Dark mode'
						description:   'Switch between light and dark themes.'
						default_value: false
						keywords:      ['theme', 'light', 'night']
					},
					ui2.SettingItem{
						key:           'appearance.accent'
						title:         'Accent color'
						description:   'Used for selections, switches and focused controls.'
						kind:          .custom
						content:       accent_swatches(app)
						field_width:   192
						default_value: accent_colors[0]
						keywords:      ['color', 'highlight', 'tint']
					},
					ui2.SettingItem{
						key:           'appearance.density'
						title:         'Density'
						kind:          .dropdown
						options:       [opt('compact', 'Compact'), opt('comfortable', 'Comfortable'),
							opt('spacious', 'Spacious')]
						default_value: 'comfortable'
						keywords:      ['spacing', 'padding']
					},
				]
			},
			ui2.SettingGroup{
				title:       'Text'
				description: 'Sizes for menus, lists and labels. The editor has its own font settings.'
				items:       [
					ui2.SettingItem{
						key:           'appearance.ui_font_size'
						title:         'Interface text size'
						kind:          .slider
						min:           11
						max:           18
						step:          1
						unit:          ' pt'
						default_value: 13.0
						keywords:      ['font', 'zoom']
					},
					ui2.SettingItem{
						key:           'appearance.system_font'
						title:         'Use the system font'
						kind:          .checkbox
						default_value: true
						keywords:      ['font', 'typeface']
					},
				]
			},
			ui2.SettingGroup{
				title:   'Sidebar'
				variant: .fill
				items:   [
					ui2.SettingItem{
						key:           'appearance.sidebar_icons'
						title:         'Show icons in the sidebar'
						default_value: true
					},
				]
			},
		]
	}
}

fn editor_page() ui2.SettingPage {
	return ui2.SettingPage{
		id:           'editor'
		title:        'Editor'
		icon:         'curlybraces'
		default_open: true
		groups:       [
			ui2.SettingGroup{
				title: 'Font'
				items: [
					ui2.SettingItem{
						key:           'editor.font_family'
						title:         'Font family'
						kind:          .dropdown
						options:       [opt('JetBrains Mono', 'JetBrains Mono'),
							opt('Fira Code', 'Fira Code'), opt('SF Mono', 'SF Mono'),
							opt('Menlo', 'Menlo'), opt('Roboto Mono', 'Roboto Mono')]
						default_value: 'JetBrains Mono'
						keywords:      ['typeface', 'monospace']
					},
					ui2.SettingItem{
						key:           'editor.font_size'
						title:         'Font size'
						kind:          .number
						min:           8
						max:           72
						default_value: 14.0
						keywords:      ['zoom']
					},
					ui2.SettingItem{
						key:           'editor.line_height'
						title:         'Line height'
						description:   'A multiple of the font size.'
						kind:          .number
						min:           1
						max:           2.5
						step:          0.1
						precision:     1
						default_value: 1.5
						keywords:      ['spacing']
					},
				]
			},
			ui2.SettingGroup{
				title: 'Editing'
				items: [
					ui2.SettingItem{
						key:           'editor.tab_size'
						title:         'Tab size'
						kind:          .number
						min:           1
						max:           8
						precision:     0
						default_value: 4.0
						keywords:      ['indent', 'indentation']
					},
					ui2.SettingItem{
						key:           'editor.insert_spaces'
						title:         'Insert spaces'
						description:   'Pressing **Tab** inserts spaces instead of a `\\t` character.'
						default_value: true
						keywords:      ['indent', 'indentation', 'tabs']
					},
					ui2.SettingItem{
						key:           'editor.format_on_save'
						title:         'Format on save'
						description:   'Runs the formatter of the file’s language, such as _vfmt_ or _prettier_.'
						default_value: false
						keywords:      ['autoformat', 'beautify']
					},
					ui2.SettingItem{
						key:           'editor.wrap'
						title:         'Word wrap'
						kind:          .dropdown
						options:       [opt('off', 'Off'), opt('viewport', 'At the window edge'),
							opt('column', 'At the ruler')]
						default_value: 'off'
						keywords:      ['soft wrap', 'lines']
					},
				]
			},
			ui2.SettingGroup{
				title: 'Display'
				items: [
					ui2.SettingItem{
						key:           'editor.line_numbers'
						title:         'Show line numbers'
						kind:          .checkbox
						default_value: true
						keywords:      ['gutter']
					},
					ui2.SettingItem{
						key:           'editor.highlight_line'
						title:         'Highlight the current line'
						kind:          .checkbox
						default_value: true
					},
					ui2.SettingItem{
						key:           'editor.ruler'
						title:         'Ruler column'
						description:   'Draws a guide at this column; 0 hides it.'
						kind:          .number
						min:           0
						max:           200
						step:          10
						precision:     0
						default_value: 100.0
						keywords:      ['guide', 'margin']
					},
				]
			},
		]
	}
}

fn notifications_page() ui2.SettingPage {
	return ui2.SettingPage{
		id:     'notifications'
		title:  'Notifications'
		icon:   'bell'
		groups: [
			ui2.SettingGroup{
				title: 'Alerts'
				items: [
					ui2.SettingItem{
						key:           'notify.allow'
						title:         'Allow notifications'
						default_value: true
						keywords:      ['alerts', 'banners']
					},
					ui2.SettingItem{
						key:           'notify.sound'
						title:         'Play a sound'
						default_value: true
						keywords:      ['audio', 'chime']
					},
					ui2.SettingItem{
						key:           'notify.volume'
						title:         'Volume'
						kind:          .slider
						min:           0
						max:           100
						step:          5
						unit:          '%'
						default_value: 70.0
						keywords:      ['sound', 'loud']
					},
					ui2.SettingItem{
						key:           'notify.previews'
						title:         'Show previews'
						kind:          .dropdown
						options:       [opt('always', 'Always'), opt('unlocked', 'When unlocked'),
							opt('never', 'Never')]
						default_value: 'unlocked'
						keywords:      ['privacy', 'lock screen']
					},
				]
			},
			ui2.SettingGroup{
				title:       'Do Not Disturb'
				description: 'Silence notifications during the hours you set.'
				items:       [
					ui2.SettingItem{
						key:           'notify.dnd'
						title:         'Use a schedule'
						default_value: false
						keywords:      ['quiet', 'focus', 'silence']
					},
					ui2.SettingItem{
						key:           'notify.dnd_from'
						title:         'From'
						kind:          .input
						placeholder:   'HH:MM'
						field_width:   96
						default_value: '22:00'
					},
					ui2.SettingItem{
						key:           'notify.dnd_to'
						title:         'Until'
						kind:          .input
						placeholder:   'HH:MM'
						field_width:   96
						default_value: '07:00'
					},
				]
			},
			ui2.SettingGroup{
				title: 'Email'
				items: [
					ui2.SettingItem{
						key:           'notify.digest'
						title:         'Send a weekly summary'
						description:   'Sign in to an account to receive email.'
						kind:          .checkbox
						disabled:      true
						default_value: false
						keywords:      ['digest', 'newsletter']
					},
				]
			},
		]
	}
}

fn transfer_row(app &Prefs) ui2.SettingContentFn {
	return fn [app] (options ui2.SettingContentOptions) []ui2.Element {
		export_w := ui2.styled_button_width('Export…', 'square.and.arrow.up', options.size)
		import_w := ui2.styled_button_width('Import…', 'folder', options.size)
		y := (options.height - 32) / 2
		import_x := options.width - import_w
		export_x := import_x - 8 - export_w
		return [
			ui2.label('', 'Settings file', ui2.rect(0, 0, export_x - 16, 20), ui2.TextStyle{
				color: options.theme.foreground
				size:  14
			}),
			ui2.label('', app.transfer, ui2.rect(0, 22, export_x - 16, options.height - 22),
				ui2.TextStyle{
					color:  options.theme.muted_foreground
					size:   13
					valign: .top
					lines:  0
				}),
			ui2.styled_button(
				id:    'export'
				frame: ui2.rect(export_x, y, export_w, 32)
				label: 'Export…'
				icon:  'square.and.arrow.up'
				size:  options.size
				theme: options.theme
			) or { panic(err) },
			ui2.styled_button(
				id:    'import'
				frame: ui2.rect(import_x, y, import_w, 32)
				label: 'Import…'
				icon:  'folder'
				size:  options.size
				theme: options.theme
			) or { panic(err) },
		]
	}
}

fn advanced_page(app &Prefs) ui2.SettingPage {
	return ui2.SettingPage{
		id:     'advanced'
		title:  'Advanced'
		icon:   'slider.horizontal.3'
		groups: [
			ui2.SettingGroup{
				title: 'Network'
				items: [
					ui2.SettingItem{
						key:           'advanced.proxy'
						title:         'Proxy server'
						description:   'Leave empty to connect directly.'
						kind:          .input
						layout:        .vertical
						placeholder:   'http://proxy.example.com:8080'
						default_value: ''
						keywords:      ['http', 'network', 'firewall']
					},
					ui2.SettingItem{
						key:           'advanced.timeout'
						title:         'Request timeout'
						description:   'Seconds before a request is abandoned.'
						kind:          .number
						min:           1
						max:           120
						step:          5
						precision:     0
						default_value: 30.0
					},
					ui2.SettingItem{
						key:           'advanced.two_factor'
						title:         'Enable two-factor authentication'
						default_value: false
						keywords:      ['MFA', '2FA', 'security']
					},
				]
			},
			ui2.SettingGroup{
				items: [
					ui2.SettingItem{
						key:           'advanced.debug_log'
						title:         'Debug logging'
						description:   'Writes detailed logs to `~/Library/Logs/Preferences`.'
						default_value: false
						keywords:      ['diagnostics', 'trace']
					},
					ui2.SettingItem{
						key:           'advanced.experiments'
						title:         'Experimental features'
						description:   'Try features before they are finished. They may change or go away.'
						kind:          .checkbox
						default_value: false
						keywords:      ['labs', 'preview']
					},
				]
			},
			ui2.SettingGroup{
				title: 'Data'
				items: [
					ui2.SettingItem{
						key:            'advanced.transfer'
						kind:           .custom
						content:        transfer_row(app)
						content_height: 44
						keywords:       ['backup', 'export', 'import', 'settings file']
					},
					ui2.SettingItem{
						key:            'advanced.reset_everything'
						title:          'Reset every setting'
						description:    'Puts every setting on every page back to its default.'
						kind:           .button
						button_text:    'Reset…'
						button_variant: .danger
						keywords:       ['defaults', 'factory']
					},
				]
			},
		]
	}
}

fn pages(app &Prefs) []ui2.SettingPage {
	return [general_page(app), appearance_page(app), editor_page(), notifications_page(),
		advanced_page(app)]
}

fn settings_config(app &Prefs) ui2.SettingsConfig {
	bounds := ui2.bounds()
	width := if bounds.width > 0 { bounds.width } else { f64(window_width) }
	height := if bounds.height > 0 { bounds.height } else { f64(window_height) }
	return ui2.SettingsConfig{
		id:            'prefs'
		frame:         ui2.rect(0, 0, width, height)
		pages:         pages(app)
		values:        app.values
		state:         app.state
		group_variant: .outline
		theme:         app_theme(app)
	}
}

// ── Build and events ────────────────────────────────────────────────

fn build() ui2.Element {
	app := prefs()
	config := settings_config(app)
	return ui2.screen(config.theme.background, [
		ui2.settings(config) or { panic(err) },
	])
}

fn (mut app Prefs) take(step ui2.SettingsStep) {
	app.state = step.state
	step.apply(mut app.values)
	match step.action {
		'general.check_now' {
			app.last_checked = 'Checked just now. You have the latest version.'
		}
		'advanced.reset_everything' {
			app.values = ui2.settings_defaults(pages(app))
		}
		else {}
	}
	if step.scroll {
		app.scroll_id = step.scroll_id
		app.scroll_to = step.scroll_to
	}
	if step.focus.len > 0 {
		app.focus_id = step.focus
	}
	if step.sync_id.len > 0 {
		app.sync_id = step.sync_id
		app.sync_text = step.sync_text
	}
}

// handle returns whether the event changed anything.
fn (mut app Prefs) handle(event string) bool {
	live := ui2.SettingsInput{
		text:   ui2.text
		number: ui2.slider_value
	}
	if step := ui2.settings_update(settings_config(app), event, live) {
		app.take(step)
		return true
	}
	if event.starts_with('accent:') {
		app.values['appearance.accent'] = ui2.SettingValue(event['accent:'.len..])
		return true
	}
	match event {
		'appearance-help' {
			app.show_tips = !app.show_tips
		}
		'export' {
			app.transfer = 'Exported to preferences.json in your Downloads folder.'
		}
		'import' {
			app.transfer = 'Choose a settings file exported from another computer.'
		}
		else {
			return false
		}
	}
	return true
}

// settle rebuilds, then does what has to wait for the new tree.
fn (mut app Prefs) settle() {
	ui2.refresh()
	if app.sync_id.len > 0 {
		if ui2.text(app.sync_id) != app.sync_text {
			ui2.set_text(app.sync_id, app.sync_text)
		}
		app.sync_id = ''
	}
	if app.focus_id.len > 0 {
		ui2.focus(app.focus_id)
		app.focus_id = ''
	}
	if app.scroll_id.len > 0 {
		ui2.scroll_to_offset(app.scroll_id, app.scroll_to)
		app.scroll_id = ''
	}
}

fn on_event(event string) {
	mut app := prefs()
	if app.handle(event) {
		app.settle()
	}
}

fn on_key(event ui2.KeyEvent) {
	mut app := prefs()
	// Cmd+F (Ctrl+F elsewhere) goes to the search field.
	if (event.cmd || event.ctrl) && event.code == .f && !event.alt && !event.shift {
		ui2.consume_key()
		ui2.focus(ui2.settings_search_field_id('prefs'))
		return
	}
	step := ui2.settings_key(settings_config(app), ui2.focused_id(), event) or { return }
	ui2.consume_key()
	app.take(step)
	app.settle()
}

fn main() {
	mut app := prefs()
	all_pages := pages(app)
	app.values = ui2.settings_defaults(all_pages)
	// A few values that differ from their defaults, so Reset shows.
	app.values['general.restore_session'] = ui2.SettingValue(false)
	app.values['editor.font_size'] = ui2.SettingValue(15.0)
	app.values['notify.volume'] = ui2.SettingValue(45.0)
	app.state = ui2.settings_initial_state(all_pages)
	ui2.on_key_event(on_key)
	ui2.run_window('Preferences', window_width, window_height, build, on_event)
}
