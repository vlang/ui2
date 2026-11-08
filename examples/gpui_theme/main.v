module main

import os
import ui2

// A theme studio for ui2's theme registry. Pick one of the bundled theme sets,
// or Sunset, a theme file embedded below and loaded on request; switch between
// light, dark and the system appearance; and the buttons, inputs, badges,
// tags, tabs, table, progress bars, alerts and gradient cards follow. The
// application owns the registry, the chosen set and the mode, and resolves
// the theme on every build.
//
// Cmd+Up and Cmd+Down (Ctrl elsewhere) step through the sets. For
// screenshots, GPUI_THEME names the starting set (Sunset loads the file) and
// GPUI_THEME_MODE the mode.

const window_width = 1180
const window_height = 800
const sidebar_width = 272.0
const content_x = 24.0
const column_width = 420.0
const column_gap = 20.0

// sunset_json is a theme file in GPUI Kit's format. It writes colors every way
// the loader reads them: hex, rgb(), hsl(), Tailwind palette names with and
// without an opacity, and linear-gradient() for the window background, cards,
// the primary color and the title bar.
const sunset_json = '{
  "name": "Sunset",
  "author": "ui2 gpui_theme example",
  "themes": [
    {
      "name": "Sunset Light",
      "mode": "light",
      "radius": 8,
      "colors": {
        "background": "linear-gradient(180deg, #fffaf5, #fff0e5)",
        "foreground": "stone-800",
        "muted.background": "hsl(28, 80%, 94%)",
        "muted.foreground": "stone-500",
        "border": "rgb(244 207 181)",
        "input.border": "rgb(244 207 181)",
        "primary.background": "linear-gradient(to right, orange-600, rose-600)",
        "primary.foreground": "white",
        "button.primary.background": "linear-gradient(to right, orange-600, rose-600)",
        "button.primary.foreground": "white",
        "success.background": "hsl(160, 84%, 30%)",
        "success.foreground": "white",
        "warning.background": "amber-400",
        "warning.foreground": "stone-900",
        "danger.background": "rose-600",
        "danger.foreground": "white",
        "group_box.background": "linear-gradient(180deg, #ffffff, #fff6ef)",
        "popover.background": "white",
        "sidebar.background": "rgba(255, 237, 213, 0.55)",
        "tab_bar.background": "orange-100/70",
        "tab.active.background": "white",
        "tab.active.foreground": "stone-900",
        "tab.foreground": "stone-600",
        "title_bar.background": "linear-gradient(to right, #fff7ed, #ffe4e6)"
      }
    },
    {
      "name": "Sunset Dark",
      "mode": "dark",
      "radius": 8,
      "colors": {
        "background": "linear-gradient(180deg, #211b18, #141110)",
        "foreground": "stone-100",
        "muted.background": "#2c2421",
        "muted.foreground": "stone-400",
        "border": "#43362f",
        "primary.background": "linear-gradient(to right, orange-400, pink-400)",
        "primary.foreground": "stone-950",
        "button.primary.background": "linear-gradient(to right, orange-400, pink-400)",
        "button.primary.foreground": "stone-950",
        "success.background": "emerald-400",
        "success.foreground": "stone-950",
        "warning.background": "amber-300",
        "warning.foreground": "stone-950",
        "danger.background": "rose-400",
        "danger.foreground": "stone-950",
        "group_box.background": "linear-gradient(180deg, #2d2521, #1f1916)",
        "popover.background": "#1f1916",
        "sidebar.background": "#1a1513",
        "tab_bar.background": "#2c2421",
        "tab.active.background": "#3d312b",
        "tab.active.foreground": "stone-50",
        "tab.foreground": "stone-400",
        "title_bar.background": "linear-gradient(to right, #2d2521, #33212a)"
      }
    }
  ]
}'

@[heap]
struct Studio {
mut:
	registry   ui2.ComponentThemeRegistry
	theme_name string                 = 'Catppuccin'
	mode       ui2.ComponentThemeMode = .system
	appearance ui2.SystemAppearance
	polling    bool
	tab        int
	query      string
	notify     bool = true
	email      bool
	message    string = 'Sunset is a theme file embedded in this example.'
}

