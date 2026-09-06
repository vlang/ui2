module main

import ui2

const nested_clipping_width = 820
const nested_clipping_height = 640
const nested_clipping_qml_source = $embed_file('nested_clipping.qml').to_string()
const clip_grid_side = 4

pub struct ClipBox {
pub:
	id       int
	key      string
	quadrant int
	column   int
	row      int
	order    string
	color    string
pub mut:
	clipping bool
}

pub struct NestedClippingDemo {
pub mut:
	boxes  []ClipBox
	status string
}

// clip_ordinal names a box by the position it takes in the drawing order, the
// way the original demo does: a later box paints over whatever an earlier,
// unclipped neighbour spilled into its cell.
fn clip_ordinal(index int) string {
	if index % 100 in [11, 12, 13] {
		return '${index}th'
	}
	return match index % 10 {
		1 { '${index}st' }
		2 { '${index}nd' }
		3 { '${index}rd' }
		else { '${index}th' }
	}
}

// clip_box_color brightens one quadrant hue per slot, so the four boxes of a
// quadrant stay recognisably related while every box keeps its own bar color.
fn clip_box_color(quadrant int, slot int) string {
	bases := [[128, 16, 0], [80, 128, 0], [0, 110, 64], [0, 64, 100]]
	factor := 1.0 + f64(clip_grid_side - slot) * 2.0 / 3.0
	mut out := '#'
	for channel in bases[quadrant - 1] {
		value := int(f64(channel) * factor)
		out += '${if value > 255 { 255 } else { value }:02X}'
	}
	return out
}

fn nested_clipping_demo() NestedClippingDemo {
	mut app := NestedClippingDemo{}
	for quadrant in 1 .. clip_grid_side + 1 {
		for slot in 1 .. clip_grid_side + 1 {
			order := (quadrant - 1) * clip_grid_side + slot
			app.boxes << ClipBox{
				id: order
				key: 'box-${order}'
				quadrant: quadrant
				column: (quadrant - 1) % 2 * 2 + (slot - 1) % 2
				row: (quadrant - 1) / 2 * 2 + (slot - 1) / 2
				order: clip_ordinal(order)
				color: clip_box_color(quadrant, slot)
				clipping: true
			}
		}
	}
	app.update_status()
	return app
}

fn (app &NestedClippingDemo) clipped_in(quadrant int) int {
	return app.boxes.filter(it.quadrant == quadrant && it.clipping).len
}

fn (mut app NestedClippingDemo) update_status() {
	mut parts := []string{cap: clip_grid_side}
	for quadrant in 1 .. clip_grid_side + 1 {
		parts << '${quadrant}: ${app.clipped_in(quadrant)}/${clip_grid_side}'
	}
	app.status = 'Clipped boxes per quadrant — ' + parts.join(' · ')
}

pub fn (mut app NestedClippingDemo) toggle_box(id int) {
	for index, box in app.boxes {
		if box.id == id {
			app.boxes[index].clipping = !box.clipping
			app.update_status()
			return
		}
	}
}

pub fn (mut app NestedClippingDemo) toggle_quadrant(quadrant int) {
	// A quadrant that is not fully clipped clips as a whole first, so one tap
	// always has a visible effect.
	clipping := app.clipped_in(quadrant) < clip_grid_side
	for index, box in app.boxes {
		if box.quadrant == quadrant {
			app.boxes[index].clipping = clipping
		}
	}
	app.update_status()
}

fn (mut app NestedClippingDemo) set_all(clipping bool) {
	for index in 0 .. app.boxes.len {
		app.boxes[index].clipping = clipping
	}
	app.update_status()
}

pub fn (mut app NestedClippingDemo) clip_all() {
	app.set_all(true)
}

pub fn (mut app NestedClippingDemo) clip_none() {
	app.set_all(false)
}

fn main() {
	ui2.run_qml[NestedClippingDemo](
		source: nested_clipping_qml_source
		model: nested_clipping_demo()
		title: 'Nested Clipping'
		width: nested_clipping_width
		height: nested_clipping_height
	) or { panic(err) }
}
