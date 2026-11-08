// SPDX-License-Identifier: Apache-2.0
// Includes form layout tests adapted from GPUI Kit (Longbridge, copyright
// 2024 - 2026), crates/component/src/form/tests.rs: label orientation is
// independent of the columns, and hidden fields leave no row behind. The other
// tests are new. See third_party/gpui-kit.
module ui2

import math

// form_box is a control that fills the frame the form gives it.
fn form_box(id string) FormSlotFn {
	return fn [id] (frame Rect) !Element {
		return view(id, frame, BoxStyle{}, []Element{})
	}
}

fn form_test_fields(count int) []FormField {
	mut fields := []FormField{}
	for i in 0 .. count {
		fields << FormField{
			id:      'f${i}'
			label:   'Field ${i}'
			control: form_box('c${i}')
		}
	}
	return fields
}

fn form_find(el Element, key string) ?Element {
	for child in el.children {
		if child.key == key {
			return child
		}
	}
	return none
}

fn form_layout_of(config FormConfig) FormLayout {
	return form_layout(config) or { panic(err) }
}

fn form_right(r Rect) f64 {
	return r.x + r.width
}

fn form_bottom(r Rect) f64 {
	return r.y + r.height
}

// ── Grid placement ──────────────────────────────────────────────────

fn test_form_place_flows_spans_and_column_starts_like_a_sparse_grid() {
	fields := [
		FormField{
			id: 'a'
		},
		FormField{
			id: 'b'
		},
		FormField{
			id: 'c'
		},
		FormField{
			id:       'wide'
			col_span: 2
		},
		FormField{
			id:        'third'
			col_start: 3
		},
		FormField{
			id:        'first'
			col_start: 1
		},
		FormField{
			id:       'huge'
			col_span: 9
		},
	]
	placed := form_place(fields, 3)
	cells := placed.map('${fields[it.index].id}@${it.row},${it.column}+${it.span}')
	// `wide` does not fit after `c`, so it starts row 1; `third` fits beside it;
	// `first` cannot go back to column 0 of row 1 and opens row 2; a span wider
	// than the grid is clamped and gets a row of its own.
	assert cells == ['a@0,0+1', 'b@0,1+1', 'c@0,2+1', 'wide@1,0+2', 'third@1,2+1', 'first@2,0+1',
		'huge@3,0+3']
}

fn test_form_place_leaves_holes_and_gives_sections_their_own_row() {
	fields := [
		FormField{
			id:        'right'
			col_start: 2
		},
		FormField{
			id: 'next'
		},
		FormField{
			id:   'section'
			kind: .section
		},
		FormField{
			id:      'hidden'
			visible: false
		},
		FormField{
			id:       'after'
			col_span: 2
		},
	]
	placed := form_place(fields, 2)
	cells := placed.map('${fields[it.index].id}@${it.row},${it.column}+${it.span}')
	// The hole at row 0, column 0 is not filled by the field after `right`.
	assert cells == ['right@0,1+1', 'next@1,0+1', 'section@2,0+2', 'after@3,0+2']
	// A column start past the grid is clamped into it.
	clamped := form_place([FormField{
		id:        'x'
		col_start: 7
		col_span:  2
	}], 3)
	assert clamped[0].column == 1 && clamped[0].span == 2
}

// ── Layout ──────────────────────────────────────────────────────────

// As GPUI Kit's own test: label orientation and grid columns are independent.
fn test_form_label_layout_is_independent_of_field_columns() {
	for width in [360.0, 800.0] {
		for orientation in [LayoutOrientation.horizontal, .vertical] {
			config := FormConfig{
				id:           'form'
				frame:        rect(0, 0, width, 0)
				columns:      2
				label_width:  80
				label_layout: orientation
				fields:       form_test_fields(3)
			}
			layout := form_layout_of(config)
			first := layout.fields[0].control
			second := layout.fields[1].control
			third := layout.fields[2].control
			caption := layout.fields[0].label
			assert first.y == second.y
			assert second.x > form_right(first)
			assert first.x == third.x
			assert third.y > form_bottom(first)
			if orientation == .horizontal {
				assert form_right(caption) < first.x
				assert caption.width == 80
				// The label is centered on a one-line control.
				assert math.abs((caption.y + caption.height / 2) - (first.y + first.height / 2)) < 1e-9
			} else {
				assert caption.x == first.x
				assert form_bottom(caption) < first.y
			}
			assert form_right(layout.fields[1].cell) <= width + 1e-9
		}
	}
}