const studio_state = &Studio{}

fn studio() &Studio {
	return unsafe { studio_state }
}

// ── Colors and text ─────────────────────────────────────────────────

fn mix(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(from + (to - from) * t + 0.5) << shift
	}
	return out
}

fn caption(content string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', content, frame, ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn heading(content string, frame ui2.Rect, color u32, size f64) ui2.Element {
	return ui2.label('', content, frame, ui2.TextStyle{
		color: color
		size:  size
		bold:  true
	})
}

fn section_label(content string, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', content, ui2.rect(20, y, 232, 16), ui2.TextStyle{
		color: theme.muted_foreground
		size:  11
		bold:  true
	})
}

// ── Sidebar: the theme picker ───────────────────────────────────────

fn modes_text(set ui2.ComponentThemeSet) string {
	light := set.has_mode(false)
	dark := set.has_mode(true)
	count := set.variants.len
	modes := if light && dark {
		'Light and dark'
	} else if dark {
		'Dark only'
	} else {
		'Light only'
	}
	return if count > 2 { '${modes} · ${count} themes' } else { modes }
}

fn swatch(color u32, x f64, y f64, ring u32) ui2.Element {
	return ui2.view('', ui2.rect(x, y, 14, 14), ui2.BoxStyle{
		bg:            color
		radius:        7
		border_color:  ring
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, [])
}

// theme_row is one set in the picker: its name, its modes and five swatches
// of the variant it would show in the current mode.
fn theme_row(set ui2.ComponentThemeSet, selected bool, current ui2.ComponentThemeVariant, frame ui2.Rect) ui2.Element {
	theme := current.theme
	preview := set.variant(current.dark).theme
	mut children := [
		heading(set.name, ui2.rect(12, 6, 130, 18), theme.foreground, 13),
		caption(modes_text(set), ui2.rect(12, 25, 140, 15), theme),
	]
	mut x := frame.width - 12 - 5 * 18 + 4
	for color in [preview.background, preview.primary, preview.success, preview.warning,
		preview.danger] {
		children << swatch(color, x, (frame.height - 14) / 2, mix(theme.border, theme.foreground,
			0.15))
		x += 18
	}
	box := if selected {
		ui2.BoxStyle{
			bg:            mix(theme.background, theme.primary, if current.dark {
				0.22
			} else {
				0.12
			})
			radius:        8
			border_color:  theme.primary
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}
	} else {
		ui2.BoxStyle{
			transparent: true
			radius:      8
		}
	}
	return ui2.Element{
		...ui2.button_view('theme:${set.name}', frame, box, children)
		accessibility_label: '${set.name} theme'
		accessibility_value: if selected { 'selected' } else { '' }
	}
}

fn mode_group(app &Studio, theme ui2.ComponentTheme) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:                  'mode'
		frame:               ui2.rect(20, 0, 232, 32)
		items:               [
			ui2.ButtonGroupItem{
				value:    'light'
				label:    'Light'
				selected: app.mode == .light
			},
			ui2.ButtonGroupItem{
				value:    'dark'
				label:    'Dark'
				selected: app.mode == .dark
			},
			ui2.ButtonGroupItem{
				value:    'system'
				label:    'System'
				selected: app.mode == .system
			},
		]
		fill:                true
		accessibility_label: 'Appearance'
		// A stronger border, so the selected segment stands out even in themes
		// whose muted and border colors are the same (Neutral Dark).
		theme:               ui2.ComponentTheme{
			...theme
			border: mix(theme.border, theme.foreground, 0.25)
		}
	}
}

fn appearance_text(app &Studio) string {
	return match app.appearance {
		.light { 'The system appearance is light.' }
		.dark { 'The system appearance is dark.' }
		.unknown { 'This platform does not report its appearance; System shows light.' }
	}
}

