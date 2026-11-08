module ui2

fn test_parse_pointer_event_reads_actions_with_colons() {
	event := parse_pointer_event('pointer:enter:card:component:trigger:12.5:-3') or { panic('none') }
	assert event.phase == 'enter'
	assert event.action == 'card:component:trigger'
	assert event.x == 12.5
	assert event.y == -3
	plain := parse_pointer_event('pointer:down:tile:1:2') or { panic('none') }
	assert plain.action == 'tile'
	for text in ['tile', 'pointer:', 'pointer:down', 'pointer:down:tile:1', 'pointer::tile:1:2',
		'pointer:down::1:2', 'pointer:down:tile:x:2', 'pointer:down:tile:1:y'] {
		assert (parse_pointer_event(text) or {
			PointerEvent{
				phase: 'none'
			}
		}).phase == 'none', text
	}
}

fn test_hover_transitions_follow_dom_order() {
	mut left, mut entered := hover_transitions([]string{}, ['list', 'row:2'])
	assert left.len == 0
	assert entered == ['list', 'row:2']
	left, entered = hover_transitions(['list', 'row:2'], ['list', 'row:3'])
	assert left == ['row:2']
	assert entered == ['row:3']
	left, entered = hover_transitions(['list', 'row:3', 'button'], []string{})
	assert left == ['button', 'row:3', 'list']
	assert entered.len == 0
	left, entered = hover_transitions(['a', 'b'], ['a', 'b'])
	assert left.len == 0 && entered.len == 0
}

fn test_with_hover_marks_only_hover() {
	el := with_hover(label('l', 'text', rect(0, 0, 10, 10), TextStyle{}))
	assert el.hoverable
	assert el.kind == .label
	assert el.text == 'text'
}
