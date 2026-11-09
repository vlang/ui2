module main

import ui2

const safe_area_width = 420
const safe_area_height = 640

fn build_safe_area_screen() ui2.Element {
	frame := ui2.bounds()
	insets := ui2.safe_area_insets()
	headline := ui2.label('insets', 'top ${int(insets.top)} left ${int(insets.left)} bottom ${int(insets.bottom)} right ${int(insets.right)}',
		ui2.rect(0, 0, frame.width, 24), ui2.TextStyle{ size: 13 })
	mut rows := []ui2.Element{cap: 30}
	for i in 0 .. 30 {
		rows << ui2.label('row_${i}', 'row ${i}', ui2.rect(0, f64(i) * 32, frame.width,
			28), ui2.TextStyle{})
	}
	list := ui2.safe_viewport(
		id:       'rows'
		frame:    ui2.rect(0, 32, frame.width, frame.height - 32)
		minimum:  ui2.LayoutPadding{
			left:   16
			right:  16
			bottom: 16
		}
		children: rows
	) or { return ui2.screen(0xffffff, []) }
	content := ui2.safe_area(
		id:       'safe'
		frame:    frame
		children: [headline, list]
	) or { return ui2.screen(0xffffff, []) }
	return ui2.screen(0xffffff, [content])
}

fn handle_safe_area_event(_ string) {}

fn main() {
	ui2.run_window('Safe Area', safe_area_width, safe_area_height, build_safe_area_screen,
		handle_safe_area_event)
}
