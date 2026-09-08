module main

import ui2

fn find_page_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_page_element(child, id) {
			return found
		}
	}
	return none
}

fn test_page_layout_demo_navigates_through_model_actions() {
	mut app := ui2.new_qml_app(page_qml_source, PageLayoutDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, page_width, page_height)) or {
		panic('initial page build failed: ${err}')
	}
	pager := find_page_element(initial, 'pager') or { panic('missing pager') }
	assert pager.children[0].frame == ui2.rect(0, 0, 356, 160)

	next := find_page_element(initial, 'next') or { panic('missing next action') }
	app.handle(next.action_id) or { panic(err) }
	assert app.state().page == 1
	rebuilt := app.build(ui2.rect(0, 0, page_width, page_height)) or {
		panic('rebuilt page failed: ${err}')
	}
	pager_after := find_page_element(rebuilt, 'pager') or { panic('missing rebuilt pager') }
	assert pager_after.children[1].frame == ui2.rect(12, 0, 356, 160)
}
