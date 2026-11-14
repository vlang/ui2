module main

import ui2

// Custom OpenUI component registered from outside the ui2 module. This is
// the supported way to extend the generative library with app-specific
// controls; it only compiles because `OpenuiComponent.render` is public.

fn render_badge(ctx ui2.OpenuiCtx) ui2.Element {
	return ui2.label(ctx.id, '★ ' + ctx.string_prop('text'), ctx.frame, ui2.TextStyle{
		bold:  true
		color: 0xb45309
	})
}

fn openui_custom_library() ui2.OpenuiLibrary {
	mut lib := ui2.new_openui_default_library()
	lib.register(ui2.OpenuiComponent{
		name:        'Badge'
		description: 'A small star-prefixed badge line.'
		params:      [
			ui2.OpenuiParam{
				name:   'text'
				schema: ui2.openui_string_schema()
			},
		]
		render:      render_badge
	})
	return lib
}

fn main() {
	mut renderer := ui2.new_openui_renderer(openui_custom_library())
	renderer.set_response('root = Stack([b])\nb = Badge("generative")', false)
	ui2.run_window('OpenUI custom', 640, 480, fn [mut renderer] () ui2.Element {
		return renderer.root_element()
	}, fn [mut renderer] (id string) {
		if renderer.handle_event(id) {
			ui2.refresh()
		}
	})
}
