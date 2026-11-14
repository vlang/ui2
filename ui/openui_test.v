module ui2

fn test_openui_library_register_and_extend() {
	lib := new_openui_default_library()
	assert lib.root == 'Stack'
	assert lib.find('Button') != none
	assert lib.find('Missing') == none
	mut extended := lib
	extended.register(OpenuiComponent{
		name:        'Badge'
		description: 'A small badge.'
		params:      [
			OpenuiParam{
				name:   'text'
				schema: openui_string_schema()
			},
		]
		render:      openui_render_text_content
	})
	assert extended.find('Badge') != none
	assert lib.find('Badge') == none
	derived := lib.extend(OpenuiExtendConfig{
		remove: ['Card']
	})
	assert derived.find('Card') == none
	assert derived.find('Stack') != none
}

fn test_openui_parse_program_statements() {
	statements := parse_openui_program('root = Stack([title])\ntitle = TextContent("Hi")\n\$days = "7"')!
	assert statements.len == 3
	assert statements[0].name == 'root'
	assert statements[2].name == '\$days'
}

fn test_openui_parse_forward_reference_ok() {
	statements := parse_openui_program('root = Stack([later])\nlater = TextContent("Hi")')!
	assert statements.len == 2
}

fn test_openui_parse_action_and_query() {
	statements := parse_openui_program('save = Button("Save", @ToAssistant("hi"))\ndata = Query("tools", {}, {rows: []})')!
	assert statements.len == 2
}

fn test_openui_eval_kpi_count_filter() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	scope.tools['list'] = fn (_ map[string]OpenuiValue) OpenuiValue {
		return openui_object({
			'rows': openui_list([
				openui_object({
					'status': openui_string('open')
				}),
				openui_object({
					'status': openui_string('shut')
				}),
			])
		})
	}
	statements := parse_openui_program('data = Query("list", {}, {rows: []})\nopen = @Filter(data.rows, "status", "==", "open")\ncount = @Count(open)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	count := scope.values['count'] or { openui_null() }
	assert count.kind == .number
	assert count.number == 1.0
}

fn test_openui_eval_unknown_component_drops() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = Nope("x")')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_unknown_component)
}

fn test_openui_eval_each_renders_per_item() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('items = ["a", "b"]\nlist = @Each(items, "t", TextContent(t))')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	list := scope.values['list'] or { openui_null() }
	assert list.kind == .list
	assert list.items.len == 2
	assert openui_is_node(list.items[0])
}

fn test_openui_prompt_lists_components_and_root() {
	lib := new_openui_default_library()
	prompt := generate_system_prompt(lib, OpenuiPromptOptions{})
	assert prompt.contains('root = Stack(...)')
	assert prompt.contains('TextContent(')
	assert prompt.contains('@Count(')
}

fn test_openui_message_markers_last_wins() {
	raw := ']]>openui:content\nroot = Stack([a])\n]]>openui:content\nroot = Stack([b])\n]]>openui:end'
	stored := parse_openui_stored(raw)
	assert stored.content.contains('[b]')
	assert stored.finished
	assert strip_openui_markers('root = Stack([x])') == 'root = Stack([x])'
}

fn test_openui_renderer_root_element() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('root = Stack([title])\ntitle = TextContent("Hello")', false)
	element := renderer.root_element()
	assert element.children.len == 1
	assert renderer.last_info.errors.len == 0
}

fn test_openui_renderer_streaming_parity() {
	lib := new_openui_default_library()
	full := 'root = Stack([title, save])\ntitle = TextContent("Hello")\nsave = Button("Go", @ToAssistant("go"))'
	mut first := new_openui_renderer(lib)
	first.set_response(full, false)
	head := first.root_element()
	mut second := new_openui_renderer(lib)
	second.set_response('root = Stack([title, save])\ntitle = TextContent("Hello")', true)
	_ = second.root_element()
	second.set_response(full, false)
	tail := second.root_element()
	assert head.children.len == tail.children.len
	assert tail.children.len == 2
}

fn test_openui_renderer_button_action_wires_event() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('\$picked = "no"\nroot = Stack([go])\ngo = Button("Go", @Set(\$picked, "yes"))',
		false)
	element := renderer.root_element()
	assert element.children.len == 1
	button := element.children[0]
	assert button.action_id.len > 0
	assert renderer.handle_event(button.action_id)
	assert renderer.state['picked'] or { openui_null() }.string_value() == 'yes'
	assert !renderer.handle_event('missing')
}

fn test_openui_renderer_query_tool_and_set() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_tool('list_tickets', fn (_ map[string]OpenuiValue) OpenuiValue {
		return openui_object({
			'rows': openui_list([openui_object({
				'status': openui_string('open')
			})])
		})
	})
	renderer.set_response('\$filter = "open"\ndata = Query("list_tickets", {}, {rows: []})\nroot = Stack([n])\nn = TextContent("x " + @Count(data.rows))', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	assert element.children.len == 1
}
