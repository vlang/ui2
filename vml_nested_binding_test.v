module ui2

pub struct NestedBindingValues {
pub:
	locked string
pub mut:
	name    string
	checked bool
	active  bool
	pressed bool
	level   f64
	count   int
	ratio   f32
mut:
	secret string
}

pub struct NestedBindingSection {
pub mut:
	values NestedBindingValues
}

pub struct NestedBindingApp {
pub:
	locked NestedBindingSection
pub mut:
	section NestedBindingSection
	saved   string
mut:
	private_section NestedBindingSection
}

pub fn (mut app NestedBindingApp) save(name string) {
	app.saved = name
}

fn test_nested_binding_reads_and_writes_before_invoking_action() {
	source := 'TextInput { id: name multiline: false bind.text: app.section.values.name on_change: app.save(app.section.values.name) }'
	mut app := new_vml_app(source, NestedBindingApp{
		section: NestedBindingSection{
			values: NestedBindingValues{
				name: 'Before'
			}
		}
	}) or { panic(err) }
	app.control_text = fn (_ string) string {
		return 'After'
	}
	built := app.build(rect(0, 0, 240, 36)) or { panic(err) }
	assert built.text == 'Before'
	app.handle(built.action_id) or { panic(err) }
	assert app.state().section.values.name == 'After'
	assert app.state().saved == 'After'
	assert (app.build(rect(0, 0, 240, 36)) or { panic(err) }).text == 'After'
}

fn test_nested_binding_supports_boolean_and_numeric_controls() {
	source := 'Screen {
		Checkbox { bind.checked: app.section.values.checked }
		Switch { bind.active: app.section.values.active }
		ToggleButton { bind.pressed: app.section.values.pressed }
		Slider { bind.value: app.section.values.level min: 0 max: 100 }
		Slider { bind.value: app.section.values.count min: 0 max: 100 }
		Slider { bind.value: app.section.values.ratio min: 0 max: 100 }
	}'
	mut app := new_vml_app(source, NestedBindingApp{}) or { panic(err) }
	app.control_value = fn (_ string) f64 {
		return 42.5
	}
	built := app.build(rect(0, 0, 300, 300)) or { panic(err) }
	for child in built.children {
		app.handle(child.action_id) or { panic(err) }
	}
	assert app.state().section.values.checked
	assert app.state().section.values.active
	assert app.state().section.values.pressed
	assert app.state().section.values.level == 42.5
	assert app.state().section.values.count == 42
	assert app.state().section.values.ratio == f32(42.5)
}

fn test_nested_binding_rejects_private_readonly_and_unknown_paths() {
	for path in ['locked.values.name', 'private_section.values.name', 'section.values.locked',
		'section.values.secret', 'section.values.missing', 'section.values.name.len'] {
		source := 'TextInput { bind.text: app.${path} }'
		if _ := new_vml_app(source, NestedBindingApp{}) {
			assert false, 'invalid binding ${path} was accepted'
		}
		mut model := NestedBindingApp{}
		if _ := vml_set_field(mut model, path, v_string('no')) {
			assert false, 'invalid write ${path} was accepted'
		}
		assert model.section.values.name == ''
	}
	if _ := new_vml_app('Checkbox { bind.checked: app.section.values.name }', NestedBindingApp{}) {
		assert false, 'a nested string is not a bool'
	} else {
		assert err.msg().contains('requires a bool field')
	}
	if _ := new_vml_app('Slider { bind.value: app.section.values.name }', NestedBindingApp{}) {
		assert false, 'a nested string is not numeric'
	} else {
		assert err.msg().contains('requires a numeric field')
	}
}
