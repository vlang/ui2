module ui2

// Stylesheet DSL: build the same StyleRule list the string parser produces,
// with compile-time-checked V values instead of a parsed string. Cascade and
// matching cannot tell which authored a rule.

// style_rule parses one selector (or selector group) and attaches raw
// property values. Values use the same grammar as the string form, including
// `@variables`.
pub fn style_rule(selector string, props map[string]string) !StyleRule {
	parsed := parse_stylesheet('${selector} { __dsl: 0; }') or {
		return error('bad selector "${selector}": ${err.msg()}')
	}
	// Re-parse properly to keep positions honest is overkill; reuse the
	// selector the parser accepted and attach the real declarations.
	sel := parsed.rules[0].selectors
	mut keys := props.keys()
	keys.sort()
	mut declarations := []StyleDeclaration{cap: props.len}
	for key in keys {
		prop := key.trim_space().to_lower()
		if prop.len == 0 {
			return error('empty property name in style_rule("${selector}")')
		}
		declarations << StyleDeclaration{
			prop:  prop
			value: props[key]
			line:  1
			col:   1
		}
	}
	if declarations.len == 0 {
		return error('style_rule("${selector}") has no declarations')
	}
	return StyleRule{
		selectors:    sel
		declarations: declarations
		line:         1
		col:          1
	}
}

// style_rule_guarded is style_rule plus @media/@container preludes, parsed
// with the same grammar as the string form. Empty preludes mean no queries.
pub fn style_rule_guarded(selector string, props map[string]string, media_src string, container_src string) !StyleRule {
	base := style_rule(selector, props)!
	media := if media_src.trim_space().len > 0 {
		parse_media_prelude(media_src)!
	} else {
		[]MediaQuery{}
	}
	containers := if container_src.trim_space().len > 0 {
		parse_container_prelude(container_src)!
	} else {
		[]ContainerQuery{}
	}
	return StyleRule{
		...base
		media:      media
		containers: containers
	}
}

// stylesheet_from_rules bundles DSL-built rules into a Stylesheet.
pub fn stylesheet_from_rules(rules []StyleRule, variables map[string]string) Stylesheet {
	return Stylesheet{
		rules:     rules.clone()
		variables: variables.clone()
	}
}