fn test_form_hidden_fields_take_no_room() {
	mut fields := form_test_fields(3)
	shown := form_layout_of(FormConfig{
		id:     'form'
		frame:  rect(0, 0, 400, 0)
		fields: fields
	})
	fields[1] = FormField{
		...fields[1]
		visible: false
	}
	hidden := form_layout_of(FormConfig{
		id:     'form'
		frame:  rect(0, 0, 400, 0)
		fields: fields
	})
	assert hidden.fields.len == 2
	if _ := hidden.field('f1') {
		assert false, 'hidden field laid out'
	}
	assert (hidden.field('f2') or { panic('missing') }).control == shown.fields[1].control
	assert hidden.height < shown.height
}

fn test_form_gaps_sizes_and_label_room() {
	base := FormConfig{
		id:     'form'
		frame:  rect(0, 0, 400, 0)
		fields: form_test_fields(2)
	}
	plain := form_layout_of(base)
	spaced := form_layout_of(FormConfig{
		...base
		row_gap: 40
	})
	gap := plain.fields[1].cell.y - form_bottom(plain.fields[0].cell)
	assert gap == 16
	assert spaced.fields[1].cell.y - form_bottom(spaced.fields[0].cell) == 40
	large := form_layout_of(FormConfig{
		...base
		size: .large
	})
	assert large.fields[0].control.height == component_metrics(.large).height
	assert large.fields[1].cell.y - form_bottom(large.fields[0].cell) > gap
	// Without a label and its room, the control starts at the top.
	bare := form_layout_of(FormConfig{
		...base
		fields: [
			FormField{
				id:           'terms'
				label_indent: false
				control:      form_box('c')
			},
			FormField{
				id:      'kept'
				control: form_box('d')
			},
		]
	})
	assert bare.fields[0].control.y == 0
	assert bare.fields[0].label == Rect{}
	assert bare.fields[1].control.y > bare.fields[1].cell.y
	tall := form_layout_of(FormConfig{
		...base
		fields: [FormField{
			id:     'bio'
			label:  'Bio'
			height: 96
		}]
	})
	assert tall.fields[0].control.height == 96
}

fn test_form_horizontal_alignment_indent_and_label_width() {
	base := FormConfig{
		id:           'form'
		frame:        rect(0, 0, 500, 0)
		label_layout: .horizontal
		label_width:  120
	}
	fields := [
		FormField{
			id:     'center'
			label:  'Center'
			height: 96
		},
		FormField{
			id:     'start'
			label:  'Start'
			height: 96
			align:  .start
		},
		FormField{
			id:     'end'
			label:  'End'
			height: 96
			align:  .end
		},
		FormField{
			id:           'flush'
			label_indent: false
		},
		FormField{
			id: 'indented'
		},
	]
	layout := form_layout_of(FormConfig{
		...base
		fields: fields
	})
	center := layout.field('center') or { panic('missing') }
	start := layout.field('start') or { panic('missing') }
	end := layout.field('end') or { panic('missing') }
	assert center.label.x == 0 && center.label.width == 120
	assert math.abs(center.label.y + center.label.height / 2 - (center.control.y + 48)) < 1e-9
	// Start and end put the label on the first and last line of the control.
	assert math.abs(start.label.y + start.label.height / 2 - (start.control.y + 16)) < 1e-9
	assert math.abs(end.label.y + end.label.height / 2 - (form_bottom(end.control) - 16)) < 1e-9
	flush := layout.field('flush') or { panic('missing') }
	indented := layout.field('indented') or { panic('missing') }
	assert flush.control.x == 0 && flush.control.width == 500
	assert indented.control.x == center.control.x
	// A label column wider than half the cell is narrowed to half of it.
	narrow := form_layout_of(FormConfig{
		...base
		frame:       rect(0, 0, 200, 0)
		label_width: 180
		fields:      [FormField{
			id:    'a'
			label: 'A'
		}]
	})
	assert narrow.fields[0].label.width == 100
	assert form_right(narrow.fields[0].control) == 200
}

