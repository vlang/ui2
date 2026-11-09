module ui2

// Predefined per-platform designs for the stylesheet engine.
//
// Two looks ship with ui2: `glass` (frosted surfaces for macOS and iOS) and
// `material` (Material-3-like solid surfaces with elevation for Android).
// Pick one explicitly to use it on every platform, or use `auto` to gate
// each look behind `@media (platform: ...)` so the running OS decides and
// every other platform keeps the neutral default:
//
// ```v
// // Same frosted cards on all five backends:
// sheet := ui2.with_platform_design(my_sheet, .glass)!
//
// // macOS/iOS get glass, Android gets material, the rest stay neutral:
// ui2.set_global_stylesheet(ui2.with_platform_design(my_sheet, .auto)!)
// ```
//
// Presets only use properties the cascade applies (background, color,
// border-radius, border, box-shadow); translucency rides on box opacity —
// there is no backdrop blur in v1. Preset rules append after the base
// sheet's rules, so on equal specificity the preset wins, while builder-set
// (inline) properties still win over everything. Dark variants ride on
// `(prefers-color-scheme: dark)` in the same gate, so they follow
// `set_stylesheet_dark` like any other `@media` rule.

// StylePlatformDesign picks a predefined look. `auto` gates each preset to
// its home platforms; `glass` and `material` apply everywhere, which is
// also how you preview another platform's look on your dev machine.
pub enum StylePlatformDesign {
	auto
	glass
	material
}

// platform_design_stylesheet returns the preset rules for a design: gated
// behind `@media (platform: ...)` for `auto`, ungated otherwise.
pub fn platform_design_stylesheet(design StylePlatformDesign) !Stylesheet {
	glass_gate := if design == .auto { '@media (platform: macos), (platform: ios)' } else { '' }
	glass_dark_gate := if design == .auto {
		'@media (platform: macos) and (prefers-color-scheme: dark), (platform: ios) and (prefers-color-scheme: dark)'
	} else {
		'@media (prefers-color-scheme: dark)'
	}
	material_gate := if design == .auto { '@media (platform: android)' } else { '' }
	material_dark_gate := if design == .auto {
		'@media (platform: android) and (prefers-color-scheme: dark)'
	} else {
		'@media (prefers-color-scheme: dark)'
	}
	mut src := []string{}
	if design == .auto || design == .glass {
		src << platform_wrapped(glass_gate, 'View { background: rgba(255, 255, 255, 0.6); border-radius: 12px; border: 1px solid rgba(0, 0, 0, 0.08); box-shadow: rgba(0, 0, 0, 0.12) 16px 0 4px; }')
		src << platform_wrapped(glass_gate, 'Button { background: rgba(255, 255, 255, 0.72); border-radius: 8px; border: 1px solid rgba(0, 0, 0, 0.08); }')
		src << platform_wrapped(glass_dark_gate, 'View { background: rgba(30, 30, 32, 0.6); border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.12); box-shadow: rgba(0, 0, 0, 0.4) 16px 0 4px; }')
		src << platform_wrapped(glass_dark_gate, 'Button { background: rgba(48, 48, 52, 0.72); border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.12); color: #f5f5f7; }')
		src << platform_wrapped(glass_dark_gate, 'Label { color: #f5f5f7; }')
	}
	if design == .auto || design == .material {
		src << platform_wrapped(material_gate, 'Button { background: #6750a4; color: white; border-radius: 20px; box-shadow: rgba(0, 0, 0, 0.3) 6px 0 2px; }')
		src << platform_wrapped(material_gate, 'View { background: #ffffff; border-radius: 12px; box-shadow: rgba(0, 0, 0, 0.18) 8px 0 4px; }')
		src << platform_wrapped(material_dark_gate, 'Button { background: #d0bcff; color: #381e72; border-radius: 20px; box-shadow: rgba(0, 0, 0, 0.5) 6px 0 2px; }')
		src << platform_wrapped(material_dark_gate, 'View { background: #141218; border-radius: 12px; box-shadow: rgba(0, 0, 0, 0.5) 8px 0 4px; }')
		src << platform_wrapped(material_dark_gate, 'Label { color: #e6e0e9; }')
	}
	return parse_stylesheet(src.join('\n'))!
}

// platform_wrapped puts a rule inside its `@media` gate, or returns it
// bare when the gate is empty (a forced preset applies everywhere).
fn platform_wrapped(gate string, rule string) string {
	if gate == '' {
		return rule
	}
	return '${gate} { ${rule} }'
}

// with_platform_design returns base with the preset rules appended. Later
// source order wins equal-specificity ties, so the preset overrides the
// base sheet where they both set a property; base variables and imports
// carry over untouched.
pub fn with_platform_design(base Stylesheet, design StylePlatformDesign) !Stylesheet {
	preset := platform_design_stylesheet(design)!
	mut rules := base.rules.clone()
	rules << preset.rules
	return Stylesheet{
		rules:      rules
		variables:  base.variables.clone()
		light_vars: base.light_vars.clone()
		dark_vars:  base.dark_vars.clone()
		imports:    base.imports.clone()
		rule_index: stylesheet_index_rules(rules)
	}
}
