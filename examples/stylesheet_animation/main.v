module main

import ui2

const demo_width = 420
const demo_height = 320

const demo_sheet = '
@accent: #2563eb;

@keyframes pulse {
	from { opacity: 1; }
	50%  { opacity: 0.4; }
	to   { opacity: 1; }
}

Button {
	background: @accent;
	color: white;
	border-radius: 8px;
	transition: background 0.2s ease, opacity 0.15s;
}
Button:hover { background: #1d4ed8; opacity: 0.9; }
Button.loading { animation: pulse 1s ease-in-out infinite; }
'

fn build() ui2.Element {
	mut loading := false
	_ = loading
	btn := ui2.button('pulse', 'Pulse (hover me)', ui2.rect(40, 60, 200, 44), ui2.BoxStyle{}, ui2.TextStyle{})
	return ui2.view('root', ui2.rect(0, 0, demo_width, demo_height), ui2.BoxStyle{bg: 0xf1f5f9}, [btn])
}

fn main() {
	ui2.set_global_stylesheet(ui2.parse_stylesheet(demo_sheet) or { panic(err) })
	ui2.run_window('VSS animations', demo_width, demo_height, build, handle_event)
}

fn handle_event(_ string) {}
