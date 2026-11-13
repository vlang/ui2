module main

import ui2

const scaffold_width = 420
const scaffold_height = 640

fn build_scaffold_screen() ui2.Element {
	frame := ui2.bounds()
	title := ui2.label('title', 'Scaffold', ui2.rect(16, 0, 200, 56), ui2.TextStyle{
		size: 20
		bold: true
	})
	body := ui2.label('body', 'Content avoids both bars.', ui2.rect(16, 16, 300, 24),
		ui2.TextStyle{})
	nav := ui2.label('nav', 'Bottom bar', ui2.rect(16, 0, 200, 64), ui2.TextStyle{
		valign: .middle
	})
	fab := ui2.button('add', '+', ui2.rect(0, 0, 56, 56), ui2.BoxStyle{
		bg:     0x2563eb
		radius: 28
	}, ui2.TextStyle{
		color: 0xffffff
		size:  24
		align: .center
	})
	snack := ui2.label('snack', 'Saved', ui2.rect(0, 0, 120, 40), ui2.TextStyle{
		color: 0xffffff
		align: .center
	})
	snack_bar := ui2.view('snack_bar', snack.frame, ui2.BoxStyle{
		bg:     0x172033
		radius: 8
	}, [ui2.Element{
		...snack
		frame: ui2.rect(0, 0, 120, 40)
	}])
	content := ui2.scaffold(
		id:                'app'
		frame:             frame
		top_bar_height:    56
		bottom_bar_height: 64
		top_bar:           [title]
		content:           [body]
		bottom_bar:        [nav]
		floating_action:   fab
		snackbar:          snack_bar
	) or { return ui2.screen(0xf1f5f9, []) }
	return ui2.screen(0xf1f5f9, [content])
}

fn handle_scaffold_event(_ string) {}

fn main() {
	ui2.run_window('Scaffold', scaffold_width, scaffold_height, build_scaffold_screen,
		handle_scaffold_event)
}
