module ui2

// Stylesheet queries: @media (window/device conditions) and @container
// (ancestor size conditions), in the spirit of CSS conditional rules.
//
// A rule inside `@media ... { }` or `@container ... { }` only applies when
// its queries match. Query lists are OR (comma), `and` inside one query is
// AND, `not` negates. Nesting accumulates: a rule in `@media A` containing
// `@container B` needs both.
//
// Container queries read ancestor frames, which stylesheets cannot change
// (only box/text props are settable), so there is no layout feedback loop.
// Media queries re-evaluate on every build; resizes already rebuild.

pub struct MediaCondition {
pub:
	feature string // orientation, platform, pointer, min-width, ...
	op      string // '', 'min' or 'max'
	value   string
}

pub struct MediaQuery {
pub:
	negate     bool
	conditions []MediaCondition
}

pub struct ContainerQuery {
pub:
	name       string // ancestor id or class; '' means the parent element
	conditions []MediaCondition
}

// StyleQueryEnv carries the window/device state media queries test. It is
// built portably in the cascade; only the dpi comes from the backend, via
// StyleMatchEnv (<= 0 means unknown, and resolution queries do not match).
pub struct StyleQueryEnv {
pub:
	width    f64
	height   f64
	dpi      f64
	platform string
	coarse   bool
	dark     bool
	insets   ?SafeInsets // none = unsupported platform; env() falls back
}

// stylesheet_platform_name reports the running OS for `(platform: ...)`
// queries. Values: windows, macos, linux, ios, android, freebsd, openbsd,
// netbsd, dragonfly, solaris.
pub fn stylesheet_platform_name() string {
	os := $if windows {
		'windows'
	} $else $if macos {
		'macos'
	} $else $if ios {
		'ios'
	} $else $if android {
		'android'
	} $else $if freebsd {
		'freebsd'
	} $else $if openbsd {
		'openbsd'
	} $else $if netbsd {
		'netbsd'
	} $else $if dragonfly {
		'dragonfly'
	} $else $if solaris {
		'solaris'
	} $else {
		'linux'
	}
	return os
}

// stylesheet_is_coarse_pointer reports whether the primary pointer is touch,
// for `(pointer: coarse)` queries. Mobile builds are coarse; desktop builds
// report fine, even with a touchscreen attached.
pub fn stylesheet_is_coarse_pointer() bool {
	return $if ios || android {
		true
	} $else {
		false
	}
}

// SafeInsets carries the display safe area (notch, camera, rounded corners)
// in logical pixels: how far content must stay from each window edge.
pub struct SafeInsets {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

// stylesheet_query_env builds the media environment for this evaluation.
// bounds() is backend-provided and nil-safe; dpi comes from the frame's
// interaction env, filled in by each backend.
pub fn stylesheet_query_env(dark bool, dpi f64) StyleQueryEnv {
	area := bounds()
	return StyleQueryEnv{
		width:    area.width
		height:   area.height
		dpi:      dpi
		platform: stylesheet_platform_name()
		coarse:   stylesheet_is_coarse_pointer()
		dark:     dark
		insets:   native_safe_insets()
	}
}

// media_query_matches reports whether one media query holds. An empty
// condition list never matches (the parser rejects it anyway).
pub fn media_query_matches(query MediaQuery, env StyleQueryEnv) bool {
	if query.conditions.len == 0 {
		return false
	}
	mut holds := true
	for condition in query.conditions {
		if !media_condition_matches(condition, env) {
			holds = false
			break
		}
	}
	return if query.negate { !holds } else { holds }
}

// media_list_matches reports whether any query in a @media list holds. An
// empty list (no @media) always applies.
pub fn media_list_matches(queries []MediaQuery, env StyleQueryEnv) bool {
	if queries.len == 0 {
		return true
	}
	for query in queries {
		if media_query_matches(query, env) {
			return true
		}
	}
	return false
}

fn media_query_orientation(env StyleQueryEnv) string {
	return if env.width >= env.height { 'landscape' } else { 'portrait' }
}

fn media_condition_matches(condition MediaCondition, env StyleQueryEnv) bool {
	match condition.feature {
		'orientation' {
			return media_query_orientation(env) == condition.value
		}
		'platform' {
			return env.platform == condition.value
		}
		'pointer' {
			coarse := condition.value == 'coarse'
			return env.coarse == coarse
		}
		'prefers-color-scheme' {
			dark := condition.value == 'dark'
			return env.dark == dark
		}
		'width', 'height' {
			size := if condition.feature == 'width' { env.width } else { env.height }
			return query_length_matches(condition.op, condition.value, size)
		}
		'resolution' {
			return query_resolution_matches(condition.op, condition.value, env.dpi)
		}
		else {
			return false
		}
	}
}

fn query_length_matches(op string, raw string, size f64) bool {
	limit := query_css_length(raw) or { return false }
	return match op {
		'min' { size >= limit }
		'max' { size <= limit }
		else { size == limit }
	}
}

fn query_css_length(raw string) ?f64 {
	lower := raw.trim_space().to_lower()
	number := if lower.ends_with('px') { lower[..lower.len - 2] } else { lower }
	value := query_plain_number(number) or { return none }
	if value < 0 || value > 1000000 {
		return none
	}
	return value
}

fn query_resolution_matches(op string, raw string, dpi f64) bool {
	if dpi <= 0 {
		return false // unknown scale: fail closed
	}
	limit := query_resolution_value(raw) or { return false }
	return match op {
		'min' { dpi >= limit }
		'max' { dpi <= limit }
		else { dpi == limit }
	}
}

fn query_resolution_value(raw string) ?f64 {
	lower := raw.trim_space().to_lower()
	number := if lower.ends_with('dppx') {
		lower[..lower.len - 4]
	} else if lower.ends_with('x') {
		lower[..lower.len - 1]
	} else {
		return none
	}
	value := query_plain_number(number) or { return none }
	if value <= 0 || value > 100 {
		return none
	}
	return value
}

// container_query_matches reports whether one container query holds against
// the element's ancestors. The unnamed query tests the parent; a named one
// tests the nearest ancestor whose id or classes match.
pub fn container_query_matches(query ContainerQuery, ancestors []StyleAncestor) bool {
	target := container_query_target(query, ancestors) or { return false }
	for condition in query.conditions {
		size := if condition.feature == 'width' { target.frame.width } else { target.frame.height }
		if !query_length_matches(condition.op, condition.value, size) {
			return false
		}
	}
	return true
}

// container_match_target returns the frame source for the first matching
// query in the list, or none when nothing matches.
pub fn container_match_target(queries []ContainerQuery, ancestors []StyleAncestor) ?Element {
	for query in queries {
		if container_query_matches(query, ancestors) {
			return container_query_target(query, ancestors)
		}
	}
	return none
}

// container_list_matches reports whether any query in a @container list
// holds. An empty list (no @container) always applies.
pub fn container_list_matches(queries []ContainerQuery, ancestors []StyleAncestor) bool {
	if queries.len == 0 {
		return true
	}
	if _ := container_match_target(queries, ancestors) {
		return true
	}
	return false
}

fn container_query_target(query ContainerQuery, ancestors []StyleAncestor) ?Element {
	if ancestors.len == 0 {
		return none
	}
	if query.name.len == 0 {
		return ancestors.last().el
	}
	for i := ancestors.len - 1; i >= 0; i-- {
		el := ancestors[i].el
		if el.id == query.name || query.name in el.classes {
			return el
		}
	}
	return none
}