fn sidebar(app &Studio, variant ui2.ComponentThemeVariant) !ui2.Element {
	theme := variant.theme
	surface := variant.color('sidebar.background', mix(theme.background, theme.muted, 0.6))
	mut children := [
		heading('Themes', ui2.rect(20, 18, 232, 24), theme.foreground, 18),
		caption('GPUI Kit theme sets for ui2', ui2.rect(20, 44, 232, 16), theme),
		section_label('THEME SETS', 76, theme),
	]
	selected := app.registry.find(app.theme_name) or { app.registry.sets()[0] }
	mut y := 96.0
	for set in app.registry.sets() {
		children << theme_row(set, set.name == selected.name, variant, ui2.rect(10, y,
			sidebar_width - 20, 46))
		y += 48
	}
	y += 14
	children << section_label('APPEARANCE', y, theme)
	y += 20
	group := mode_group(app, theme)
	children << ui2.button_group(ui2.ButtonGroupConfig{
		...group
		frame: ui2.rect(20, y, 232, 32)
	})!
	y += 38
	children << ui2.label('', appearance_text(app), ui2.rect(20, y, 232, 32), ui2.TextStyle{
		color:  theme.muted_foreground
		size:   12
		valign: .top
		lines:  2
	})
	y += 40
	children << ui2.styled_button(
		id:      'load-json'
		frame:   ui2.rect(20, y, 232, 32)
		label:   'Load Sunset from JSON'
		icon:    'doc.text.fill'
		outline: true
		theme:   theme
	)!
	y += 40
	children << ui2.label('', app.message, ui2.rect(20, y, 232, 32), ui2.TextStyle{
		color:  theme.muted_foreground
		size:   12
		valign: .top
		lines:  2
	})
	return ui2.view('sidebar', ui2.rect(0, 0, sidebar_width, window_height), ui2.BoxStyle{
		bg:           surface
		border_color: theme.border
		border_right: 1
	}, children)
}

// ── Preview cards ───────────────────────────────────────────────────

// card is a raised surface in the theme: its card_box (a gradient when the
// theme's group box color is one) with a title. Children are card-relative.
fn card(id string, title string, frame ui2.Rect, variant ui2.ComponentThemeVariant, children []ui2.Element) ui2.Element {
	mut all := [heading(title, ui2.rect(16, 12, frame.width - 32, 18), variant.theme.foreground,
		13)]
	all << children
	return ui2.view(id, frame, variant.card_box(10), all)
}

// gradient_button fills a button with the theme's primary button token: a
// gradient in Aurora and Sunset, and an accent gradient derived from the
// primary color in themes that have none.
fn gradient_button(id string, caption_text string, frame ui2.Rect, variant ui2.ComponentThemeVariant) ui2.Element {
	theme := variant.theme
	token := variant.token_or('button.primary.background', theme.primary)
	box := if token.has_gradient() {
		token.box(6)
	} else {
		ui2.BoxStyle{
			bg:       theme.primary
			radius:   6
			gradient: ui2.component_theme_accent_gradient(theme)
		}
	}
	return ui2.button_view(id, frame, box, [
		ui2.label('', caption_text, ui2.rect(0, 0, frame.width, frame.height), ui2.TextStyle{
			color: variant.color('button.primary.foreground', theme.primary_foreground)
			size:  14
			align: .center
		}),
	])
}

fn button_row(labels []string, variants []ui2.ButtonVariant, outlines []bool, y f64, theme ui2.ComponentTheme) ![]ui2.Element {
	mut out := []ui2.Element{}
	mut x := 16.0
	for index, caption_text in labels {
		width := ui2.styled_button_width(caption_text, '', .medium)
		out << ui2.styled_button(
			id:      'button-${caption_text.to_lower()}'
			frame:   ui2.rect(x, y, width, 32)
			label:   caption_text
			variant: variants[index]
			outline: outlines[index]
			theme:   theme
		)!
		x += width + 8
	}
	return out
}

fn buttons_card(variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	mut children := button_row(['Primary', 'Secondary', 'Outline', 'Ghost'], [
		ui2.ButtonVariant.primary,
		.secondary,
		.primary,
		.ghost,
	], [false, false, true, false], 42, theme)!
	children << button_row(['Success', 'Warning', 'Danger'], [
		ui2.ButtonVariant.success,
		.warning,
		.danger,
	], [false, false, false], 82, theme)!
	children << gradient_button('button-gradient', 'Gradient', ui2.rect(frame.width - 16 - 108,
		82, 108, 32), variant)
	return card('buttons', 'Buttons', frame, variant, children)
}

