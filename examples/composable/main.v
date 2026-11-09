module main

import ui2

const composable_width = 420
const composable_height = 360

fn build_composable_screen() ui2.Element {
	frame := ui2.bounds()
	width := frame.width - 32
	presets := ui2.component_variant_presets()
	return ui2.screen(0xf1f5f9, [
		ui2.composable_button('save', ui2.rect(16, 16, width, 44), presets['default'], .medium, [], 'Save', ui2.TextStyle{ color: 0x111111 }) or { return ui2.screen(0xf1f5f9, []) },
		ui2.composable_button('delete', ui2.rect(16, 68, width, 44), presets['destructive'], .medium, [], 'Delete', ui2.TextStyle{ color: 0xffffff }) or { return ui2.screen(0xf1f5f9, []) },
		ui2.composable_button('ghost', ui2.rect(16, 120, width, 44), presets['ghost'], .medium, [], 'Ghost', ui2.TextStyle{ color: 0x111111 }) or { return ui2.screen(0xf1f5f9, []) },
		ui2.composable_card('card', ui2.rect(16, 172, width, 120), presets['default'], ui2.ComponentParts{
			body:   [ui2.label('body', 'Card body', ui2.rect(0, 0, width - 32, 24), ui2.TextStyle{})]
			footer: [ui2.label('foot', 'Footer', ui2.rect(0, 0, width - 32, 20), ui2.TextStyle{ color: 0x64748b })]
		}) or { return ui2.screen(0xf1f5f9, []) },
	])
}

fn handle_composable_event(_ string) {}

fn main() {
	ui2.run_window('Composable', composable_width, composable_height, build_composable_screen,
		handle_composable_event)
}
