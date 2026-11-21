module ui2

import math

fn test_component_variant_fills_missing_fields_from_base() {
	base_box := BoxStyle{ bg: 0x123456, radius: 8 }
	base_text := TextStyle{ color: 0xabcdef, size: 14, lines: 0 }
	variant := ComponentVariant{ name: 'accent', box: BoxStyle{ bg: 0xff0000 } }
	box, text := component_variant(base_box, base_text, variant)
	assert box.bg == 0xff0000
	assert box.radius == 8
	// A variant that only spells out box fields keeps the base text: the
	// TextStyle defaults (0x111111/15.0) count as unset, not as overrides.
	assert text.color == 0xabcdef
	assert text.size == 14
	assert text.lines == 0
}

fn test_component_variant_explicit_text_overrides_base() {
	base_box := BoxStyle{ bg: 0x123456, radius: 8 }
	base_text := TextStyle{ color: 0xabcdef, size: 14 }
	variant := ComponentVariant{
		name: 'accent'
		text: TextStyle{ color: 0xffffff, size: 18 }
	}
	_, text := component_variant(base_box, base_text, variant)
	assert text.color == 0xffffff
	assert text.size == 18
}

fn test_component_variant_default_bg_keeps_base() {
	base_box := BoxStyle{ bg: 0x123456, radius: 8 }
	base_text := TextStyle{ color: 0xabcdef, size: 14 }
	// BoxStyle{}.bg (white) is the unset sentinel: a variant that does not
	// name a bg must not whitewash a colored base.
	variant := ComponentVariant{ name: 'ghost', box: BoxStyle{ transparent: true } }
	box, text := component_variant(base_box, base_text, variant)
	assert box.bg == 0x123456
	assert box.transparent == true
	assert text.color == 0xabcdef
	assert text.size == 14
}

fn test_component_variant_caller_size_survives_preset() {
	base_text := TextStyle{ color: 0xffffff, size: 18 }
	presets := component_variant_presets()
	_, style := component_variant(BoxStyle{ bg: 0xffffff, radius: 6 }, base_text, presets['destructive'])
	assert style.color == 0xffffff
	assert style.size == 18
}

fn test_component_variants_find_matches_by_name_and_defaults_to_first() {
	variants := [
		ComponentVariant{ name: 'default', box: BoxStyle{ bg: 0x111111 } },
		ComponentVariant{ name: 'destructive', box: BoxStyle{ bg: 0xff0000 } },
	]
	assert component_variants_find(variants, 'destructive').box.bg == 0xff0000
	assert component_variants_find(variants, 'DESTRUCTIVE').box.bg == 0xff0000
	assert component_variants_find(variants, 'missing').box.bg == 0x111111
	assert component_variants_find([], 'anything').name == ''
}

fn test_component_assemble_combines_parts_in_order() {
	el := component_assemble('assembled', rect(0, 0, 100, 80), BoxStyle{ bg: 0xffffff }, ComponentParts{
		leading: [label('l', 'L', rect(0, 0, 20, 20), TextStyle{})]
		body:    [label('b', 'B', rect(0, 0, 60, 20), TextStyle{})]
	}) or { panic(err) }
	assert el.id == 'assembled'
	assert el.children.len == 2
	assert el.children[0].id == 'l'
	assert el.children[1].id == 'b'
}

fn test_component_assemble_rejects_id_collision_with_slot() {
	component_assemble('l', rect(0, 0, 100, 80), BoxStyle{ bg: 0xffffff }, ComponentParts{
		leading: [label('l', 'L', rect(0, 0, 20, 20), TextStyle{})]
	}) or {
		assert err.msg().contains('duplicate element id')
		return
	}
	assert false, 'duplicate root/slot id accepted'
}

fn test_component_slot_reports_populated_parts() {
	parts := ComponentParts{ trailing: [label('t', 'T', rect(0, 0, 10, 10), TextStyle{})] }
	assert component_slot(parts, 'trailing')
	assert !component_slot(parts, 'leading')
	assert !component_slot(parts, 'nope')
}

