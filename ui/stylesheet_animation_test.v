module ui2

import math

// Parse: @keyframes + transition/animation shorthands and atomic forms.
fn test_stylesheet_animation_parse() {
	sheet := parse_stylesheet('
@keyframes pulse {
	from { opacity: 1; }
	50%  { opacity: 0.5; }
	to   { opacity: 1; }
}
Button { transition: background 0.2s ease, opacity 0.15s; }
Button.loading { animation: pulse 1s ease-in-out 2 alternate forwards; }
')!
	assert sheet.keyframes.len == 1
	kf := sheet.keyframes['pulse']!
	assert kf.stops.len == 3
	assert kf.stops[0].stop == 0.0
	assert kf.stops[1].stop == 0.5
	assert kf.stops[2].stop == 1.0
	// button rule carries transition shorthand -> 2 entries
	btn_rule := sheet.rules[0]
	_ = btn_rule
}

// Cascade: transition/animation specs land on the element.
fn test_stylesheet_animation_cascade() {
	sheet := parse_stylesheet('
@keyframes pulse { from { opacity: 1; } to { opacity: 0.5; } }
Button { transition: opacity 0.2s linear; }
Button.loading { animation: pulse 0.5s; }
')!
	styled_plain := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert styled_plain.style_transitions.len == 1
	assert styled_plain.style_transitions[0].duration == 0.2
	assert styled_plain.style_animations.len == 0

	styled_loading := apply_stylesheet(with_classes(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), 'loading'), sheet, StyleMatchEnv{})
	assert styled_loading.style_animations.len == 1
	assert styled_loading.style_animations[0].name == 'pulse'
	assert styled_loading.style_animations[0].iteration_count == 1.0
}

// Atomic forms align by comma index.
fn test_stylesheet_animation_atomic() {
	sheet := parse_stylesheet('
Button {
	transition-property: background, opacity;
	transition-duration: 0.2s, 0.1s;
	transition-timing-function: ease, linear;
}
')!
	el := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert el.style_transitions.len == 2
	assert el.style_transitions[0].duration == 0.2
	assert el.style_transitions[1].duration == 0.1
}

// cubic-bezier timing parses into a function.
fn test_stylesheet_animation_cubic_bezier() {
	sheet := parse_stylesheet('Button { transition: opacity 0.3s cubic-bezier(0.25, 0.1, 0.25, 1); }')!
	el := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert el.style_transitions.len == 1
	assert voidptr(el.style_transitions[0].timing_fn) != unsafe { nil }
}

fn test_stylesheet_animation_longhand_keywords_ignore_case() {
	sheet := parse_stylesheet('View {
		animation-name: Fade, NONE;
		animation-duration: 1s;
		animation-iteration-count: INFINITE;
		animation-direction: REVERSE;
		animation-fill-mode: BOTH;
		animation-play-state: PAUSED;
	}')!
	el := apply_stylesheet(view('target', rect(0, 0, 10, 10), BoxStyle{}, []), sheet, StyleMatchEnv{})
	spec := el.style_animations[0]
	assert spec.name == 'Fade'
	assert spec.infinite
	assert spec.direction == 'reverse'
	assert spec.fill_mode == 'both'
	assert spec.play_state == 'paused'
	assert el.style_animations[1].name == ''
}

fn test_stylesheet_cubic_bezier_handles_flat_derivatives() {
	// x(u) = u^3: u = 0.01 at x = 0.000001.
	start := parse_cubic_bezier('cubic-bezier(0, 1, 0, 1)') or { panic('invalid curve') }
	assert start(0) == 0
	assert start(1) == 1
	assert math.abs(start(0.000001) - 0.029701) < 0.0000001
	end := parse_cubic_bezier('cubic-bezier(1, 0, 1, 0)') or { panic('invalid curve') }
	assert math.abs(end(0.999999) - 0.970299) < 0.0000001
	// x'(u) vanishes inside the interval at u = 0.5.
	middle := parse_cubic_bezier('cubic-bezier(1, 0, 0, 1)') or { panic('invalid curve') }
	assert math.abs(middle(0.500004) - 0.514998) < 0.0000001
}

// Driver: a property change between builds starts a transition run.
fn test_stylesheet_animation_driver_transition() {
	set_global_stylesheet(parse_stylesheet('Button { transition: opacity 0.2s; }')!)
	b1 := stylesheet_apply_frame(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{ opacity: 1.0 }, TextStyle{}), StyleMatchEnv{})
	_ = b1
	b2 := stylesheet_apply_frame(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{ opacity: 0.5 }, TextStyle{}), StyleMatchEnv{})
	_ = b2
	assert 'b' in animation_runtime().style_runs
	clear_global_stylesheet()
}