fn test_form_descriptions_messages_and_reserved_lines() {
	base := FormConfig{
		id:    'form'
		frame: rect(0, 0, 320, 0)
	}
	plain := FormField{
		id:    'name'
		label: 'Name'
	}
	described := FormField{
		...plain
		description: 'Shown on your profile.'
	}
	long := FormField{
		...plain
		description: 'A description long enough that it has to wrap onto a second line in a narrow form like this one.'
	}
	failing := FormField{
		...described
		error: 'Name is required.'
	}
	none_ := form_layout_of(FormConfig{
		...base
		fields: [plain]
	}).fields[0]
	one := form_layout_of(FormConfig{
		...base
		fields: [described]
	}).fields[0]
	two := form_layout_of(FormConfig{
		...base
		fields: [long]
	}).fields[0]
	message := form_layout_of(FormConfig{
		...base
		fields: [failing]
	}).fields[0]
	reserved := form_layout_of(FormConfig{
		...base
		fields:               [plain]
		reserve_descriptions: true
	}).fields[0]
	assert none_.description == Rect{}
	assert one.description.y > form_bottom(one.control)
	assert one.description.x == one.control.x && one.description.width == one.control.width
	assert two.description.height >= 2 * one.description.height
	assert message.description.height == one.description.height
	assert reserved.description.height == one.description.height
	assert reserved.cell.height == one.cell.height
	// A custom description gets the height it asks for.
	custom := form_layout_of(FormConfig{
		...base
		fields: [
			FormField{
				...plain
				description_fn:     fn (frame Rect) !Element {
					return view('meter', frame, BoxStyle{}, []Element{})
				}
				description_height: 40
			},
		]
	}).fields[0]
	assert custom.description.height == 40
}

fn test_form_sections_span_the_grid_with_extra_space_above() {
	layout := form_layout_of(FormConfig{
		id:      'form'
		frame:   rect(0, 0, 600, 0)
		columns: 3
		fields:  [
			FormField{
				id:          'profile'
				kind:        .section
				label:       'Profile'
				description: 'How others see you.'
				col_span:    1
			},
			FormField{
				id: 'a'
			},
			FormField{
				id:    'prefs'
				kind:  .section
				label: 'Preferences'
			},
			FormField{
				id:   'rule'
				kind: .section
			},
		]
	})
	profile := layout.field('profile') or { panic('missing') }
	a := layout.field('a') or { panic('missing') }
	prefs := layout.field('prefs') or { panic('missing') }
	rule := layout.field('rule') or { panic('missing') }
	assert profile.row == 0 && profile.span == 3 && profile.cell.width == 600
	assert profile.description.y > form_bottom(profile.label)
	assert profile.control.height == 1 && profile.control.y > form_bottom(profile.description)
	assert a.row == 1
	// A later section gets the section gap on top of the row gap.
	assert prefs.cell.y - form_bottom(a.cell) == 32
	// A section without title or description is just the rule.
	assert rule.control == rect(0, rule.cell.y, 600, 1)
}

fn test_form_actions_follow_the_fields_and_align() {
	base := FormConfig{
		id:      'form'
		frame:   rect(0, 0, 400, 0)
		fields:  form_test_fields(1)
		actions: [
			FormAction{
				id:    'reset'
				label: 'Reset'
				kind:  .reset
			},
			FormAction{
				id:    'save'
				label: 'Save changes'
				kind:  .submit
			},
		]
	}
	end := form_layout_of(base)
	assert end.actions.len == 2
	assert math.abs(form_right(end.actions[1]) - 400) < 1e-9
	assert end.actions[0].x < end.actions[1].x
	assert end.actions[0].y > form_bottom(end.fields[0].cell)
	assert end.height == form_bottom(end.actions[0])
	start := form_layout_of(FormConfig{
		...base
		actions_align: .start
	})
	assert start.actions[0].x == 0
	stretch := form_layout_of(FormConfig{
		...base
		actions_align: .stretch
	})
	assert stretch.actions[0].x == 0 && math.abs(form_right(stretch.actions[1]) - 400) < 1e-9
	assert stretch.actions[0].width == stretch.actions[1].width
	center := form_layout_of(FormConfig{
		...base
		actions_align: .center
	})
	assert math.abs(center.actions[0].x - (400 - form_right(center.actions[1]))) < 1e-9
	// Buttons wider than the form shrink to fit it.
	cramped := form_layout_of(FormConfig{
		...base
		frame: rect(0, 0, 120, 0)
	})
	assert cramped.actions[0].x >= 0 && form_right(cramped.actions[1]) <= 120 + 1e-9
	// Without fields the actions start at the top; without actions nothing is added.
	alone := form_layout_of(FormConfig{
		...base
		fields: []
	})
	assert alone.actions[0].y == 0
	bare := form_layout_of(FormConfig{
		...base
		actions: []
	})
	assert bare.actions.len == 0
	assert bare.height == form_bottom(bare.fields[0].cell)
}

