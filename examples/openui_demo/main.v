module main

import ui2

// Generative UI demo: an OpenUI Lang response rendered directly to `Element`.
// In a real app the response streams from the model; here it is fixed text so
// the demo runs without network or keys.

const demo_width = 640
const demo_height = 480

const demo_response = '\$filter = "open"\n' +
	'tickets = Query("list_tickets", {}, {rows: [{title: "Login fails", status: "open"}, {title: "Dark mode", status: "shut"}]})\n' +
	'open = @Filter(tickets.rows, "status", "==", \$filter)\n' +
	'root = Stack([heading, count, grid, toggle])\n' +
	'heading = TextContent("Support tickets", "large-heavy")\n' +
	'count = TextContent("Open: " + @Count(open))\n' +
	'grid = Table(open)\n' +
	'toggle = Button("Show all", @Set(\$filter, "shut"))'

struct DemoState {
mut:
	renderer &ui2.OpenuiRenderer = unsafe { nil }
	ready    bool
}

// The window callbacks are plain functions, so the renderer lives in a
// module singleton like the VML controller instead of a global.

const demo_state = &DemoState{}

fn demo_tool(_ map[string]ui2.OpenuiValue) ui2.OpenuiValue {
	return ui2.openui_object({
		'rows': ui2.openui_list([
			ui2.openui_object({
				'title':  ui2.openui_string('Login fails')
				'status': ui2.openui_string('open')
			}),
			ui2.openui_object({
				'title':  ui2.openui_string('Dark mode')
				'status': ui2.openui_string('shut')
			}),
		])
	})
}

fn demo_build() ui2.Element {
	mut state := demo_state
	if !state.ready {
		return ui2.screen(0xffffff, [])
	}
	return state.renderer.root_element()
}

fn demo_event(event_id string) {
	mut state := demo_state
	if state.renderer.handle_event(event_id) {
		ui2.refresh()
	}
}

fn demo_on_action(event ui2.OpenuiActionEvent) {
	println('assistant: ${event.message}')
}

fn main() {
	state_renderer := &ui2.OpenuiRenderer{
		library: ui2.new_openui_default_library()
	}
	mut state := demo_state
	state.renderer = state_renderer
	state.renderer.set_tool('list_tickets', demo_tool)
	state.renderer.on_action = demo_on_action
	state.renderer.set_response(demo_response, false)
	state.ready = true
	ui2.run_window('OpenUI demo', demo_width, demo_height, demo_build, demo_event)
}
