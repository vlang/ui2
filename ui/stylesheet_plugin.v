@[has_globals]
module ui2

import os
import hash.fnv1a

// Stylesheet plugins: extend ui2's styling the way Vite plugins extend a
// build. A plugin is a plain value registered once, usually at startup:
//
// ```v
// ui2.register_style_plugin(ui2.StylePlugin{
// 	name:      'brand-tokens'
// 	functions: ['brand']
// 	eval_function: brand_lookup
// })
//
// fn brand_lookup(name string, inner string, ctx ui2.StyleLengthCtx) !ui2.StyleFnValue {
// 	...
// }
// ```
//
// Everything is compile-time registered — V has no runtime module loading,
// so there are no remote or lazily-loaded plugins. Hooks that are not set
// cost nothing: the core checks registration before doing any extra work.
//
// Hook overview, in pipeline order:
//   lint        extra `stylesheet_lint` notes for a sheet.
//   at-rule     `@name prelude { ... }` expands inner rules at parse time
//               (parse-time macros: scoping, static gating, sugar).
//   pseudo      custom `:name` / `:name(arg)` state, matched per element.
//   media       custom `@media (feature: value)` features.
//   function    custom value functions for numbers (`double(4px)`) and
//               colors (`theme(primary)`).
//   transform   per-element post pass after the cascade (Vite-style
//               `transform`): adjust box/text of the resolved element.

pub struct StylePlugin {
pub:
	name           string
	pseudos        []string // custom `:name` selectors this plugin matches
	at_rules       []string // custom `@name` blocks this plugin expands
	media_features []string // custom `@media` features this plugin matches
	functions      []string // custom value functions this plugin evaluates
	match_pseudo   StyleMatchPseudoFn
	expand_at_rule StyleExpandAtRuleFn
	match_media    StyleMatchMediaFn
	eval_function  StyleEvalFunctionFn
	transform      StyleTransformFn
	lint           StyleLintFn
}