fn test_form_collapses_below_a_width() {
	assert form_responsive_columns(500, 3, 640) == 1
	assert form_responsive_columns(800, 3, 640) == 3
	assert form_responsive_columns(500, 3, 0) == 3
	assert form_responsive_columns(500, 0, 0) == 1
	config := FormConfig{
		id:             'form'
		frame:          rect(0, 0, 500, 0)
		columns:        2
		label_layout:   .horizontal
		collapse_below: 640
		fields:         [
			FormField{
				id:       'wide'
				col_span: 2
			},
			FormField{
				id:        'second'
				col_start: 2
			},
		]
	}
	narrow := form_layout_of(config)
	assert narrow.columns == 1 && narrow.vertical
	assert narrow.fields.map(it.span) == [1, 1]
	assert narrow.fields.map(it.column) == [0, 0]
	wide := form_layout_of(FormConfig{
		...config
		frame: rect(0, 0, 800, 0)
	})
	assert wide.columns == 2 && !wide.vertical
	assert wide.fields[1].column == 1
}

fn test_form_split_and_control_frames() {
	halves := form_split(rect(5, 5, 210, 32), [0.0, 0], 10)
	assert halves == [rect(0, 0, 100, 32), rect(110, 0, 100, 32)]
	mixed := form_split(rect(0, 0, 300, 32), [0.0, 100], 8)
	assert mixed == [rect(0, 0, 192, 32), rect(200, 0, 100, 32)]
	squeezed := form_split(rect(0, 0, 100, 20), [80.0, 80, 0], 0)
	assert squeezed[0].width == 50 && squeezed[1].width == 50 && squeezed[2].width == 0
	assert form_split(rect(0, 0, 10, 10), []f64{}, 4).len == 0
	config := FormConfig{
		id:     'form'
		frame:  rect(40, 60, 300, 0)
		fields: form_test_fields(2)
	}
	local := form_layout_of(config).fields[1].control
	assert form_control_frame(config, 'f1') or { panic('missing') } == rect(40 + local.x, 60 + local.y,
		local.width, local.height)
	if _ := form_control_frame(config, 'missing') {
		assert false, 'unknown field has a frame'
	}
}

fn test_form_rejects_invalid_configurations() {
	good := FormConfig{
		id:     'form'
		frame:  rect(0, 0, 100, 100)
		fields: form_test_fields(1)
	}
	form(good) or { panic(err) }
	bad := [
		FormConfig{
			...good
			id: ' '
		},
		FormConfig{
			...good
			frame: rect(0, 0, -1, 0)
		},
		FormConfig{
			...good
			columns: 0
		},
		FormConfig{
			...good
			columns: form_max_columns + 1
		},
		FormConfig{
			...good
			label_width: math.nan()
		},
		FormConfig{
			...good
			row_gap: math.inf(1)
		},
		FormConfig{
			...good
			fields: [FormField{
				id: ''
			}]
		},
		FormConfig{
			...good
			fields: [FormField{
				id: 'a'
			}, FormField{
				id: 'a'
			}]
		},
		FormConfig{
			...good
			fields: [FormField{
				id:       'a'
				col_span: 0
			}]
		},
		FormConfig{
			...good
			fields: [FormField{
				id:     'a'
				height: -4
			}]
		},
		FormConfig{
			...good
			actions: [FormAction{
				id: 'empty'
			}]
		},
		FormConfig{
			...good
			actions: [FormAction{
				id:   'icon'
				icon: 'checkmark'
			}]
		},
		FormConfig{
			...good
			actions: [FormAction{
				id:    'odd'
				label: 'Odd'
				icon:  'no.such.symbol'
			}]
		},
		FormConfig{
			...good
			actions: [FormAction{
				id:    'a'
				label: 'A'
			}, FormAction{
				id:    'a'
				label: 'B'
			}]
		},
	]
	for config in bad {
		if _ := form(config) {
			assert false, 'invalid form accepted: ${config.id} ${config.columns}'
		}
	}
}

