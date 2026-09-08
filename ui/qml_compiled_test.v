module ui2

pub struct CompiledQmlTestModel {
pub mut:
	checked   bool
	secondary bool
	level     f64
	selected  string
	source    string
}

fn test_compiled_qml_event_resolves_app_argument_when_dispatched() {
	mut model := CompiledQmlTestModel{ source: 'current value' }
	event := compiled_qml_event_arg_path('', '', '', 'select', 'app.source')
	_ := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or { panic(err) }
	assert model.selected == 'current value'
}

pub fn (mut model CompiledQmlTestModel) select(value string) {
	model.selected = value
}

fn test_compiled_qml_event_applies_binding_and_typed_action() {
	mut model := CompiledQmlTestModel{}
	event := compiled_qml_event_arg('accept', 'checked', 'app.checked', 'select', 'Привет')
	handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or { panic(err) }
	assert handled
	assert model.checked
	assert model.selected == 'Привет'
}

fn test_compiled_qml_event_leaves_regular_actions_for_the_caller() {
	mut model := CompiledQmlTestModel{}
	handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, 'save') or { panic(err) }
	assert !handled
	assert !model.checked
}

fn test_compiled_qml_event_applies_numeric_slider_binding() {
	mut model := CompiledQmlTestModel{ level: 12.5 }
	event := compiled_qml_event('missing-slider', 'value', 'app.level', '')
	handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or { panic(err) }
	assert handled
	assert model.level == 0
}

fn test_compiled_qml_event_applies_active_switch_binding() {
	mut model := CompiledQmlTestModel{}
	event := compiled_qml_event('notifications', 'active', 'app.checked', '')
	handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or { panic(err) }
	assert handled
	assert model.checked
}

fn test_compiled_qml_event_applies_pressed_toggle_binding() {
	mut model := CompiledQmlTestModel{ checked: true }
	event := compiled_qml_event('missing-toggle', 'pressed', 'app.checked', '')
	handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or { panic(err) }
	assert handled
	assert !model.checked
}

fn test_compiled_qml_event_clears_pressed_group_peers() {
	$if ui2_custom_rendering ? {
		reset_compiled_qml_bindings()
		_ = compiled_qml_event('left', 'pressed', 'app.checked', '')
		event := compiled_qml_event('right', 'pressed', 'app.secondary', '')
		g_toggle_values = map[string]bool{
			'left':  false
			'right': true
		}
		g_toggle_groups = map[string]string{
			'left':  'choice'
			'right': 'choice'
		}
		g_active_toggles = map[string]bool{
			'left':  true
			'right': true
		}
		mut model := CompiledQmlTestModel{ checked: true }
		handled := handle_compiled_qml_event[CompiledQmlTestModel](mut model, event) or {
			panic(err)
		}
		assert handled
		assert !model.checked
		assert model.secondary
		g_toggle_values = map[string]bool{}
		g_toggle_groups = map[string]string{}
		g_active_toggles = map[string]bool{}
		reset_compiled_qml_bindings()
	}
}
