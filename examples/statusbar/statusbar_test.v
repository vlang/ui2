module main

import ui2

fn test_statusbar_example_updates_message_and_indicator() {
	initial := build_statusbar_demo(0)
	assert initial.children[2].frame == ui2.rect(0, ui2.bounds().height - ui2.statusbar_height,
		ui2.bounds().width, ui2.statusbar_height)
	assert initial.children[2].children[0].text == 'Ready'
	assert initial.children[2].children[1].children[0].text == '0 clicks'
	assert initial.children[2].children[2].children[0].kind == .button
	assert initial.children[2].children[2].children[0].action_id == 'reset'

	updated := build_statusbar_demo(3)
	assert updated.children[2].children[0].text == 'Added one'
	assert updated.children[2].children[1].children[0].text == '3 clicks'
}