// ── Building ────────────────────────────────────────────────────────

fn test_form_builds_labels_controls_and_messages() {
	config := FormConfig{
		id:     'signup'
		frame:  rect(10, 20, 300, 0)
		fields: [
			FormField{
				id:          'email'
				label:       'Email'
				required:    true
				description: 'We never share it.'
				control:     fn (frame Rect) !Element {
					return text_field('email-input', 'you@example.com', '', frame, BoxStyle{},
						TextStyle{}, 0)
				}
			},
			FormField{
				id:          'password'
				label:       'Password'
				description: 'At least 8 characters.'
				error:       'Password is too short.'
				control:     form_box('password-input')
			},
			FormField{
				id:    'plan'
				label: 'Plan'
				text:  'Pro'
			},
		]
	}
	el := form(config) or { panic(err) }
	layout := form_layout_of(config)
	assert el.id == 'signup'
	assert el.frame == rect(10, 20, 300, layout.height)
	assert el.accessibility_role == 'group'
	email := form_find(el, 'control:email') or { panic('missing') }
	assert email.id == 'email-input'
	assert email.kind == .text_field
	assert email.frame == (layout.field('email') or { panic('missing') }).control
	assert email.accessibility_label == 'Email'
	label_el := form_find(el, 'label:email') or { panic('missing') }
	assert label_el.text == 'Email'
	assert label_el.accessibility_label == 'Email, required'
	marker := form_find(el, 'required:email') or { panic('missing') }
	assert marker.text == '*'
	assert marker.text_style.color == config.theme.danger
	assert marker.frame.x > label_el.frame.x
	assert form_right(marker.frame) <= form_right(label_el.frame) + marker.frame.width + 3
	description := form_find(el, 'description:email') or { panic('missing') }
	assert description.text_style.color == config.theme.muted_foreground
	// Wrapped text is given the line count its row was sized for.
	assert description.text_style.lines == 1
	narrow := form(FormConfig{
		...config
		frame: rect(0, 0, 120, 0)
	}) or { panic(err) }
	wrapped := form_find(narrow, 'error:password') or { panic('missing') }
	wrapped_room := (form_layout_of(FormConfig{
		...config
		frame: rect(0, 0, 120, 0)
	}).field('password') or { panic('missing') }).description
	assert wrapped.text_style.lines >= 2
	assert wrapped.frame.y == wrapped_room.y && wrapped.frame.height >= wrapped_room.height
	// A message replaces the description, in the danger color with an icon.
	if _ := form_find(el, 'description:password') {
		assert false, 'description drawn under a message'
	}
	message := form_find(el, 'error:password') or { panic('missing') }
	assert message.text == 'Password is too short.'
	assert message.text_style.color == config.theme.danger
	icon := form_find(el, 'error-icon:password') or { panic('missing') }
	assert icon.image_path == 'symbol:exclamationmark.circle'
	assert symbol_known('exclamationmark.circle')
	assert icon.text_style.color == config.theme.danger
	value := form_find(el, 'control:plan') or { panic('missing') }
	assert value.kind == .label && value.text == 'Pro'
	// The view grows to its content, so every control stays inside it and can be clicked.
	tall := form(FormConfig{
		...config
		frame: rect(0, 0, 300, 900)
	}) or { panic(err) }
	assert tall.frame.height == 900
}