fn inputs_card(app &Studio, variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	text_style := ui2.TextStyle{
		color: theme.foreground
		size:  13
	}
	return card('inputs', 'Inputs', frame, variant, [
		ui2.input_group(
			id:          'search'
			frame:       ui2.rect(16, 42, frame.width - 32, 32)
			text:        app.query
			placeholder: 'Search components…'
			clearable:   true
			addons:      [
				ui2.InputGroupAddon{
					id:   'search-icon'
					kind: .icon
					icon: 'magnifyingglass'
				},
			]
			theme:       theme
		)!,
		ui2.checkbox('email', 'Email me about releases', app.email, ui2.rect(16, 86, 210, 24),
			text_style),
		ui2.switch_control(
			id:     'notify'
			frame:  ui2.rect(frame.width - 16 - 40, 86, 40, 24)
			active: app.notify
			style:  ui2.SwitchStyle{
				inactive_track_color: mix(theme.border, theme.foreground, 0.1)
				active_track_color:   theme.primary
				thumb_color:          0xffffff
			}
		),
		ui2.label('', 'Notifications', ui2.rect(frame.width - 16 - 40 - 104, 86, 96, 24),
			ui2.TextStyle{
				...text_style
				align: .right
			}),
	])
}

fn tag_width(content string) f64 {
	return ui2.measure_text_width(content, ui2.TextStyle{ size: 12 }) + 16
}

fn badges_card(variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	mut children := []ui2.Element{}
	mut x := 16.0
	for index, count in [3, 12, 104] {
		tone := [ui2.ComponentTone.primary, .success, .danger][index]
		natural := ui2.measure_text_width(ui2.badge_text(count, 99), ui2.TextStyle{ size: 12 }) + 14
		width := if natural > 22 { natural } else { 22.0 }
		children << ui2.badge(
			frame: ui2.rect(x, 44, width, 22)
			count: count
			tone:  tone
			size:  .small
			theme: theme
		)!
		x += width + 8
	}
	children << ui2.badge(frame: ui2.rect(x, 51, 8, 8), dot: true, tone: .warning, theme: theme)!
	x += 22
	for index, tone in [ui2.ComponentTone.neutral, .primary, .success, .warning, .danger] {
		content := ['Draft', 'New', 'Paid', 'Due', 'Late'][index]
		width := tag_width(content)
		children << ui2.tag(
			frame:   ui2.rect(x, 42, width, 24)
			text:    content
			tone:    tone
			outline: index in [1, 4]
			size:    .small
			theme:   theme
		)!
		x += width + 6
	}
	return card('badges', 'Badges and tags', frame, variant, children)
}

fn progress_card(variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	bar_width := frame.width - 32 - 96
	mut children := []ui2.Element{}
	for index, value in [64.0, 38] {
		y := 46.0 + index * 34
		tone := if index == 0 { ui2.ComponentTone.primary } else { .success }
		children << caption(['Upload', 'Sync'][index], ui2.rect(16, y - 6, 120, 15), theme)
		children << caption('${int(value)}%', ui2.rect(16 + bar_width - 40, y - 6, 40, 15), theme)
		children << ui2.linear_progress(
			id:            'bar-${index}'
			frame:         ui2.rect(16, y + 12, bar_width, 8)
			value:         value
			tone:          tone
			reduce_motion: true
			theme:         theme
		)!
	}
	surface := variant.card_box(0).bg
	children << ui2.progress_circle(
		id:            'ring'
		frame:         ui2.rect(frame.width - 16 - 72, 38, 72, 72)
		diameter:      68
		value:         72
		label:         '72%'
		tone:          .primary
		background:    surface
		size:          .large
		reduce_motion: true
		theme:         theme
	)!
	return card('progress', 'Progress', frame, variant, children)
}

