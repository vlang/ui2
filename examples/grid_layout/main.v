module main

import ui2

const grid_width = 360
const grid_height = 260

fn grid_tree(frame ui2.Rect) !ui2.Element {
	captions := ['Overview', 'Activity', 'Messages', 'Files', 'Calendar', 'Settings']
	colors := [u32(0xdbeafe), u32(0xdcfce7), u32(0xfce7f3), u32(0xfef3c7), u32(0xede9fe),
		u32(0xe2e8f0)]
	mut children := []ui2.Element{}
	for index, caption in captions {
		children << ui2.button('dashboard-${index}', caption, ui2.Rect{},
			ui2.BoxStyle{ bg: colors[index], radius: 8 }, ui2.TextStyle{})
	}
	dashboard := ui2.grid(ui2.GridConfig{
		id:       'dashboard'
		frame:    ui2.rect(20, 60, frame.width - 40, frame.height - 80)
		columns:  3
		padding:  ui2.GridPadding{ left: 8, right: 8, top: 8, bottom: 8 }
		spacing:  ui2.GridSpacing{ horizontal: 8, vertical: 8 }
		children: children
	})!
	return ui2.screen(0xf1f5f9, [
		ui2.label('heading', 'Dashboard', ui2.rect(20, 16, frame.width - 40, 32),
			ui2.TextStyle{ color: 0x0f172a, size: 22, bold: true }),
		dashboard,
	])
}

fn build() ui2.Element {
	return grid_tree(ui2.bounds()) or { panic(err) }
}

fn event(_id string) {}

fn main() {
	ui2.run_window('Grid layout', grid_width, grid_height, build, event)
}
