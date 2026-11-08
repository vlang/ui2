module main

import ui2

const menus_source = $embed_file('menus.vml').to_string()

fn build() ui2.Element {
	return ui2.screen(0xffffff, [
		ui2.label('hint', 'Choose a menu item; its action id is printed to the terminal.',
			ui2.rect(20, 20, 460, 80), ui2.TextStyle{
				size: 15
			}),
	])
}

fn on_event(id string) {
	println('Menu action: ${id}')
}

fn main() {
	menus := ui2.menu_bar_from_vml(menus_source) or { panic(err) }
	ui2.set_menu_bar(menus)
	ui2.run_window('VML menus', 500, 180, build, on_event)
}
