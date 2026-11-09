module ui2

// Stylesheet lint: static notes about a parsed sheet, without an element
// tree. The parser already rejects syntax errors with line:col positions;
// this reports the semantic maybe-mistakes the cascade would otherwise only
// surface as per-element warnings at build time:
//
//   - unknown properties (not in stylesheet_known_props; `--*` custom
//     properties always pass)
//   - layout-owned properties (parsed, not applied in v1)
//   - variable references, found exactly where the cascade finds them
//     (anywhere in a value, inside `var()` fallbacks too):
//       `@name` that the sheet never defines is an error, since `@`
//       variables are sheet variables;
//       `--name` the sheet never defines only warns, bare or in `var()`
//       alike, since a custom property may come from an ancestor at
//       runtime; `var()` must name a `--` custom property
//   - empty stylesheet (no rules, variables or imports)
//
// StylesheetLintNotes keeps errors (sheet cannot work as written) separate
// from warnings (works with caveats). Nothing here fails a build; the demo
// prints them in debug output, and CI can gate on errors. Positions are
// each declaration's own line.

pub struct StylesheetLintNotes {
pub mut:
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
	if stylesheet_is_empty(sheet) && sheet.imports.len == 0 {
		errors << 'empty stylesheet: no rules, variables or imports'
	}
	for rule in sheet.rules {
		for decl in rule.declarations {
			position := 'line ${if decl.line > 0 { decl.line } else { rule.line }}'
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
	mut notes := StylesheetLintNotes{
		errors:   errors
		warnings: warnings
	}
	style_plugin_lint(sheet, mut notes)
	return notes
}

// stylesheet_lint_value checks every variable reference in a value against
// the sheet's own variables, scanning the way the cascade resolves: bare
// `@name`/`--name` anywhere, and `var()` with its fallback.
fn stylesheet_lint_value(sheet Stylesheet, value string, position string, mut warnings []string, mut errors []string) {
	mut index := 0
	for index < value.len {
		word := style_var_word_at(value, index)
		if word == '@' || word == '--' {
			mut end := index + word.len
			for end < value.len && is_style_name_char(value[end]) {
				end++
			}
			name := value[index..end]
			if name.len == word.len {
				errors << '${position}: "${word}" needs a variable name'
			} else {
				stylesheet_lint_name(sheet, name, position, mut warnings, mut errors)
			}
			index = end
			continue
		}
		if word != 'var' {
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
			errors << '${position}: unclosed var()'
			return
		}
		// Like the cascade, the fallback is everything after the first
		// top-level comma.
		raw_name, fallback := style_split_first_comma(value[index + 4..end - 1])
		name := raw_name.trim_space()
		if !name.starts_with('--') || name.len <= 2 {
			errors << '${position}: var() takes a `--name` custom property, not "${name}"'
		} else {
			stylesheet_lint_name(sheet, name, position, mut warnings, mut errors)
		}
		if fb := fallback {
			if fb.trim_space() == '' {
				warnings << '${position}: empty var() fallback never applies'
			} else {
				stylesheet_lint_value(sheet, fb, position, mut warnings, mut errors)
			}
		}
		index = end
	}
}

// stylesheet_lint_name reports one referenced name the sheet never defines:
// an error for `@` sheet variables, a warning for `--` custom properties,
// which an ancestor may provide at runtime.
fn stylesheet_lint_name(sheet Stylesheet, name string, position string, mut warnings []string, mut errors []string) {
	if sheet.resolve_var(name, false) != none || sheet.resolve_var(name, true) != none {
		return
	}
	if name.starts_with('@') {
		errors << '${position}: unknown variable "${name}"'
	} else {
		warnings << '${position}: "${name}" is not a sheet variable; it must come from the tree'
	}
}

// stylesheet_lint_source parses and lints in one step.
pub fn stylesheet_lint_source(source string) !StylesheetLintNotes {
	return stylesheet_lint(parse_stylesheet(source)!)
}
