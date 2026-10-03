module ui2

pub interface RepeaterItemContract {
	id    int
	label string
}

pub struct RepeaterItemA {
pub:
	id    int
	label string
	extra string
}

pub struct RepeaterItemB {
pub:
	id    int
	label string
}

pub struct InterfaceRepeaterApp {
pub mut:
	items    []RepeaterItemContract
	selected int
}

pub fn (mut app InterfaceRepeaterApp) select(id int) {
	app.selected = id
}

const interface_repeater_source = 'Column {
	Repeater {
		model: app.items
		key: item.id
		Button { text: item.label on_tap: app.select(item.id) }
	}
}'

fn test_repeater_reads_interface_fields_and_dispatches_stable_item_actions() {
	mut model := InterfaceRepeaterApp{
		items: [RepeaterItemContract(RepeaterItemA{
			id:    7
			label: 'One'
		}),
			RepeaterItemContract(&RepeaterItemB{
				id:    9
				label: 'Two'
			})]
	}
	template := parse_vml(interface_repeater_source) or { panic(err) }
	v_validate_template(template, model) or { panic(err) }
	resolved, events := v_evaluate_template(template, model, rect(0, 0, 240, 160)) or { panic(err) }
	root := element_from_vnode(resolved, rect(0, 0, 240, 160)) or { panic(err) }
	assert root.children.len == 2
	assert root.children[0].text == 'One'
	assert root.children[1].text == 'Two'
	assert root.children[0].key == '7'
	assert root.children[1].key == '9'
	event := events[root.children[1].action_id] or { panic('missing event') }
	invocation := event.invocation or { panic('missing action') }
	vml_dispatch(mut model, invocation) or { panic(err) }
	assert model.selected == 9
	model.items.reverse_in_place()
	reordered, _ := v_evaluate_template(template, model, rect(0, 0, 240, 160)) or { panic(err) }
	assert reordered.children[0].prop('on_tap') == root.children[1].action_id
}

fn test_empty_interface_repeater_validates_without_dereferencing_an_item() {
	root := element_from_vml_model(interface_repeater_source, InterfaceRepeaterApp{}, rect(0, 0,
		240, 160)) or { panic(err) }
	assert root.children.len == 0
	for field in ['typo', 'extra'] {
		bad := interface_repeater_source.replace('item.label', 'item.${field}')
		if _ := element_from_vml_model(bad, InterfaceRepeaterApp{}, rect(0, 0, 240, 160)) {
			assert false, 'fields outside the interface contract must be rejected'
		} else {
			assert err.msg().contains('item.${field}')
		}
	}
}

fn test_interface_repeater_rejects_duplicate_keys() {
	model := InterfaceRepeaterApp{
		items: [RepeaterItemContract(RepeaterItemA{
			id: 7
		}),
			RepeaterItemContract(RepeaterItemB{
				id: 7
			})]
	}
	if _ := element_from_vml_model(interface_repeater_source, model, rect(0, 0, 240, 160)) {
		assert false, 'duplicate interface keys must not be accepted'
	} else {
		assert err.msg().contains('duplicate Repeater key')
	}
}
