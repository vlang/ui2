// SPDX-License-Identifier: Apache-2.0
// Includes number-input stepping cases adapted from GPUI Kit (Longbridge,
// copyright 2024 - 2026); the other tests are new. See third_party/gpui-kit.
module ui2

import math

fn inputs_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := inputs_find(child, id) {
			return found
		}
	}
	return none
}

fn inputs_has_key(el Element, key string) bool {
	for child in el.children {
		if child.key == key {
			return true
		}
	}
	return false
}

// ── Number input ─────────────────────────────────────────────────────

fn inputs_number_config(text string) NumberInputConfig {
	return NumberInputConfig{
		id:    'qty'
		frame: rect(0, 0, 160, 32)
		text:  text
	}
}

fn test_number_input_parse_accepts_signed_decimals_only() {
	assert number_input_parse('42') or { 0 } == 42
	assert number_input_parse(' -1.5 ') or { 0 } == -1.5
	assert number_input_parse('.5') or { 0 } == 0.5
	assert number_input_parse('2.') or { 0 } == 2
	assert number_input_parse('+7') or { 0 } == 7
	for bad in ['', '-', '.', '+.', '1e3', '1,000', '1.2.3', '--1', 'abc', '١٢'] {
		if value := number_input_parse(bad) {
			assert false, '`${bad}` parsed as ${value}'
		}
	}
}

fn test_number_input_format_avoids_float_noise() {
	assert number_input_format(0.1 + 0.2, 1) == '0.3'
	assert number_input_format(-0.04, 1) == '0.0'
	assert number_input_format(-2.5, 0) == '-3'
	assert number_input_format(0.05, 2) == '0.05'
	assert number_input_format(12, 3) == '12.000'
	assert number_input_format(math.nan(), 2) == ''
	assert number_input_format(3, -4) == '3'
	assert number_input_format(1.0, 99).len == '1.'.len + number_input_max_precision
}

fn test_number_input_sanitize_keeps_a_number() {
	config := inputs_number_config('')
	assert number_input_sanitize(config, '12a3') == '123'
	assert number_input_sanitize(config, '-1.2.3') == '-1.23'
	assert number_input_sanitize(config, '1-2') == '12'
	assert number_input_sanitize(config, '１２３．５') == '123.5'
	assert number_input_sanitize(config, '－４') == '-4'
	assert number_input_sanitize(config, '+5') == '+5'
	assert number_input_sanitize(config, '1,000 ') == '1000'
	positive := NumberInputConfig{
		...config
		min: 0
	}
	assert number_input_sanitize(positive, '-5') == '5'
	integers := NumberInputConfig{
		...config
		precision: 0
	}
	assert number_input_sanitize(integers, '3.75') == '375'
}

fn test_number_input_step_keeps_decimals_and_direction() {
	assert number_input_step(inputs_number_config('1'), .increment) or { '' } == '2'
	assert number_input_step(inputs_number_config('-2'), .increment) or { '' } == '-1'
	assert number_input_step(inputs_number_config(''), .increment) or { '' } == '1'
	assert number_input_step(inputs_number_config(''), .decrement) or { '' } == '-1'
	assert number_input_step(inputs_number_config('-'), .increment) or { '' } == '1'
	assert number_input_step(inputs_number_config('1.25'), .increment) or { '' } == '2.25'
	tenth := NumberInputConfig{
		...inputs_number_config('0.2')
		step: 0.1
	}
	assert number_input_step(tenth, .increment) or { '' } == '0.3'
	assert number_input_step(NumberInputConfig{ ...tenth, text: '0.3' }, .decrement) or { '' } == '0.2'
	money := NumberInputConfig{
		...inputs_number_config('4')
		step:      0.25
		precision: 2
	}
	assert number_input_step(money, .increment) or { '' } == '4.25'
}

