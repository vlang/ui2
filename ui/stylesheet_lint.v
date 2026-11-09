module ui2

// Stylesheet lint: static notes about a parsed sheet, without an element
// tree. The parser already rejects syntax errors with line:col positions;
// this reports the semantic maybe-mistakes the cascade would otherwise only
// surface as per-element warnings at build time:
//
//   - unknown properties (not in stylesheet_known_props; `--*` custom
//     properties always pass)
//   - layout-owned properties (parsed, not applied in v1)
//   - variables that resolve in neither mode (`var()` fallbacks and
//     tree-provided custom properties only warn, since the tree is unknown)
//   - empty stylesheet (no rules and no variables)
//
// StylesheetLintNotes keeps errors (sheet cannot work as written) separate
// from warnings (works with caveats). Nothing here fails a build; the demo
// prints them in debug output, and CI can gate on errors.

pub struct StylesheetLintNotes {
pub:
	errors   []string
	warnings []string
}

pub fn (notes StylesheetLintNotes) has_errors() bool {
	return notes.errors.len > 0
}

// stylesheet_lint lints an already-parsed sheet.
pub fn stylesheet_lint(sheet Stylesheet) StylesheetLintNotes {
	mut errors := []string{}
	mut warnings := []string{}
	if sheet.rules.len == 0 && sheet.variables.len == 0 && sheet.light_vars.len == 0
		&& sheet.dark_vars.len == 0 {
		errors << 'empty stylesheet: no rules or variables'
	}
	for rule in sheet.rules {
		position := 'line ${rule.line}'
		for decl in rule.declarations {
			if decl.prop.starts_with('--') {
				// Custom properties register per element; only their values
				// lint like any other value.
				stylesheet_lint_value(sheet, decl.value, position, mut warnings, mut errors)
				continue
			}
			if decl.prop !in stylesheet_known_props {
				errors << '${position}: unknown property "${decl.prop}"'
				continue
			}
			if decl.prop in ['padding', 'margin', 'gap'] {
				warnings << '${position}: "${decl.prop}" is layout-owned in v1: parsed, not applied yet'
			}
			stylesheet_lint_value(sheet, decl.value, position, mut warnings, mut errors)
		}
	}
	return StylesheetLintNotes{
		errors:   errors
		warnings: warnings
	}
}

// stylesheet_lint_value checks one value's variable references against the
// sheet's own variables. Bare `@`/`--` names must resolve or they are
// errors; `var()` with a missing name only warns, since a custom property
// may come from an ancestor at runtime, and a missing fallback warns too.
fn stylesheet_lint_value(sheet Stylesheet, value string, position string, mut warnings []string, mut errors []string) {
	trimmed := value.trim_space()
	if var_name := stylesheet_var_ref(trimmed) {
		light := sheet.resolve_var(var_name, false)
		dark := sheet.resolve_var(var_name, true)
		if light == none && dark == none {
			errors << '${position}: unknown variable "${var_name}"'
		}
		return
	}
	mut index := 0
	for index < value.len {
		// `var(` only counts at a word boundary, so `myvar(` is ignored.
		preceded := index > 0 && (is_style_name_char(value[index - 1]) || value[index - 1] == `-`)
		if value[index] != `v` || preceded || index + 4 >= value.len
			|| value[index..index + 4] != 'var(' {
			index++
			continue
		}
		mut depth := 1
		mut end := index + 4
		for end < value.len && depth > 0 {
			if value[end] == `(` {
				depth++
			} else if value[end] == `)` {
				depth--
			}
			end++
		}
		if depth != 0 {
			warnings << '${position}: unclosed var()'
			break
		}
		inner := value[index + 4..end - 1]
		parts := theme_split_commas(inner)
		name := if parts.len > 0 { parts[0].trim_space() } else { '' }
		if name == '' || (!name.starts_with('--') && !name.starts_with('@')) {
			warnings << '${position}: var() needs a variable name'
		} else if sheet.resolve_var(name, false) == none
			&& sheet.resolve_var(name, true) == none {
			warnings << '${position}: "${name}" is not a sheet variable; it must come from the tree'
		}
		if parts.len > 1 && parts[1..].join(',').trim_space() == '' {
			warnings << '${position}: empty var() fallback never applies'
		}
		index = end
	}
}

// stylesheet_lint_source parses and lints in one step.
pub fn stylesheet_lint_source(source string) !StylesheetLintNotes {
	return stylesheet_lint(parse_stylesheet(source)!)
}

// stylesheet_var_ref returns the variable name when a value references one
// (`@name ...` or `--name ...`), else none.
fn stylesheet_var_ref(value string) ?string {
	trimmed := value.trim_space()
	if trimmed.starts_with('@') || trimmed.starts_with('--') {
		return trimmed.fields()[0]
	}
	return none
}
