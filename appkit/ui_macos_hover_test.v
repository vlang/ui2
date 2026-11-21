// vfmt off
module ui2

$if !ui2_custom_rendering ? {

import macos

fn test_macos_shortened_text_shows_whole_text_on_hover() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	long_title := 'Restart numbering from the beginning of this list'
	narrow := button('hover-narrow', long_title, rect(0, 0, 60, 24), BoxStyle{}, TextStyle{
		size: 12
	})
	narrow_view := native_create_element(narrow)
	defer {
		macos.release(narrow_view)
	}
	assert native_hover_text('narrow', narrow_view, narrow) == long_title

	wide := button('hover-wide', 'Bold', rect(0, 0, 200, 24), BoxStyle{}, TextStyle{
		size: 12
	})
	wide_view := native_create_element(wide)
	defer {
		macos.release(wide_view)
	}
	assert native_hover_text('wide', wide_view, wide) == ''

	// A title that only just fits is measured rather than waved through, and is not
	// given the tooltip meant for text that was cut short.
	snug := button('hover-snug', 'Heading 1', rect(0, 0, 76, 24), BoxStyle{}, TextStyle{
		size: 12
	})
	snug_view := native_create_element(snug)
	defer {
		macos.release(snug_view)
	}
	assert !text_surely_fits(snug.text, snug)
	assert native_hover_text('snug', snug_view, snug) == ''

	label_el := label('hover-label', long_title, rect(0, 0, 80, 18), TextStyle{
		size: 12
	})
	label_view := native_create_element(label_el)
	defer {
		macos.release(label_view)
	}
	assert native_hover_text('label', label_view, label_el) == long_title

	// Help the caller gave wins over the text it would otherwise repeat.
	helped := with_tooltip(narrow, 'Restart numbering')
	assert native_hover_text('narrow', narrow_view, helped) == 'Restart numbering'

	options := ['Calibri (Body) and a long family name', 'Arial']
	dropdown_el := dropdown('hover-dropdown', options[0], options, rect(0, 0, 90, 24),
		BoxStyle{}, TextStyle{
		size: 12
	})
	dropdown_view := native_create_element(dropdown_el)
	defer {
		macos.release(dropdown_view)
	}
	assert native_hover_text('dropdown', dropdown_view, dropdown_el) == options[0]
}

fn test_macos_composite_button_uses_pointer_view_and_passive_child_classes() {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	ensure_runtime_classes()
	el := button_view('save_card', rect(0, 0, 160, 48), BoxStyle{}, [
		label('save_card_label', 'Save changes', rect(12, 12, 136, 24), TextStyle{}),
	])
	native := native_create_element(el)
	label_native := native_create_element(el.children[0])
	decorative_native := native_create_element(view('decoration', rect(0, 0, 20, 20),
		BoxStyle{}, []Element{}))
	defer {
		macos.release(native)
		macos.release(label_native)
		macos.release(decorative_native)
	}

	assert macos.msg_bool_id(native, 'isKindOfClass:', macos.get_class('UI2PointerView'))
	assert macos.msg_bool_id(label_native, 'isKindOfClass:', macos.get_class('UI2PointerLabel'))
	assert macos.msg_bool_id(decorative_native, 'isKindOfClass:',
		macos.get_class('UI2PointerChildView'))
	assert macos.responds_to(native, 'accessibilityPerformPress')
	register_pointer(native, el)
	pointer := u64(voidptr(native))
	mut st := state()
	assert (st.pointer_buttons[pointer] or { false })
	assert (st.pointer_ids[pointer] or { '' }) == 'save_card'

	disabled := Element{
		...el
		enabled: false
	}
	register_pointer(native, disabled)
	assert pointer !in st.pointer_buttons
	assert pointer !in st.pointer_ids
}
}
