module ui2

// P1 stylesheet cascade: apply parsed stylesheets to an element tree.
//
// apply_stylesheet walks the tree once, carrying the ancestor chain (for
// descendant/child selectors) and the active scope stack (global sheet plus
// every ancestor's Element.stylesheet). Matching declarations are ordered by
// (specificity, scope depth, source order) and applied in that order, so the
// strongest wins.
//
// Inline wins: a sheet declaration only fills a property the element leaves
// at its struct default. Anything a builder sets explicitly survives. The
// one caveat: explicitly setting a field to its default value (e.g.
// `bg: 0xffffff`) is indistinguishable from leaving it unset, and the sheet
// will override it. Layout-owned props (padding/margin/gap) are collected
// into warnings instead of applied; the layout code does not read them yet.

// stylesheet_known_props lists every property the cascade applies or
// deliberately defers. Anything else warns as unknown. The lint helper reads
// the same list, so the two can never disagree.
pub const stylesheet_known_props = ['background', 'background-color', 'background-gradient', 'color',
	'font-size', 'font-family', 'font-weight', 'font-style', 'text-align', 'text-decoration', 'border',
	'border-radius', 'border-color', 'border-width', 'opacity', 'box-shadow', 'padding', 'margin',
	'gap']

pub struct StylesheetWarning {
pub:
	element string
	prop    string
	message string
}

// with_classes returns el with stylesheet classes attached.
pub fn with_classes(el Element, classes ...string) Element {
	return Element{
		...el
		classes: classes.clone()
	}
}

// with_stylesheet returns el with a scoped sheet for its subtree.
pub fn with_stylesheet(el Element, sheet Stylesheet) Element {
	return Element{
		...el
		stylesheet: sheet
	}
}

// apply_stylesheet applies the global sheet to the tree rooted at root.
// Scoped Element.stylesheet sheets on the way down win over global rules on
// equal specificity; inline (builder-set) properties always win.
pub fn apply_stylesheet(root Element, global Stylesheet, env StyleMatchEnv) Element {
	result, _ := apply_stylesheet_ex(root, global, env)
	return result
}

// apply_stylesheet_ex is apply_stylesheet plus per-property warnings.
pub fn apply_stylesheet_ex(root Element, global Stylesheet, env StyleMatchEnv) (Element, []StylesheetWarning) {
	mut warnings := []StylesheetWarning{}
	mut scopes := []Stylesheet{}
	if global.rules.len > 0 {
		scopes << global
	}
	qenv := stylesheet_query_env(env.dark, env.dpi)
	root_out := cascade_element(root, [], 0, 1, scopes, env, qenv, map[string]string{}, mut warnings)
	return root_out, warnings
}

fn cascade_element(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, qenv StyleQueryEnv, inherited map[string]string, mut warnings []StylesheetWarning) Element {
	mut active := scopes.clone()
	if el.stylesheet.rules.len > 0 || el.stylesheet.variables.len > 0
		|| el.stylesheet.light_vars.len > 0 || el.stylesheet.dark_vars.len > 0 {
		active << el.stylesheet
	}
	mut out := el
	mut child_inherited := inherited.clone()
	if !el.ignore_stylesheet {
		out, child_inherited = cascade_props(el, ancestors, index, count, active, env,
			qenv, inherited, mut warnings)
	}
	mut children := []Element{cap: el.children.len}
	for child_index, child in el.children {
		ancestors_next := [...ancestors, StyleAncestor{
			el:    out
			index: index
			count: count
		}]
		children << cascade_element(child, ancestors_next, child_index, el.children.len,
			active, env, qenv, child_inherited, mut warnings)
	}
	return Element{
		...out
		children: children
	}
}

struct StyleCandidate {
	specificity int
	scope_level int
	rule_order  int
	decl_index  int
	decl        StyleDeclaration
	length      StyleLengthCtx
}

