module main

import ui2

fn find_demo_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_demo_element(child, id) {
			return found
		}
	}
	return none
}

fn test_openui_demo_builds_from_response() {
	mut renderer := ui2.new_openui_renderer(ui2.new_openui_default_library())
	renderer.set_tool('list_tickets', fn (_ map[string]ui2.OpenuiValue) ui2.OpenuiValue {
		return ui2.openui_object({
			'rows': ui2.openui_list([
				ui2.openui_object({
					'status': ui2.openui_string('open')
				}),
			])
		})
	})
	renderer.set_response(demo_response, false)
	root, info := renderer.render()
	assert info.errors.len == 0
	assert root.children.len == 5
	button := find_demo_element(root, root.children[4].id) or { panic('missing button') }
	assert button.action_id.len > 0
	assert renderer.handle_event(button.action_id)
	assert renderer.state['filter'] or { ui2.openui_null() }.string_value() == 'shut'
}