fn test_number_input_step_respects_bounds() {
	bounded := NumberInputConfig{
		...inputs_number_config('99.5')
		min: 10
		max: 100
	}
	assert number_input_step(bounded, .increment) or { '' } == '100.0'
	assert number_input_step(NumberInputConfig{ ...bounded, text: '100' }, .increment) == none
	assert number_input_step(NumberInputConfig{ ...bounded, text: '10' }, .decrement) == none
	// A value outside the range only steps back toward it.
	assert number_input_step(NumberInputConfig{ ...bounded, text: '5' }, .decrement) == none
	assert number_input_step(NumberInputConfig{ ...bounded, text: '5' }, .increment) or { '' } == '10'
	assert number_input_step(NumberInputConfig{ ...bounded, text: '1000' }, .increment) == none
	assert number_input_step(NumberInputConfig{ ...bounded, text: '1000' }, .decrement) or { '' } == '100'
	// An empty field steps into the range from zero.
	assert number_input_step(NumberInputConfig{ ...bounded, text: '' }, .decrement) or { '' } == '10'
	quarter := NumberInputConfig{
		...inputs_number_config('1')
		min: 0.25
	}
	assert number_input_step(quarter, .decrement) or { '' } == '0.25'
	// Fixed precision never rounds a bound outside the range.
	tight := NumberInputConfig{
		...inputs_number_config('0')
		max:       0.25
		precision: 1
	}
	assert number_input_step(tight, .increment) or { '' } == '0.2'
}

fn test_number_input_in_range() {
	config := NumberInputConfig{
		...inputs_number_config('')
		min: 1
		max: 99
	}
	assert number_input_in_range(config, '1')
	assert number_input_in_range(config, '99.0')
	assert !number_input_in_range(config, '150')
	assert !number_input_in_range(config, '0.5')
	assert !number_input_in_range(config, '')
	assert !number_input_in_range(config, '-')
	assert number_input_in_range(inputs_number_config(''), '-1')
}

fn test_number_input_disabled_and_readonly_do_not_step() {
	assert number_input_step(NumberInputConfig{ ...inputs_number_config('1'), enabled: false }, .increment) == none
	assert number_input_step(NumberInputConfig{ ...inputs_number_config('1'), readonly: true }, .increment) == none
	assert number_input_step(NumberInputConfig{ ...inputs_number_config('1'), step: 0 }, .increment) == none
}

fn test_number_input_commit_parses_clamps_and_formats() {
	config := NumberInputConfig{
		...inputs_number_config('')
		min: 1
		max: 99
	}
	assert number_input_commit(config, ' ') or { 'x' } == ''
	assert number_input_commit(config, '007') or { '' } == '7'
	assert number_input_commit(config, '250') or { '' } == '99'
	assert number_input_commit(config, '0.5') or { '' } == '1.0'
	assert number_input_commit(config, '2.') or { '' } == '2'
	assert number_input_commit(config, '-') == none
	money := NumberInputConfig{
		...config
		precision: 2
	}
	assert number_input_commit(money, '3.456') or { '' } == '3.46'
	assert number_input_commit(money, '5') or { '' } == '5.00'
}

fn test_number_input_actions_and_keys() {
	config := NumberInputConfig{
		...inputs_number_config('5')
		max: 5
	}
	field := number_input_field_id('qty')
	assert field == 'qty:component:field'
	assert number_input_event(config, field) or { NumberInputEventKind.submit } == .change
	assert number_input_event(config, 'qty:component:submit') or { NumberInputEventKind.change } == .submit
	assert number_input_event(config, 'qty:component:decrement') or { NumberInputEventKind.change } == .decrement
	// At the max the increment is a no-op and is rejected.
	assert number_input_event(config, 'qty:component:increment') == none
	assert number_input_value_from_action(config, 'qty:component:decrement') or { '' } == '4'
	assert number_input_value_from_action(config, field) == none
	for forged in ['qty', 'other:component:increment', 'qty:component:', 'qty:component:incrementx',
		'qty:component:Increment'] {
		assert number_input_event(config, forged) == none
	}
	assert number_input_event(NumberInputConfig{ ...config, enabled: false }, field) == none
	assert number_input_event(NumberInputConfig{ ...config, readonly: true }, field) == none
	assert number_input_event(NumberInputConfig{ ...config, readonly: true }, 'qty:component:submit') or {
		NumberInputEventKind.change
	} == .submit
	up := KeyEvent{
		code: .up
	}
	down := KeyEvent{
		code: .down
	}
	assert number_input_key_step(up) or { NumberInputStep.decrement } == .increment
	assert number_input_key_step(KeyEvent{ code: .up, shift: true }) == none
	assert number_input_key_step(KeyEvent{ code: .left }) == none
	assert number_input_value_from_key(config, up) == none
	assert number_input_value_from_key(config, down) or { '' } == '4'
}

