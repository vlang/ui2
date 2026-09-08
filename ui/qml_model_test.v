module ui2

pub struct QmlTestUser {
pub:
	id     int
	name   string
	weight f64
}

pub struct QmlTestNestedItem {
pub:
	id string
}

pub struct QmlTestGroup {
pub:
	id    string
	items []QmlTestNestedItem
}

pub struct QmlTestApp {
pub:
	max_users int = 3
pub mut:
	name    string
	enabled bool
	level   f64
	users   []QmlTestUser
	groups  []QmlTestGroup
	removed int
	saved   string
}

fn qml_test_control_value(_id string) f64 {
	return 72.5
}

fn qml_test_spinner_text(_id string) string {
	return 'Work'
}

pub fn (mut app QmlTestApp) clear() {
	app.name = ''
}

pub fn (mut app QmlTestApp) remove_user(id int) {
	app.removed = id
}

pub fn (mut app QmlTestApp) save_name(name string) {
	app.saved = name
}

fn qml_test_find(element Element, text string) ?Element {
	if element.text == text {
		return element
	}
	for child in element.children {
		if found := qml_test_find(child, text) {
			return found
		}
	}
	return none
}

fn test_qml_model_expressions_bindings_and_repeaters() {
	source := r'Screen {
		id: root
		property bool compact: root.width < 700

		TextField {
			bind.text: app.name
			width: root.compact ? root.width-32 : 210
		}
		Checkbox {
			bind.checked: app.enabled
		}
		Label {
			text: "${app.users.len}/${app.max_users}"
		}
		Button {
			text: "Clear"
			on_tap: app.clear()
		}
		Column {
			Repeater {
				model: app.users
				key: item.id
				Row {
					height: 30
					background: index % 2 == 0 ? #FFFFFF : #F1F5F9
					Label { text: item.name }
					Button { text: "Remove" on_tap: app.remove_user(item.id) }
				}
			}
		}
	}'
	app := QmlTestApp{
		name: 'Ada'
		enabled: true
		users: [
			QmlTestUser{ id: 7, name: 'Ada' },
			QmlTestUser{ id: 9, name: 'Lin' },
		]
	}
	root := element_from_qml_model(source, app, rect(0, 0, 640, 400)) or { panic(err) }
	validate_element_tree(root) or { panic(err) }
	assert (qml_test_find(root, '2/3') or { panic('missing count') }).text == '2/3'
	assert (qml_test_find(root, 'Ada') or { panic('missing model-bound field') }).frame.width == 608
	column := root.children[4]
	assert column.children.len == 2
	assert column.children[0].key == '7'
	assert column.children[1].key == '9'
	assert column.children[0].box.bg == u32(0xFFFFFF)
	assert column.children[1].box.bg == u32(0xF1F5F9)
}

fn test_qml_model_supports_numeric_slider_bindings() {
	source := 'Slider { id: volume bind.value: app.level min: 0 max: 100 step: 0.5 }'
	root := element_from_qml_model(source, QmlTestApp{ level: 12.5 }, rect(0, 0, 240, 32)) or {
		panic(err)
	}
	assert root.kind == .slider
	assert root.value == 12.5

	mut app := new_qml_app(source, QmlTestApp{ level: 12.5 }) or { panic(err) }
	app.control_value = qml_test_control_value
	built := app.build(rect(0, 0, 240, 32)) or { panic(err) }
	app.handle(built.action_id) or { panic(err) }
	assert app.state().level == 72.5
}

fn test_qml_model_supports_active_switch_bindings() {
	source := 'Switch { id: notifications bind.active: app.enabled }'
	root := element_from_qml_model(source, QmlTestApp{ enabled: true }, rect(0, 0, 83, 32)) or {
		panic(err)
	}
	assert root.kind == .switch_control
	assert root.checked

	mut app := new_qml_app(source, QmlTestApp{ enabled: false }) or { panic(err) }
	built := app.build(rect(0, 0, 83, 32)) or { panic(err) }
	app.handle(built.action_id) or { panic(err) }
	assert app.state().enabled
}

