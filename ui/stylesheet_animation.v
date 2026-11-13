module ui2

// apply_style_animation_decl folds one transition/animation declaration into
// el's style_transitions / style_animations lists. Shorthands reset the
// whole list; atomic properties update entries positionally (creating them
// with defaults as needed), matching CSS list alignment.

fn apply_style_animation_decl(el Element, prop string, value string) Element {
	mut out := el
	lower := prop.to_lower()
	if lower == 'transition' {
		out.style_transitions = parse_transition_shorthand(value)
		return out
	}
	if lower == 'animation' {
		out.style_animations = parse_animation_shorthand(value, el.id)
		return out
	}
	if lower.starts_with('transition-') {
		out.style_transitions = apply_transition_atomic(out.style_transitions, lower, value)
		return out
	}
	if lower.starts_with('animation-') {
		out.style_animations = apply_animation_atomic(out.style_animations, lower, value)
		return out
	}
	return out
}

// ---- transitions ----

fn parse_transition_shorthand(value string) []StyleTransition {
	mut out := []StyleTransition{}
	for entry in split_top_level_commas(value) {
		tokens := split_shorthand_tokens(entry)
		if tokens.len == 0 {
			continue
		}
		mut props := []string{}
		mut duration := 0.2
		mut timing := AnimationTransition.out_cubic
		mut timing_fn := AnimationTransitionFn(unsafe { nil })
		mut delay := 0.0
		mut seen_duration := false
		for tok in tokens {
			l := tok.to_lower()
			if l == 'all' {
				props << 'all'
			} else if d := parse_time_seconds(tok) {
				if !seen_duration {
					duration = d
					seen_duration = true
				} else {
					delay = d
				}
			} else if t := parse_timing_token(tok) {
				timing = t
				timing_fn = unsafe { nil }
			} else if f := parse_cubic_bezier(tok) {
				timing = .linear
				timing_fn = f
			} else if is_transition_property_name(tok) {
				props << tok
			}
		}
		if props.len == 0 {
			props = ['all']
		}
		out << StyleTransition{
			properties: props
			duration:   duration
			timing:     timing
			timing_fn:  timing_fn
			delay:      delay
		}
	}
	return out
}

fn apply_transition_atomic(list []StyleTransition, prop string, value string) []StyleTransition {
	vals := split_top_level_commas(value)
	n := if vals.len > list.len { vals.len } else { list.len }
	mut out := []StyleTransition{len: n}
	for i in 0 .. n {
		base := if i < list.len {
			list[i]
		} else {
			StyleTransition{ properties: ['all'], duration: 0.2, timing: .out_cubic, delay: 0.0 }
		}
		out[i] = base
	}
	for i, v in vals {
		trimmed := v.trim_space()
		match prop {
			'transition-property' {
				mut props := []string{}
				for p in trimmed.split(',') {
					pp := p.trim_space()
					if pp.len > 0 {
						props << pp
					}
				}
				if props.len == 0 {
					props = ['all']
				}
				out[i].properties = props
			}
			'transition-duration' {
				if d := parse_time_seconds(trimmed) {
					out[i].duration = d
				}
			}
			'transition-timing-function' {
				if t := parse_timing_token(trimmed) {
					out[i].timing = t
					out[i].timing_fn = unsafe { nil }
				} else if f := parse_cubic_bezier(trimmed) {
					out[i].timing = .linear
					out[i].timing_fn = f
				}
			}
			'transition-delay' {
				if d := parse_time_seconds(trimmed) {
					out[i].delay = d
				}
			}
			else {}
		}
	}
	return out
}

fn is_transition_property_name(tok string) bool {
	if parse_time_seconds(tok) != none {
		return false
	}
	if parse_timing_token(tok) != none {
		return false
	}
	l := tok.to_lower()
	if l == 'all' || l == 'none' {
		return false
	}
	return true
}

// ---- animations ----

