module ui2

pub struct QmlTestUser {
pub:
	id   int
	name string
}

pub struct QmlTestApp {
pub:
	max_users int = 3
pub mut:
	name    string
	enabled bool
	users   []QmlTestUser
	removed int
}

pub fn (mut app QmlTestApp) clear() {
	app.name = ''
}

pub fn (mut app QmlTestApp) remove_user(id int) {
	app.removed = id
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

fn test_qml_model_adapter_writes_fields_and_dispatches_typed_actions() {
	mut app := QmlTestApp{ name: 'before' }
	qml_set_field[QmlTestApp](mut app, 'name', q_string('after')) or { panic(err) }
	assert app.name == 'after'
	qml_dispatch[QmlTestApp](mut app, QmlInvocation{ name: 'clear' }) or { panic(err) }
	assert app.name == ''
	qml_dispatch[QmlTestApp](mut app, QmlInvocation{
		name: 'remove_user'
		args: [q_number(42, '42')]
	}) or { panic(err) }
	assert app.removed == 42
}