fn test_qml_model_rejects_non_boolean_switch_bindings() {
	if _ := element_from_qml_model('Switch { bind.active: app.name }', QmlTestApp{}, rect(0, 0, 83, 32)) {
		assert false, 'switch active state must bind to a bool field'
	} else {
		assert err.msg().contains('bind.active requires a bool field')
	}
}

fn test_qml_model_supports_spinner_text_bindings() {
	source := 'Spinner {
		id: location
		bind.text: app.name
		Option { text: "Home" }
		Option { text: "Work" }
	}'
	mut app := new_qml_app(source, QmlTestApp{ name: 'Home' }) or { panic(err) }
	app.control_text = qml_test_spinner_text
	built := app.build(rect(0, 0, 160, 42)) or { panic(err) }
	assert built.kind == .dropdown
	assert built.menu.len == 2
	app.handle(built.action_id) or { panic(err) }
	assert app.state().name == 'Work'
}

fn test_qml_model_supports_toggle_button_pressed_bindings() {
	source := 'ToggleButton { id: bold text: "Bold" bind.pressed: app.enabled }'
	root := element_from_qml_model(source, QmlTestApp{ enabled: true }, rect(0, 0, 100, 40)) or {
		panic(err)
	}
	assert root.kind == .toggle_button
	assert root.checked

	mut app := new_qml_app(source, QmlTestApp{ enabled: false }) or { panic(err) }
	built := app.build(rect(0, 0, 100, 40)) or { panic(err) }
	app.handle(built.action_id) or { panic(err) }
	assert app.state().enabled
}

fn test_qml_model_rejects_non_numeric_slider_bindings() {
	if _ := element_from_qml_model('Slider { bind.value: app.name }', QmlTestApp{}, rect(0, 0, 100, 30)) {
		assert false, 'slider values must bind to numeric fields'
	} else {
		assert err.msg().contains('bind.value requires a numeric field')
	}
}

fn test_qml_model_reports_unknown_paths_with_a_source_line() {
	if _ := element_from_qml_model('Label { text: app.frist_name }', QmlTestApp{}, rect(0, 0, 100, 30)) {
		assert false, 'unknown fields must not silently become empty strings'
	} else {
		assert err.msg().contains('app.frist_name')
		assert err.msg().contains('line 1')
	}
}

fn test_qml_model_rejects_readonly_bindings_and_unknown_actions() {
	if _ := element_from_qml_model('TextField { bind.text: app.max_users }', QmlTestApp{}, rect(0, 0, 100, 30)) {
		assert false, 'readonly fields must not be binding targets'
	} else {
		assert err.msg().contains('not mutable')
	}
	if _ := element_from_qml_model('Button { on_tap: app.typo() }', QmlTestApp{}, rect(0, 0, 100, 30)) {
		assert false, 'unknown actions must fail document loading'
	} else {
		assert err.msg().contains('unknown app action `typo`')
		assert err.msg().contains('line 1')
	}
}

fn test_qml_model_validates_an_initially_empty_repeater() {
	source := 'Screen { Repeater { model: app.users key: item.id Label { text: item.typo } } }'
	if _ := element_from_qml_model(source, QmlTestApp{}, rect(0, 0, 100, 30)) {
		assert false, 'empty repeaters must still validate their item paths'
	} else {
		assert err.msg().contains('item.typo')
	}
}

fn test_qml_model_does_not_evaluate_an_empty_repeater_schema() {
	source := 'Screen { Repeater { model: app.users key: item.id Label { width: 100 / item.weight } } }'
	root := element_from_qml_model(source, QmlTestApp{}, rect(0, 0, 100, 30)) or {
		panic(err)
	}
	assert root.children.len == 0
}

fn test_qml_model_validates_inactive_expression_branches() {
	source := 'Label { text: app.enabled ? app.typo : "OK" }'
	if _ := element_from_qml_model(source, QmlTestApp{ enabled: false }, rect(0, 0, 100, 30)) {
		assert false, 'inactive branches must still be validated'
	} else {
		assert err.msg().contains('app.typo')
	}
}