fn test_form_builds_sections_actions_and_skips_hidden_fields() {
	mut built := []string{}
	config := FormConfig{
		id:      'settings'
		frame:   rect(0, 0, 400, 0)
		fields:  [
			FormField{
				id:    'profile'
				kind:  .section
				label: 'Profile'
			},
			FormField{
				id:      'shown'
				label:   'Shown'
				control: form_box('shown-control')
			},
			FormField{
				id:      'hidden'
				label:   'Hidden'
				visible: false
				control: fn (frame Rect) !Element {
					return error('a hidden field must not be built')
				}
			},
		]
		actions: [
			FormAction{
				id:    'reset'
				label: 'Reset'
				kind:  .reset
			},
			FormAction{
				id:      'save'
				label:   'Save'
				kind:    .submit
				enabled: false
			},
			FormAction{
				id:      'delete'
				label:   'Delete'
				variant: .danger
			},
		]
	}
	el := form(config) or { panic(err) }
	for child in el.children {
		built << child.key
	}
	assert built == ['section:profile', 'rule:profile', 'label:shown', 'control:shown', 'action:reset',
		'action:save', 'action:delete']
	title := form_find(el, 'section:profile') or { panic('missing') }
	assert title.text_style.bold
	rule := form_find(el, 'rule:profile') or { panic('missing') }
	assert rule.box.bg == config.theme.border && rule.frame.height == 1
	save := form_find(el, 'action:save') or { panic('missing') }
	assert save.id == form_action_id('settings', 'save')
	assert !save.enabled
	reset := form_find(el, 'action:reset') or { panic('missing') }
	assert reset.id == form_action_id('settings', 'reset')
	// Submit buttons default to the primary variant, others to secondary.
	primary := button_variant_colors(config.theme, .primary, false, false, false)
	secondary := button_variant_colors(config.theme, .secondary, false, false, true)
	danger := button_variant_colors(config.theme, .danger, false, false, true)
	assert save.button_behavior && reset.button_behavior
	assert save.box.bg == primary.fill || save.children.any(it.box.bg == primary.fill)
	assert reset.box.bg == secondary.fill || reset.children.any(it.box.bg == secondary.fill)
	delete := form_find(el, 'action:delete') or { panic('missing') }
	assert delete.box.bg == danger.fill || delete.children.any(it.box.bg == danger.fill)
}

fn test_form_reports_control_errors_and_duplicate_ids() {
	if _ := form(FormConfig{
		id:     'form'
		fields: [
			FormField{
				id:      'broken'
				control: fn (frame Rect) !Element {
					return error('cannot build')
				}
			},
		]
	})
	{
		assert false, 'control error swallowed'
	} else {
		assert err.msg() == 'cannot build'
	}
	if _ := form(FormConfig{
		id:     'form'
		fields: [
			FormField{
				id:      'a'
				control: form_box('same')
			},
			FormField{
				id:      'b'
				control: form_box('same')
			},
		]
	}) {
		assert false, 'duplicate control ids accepted'
	}
}

fn test_form_custom_descriptions_and_horizontal_labels() {
	config := FormConfig{
		id:           'form'
		frame:        rect(0, 0, 420, 0)
		label_layout: .horizontal
		label_align:  .right
		label_width:  100
		fields:       [
			FormField{
				id:                 'bio'
				label:              'A very long label for a narrow column'
				required:           true
				description_fn:     fn (frame Rect) !Element {
					return label('count', '12 / 160', frame, TextStyle{})
				}
				description_height: 20
				control:            form_box('bio-input')
			},
		]
	}
	el := form(config) or { panic(err) }
	item := form_layout_of(config).fields[0]
	custom := form_find(el, 'description:bio') or { panic('missing') }
	assert custom.id == 'count'
	assert custom.frame == item.description && custom.frame.height == 20
	label_el := form_find(el, 'label:bio') or { panic('missing') }
	assert label_el.text_style.align == .right
	// A label that is cut short carries the whole text as a tooltip, and the
	// marker sits at the end of the label column.
	assert label_el.tooltip == 'A very long label for a narrow column'
	marker := form_find(el, 'required:bio') or { panic('missing') }
	inset := form_label_inset()
	assert form_right(marker.frame) <= form_right(item.label) + 1e-9
	assert marker.frame.x + inset >= form_right(label_el.frame) - inset
}

fn test_form_field_draws_one_field_in_its_own_frame() {
	el := form_field(
		id:    'standalone'
		frame: rect(20, 30, 260, 0)
		field: FormField{
			id:      'name'
			label:   'Name'
			control: form_box('name-input')
		}
	) or { panic(err) }
	assert el.id == 'standalone'
	assert el.accessibility_label == 'Name'
	control := form_find(el, 'control:name') or { panic('missing') }
	assert control.frame.x == 0 && control.frame.width == 260
	assert el.frame.height == form_bottom(control.frame)
}

// ── Events ──────────────────────────────────────────────────────────

