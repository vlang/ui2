module ui2

import math

fn controls_assert_inside(el Element) {
	component_validate_frame(el.frame) or { panic(err) }
	for child in el.children {
		assert child.frame.x >= -1e-9 && child.frame.y >= -1e-9
		assert child.frame.x + child.frame.width <= el.frame.width + 1e-9
		assert child.frame.y + child.frame.height <= el.frame.height + 1e-9
		controls_assert_inside(child)
	}
}

fn controls_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := controls_find(child, id) {
			return found
		}
	}
	return none
}

fn controls_collect(el Element, keep fn (Element) bool) []Element {
	mut found := []Element{}
	if keep(el) {
		found << el
	}
	for child in el.children {
		found << controls_collect(child, keep)
	}
	return found
}

fn controls_texts(el Element) []string {
	return controls_collect(el, fn (e Element) bool {
		return e.kind == .label
	}).map(it.text)
}

fn controls_near(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

// ── Checkbox ────────────────────────────────────────────────────────

fn test_checkbox_draws_box_mark_label_and_description() {
	config := StyledCheckboxConfig{
		id:          'terms'
		frame:       rect(10, 20, 260, 60)
		label:       'Accept the terms'
		description: 'You can withdraw at any time.'
		checked:     true
	}
	el := styled_checkbox(config)!
	controls_assert_inside(el)
	assert el.button_behavior
	assert el.action_id == 'terms'
	assert el.accessibility_role == 'checkbox'
	assert el.accessibility_label == 'Accept the terms'
	assert el.accessibility_value == 'checked'
	assert controls_texts(el) == ['Accept the terms', 'You can withdraw at any time.']
	mark := controls_find(el, component_part_id('terms', 'mark')) or { panic('no mark') }
	assert mark.path.len == 3
	assert mark.shape_style.stroke or { 0 } == component_theme(false).primary_foreground

	off := styled_checkbox(StyledCheckboxConfig{ ...config, checked: false })!
	assert controls_find(off, component_part_id('terms', 'mark')) == none
	assert off.accessibility_value == 'unchecked'

	mixed := styled_checkbox(StyledCheckboxConfig{ ...config, checked: false, indeterminate: true })!
	assert mixed.accessibility_value == 'mixed'
	dash := controls_find(mixed, component_part_id('terms', 'mark')) or { panic('no dash') }
	assert dash.path.len == 2
	assert dash.path[0].y == dash.path[1].y
}

fn test_checkbox_sizes_focus_ring_tooltip_and_disabled() {
	mut sides := []f64{}
	for size in [ComponentSize.small, .medium, .large] {
		config := StyledCheckboxConfig{
			id:    'cb'
			frame: rect(0, 0, 200, 32)
			label: 'Size'
			size:  size
		}
		el := styled_checkbox(config)!
		controls_assert_inside(el)
		// The box is the first view: its frame is the box side.
		sides << el.children[0].frame.width
		assert styled_checkbox_width(config) > checkbox_metrics(size).box + 2 * controls_ring
	}
	assert sides == [14.0, 16, 18]

	plain := styled_checkbox(id: 'cb', frame: rect(0, 0, 200, 32), label: 'Focus')!
	focused := styled_checkbox(
		id:      'cb'
		frame:   rect(0, 0, 200, 32)
		label:   'Focus'
		focused: true
		tooltip: 'Help'
	)!
	assert focused.children.len == plain.children.len + 1
	ring := focused.children[0]
	assert ring.frame.width == 16 + 2 * controls_ring
	assert ring.frame.x >= 0
	assert focused.tooltip == 'Help'

	disabled := styled_checkbox(
		id:      'cb'
		frame:   rect(0, 0, 200, 32)
		label:   'Off'
		focused: true
		enabled: false
	)!
	assert !disabled.enabled
	// A disabled checkbox draws no focus ring.
	assert disabled.children.len == plain.children.len
	theme := component_theme(false)
	labels := controls_collect(disabled, fn (e Element) bool {
		return e.kind == .label
	})
	assert labels[0].text_style.color == choice_disabled_text(theme)
}

fn test_checkbox_wraps_long_labels_and_centers_short_rows() {
	long := StyledCheckboxConfig{
		id:          'long'
		frame:       rect(0, 0, 120, 200)
		label:       'Automatically transcribe every downloaded episode'
		description: 'Transcripts are stored next to the audio files and kept in sync.'
	}
	row := checkbox_row(long, 120)
	assert row.label_lines > 1
	assert row.detail_lines > 1
	assert row.detail.y >= row.label.y + row.label.height
	assert styled_checkbox_height(long) == row.height
	el := styled_checkbox(long)!
	controls_assert_inside(el)
	// A short row is centered in a taller frame.
	short := styled_checkbox(id: 's', frame: rect(0, 0, 200, 40), label: 'Short')!
	box := short.children[0]
	assert controls_near(box.frame.y + box.frame.height / 2, 20)
}

fn test_checkbox_decoder_and_keys() {
	config := StyledCheckboxConfig{
		id:    'remember'
		frame: rect(0, 0, 200, 24)
		label: 'Remember me'
	}
	assert styled_checkbox_checked_from_action(config, 'remember')? == true
	assert styled_checkbox_checked_from_action(StyledCheckboxConfig{ ...config, checked: true },
		'remember')? == false
	assert styled_checkbox_checked_from_action(StyledCheckboxConfig{
		...config
		checked:       false
		indeterminate: true
	}, 'remember')? == true
	assert styled_checkbox_checked_from_action(config, 'other') == none
	assert styled_checkbox_checked_from_action(StyledCheckboxConfig{ ...config, enabled: false },
		'remember') == none
	custom := StyledCheckboxConfig{
		...config
		action_id: 'remember-changed'
	}
	assert styled_checkbox_checked_from_action(custom, 'remember') == none
	assert styled_checkbox_checked_from_action(custom, 'remember-changed')? == true
	assert styled_checkbox_checked_after_key(config, KeyEvent{ code: .space })? == true
	assert styled_checkbox_checked_after_key(config, KeyEvent{ code: .enter })? == true
	assert styled_checkbox_checked_after_key(config, KeyEvent{ code: .space, cmd: true }) == none
	assert styled_checkbox_checked_after_key(config, KeyEvent{ code: .a }) == none
	assert styled_checkbox_checked_after_key(StyledCheckboxConfig{ ...config, enabled: false },
		KeyEvent{
			code: .space
		}) == none
	if _ := styled_checkbox(StyledCheckboxConfig{ ...config, id: ' ' }) {
		assert false
	}
	if _ := styled_checkbox(StyledCheckboxConfig{ ...config, frame: rect(0, 0, -1, 4) }) {
		assert false
	}
}

// ── Checkbox group ──────────────────────────────────────────────────

fn controls_group(selected []string) CheckboxGroupConfig {
	return CheckboxGroupConfig{
		id:         'notify'
		frame:      rect(0, 0, 300, 220)
		select_all: 'All notifications'
		selected:   selected
		options:    [
			CheckboxOption{
				value:       'mail'
				label:       'Email'
				description: 'Daily digest'
			},
			CheckboxOption{
				value: 'push'
				label: 'Push'
			},
			CheckboxOption{
				value:   'sms'
				label:   'Text message'
				enabled: false
			},
		]
	}
}

fn test_checkbox_group_builds_options_and_select_all_state() {
	el := checkbox_group(controls_group(['mail']))!
	controls_assert_inside(el)
	assert el.accessibility_role == 'group'
	assert el.accessibility_value == 'Email'
	assert el.children.len == 4
	all := el.children[0]
	assert all.id == checkbox_group_select_all_action_id('notify')
	assert all.accessibility_value == 'mixed'
	// Options are indented under select-all in a vertical group.
	assert el.children[1].frame.x > 0
	assert el.children[1].id == checkbox_group_action_id('notify', 'mail')
	assert el.children[1].accessibility_value == 'checked'
	assert !el.children[3].enabled

	full := checkbox_group(controls_group(['mail', 'push']))!
	assert full.children[0].accessibility_value == 'checked'
	none_selected := checkbox_group(controls_group([]))!
	assert none_selected.children[0].accessibility_value == 'unchecked'
	// A disabled option that is selected alone does not make select-all mixed
	// toward checking it, but it is still reported as partly selected.
	only_disabled := checkbox_group(controls_group(['sms']))!
	assert only_disabled.children[0].accessibility_value == 'mixed'

	if _ := checkbox_group(CheckboxGroupConfig{
		...controls_group([])
		options: [CheckboxOption{
			label: 'A'
		}, CheckboxOption{
			label: 'A'
		}]
	})
	{
		assert false
	}
}

fn test_checkbox_group_decodes_toggles_and_select_all() {
	config := controls_group(['mail'])
	assert checkbox_group_selection_from_action(config, checkbox_group_action_id('notify',
		'push'))? == ['mail', 'push']
	assert checkbox_group_selection_from_action(config, checkbox_group_action_id('notify',
		'mail'))? == []string{}
	// Disabled options and foreign or forged actions change nothing.
	assert checkbox_group_selection_from_action(config, checkbox_group_action_id('notify',
		'sms')) == none
	assert checkbox_group_selection_from_action(config, checkbox_group_action_id('notify',
		'fax')) == none
	assert checkbox_group_selection_from_action(config, 'notify') == none
	assert checkbox_group_selection_from_action(CheckboxGroupConfig{ ...config, enabled: false },
		checkbox_group_action_id('notify', 'push')) == none
	// Select-all checks every enabled option, then clears them, and leaves a
	// disabled option's state alone.
	all := checkbox_group_select_all_action_id('notify')
	assert checkbox_group_selection_from_action(config, all)? == ['mail', 'push']
	with_sms := controls_group(['mail', 'push', 'sms'])
	assert checkbox_group_selection_from_action(with_sms, all)? == ['sms']
	assert checkbox_group_selection_from_action(CheckboxGroupConfig{ ...config, select_all: '' },
		all) == none
	// Unknown selected values are dropped; the result follows option order.
	assert checkbox_group_selection_from_action(controls_group(['push', 'gone']), checkbox_group_action_id('notify',
		'mail'))? == ['mail', 'push']
}

fn test_checkbox_group_horizontal_wraps_and_height_fits() {
	config := CheckboxGroupConfig{
		id:          'days'
		frame:       rect(0, 0, 200, 80)
		orientation: .horizontal
		options:     ['Monday', 'Tuesday', 'Wednesday', 'Thursday'].map(CheckboxOption{
			label: it
		})
	}
	frames := checkbox_group_frames(config)
	assert frames.len == 4
	assert frames[0].y == 0
	assert frames.any(it.y > 0)
	for frame in frames {
		assert frame.x + frame.width <= 200 + 1e-9
	}
	height := checkbox_group_height(CheckboxGroupConfig{ ...config, frame: rect(0, 0, 200, 0) })
	assert height > 0
	el := checkbox_group(CheckboxGroupConfig{ ...config, frame: rect(0, 0, 200, height) })!
	controls_assert_inside(el)
}

// ── Switch ──────────────────────────────────────────────────────────

fn test_switch_sizes_match_gpui_kit() {
	for size, expected in {
		ComponentSize.small: [28.0, 16, 12]
		.medium:             [36.0, 20, 16]
		.large:              [44.0, 24, 20]
	} {
		sm := switch_metrics(size)
		assert [sm.width, sm.height, sm.thumb] == expected
		assert styled_switch_thumb_x(size, false) == 2
		assert styled_switch_thumb_x(size, true) == sm.width - sm.thumb - 2
	}
}

fn test_switch_builds_track_thumb_label_and_description() {
	config := StyledSwitchConfig{
		id:            'wifi'
		frame:         rect(0, 0, 280, 48)
		label:         'Wi-Fi'
		description:   'Join known networks automatically'
		checked:       true
		reduce_motion: true
	}
	el := styled_switch(config)!
	controls_assert_inside(el)
	assert el.button_behavior
	assert el.accessibility_role == 'switch'
	assert el.accessibility_label == 'Wi-Fi'
	assert el.accessibility_value == 'on'
	assert controls_texts(el) == ['Wi-Fi', 'Join known networks automatically']
	thumb := controls_find(el, component_part_id('wifi', 'thumb')) or { panic('no thumb') }
	assert thumb.frame.x == styled_switch_thumb_x(.medium, true)
	assert thumb.box.shadow.opacity > 0
	assert thumb.box.shadow.y == 0
	theme := component_theme(false)
	track := el.children[0]
	assert track.box.bg == theme.primary
	assert track.frame.x == controls_ring
	assert thumb.box.bg == theme.primary_foreground

	left := styled_switch(StyledSwitchConfig{ ...config, label_side: .left })!
	left_track := left.children[0]
	assert controls_near(left_track.frame.x + left_track.frame.width, 280 - controls_ring)
	labels := controls_collect(left, fn (e Element) bool {
		return e.kind == .label
	})
	assert labels[0].frame.x == 0
	assert labels[0].frame.x + labels[0].frame.width <= left_track.frame.x

	off := styled_switch(StyledSwitchConfig{ ...config, checked: false })!
	assert off.accessibility_value == 'off'
	assert off.children[0].box.bg == theme.border
	assert styled_switch_width(config) > 36 + 2 * controls_ring
}

fn test_switch_color_disabled_loading_and_focus() {
	theme := component_theme(false)
	base := StyledSwitchConfig{
		id:            'sw'
		frame:         rect(0, 0, 200, 28)
		label:         'Switch'
		checked:       true
		reduce_motion: true
	}
	green := styled_switch(StyledSwitchConfig{ ...base, color: u32(0x16a34a) })!
	assert green.children[0].box.bg == 0x16a34a
	yellow := styled_switch(StyledSwitchConfig{ ...base, color: theme.warning })!
	// A light accent gets the dark end of the theme on it.
	assert controls_find(yellow, component_part_id('sw', 'thumb'))?.box.bg == theme.foreground

	disabled := styled_switch(StyledSwitchConfig{ ...base, enabled: false })!
	assert !disabled.enabled
	assert disabled.children[0].box.bg == choice_mix(theme.primary, theme.background, 0.5)

	loading := styled_switch(StyledSwitchConfig{ ...base, loading: true })!
	assert !loading.enabled
	assert loading.accessibility_value == 'on, busy'
	thumb := controls_find(loading, component_part_id('sw', 'thumb')) or { panic('no thumb') }
	assert thumb.children.len == 1
	assert styled_switch_checked_from_action(StyledSwitchConfig{ ...base, loading: true },
		'sw') == none

	focused := styled_switch(StyledSwitchConfig{ ...base, focused: true })!
	plain := styled_switch(base)!
	assert focused.children.len == plain.children.len + 1
	assert focused.children[0].frame.width == 36 + 2 * controls_ring
	tooltip := styled_switch(StyledSwitchConfig{ ...base, tooltip: 'Airplane mode' })!
	assert tooltip.tooltip == 'Airplane mode'
}

fn test_switch_decoder_keys_and_validation() {
	config := StyledSwitchConfig{
		id:    'push'
		frame: rect(0, 0, 200, 24)
	}
	assert styled_switch_checked_from_action(config, 'push')? == true
	assert styled_switch_checked_from_action(StyledSwitchConfig{ ...config, checked: true },
		'push')? == false
	assert styled_switch_checked_from_action(config, 'pull') == none
	assert styled_switch_checked_from_action(StyledSwitchConfig{ ...config, enabled: false },
		'push') == none
	assert styled_switch_checked_after_key(config, KeyEvent{ code: .space })? == true
	assert styled_switch_checked_after_key(config, KeyEvent{ code: .kp_enter })? == true
	assert styled_switch_checked_after_key(config, KeyEvent{ code: .space, ctrl: true }) == none
	if _ := styled_switch(StyledSwitchConfig{ ...config, id: '' }) {
		assert false
	}
}

fn test_switch_thumb_slides_between_builds() {
	id := 'slide-test'
	thumb_id := component_part_id(id, 'thumb')
	clear_animation(thumb_id)
	config := StyledSwitchConfig{
		id:    id
		frame: rect(0, 0, 60, 24)
	}
	styled_switch(config)!
	// The first build records where the thumb is without moving it.
	assert switch_x_target(thumb_id)? == 2
	styled_switch(StyledSwitchConfig{ ...config, checked: true })!
	assert switch_x_target(thumb_id)? == styled_switch_thumb_x(.medium, true)
	assert animation_info(thumb_id).duration == switch_slide_seconds
	styled_switch(StyledSwitchConfig{ ...config, checked: true, reduce_motion: true })!
	assert switch_x_target(thumb_id) == none
}

// ── Slider values ───────────────────────────────────────────────────

fn test_slider_scales_map_values_both_ways() {
	assert slider_scale_fraction(25, 0, 100, .linear) == 0.25
	assert slider_scale_value(0.25, 0, 100, .linear) == 25
	assert slider_scale_fraction(-5, 0, 100, .linear) == 0
	assert slider_scale_fraction(5, 5, 5, .linear) == 0
	// GPUI Kit's documented logarithmic values for 1...1000.
	assert math.abs(slider_scale_value(0.25, 1, 1000, .logarithmic) - 5.62) < 0.01
	assert math.abs(slider_scale_value(0.5, 1, 1000, .logarithmic) - 31.62) < 0.01
	assert math.abs(slider_scale_value(0.75, 1, 1000, .logarithmic) - 177.83) < 0.01
	assert slider_scale_value(1, 1, 1000, .logarithmic) == 1000
	assert slider_scale_value(0, 1, 1000, .logarithmic) == 1
	assert math.abs(slider_scale_fraction(100, 1, 1000, .logarithmic) - 2.0 / 3) < 1e-9
}

fn test_slider_snaps_without_binary_noise_and_formats() {
	assert slider_snap(0.30000000000000004, 0, 1, 0.1) == 0.3
	assert slider_snap(0.36, 0, 1, 0.1) == 0.4
	assert slider_snap(97, 0, 95, 10) == 95
	assert slider_snap(3.2, 0.5, 10, 1) == 3.5
	assert slider_snap(42.4, 0, 100, 0) == 42.4
	assert slider_decimals(0.25) == 2
	assert slider_decimals(5) == 0
	assert slider_format_number(3.14159, 2) == '3.14'
	assert slider_format_number(-0.001, 2) == '0.00'
	assert slider_format_number(-2.5, 1) == '-2.5'
	assert slider_format_number(7, 0) == '7'
	config := StyledSliderConfig{
		id:           'temp'
		min:          -10
		max:          40
		step:         0.5
		value_suffix: ' °C'
	}
	assert styled_slider_value_text(config, 20) == '20.0 °C'
	assert styled_slider_value_text(StyledSliderConfig{ ...config, decimals: 0 }, 20.4) == '20 °C'
	price := StyledSliderConfig{
		id:           'price'
		max:          1000
		step:         10
		value_prefix: '$'
	}
	assert styled_slider_value_text(price, 250) == '$250'
	continuous := StyledSliderConfig{
		id:   'c'
		max:  1
		step: 0
	}
	assert styled_slider_value_text(continuous, 0.5) == '0.50'
}

fn test_slider_validation_rejects_bad_configs() {
	base := StyledSliderConfig{
		id:    's'
		frame: rect(0, 0, 200, 24)
	}
	styled_slider(base)!
	for bad in [
		StyledSliderConfig{
			...base
			id: ''
		},
		StyledSliderConfig{
			...base
			min: 10
			max: 5
		},
		StyledSliderConfig{
			...base
			step: -1
		},
		StyledSliderConfig{
			...base
			scale: .logarithmic
		},
		StyledSliderConfig{
			...base
			value: math.nan()
		},
		StyledSliderConfig{
			...base
			marks: [SliderMark{
				value: math.inf(1)
			}]
		},
	] {
		if _ := styled_slider(bad) {
			assert false
		}
		assert styled_slider_change(bad, 'pointer:down:${styled_slider_track_id(bad.id)}:10:10') == none
	}
	// An empty range is valid and inert.
	empty := styled_slider(StyledSliderConfig{ ...base, min: 5, max: 5, value: 5 })!
	controls_assert_inside(empty)
}

// ── Slider geometry and build ───────────────────────────────────────

fn controls_slider() StyledSliderConfig {
	return StyledSliderConfig{
		id:    'vol'
		frame: rect(0, 0, 222, 24)
		value: 50
	}
}

fn test_slider_builds_track_fill_and_thumb() {
	config := controls_slider()
	el := styled_slider(config)!
	controls_assert_inside(el)
	assert el.accessibility_value == '50'
	thumb := controls_find(el, styled_slider_thumb_id('vol', .value)) or { panic('no thumb') }
	assert thumb.draggable
	assert thumb.accessibility_role == 'slider'
	assert thumb.accessibility_label == 'Slider'
	assert thumb.accessibility_value == '50'
	// pad = thumb / 2 + ring = 11, so the track is 200 long and 50 is at 111.
	assert controls_near(thumb.frame.x + thumb.frame.width / 2, 111)
	assert controls_near(thumb.frame.y + thumb.frame.height / 2, 12)
	// The thumb's shadow is centred, so its bottom edge is no larger than its top.
	assert thumb.box.shadow.opacity > 0
	assert thumb.box.shadow.y == 0
	track := controls_find(el, styled_slider_track_id('vol')) or { panic('no track') }
	assert track.draggable
	assert track.children.len == 2
	fill := track.children[1]
	assert controls_near(fill.frame.x, 11)
	assert controls_near(fill.frame.width, 100)
	assert fill.box.bg == component_theme(false).primary

	reversed := styled_slider(StyledSliderConfig{ ...config, reverse: true })!
	rfill := (controls_find(reversed, styled_slider_track_id('vol')) or { panic('no track') }).children[1]
	assert controls_near(rfill.frame.x, 111)
	assert controls_near(rfill.frame.width, 100)

	at_min := styled_slider(StyledSliderConfig{ ...config, value: 0 })!
	assert (controls_find(at_min, styled_slider_track_id('vol')) or { panic('no track') }).children.len == 1
}

fn test_slider_range_has_two_thumbs_and_fills_between() {
	config := StyledSliderConfig{
		id:                  'price'
		frame:               rect(0, 0, 222, 24)
		range:               true
		start:               80
		end:                 20
		accessibility_label: 'Price'
	}
	el := styled_slider(config)!
	controls_assert_inside(el)
	start := controls_find(el, styled_slider_thumb_id('price', .start)) or { panic('no start') }
	end := controls_find(el, styled_slider_thumb_id('price', .end)) or { panic('no end') }
	// Start and end are ordered, whichever way they were given.
	assert start.accessibility_value == '20'
	assert end.accessibility_value == '80'
	assert start.accessibility_label == 'Price minimum'
	assert end.accessibility_label == 'Price maximum'
	assert el.accessibility_value == '20 – 80'
	fill := (controls_find(el, styled_slider_track_id('price')) or { panic('no track') }).children[1]
	assert controls_near(fill.frame.x, 51)
	assert controls_near(fill.frame.width, 120)
	// Thumbs that meet in the upper half put the start on top.
	met := styled_slider(StyledSliderConfig{ ...config, start: 90, end: 90 })!
	ids := controls_collect(met, fn (e Element) bool {
		return e.draggable && e.id.contains('thumb')
	}).map(it.id)
	assert ids == [styled_slider_thumb_id('price', .end), styled_slider_thumb_id('price', .start)]
}

fn test_slider_marks_draw_dots_and_labels_inside_the_frame() {
	config := StyledSliderConfig{
		id:    'marks'
		frame: rect(0, 0, 222, 60)
		value: 50
		marks: [SliderMark{
			value: 0
			label: '0%'
		}, SliderMark{
			value: 50
			label: '50%'
		}, SliderMark{
			value: 100
			label: '100%'
		}, SliderMark{
			value: 120
			label: 'outside'
		}]
	}
	el := styled_slider(config)!
	controls_assert_inside(el)
	assert controls_texts(el) == ['0%', '50%', '100%']
	track := controls_find(el, styled_slider_track_id('marks')) or { panic('no track') }
	// Track, fill and one dot per mark in range.
	assert track.children.len == 5
	colors := styled_slider_colors(config)
	assert track.children[2].box.bg == colors.dot_on
	assert track.children[4].box.bg == colors.dot_off
	assert styled_slider_thickness(config) > slider_metrics(.medium).band
	marks := slider_step_marks(StyledSliderConfig{ ...config, max: 10, step: 1 }, 2.5, true)?
	assert marks.map(it.value) == [0.0, 2.5, 5, 7.5, 10]
	assert marks[1].label == '2.5'
	assert slider_step_marks(StyledSliderConfig{ ...config, max: 10 }, 3, false)?.map(it.value) == [
		0.0,
		3,
		6,
		9,
		10,
	]
	assert slider_step_marks(config, 0, false) == none
	assert slider_step_marks(config, 0.1, false) == none
}

fn test_slider_value_bubbles_follow_the_label_mode() {
	base := StyledSliderConfig{
		id:    'b'
		frame: rect(0, 0, 222, 60)
		value: 30
	}
	bubbles := fn (el Element) []Element {
		return controls_collect(el, fn (e Element) bool {
			return e.key.starts_with('bubble:')
		})
	}
	assert bubbles(styled_slider(base)!).len == 0
	assert bubbles(styled_slider(StyledSliderConfig{ ...base, value_label: .active })!).len == 0
	active := styled_slider(StyledSliderConfig{ ...base, value_label: .active, focused: true })!
	controls_assert_inside(active)
	assert bubbles(active).len == 1
	assert controls_texts(active) == ['30']
	always := styled_slider(StyledSliderConfig{ ...base, value_label: .always })!
	assert bubbles(always).len == 1
	// The bubble sits above the thumb, its arrow on the thumb's center.
	arrow := controls_find(always, component_part_id('b', 'arrow:value')) or { panic('no arrow') }
	thumb := controls_find(always, styled_slider_thumb_id('b', .value)) or { panic('no thumb') }
	assert controls_near(arrow.frame.x + arrow.frame.width / 2, thumb.frame.x + thumb.frame.width / 2)
	assert arrow.frame.y + arrow.frame.height <= thumb.frame.y

	range := StyledSliderConfig{
		...base
		range:       true
		start:       20
		end:         80
		value_label: .always
	}
	apart := styled_slider(range)!
	assert bubbles(apart).len == 2
	close := styled_slider(StyledSliderConfig{ ...range, start: 48, end: 52 })!
	assert bubbles(close).len == 1
	assert controls_texts(close) == ['48 – 52']
	only_start := styled_slider(StyledSliderConfig{
		...range
		value_label: .active
		focused:     true
		active:      .start
	})!
	assert controls_texts(only_start) == ['20']
	// The focused thumb gets a ring under it.
	assert only_start.children.len == apart.children.len - 1
}

fn test_slider_vertical_layout_puts_min_at_the_bottom() {
	config := StyledSliderConfig{
		id:          'v'
		frame:       rect(0, 0, 140, 222)
		orientation: .vertical
		value:       25
		value_label: .always
		marks:       [SliderMark{
			value: 100
			label: 'Max'
		}]
	}
	el := styled_slider(config)!
	controls_assert_inside(el)
	thumb := controls_find(el, styled_slider_thumb_id('v', .value)) or { panic('no thumb') }
	assert controls_near(thumb.frame.y + thumb.frame.height / 2, 11 + 150)
	track := controls_find(el, styled_slider_track_id('v')) or { panic('no track') }
	fill := track.children[1]
	assert controls_near(fill.frame.y, 161)
	assert controls_near(fill.frame.height, 50)
	// The bubble is left of the thumb and the mark label right of the track.
	arrow := controls_find(el, component_part_id('v', 'arrow:value')) or { panic('no arrow') }
	assert arrow.frame.x + arrow.frame.width <= thumb.frame.x
	labels := controls_collect(el, fn (e Element) bool {
		return e.kind == .label && e.text == 'Max'
	})
	assert labels[0].frame.x >= track.frame.x + track.frame.width
}

// ── Slider decoding ─────────────────────────────────────────────────

fn controls_pointer(phase string, action string, x f64, y f64) string {
	return 'pointer:${phase}:${action}:${x}:${y}'
}

fn test_slider_pointer_events_move_the_value() {
	config := StyledSliderConfig{
		...controls_slider()
		frame:    rect(20, 30, 222, 24)
		origin_x: 100
		origin_y: 50
	}
	track := styled_slider_track_id('vol')
	// The track starts at window x = 100 + 20 + 11.
	down := styled_slider_change(config, controls_pointer('down', track, 131 + 150, 90))?
	assert down.thumb == .value
	assert down.value == 75
	assert !down.done
	assert styled_slider_change(config, controls_pointer('drag', track, 131, 90))?.value == 0
	assert styled_slider_change(config, controls_pointer('drag', track, 1000, 90))?.value == 100
	// A drag that changes nothing is dropped; a release is always reported.
	assert styled_slider_change(config, controls_pointer('drag', track, 231, 90)) == none
	up := styled_slider_change(config, controls_pointer('up', track, 231, 90))?
	assert up.done && up.value == 50
	// A press on the thumb reports it without moving it.
	thumb := styled_slider_thumb_id('vol', .value)
	press := styled_slider_change(config, controls_pointer('down', thumb, 240, 90))?
	assert press.value == 50
	assert styled_slider_change(config, controls_pointer('drag', thumb, 241, 90))?.value == 55
	// Foreign, forged, wrong-thumb, hover and disabled events are none.
	assert styled_slider_change(config, controls_pointer('down', 'other', 200, 90)) == none
	assert styled_slider_change(config, controls_pointer('down', component_part_id('vol',
		'knob'), 200, 90)) == none
	assert styled_slider_change(config, controls_pointer('down', styled_slider_thumb_id('vol',
		.start), 200, 90)) == none
	assert styled_slider_change(config, controls_pointer('enter', track, 200, 90)) == none
	assert styled_slider_change(StyledSliderConfig{ ...config, enabled: false }, controls_pointer('down',
		track, 200, 90)) == none
	assert styled_slider_change(config, 'vol') == none
}

fn test_slider_range_moves_the_nearest_thumb_and_keeps_order() {
	config := StyledSliderConfig{
		id:    'r'
		frame: rect(0, 0, 222, 24)
		range: true
		start: 20
		end:   60
	}
	track := styled_slider_track_id('r')
	near_start := styled_slider_change(config, controls_pointer('down', track, 11 + 10, 12))?
	assert near_start.thumb == .start
	assert near_start.start == 5 && near_start.end == 60
	near_end := styled_slider_change(config, controls_pointer('down', track, 11 + 160, 12))?
	assert near_end.thumb == .end
	assert near_end.start == 20 && near_end.end == 80
	// Dragging the start thumb past the end stops at the end.
	start_thumb := styled_slider_thumb_id('r', .start)
	past := styled_slider_change(config, controls_pointer('drag', start_thumb, 11 + 180, 12))?
	assert past.thumb == .start
	assert past.start == 60 && past.end == 60
	end_thumb := styled_slider_thumb_id('r', .end)
	below := styled_slider_change(config, controls_pointer('drag', end_thumb, 0, 12))?
	assert below.start == 20 && below.end == 20
	assert styled_slider_change(config, controls_pointer('down', styled_slider_thumb_id('r',
		.value), 50, 12)) == none
	// A drag from the track of an unfocused range moves whichever thumb is
	// nearer; a focused range keeps moving its active thumb, even past the other.
	assert styled_slider_change(config, controls_pointer('drag', track, 11 + 180, 12))?.thumb == .end
	focused := StyledSliderConfig{
		...config
		focused: true
		active:  .start
	}
	kept := styled_slider_change(focused, controls_pointer('drag', track, 11 + 180, 12))?
	assert kept.thumb == .start && kept.start == 60 && kept.end == 60
	// A press always picks the nearer thumb.
	assert styled_slider_change(focused, controls_pointer('down', track, 11 + 180, 12))?.thumb == .end
}

fn test_slider_vertical_snap_to_marks_and_log_pointer_mapping() {
	vertical := StyledSliderConfig{
		id:          'v'
		frame:       rect(0, 0, 40, 222)
		orientation: .vertical
	}
	track := styled_slider_track_id('v')
	assert styled_slider_change(vertical, controls_pointer('down', track, 20, 11))?.value == 100
	assert styled_slider_change(vertical, controls_pointer('down', track, 20, 161))?.value == 25

	marks := StyledSliderConfig{
		...controls_slider()
		snap_to_marks: true
		marks:         [SliderMark{
			value: 0
		}, SliderMark{
			value: 30
		}, SliderMark{
			value: 100
		}]
	}
	assert styled_slider_change(marks, controls_pointer('down', styled_slider_track_id('vol'),
		11 + 90, 12))?.value == 30
	assert styled_slider_change(marks, controls_pointer('down', styled_slider_track_id('vol'),
		11 + 140, 12))?.value == 100

	log := StyledSliderConfig{
		id:    'log'
		frame: rect(0, 0, 222, 24)
		min:   1
		max:   1000
		value: 10
		scale: .logarithmic
	}
	assert styled_slider_change(log, controls_pointer('down', styled_slider_track_id('log'),
		11 + 100, 12))?.value == 32
}

fn test_slider_keys_step_page_and_jump() {
	config := controls_slider()
	key := fn (code KeyCode) KeyEvent {
		return KeyEvent{
			code: code
		}
	}
	assert styled_slider_change_after_key(config, key(.right))?.value == 51
	assert styled_slider_change_after_key(config, key(.up))?.value == 51
	assert styled_slider_change_after_key(config, key(.left))?.value == 49
	assert styled_slider_change_after_key(config, KeyEvent{ code: .right, shift: true })?.value == 60
	assert styled_slider_change_after_key(config, key(.page_up))?.value == 60
	assert styled_slider_change_after_key(config, key(.page_down))?.value == 40
	assert styled_slider_change_after_key(config, key(.home))?.value == 0
	end := styled_slider_change_after_key(config, key(.end))?
	assert end.value == 100 && end.done
	assert styled_slider_change_after_key(StyledSliderConfig{ ...config, value: 100 },
		key(.right)) == none
	assert styled_slider_change_after_key(config, KeyEvent{ code: .right, cmd: true }) == none
	assert styled_slider_change_after_key(config, key(.a)) == none
	assert styled_slider_change_after_key(StyledSliderConfig{ ...config, enabled: false },
		key(.right)) == none

	range := StyledSliderConfig{
		...config
		range:  true
		start:  40
		end:    42
		active: .start
	}
	moved := styled_slider_change_after_key(range, key(.right))?
	assert moved.thumb == .start && moved.start == 41 && moved.end == 42
	assert styled_slider_change_after_key(range, key(.end))?.start == 42
	end_moves := styled_slider_change_after_key(StyledSliderConfig{ ...range, active: .value },
		key(.left))?
	assert end_moves.thumb == .end && end_moves.end == 41

	marks := StyledSliderConfig{
		...config
		value:         30
		snap_to_marks: true
		marks:         [SliderMark{
			value: 0
		}, SliderMark{
			value: 30
		}, SliderMark{
			value: 100
		}]
	}
	assert styled_slider_change_after_key(marks, key(.right))?.value == 100
	assert styled_slider_change_after_key(marks, key(.left))?.value == 0
	assert styled_slider_change_after_key(StyledSliderConfig{ ...marks, value: 100 }, key(.right)) == none

	log := StyledSliderConfig{
		...config
		min:   1
		max:   1000
		value: 500
		scale: .logarithmic
	}
	up := styled_slider_change_after_key(log, key(.right))?
	assert up.value > 500 && up.value < 600
	assert styled_slider_change_after_key(StyledSliderConfig{ ...log, value: 1 }, key(.right))?.value == 2

	continuous := StyledSliderConfig{
		...config
		max:   1
		value: 0.5
		step:  0
	}
	assert controls_near(styled_slider_change_after_key(continuous, key(.right))?.value, 0.51)
}