fn test_number_input_elements_and_validation() {
	el := number_input(NumberInputConfig{
		...inputs_number_config('5')
		min:                 0
		max:                 5
		accessibility_label: 'Quantity'
	}) or { panic(err) }
	assert el.accessibility_role == 'group'
	assert el.accessibility_value == 'from 0 to 5'
	field := inputs_find(el, 'qty:component:field') or { panic('no field') }
	assert field.kind == .text_field
	assert field.text == '5'
	assert field.emit_change
	assert field.submit_id == 'qty:component:submit'
	assert field.frame == rect(32, 0, 96, 32)
	assert field.text_style.align == .left
	assert field.padding_left == 12
	centered := number_input(NumberInputConfig{ ...inputs_number_config(''), align: .center }) or {
		panic(err)
	}
	assert centered.children[0].text_style.align == .center
	assert centered.children[0].padding_left == 8
	assert field.accessibility_label == 'Quantity'
	decrement := inputs_find(el, 'qty:component:decrement') or { panic('no decrement') }
	increment := inputs_find(el, 'qty:component:increment') or { panic('no increment') }
	assert decrement.enabled
	assert !increment.enabled
	assert decrement.frame == rect(0, 0, 32, 32)
	assert increment.frame == rect(128, 0, 32, 32)
	trailing := number_input(NumberInputConfig{
		...inputs_number_config('')
		controls: .trailing
		frame:    rect(10, 10, 120, 32)
	}) or { panic(err) }
	trailing_field := inputs_find(trailing, 'qty:component:field') or { panic('no field') }
	assert trailing_field.frame == rect(0, 0, 96, 32)
	up := inputs_find(trailing, 'qty:component:increment') or { panic('no increment') }
	assert up.frame == rect(96, 0, 24, 16)
	assert inputs_has_key(trailing, 'divider')
	disabled_el := number_input(NumberInputConfig{ ...inputs_number_config('3'), enabled: false }) or {
		panic(err)
	}
	for part in ['field', 'decrement', 'increment'] {
		child := inputs_find(disabled_el, 'qty:component:${part}') or { panic('no ${part}') }
		assert !child.enabled
	}
	for bad in [NumberInputConfig{
		...inputs_number_config('')
		step: -1
	}, NumberInputConfig{
		...inputs_number_config('')
		step: math.inf(1)
	}, NumberInputConfig{
		...inputs_number_config('')
		min: 5
		max: 1
	}, NumberInputConfig{
		...inputs_number_config('')
		precision: 13
	}, NumberInputConfig{
		...inputs_number_config('')
		min: math.nan()
	}, NumberInputConfig{
		...inputs_number_config('')
		id: ''
	}, NumberInputConfig{
		...inputs_number_config('')
		frame: rect(0, 0, -1, 10)
	}] {
		if _ := number_input(bad) {
			assert false, 'invalid number input accepted'
		}
	}
}

// ── OTP input ────────────────────────────────────────────────────────

fn inputs_otp_config(code string) OtpInputConfig {
	return OtpInputConfig{
		id:    'otp'
		frame: rect(0, 0, 400, 48)
		code:  code
	}
}

fn test_otp_input_normalize_by_charset() {
	assert otp_input_normalize('12 34-56', .digits) == '123456'
	assert otp_input_normalize('１２３', .digits) == '123'
	assert otp_input_normalize('ab12', .digits) == '12'
	assert otp_input_normalize('ab-12_Ｃ', .alphanumeric) == 'ab12C'
	assert otp_input_normalize('é٣', .alphanumeric) == ''
}

fn test_otp_input_typing_appends_and_moves_focus() {
	first := otp_input_edit(inputs_otp_config(''), 0, '1')
	assert first.code == '1'
	assert first.focus == 1
	assert first.changed
	assert !first.complete
	// Typing into a later empty cell still fills the first empty one.
	skipped := otp_input_edit(inputs_otp_config('12'), 5, '3')
	assert skipped.code == '123'
	assert skipped.focus == 3
	// Typing in a filled cell replaces its character, whichever side the caret was on.
	after := otp_input_edit(inputs_otp_config('123'), 1, '27')
	assert after.code == '173'
	assert after.focus == 2
	before := otp_input_edit(inputs_otp_config('123'), 1, '72')
	assert before.code == '173'
	// The same character again keeps the code and still advances.
	same := otp_input_edit(inputs_otp_config('123'), 1, '22')
	assert same.code == '123'
	assert !same.changed
	assert same.focus == 2
	last := otp_input_edit(inputs_otp_config('12345'), 5, '6')
	assert last.complete
	assert last.focus == 5
	assert otp_input_cell_text(last.code, 5) == '6'
	assert otp_input_cell_text(last.code, 6) == ''
}

