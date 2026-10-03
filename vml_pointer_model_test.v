module ui2

pub struct PointerCounter {
pub mut:
	count int
	next  &PointerCounter = unsafe { nil }
}

pub struct PointerCounterApp {
pub mut:
	counter &PointerCounter = unsafe { nil }
	other   &PointerCounter = unsafe { nil }
	items   []&PointerCounter
}

pub fn (mut app PointerCounterApp) increment() {
	app.counter.count++
}

fn test_pointer_model_reads_live_values_after_an_action() {
	counter := &PointerCounter{
		count: 3
	}
	mut app := new_vml_app('Screen {
		Label { text: app.counter.count }
		Button { on_tap: app.increment() }
	}', PointerCounterApp{
		counter: counter
	}) or { panic(err) }
	built := app.build(rect(0, 0, 200, 100)) or { panic(err) }
	assert built.children[0].text == '3'
	app.handle(built.children[1].action_id) or { panic(err) }
	assert counter.count == 4
	assert (app.build(rect(0, 0, 200, 100)) or { panic(err) }).children[0].text == '4'
}

fn test_pointer_model_handles_shared_nested_and_cyclic_references() {
	mut counter := &PointerCounter{
		count: 3
	}
	counter.next = counter
	model := PointerCounterApp{
		counter: counter
		other:   counter
	}
	root := element_from_vml_model('Label { text: app.counter.count + app.other.count }', model, rect(0,
		0, 100, 30)) or { panic(err) }
	assert root.text == '6.0'
	counter.next = &PointerCounter{
		count: 5
	}
	nested := element_from_vml_model('Label { text: app.counter.next.count }', model, rect(0, 0,
		100, 30)) or { panic(err) }
	assert nested.text == '5'
}

fn test_pointer_model_nil_path_returns_an_error_without_dereferencing() {
	if _ := element_from_vml_model('Label { text: app.counter.count }', PointerCounterApp{}, rect(0,
		0, 100, 30))
	{
		assert false, 'a nil counter must not be dereferenced'
	} else {
		assert err.msg().contains('app.counter.count')
		assert err.msg().contains('line 1')
	}
	// A nil field that is not used by this template must be harmless.
	assert (element_from_vml_model('Label { text: "OK" }', PointerCounterApp{}, rect(0, 0, 100, 30)) or {
		panic(err)
	}).text == 'OK'
}

fn test_pointer_model_arrays_validate_when_empty_and_render_when_populated() {
	source := 'Column { Repeater { model: app.items key: item.count Label { text: item.count } } }'
	empty := element_from_vml_model(source, PointerCounterApp{}, rect(0, 0, 100, 100)) or {
		panic(err)
	}
	assert empty.children.len == 0
	full := element_from_vml_model(source, PointerCounterApp{ items: [&PointerCounter{ count: 7 }] }, rect(0,
		0, 100, 100)) or { panic(err) }
	assert full.children[0].text == '7'
	if _ := element_from_vml_model(source.replace('text: item.count', 'text: item.typo'), PointerCounterApp{}, rect(0,
		0, 100, 100))
	{
		assert false, 'empty pointer arrays must still validate fields'
	} else {
		assert err.msg().contains('item.typo')
	}
}

fn test_pointer_model_dereferences_scalar_and_multiple_indirections() {
	number := 42
	pointer := &number
	assert v_value_from(pointer).number == 42
	assert v_value_from(&pointer).number == 42
	assert v_schema_from(&pointer).kind == .number
	text := 'Hello'
	assert v_value_from(&text).text == 'Hello'
	flag := true
	assert v_value_from(&flag).bool_
	assert v_value_from(unsafe { nil }).kind == .invalid
}

fn test_pointer_model_multiple_nil_indirections_are_safe() {
	nil_counter := unsafe { &PointerCounter(nil) }
	assert v_value_from(&nil_counter).kind == .invalid
	assert v_schema_from(&nil_counter).kind == .object
	schema := v_schema_from(&nil_counter)
	assert (schema.fields['count'] or { panic('missing count schema') }).kind == .number
	nil_double := unsafe { &&PointerCounter(nil) }
	assert v_schema_from(nil_double).kind == .object
	assert v_value_from(nil_double).kind == .invalid
}
