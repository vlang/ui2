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
	// Colors parse independent of the element, so one run-wide cache serves
	// every declaration: sheets repeat the same few values.
	mut color_cache := map[string]ComponentThemeToken{}
	mut len_cache := map[string]f64{}
	mut split_cache := map[string][]string{}
	root_out := cascade_element(root, [], 0, 1, scopes, env, qenv, map[string]string{},
		mut warnings, mut color_cache, mut len_cache, mut split_cache)
	return root_out, warnings
}

fn cascade_element(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, qenv StyleQueryEnv, inherited map[string]string, mut warnings []StylesheetWarning, mut color_cache map[string]ComponentThemeToken, mut len_cache map[string]f64, mut split_cache map[string][]string) Element {
	// No clone when the element brings no scoped sheet: scopes is only read.
	has_scoped := el.stylesheet.rules.len > 0 || el.stylesheet.variables.len > 0
		|| el.stylesheet.light_vars.len > 0 || el.stylesheet.dark_vars.len > 0
	mut active := scopes
	if has_scoped {
		active = scopes.clone()
		active << el.stylesheet
	}
	// The inherited map is shared (never mutated in place: cascade_props
	// clones before merging), threaded through a return because V forbids
	// aliasing a map into a mutable local.
	mut out, child_inherited := cascade_props_or_share(el, ancestors, index, count, active, env,
		qenv, inherited, mut warnings, mut color_cache, mut len_cache, mut split_cache)
	// Plugin transforms run post-cascade, top-down: children see the
	// transformed parent. Identity and kind are pinned so a transform
	// cannot break reconciliation or dispatch; children are replaced
	// below regardless. Skipped entirely when no plugin is registered.
	if g_style_plugins.len > 0 {
		transformed := style_plugin_transform(out, env)
		if transformed.id != out.id || transformed.kind != out.kind {
			// Keep the tree valid even for a misbehaving plugin.
			out = Element{
				...transformed
				id:   out.id
				kind: out.kind
			}
		} else {
			out = transformed
		}
	}
	// One chain per element, not per child: every sibling shares it.
	ancestors_next := [...ancestors, StyleAncestor{
		el:    out
		index: index
		count: count
	}]
	mut children := []Element{cap: el.children.len}
	for child_index, child in el.children {
		children << cascade_element(child, ancestors_next, child_index, el.children.len,
			active, env, qenv, child_inherited, mut warnings, mut color_cache, mut len_cache,
			mut split_cache)
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

// cascade_props_or_share runs the cascade unless the element opts out, in
// which case the inherited map passes through shared.
fn cascade_props_or_share(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, qenv StyleQueryEnv, inherited map[string]string, mut warnings []StylesheetWarning, mut color_cache map[string]ComponentThemeToken, mut len_cache map[string]f64, mut split_cache map[string][]string) (Element, map[string]string) {
	if el.ignore_stylesheet {
		return el, inherited
	}
	return cascade_props(el, ancestors, index, count, scopes, env, qenv, inherited,
		mut warnings, mut color_cache, mut len_cache, mut split_cache)
}

fn cascade_props(el Element, ancestors []StyleAncestor, index int, count int, scopes []Stylesheet, env StyleMatchEnv, qenv StyleQueryEnv, inherited map[string]string, mut warnings []StylesheetWarning, mut color_cache map[string]ComponentThemeToken, mut len_cache map[string]f64, mut split_cache map[string][]string) (Element, map[string]string) {
	mut candidates := []StyleCandidate{}
	kind_name := el.kind.str()
	for scope_level, sheet in scopes {
		if stylesheet_index_covers(sheet) {
			cascade_indexed_candidates(sheet, scope_level, kind_name, el, ancestors,
				index, count, env, qenv, mut candidates)
			continue
		}
		for rule_index, rule in sheet.rules {
			cascade_rule_candidates(rule, rule_index, scope_level, el, ancestors, index, count,
				env, qenv, mut candidates)
		}
	}
	if candidates.len == 0 {
		return el, inherited
	}
	// Usually already ordered (rules author low→high specificity): one linear
	// check, which is also the sort's fixed point, skips the closure sort.
	if candidates.len > 1 && !candidates_in_order(candidates) {
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
	}
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
	// Resolve pass: every candidate resolves in order (warnings keep their
	// sequence), then the apply pass runs only survivors. A repeated
	// value-setting property applies once — its last resolved candidate —
	// instead of copying the whole element per override. Exempt props keep
	// every application: backgrounds fold an opacity side effect into later
	// rules, `text-decoration: none` keeps earlier decoration, and
	// layout-owned/unknown props warn per declaration.
	mut resolved := []string{len: candidates.len}
	mut failed := []bool{len: candidates.len}
	for i, candidate in candidates {
		if candidate.decl.prop.starts_with('--') {
			continue
		}
		resolved[i] = cascade_resolve_inner(candidate.decl.value, mut scope) or {
			cascade_warn(mut warnings, el, candidate.decl.prop, 'unknown variable in "${candidate.decl.value}"')
			failed[i] = true
			continue
		}
	}
	for i, candidate in candidates {
		if candidate.decl.prop.starts_with('--') {
			continue
		}
		if failed[i] {
			continue
		}
		if cascade_foldable(candidate.decl.prop) {
			mut superseded := false
			for j := i + 1; j < candidates.len; j++ {
				if !failed[j] && candidates[j].decl.prop == candidate.decl.prop {
					superseded = true
					break
				}
			}
			if superseded {
				continue
			}
		}
		out = apply_declaration(&el, out, candidate.decl.prop, resolved[i], candidate.length,
			mut warnings, mut color_cache, mut len_cache, mut split_cache)
	}
	if raw.len == 0 && scope.resolved.len == 0 {
		// No custom properties produced: the inherited map passes through
		// shared instead of cloned.
		return out, inherited
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

// cascade_rule_candidates appends one rule's declarations for the first
// matching selector. Media gates are element-independent but cheap; the
// length context (container lookup) is built only after a selector
// matches, so non-matching rules cost just the match attempt.
fn cascade_rule_candidates(rule StyleRule, rule_index int, scope_level int, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv, qenv StyleQueryEnv, mut candidates []StyleCandidate) {
	if !media_list_matches(rule.media, qenv) {
		return
	}
	for sel in rule.selectors {
		if stylesheet_selector_matches(sel, el, ancestors, index, count, env) {
			lctx := cascade_length_ctx(rule.containers, ancestors, qenv) or { return }
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
			return
		}
	}
}

// cascade_indexed_candidates runs only the rules an element can match: the
// union of its kind, id, and class buckets plus the universal bucket,
// sorted back into source order with duplicates (one rule filed under
// several subjects) applied once. Rules without an index fall back to the
// full scan in the caller, and every gathered rule still runs the complete
// selector, media, and container checks — the index only skips rules whose
// subject can never match.
fn cascade_indexed_candidates(sheet Stylesheet, scope_level int, kind_name string, el Element, ancestors []StyleAncestor, index int, count int, env StyleMatchEnv, qenv StyleQueryEnv, mut candidates []StyleCandidate) {
	mut order := sheet.rule_index.universal.clone()
	if kinds := sheet.rule_index.by_kind[kind_name] {
		order << kinds
	}
	if el.id.len > 0 {
		if ids := sheet.rule_index.by_id[el.id] {
			order << ids
		}
	}
	for class in el.classes {
		if rows := sheet.rule_index.by_class[class] {
			order << rows
		}
	}
	if order.len == 0 {
		return
	}
	order.sort()
	mut prev := -1
	for rule_index in order {
		if rule_index == prev {
			continue
		}
		prev = rule_index
		cascade_rule_candidates(sheet.rules[rule_index], rule_index, scope_level, el,
			ancestors, index, count, env, qenv, mut candidates)
	}
}

// candidates_in_order reports whether candidates already match the
// comparator below: specificity, scope, rule, then declaration order. That
// order is the sort's fixed point, so checking first skips the sort.
fn candidates_in_order(candidates []StyleCandidate) bool {
	for i in 1 .. candidates.len {
		a := candidates[i - 1]
		b := candidates[i]
		if a.specificity > b.specificity {
			return false
		}
		if a.specificity == b.specificity {
			if a.scope_level > b.scope_level {
				return false
			}
			if a.scope_level == b.scope_level {
				if a.rule_order > b.rule_order {
					return false
				}
				if a.rule_order == b.rule_order && a.decl_index > b.decl_index {
					return false
				}
			}
		}
	}
	return true
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

// cascade_foldable reports whether a property applies purely — later
// declarations fully overwrite earlier ones — so only the last resolved
// candidate needs applying. Backgrounds carry an opacity side effect into
// later rules, `text-decoration: none` preserves earlier decoration, and
// layout-owned/unknown props warn per declaration, so those stay unfolded.
fn cascade_foldable(prop string) bool {
	return prop == 'color' || prop == 'font-size' || prop == 'font-family'
		|| prop == 'font-weight' || prop == 'font-style' || prop == 'text-align'
		|| prop == 'border' || prop == 'border-radius' || prop == 'border-color'
		|| prop == 'border-width' || prop == 'opacity' || prop == 'box-shadow'
}

fn cascade_lookup_var(name string, scopes []Stylesheet, dark bool) ?string {
	for i := scopes.len - 1; i >= 0; i-- {
		if value := scopes[i].resolve_var(name, dark) {
			return value
		}
	}
	return none
}

// cascade_token parses a color value, memoizing successes per cascade run.
// Color values do not depend on the element (no lengths, no variables left
// — those resolve before apply_declaration runs), and sheets repeat the
// same few values across every element.
fn cascade_token(value string, mut color_cache map[string]ComponentThemeToken) !ComponentThemeToken {
	if token := color_cache[value] {
		return token
	}
	token := component_theme_token(value)!
	color_cache[value] = token
	return token
}

// cascade_length_px resolves a length, memoizing the plain-number case per
// cascade run. Only `12px`/`4`-shaped values qualify: anything with units
// needing the length context (percent, viewport, container), functions, or
// operators always takes the slow path.
fn cascade_length_px(raw string, lctx StyleLengthCtx, mut len_cache map[string]f64) ?f64 {
	trimmed := raw.trim_space()
	if cached := len_cache[trimmed] {
		return cached
	}
	if !is_plain_length(trimmed) {
		return style_length_px(trimmed, lctx)
	}
	value := style_length_px(trimmed, lctx) or { return none }
	len_cache[trimmed] = value
	return value
}

// is_plain_length reports whether text is an optional `-`, digits with at
// most one `.`, and an optional `px` — the only spellings whose length
// never consults the context.
fn is_plain_length(text string) bool {
	mut i := 0
	if text.starts_with('-') {
		i++
	}
	mut digits := 0
	mut points := 0
	for i < text.len {
		ch := text[i]
		if ch >= `0` && ch <= `9` {
			digits++
		} else if ch == `.` {
			points++
			if points > 1 {
				return false
			}
		} else {
			break
		}
		i++
	}
	if digits == 0 {
		return false
	}
	rest := text[i..]
	return rest == '' || rest == 'px'
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
	// Fast path first, usually allocation-free: most values carry no
	// variables, need no trim, and are not light-dark(). The trim is skipped
	// when neither end has whitespace; the lowercase check runs only for
	// values starting with l/L.
	value := if needs_trim(raw) { raw.trim_space() } else { raw }
	if !value.contains('@') && !value.contains('--') && !value.contains('var(')
		&& !value.contains('var (') {
		if value.len > 11 && (value[0] == `l` || value[0] == `L`) {
			if value.to_lower().starts_with('light-dark(') && value.ends_with(')') {
				return cascade_resolve_value_light_dark(value, mut scope)
			}
		}
		return value
	}
	if value.to_lower().starts_with('light-dark(') && value.ends_with(')') {
		return cascade_resolve_value_light_dark(value, mut scope)
	}
	// Markers are present here: the fast path above returned otherwise.
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

// needs_trim reports whether trimming would change the string.
fn needs_trim(s string) bool {
	if s.len == 0 {
		return false
	}
	first := s[0]
	last := s[s.len - 1]
	return first == ` ` || first == `\t` || first == `\n` || first == `\r` || last == ` `
		|| last == `\t` || last == `\n` || last == `\r`
}

// cascade_resolve_value_light_dark resolves a top-level `light-dark(a, b)`.
fn cascade_resolve_value_light_dark(trimmed string, mut scope StyleVarScope) !string {
	inner := trimmed['light-dark('.len..trimmed.len - 1]
	parts := theme_split_commas(inner)
	if parts.len != 2 {
		return error('light-dark() needs exactly two branches')
	}
	branch := if scope.dark { parts[1] } else { parts[0] }
	return cascade_resolve_inner(branch, mut scope)
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
// Inline wins is read off base (the pre-cascade element): checks below look
// at base, writes accumulate onto out, so later (stronger) sheet rules still
// override earlier ones while builder-set properties survive. base travels
// by reference: declarations apply per element per rule, and it is only
// ever read.
fn apply_declaration(base &Element, out Element, prop string, value string, lctx StyleLengthCtx, mut warnings []StylesheetWarning, mut color_cache map[string]ComponentThemeToken, mut len_cache map[string]f64, mut split_cache map[string][]string) Element {
	match prop {
		'background', 'background-color', 'background-gradient' {
			if base.box.bg != 0xffffff || base.box.gradient.stops.len > 0 {
				return out // inline wins
			}
			token := cascade_token(value, mut color_cache) or {
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
			token := cascade_token(value, mut color_cache) or {
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
			size := cascade_length_px(value, lctx, mut len_cache) or {
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
			for part in cascade_split_value(value, mut split_cache) {
				if width == none {
					if w := cascade_length_px(part, lctx, mut len_cache) {
						width = w
						continue
					}
				}
				if color == none {
					if token := cascade_token(part, mut color_cache) {
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
			radius := cascade_length_px(value, lctx, mut len_cache) or {
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
			token := cascade_token(value, mut color_cache) or {
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
			width := cascade_length_px(value, lctx, mut len_cache) or {
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
			trimmed := if needs_trim(value) { value.trim_space() } else { value }
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
			shadow := cascade_shadow(value, lctx, mut color_cache, mut len_cache, mut split_cache) or {
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

// cascade_split_value splits a shorthand value, memoizing per cascade run.
// Shorthand text is element-independent; sheets repeat the same few
// spellings across every element.
fn cascade_split_value(value string, mut split_cache map[string][]string) []string {
	if cached := split_cache[value] {
		return cached
	}
	parts := style_split_value(value)
	split_cache[value] = parts
	return parts
}

fn cascade_shadow(raw string, lctx StyleLengthCtx, mut color_cache map[string]ComponentThemeToken, mut len_cache map[string]f64, mut split_cache map[string][]string) ?BoxShadow {
	parts := cascade_split_value(raw.trim_space(), mut split_cache)
	if parts.len == 0 {
		return none
	}
	// Color is the first token that parses as a color; the rest are lengths.
	mut color := ?u32(none)
	mut opacity := 1.0
	mut numbers := []f64{}
	for part in parts {
		if token := cascade_token(part, mut color_cache) {
			if color == none {
				color = token.color & 0xffffff
				opacity = token.opacity
				continue
			}
		}
		numbers << cascade_length_px(part, lctx, mut len_cache) or { return none }
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