fn test_form_event_decodes_actions_and_return() {
	config := FormConfig{
		id:      'signup'
		actions: [
			FormAction{
				id:    'cancel'
				label: 'Cancel'
			},
			FormAction{
				id:      'draft'
				label:   'Save draft'
				kind:    .submit
				enabled: false
			},
			FormAction{
				id:    'create'
				label: 'Create'
				kind:  .submit
			},
			FormAction{
				id:    'reset'
				label: 'Reset'
				kind:  .reset
			},
		]
	}
	cancel := form_event(config, form_action_id('signup', 'cancel')) or { panic('missing') }
	assert cancel.kind == .button && cancel.action == 'cancel'
	reset := form_event(config, form_action_id('signup', 'reset')) or { panic('missing') }
	assert reset.kind == .reset && reset.action == 'reset'
	create := form_event(config, form_action_id('signup', 'create')) or { panic('missing') }
	assert create.kind == .submit && create.action == 'create'
	// Return submits with the first enabled submit action.
	enter := form_event(config, form_submit_action('signup')) or { panic('missing') }
	assert enter.kind == .submit && enter.action == 'create'
	for action in [form_action_id('signup', 'draft'), form_action_id('other', 'create'),
		form_action_id('signup', 'missing'), 'signup:component:action:zz', 'signup:component:',
		'signup', '', form_submit_action('other')] {
		if _ := form_event(config, action) {
			assert false, 'accepted ${action}'
		}
	}
	// A form without submit actions still reports Return; one whose submit
	// actions are all disabled does not.
	open := form_event(FormConfig{
		id: 'search'
	}, form_submit_action('search')) or { panic('missing') }
	assert open.kind == .submit && open.action == ''
	if _ := form_event(FormConfig{
		id:      'locked'
		actions: [FormAction{
			id:      'go'
			label:   'Go'
			kind:    .submit
			enabled: false
		}]
	}, form_submit_action('locked')) {
		assert false, 'submitted with every submit action disabled'
	}
}

fn test_form_first_error_follows_field_order() {
	config := FormConfig{
		id:     'form'
		fields: [
			FormField{
				id: 'a'
			},
			FormField{
				id:      'b'
				error:   'B is wrong.'
				visible: false
			},
			FormField{
				id:    'c'
				error: 'C is wrong.'
			},
			FormField{
				id:    'd'
				error: 'D is wrong.'
			},
		]
	}
	assert form_first_error(config) or { '' } == 'c'
	if _ := form_first_error(FormConfig{
		id:     'form'
		fields: form_test_fields(2)
	})
	{
		assert false, 'valid form has an error'
	}
}

// ── Text estimates ──────────────────────────────────────────────────

fn test_form_text_width_tells_narrow_from_wide_letters() {
	assert form_text_width('', 14) == 0
	assert form_widths_system.len == 95 && form_widths_roboto.len == 95
	assert form_text_width('iiii', 14) < form_text_width('MMMM', 14)
	assert form_text_width('Email', 14) < component_text_width_estimate('Email', 14)
	assert math.abs(form_text_width('Email', 28) - 2 * form_text_width('Email', 14)) < 1e-9
	assert form_text_width('名字', 14) > form_text_width('ab', 14)
	assert form_text_lines('', 100, 12) == 0
	assert form_text_lines('Short', 400, 12) == 1
	assert form_text_lines('one\ntwo', 400, 12) == 2
	assert form_text_lines('word '.repeat(200), 100, 12) == form_max_description_lines
	assert form_text_lines('Anything', 0, 12) == 1
}

// ── Validation ──────────────────────────────────────────────────────

