module ui2

struct VmlHookApp {
pub mut:
	calls  int
	phase  string
	action string
	x      f64
	y      f64
}

pub fn (mut app VmlHookApp) on_pointer_event(event PointerEvent) {
	app.calls++
	app.phase = event.phase
	app.action = event.action
	app.x = event.x
	app.y = event.y
}

struct VmlRawHookApp {
pub mut:
	raw string
}

pub fn (mut app VmlRawHookApp) on_pointer_event(raw string) {
	app.raw = raw
}

struct VmlHookTapApp {
pub mut:
	taps         int
	pointer_hits int
}

pub fn (mut app VmlHookTapApp) on_pointer_event(_ PointerEvent) {
	app.pointer_hits++
}

pub fn (mut app VmlHookTapApp) tap() {
	app.taps++
}

struct VmlNoHookApp {
pub mut:
	taps int
}

pub fn (mut app VmlNoHookApp) tap() {
	app.taps++
}

struct VmlInvalidHookApp {
pub mut:
	value int
}

pub fn (mut app VmlInvalidHookApp) on_pointer_event(x int, y int) {
	app.value = x + y
}

fn test_vml_pointer_hook_receives_pointer_phases_and_coordinates() {
	mut app := new_vml_app('Screen { Button { text: "Drag" } }', VmlHookApp{}) or { panic(err) }
	_ = app.build(rect(0, 0, 200, 100)) or { panic(err) }
	app.handle('pointer:down:drag_handle:10:20') or { panic(err) }
	mut state := app.state()
	assert state.calls == 1
	assert state.phase == 'down'
	assert state.action == 'drag_handle'
	assert state.x == 10
	assert state.y == 20
	app.handle('pointer:drag:drag_handle:12.5:24.5') or { panic(err) }
	state = app.state()
	assert state.calls == 2
	assert state.phase == 'drag'
	assert state.x == 12.5
	assert state.y == 24.5
	app.handle('pointer:up:drag_handle:13:25') or { panic(err) }
	assert app.state().phase == 'up'
}

fn test_vml_pointer_hook_decodes_colons_and_hover_phases() {
	mut app := new_vml_app('Screen { Label { text: "Hover" } }', VmlHookApp{}) or { panic(err) }
	_ = app.build(rect(0, 0, 200, 100)) or { panic(err) }
	app.handle('pointer:enter:component:trigger@0:save:1:2') or { panic(err) }
	mut state := app.state()
	assert state.calls == 1
	assert state.phase == 'enter'
	assert state.action == 'component:trigger@0:save'
	assert state.x == 1
	assert state.y == 2
	app.handle('pointer:leave:component:trigger@0:save:3:4') or { panic(err) }
	assert app.state().phase == 'leave'
}

fn test_vml_pointer_hook_can_take_the_raw_event() {
	mut app := new_vml_app('Screen { Label { text: "Text" } }', VmlRawHookApp{}) or { panic(err) }
	app.handle('pointer:drag:track:3:4') or { panic(err) }
	assert app.state().raw == 'pointer:drag:track:3:4'
}

fn test_vml_pointer_event_does_not_fire_on_tap_a_second_time() {
	mut app := new_vml_app('Screen { Button { text: "Tap" on_tap: app.tap() } }', VmlHookTapApp{}) or {
		panic(err)
	}
	element := app.build(rect(0, 0, 200, 100)) or { panic(err) }
	id := element.children[0].action_id
	assert id.len > 0
	app.handle(id) or { panic(err) }
	assert app.state().taps == 1
	assert app.state().pointer_hits == 0
	app.handle('pointer:down:${id}:1:2') or { panic(err) }
	assert app.state().taps == 1
	assert app.state().pointer_hits == 1
}

fn test_vml_without_pointer_hook_ignores_pointer_events() {
	mut app := new_vml_app('Screen { Button { text: "Tap" on_tap: app.tap() } }', VmlNoHookApp{}) or {
		panic(err)
	}
	element := app.build(rect(0, 0, 200, 100)) or { panic(err) }
	app.handle('pointer:down:whatever:1:2') or { panic(err) }
	assert app.state().taps == 0
	app.handle(element.children[0].action_id) or { panic(err) }
	assert app.state().taps == 1
}

fn test_vml_rejects_an_unsupported_pointer_hook() {
	if _ := new_vml_app('Screen { Label { text: "Text" } }', VmlInvalidHookApp{}) {
		assert false, 'an unsupported pointer hook must be rejected'
	} else {
		assert err.msg().contains('on_pointer_event')
		assert err.msg().contains('PointerEvent')
	}
}

fn test_vml_controller_routes_pointer_events_to_the_hook() {
	mut controller := &VmlController[VmlHookApp]{
		template: parse_vml('Screen { Button { text: "x" } }') or { panic(err) }
		model:    VmlHookApp{}
		events:   map[string]VmlEvent{}
	}
	controller.handle('pointer:up:track:7:8')
	assert controller.model.calls == 1
	assert controller.model.phase == 'up'
	assert controller.model.action == 'track'
	assert controller.model.x == 7
	assert controller.model.y == 8
}