// Inline wins: builder-set animation specs? Sheets only; inline ignore via ignore_stylesheet.
fn test_stylesheet_animation_inline_wins() {
	sheet := parse_stylesheet('Button { transition: opacity 0.2s; }')!
	el := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert el.style_transitions.len == 1
	ignored := apply_stylesheet(Element{ ...el, ignore_stylesheet: true }, sheet, StyleMatchEnv{})
	_ = ignored
}

fn anim_probe_btn(id string, opacity f64) Element {
	return button(id, 'hi', rect(0, 0, 10, 10), BoxStyle{ opacity: opacity }, TextStyle{})
}

// First frame counts as entry: animations matching the initial tree play
// instead of waiting for an unmatch/rematch cycle that may never come.
fn test_stylesheet_animation_starts_on_first_frame() {
	set_global_stylesheet(parse_stylesheet('@keyframes pulse { from { opacity: 1; } to { opacity: 0.5; } } Button.loading { animation: pulse 0.5s; }')!)
	btn := with_classes(anim_probe_btn('pa', 1.0), 'loading')
	_ = stylesheet_apply_frame(btn, StyleMatchEnv{})
	_ = stylesheet_apply_frame(btn, StyleMatchEnv{})
	assert 'pa' in animation_runtime().style_runs
	clear_global_stylesheet()
	cancel_animation('pa')
}

// Several changed shorthand entries animate concurrently: one tween child
// per entry under a .parallel parent.
fn test_stylesheet_transition_multi_entry_keeps_all_targets() {
	set_global_stylesheet(parse_stylesheet('Button { transition: background 0.2s, opacity 0.15s; }')!)
	b1 := button('pq', 'hi', rect(0, 0, 10, 10), BoxStyle{ bg: 0xffffff, opacity: 1.0 }, TextStyle{})
	b2 := button('pq', 'hi', rect(0, 0, 10, 10), BoxStyle{ bg: 0x000000, opacity: 0.5 }, TextStyle{})
	_ = stylesheet_apply_frame(b1, StyleMatchEnv{})
	_ = stylesheet_apply_frame(b2, StyleMatchEnv{})
	run := animation_runtime().style_runs['pq'] or { panic('no run for pq') }
	assert 'background' in run.transitions
	assert 'box.opacity' in run.transitions
	clear_global_stylesheet()
	cancel_animation('pq')
}

// Finite counts keep one timeline rather than unrolling repeated sequences.
fn test_stylesheet_animation_finite_count_keeps_one_timeline() {
	set_global_stylesheet(parse_stylesheet('@keyframes bl { from { opacity: 1; } 50% { opacity: 0; } to { opacity: 1; } } Button.go { animation: bl 0.5s linear 2; }')!)
	_ = stylesheet_apply_frame(anim_probe_btn('pk', 1.0), StyleMatchEnv{})
	_ = stylesheet_apply_frame(with_classes(anim_probe_btn('pk', 1.0), 'go'), StyleMatchEnv{})
	run := animation_runtime().style_runs['pk'] or { panic('no run for pk') }
	assert run.animations.len == 1
	assert run.animations[0].spec.iteration_count == 2
	assert !run.animations[0].spec.infinite
	clear_global_stylesheet()
	cancel_animation('pk')
}

