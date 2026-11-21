module ui2

// Keep longhand source lists until the controlling property/name list is known.
// This makes list repetition independent of declaration order.
fn apply_style_animation_decl(el Element, prop string, value string) Element {
	if !style_animation_decl_valid(prop, value) { return el }
	mut out := el
	if prop == 'transition' || prop.starts_with('transition-') {
		mut values := el.style_transition_values.clone()
		if prop == 'transition' { values.clear() }
		values[prop] = value
		out.style_transition_values = values.clone()
		out.style_transitions = resolve_style_transitions(values)
	} else {
		mut values := el.style_animation_values.clone()
		if prop == 'animation' { values.clear() }
		values[prop] = value
		out.style_animation_values = values.clone()
		out.style_animations = resolve_style_animations(values)
	}
	return out
}

fn style_animation_decl_valid(prop string, value string) bool {
	for raw in split_top_level_commas(value) {
		v := raw.trim_space()
		if prop.ends_with('-duration') || prop.ends_with('-delay') {
			n := parse_time_seconds(v) or { return false }
			if prop.ends_with('-duration') && n < 0 { return false }
		} else if prop.ends_with('-timing-function') {
			if parse_timing_token(v) == none && parse_cubic_bezier(v) == none { return false }
		} else if prop == 'animation-iteration-count' {
			if !is_iteration_token(v) { return false }
		} else if prop == 'animation-direction' && !is_direction_token(v) {
			return false
		} else if prop == 'animation-fill-mode' && !is_fill_token(v) {
			return false
		} else if prop == 'animation-play-state' && !is_play_state_token(v) {
			return false
		}
	}
	return true
}

fn style_list_value(values map[string]string, prop string, index int) ?string {
	raw := values[prop] or { return none }
	list := split_top_level_commas(raw)
	return list[index % list.len].trim_space()
}

fn resolve_style_transitions(values map[string]string) []StyleTransition {
	mut base := [StyleTransition{ properties: ['all'], duration: 0.2, timing: .out_cubic }]
	if shorthand := values['transition'] { base = parse_transition_shorthand(shorthand) }
	mut count := base.len
	if props := values['transition-property'] {
		if props.trim_space().to_lower() == 'none' { return []StyleTransition{} }
		count = split_top_level_commas(props).len
	}
	mut out := []StyleTransition{}
	for i in 0 .. count {
		mut entry := if base.len > 0 {
			base[i % base.len]
		} else {
			StyleTransition{ properties: ['all'], duration: 0.2, timing: .out_cubic }
		}
		if prop := style_list_value(values, 'transition-property', i) {
			entry.properties = [prop.to_lower()]
		}
		if raw := style_list_value(values, 'transition-duration', i) {
			entry.duration = parse_time_seconds(raw) or { entry.duration }
		}
		if raw := style_list_value(values, 'transition-delay', i) {
			entry.delay = parse_time_seconds(raw) or { entry.delay }
		}
		if raw := style_list_value(values, 'transition-timing-function', i) {
			entry.timing_fn = unsafe { nil }
			if timing := parse_timing_token(raw) {
				entry.timing = timing
			} else if f := parse_cubic_bezier(raw) {
				entry.timing = .linear
				entry.timing_fn = f
			}
		}
		out << entry
	}
	return out
}

fn parse_transition_shorthand(value string) []StyleTransition {
	if value.trim_space().to_lower() == 'none' { return []StyleTransition{} }
	mut out := []StyleTransition{}
	for entry in split_top_level_commas(value) {
		mut tr := StyleTransition{ properties: ['all'], duration: 0.2, timing: .out_cubic }
		mut times := 0
		for token in split_shorthand_tokens(entry) {
			if n := parse_time_seconds(token) {
				if times == 0 { tr.duration = n } else { tr.delay = n }
				times++
			} else if t := parse_timing_token(token) {
				tr.timing = t
			} else if f := parse_cubic_bezier(token) {
				tr.timing = .linear
				tr.timing_fn = f
			} else {
				tr.properties = [token.trim_space().to_lower()]
			}
		}
		if tr.duration >= 0 { out << tr }
	}
	return out
}