fn test_composable_button_renders_caption_when_no_children() {
	el := composable_button('btn', rect(0, 0, 120, 40), ComponentVariant{ name: 'default' }, .medium, [], 'Save', TextStyle{ color: 0x111111 }) or { panic(err) }
	assert el.kind == .view
	assert el.button_behavior
	assert el.accessibility_role == 'button'
	assert el.id == 'btn'
	assert el.text == 'Save'
	assert el.children.len == 1
	assert el.children[0].id == 'btn_label'
}

fn test_composable_button_keeps_supplied_children() {
	child := label('icon', '★', rect(0, 0, 16, 16), TextStyle{})
	el := composable_button('btn', rect(0, 0, 120, 40), ComponentVariant{ name: 'default' }, .medium, [child], '', TextStyle{}) or { panic(err) }
	assert el.children.len == 1
	assert el.children[0].id == 'icon'
}

fn test_composable_card_assembles_header_and_footer() {
	el := composable_card('card', rect(0, 0, 200, 120), ComponentVariant{ name: 'default' }, ComponentParts{
		body:   [label('body', 'Body', rect(0, 0, 180, 20), TextStyle{})]
		footer: [label('foot', 'Foot', rect(0, 0, 180, 20), TextStyle{})]
	}) or { panic(err) }
	assert el.id == 'card'
	assert el.children.len == 2
	assert el.children[0].id == 'body'
	assert el.children[1].id == 'foot'
}

fn test_composable_input_places_leading_and_trailing_slots() {
	leading := label('search', 'Q', rect(0, 8, 16, 16), TextStyle{})
	trailing := label('clear', '×', rect(184, 8, 16, 16), TextStyle{})
	el := composable_input('q', rect(0, 0, 200, 32), ComponentVariant{ name: 'outline' }, leading, trailing, 'Search', '', TextStyle{}) or { panic(err) }
	assert el.id == 'q'
	assert el.children.len == 3
	assert el.children[0].id == 'search'
	assert el.children[1].id == 'q_field'
	assert el.children[2].id == 'clear'
	field := el.children[1].frame
	assert field.x >= leading.frame.x + leading.frame.width
	assert field.x + field.width <= trailing.frame.x
}

fn test_component_variant_presets_cover_shadcn_families() {
	presets := component_variant_presets()
	for name in ['default', 'secondary', 'destructive', 'outline', 'ghost', 'link'] {
		assert name in presets
	}
	assert presets['destructive'].box.bg == 0xb91c1c
	assert presets['link'].text.underline
}

fn test_component_variant_explicit_fields_clear_previous_styles() {
	base_box := BoxStyle{
		bg:            0x123456
		radius:        8
		transparent:   true
		border_color:  0xabcdef
		border_left:   2
		border_top:    2
		border_right:  2
		border_bottom: 2
		opacity:       0.5
		gradient:      linear_gradient(0, gradient_stop(0xff0000, 0), gradient_stop(0x0000ff, 1))
		shadow:        box_shadow(0x000000, 0.2, 8, 2)
	}
	base_text := TextStyle{
		color:              0xffffff
		background_color:   0x112233
		size:               24
		font_family:        'Custom'
		bold:               true
		italic:             true
		underline:          true
		strikethrough:      true
		shadow:             true
		outline:            true
		vertical_align:     'superscript'
		link:               'https://vlang.io'
		align:              .right
		valign:             .bottom
		head_indent:        12
		first_line_indent:  8
		hyphenation_factor: 0.8
		lines:              3
	}
	variant := ComponentVariant{
		box:         BoxStyle{ bg: 0, opacity: 0 }
		text:        TextStyle{ color: 0, lines: 0 }
		box_fields:  [.bg, .radius, .transparent, .border_color, .border_left, .border_top,
			.border_right, .border_bottom, .opacity, .gradient, .shadow]
		text_fields: [.color, .background_color, .size, .font_family, .bold, .italic, .underline,
			.strikethrough, .shadow, .outline, .vertical_align, .link, .align, .valign, .head_indent,
			.first_line_indent, .hyphenation_factor, .lines]
	}
	box, text := component_variant(base_box, base_text, variant)
	assert box == BoxStyle{ bg: 0, opacity: 0 }
	assert text == TextStyle{ color: 0, lines: 0 }
	// Explicit defaults also restore a white, opaque surface and one line.
	restored_box, restored_text := component_variant(box, text, ComponentVariant{
		box_fields:  [.bg, .opacity]
		text_fields: [.color, .lines]
	})
	assert restored_box.bg == 0xffffff
	assert restored_box.opacity == 1
	assert restored_text.color == 0x111111
	assert restored_text.lines == 1
}