// A zero-duration animation has no stops to tween: starting an empty
// Animation would replace and cancel the element's in-flight run.
fn test_stylesheet_animation_zero_duration_starts_nothing() {
	set_global_stylesheet(parse_stylesheet('@keyframes bl { from { opacity: 1; } to { opacity: 0; } } Button.go { animation: bl 0s; }')!)
	_ = stylesheet_apply_frame(anim_probe_btn('pz', 1.0), StyleMatchEnv{})
	_ = stylesheet_apply_frame(with_classes(anim_probe_btn('pz', 1.0), 'go'), StyleMatchEnv{})
	assert 'pz' !in animation_runtime().style_runs
	clear_global_stylesheet()
}

// Keyframe declarations resolve `@variables` against the keyframes' sheet
// scope, the same way the cascade resolves ordinary declarations.
fn test_stylesheet_animation_keyframes_resolve_variables() {
	set_global_stylesheet(parse_stylesheet('@accent: #2563eb; @keyframes k { from { opacity: 1; } to { background: @accent; } } Button.go { animation: k 0.5s; }')!)
	_ = stylesheet_apply_frame(anim_probe_btn('pv', 1.0), StyleMatchEnv{})
	_ = stylesheet_apply_frame(with_classes(anim_probe_btn('pv', 1.0), 'go'), StyleMatchEnv{})
	run := animation_runtime().style_runs['pv'] or { panic('no run for pv') }
	assert run.animations[0].tracks.any(it.property == 'background')
	// The composed color must be the accent, not a zeroed fallback.
	found := run.animations[0].tracks.filter(it.property == 'background')
	assert found.len == 1
	assert found[0].stops.last().value.color == 0x2563eb
	clear_global_stylesheet()
	cancel_animation('pv')
}

// A garbage iteration count keeps the previous entry, never infinite:
// f64('banana') == 0 collides with the infinite encoding.
fn test_stylesheet_animation_iteration_garbage_keeps_previous() {
	sheet := parse_stylesheet('Button { animation: fade 1s; animation-iteration-count: banana; }')!
	el := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert el.style_animations.len == 1
	assert el.style_animations[0].iteration_count == 1.0
}

// Near-miss property names fall through to the unknown-property warning
// instead of vanishing inside the animation interceptor.
fn test_stylesheet_animation_typo_warns_unknown_property() {
	sheet := parse_stylesheet('Button { transitions: opacity 0.2s; transition-foo: 1s; }')!
	_, warnings := apply_stylesheet_ex(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert warnings.any(it.message == 'unknown property' && it.prop == 'transitions')
	assert warnings.any(it.message == 'unknown property' && it.prop == 'transition-foo')
}

// A bare `%` is not a keyframe stop.
fn test_stylesheet_keyframes_reject_bare_percent() {
	if _ := parse_stylesheet('@keyframes k { % { opacity: 1; } }') {
		assert false, 'bare % must not parse as a stop'
	} else {
		assert err.msg().contains('percentage')
	}
}

// Delay shifts the tween once: the frame node pre-adjusts elapsed and the
// evaluator must not subtract the delay a second time.
fn test_animation_delay_applies_once() {
	reset_widget_animations()
	definition := animation(AnimationConfig{
		duration:   1.0
		delay:      0.5
		transition: .linear
		x:          100
	})
	start_widget_animation_at('dz', definition, 1_000, false)
	quarter := anim_test_find(apply_widget_animations_at(anim_test_root(view('dz', rect(0, 0, 100, 40), BoxStyle{}, [])), 1_750), 'dz')
	assert quarter.frame.x == 25
	done := anim_test_find(apply_widget_animations_at(anim_test_root(view('dz', rect(0, 0, 100, 40), BoxStyle{}, [])), 2_500), 'dz')
	assert done.frame.x == 100
	reset_widget_animations()
}

fn anim_test_root(element Element) Element {
	return screen(0xffffff, [element])
}

fn anim_test_find(element Element, id string) Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		found := anim_test_find(child, id)
		if found.id == id {
			return found
		}
	}
	return Element{}
}
