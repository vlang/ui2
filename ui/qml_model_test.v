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
	name        string
	enabled     bool
	secondary   bool
	level       f64
	users       []QmlTestUser
	groups      []QmlTestGroup
	removed     int
	saved       string
	page        int
	tree_open   bool
	selected    string
	screen_name string
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

pub fn (mut app QmlTestApp) select_second_tab() {
	app.page = 1
}

pub fn (mut app QmlTestApp) toggle_tree() {
	app.tree_open = !app.tree_open
}

pub fn (mut app QmlTestApp) select_tree_leaf() {
	app.selected = 'guide'
}

pub fn (mut app QmlTestApp) show_details_screen() {
	app.screen_name = 'details'
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

fn test_qml_model_supports_text_input_bindings_and_validation_events() {
	source := 'TextInput {
		id: entry
		multiline: false
		bind.text: app.name
		on_text_validate: app.clear()
	}'
	mut app := new_qml_app(source, QmlTestApp{ name: 'Before' }) or { panic(err) }
	app.control_text = qml_test_spinner_text
	built := app.build(rect(0, 0, 240, 36)) or { panic(err) }
	assert built.kind == .text_field
	assert built.text == 'Before'
	app.handle(built.action_id) or { panic(err) }
	assert app.state().name == 'Work'
	app.handle(built.submit_id) or { panic(err) }
	assert app.state().name == ''
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

fn test_qml_model_toggle_button_groups_update_all_bound_fields() {
	source := 'Screen {
		ToggleButton {
			id: primary
			text: "Primary"
			group: choice
			allow_no_selection: false
			bind.pressed: app.enabled
		}
		ToggleButton {
			id: secondary
			text: "Secondary"
			group: choice
			allow_no_selection: false
			bind.pressed: app.secondary
		}
	}'
	normalized := element_from_qml_model(source, QmlTestApp{
		enabled: true
		secondary: true
	}, rect(0, 0, 240, 80)) or { panic(err) }
	assert (qml_test_find(normalized, 'Primary') or { panic('missing primary toggle') }).checked
	assert !(qml_test_find(normalized, 'Secondary') or { panic('missing secondary toggle') }).checked

	mut app := new_qml_app(source, QmlTestApp{ enabled: true }) or { panic(err) }
	built := app.build(rect(0, 0, 240, 80)) or { panic(err) }
	secondary := qml_test_find(built, 'Secondary') or { panic('missing secondary toggle') }
	app.handle(secondary.action_id) or { panic(err) }
	assert !app.state().enabled
	assert app.state().secondary

	rebuilt := app.build(rect(0, 0, 240, 80)) or { panic(err) }
	primary := qml_test_find(rebuilt, 'Primary') or { panic('missing primary toggle') }
	app.handle(primary.action_id) or { panic(err) }
	assert app.state().enabled
	assert !app.state().secondary
	app.handle(primary.action_id) or { panic(err) }
	assert app.state().enabled
}

fn test_qml_model_grid_layout_counts_repeater_children() {
	source := 'GridLayout {
		columns: 2
		padding: 10
		spacing: 10
		Repeater {
			model: app.users
			key: item.id
			Button { text: item.name }
		}
	}'
	grid := element_from_qml_model(source, QmlTestApp{
		users: [
			QmlTestUser{ id: 1, name: 'One' },
			QmlTestUser{ id: 2, name: 'Two' },
			QmlTestUser{ id: 3, name: 'Three' },
		]
	}, rect(0, 0, 210, 110)) or { panic(err) }
	assert grid.children.len == 3
	assert grid.children[0].frame == rect(10, 10, 90, 40)
	assert grid.children[1].frame == rect(110, 10, 90, 40)
	assert grid.children[2].frame == rect(10, 60, 90, 40)
}

fn test_qml_model_box_layout_uses_repeater_size_hints() {
	source := 'BoxLayout {
		padding: 10
		spacing: 10
		Button { text: "Fixed" width: 80 size_hint_x: -1 }
		Repeater {
			model: app.users
			key: item.id
			Button { text: item.name size_hint_x: item.weight }
		}
	}'
	box := element_from_qml_model(source, QmlTestApp{
		users: [
			QmlTestUser{ id: 1, name: 'Wide', weight: 2 },
			QmlTestUser{ id: 2, name: 'Narrow', weight: 1 },
		]
	}, rect(0, 0, 330, 80)) or { panic(err) }
	assert box.children.len == 3
	assert box.children[0].frame == rect(10, 10, 80, 60)
	assert box.children[1].frame == rect(100, 10, 140, 60)
	assert box.children[2].frame == rect(250, 10, 70, 60)
}