fn cascade_props(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, qenv StyleQueryEnv, inherited map[string]string, mut warnings []StylesheetWarning) (Element, map[string]string) {
	mut candidates := []StyleCandidate{}
	for scope_level, sheet in scopes {
		for rule_index, rule in sheet.rules {
			if !media_list_matches(rule.media, qenv) {
				continue
			}
			lctx := cascade_length_ctx(rule.containers, ancestors, qenv) or { continue }
			for sel in rule.selectors {
				if stylesheet_selector_matches(sel, el, ancestors, index, count, env) {
					for decl_index, decl in rule.declarations {
						candidates << StyleCandidate{
							specificity: sel.specificity
							scope_level: scope_level
							rule_order:  rule_index
							decl_index:  decl_index
							decl:        decl
							length:      lctx
						}
					}
					break
				}
			}
		}
	}
	if candidates.len == 0 {
		return el, inherited
	}
	candidates.sort_with_compare(fn (a &StyleCandidate, b &StyleCandidate) int {
		if a.specificity != b.specificity {
			return a.specificity - b.specificity
		}
		if a.scope_level != b.scope_level {
			return a.scope_level - b.scope_level
		}
		if a.rule_order != b.rule_order {
			return a.rule_order - b.rule_order
		}
		// Same rule, several declarations: source order wins, independent of
		// the sort algorithm's stability.
		return a.decl_index - b.decl_index
	})
	// Custom properties resolve in cascade order and pass down the tree;
	// normal declarations resolve against them.
	mut raw := map[string]string{}
	for candidate in candidates {
		if candidate.decl.prop.starts_with('--') {
			raw[candidate.decl.prop] = candidate.decl.value
		}
	}
	mut scope := StyleVarScope{
		scopes:    scopes
		dark:      env.dark
		inherited: inherited
		raw:       raw
	}
	mut out := el
	for candidate in candidates {
		if candidate.decl.prop.starts_with('--') {
			continue
		}
		value := cascade_resolve_inner(candidate.decl.value, mut scope) or {
			cascade_warn(mut warnings, el, candidate.decl.prop, 'unknown variable in "${candidate.decl.value}"')
			continue
		}
		out = apply_declaration(el, out, candidate.decl.prop, value, candidate.length,
			mut warnings)
	}
	mut merged := inherited.clone()
	for key, value in raw {
		merged[key] = value
	}
	for key, value in scope.resolved {
		merged[key] = value
	}
	return out, merged
}

// cascade_length_ctx builds the length basis for one rule: the window from
// the query env, the container from the rule's matched query, else the
// parent frame, else the window (the CSS small-viewport fallback).
fn cascade_length_ctx(containers []ContainerQuery, ancestors []StyleAncestor, qenv StyleQueryEnv) ?StyleLengthCtx {
	mut cont_w := qenv.width
	mut cont_h := qenv.height
	if ancestors.len > 0 {
		parent := ancestors.last().el
		cont_w = parent.frame.width
		cont_h = parent.frame.height
	}
	if containers.len > 0 {
		target := container_match_target(containers, ancestors) or { return none }
		cont_w = target.frame.width
		cont_h = target.frame.height
	}
	return StyleLengthCtx{
		win_w:  qenv.width
		win_h:  qenv.height
		cont_w: cont_w
		cont_h: cont_h
		insets: qenv.insets
	}
}

fn cascade_lookup_var(name string, scopes []Stylesheet, dark bool) ?string {
	for i := scopes.len - 1; i >= 0; i-- {
		if value := scopes[i].resolve_var(name, dark) {
			return value
		}
	}
	return none
}

// style_var_scope resolves `var()` references and `@`/`--` names against
// custom properties (nearest definition wins, inherited down the tree) and
// the in-scope theme variables. Lookups memoize; depth caps cycles.
struct StyleVarScope {
	scopes    []Stylesheet
	dark      bool
	inherited map[string]string
	raw       map[string]string
mut:
	resolved map[string]string
	depth    int
}