// StyleMatchPseudoFn answers a custom pseudo-class for one element.
pub type StyleMatchPseudoFn = fn (pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool

// StyleExpandAtRuleFn rewrites a custom `@name prelude { body }` block into
// stylesheet source, which the core then parses as inner content in the
// enclosing media/container context.
pub type StyleExpandAtRuleFn = fn (name string, prelude string, body string) !string

// StyleMatchMediaFn answers a custom `@media (feature: value)` condition.
pub type StyleMatchMediaFn = fn (feature string, op string, value string, env StyleQueryEnv) bool

// StyleFnValue is what a custom value function returns: a number for
// numeric contexts, a color token for colors.
pub type StyleFnValue = StyleValue | ComponentThemeToken

// StyleEvalFunctionFn computes `name(inner)` in a value position. `inner`
// is the raw text between the parens; parse it with `style_math_tokenize`
// for numbers or `theme_split_commas` for lists.
pub type StyleEvalFunctionFn = fn (name string, inner string, ctx StyleLengthCtx) !StyleFnValue

// StyleTransformFn post-processes one cascaded element, top-down (children
// see transformed ancestors). It can only touch existing fields; it cannot
// invent storage on Element.
pub type StyleTransformFn = fn (el Element, env StyleMatchEnv) Element

// StyleLintFn returns lint notes about a parsed sheet.
pub type StyleLintFn = fn (sheet Stylesheet) StylesheetLintNotes

__global g_style_plugins = []StylePlugin{}

// register_style_plugin adds a plugin. Names must be unique; registering a
// name twice replaces the earlier plugin.
pub fn register_style_plugin(plugin StylePlugin) {
	for index, registered in g_style_plugins {
		if registered.name == plugin.name {
			g_style_plugins[index] = plugin
			return
		}
	}
	g_style_plugins << plugin
}

// unregister_style_plugin removes a plugin by name. Tests use this to leave
// no global state behind.
pub fn unregister_style_plugin(name string) {
	for index, registered in g_style_plugins {
		if registered.name == name {
			g_style_plugins.delete(index)
			return
		}
	}
}

// style_plugin_has_pseudo reports whether any plugin claims a `:name`.
pub fn style_plugin_has_pseudo(name string) bool {
	for plugin in g_style_plugins {
		if name in plugin.pseudos {
			return true
		}
	}
	return false
}

// style_plugin_has_at_rule reports whether any plugin expands `@name`.
pub fn style_plugin_has_at_rule(name string) bool {
	for plugin in g_style_plugins {
		if name in plugin.at_rules {
			return true
		}
	}
	return false
}

// style_plugin_has_media reports whether any plugin matches a media feature.
pub fn style_plugin_has_media(feature string) bool {
	for plugin in g_style_plugins {
		if feature in plugin.media_features {
			return true
		}
	}
	return false
}

// style_plugin_has_function reports whether any plugin evaluates `name()`.
pub fn style_plugin_has_function(name string) bool {
	for plugin in g_style_plugins {
		if name in plugin.functions {
			return true
		}
	}
	return false
}

// style_plugin_match_pseudo asks registered plugins about a custom pseudo.
// Unknown names (no plugin claims them) do not match.
pub fn style_plugin_match_pseudo(pseudo StylePseudo, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv) bool {
	for plugin in g_style_plugins {
		if pseudo.name !in plugin.pseudos {
			continue
		}
		if plugin.match_pseudo == unsafe { nil } {
			continue
		}
		if plugin.match_pseudo(pseudo, el, ancestors, index, count, env) {
			return true
		}
	}
	return false
}

// style_plugin_match_media asks registered plugins about a custom media
// condition. Unknown features do not match.
pub fn style_plugin_match_media(feature string, op string, value string, env StyleQueryEnv) bool {
	for plugin in g_style_plugins {
		if feature !in plugin.media_features {
			continue
		}
		if plugin.match_media == unsafe { nil } {
			continue
		}
		if plugin.match_media(feature, op, value, env) {
			return true
		}
	}
	return false
}

// style_plugin_eval_function asks the plugins claiming `name` to compute a
// value, in registration order: the first success wins, so a second plugin
// claiming the same name is still consulted when the first declines with
// an error (like pseudo and media hooks, every claimant gets a say). With
// every claimant failing, the first error reports. Unclaimed names are an
// error, so typos still fail fast.
pub fn style_plugin_eval_function(name string, inner string, ctx StyleLengthCtx) !StyleFnValue {
	mut first_err := ''
	for plugin in g_style_plugins {
		if name !in plugin.functions {
			continue
		}
		if plugin.eval_function == unsafe { nil } {
			continue
		}
		value := plugin.eval_function(name, inner, ctx) or {
			if first_err == '' {
				first_err = err.msg()
			}
			continue
		}
		return value
	}
	if first_err != '' {
		return error(first_err)
	}
	return error('unknown function "${name}()"')
}

// style_plugin_expand_at_rule expands a custom at-rule block through the
// plugins that claim it, in registration order: the first successful
// expansion wins; with every claimant failing, the first error reports.
pub fn style_plugin_expand_at_rule(name string, prelude string, body string) !string {
	mut first_err := ''
	for plugin in g_style_plugins {
		if name !in plugin.at_rules {
			continue
		}
		if plugin.expand_at_rule == unsafe { nil } {
			continue
		}
		out := plugin.expand_at_rule(name, prelude, body) or {
			if first_err == '' {
				first_err = err.msg()
			}
			continue
		}
		return out
	}
	if first_err != '' {
		return error(first_err)
	}
	return error('unknown at-rule "@${name}"')
}

// style_plugin_transform runs every registered per-element transform,
// in registration order.
pub fn style_plugin_transform(el Element, env StyleMatchEnv) Element {
	mut out := el
	for plugin in g_style_plugins {
		if plugin.transform == unsafe { nil } {
			continue
		}
		out = plugin.transform(out, env)
	}
	return out
}

// style_plugin_lint merges every registered lint pass into notes.
pub fn style_plugin_lint(sheet Stylesheet, mut notes StylesheetLintNotes) {
	for plugin in g_style_plugins {
		if plugin.lint == unsafe { nil } {
			continue
		}
		extra := plugin.lint(sheet)
		notes.errors << extra.errors
		notes.warnings << extra.warnings
	}
}

// ── Live-reload helpers ───────────────────────────────────────────
// Hot reload without threads: poll a stamp (on a timer, a button, or each
// build in debug harnesses) and re-load when it changes.
//
// ```v
// mut known := ui2.stylesheet_file_stamp('theme.vss')
// // ...later, e.g. on a Reload button:
// changed, now := ui2.stylesheet_file_changed('theme.vss', known)
// if changed {
//     ui2.set_global_stylesheet(ui2.load_stylesheet('theme.vss') or { return })
//     ui2.refresh()
//     known = now
// }
// ```

// stylesheet_file_mtime reports a stylesheet file's modification time in
// whole seconds, or 0 when it cannot be read. Two saves within one second
// share a time; use stylesheet_file_stamp to detect every change.
pub fn stylesheet_file_mtime(path string) i64 {
	info := os.stat(path) or { return 0 }
	return info.mtime
}

// stylesheet_file_stamp fingerprints a stylesheet's content plus its
// `@import` chain, so it changes on every edit — a save half a second
// after the last load, or an edit to an imported partial — where a
// whole-second mtime would not. It is 0 when the file cannot be read.
pub fn stylesheet_file_stamp(path string) u64 {
	mut visited := []string{}
	return stylesheet_stamp_file(path, mut visited)
}

fn stylesheet_stamp_file(path string, mut visited []string) u64 {
	absolute := os.real_path(path)
	if absolute in visited {
		return 0
	}
	visited << absolute
	source := os.read_file(absolute) or { return 0 }
	mut stamp := fnv1a.sum64_string(source)
	// A sheet that no longer parses still stamps its own text, so the
	// broken save registers and the reload can report the error.
	if sheet := parse_stylesheet(source) {
		base := os.dir(absolute)
		for name in sheet.imports {
			target := if os.is_abs_path(name) { name } else { os.join_path(base, name) }
			stamp = (stamp ^ stylesheet_stamp_file(target, mut visited)) * 1099511628211
		}
	}
	return if stamp == 0 { 1 } else { stamp }
}

// stylesheet_file_changed reports whether path (or anything it imports)
// changed since the known stamp, and the current stamp either way (0 when
// unreadable).
pub fn stylesheet_file_changed(path string, known u64) (bool, u64) {
	now := stylesheet_file_stamp(path)
	return now != known, now
}