fn test_qml_model_resolves_named_node_geometry_before_children() {
	source := 'Screen { Rectangle { id: panel width: 200 Label { text: "Hello" width: panel.width } } }'
	root := element_from_qml_model(source, QmlTestApp{}, rect(0, 0, 780, 300)) or {
		panic(err)
	}
	text_label := qml_test_find(root, 'Hello') or { panic('missing label') }
	assert text_label.frame.width == 200
}

fn test_qml_model_evaluates_action_arguments_after_binding_writes() {
	source := 'TextField { bind.text: app.name on_change: app.save_name(app.name) }'
	template := parse_qml(source) or { panic(err) }
	mut app := QmlTestApp{ name: 'Ada' }
	q_validate_template[QmlTestApp](template, app) or { panic(err) }
	resolved, events := q_evaluate_template(template, app, rect(0, 0, 200, 30)) or {
		panic(err)
	}
	field := element_from_qnode(resolved, rect(0, 0, 200, 30)) or { panic(err) }
	event := events[field.action_id] or { panic('missing field event') }
	invocation := event.invocation or { panic('missing field action') }

	// This is the order used by QmlController.handle(): binding first, action second.
	qml_set_field[QmlTestApp](mut app, 'name', q_string('Adam')) or { panic(err) }
	qml_dispatch[QmlTestApp](mut app, invocation) or { panic(err) }
	assert app.name == 'Adam'
	assert app.saved == 'Adam'
}

fn test_qml_model_nested_repeater_event_identities_do_not_collide() {
	source := 'Screen {
		Repeater {
			model: app.groups
			key: item.id
			Rectangle {
				Repeater {
					model: item.items
					key: item.id
					Button { text: item.id on_tap: app.save_name(item.id) }
				}
			}
		}
	}'
	mut app := QmlTestApp{
		groups: [
			QmlTestGroup{ id: 'a/b', items: [QmlTestNestedItem{ id: 'c' }] },
			QmlTestGroup{ id: 'a', items: [QmlTestNestedItem{ id: 'b/c' }] },
		]
	}
	template := parse_qml(source) or { panic(err) }
	q_validate_template[QmlTestApp](template, app) or { panic(err) }
	resolved, events := q_evaluate_template(template, app, rect(0, 0, 200, 100)) or {
		panic(err)
	}
	root := element_from_qnode(resolved, rect(0, 0, 200, 100)) or { panic(err) }
	first := qml_test_find(root, 'c') or { panic('missing first nested item') }
	second := qml_test_find(root, 'b/c') or { panic('missing second nested item') }
	assert first.action_id != second.action_id
	assert events.len == 2

	first_invocation := (events[first.action_id] or { panic('missing first event') }).invocation or {
		panic('missing first invocation')
	}
	second_invocation := (events[second.action_id] or { panic('missing second event') }).invocation or {
		panic('missing second invocation')
	}
	qml_dispatch[QmlTestApp](mut app, first_invocation) or { panic(err) }
	assert app.saved == 'c'
	qml_dispatch[QmlTestApp](mut app, second_invocation) or { panic(err) }
	assert app.saved == 'b/c'
}

fn test_qml_model_adapter_writes_fields_and_dispatches_typed_actions() {
	mut app := QmlTestApp{ name: 'before' }
	qml_set_field[QmlTestApp](mut app, 'name', q_string('after')) or { panic(err) }
	assert app.name == 'after'
	qml_dispatch[QmlTestApp](mut app, QmlInvocation{ name: 'clear' }) or { panic(err) }
	assert app.name == ''
	argument := &QExpression{ kind: .literal, value: '42', line: 1 }
	qml_dispatch[QmlTestApp](mut app, QmlInvocation{
		name: 'remove_user'
		args: [argument]
	}) or { panic(err) }
	assert app.removed == 42
}