fn test_form_check_rules_and_default_messages() {
	assert form_check('', 'Email', [form_required()]) == 'Email is required.'
	assert form_check('   ', '', [form_required()]) == 'This field is required.'
	assert form_check('x', 'Email', [form_required()]) == ''
	// Blank values pass every rule but required.
	assert form_check('', 'Email', [form_email(), form_min_length(3)]) == ''
	assert form_check('ab', 'Password', [form_min_length(8)]) == 'Password must be at least 8 characters.'
	assert form_check('ab', 'Code', [form_min_length(1)]) == ''
	assert form_check('é', 'Code', [form_min_length(2)]) == 'Code must be at least 2 characters.'
	assert form_check('ééé', 'Code', [form_max_length(3)]) == ''
	assert form_check('abcd', 'Code', [form_max_length(1)]) == 'Code must be at most 1 character.'
	assert form_check('ada@', 'Email', [form_email()]) == 'Enter a valid email address.'
	assert form_check(' ada@example.com ', 'Email', [form_email()]) == ''
	assert form_check('12a', 'PIN', [form_digits()]) == 'PIN can only contain digits.'
	assert form_check('0123', 'PIN', [form_digits()]) == ''
	assert form_check('ab-1', 'Username', [form_alphanumeric()]) == 'Username can only contain letters and digits.'
	assert form_check('ab1', 'Username', [form_alphanumeric()]) == ''
	assert form_check('abc', 'Age', [form_number(none, none)]) == 'Age must be a number.'
	assert form_check('12', 'Age', [form_number(18, 120)]) == 'Age must be a number from 18 to 120.'
	assert form_check('12', 'Age', [form_number(18, none)]) == 'Age must be a number of at least 18.'
	assert form_check('2.5', 'Size', [form_number(none, 2)]) == 'Size must be a number of at most 2.'
	assert form_check('1.5', 'Size', [form_number(0.5, 2.5)]) == ''
	assert form_check('1234', 'ZIP', [form_pattern('#####')]) == 'ZIP is not in the expected format.'
	assert form_check('secret', 'Confirm password', [form_equals('secret!')]) == 'Confirm password does not match.'
	assert form_check('secret!', 'Confirm password', [form_equals('secret!')]) == ''
	// The first failing rule wins, and a rule can carry its own message.
	assert form_check('', 'Terms', [form_required().with_message('Accept the terms to continue.')]) == 'Accept the terms to continue.'
	assert form_check('a', 'Name', [form_min_length(2), form_digits()]) == 'Name must be at least 2 characters.'
}

fn test_form_validate_maps_fields_to_their_first_message() {
	errors := form_validate([
		FormValue{
			field: 'email'
			label: 'Email'
			value: ''
			rules: [form_required(), form_email()]
		},
		FormValue{
			field: 'email'
			label: 'Email'
			value: ''
			rules: [form_min_length(100).with_message('never shown')]
		},
		FormValue{
			field: 'name'
			label: 'Name'
			value: 'Ada'
			rules: [form_required()]
		},
		FormValue{
			field: 'confirm'
			label: 'Confirm password'
			value: 'a'
			rules: [form_equals('b')]
		},
	])
	assert errors == {
		'email':   'Email is required.'
		'confirm': 'Confirm password does not match.'
	}
	assert form_validate([]FormValue{}).len == 0
}

fn test_form_email_shapes() {
	for address in ['ada@example.com', 'ada.lovelace+notes@mail.example.co.uk', "o'brien@example.ie",
		'user_name@sub-domain.example.org', 'jürgen@münchen.de'] {
		assert form_email_valid(address), address
	}
	for address in ['', 'ada', 'ada@', '@example.com', 'ada@example', 'ada@@example.com',
		'a@b@example.com', '.ada@example.com', 'ada.@example.com', 'a..b@example.com',
		'ada lovelace@example.com', 'ada@exa mple.com', 'ada@-example.com', 'ada@example-.com',
		'ada@example..com', 'ada@example.c', 'ada@127.0.0.1', 'ada@example.com.', 'ada(x)@example.com',
		'a'.repeat(65) + '@example.com'] {
		assert !form_email_valid(address), address
	}
}

fn test_form_pattern_matching() {
	assert form_pattern_matches('12345', '#####')
	assert !form_pattern_matches('1234', '#####')
	assert !form_pattern_matches('123456', '#####')
	assert form_pattern_matches('12345-6789', '#####|#####-####')
	assert !form_pattern_matches('12345-678', '#####|#####-####')
	assert form_pattern_matches('K1A 0B1', 'A#A #A#')
	assert !form_pattern_matches('K1A0B1', 'A#A #A#')
	assert form_pattern_matches('ab12', '****')
	assert !form_pattern_matches('ab-2', '****')
	assert form_pattern_matches('x-é', '???')
	assert form_pattern_matches('#1', '\\##')
	assert !form_pattern_matches('11', '\\##')
	assert form_pattern_matches('a|b', 'A\\|A')
	assert form_pattern_matches('', '')
	assert !form_pattern_matches('a', '')
	assert form_pattern_matches('', '#|')
}