fn tabs_card(app &Studio, variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	titles := ['Overview', 'Activity', 'Settings']
	bodies := [
		'Tabs read tab_bar, tab and tab.active tokens when the theme has them.',
		'Three deployments finished today; one is waiting for review.',
		'Rebuild with another set name or mode to switch themes.',
	]
	panel_width := frame.width - 32
	tab_bar := variant.color('tab_bar.background', theme.muted)
	active_box := ui2.BoxStyle{
		bg:            variant.color('tab.active.background', theme.background)
		radius:        6
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}
	mut tabs := []ui2.TabbedPanelTab{}
	for index, title in titles {
		tabs << ui2.TabbedPanelTab{
			id:        'tab-${index}'
			title:     title
			action_id: 'tab:${index}'
			// The panel gives its content the frame below the tabs.
			content:   ui2.view('', ui2.rect(0, 0, 0, 0), ui2.BoxStyle{ transparent: true }, [
				ui2.label('', bodies[index], ui2.rect(2, 10, panel_width - 8, 36), ui2.TextStyle{
					color:  theme.foreground
					size:   13
					valign: .top
					lines:  2
				}),
			])
		}
	}
	return card('tabs', 'Tabs', frame, variant, [
		ui2.view('', ui2.rect(16, 40, 3 * 96 + 8, 34), ui2.BoxStyle{
			bg:     tab_bar
			radius: 8
		}, []),
		ui2.tabbed_panel(
			id:                       'tab-panel'
			frame:                    ui2.rect(20, 42, panel_width - 4, frame.height - 42 - 10)
			box:                      ui2.BoxStyle{
				transparent: true
			}
			current:                  app.tab
			tab_height:               30
			tab_width:                96
			header_box:               ui2.BoxStyle{
				bg:     tab_bar
				radius: 6
			}
			active_header_box:        active_box
			header_text_style:        ui2.TextStyle{
				color: variant.color('tab.foreground', theme.muted_foreground)
				size:  13
				align: .center
			}
			active_header_text_style: ui2.TextStyle{
				color: variant.color('tab.active.foreground', theme.foreground)
				size:  13
				bold:  true
				align: .center
			}
			tabs:                     tabs
		)!,
	])
}

fn table_card(variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	status := fn (content string, color u32) ui2.TableCell {
		return ui2.TableCell{
			text:  content
			color: color
			bold:  true
		}
	}
	rows := [
		ui2.TableRow{
			cells: [ui2.TableCell{
				text: 'Ada Lovelace'
			}, ui2.TableCell{
				text: 'Engineering'
			}, status('Active', theme.success)]
		},
		ui2.TableRow{
			cells: [ui2.TableCell{
				text: 'Grace Hopper'
			}, ui2.TableCell{
				text: 'Compilers'
			}, status('Review', mix(theme.warning, theme.foreground, if variant.dark {
				0.0
			} else {
				0.45
			}))]
		},
		ui2.TableRow{
			cells: [ui2.TableCell{
				text: 'Alan Turing'
			}, ui2.TableCell{
				text: 'Research'
			}, status('Active', theme.success)]
		},
		ui2.TableRow{
			cells: [ui2.TableCell{
				text: 'Edsger Dijkstra'
			}, ui2.TableCell{
				text: 'Algorithms'
			}, status('Away', theme.muted_foreground)]
		},
	]
	config := ui2.TableConfig{
		frame:   ui2.rect(16, 40, frame.width - 32, 0)
		columns: [
			ui2.TableColumn{
				title: 'Name'
				flex:  1.4
			},
			ui2.TableColumn{
				title: 'Team'
			},
			ui2.TableColumn{
				title: 'Status'
				width: 80
			},
		]
		rows:    rows
		striped: true
		size:    .small
		theme:   theme
	}
	return card('table', 'Table', frame, variant, [
		ui2.table(ui2.TableConfig{
			...config
			frame: ui2.rect(16, 40, frame.width - 32, ui2.table_height(config))
		})!,
	])
}

fn alerts_card(variant ui2.ComponentThemeVariant, frame ui2.Rect) !ui2.Element {
	theme := variant.theme
	titles := ['Heads up', 'Saved', 'Storage almost full', 'Sync failed']
	texts := ['A new version is ready.', 'Your changes are live.', '92% of 10 GB used.',
		'Retrying in 30 seconds.']
	width := (frame.width - 32 - 8) / 2
	mut children := []ui2.Element{}
	for index, tone in [ui2.ComponentTone.primary, .success, .warning, .danger] {
		children << ui2.inline_alert(
			frame:       ui2.rect(16 + (index % 2) * (width + 8), 40 + (index / 2) * 58, width,
				52)
			title:       titles[index]
			description: texts[index]
			tone:        tone
			size:        .small
			theme:       theme
		)!
	}
	return card('alerts', 'Alerts', frame, variant, children)
}

