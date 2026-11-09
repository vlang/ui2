module main

import os
import ui2

// A worked example of the stylesheet plugin system: a `demo-kit` plugin
// provides a theme() color function, a @supports at-rule, a :--has-tooltip
// pseudo-class, a debug-outlines transform and a lint rule. The sheet itself
// lives on disk next to this file and reloads with the button below, so the
// example doubles as a live-reload demo.

const plugins_width = 640
const plugins_height = 480

struct PluginsDemo {
mut:
	status      string = 'Edit theme.vss next to main.v, then press Reload.'
	known_mtime i64
	outlines    bool
}

const plugins_state = &PluginsDemo{}

fn plugin_debug_outlines(el ui2.Element, env ui2.StyleMatchEnv) ui2.Element {
	_ = env
	state := unsafe { plugins_state }
	if !state.outlines || el.id == '' {
		return el
	}
	return ui2.Element{
		...el
		box: ui2.BoxStyle{
			...el.box
			border_color:  0xff00ff
			border_left:   2
			border_top:    2
			border_right:  2
			border_bottom: 2
		}
	}
}

// theme() looks a name up in a tiny built-in palette. A real application
// would read its ComponentThemeRegistry here instead.
fn plugin_theme_lookup(name string, inner string, ctx ui2.StyleLengthCtx) !ui2.StyleFnValue {
	_ = name
	_ = ctx
	return match inner.trim_space().to_lower() {
		'primary' {
			ui2.StyleFnValue(ui2.ComponentThemeToken{ color: 0x2563eb, opacity: 1.0 })
		}
		'paper' {
			ui2.StyleFnValue(ui2.ComponentThemeToken{ color: 0xf8fafc, opacity: 1.0 })
		}
		'ink' {
			ui2.StyleFnValue(ui2.ComponentThemeToken{ color: 0x172033, opacity: 1.0 })
		}
		else {
			error('unknown theme color "${inner.trim_space()}"')
		}
	}
}

// @supports wraps its body in a global @media when the feature is known,
// and drops the block otherwise.
fn plugin_supports(name string, prelude string, body string) !string {
	_ = name
	known := ['container-queries', 'color-mix', 'nesting', 'custom-props', 'cqw-units']
	if prelude.trim_space().to_lower() in known {
		return '@media all { ${body} }'
	}
	return ''
}

fn plugin_has_tooltip(pseudo ui2.StylePseudo, el ui2.Element, ancestors []ui2.StyleAncestor, index int, count int, env ui2.StyleMatchEnv) bool {
	_ = pseudo
	_ = ancestors
	_ = index
	_ = count
	_ = env
	return el.tooltip.len > 0
}

fn plugin_no_red(sheet ui2.Stylesheet) ui2.StylesheetLintNotes {
	mut warnings := []string{}
	for rule in sheet.rules {
		for decl in rule.declarations {
			if decl.value.trim_space().to_lower() == 'red' {
				warnings << 'line ${rule.line}: avoid the bare color red; use a theme token'
			}
		}
	}
	return ui2.StylesheetLintNotes{ warnings: warnings }
}

fn plugin_sheet_path() string {
	return os.join_path(os.dir(@FILE), 'theme.vss')
}

fn plugin_load_sheet() !ui2.Stylesheet {
	return ui2.load_stylesheet(plugin_sheet_path())
}

fn build_plugins_screen() ui2.Element {
	state := unsafe { plugins_state }
	screen_bg := if ui2.stylesheet_dark_mode() { u32(0x10151f) } else { u32(0xf1f5f9) }
	return ui2.screen(screen_bg, [
		ui2.with_classes(ui2.label('t', 'Plugin Gallery', ui2.rect(24, 16, 500, 30),
			ui2.TextStyle{}), 'title'),
		ui2.with_classes(ui2.label('s', 'theme() + @supports + :--has-tooltip + lint + reload',
			ui2.rect(24, 46, 500, 20), ui2.TextStyle{}), 'sub'),
		ui2.button('reload', 'Reload theme.vss', ui2.rect(24, 84, 200, 38),
			ui2.BoxStyle{}, ui2.TextStyle{}),
		ui2.button('outlines', if state.outlines { 'Outlines: on' } else { 'Outlines: off' },
			ui2.rect(236, 84, 150, 38), ui2.BoxStyle{}, ui2.TextStyle{}),
		ui2.with_classes(ui2.Element{
			...ui2.label('help', '?', ui2.rect(398, 84, 38, 38), ui2.TextStyle{})
			tooltip: 'served by a custom pseudo-class'
		}, 'help'),
		ui2.with_classes(ui2.label('status', state.status, ui2.rect(24, 134, 592, 120),
			ui2.TextStyle{}), 'readout'),
	])
}

fn handle_plugins_event(event string) {
	mut state := unsafe { plugins_state }
	match event {
		'reload' {
			known := ui2.stylesheet_file_mtime(plugin_sheet_path())
			if known == 0 {
				state.status = 'theme.vss not found on disk.'
			} else if known == state.known_mtime {
				state.status = 'No changes since last load.'
			} else {
				sheet := ui2.load_stylesheet(plugin_sheet_path()) or {
					state.status = 'Reload failed: ${err.msg()}'
					ui2.refresh()
					return
				}
				ui2.set_global_stylesheet(sheet)
				state.known_mtime = known
				state.status = 'Reloaded theme.vss.'
			}
		}
		'outlines' {
			state.outlines = !state.outlines
			state.status = if state.outlines { 'Debug outlines on.' } else { 'Debug outlines off.' }
		}
		else {
			return
		}
	}
	ui2.refresh()
}

fn main() {
	ui2.register_style_plugin(ui2.StylePlugin{
		name:           'demo-kit'
		functions:      ['theme']
		eval_function:  plugin_theme_lookup
		at_rules:       ['supports']
		expand_at_rule: plugin_supports
		pseudos:        ['--has-tooltip']
		match_pseudo:   plugin_has_tooltip
		transform:      plugin_debug_outlines
		lint:           plugin_no_red
	})
	sheet := plugin_load_sheet() or { panic(err) }
	ui2.set_global_stylesheet(sheet)
	notes := ui2.stylesheet_lint(sheet)
	mut state := unsafe { plugins_state }
	state.known_mtime = ui2.stylesheet_file_mtime(plugin_sheet_path())
	if notes.warnings.len > 0 {
		state.status = 'Lint: ${notes.warnings[0]}'
	}
	ui2.run_window('Stylesheet Plugins', plugins_width, plugins_height, build_plugins_screen,
		handle_plugins_event)
}
