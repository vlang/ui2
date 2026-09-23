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
}