// hero is a banner on the theme's primary gradient, or on an accent gradient
// derived from its primary color when the theme has no gradient for it.
fn hero(variant ui2.ComponentThemeVariant, frame ui2.Rect) ui2.Element {
	theme := variant.theme
	gradient := variant.gradient('primary.background') or {
		ui2.component_theme_accent_gradient(theme)
	}
	gradients := variant.tokens.values().filter(it.has_gradient()).len
	detail := if gradients > 0 {
		'${variant.name} has ${gradients} gradient tokens; this banner uses its primary gradient.'
	} else {
		'${variant.name} has solid colors only, so this banner derives a gradient from its primary color.'
	}
	return ui2.view('hero', frame, ui2.BoxStyle{
		bg:       theme.primary
		radius:   12
		gradient: gradient
		shadow:   if variant.shadow { ui2.component_card_shadow() } else { ui2.BoxShadow{} }
	}, [
		heading('Gradient backgrounds', ui2.rect(24, 20, 560, 24), theme.primary_foreground, 18),
		ui2.label('', detail, ui2.rect(24, 50, 600, 36), ui2.TextStyle{
			color:  theme.primary_foreground
			size:   13
			valign: .top
			lines:  2
		}),
		ui2.button_view('hero-button', ui2.rect(frame.width - 24 - 132, (frame.height - 36) / 2,
			132, 36), ui2.BoxStyle{
			bg:     theme.background
			radius: 8
		}, [
			ui2.label('', 'Copy as JSON', ui2.rect(0, 0, 132, 36), ui2.TextStyle{
				color: theme.foreground
				size:  13
				bold:  true
				align: .center
			}),
		]),
	])
}

