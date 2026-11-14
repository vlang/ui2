module ui2

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
	el := component_assemble(rect(0, 0, 100, 80), BoxStyle{ bg: 0xffffff }, ComponentParts{
		leading: [label('l', 'L', rect(0, 0, 20, 20), TextStyle{})]
		body:    [label('b', 'B', rect(0, 0, 60, 20), TextStyle{})]
	}) or { panic(err) }
	assert el.children.len == 2
	assert el.children[0].id == 'l'
	assert el.children[1].id == 'b'
}

fn test_component_slot_reports_populated_parts() {
	parts := ComponentParts{ trailing: [label('t', 'T', rect(0, 0, 10, 10), TextStyle{})] }
	assert component_slot(parts, 'trailing')
	assert !component_slot(parts, 'leading')
	assert !component_slot(parts, 'nope')
}

fn test_composable_button_renders_caption_when_no_children() {
	el := composable_button('btn', rect(0, 0, 120, 40), ComponentVariant{ name: 'default' }, .medium, [], 'Save', TextStyle{ color: 0x111111 }) or { panic(err) }
	assert el.kind == .button
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
	assert el.children.len == 2
	assert el.children[0].id == 'body'
	assert el.children[1].id == 'foot'
}

fn test_composable_input_places_leading_and_trailing_slots() {
	leading := label('search', 'Q', rect(0, 0, 16, 16), TextStyle{})
	trailing := label('clear', '×', rect(0, 0, 16, 16), TextStyle{})
	el := composable_input('q', rect(0, 0, 200, 32), ComponentVariant{ name: 'outline' }, leading, trailing, 'Search', '', TextStyle{}) or { panic(err) }
	assert el.children.len == 3
	assert el.children[0].id == 'search'
	assert el.children[2].id == 'clear'
}

fn test_component_variant_presets_cover_shadcn_families() {
	presets := component_variant_presets()
	for name in ['default', 'secondary', 'destructive', 'outline', 'ghost', 'link'] {
		assert name in presets
	}
	assert presets['destructive'].box.bg == 0xb91c1c
	assert presets['link'].text.underline
}