fn test_otp_input_paste_fills_cells_and_rejects_other_characters() {
	pasted := otp_input_edit(inputs_otp_config(''), 0, '123-456')
	assert pasted.code == '123456'
	assert pasted.complete
	assert pasted.focus == 5
	overflow := otp_input_edit(inputs_otp_config('12'), 2, '3456789')
	assert overflow.code == '123456'
	middle := otp_input_edit(inputs_otp_config('123456'), 2, '9')
	assert middle.code == '129456'
	assert middle.focus == 3
	rejected := otp_input_edit(inputs_otp_config('12'), 2, 'x')
	assert rejected.code == '12'
	assert !rejected.changed
	assert rejected.focus == 2
	letters := otp_input_edit(OtpInputConfig{ ...inputs_otp_config('A'), charset: .alphanumeric },
		1, 'b')
	assert letters.code == 'Ab'
	disabled_el := otp_input_edit(OtpInputConfig{ ...inputs_otp_config(''), enabled: false }, 0, '1')
	assert !disabled_el.changed
}

fn test_otp_input_clearing_a_cell_closes_the_gap() {
	cleared := otp_input_edit(inputs_otp_config('123456'), 2, '')
	assert cleared.code == '12456'
	assert cleared.focus == 2
	assert !cleared.complete
	nothing := otp_input_edit(inputs_otp_config('12'), 4, '')
	assert !nothing.changed
}

fn test_otp_input_keys() {
	backspace := KeyEvent{
		code: .backspace
	}
	// In the empty cell after the code, Backspace removes the last character.
	back := otp_input_key(inputs_otp_config('123'), 3, backspace) or { panic('ignored') }
	assert back.code == '12'
	assert back.focus == 2
	// In a filled cell it removes that character and stays.
	own := otp_input_key(inputs_otp_config('123456'), 5, backspace) or { panic('ignored') }
	assert own.code == '12345'
	assert own.focus == 5
	assert otp_input_key(inputs_otp_config(''), 0, backspace) == none
	delete := otp_input_key(inputs_otp_config('123'), 0, KeyEvent{ code: .delete }) or { panic('ignored') }
	assert delete.code == '23'
	assert otp_input_key(inputs_otp_config('123'), 3, KeyEvent{ code: .delete }) == none
	left := otp_input_key(inputs_otp_config('123'), 2, KeyEvent{ code: .left }) or { panic('ignored') }
	assert left.focus == 1
	assert !left.changed
	assert otp_input_key(inputs_otp_config('123'), 0, KeyEvent{ code: .left }) == none
	right := otp_input_key(inputs_otp_config('123'), 2, KeyEvent{ code: .right }) or { panic('ignored') }
	assert right.focus == 3
	// Right stops at the first empty cell.
	assert otp_input_key(inputs_otp_config('123'), 3, KeyEvent{ code: .right }) == none
	end := otp_input_key(inputs_otp_config('123'), 0, KeyEvent{ code: .end }) or { panic('ignored') }
	assert end.focus == 3
	home := otp_input_key(inputs_otp_config('123'), 3, KeyEvent{ code: .home }) or { panic('ignored') }
	assert home.focus == 0
	// Shortcuts such as Cmd+V and other keys are left to the field.
	assert otp_input_key(inputs_otp_config('123'), 3, KeyEvent{ code: .v, cmd: true }) == none
	assert otp_input_key(inputs_otp_config('123'), 3, KeyEvent{ code: ._4 }) == none
	assert otp_input_key(OtpInputConfig{ ...inputs_otp_config('123'), enabled: false }, 3, backspace) == none
}

fn test_otp_input_cell_actions() {
	config := inputs_otp_config('12')
	assert otp_input_cell_id('otp', 3) == 'otp:component:cell:3'
	assert otp_input_cell_from_action(config, 'otp:component:cell:3') or { -1 } == 3
	for forged in ['otp:component:cell:6', 'otp:component:cell:03', 'otp:component:cell:-1',
		'otp:component:cell:', 'otp:component:cell:99999999999999999999', 'other:component:cell:1',
		'otp'] {
		assert otp_input_cell_from_action(config, forged) == none
	}
	assert otp_input_cell_from_action(OtpInputConfig{ ...config, enabled: false }, 'otp:component:cell:1') == none
	assert otp_input_focus_index(config) == 2
	assert otp_input_focus_index(inputs_otp_config('123456789')) == 5
}

