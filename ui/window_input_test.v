@[has_globals]
module ui2

fn test_menu_bar_hidden_round_trips() {
	assert !menu_bar_hidden()
	set_menu_bar_hidden(true)
	assert menu_bar_hidden()
	set_menu_bar_hidden(false)
	assert !menu_bar_hidden()
}

fn test_key_event_is_not_a_repeat_unless_marked() {
	ev := KeyEvent{
		code: .a
	}
	assert !ev.repeat
	held := KeyEvent{
		code:   .a
		repeat: true
	}
	assert held.repeat
}