fn parse_animation_shorthand(value string, _ string) []StyleAnimation {
	mut out := []StyleAnimation{}
	for entry in split_top_level_commas(value) {
		tokens := split_shorthand_tokens(entry)
		if tokens.len == 0 {
			continue
		}
		mut name := ''
		mut duration := 0.0
		mut timing := AnimationTransition.out_cubic
		mut timing_fn := AnimationTransitionFn(unsafe { nil })
		mut delay := 0.0
		mut iters := 1.0
		mut infinite := false
		mut direction := 'normal'
		mut fill := 'none'
		mut play := 'running'
		mut seen_duration := false
		for tok in tokens {
			l := tok.to_lower()
			if name == '' && !is_time_token(tok) && !is_timing_token(tok) && !is_iteration_token(tok)
				&& !is_direction_token(tok) && !is_fill_token(tok) && !is_play_state_token(tok)
				&& parse_cubic_bezier(tok) == none {
				name = tok
				continue
			}
			if d := parse_time_seconds(tok) {
				if !seen_duration {
					duration = d
					seen_duration = true
				} else {
					delay = d
				}
				continue
			}
			if t := parse_timing_token(tok) {
				// only assign if token is a timing keyword (parse_timing_token returns none otherwise)
				timing = t
				timing_fn = unsafe { nil }
				continue
			} else if f := parse_cubic_bezier(tok) {
				timing = .linear
				timing_fn = f
				continue
			}
			if is_iteration_token(tok) {
				if l == 'infinite' {
					infinite = true
					iters = 0
				} else {
					iters = tok.f64()
				}
				continue
			}
			if is_direction_token(tok) {
				direction = l
				continue
			}
			if is_fill_token(tok) {
				fill = l
				continue
			}
			if is_play_state_token(tok) {
				play = l
				continue
			}
		}
		if name == '' {
			continue
		}
		out << StyleAnimation{
			name:            name
			duration:        if duration <= 0 { 0.0 } else { duration }
			timing:          timing
			timing_fn:       timing_fn
			delay:           delay
			iteration_count: if infinite { 0 } else { iters }
			direction:       direction
			fill_mode:       fill
			play_state:      play
		}
	}
	return out
}

fn apply_animation_atomic(list []StyleAnimation, prop string, value string) []StyleAnimation {
	vals := split_top_level_commas(value)
	n := if vals.len > list.len { vals.len } else { list.len }
	mut out := []StyleAnimation{len: n}
	for i in 0 .. n {
		base := if i < list.len {
			list[i]
		} else {
			StyleAnimation{ name: '', duration: 0.0, timing: .out_cubic, delay: 0.0, iteration_count: 1.0, direction: 'normal', fill_mode: 'none', play_state: 'running' }
		}
		out[i] = base
	}
	for i, v in vals {
		trimmed := v.trim_space()
		match prop {
			'animation-name' { out[i].name = trimmed }
			'animation-duration' {
				if d := parse_time_seconds(trimmed) { out[i].duration = d }
			}
			'animation-timing-function' {
				if t := parse_timing_token(trimmed) {
					out[i].timing = t
					out[i].timing_fn = unsafe { nil }
				} else if f := parse_cubic_bezier(trimmed) {
					out[i].timing = .linear
					out[i].timing_fn = f
				}
			}
			'animation-delay' {
				if d := parse_time_seconds(trimmed) { out[i].delay = d }
			}
			'animation-iteration-count' {
				if trimmed.to_lower() == 'infinite' {
					out[i].iteration_count = 0
				} else {
					out[i].iteration_count = trimmed.f64()
				}
			}
			'animation-direction' { out[i].direction = trimmed.to_lower() }
			'animation-fill-mode' { out[i].fill_mode = trimmed.to_lower() }
			'animation-play-state' { out[i].play_state = trimmed.to_lower() }
			else {}
		}
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
		num := t[..t.len - 2].f64()
		return num / 1000.0
	}
	if t.ends_with('s') {
		return t[..t.len - 1].f64()
	}
	// bare number treated as seconds
	n := t.f64()
	if t == n.str() {
		return n
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
	if tok.len == 0 {
		return false
	}
	first := tok[0]
	if !(first >= `0` && first <= `9`) {
		return false
	}
	// must be numeric
	n := tok.f64()
	return n > 0 || tok == '0'
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
	x1 := parts[0].trim_space().f64()
	y1 := parts[1].trim_space().f64()
	x2 := parts[2].trim_space().f64()
	y2 := parts[3].trim_space().f64()
	return cubic_bezier_easing(x1, y1, x2, y2)
}

fn cubic_bezier_easing(x1 f64, y1 f64, x2 f64, y2 f64) AnimationTransitionFn {
	return fn [x1, y1, x2, y2](t f64) f64 {
		// Newton-Raphson to find u with bezier_x(u) = t
		mut u := t
		for _ in 0 .. 8 {
			x := bezier_component(u, x1, x2) - t
			dx := bezier_derivative(u, x1, x2)
			if dx == 0 {
				break
			}
			u -= x / dx
			if u < 0 {
				u = 0
			}
			if u > 1 {
				u = 1
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