fn test_otp_input_groups_and_layout() {
	config := inputs_otp_config('12')
	assert otp_input_width(config) == 6 * 34 + 4 * 6 + 20
	cells := otp_input_cell_frames(config)
	assert cells.len == 6
	assert cells[0] == rect(0, 4, 34, 40)
	assert cells[2].x + cells[2].width + 20 == cells[3].x
	assert otp_input_group_of(OtpInputConfig{ ...config, groups: 0 }, 5) == 0
	assert otp_input_group_of(OtpInputConfig{ ...config, groups: 20 }, 5) == 5
	assert otp_input_group_of(OtpInputConfig{ ...config, length: 5, groups: 2 }, 3) == 1
	narrow := otp_input_cell_frames(OtpInputConfig{ ...config, frame: rect(0, 0, 124, 48) })
	assert math.abs(narrow[5].x + narrow[5].width - 124) < 1e-9
}

fn test_otp_input_elements() {
	el := otp_input(OtpInputConfig{
		...inputs_otp_config('12')
		masked:    true
		separator: '-'
	}) or { panic(err) }
	assert el.accessibility_role == 'group'
	assert el.accessibility_value == '2 of 6 entered'
	assert inputs_has_key(el, 'separator:3')
	first := inputs_find(el, 'otp:component:cell:0') or { panic('no cell') }
	assert first.kind == .text_field
	assert first.text == '1'
	assert first.secure
	assert first.emit_change
	assert !first.autocorrect
	assert first.accessibility_label == 'Digit 1 of 6'
	empty := inputs_find(el, 'otp:component:cell:4') or { panic('no cell') }
	assert empty.text == ''
	disabled_el := otp_input(OtpInputConfig{ ...inputs_otp_config(''), enabled: false }) or { panic(err) }
	cell := inputs_find(disabled_el, 'otp:component:cell:0') or { panic('no cell') }
	assert !cell.enabled
	invalid := otp_input(OtpInputConfig{ ...inputs_otp_config(''), invalid: true }) or { panic(err) }
	invalid_cell := inputs_find(invalid, 'otp:component:cell:0') or { panic('no cell') }
	assert invalid_cell.box.border_color == ComponentTheme{}.danger
	for length in [0, -1, otp_input_max_length + 1] {
		if _ := otp_input(OtpInputConfig{ ...inputs_otp_config(''), length: length }) {
			assert false, 'length ${length} accepted'
		}
	}
}

// ── Input group ──────────────────────────────────────────────────────

fn inputs_group_config(text string) InputGroupConfig {
	return InputGroupConfig{
		id:        'search'
		frame:     rect(0, 0, 300, 32)
		text:      text
		clearable: true
		addons:    [
			InputGroupAddon{
				id:   'icon'
				kind: .icon
				icon: 'magnifyingglass'
			},
			InputGroupAddon{
				id:      'go'
				kind:    .button
				side:    .trailing
				text:    'Go'
				primary: true
			},
		]
	}
}

fn test_input_group_layout_and_clear_button() {
	layout := input_group_layout(inputs_group_config('gpui'))
	assert layout.leading == [rect(0, 0, 32, 32)]
	// The button width follows input_group_addon_width's order of operations
	// (estimate + 2*padding, then padding/2 plus the bold slack) so the f64
	// accumulation matches bit for bit: regrouping it as estimate * 1.08
	// rounds one ulp differently.
	go_width := component_text_width_estimate('Go', 14) + 16 + (4 + component_text_width_estimate('Go', 14) * 0.08)
	assert layout.trailing == [rect(300 - go_width, 0, go_width, 32)]
	assert layout.field == rect(32, 0, 300 - 32 - go_width, 32)
	assert layout.clear == rect(layout.field.x + layout.field.width - 31, 1, 30, 30)
	assert input_group_layout(inputs_group_config('')).clear.width == 0
	assert input_group_layout(InputGroupConfig{ ...inputs_group_config('x'), readonly: true }).clear.width == 0
	// Addons shrink so the field keeps two control heights.
	crowded := input_group_layout(InputGroupConfig{
		...inputs_group_config('')
		frame:  rect(0, 0, 100, 32)
		addons: [InputGroupAddon{
			id:   'long'
			kind: .text
			text: 'a very long prefix'
		}]
	})
	assert crowded.field.width == 64
	assert crowded.leading[0].width == 36
}

