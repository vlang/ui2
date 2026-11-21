module main

import ui2

fn find_custom_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_custom_element(child, id) {
			return found
		}
	}
	return none
}

fn test_openui_custom_component_renders() {
	mut renderer := ui2.new_openui_renderer(openui_custom_library())
	renderer.set_response('root = Stack([b])\nb = Badge("generative")', false)
	root, info := renderer.render()
	assert info.errors.len == 0
	assert root.children.len == 1
	badge := root.children[0]
	assert badge.text == '★ generative'
	assert find_custom_element(root, badge.id) != none
}
