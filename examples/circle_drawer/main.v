module main

import math
import ui2

const circle_drawer_width = 680
const circle_drawer_height = 520
const circle_drawer_vml_source = $embed_file('circle_drawer.vml').to_string()
const circle_canvas_root_x = 34.0
const circle_canvas_root_y = 92.0

pub struct DrawCircle {
pub:
	id    int
	x     f64
	y     f64
	color string
pub mut:
	radius f64
}

@[heap]
pub struct CircleDrawerDemo {
pub mut:
	circles         []DrawCircle
	selected_id     int = -1
	selected_radius f64
	radius_label    string = 'No selection'
	can_undo        bool
	can_redo        bool
	status          string = 'Click the canvas to add a circle; click a circle to select it.'
mut:
	next_id    int = 1
	undo_stack [][]DrawCircle
	redo_stack [][]DrawCircle
}

const circle_drawer_state = &CircleDrawerDemo{}

fn (mut app CircleDrawerDemo) update_history_flags() {
	app.can_undo = app.undo_stack.len > 0
	app.can_redo = app.redo_stack.len > 0
}

fn (mut app CircleDrawerDemo) checkpoint() {
	app.undo_stack << app.circles.clone()
	app.redo_stack = [][]DrawCircle{}
	app.update_history_flags()
}

fn (app &CircleDrawerDemo) circle_at(x f64, y f64) int {
	for index := app.circles.len - 1; index >= 0; index-- {
		circle := app.circles[index]
		if math.pow(circle.x - x, 2) + math.pow(circle.y - y, 2) <= math.pow(circle.radius, 2) {
			return index
		}
	}
	return -1
}

fn circle_color(id int) string {
	colors := ['#BFDBFE', '#BBF7D0', '#FDE68A', '#FBCFE8', '#DDD6FE']
	return colors[(id - 1) % colors.len]
}

fn (mut app CircleDrawerDemo) add_or_select(x f64, y f64) {
	index := app.circle_at(x, y)
	if index >= 0 {
		circle := app.circles[index]
		app.selected_id = circle.id
		app.selected_radius = circle.radius
		app.radius_label = 'r = ${int(circle.radius)}'
		app.status = 'Circle ${circle.id} selected.'
		return
	}
	app.checkpoint()
	circle := DrawCircle{
		id: app.next_id
		x: x
		y: y
		radius: 24
		color: circle_color(app.next_id)
	}
	app.circles << circle
	app.selected_id = circle.id
	app.selected_radius = circle.radius
	app.radius_label = 'r = ${int(circle.radius)}'
	app.next_id++
	app.status = 'Circle ${circle.id} added.'
	app.update_history_flags()
}

fn (mut app CircleDrawerDemo) adjust_radius(delta f64) {
	for index, circle in app.circles {
		if circle.id != app.selected_id {
			continue
		}
		app.checkpoint()
		next_radius := if circle.radius + delta < 12 {
			12.0
		} else if circle.radius + delta > 64 {
			64.0
		} else {
			circle.radius + delta
		}
		app.circles[index].radius = next_radius
		app.selected_radius = next_radius
		app.radius_label = 'r = ${int(next_radius)}'
		app.status = 'Circle ${circle.id} radius: ${int(next_radius)}.'
		app.update_history_flags()
		return
	}
}

fn (mut app CircleDrawerDemo) reconcile_selection() {
	for circle in app.circles {
		if circle.id == app.selected_id {
			app.selected_radius = circle.radius
			app.radius_label = 'r = ${int(circle.radius)}'
			return
		}
	}
	app.selected_id = -1
	app.selected_radius = 0
	app.radius_label = 'No selection'
}

fn (mut app CircleDrawerDemo) undo() {
	if app.undo_stack.len == 0 {
		return
	}
	app.redo_stack << app.circles.clone()
	app.circles = app.undo_stack.last().clone()
	app.undo_stack.delete_last()
	app.reconcile_selection()
	app.update_history_flags()
	app.status = 'Undid the last change.'
}

fn (mut app CircleDrawerDemo) redo() {
	if app.redo_stack.len == 0 {
		return
	}
	app.undo_stack << app.circles.clone()
	app.circles = app.redo_stack.last().clone()
	app.redo_stack.delete_last()
	app.reconcile_selection()
	app.update_history_flags()
	app.status = 'Redid the last change.'
}

fn (mut app CircleDrawerDemo) handle_event(event string) {
	match event {
		'undo' { app.undo() }
		'redo' { app.redo() }
		'radius_less' { app.adjust_radius(-4) }
		'radius_more' { app.adjust_radius(4) }
		else {
			if event.starts_with('pointer:up:circle_canvas:') {
				parts := event.split(':')
				if parts.len >= 5 {
					app.add_or_select(parts[3].f64() - circle_canvas_root_x, parts[4].f64() - circle_canvas_root_y)
				}
			}
		}
	}
}

fn build_circle_drawer_screen() ui2.Element {
	state := unsafe { circle_drawer_state }
	return ui2.element_from_vml_model(circle_drawer_vml_source, *state, ui2.bounds()) or {
		eprintln('circle-drawer VML failed: ${err}')
		ui2.screen(0xf1f5f9, [])
	}
}

fn handle_circle_drawer_event(event string) {
	mut state := unsafe { circle_drawer_state }
	state.handle_event(event)
	ui2.refresh()
}

fn main() {
	ui2.run_window('Circle Drawer', circle_drawer_width, circle_drawer_height, build_circle_drawer_screen, handle_circle_drawer_event)
}
