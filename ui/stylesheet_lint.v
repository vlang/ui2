module ui2

// Stylesheet lint: static notes about a parsed sheet, without an element
// tree. The parser already rejects syntax errors with line:col positions;
// this reports the semantic maybe-mistakes the cascade would otherwise only
// surface as per-element warnings at build time:
//
//   - unknown properties (not in stylesheet_known_props)
//   - layout-owned properties (parsed, not applied in v1)
//   - variables that resolve in neither mode
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
			if decl.prop !in stylesheet_known_props {
				errors << '${position}: unknown property "${decl.prop}"'
				continue
			}
			if decl.prop in ['padding', 'margin', 'gap'] {
				warnings << '${position}: "${decl.prop}" is layout-owned in v1: parsed, not applied yet'
			}
			if var_name := stylesheet_var_ref(decl.value) {
				light := sheet.resolve_var(var_name, false)
				dark := sheet.resolve_var(var_name, true)
				if light == none && dark == none {
					errors << '${position}: unknown variable "${var_name}"'
				}
			}
		}
	}
	return StylesheetLintNotes{
		errors:   errors
		warnings: warnings
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
