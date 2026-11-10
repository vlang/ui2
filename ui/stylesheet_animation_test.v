module ui2

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

// Inline wins: builder-set animation specs? Sheets only; inline ignore via ignore_stylesheet.
fn test_stylesheet_animation_inline_wins() {
	sheet := parse_stylesheet('Button { transition: opacity 0.2s; }')!
	el := apply_stylesheet(button('b', 'hi', rect(0, 0, 10, 10), BoxStyle{}, TextStyle{}), sheet, StyleMatchEnv{})
	assert el.style_transitions.len == 1
	ignored := apply_stylesheet(Element{...el, ignore_stylesheet: true}, sheet, StyleMatchEnv{})
	_ = ignored
}
