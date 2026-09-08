module main

import ui2

fn test_carousel_demo_loops_through_slides() {
	mut app := ui2.new_vml_app(carousel_vml_source, CarouselDemo{}) or { panic(err) }
	initial := app.build(ui2.rect(0, 0, carousel_width, carousel_height)) or { panic(err) }
	gallery := initial.children[2]
	assert !gallery.children[0].hidden
	assert gallery.children[1].hidden
	app.handle(initial.children[4].action_id) or { panic(err) }
	assert app.state().index == 1

	rebuilt := app.build(ui2.rect(0, 0, carousel_width, carousel_height)) or { panic(err) }
	assert rebuilt.children[2].children[0].hidden
	assert !rebuilt.children[2].children[1].hidden
	assert rebuilt.children[2].children[1].children[0].text == 'Forest'
}