fn test_input_group_elements() {
	el := input_group(inputs_group_config('gpui')) or { panic(err) }
	assert el.accessibility_role == 'group'
	field := inputs_find(el, 'search:component:field') or { panic('no field') }
	assert field.kind == .text_field
	assert field.text == 'gpui'
	assert field.submit_id == 'search:component:submit'
	clear := inputs_find(el, 'search:component:clear') or { panic('no clear') }
	assert clear.button_behavior
	assert clear.accessibility_label == 'Clear'
	assert clear.children[0].image_path == 'symbol:xmark'
	go_button := inputs_find(el, 'search:component:addon:${'go'.bytes().hex()}') or {
		panic('no go')
	}
	assert go_button.button_behavior
	assert go_button.accessibility_label == 'Go'
	icon := el.children[0]
	assert icon.key == 'addon:icon'
	assert icon.accessibility_role == 'img'
	assert icon.children[0].image_path == 'symbol:magnifyingglass'
	// Keys keep the field's identity when the clear button comes and goes.
	keys := el.children.map(it.key)
	assert keys == ['addon:icon', 'field', 'clear', 'addon:go']
	empty := input_group(inputs_group_config('')) or { panic(err) }
	assert empty.children.map(it.key) == ['addon:icon', 'field', 'addon:go']
	disabled_el := input_group(InputGroupConfig{ ...inputs_group_config('x'), enabled: false }) or {
		panic(err)
	}
	assert !disabled_el.children[1].enabled
	assert !disabled_el.children[2].enabled
	invalid := input_group(InputGroupConfig{ ...inputs_group_config('x'), invalid: true }) or { panic(err) }
	assert invalid.box.border_color == ComponentTheme{}.danger
}

fn test_input_group_events() {
	config := inputs_group_config('gpui')
	go_action := 'search:component:addon:${'go'.bytes().hex()}'
	assert input_group_field_id('search') == 'search:component:field'
	assert (input_group_event(config, 'search:component:field') or { panic('none') }).kind == .change
	assert (input_group_event(config, 'search:component:submit') or { panic('none') }).kind == .submit
	assert (input_group_event(config, 'search:component:clear') or { panic('none') }).kind == .clear
	pressed := input_group_event(config, go_action) or { panic('none') }
	assert pressed.kind == .addon
	assert pressed.addon == 'go'
	// Nothing to clear, read-only, disabled, foreign and forged actions.
	assert input_group_event(inputs_group_config(''), 'search:component:clear') == none
	assert input_group_event(InputGroupConfig{ ...config, readonly: true }, 'search:component:field') == none
	assert input_group_event(InputGroupConfig{ ...config, enabled: false }, go_action) == none
	icon := 'search:component:addon:${'icon'.bytes().hex()}'
	for forged in [icon, 'search:component:addon:zz', 'search:component:addon:', 'other:component:field',
		'search', 'search:component:fieldx'] {
		assert input_group_event(config, forged) == none
	}
	off := InputGroupConfig{
		...config
		addons: [InputGroupAddon{
			id:      'go'
			kind:    .button
			text:    'Go'
			enabled: false
		}]
	}
	assert input_group_event(off, go_action) == none
}

fn test_input_group_validation() {
	for addons in [
		[InputGroupAddon{
			id:   ''
			kind: .text
			text: 'x'
		}],
		[InputGroupAddon{
			id:   'a'
			kind: .text
			text: 'x'
		}, InputGroupAddon{
			id:   'a'
			kind: .text
			text: 'y'
		}],
		[InputGroupAddon{
			id:   'a'
			kind: .icon
			icon: 'not.a.known.symbol'
		}],
		[InputGroupAddon{
			id:   'a'
			kind: .button
			icon: 'eye'
		}],
		[InputGroupAddon{
			id:   'a'
			kind: .text
		}],
	] {
		if _ := input_group(InputGroupConfig{ ...inputs_group_config(''), addons: addons }) {
			assert false, 'invalid addons accepted'
		}
	}
	if _ := input_group(InputGroupConfig{ ...inputs_group_config(''), id: ' ' }) {
		assert false, 'group accepted without identity'
	}
	icon_button := input_group(InputGroupConfig{
		...inputs_group_config('')
		addons: [InputGroupAddon{
			id:                  'reveal'
			kind:                .button
			side:                .trailing
			icon:                'eye'
			accessibility_label: 'Show password'
		}]
	}) or { panic(err) }
	assert icon_button.children[1].accessibility_label == 'Show password'
}