fn (mut s StyleVarScope) lookup(name string) !string {
	if value := s.resolved[name] {
		return value
	}
	if value := s.inherited[name] {
		return value
	}
	if raw_value := s.raw[name] {
		if s.depth >= 16 {
			return error('variable cycle through "${name}"')
		}
		s.depth++
		value := cascade_resolve_inner(raw_value, mut s) or {
			s.depth--
			return err
		}
		s.depth--
		s.resolved[name] = value
		return value
	}
	return cascade_lookup_var(name, s.scopes, s.dark) or {
		return error('unknown variable "${name}"')
	}
}

// cascade_resolve_value resolves `var()` references plus `@name`/`--name`
// names anywhere in a value, then applies a top-level `light-dark()`.
fn cascade_resolve_value(raw string, scopes []Stylesheet, dark bool, inherited map[string]string, raw_custom map[string]string) !string {
	mut scope := StyleVarScope{
		scopes:    scopes
		dark:      dark
		inherited: inherited.clone()
		raw:       raw_custom.clone()
	}
	return cascade_resolve_inner(raw, mut scope)
}

fn cascade_resolve_inner(raw string, mut scope StyleVarScope) !string {
	trimmed := raw.trim_space()
	if trimmed.to_lower().starts_with('light-dark(') && trimmed.ends_with(')') {
		inner := trimmed['light-dark('.len..trimmed.len - 1]
		parts := theme_split_commas(inner)
		if parts.len != 2 {
			return error('light-dark() needs exactly two branches')
		}
		branch := if scope.dark { parts[1] } else { parts[0] }
		return cascade_resolve_inner(branch, mut scope)
	}
	value := raw.trim_space()
	if !value.contains('@') && !value.contains('--') && !value.contains('var(')
		&& !value.contains('var (') {
		return value
	}
	mut out := []u8{}
	mut index := 0
	for index < value.len {
		word := style_var_word_at(value, index)
		if word == '@' || word == '--' {
			mut end := index + word.len
			for end < value.len && is_style_name_char(value[end]) {
				end++
			}
			key := value[index..end]
			resolved := scope.lookup(key) or { return error('unknown variable "${key}"') }
			out << resolved.bytes()
			index = end
			continue
		}
		if word == 'var' {
			end, replacement := style_var_function(value, index, mut scope) or {
				return error('unresolvable var() in "${value}"')
			}
			out << replacement.bytes()
			index = end
			continue
		}
		out << value[index]
		index++
	}
	return out.bytestr()
}

// style_var_word_at classifies the token at pos: `@`, `--`, `var` (only
// when followed by `(`), or '' for anything else. A `var` that is part of
// a longer identifier (e.g. `myvar(`) is not a function.
fn style_var_word_at(value string, pos int) string {
	if value[pos] == `@` {
		return '@'
	}
	if value[pos] == `-` && pos + 1 < value.len && value[pos + 1] == `-` {
		return '--'
	}
	if value[pos] == `v` && pos + 3 < value.len && value[pos..pos + 3] == 'var'
		&& value[pos + 3] == `(` {
		if pos > 0 && (is_style_name_char(value[pos - 1]) || value[pos - 1] == `-`) {
			return ''
		}
		return 'var'
	}
	return ''
}

// style_var_function parses `var(--name[, fallback])` at pos and returns the
// end position plus the substituted text.
fn style_var_function(value string, pos int, mut scope StyleVarScope) !(int, string) {
	mut depth := 0
	mut index := pos + 3 // past `var`
	for index < value.len {
		if value[index] == `(` {
			depth++
		} else if value[index] == `)` {
			depth--
			if depth == 0 {
				break
			}
		}
		index++
	}
	if index >= value.len {
		return error('unclosed var()')
	}
	inner := value[pos + 4..index]
	parts := theme_split_commas(inner)
	if parts.len == 0 || parts.len > 2 {
		return error('var() needs a name and optional fallback')
	}
	name := parts[0].trim_space()
	if !name.starts_with('--') || name.len <= 2 {
		return error('"${name}" is not a custom property')
	}
	if resolved := scope.lookup(name) {
		return index + 1, cascade_resolve_inner(resolved, mut scope)!
	}
	if parts.len == 2 {
		return index + 1, cascade_resolve_inner(parts[1], mut scope)!
	}
	return error('unknown variable "${name}"')
}