fn resolve_style_animations(values map[string]string) []StyleAnimation {
	mut base := [default_style_animation()]
	if shorthand := values['animation'] { base = parse_animation_shorthand(shorthand) }
	mut count := base.len
	if names := values['animation-name'] { count = split_top_level_commas(names).len }
	mut out := []StyleAnimation{}
	for i in 0 .. count {
		mut entry := if base.len > 0 { base[i % base.len] } else { default_style_animation() }
		if raw := style_list_value(values, 'animation-name', i) {
			entry.name = if raw.to_lower() == 'none' { '' } else { raw }
		}
		if raw := style_list_value(values, 'animation-duration', i) {
			entry.duration = parse_time_seconds(raw) or { entry.duration }
		}
		if raw := style_list_value(values, 'animation-delay', i) {
			entry.delay = parse_time_seconds(raw) or { entry.delay }
		}
		if raw := style_list_value(values, 'animation-timing-function', i) {
			entry.timing_fn = unsafe { nil }
			if t := parse_timing_token(raw) {
				entry.timing = t
			} else if f := parse_cubic_bezier(raw) {
				entry.timing = .linear
				entry.timing_fn = f
			}
		}
		if raw := style_list_value(values, 'animation-iteration-count', i) {
			entry.iteration_count = if raw.to_lower() == 'infinite' {
				0.0
			} else {
				query_plain_number(raw) or { 1.0 }
			}
			entry.infinite = raw.to_lower() == 'infinite'
		}
		if raw := style_list_value(values, 'animation-direction', i) {
			entry.direction = raw.to_lower()
		}
		if raw := style_list_value(values, 'animation-fill-mode', i) {
			entry.fill_mode = raw.to_lower()
		}
		if raw := style_list_value(values, 'animation-play-state', i) {
			entry.play_state = raw.to_lower()
		}
		out << entry
	}
	return out
}

fn default_style_animation() StyleAnimation {
	return StyleAnimation{ timing: .out_cubic, iteration_count: 1, direction: 'normal', fill_mode: 'none', play_state: 'running' }
}

fn parse_animation_shorthand(value string) []StyleAnimation {
	if value.trim_space().to_lower() == 'none' { return []StyleAnimation{} }
	mut out := []StyleAnimation{}
	for entry in split_top_level_commas(value) {
		mut spec := default_style_animation()
		mut times := 0
		for tok in split_shorthand_tokens(entry) {
			l := tok.to_lower()
			if d := parse_time_seconds(tok) {
				if times == 0 { spec.duration = d } else { spec.delay = d }
				times++
			} else if t := parse_timing_token(tok) {
				spec.timing = t
			} else if f := parse_cubic_bezier(tok) {
				spec.timing = .linear
				spec.timing_fn = f
			} else if is_iteration_token(tok) {
				spec.infinite = l == 'infinite'
				spec.iteration_count = if spec.infinite {
					0.0
				} else {
					query_plain_number(tok) or { 1.0 }
				}
			} else if is_direction_token(tok) {
				spec.direction = l
			} else if is_fill_token(tok) {
				spec.fill_mode = l
			} else if is_play_state_token(tok) {
				spec.play_state = l
			} else {
				spec.name = tok
			}
		}
		if spec.name.len > 0 && spec.duration >= 0 { out << spec }
	}
	return out
}

// ---- helpers ----

fn split_top_level_commas(s string) []string {
	mut out := []string{}
	mut depth := 0
	mut quote := u8(0)
	mut start := 0
	for i in 0 .. s.len {
		ch := s[i]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
		} else if ch == `(` {
			depth++
		} else if ch == `)` {
			if depth > 0 {
				depth--
			}
		} else if ch == `,` && depth == 0 {
			out << s[start..i]
			start = i + 1
		}
	}
	if start < s.len {
		out << s[start..]
	}
	if out.len == 0 {
		out << s
	}
	return out
}

fn parse_time_seconds(tok string) ?f64 {
	t := tok.trim_space().to_lower()
	if t.ends_with('ms') {
		num := query_plain_number(t[..t.len - 2]) or { return none }
		return num / 1000.0
	}
	if t.ends_with('s') {
		return query_plain_number(t[..t.len - 1])
	}
	return none
}

fn is_time_token(tok string) bool {
	return parse_time_seconds(tok) != none
}

