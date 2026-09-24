module main

import ui2

@[heap]
struct StatusbarDemo {
mut:
	clicks int
}

const statusbar_demo_state = &StatusbarDemo{}

fn build_statusbar_demo(clicks int) ui2.Element {
	frame := ui2.bounds()
	message := if clicks == 0 { 'Ready' } else { 'Added one' }
	return ui2.screen(0xf8fafc, [
		ui2.label('heading', 'Reusable status bar', ui2.rect(20, 20, frame.width - 40, 28),
			ui2.TextStyle{
				size: 18
				bold: true
			}),
		ui2.button('increment', 'Add one', ui2.rect(20, 64, 120, 36), ui2.BoxStyle{
			bg:     0xe2e8f0
			radius: 5
		}, ui2.TextStyle{}),
		ui2.statusbar(
			message:    message
			indicators: [
				ui2.StatusIndicator{
					id:      'count'
					text:    '${clicks} clicks'
					tooltip: 'Total button presses'
				},
				ui2.StatusIndicator{
					id:        'reset'
					text:      'Reset'
					tooltip:   'Reset the count'
					action_id: 'reset'
				},
			]
		),
	])
}

fn build_statusbar_screen() ui2.Element {
	state := unsafe { statusbar_demo_state }
	return build_statusbar_demo(state.clicks)
}

fn handle_statusbar_event(id string) {
	mut state := unsafe { statusbar_demo_state }
	match id {
		'increment' { state.clicks++ }
		'reset' { state.clicks = 0 }
		else { return }
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('Status Bar', 480, 280, build_statusbar_screen, handle_statusbar_event)
}