fn test_qml_model_float_layout_uses_repeater_hints() {
	source := 'FloatLayout {
		Repeater {
			model: app.users
			key: item.id
			Button {
				text: item.name
				height: 24
				size_hint_x: item.weight
				size_hint_y: -1
				pos_hint_center_x: index == 0 ? 0.25 : 0.75
				pos_hint_y: index * 0.25
			}
		}
	}'
	canvas := element_from_qml_model(source, QmlTestApp{
		users: [
			QmlTestUser{ id: 1, name: 'Small', weight: 0.25 },
			QmlTestUser{ id: 2, name: 'Large', weight: 0.5 },
		]
	}, rect(0, 0, 200, 100)) or { panic(err) }
	assert canvas.children[0].frame == rect(25, 0, 50, 24)
	assert canvas.children[1].frame == rect(100, 25, 100, 24)
}

fn test_qml_model_relative_layout_resolves_local_child_geometry() {
	source := 'RelativeLayout {
		x: 40
		y: 50
		width: 200
		height: 100
		Button {
			text: app.name
			width: app.level
			height: 30
			size_hint_x: -1
			size_hint_y: -1
			pos_hint_center_x: 0.5
			pos_hint_center_y: 0.5
		}
	}'
	panel := element_from_qml_model(source, QmlTestApp{ name: 'Action', level: 80 }, rect(0, 0, 400, 240)) or { panic(err) }
	assert panel.frame == rect(40, 50, 200, 100)
	assert panel.children[0].frame == rect(60, 35, 80, 30)
}

fn test_qml_model_page_layout_resolves_current_page() {
	source := 'PageLayout {
		page: app.page
		border: 40
		Rectangle { id: first }
		Rectangle { id: second }
		Rectangle { id: third }
	}'
	pager := element_from_qml_model(source, QmlTestApp{ page: 1 }, rect(0, 0, 300, 160)) or { panic(err) }
	assert pager.children[0].frame == rect(0, 0, 260, 160)
	assert pager.children[1].frame == rect(20, 0, 260, 160)
	assert pager.children[2].frame == rect(280, 0, 260, 160)
}

fn test_qml_model_tabbed_panel_switches_content_through_tab_action() {
	source := 'TabbedPanel {
		id: panel
		current: app.page
		tab_width: 100
		Tab { id: first text: "First" Label { text: "First content" } }
		Tab {
			id: second
			text: "Second"
			on_select: app.select_second_tab()
			Label { text: "Second content" }
		}
	}'
	mut app := new_qml_app(source, QmlTestApp{}) or { panic(err) }
	initial := app.build(rect(0, 0, 300, 180)) or { panic(err) }
	assert initial.children[0].children[0].text == 'First content'
	app.handle(initial.children[2].action_id) or { panic(err) }
	assert app.state().page == 1
	rebuilt := app.build(rect(0, 0, 300, 180)) or { panic(err) }
	assert rebuilt.children[0].children[0].text == 'Second content'
	assert rebuilt.children[2].accessibility_value == 'selected'
}

fn test_qml_model_accordion_switches_content_through_item_action() {
	source := 'Accordion {
		id: sections
		current: app.page
		orientation: vertical
		min_space: 40
		AccordionItem { id: first title: "First" Label { text: "First content" } }
		AccordionItem {
			id: second
			title: "Second"
			on_select: app.select_second_tab()
			Label { text: "Second content" }
		}
	}'
	mut app := new_qml_app(source, QmlTestApp{}) or { panic(err) }
	initial := app.build(rect(0, 0, 300, 180)) or { panic(err) }
	assert initial.children[0].children[0].text == 'First content'
	app.handle(initial.children[2].action_id) or { panic(err) }
	assert app.state().page == 1
	rebuilt := app.build(rect(0, 0, 300, 180)) or { panic(err) }
	assert rebuilt.children[0].children[0].text == 'Second content'
	assert rebuilt.children[2].accessibility_value == 'expanded'
}