fn palette_strip(variant ui2.ComponentThemeVariant, frame ui2.Rect) ui2.Element {
	theme := variant.theme
	names := ['background', 'foreground', 'muted', 'border', 'primary', 'success', 'warning', 'danger']
	colors := [theme.background, theme.foreground, theme.muted, theme.border, theme.primary,
		theme.success, theme.warning, theme.danger]
	width := frame.width / names.len
	mut children := []ui2.Element{}
	for index, name in names {
		x := index * width
		children << ui2.view('', ui2.rect(x, 6, 24, 24), ui2.BoxStyle{
			bg:            colors[index]
			radius:        6
			border_color:  mix(theme.border, theme.foreground, 0.15)
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [])
		children << ui2.label('', name, ui2.rect(x + 31, 2, width - 31, 15), ui2.TextStyle{
			color: theme.foreground
			size:  12
		})
		children << caption(ui2.color_hex(colors[index], 1).to_lower(), ui2.rect(x + 31, 18,
			width - 31, 15), theme)
	}
	return ui2.view('palette', frame, ui2.BoxStyle{ transparent: true }, children)
}

fn content_area(app &Studio, variant ui2.ComponentThemeVariant) !ui2.Element {
	theme := variant.theme
	set := app.registry.find(app.theme_name) or { app.registry.sets()[0] }
	mode := if variant.dark { 'dark' } else { 'light' }
	byline := if set.author.len > 0 { 'by ${set.author} · ' } else { '' }
	left := content_x
	right := content_x + column_width + column_gap
	return ui2.view('content', ui2.rect(sidebar_width, 0, f64(window_width) - sidebar_width,
		window_height), variant.background_box(), [
		heading(variant.name, ui2.rect(left, 18, 600, 28), theme.foreground, 22),
		caption('${byline}${mode} variant of ${set.name} · radius ${int(variant.radius)} · ${variant.tokens.len} tokens',
			ui2.rect(left, 48, 700, 16), theme),
		hero(variant, ui2.rect(left, 76, 2 * column_width + column_gap, 104)),
		buttons_card(variant, ui2.rect(left, 196, column_width, 124))!,
		inputs_card(app, variant, ui2.rect(left, 332, column_width, 124))!,
		badges_card(variant, ui2.rect(left, 468, column_width, 84))!,
		progress_card(variant, ui2.rect(left, 564, column_width, 136))!,
		tabs_card(app, variant, ui2.rect(right, 196, column_width, 124))!,
		table_card(variant, ui2.rect(right, 332, column_width, 196))!,
		alerts_card(variant, ui2.rect(right, 540, column_width, 160))!,
		palette_strip(variant, ui2.rect(left, 720, 2 * column_width + column_gap, 40)),
	])
}

// ── Build and events ────────────────────────────────────────────────

fn build() ui2.Element {
	mut app := studio()
	app.appearance = ui2.system_appearance()
	variant := app.registry.resolve(app.theme_name, app.mode)
	return ui2.screen(variant.theme.background, [
		sidebar(app, variant) or { panic(err) },
		content_area(app, variant) or { panic(err) },
	])
}

// follow_system rebuilds every two seconds while the mode follows the system,
// since no backend reports appearance changes; a timer's callback is always
// followed by a rebuild.
fn (mut app Studio) follow_system() {
	if app.mode != .system || app.polling {
		return
	}
	app.polling = true
	ui2.after(2.0, fn () {
		mut app := studio()
		app.polling = false
		app.follow_system()
	})
}

fn (mut app Studio) load_sunset() {
	set := app.registry.load_json(sunset_json) or {
		app.message = 'Could not load the theme: ${err.msg()}'
		return
	}
	app.theme_name = set.name
	mut gradients := 0
	for variant in set.variants {
		gradients += variant.tokens.values().filter(it.has_gradient()).len
	}
	app.message = 'Loaded ${set.name}: ${set.variants.len} themes, ${gradients} gradient tokens.'
}

fn (mut app Studio) handle(event string) bool {
	if event.starts_with('theme:') {
		app.theme_name = event['theme:'.len..]
		return true
	}
	if event.starts_with('tab:') {
		app.tab = event['tab:'.len..].int()
		return true
	}
	variant := app.registry.resolve(app.theme_name, app.mode)
	if value := ui2.button_group_value_from_action(mode_group(app, variant.theme), event) {
		app.mode = ui2.component_theme_mode_from_name(value) or { return false }
		app.follow_system()
		return true
	}
	search := ui2.InputGroupConfig{
		id:        'search'
		text:      app.query
		clearable: true
	}
	if change := ui2.input_group_event(search, event) {
		match change.kind {
			.change { app.query = ui2.text(ui2.input_group_field_id('search')) }
			.clear { app.query = '' }
			else {}
		}
		return true
	}
	match event {
		'load-json' {
			app.load_sunset()
		}
		'email' {
			app.email = !app.email
		}
		'notify' {
			app.notify = !app.notify
		}
		'hero-button' {
			set := app.registry.find(app.theme_name) or { return false }
			ok := ui2.set_clipboard_text(ui2.component_theme_set_json(set))
			app.message = if ok {
				'Copied ${set.name} to the clipboard as a theme file.'
			} else {
				'This platform has no clipboard.'
			}
		}
		else {
			return false
		}
	}
	return true
}

fn on_event(event string) {
	mut app := studio()
	if app.handle(event) {
		ui2.refresh()
	}
}

fn on_key(event ui2.KeyEvent) {
	if !(event.cmd || event.ctrl) || event.code !in [ui2.KeyCode.up, .down] {
		return
	}
	ui2.consume_key()
	mut app := studio()
	app.theme_name = app.registry.cycle(app.theme_name, if event.code == .down { 1 } else { -1 })
	ui2.refresh()
}

fn main() {
	mut app := studio()
	app.registry = ui2.component_theme_registry()
	start := os.getenv('GPUI_THEME')
	if start.len > 0 {
		if start.to_lower() == 'sunset' {
			app.load_sunset()
		}
		app.theme_name = start
	}
	app.mode = ui2.component_theme_mode_from_name(os.getenv('GPUI_THEME_MODE')) or { app.mode }
	app.appearance = ui2.system_appearance()
	app.follow_system()
	ui2.on_key_event(on_key)
	ui2.run_window('Themes', window_width, window_height, build, on_event)
}
