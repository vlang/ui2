// vfmt off
@[has_globals]
module ui2

// Every backend reports hover changes through hover_transitions, so this part
// runs natively too (and keeps the file from being empty there).
fn test_hover_transitions_report_nothing_for_an_unchanged_chain() {
	left, entered := hover_transitions(['list', 'row:1'], ['list', 'row:1'])
	assert left.len == 0 && entered.len == 0
}

$if (android || linux || freebsd || openbsd || netbsd || dragonfly || solaris || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	struct HoverLog {
	mut:
		events []string
	}

	fn hover_test_setup(mut log HoverLog) {
		// A list with two rows, each row with a button, and a popover drawn last
		// over the second row's button.
		g_hover_regions = [
			HoverRegion{ area: rect(0, 0, 400, 300), chain: []string{} },
			HoverRegion{ area: rect(10, 10, 200, 200), chain: ['list'] },
			HoverRegion{ area: rect(10, 10, 200, 40), chain: ['list', 'row:1'] },
			HoverRegion{ area: rect(150, 15, 50, 30), chain: ['list', 'row:1', 'more:1'] },
			HoverRegion{ area: rect(10, 50, 200, 40), chain: ['list', 'row:2'] },
			HoverRegion{ area: rect(140, 50, 120, 60), chain: []string{} },
		]
		g_hovered = []string{}
		g_hover_pointer = HoverPointer{}
		g_event_handler = fn [mut log] (event string) {
			log.events << event
		}
	}

	fn hover_test_move(x f64, y f64) {
		g_hover_pointer = HoverPointer{ x: x, y: y, inside: true }
		update_hover()
	}

	fn test_hover_reports_enter_and_leave_like_css_hover() {
		mut log := &HoverLog{}
		hover_test_setup(mut log)
		hover_test_move(20, 20)
		assert log.events == ['pointer:enter:list:20.0:20.0', 'pointer:enter:row:1:20.0:20.0']
		log.events.clear()
		// Onto the row's own button: its ancestors stay hovered.
		hover_test_move(160, 20)
		assert log.events == ['pointer:enter:more:1:160.0:20.0']
		log.events.clear()
		hover_test_move(20, 60)
		assert log.events == ['pointer:leave:more:1:20.0:60.0', 'pointer:leave:row:1:20.0:60.0',
			'pointer:enter:row:2:20.0:60.0']
		log.events.clear()
		// The popover covers the row there, so nothing hoverable is hovered.
		hover_test_move(180, 60)
		assert log.events == ['pointer:leave:row:2:180.0:60.0', 'pointer:leave:list:180.0:60.0']
		log.events.clear()
		hover_test_move(20, 60)
		g_hover_pointer.inside = false
		update_hover()
		assert log.events == ['pointer:enter:list:20.0:60.0', 'pointer:enter:row:2:20.0:60.0',
			'pointer:leave:row:2:20.0:60.0', 'pointer:leave:list:20.0:60.0']
		g_event_handler = EventFn(unsafe { nil })
	}

	fn test_hover_regions_are_clipped_to_what_is_visible() {
		g_hover_regions = []HoverRegion{}
		g_hover_chain = ['scroll']
		add_hover_region(rect(0, 0, 100, 100), rect(0, 50, 100, 50))
		add_hover_region(rect(0, 0, 100, 10), rect(0, 50, 100, 50))
		assert g_hover_regions.len == 1
		assert g_hover_regions[0].area == rect(0, 50, 100, 50)
		assert hovered_chain_at(10, 10).len == 0
		assert hovered_chain_at(10, 60) == ['scroll']
		g_hover_chain = []string{}
	}
}