fn cascade_warn(mut warnings []StylesheetWarning, el Element, prop string, message string) {
	warnings << StylesheetWarning{
		element: el.id
		prop:    prop
		message: message
	}
}

// Inline wins is read off base (the pre-cascade element): checks below look
// at base, writes accumulate onto out, so later (stronger) sheet rules still
// override earlier ones while builder-set properties survive.
fn apply_declaration(base Element, out Element, prop string, value string, lctx StyleLengthCtx, mut warnings []StylesheetWarning) Element {
	match prop {
		'background', 'background-color', 'background-gradient' {
			if base.box.bg != 0xffffff || base.box.gradient.stops.len > 0 {
				return out // inline wins
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, prop, 'unparseable color: ${err.msg()}')
				return out
			}
			if token.has_gradient() {
				return Element{
					...out
					box: BoxStyle{
						...out.box
						gradient: token.gradient
					}
				}
			}
			bg := token.over(0xffffff)
			opacity := if token.opacity < 1.0 { token.opacity } else { out.box.opacity }
			return Element{
				...out
				box: BoxStyle{
					...out.box
					bg:      bg
					opacity: opacity
				}
			}
		}
		'color' {
			if base.text_style.color != 0x111111 {
				return out
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, prop, 'unparseable color: ${err.msg()}')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					color: token.over(0xffffff)
				}
			}
		}
		'font-size' {
			if base.text_style.size != 15.0 {
				return out
			}
			size := style_length_px(value, lctx) or {
				cascade_warn(mut warnings, out, prop, 'expected a length')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					size: size
				}
			}
		}
		'font-family' {
			if base.text_style.font_family.len > 0 {
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					font_family: value.trim('"\'')
				}
			}
		}
		'font-weight' {
			lower := value.to_lower()
			bold := if lower in ['bold', 'bolder'] {
				true
			} else if lower == 'normal' || lower == 'lighter' {
				false
			} else {
				(lower.int() >= 600)
			}
			if base.text_style.bold {
				return out // inline wins
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					bold: bold
				}
			}
		}
		'font-style' {
			italic := value.to_lower() == 'italic'
			if base.text_style.italic {
				return out // inline wins (default false)
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					italic: italic
				}
			}
		}
		'text-align' {
			align := match value.to_lower() {
				'left' { Align.left }
				'center' { Align.center }
				'right' { Align.right }
				else {
					cascade_warn(mut warnings, out, prop, 'expected left, center or right')
					return out
				}
			}
			if base.text_style.align != .left {
				return out // inline wins
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					align: align
				}
			}
		}
		'text-decoration' {
			lower := value.to_lower()
			if lower == 'none' {
				return out
			}
			if base.text_style.underline || base.text_style.strikethrough {
				return out // inline wins
			}
			underline := lower.contains('underline')
			strike := lower.contains('line-through') || lower.contains('strikethrough')
			if !underline && !strike {
				cascade_warn(mut warnings, out, prop, 'expected underline, line-through or none')
				return out
			}
			return Element{
				...out
				text_style: TextStyle{
					...out.text_style
					underline:     underline
					strikethrough: strike
				}
			}
		}
		'border' {
			if value.to_lower() == 'none' {
				return out
			}
			mut width := ?f64(none)
			mut color := ?u32(none)
			for part in style_split_value(value) {
				if width == none {
					if w := style_length_px(part, lctx) {
						width = w
						continue
					}
				}
				if color == none {
					if token := component_theme_token(part) {
						color = token.over(0xffffff)
					}
				}
			}
			if width == none && color == none {
				cascade_warn(mut warnings, out, prop, 'expected `<width> [style] <color>`')
				return out
			}
			w := width or { base.box.border_left }
			c := color or { base.box.border_color }
			if base.box.border_left != 0 || base.box.border_color != 0 {
				return out // inline wins
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_left:   w
					border_top:    w
					border_right:  w
					border_bottom: w
					border_color:  c
				}
			}
		}
		'border-radius' {
			if base.box.radius != 0 {
				return out
			}
			radius := style_length_px(value, lctx) or {
				cascade_warn(mut warnings, out, prop, 'expected a length')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					radius: radius
				}
			}
		}
		'border-color' {
			if base.box.border_color != 0 {
				return out
			}
			token := component_theme_token(value) or {
				cascade_warn(mut warnings, out, prop, 'unparseable color: ${err.msg()}')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_color: token.over(0xffffff)
				}
			}
		}
		'border-width' {
			if base.box.border_left != 0 || base.box.border_top != 0 || base.box.border_right != 0
				|| base.box.border_bottom != 0 {
				return out
			}
			width := style_length_px(value, lctx) or {
				cascade_warn(mut warnings, out, prop, 'expected a length')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					border_left:   width
					border_top:    width
					border_right:  width
					border_bottom: width
				}
			}
		}
		'opacity' {
			if base.box.opacity != 1.0 {
				return out
			}
			trimmed := value.trim_space()
			raw := if trimmed.ends_with('%') { trimmed[..trimmed.len - 1] } else { trimmed }
			number := query_plain_number(raw) or {
				cascade_warn(mut warnings, out, prop, 'expected a number or percentage')
				return out
			}
			opacity := if trimmed.ends_with('%') { number / 100 } else { number }
			return Element{
				...out
				box: BoxStyle{
					...out.box
					opacity: unit_clamp(opacity)
				}
			}
		}
		'box-shadow' {
			if value.to_lower() == 'none' {
				return out
			}
			if base.box.shadow.opacity != 0 {
				return out
			}
			shadow := cascade_shadow(value, lctx) or {
				cascade_warn(mut warnings, out, prop, 'expected `<color> [blur] [x y] [spread]`')
				return out
			}
			return Element{
				...out
				box: BoxStyle{
					...out.box
					shadow: shadow
				}
			}
		}
		'padding', 'margin', 'gap' {
			cascade_warn(mut warnings, out, prop, 'layout-owned in v1: parsed, not applied yet')
			return out
		}
		else {
			cascade_warn(mut warnings, out, prop, 'unknown property')
			return out
		}
	}
}

fn cascade_shadow(raw string, lctx StyleLengthCtx) ?BoxShadow {
	parts := style_split_value(raw.trim_space())
	if parts.len == 0 {
		return none
	}
	// Color is the first token that parses as a color; the rest are lengths.
	mut color := ?u32(none)
	mut opacity := 1.0
	mut numbers := []f64{}
	for part in parts {
		if token := component_theme_token(part) {
			if color == none {
				color = token.color & 0xffffff
				opacity = token.opacity
				continue
			}
		}
		numbers << style_length_px(part, lctx) or { return none }
	}
	solid := color or { return none }
	mut blur := 0.0
	mut x := 0.0
	mut y := 0.0
	mut spread := 0.0
	if numbers.len > 0 {
		blur = numbers[0]
	}
	if numbers.len > 1 {
		x = numbers[1]
	}
	if numbers.len > 2 {
		y = numbers[2]
	}
	if numbers.len > 3 {
		spread = numbers[3]
	}
	if numbers.len > 4 {
		return none
	}
	return BoxShadow{
		color:   solid
		opacity: opacity
		blur:    blur
		x:       x
		y:       y
		spread:  spread
	}
}