fn parse_timing_token(tok string) ?AnimationTransition {
	l := tok.to_lower().trim_space()
	match l {
		'linear' { return .linear }
		'ease' { return .out_cubic }
		'ease-in' { return .in_cubic }
		'ease-out' { return .out_cubic }
		'ease-in-out' { return .in_out_cubic }
		else { return none }
	}
}

fn is_timing_token(tok string) bool {
	return parse_timing_token(tok) != none
}

fn is_iteration_token(tok string) bool {
	l := tok.to_lower()
	if l == 'infinite' {
		return true
	}
	n := query_plain_number(tok) or { return false }
	return n >= 0
}

fn is_direction_token(tok string) bool {
	l := tok.to_lower()
	return l in ['normal', 'reverse', 'alternate', 'alternate-reverse']
}

fn is_play_state_token(tok string) bool {
	l := tok.to_lower()
	return l in ['running', 'paused']
}

fn is_fill_token(tok string) bool {
	l := tok.to_lower()
	return l in ['none', 'forwards', 'backwards', 'both']
}

fn parse_cubic_bezier(tok string) ?AnimationTransitionFn {
	t := tok.trim_space().to_lower()
	if !t.starts_with('cubic-bezier(') || !t.ends_with(')') {
		return none
	}
	inner := t['cubic-bezier('.len..t.len - 1]
	parts := inner.split(',')
	if parts.len != 4 {
		return none
	}
	x1 := query_plain_number(parts[0].trim_space()) or { return none }
	y1 := query_plain_number(parts[1].trim_space()) or { return none }
	x2 := query_plain_number(parts[2].trim_space()) or { return none }
	y2 := query_plain_number(parts[3].trim_space()) or { return none }
	if x1 < 0 || x1 > 1 || x2 < 0 || x2 > 1 { return none }
	return cubic_bezier_easing(x1, y1, x2, y2)
}

fn cubic_bezier_easing(x1 f64, y1 f64, x2 f64, y2 f64) AnimationTransitionFn {
	return fn [x1, y1, x2, y2] (t f64) f64 {
		if t <= 0 { return 0 }
		if t >= 1 { return 1 }
		// Keep Newton steps bracketed. Flat derivatives can otherwise send a
		// step to an endpoint and leave a large error after eight iterations.
		mut low := 0.0
		mut high := 1.0
		mut u := t
		for _ in 0 .. 40 {
			x := bezier_component(u, x1, x2) - t
			if x == 0 || high - low < 0.000000000001 { break }
			if x < 0 { low = u } else { high = u }
			dx := bezier_derivative(u, x1, x2)
			candidate := if dx > 0 { u - x / dx } else { -1.0 }
			u = if candidate > low && candidate < high {
				candidate
			} else {
				(low + high) / 2
			}
		}
		return bezier_component(u, y1, y2)
	}
}

fn bezier_component(u f64, a f64, b f64) f64 {
	// 3*(1-u)^2*u*a + 3*(1-u)*u^2*b + u^3
	mut v := 1.0 - u
	return 3.0 * v * v * u * a + 3.0 * v * u * u * b + u * u * u
}

fn bezier_derivative(u f64, a f64, b f64) f64 {
	mut v := 1.0 - u
	return 3.0 * v * v * a + 6.0 * v * u * (b - a) + 3.0 * u * u * (1.0 - b)
}

// split_shorthand_tokens splits a shorthand value into tokens, keeping
// parenthesized groups (such as cubic-bezier(...)) together.
fn split_shorthand_tokens(s string) []string {
	mut out := []string{}
	mut depth := 0
	mut quote := u8(0)
	mut start := -1
	for i in 0 .. s.len {
		ch := s[i]
		if quote != 0 {
			if ch == quote {
				quote = 0
			}
			continue
		}
		if ch == `"` || ch == `'` {
			quote = ch
			if start < 0 {
				start = i
			}
			continue
		}
		if ch == `(` {
			if start < 0 {
				start = i
			}
			depth++
			continue
		}
		if ch == `)` {
			if depth > 0 {
				depth--
			}
			continue
		}
		if (ch == ` ` || ch == `\t` || ch == `\n` || ch == `\r`) && depth == 0 {
			if start >= 0 {
				out << s[start..i]
				start = -1
			}
			continue
		}
		if start < 0 {
			start = i
		}
	}
	if start >= 0 && start < s.len {
		out << s[start..]
	}
	return out
}