fn test_qml_model_tree_view_expands_and_selects_through_actions() {
	source := 'TreeView {
		id: navigation
		TreeNode {
			id: docs
			text: "Documentation"
			expanded: app.tree_open
			on_toggle: app.toggle_tree()
			TreeNode {
				id: guide
				text: "Guide"
				selected: app.selected == "guide"
				on_select: app.select_tree_leaf()
			}
		}
		TreeNode { id: license text: "License" }
	}'
	mut app := new_qml_app(source, QmlTestApp{}) or { panic(err) }
	initial := app.build(rect(0, 0, 300, 200)) or { panic(err) }
	assert initial.children.len == 2
	app.handle(initial.children[0].children[0].action_id) or { panic(err) }
	assert app.state().tree_open

	expanded := app.build(rect(0, 0, 300, 200)) or { panic(err) }
	assert expanded.children.len == 3
	app.handle(expanded.children[1].children[1].action_id) or { panic(err) }
	assert app.state().selected == 'guide'

	selected := app.build(rect(0, 0, 300, 200)) or { panic(err) }
	assert selected.children[1].children[1].accessibility_value == 'selected'
}

fn test_qml_model_screen_manager_switches_active_screen_through_action() {
	source := 'ScreenManager {
		id: manager
		current: app.screen_name
		Screen {
			id: home
			Button { text: "Details" on_tap: app.show_details_screen() }
		}
		Screen { id: details Label { text: "Details content" } }
	}'
	mut app := new_qml_app(source, QmlTestApp{}) or { panic(err) }
	initial := app.build(rect(0, 0, 320, 200)) or { panic(err) }
	assert initial.children.len == 1
	assert initial.children[0].id == 'home'
	app.handle(initial.children[0].children[0].action_id) or { panic(err) }
	assert app.state().screen_name == 'details'

	rebuilt := app.build(rect(0, 0, 320, 200)) or { panic(err) }
	assert rebuilt.children.len == 1
	assert rebuilt.children[0].id == 'details'
	assert rebuilt.children[0].children[0].text == 'Details content'
}

fn test_qml_model_carousel_switches_active_slide_through_action() {
	source := 'Carousel {
		id: gallery
		index: app.page
		loop: true
		CarouselSlide {
			id: first
			Button { text: "Next" on_tap: app.select_second_tab() }
		}
		CarouselSlide { id: second Label { text: "Second slide" } }
	}'
	mut app := new_qml_app(source, QmlTestApp{}) or { panic(err) }
	initial := app.build(rect(0, 0, 320, 200)) or { panic(err) }
	assert !initial.children[0].hidden
	assert initial.children[1].hidden
	app.handle(initial.children[0].children[0].action_id) or { panic(err) }
	assert app.state().page == 1

	rebuilt := app.build(rect(0, 0, 320, 200)) or { panic(err) }
	assert rebuilt.children[0].hidden
	assert !rebuilt.children[1].hidden
	assert rebuilt.children[1].children[0].text == 'Second slide'
}

fn test_qml_model_anchor_layout_uses_resolved_child_sizes() {
	source := 'AnchorLayout {
		anchor_x: center
		anchor_y: center
		Rectangle {
			id: card
			width: app.level
			height: 30
			Label { text: "Centered" x: card.x }
		}
	}'
	anchored := element_from_qml_model(source, QmlTestApp{ level: 120 }, rect(0, 0, 200, 100)) or { panic(err) }
	assert anchored.children.len == 1
	assert anchored.children[0].frame == rect(40, 35, 120, 30)
	assert anchored.children[0].children[0].frame.width == 120
	assert anchored.children[0].children[0].frame.x == 40
}

fn test_qml_model_stack_layout_wraps_repeater_children_by_resolved_size() {
	source := 'StackLayout {
		padding: 10
		spacing_x: 6
		spacing_y: 4
		Repeater {
			model: app.users
			key: item.id
			Button { text: item.name width: item.weight height: 24 }
		}
	}'
	stack := element_from_qml_model(source, QmlTestApp{
		users: [
			QmlTestUser{ id: 1, name: 'One', weight: 70 },
			QmlTestUser{ id: 2, name: 'Two', weight: 80 },
			QmlTestUser{ id: 3, name: 'Three', weight: 90 },
		]
	}, rect(0, 0, 180, 100)) or { panic(err) }
	assert stack.children.len == 3
	assert stack.children[0].frame == rect(10, 10, 70, 24)
	assert stack.children[1].frame == rect(86, 10, 80, 24)
	assert stack.children[2].frame == rect(10, 38, 90, 24)
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