fn test_component_variant_presets_restore_default_colors_and_link_radius() {
	presets := component_variant_presets()
	box, text := component_variant(BoxStyle{ bg: 0x123456, transparent: true, radius: 10 },
		TextStyle{ color: 0xffffff, size: 18 }, presets['default'])
	assert box.bg == 0xffffff
	assert !box.transparent
	assert text.color == 0x111111
	assert text.size == 18
	link_box, _ := component_variant(box, text, presets['link'])
	assert link_box.transparent
	assert link_box.radius == 0
}

fn test_composable_button_size_controls_default_caption_and_keeps_custom_size() {
	small := composable_button('small', rect(0, 0, 100, 24), ComponentVariant{}, .small,
		[], 'Small', TextStyle{}) or { panic(err) }
	large := composable_button('large', rect(0, 0, 100, 40), ComponentVariant{}, .large,
		[], 'Large', TextStyle{}) or { panic(err) }
	custom := composable_button('custom', rect(0, 0, 100, 40), ComponentVariant{}, .large,
		[], 'Custom', TextStyle{ size: 18 }) or { panic(err) }
	assert small.children[0].text_style.size == 12
	assert large.children[0].text_style.size == 16
	assert custom.children[0].text_style.size == 18
}

fn test_composable_interactive_recipes_reject_empty_identity() {
	if _ := composable_button(' ', rect(0, 0, 100, 40), ComponentVariant{}, .medium,
		[], 'Save', TextStyle{}) {
		assert false, 'button with no action identity accepted'
	}
	if _ := composable_input('', rect(0, 0, 100, 32), ComponentVariant{}, none, none,
		'Value', '', TextStyle{}) {
		assert false, 'input with a shared anonymous field identity accepted'
	}
}

fn test_composable_input_clamps_slots_to_local_bounds() {
	for x in [-50.0, 50.0, 150.0] {
		trailing := label('trailing', 'X', rect(x, 0, 20, 32), TextStyle{})
		el := composable_input('entry', rect(10, 20, 100, 32), ComponentVariant{}, none,
			trailing, 'Value', '', TextStyle{}) or { panic(err) }
		field := el.children[0]
		assert field.id == composable_input_field_id('entry')
		assert field.frame.x >= 0
		assert field.frame.width >= 0
		assert field.frame.x + field.frame.width <= 100
	}
	leading := label('leading', 'Q', rect(80, 0, 40, 32), TextStyle{})
	trailing := label('trailing', 'X', rect(70, 0, 20, 32), TextStyle{})
	crowded := composable_input('entry', rect(0, 0, 100, 32), ComponentVariant{},
		leading, trailing, '', '', TextStyle{}) or { panic(err) }
	assert crowded.children[1].frame == rect(70, 0, 0, 32)
}

fn test_composable_input_hidden_slots_do_not_reserve_space() {
	leading := Element{
		...label('hidden', 'Q', rect(0, 0, 80, 32), TextStyle{})
		hidden: true
	}
	el := composable_input('entry', rect(0, 0, 100, 32), ComponentVariant{}, leading, none,
		'Value', '', TextStyle{}) or { panic(err) }
	assert el.children[1].frame == rect(0, 0, 100, 32)
}

fn test_composable_input_rejects_invalid_slot_geometry() {
	for frame in [rect(math.nan(), 0, 20, 32), rect(0, 0, -1, 32)] {
		if _ := composable_input('entry', rect(0, 0, 100, 32), ComponentVariant{},
			none, label('invalid', 'X', frame, TextStyle{}), '', '', TextStyle{}) {
			assert false, 'invalid slot frame accepted'
		}
	}
}
