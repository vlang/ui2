// vfmt off
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import time

	fn reset_tooltip_test() {
		g_tooltip = TooltipState{}
		g_tooltip_targets = []TooltipTarget{}
		g_tooltip_owners = 0
		g_touch = TouchState{}
		g_hit_targets = []HitTarget{}
		g_event_handler = EventFn(unsafe { nil })
		g_scroll_handler = ScrollFn(unsafe { nil })
		reset_scroll_frame()
		close_dropdown()
	}

	fn tooltip_target(key string, text string, x f64, y f64, w f64, h f64) TooltipTarget {
		return TooltipTarget{
			key: key
			text: text
			frame: rect(x, y, w, h)
		}
	}

	// Ten pixels a rune stands in for a font, as in the text area tests.
	fn tooltip_test_width(line string) f64 {
		return f64(line.runes().len) * 10
	}

	fn test_tooltip_target_at_prefers_what_was_drawn_last() {
		label := tooltip_target('label', 'A long label', 0, 0, 100, 20)
		button := tooltip_target('button', 'Save', 50, 0, 100, 20)
		targets := [label, button]
		assert tooltip_target_at(targets, 10, 10).key == 'label'
		assert tooltip_target_at(targets, 60, 10).key == 'button'
		assert tooltip_target_at(targets, 200, 10).text == ''
		// A surface drawn over both hides them, and has nothing to show itself.
		covered := [label, button, tooltip_target('', '', 40, 0, 30, 20)]
		assert tooltip_target_at(covered, 10, 10).key == 'label'
		assert tooltip_target_at(covered, 60, 10).text == ''
		assert tooltip_target_at(covered, 80, 10).key == 'button'
		// Neighbours sharing an edge do not both claim it.
		row := [tooltip_target('a', 'a', 0, 0, 50, 20), tooltip_target('b', 'b', 50, 0, 50, 20)]
		assert tooltip_target_at(row, 49.5, 10).key == 'a'
		assert tooltip_target_at(row, 50, 10).key == 'b'
		assert tooltip_target_at(row, 100, 10).text == ''
	}

	fn test_tooltip_opens_after_the_pointer_rests_and_stays_put() {
		mut state := TooltipState{}
		target := tooltip_target('button', 'Save the document', 0, 0, 100, 20)
		state.pointer_moved(10, 10, 1000)
		state.update(target, false, 1000)
		assert !state.visible
		state.update(target, false, 1499)
		assert !state.visible
		// Moving restarts the rest.
		state.pointer_moved(12, 11, 1400)
		state.update(target, false, 1899)
		assert !state.visible
		state.update(target, false, 1900)
		assert state.visible
		assert state.text == 'Save the document'
		assert state.anchor_x == 12 && state.anchor_y == 11
		// An open tooltip does not chase the pointer around its target.
		state.pointer_moved(80, 15, 2000)
		state.update(target, false, 2000)
		assert state.visible
		assert state.anchor_x == 12 && state.anchor_y == 11
		// Text that changes under an open tooltip is shown as it is now.
		state.update(TooltipTarget{
			...target
			text: 'Saved'
		}, false, 2100)
		assert state.visible
		assert state.text == 'Saved'
	}

	fn test_tooltip_closes_when_the_pointer_leaves_its_target() {
		mut state := TooltipState{}
		first := tooltip_target('first', 'First', 0, 0, 100, 20)
		second := tooltip_target('second', 'Second', 0, 20, 100, 20)
		state.pointer_moved(10, 10, 0)
		state.update(first, false, 0)
		state.update(first, false, 600)
		assert state.visible
		// Onto another target: the rest starts over there.
		state.pointer_moved(10, 30, 700)
		state.update(second, false, 700)
		assert !state.visible
		state.update(second, false, 1200)
		assert state.visible && state.text == 'Second'
		// Onto nothing.
		state.pointer_moved(10, 50, 1300)
		state.update(TooltipTarget{}, false, 1300)
		assert !state.visible
		state.update(TooltipTarget{}, false, 5000)
		assert !state.visible
		// Out of the window altogether.
		state.pointer_moved(10, 10, 6000)
		state.update(first, false, 6000)
		state.update(first, false, 6600)
		assert state.visible
		state.pointer_left()
		state.update(first, false, 7000)
		assert !state.visible
	}

	fn test_tooltip_closed_by_a_click_waits_for_another_target() {
		mut state := TooltipState{}
		first := tooltip_target('first', 'First', 0, 0, 100, 20)
		second := tooltip_target('second', 'Second', 0, 20, 100, 20)
		state.pointer_moved(10, 10, 0)
		state.update(first, false, 0)
		state.update(first, false, 600)
		assert state.visible
		state.dismiss()
		assert !state.visible
		state.update(first, false, 5000)
		assert !state.visible
		// Moving about on the same target does not bring it back.
		state.pointer_moved(20, 12, 5100)
		state.update(first, false, 9000)
		assert !state.visible
		// Another target has its own tooltip, and coming back reopens the first.
		state.pointer_moved(20, 30, 9100)
		state.update(second, false, 9100)
		state.update(second, false, 9600)
		assert state.visible && state.text == 'Second'
		state.pointer_moved(20, 10, 9700)
		state.update(first, false, 9700)
		state.update(first, false, 10200)
		assert state.visible && state.text == 'First'
		// Leaving the target and coming back also clears a dismissal.
		state.dismiss()
		state.pointer_moved(20, 200, 10300)
		state.update(TooltipTarget{}, false, 10300)
		state.pointer_moved(20, 10, 10400)
		state.update(first, false, 10400)
		state.update(first, false, 10900)
		assert state.visible
	}

	fn test_tooltip_waits_for_a_fresh_rest_after_blocking_and_scrolling() {
		mut state := TooltipState{}
		target := tooltip_target('button', 'Save', 0, 0, 100, 20)
		state.pointer_moved(10, 10, 0)
		state.update(target, false, 0)
		state.update(target, false, 600)
		assert state.visible
		state.update(target, true, 700)
		assert !state.visible
		state.update(target, true, 5000)
		assert !state.visible
		state.update(target, false, 5100)
		assert !state.visible
		state.update(target, false, 5500)
		assert state.visible
		state.restart(6000)
		assert !state.visible
		state.update(target, false, 6400)
		assert !state.visible
		state.update(target, false, 6500)
		assert state.visible
	}

	// The event handlers stamp moves with the real clock, so each new target is
	// settled at the current time before the rest is measured from it.
	fn settle_tooltip() {
		update_tooltip(time.ticks())
	}

	fn rest_tooltip() {
		update_tooltip(time.ticks() + tooltip_delay_ms)
	}

	fn test_tooltip_follows_window_events() {
		reset_tooltip_test()
		g_tooltip_targets = [tooltip_target('button', 'Save', 0, 0, 100, 20),
			tooltip_target('label', 'Full label text', 0, 40, 100, 20)]
		on_event(&gg.Event{typ: .mouse_move, mouse_x: 10, mouse_y: 10}, &GgApp{})
		settle_tooltip()
		assert !g_tooltip.visible
		rest_tooltip()
		assert g_tooltip.visible && g_tooltip.text == 'Save'
		// A key press closes it until the pointer moves to another target.
		on_event(&gg.Event{typ: .key_down, key_code: .a}, &GgApp{})
		assert !g_tooltip.visible
		update_tooltip(time.ticks() + 10 * tooltip_delay_ms)
		assert !g_tooltip.visible
		on_event(&gg.Event{typ: .mouse_move, mouse_x: 10, mouse_y: 50}, &GgApp{})
		settle_tooltip()
		rest_tooltip()
		assert g_tooltip.visible && g_tooltip.text == 'Full label text'
		// So does a press, and nothing opens while one is held.
		on_event(&gg.Event{typ: .mouse_down, mouse_x: 10, mouse_y: 50}, &GgApp{})
		assert !g_tooltip.visible && g_touch.down
		on_event(&gg.Event{typ: .mouse_move, mouse_x: 10, mouse_y: 10}, &GgApp{})
		settle_tooltip()
		assert !g_tooltip.visible
		on_event(&gg.Event{typ: .mouse_up, mouse_x: 10, mouse_y: 10}, &GgApp{})
		assert !g_touch.down
		rest_tooltip()
		assert g_tooltip.visible && g_tooltip.text == 'Save'
		// A scroll hides it until the pointer rests again.
		on_event(&gg.Event{typ: .mouse_scroll, mouse_x: 10, mouse_y: 10, scroll_y: 1}, &GgApp{})
		assert !g_tooltip.visible
		settle_tooltip()
		assert !g_tooltip.visible
		rest_tooltip()
		assert g_tooltip.visible
		// Leaving the window hides it.
		on_event(&gg.Event{typ: .mouse_leave}, &GgApp{})
		update_tooltip(time.ticks() + 10 * tooltip_delay_ms)
		assert !g_tooltip.visible
		reset_tooltip_test()
	}

	fn test_tooltip_is_held_back_while_a_dropdown_list_is_open() {
		reset_tooltip_test()
		g_tooltip_targets = [tooltip_target('button', 'Save', 0, 0, 100, 20)]
		mut clock := time.ticks()
		on_event(&gg.Event{typ: .mouse_move, mouse_x: 10, mouse_y: 10}, &GgApp{})
		g_open_dropdown = 'country'
		update_tooltip(clock)
		clock += 10 * tooltip_delay_ms
		update_tooltip(clock)
		assert !g_tooltip.visible
		// The rest only starts once the list has closed.
		close_dropdown()
		update_tooltip(clock)
		assert !g_tooltip.visible
		clock += tooltip_delay_ms
		update_tooltip(clock)
		assert g_tooltip.visible
		reset_tooltip_test()
	}

	fn test_tooltip_opens_below_right_of_the_pointer_inside_the_window() {
		window := rect(0, 0, 800, 600)
		assert tooltip_frame(100, 100, 120, 30, window) == rect(112, 120, 120, 30)
		// Pushed in from the right edge.
		assert tooltip_frame(750, 100, 120, 30, window) == rect(676, 120, 120, 30)
		// Opened above the pointer where there is no room below it.
		assert tooltip_frame(100, 580, 120, 30, window) == rect(112, 544, 120, 30)
		// A window too small either way still gets its corner of it.
		assert tooltip_frame(10, 10, 120, 30, rect(0, 0, 100, 40)) == rect(4, 4, 120, 30)
	}

	fn test_tooltip_text_wraps_to_a_readable_measure() {
		lines, width := tooltip_lines('Save', tooltip_test_width)
		assert lines == ['Save']
		assert width == 40
		// Explicit lines are kept, and a trailing newline does not add one.
		multi, multi_width := tooltip_lines('line one\nline two, longer\n', tooltip_test_width)
		assert multi == ['line one', 'line two, longer']
		assert multi_width == 160
		// Long text wraps at the measure: 36 runes of ten pixels.
		words := []string{len: 20, init: 'word${index:02}'}
		wrapped, wrapped_width := tooltip_lines(words.join(' '), tooltip_test_width)
		assert wrapped.len == 4
		assert wrapped[0] == 'word00 word01 word02 word03 word04'
		assert wrapped_width == 340
		// A word wider than the measure is left for the draw to shorten.
		_, long_width := tooltip_lines('x'.repeat(100), tooltip_test_width)
		assert long_width == tooltip_max_text_width
		// Very long text stops at the line cap.
		many := []string{len: 200, init: 'word${index:03}'}
		capped, _ := tooltip_lines(many.join(' '), tooltip_test_width)
		assert capped.len == tooltip_max_lines
	}

	fn test_tooltip_targets_cover_the_visible_part_of_an_element() {
		reset_tooltip_test()
		label := Element{
			kind: .label
			text: 'A label too long for its frame'
			frame: rect(10, 20, 100, 20)
		}
		area := rect(10, 20, 100, 20)
		clip := rect(0, 0, 60, 600)
		// Text that fit needs no tooltip.
		add_full_text_tooltip(label, area, clip, label.text, false)
		assert g_tooltip_targets.len == 0
		add_full_text_tooltip(label, area, clip, label.text, true)
		assert g_tooltip_targets.len == 1
		assert g_tooltip_targets[0].text == label.text
		assert g_tooltip_targets[0].frame == rect(10, 20, 50, 20)
		assert g_tooltip_targets[0].key == tooltip_key(label, area)
		// The declared tooltip, registered before the text is drawn, is kept.
		described := with_tooltip(label, 'Customer name')
		add_full_text_tooltip(described, area, clip, described.text, true)
		assert g_tooltip_targets.len == 1
		// Nothing is registered for an element scrolled out of its viewport.
		add_full_text_tooltip(label, area, rect(0, 100, 800, 500), label.text, true)
		assert g_tooltip_targets.len == 1
		reset_tooltip_test()
	}

	fn test_tooltip_keys_and_hiding_surfaces() {
		area := rect(10, 20, 100, 20)
		assert tooltip_key(Element{kind: .button, id: 'save'}, area) == 'button#save'
		assert tooltip_key(Element{kind: .button, id: 'save'}, rect(0, 0, 1, 1)) == 'button#save'
		assert tooltip_key(Element{kind: .label}, area) != tooltip_key(Element{kind: .label}, rect(10, 40, 100, 20))
		assert tooltip_hides_beneath(Element{kind: .view})
		assert !tooltip_hides_beneath(Element{kind: .view, box: BoxStyle{transparent: true}})
		assert tooltip_hides_beneath(Element{kind: .scroll})
		assert !tooltip_hides_beneath(Element{kind: .label})
	}
}
