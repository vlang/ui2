module ui2

// Stylesheets inside VML: co-locate style with markup instead of repeating
// inline props on every node.
//
// ```vml
// Screen {
//     Style {
//         Button.primary { background: #3478D4; color: white; border-radius: 7px; }
//         Label.title { font-size: 20px; }
//     }
//     Button {
//         id: increment
//         class: primary
//         text: "Count"
//     }
// }
// ```
//
// Three pieces, mirroring HTML:
//   - `Style { ... }` blocks hold raw `.vss` source and become the node's
//     scoped stylesheet (several blocks merge in order). They match the
//     node's whole subtree, so one block on `Screen` themes the document.
//   - `class: "a b"` puts the node in stylesheet classes, which is what the
//     block above matches on. VML never had classes before; ids keep working.
//   - `style: "background: red; opacity: 0.9"` holds inline declarations for
//     one node, for properties with no VML prop (opacity, box-shadow, ...).
//     Like any inline value it beats sheets; individual VML props
//     (`background:`, `font_size:`) beat it in turn.
//
// A VML tree runs through the same cascade as builder trees. Built inside a
// running window, the backend's frame pass styles it with live hover,
// press, focus and dpi, so interaction pseudos work like on builder trees.
// Built standalone (`element_from_vml` / `element_from_vnode` outside a
// frame, e.g. in tests), it is styled at that boundary: in-document sheets
// always, the global sheet when set; interaction pseudos stay quiet there.
// Inline `style:` takes plain values only: no sheet variables, and lengths
// resolve against the node's own frame.

// v_classes splits a node's `class:` prop into stylesheet classes.
fn v_classes(node &VNode) []string {
	return node.prop('class').fields()
}

// v_style_sheet merges a node's direct `Style {}` children into one scoped
// sheet. Later blocks win ties, like later rules in one file.
fn v_style_sheet(node &VNode) !Stylesheet {
	mut rules := []StyleRule{}
	mut variables := map[string]string{}
	mut light_vars := map[string]string{}
	mut dark_vars := map[string]string{}
	for child in node.children {
		if child.tag != 'Style' {
			continue
		}
		sheet := parse_stylesheet(child.prop('source')) or {
			return error('invalid `Style` block (line ${child.line}): ${err.msg()}')
		}
		if sheet.imports.len > 0 {
			return error('invalid `Style` block (line ${child.line}): `@import` needs a file; inline the sheet or style from V')
		}
		rules << sheet.rules
		for key, value in sheet.variables {
			variables[key] = value
		}
		for key, value in sheet.light_vars {
			light_vars[key] = value
		}
		for key, value in sheet.dark_vars {
			dark_vars[key] = value
		}
	}
	return Stylesheet{
		rules:      rules
		variables:  variables
		light_vars: light_vars
		dark_vars:  dark_vars
		rule_index: stylesheet_index_rules(rules)
	}
}

// v_inline_style applies a node's `style: "..."` declarations as inline
// values on top of the builder-set props. Individual VML props already
// filled their fields, and inline wins only fills defaults, so on a shared
// property the VML prop keeps precedence. Like sheet declarations, values
// that do not apply (layout-owned props, unparseable values) are skipped,
// not fatal; only a syntax error fails the document. Values resolve in the
// live color mode and device scale, so `light-dark()` follows the sheet.
fn v_inline_style(node &VNode, el Element, frame Rect) !Element {
	raw := node.prop('style').trim_space()
	if raw == '' {
		return el
	}
	sheet := parse_stylesheet('* { ${raw} }') or {
		return error('invalid `style` on <${node.tag}> (line ${node.line}): ${err.msg()}')
	}
	if sheet.rules.len == 0 {
		return el
	}
	dark := stylesheet_dark_mode()
	qenv := stylesheet_query_env(dark, stylesheet_live_dpi())
	lctx := StyleLengthCtx{
		win_w:  qenv.width
		win_h:  qenv.height
		cont_w: frame.width
		cont_h: frame.height
		insets: qenv.insets
	}
	mut scope := StyleVarScope{
		scopes:    []
		dark:      dark
		inherited: map[string]string{}
		raw:       map[string]string{}
	}
	mut warnings := []StylesheetWarning{}
	mut color_cache := map[string]ComponentThemeToken{}
	mut len_cache := map[string]f64{}
	mut split_cache := map[string][]string{}
	mut fill := StyleFill{}
	mut out := el
	for decl in sheet.rules[0].declarations {
		if decl.prop.starts_with('--') {
			return error('invalid `style` on <${node.tag}> (line ${node.line}): custom properties need a `Style` block')
		}
		value := cascade_resolve_inner(decl.value, mut scope) or {
			return error('invalid `style` on <${node.tag}> (line ${node.line}): ${err.msg()}')
		}
		out = apply_declaration(&el, out, decl.prop, value, lctx, mut fill, mut warnings, mut
			color_cache, mut len_cache, mut split_cache)
	}
	return style_fill_finish(&el, out, fill)
}

// vml_styled_tree runs a freshly built VML tree through the cascade: the
// global sheet when one is set, in-document `Style` scopes regardless.
// Without either it is a plain walk that changes nothing, so unstyled
// documents pay almost nothing for the feature existing.
//
// Inside a backend's build (stylesheet_frame_build) the tree is returned
// unstyled: the backend's frame pass styles it once, with live hover,
// press, focus and dpi. Styling it here too would run plugin transforms
// twice and leave first-pass values looking like inline props, which
// interaction pseudos could then never override.
fn vml_styled_tree(el Element) Element {
	if g_stylesheet_frame_building > 0 {
		return el
	}
	global := if g_stylesheet_has_global { g_stylesheet_global } else { Stylesheet{} }
	return apply_stylesheet(el, global, StyleMatchEnv{
		dark: stylesheet_dark_mode()
		dpi:  stylesheet_live_dpi()
	})
}
