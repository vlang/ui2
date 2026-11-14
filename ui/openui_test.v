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
				openui_object({
					'status': openui_string('open')
				}),
			])
		})
	}
	statements := parse_openui_program('data = Query("list", {}, {rows: []})\nopen = @Filter(data.rows, "status", "==", "open")\ncount = @Count(open)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	count := scope.values['count'] or { openui_null() }
	assert count.kind == .number
	// Two open rows: flipping == to != would yield 1, not 2.
	assert count.number == 2.0
	kept := scope.values['open'] or { openui_null() }
	assert kept.kind == .list
	assert kept.items.len == 2
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
	for name in ['Stack(', 'Card(', 'TextContent(', 'Button(', 'Table(', 'Chart(', 'Input(', 'Select('] {
		assert prompt.contains(name), 'missing ${name}'
	}
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
	assert element.kind == .view
	assert element.children[0].kind == .label
	assert element.children[0].text == 'Hello'
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
	// "x 1" proves the tool ran: the {rows: []} default would show "x 0".
	assert element.children[0].text == 'x 1'
}

fn test_openui_table_renders_header_and_rows() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('rows = [{title: "Login fails", status: "open"}, {title: "Dark mode", status: "shut"}]\nroot = Stack([grid])\ngrid = Table(rows)', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	assert element.children.len == 1
	grid := element.children[0]
	assert grid.children.len == 2 + 2 * 2
}

fn test_openui_chart_renders_from_values() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('root = Stack([sales])\nsales = Chart("bar", ["Jan", "Feb"], [12, 19], "Sales")', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	assert element.children.len == 1
	sales := element.children[0]
	assert sales.children.len > 0
}

fn openui_test_live_text(_ string) string {
	return 'typed!'
}

fn test_openui_input_binds_variable_round_trip() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.live_text = openui_test_live_text
	renderer.set_response('\$query = "login"\nroot = Stack([search])\nsearch = Input(\$query, "Search tickets")', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	assert element.children.len == 1
	field := element.children[0]
	assert field.kind == .text_field
	assert field.text == 'login'
	assert renderer.input_bindings[field.id] == 'query'
	assert renderer.handle_event(field.id)
	assert renderer.state['query'] or { openui_null() }.string_value() == 'typed!'
}

fn test_openui_input_action_runs_after_write_back() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.live_text = openui_test_live_text
	renderer.set_response('\$query = "login"\n\$picked = "no"\nroot = Stack([search])\nsearch = Input(\$query, "Search", @Set(\$picked, "yes"))', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	field := element.children[0]
	// The action registers under the element id itself, so one event
	// both writes the edit back and runs the steps.
	assert field.action_id == field.id
	assert renderer.handle_event(field.id)
	assert renderer.state['query'] or { openui_null() }.string_value() == 'typed!'
	assert renderer.state['picked'] or { openui_null() }.string_value() == 'yes'
}

fn test_openui_input_rejects_plain_values() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = Stack([search])\nsearch = Input("literal")')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
}

fn test_openui_select_renders_dropdown() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.live_text = openui_test_live_text
	renderer.set_response('\$choice = "open"\nroot = Stack([pick])\npick = Select(\$choice, ["open", "shut"])', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	assert element.children.len == 1
	pick := element.children[0]
	assert pick.kind == .dropdown
	assert pick.text == 'open'
	assert renderer.input_bindings[pick.id] == 'choice'
	assert renderer.handle_event(pick.id)
	assert renderer.state['choice'] or { openui_null() }.string_value() == 'typed!'
}

fn test_openui_select_rejects_plain_value() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = Stack([pick])\npick = Select("open", ["open", "shut"])')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
}

fn test_openui_unknown_reference_is_loud() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = Stack([titel])\ntitle = TextContent("Hi")')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_unknown_reference)
	root := scope.values['root'] or { openui_null() }
	assert !openui_is_node(root) || openui_node_slots(root).len == 0
}

fn test_openui_bare_ident_in_text_is_loud() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = TextContent(hello)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_unknown_reference)
}

fn test_openui_unterminated_string_fails_closed() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('root = TextContent("abc)', false)
	_, info := renderer.render()
	assert info.errors.any(it.code == openui_err_parse_failed)
}

fn test_openui_query_arity_is_checked() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('q = Query("search", {})')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
	assert scope.values['q'] or { openui_null() }.kind == .null_
}

fn test_openui_run_empty_mutation_is_safe() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('m = Mutation()\nroot = Stack([go])\ngo = Button("Go", @Run(m))', false)
	element := renderer.root_element()
	button := element.children[0]
	assert renderer.handle_event(button.action_id)
}

fn test_openui_deep_nesting_fails_closed() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('root = TextContent(' + '('.repeat(300) + '"hi"' + ')'.repeat(300) + ')', false)
	_, info := renderer.render()
	assert info.errors.any(it.code == openui_err_parse_failed)
}

fn test_openui_deep_ref_chain_fails_closed() {
	mut lines := []string{}
	for i := 0; i < 250; i++ {
		lines << 'a${i} = a${i + 1}'
	}
	lines << 'a250 = 1'
	lines << 'root = TextContent("x")'
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program(lines.join('\n'))!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_runtime)
}

fn test_openui_round_precision_is_capped() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('a = @Round(1.2345, 1000000000)\nb = @Round(1.2345, 15)\nc = @Round(1.6, -2)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	a := scope.values['a'] or { openui_null() }
	b := scope.values['b'] or { openui_null() }
	assert a.kind == .number
	assert a.number == b.number
	c := scope.values['c'] or { openui_null() }
	assert c.number == 2.0
}

fn test_openui_sort_is_correct_and_scales() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	mut rows := []string{}
	for i := 1999; i >= 0; i-- {
		rows << '{"n": "${i}"}'
	}
	statements := parse_openui_program('items = [${rows.join(', ')}]\nasc = @Sort(items, "n", "asc")\ndesc = @Sort(items, "n", "desc")')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	asc := scope.values['asc'] or { openui_null() }
	assert asc.items.len == 2000
	assert asc.items[0].fields['n'] or { openui_null() }.string_value() == '0'
	assert asc.items[1999].fields['n'] or { openui_null() }.string_value() == '999'
	desc := scope.values['desc'] or { openui_null() }
	assert desc.items[0].fields['n'] or { openui_null() }.string_value() == '999'
}

fn test_openui_table_truncates_rows_and_columns() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	mut cells := []string{}
	for i := 0; i < 40; i++ {
		cells << '"c${i}": "${i}"'
	}
	row := '{${cells.join(', ')}}'
	mut rows := []string{}
	for _ in 0 .. 25 {
		rows << row
	}
	renderer.set_response('rows = [${rows.join(', ')}]\nroot = Stack([grid])\ngrid = Table(rows)', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	grid := element.children[0]
	// 32 capped header labels + 20 rows x 32 cells + 1 footer note.
	assert grid.children.len == 32 + 20 * 32 + 1
	footer := grid.children[grid.children.len - 1]
	assert footer.text.contains('more') || footer.text.contains('columns')
}

fn test_openui_table_single_node_row_errors() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('t = TextContent("hi")\nroot = Stack([grid])\ngrid = Table(t)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
}

fn test_openui_stack_of_strings_errors() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('root = Stack(["a", "b"])')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
}

fn test_openui_each_nulls_drop_silently() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	// `null` rows never reach data slots: the component-arg partition
	// drops them per the streaming no-null-holes rule.
	statements := parse_openui_program('rows = [{a: "1"}, null, {a: "2"}]\nroot = Stack([grid])\ngrid = Table(rows)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	grid := scope.values['grid'] or { openui_null() }
	assert openui_is_node(grid)
	assert openui_node_props(grid)['rows'] or { openui_null() }.items.len == 2
}

fn test_openui_two_binds_rejected() {
	mut lib := new_openui_default_library()
	lib.register(OpenuiComponent{
		name:        'Dual'
		description: 'Two binds.'
		params:      [
			OpenuiParam{
				name:   'first'
				schema: openui_bind_schema()
			},
			OpenuiParam{
				name:   'second'
				schema: openui_bind_schema()
			},
		]
		render:      openui_render_text_content
	})
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('\$a = "x"\n\$b = "y"\nroot = Stack([d])\nd = Dual(\$a, \$b)')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_type_mismatch)
}

fn test_openui_custom_function_null_skips_optional() {
	mut lib := new_openui_default_library()
	lib.functions << OpenuiFunction{
		name:        'Shout'
		description: 'Shouts.'
		params:      [
			OpenuiFuncParam{
				name:   'text'
				schema: openui_string_schema()
			},
			OpenuiFuncParam{
				name:     'loud'
				schema:   openui_string_schema()
				optional: true
			},
		]
	}
	mut scope := new_openui_scope(lib)
	scope.funcs['Shout'] = fn (args map[string]OpenuiValue) OpenuiValue {
		return openui_string(args['text'] or { openui_string('') }.string_value())
	}
	statements := parse_openui_program('root = TextContent(@Shout("hi", null))')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	root := scope.values['root'] or { openui_null() }
	assert openui_is_node(root)
	assert openui_node_props(root)['text'] or { openui_null() }.string_value() == 'hi'
}

fn test_openui_error_codes_covered() {
	cases := {
		'missing-required': 'root = Button()'
		'null-required':    'root = Button(null)'
		'excess-args':      'root = TextContent("a", "b", "c", "d")'
		'unknown-function': 'root = TextContent(@Nope("a"))'
		'runtime-error':    'x = 1 / 0\nroot = TextContent("t")'
		'tool-not-found':   'q = Query("missing", {}, {rows: []})\nroot = TextContent("t")'
	}
	for code, program in cases {
		lib := new_openui_default_library()
		mut scope := new_openui_scope(lib)
		statements := parse_openui_program(program)!
		openui_eval_program(statements, mut scope)
		assert scope.errors.any(it.code == code), 'missing ${code}'
	}
}

fn test_openui_inline_reserved_query() {
	lib := new_openui_default_library()
	mut scope := new_openui_scope(lib)
	statements := parse_openui_program('q = Query("t", {}, {rows: []})\nroot = Stack([q])\nwrap = [Query("t", {}, {rows: []})]')!
	openui_eval_program(statements, mut scope)
	assert scope.errors.any(it.code == openui_err_inline_reserved)
}

fn test_openui_message_context_and_unknown_markers() {
	stored := parse_openui_stored(']]>openui:content\nroot = Stack([a])\n]]>openui:weird\nkept\n]]>openui:context\n{"a": 1}\n]]>openui:end')
	assert stored.content.contains('kept')
	assert stored.context == '{"a": 1}'
	assert stored.finished
	assert stored.has_stream
}

fn test_openui_prompt_gating_variants() {
	lib := new_openui_default_library()
	off := generate_system_prompt(lib, OpenuiPromptOptions{
		tool_calls: false
		bindings:   false
	})
	assert !off.contains('@Count(')
	assert off.contains('TextContent(')
	on := generate_system_prompt(lib, OpenuiPromptOptions{
		tool_calls:        false
		bindings:          false
		builtin_functions: true
	})
	assert on.contains('@Count(')
}

fn test_openui_no_root_fallback_and_orphans() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('t = TextContent("hi")\ns = Stack([t])', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.any(it.code == openui_err_no_root)
	assert element.children.len == 1
	// The entry itself is reachable; the earlier sibling is not orphaned
	// by the entry rule (it is unreachable from the entry).
	assert !('s' in renderer.last_info.orphaned)
	assert 't' !in renderer.last_info.orphaned
}

fn test_openui_streaming_query_parity() {
	new_tool := fn (_ map[string]OpenuiValue) OpenuiValue {
		return openui_object({
			'rows': openui_list([openui_object({
				'status': openui_string('open')
			})])
		})
	}
	lib := new_openui_default_library()
	full := '\$f = "open"\ndata = Query("list", {}, {rows: []})\nroot = Stack([n])\nn = TextContent("x " + @Count(@Filter(data.rows, "status", "==", \$f)))'
	mut streamed := new_openui_renderer(lib)
	streamed.set_tool('list', new_tool)
	streamed.set_response('\$f = "open"\ndata = Query("list", {}, {rows: []})', true)
	_ = streamed.root_element()
	streamed.set_response(full, false)
	head := streamed.root_element()
	mut fresh := new_openui_renderer(lib)
	fresh.set_tool('list', new_tool)
	fresh.set_response(full, false)
	tail := fresh.root_element()
	assert head.children.len == tail.children.len
	assert head.children[0].text == tail.children[0].text
	assert tail.children[0].text == 'x 1'
}

fn test_openui_reset_restores_and_clears_dirty() {
	lib := new_openui_default_library()
	mut renderer := new_openui_renderer(lib)
	renderer.set_response('\$q = "a"\nroot = Stack([go, back])\ngo = Button("Go", @Set(\$q, "b"))\nback = Button("Back", @Reset(\$q))', false)
	element := renderer.root_element()
	assert element.children.len == 2
	go_btn := element.children[0]
	back := element.children[1]
	assert renderer.handle_event(go_btn.action_id)
	assert renderer.state['q'] or { openui_null() }.string_value() == 'b'
	// A revised default does not clobber the user edit ...
	renderer.set_response('\$q = "z"\nroot = Stack([go, back])\ngo = Button("Go", @Set(\$q, "b"))\nback = Button("Back", @Reset(\$q))', false)
	_ = renderer.root_element()
	assert renderer.state['q'] or { openui_null() }.string_value() == 'b'
	// ... but Reset restores the revised default and clears the mark,
	// so the next revision applies again.
	assert renderer.handle_event(back.action_id)
	assert renderer.state['q'] or { openui_null() }.string_value() == 'z'
	renderer.set_response('\$q = "w"\nroot = Stack([go, back])\ngo = Button("Go", @Set(\$q, "b"))\nback = Button("Back", @Reset(\$q))', false)
	_ = renderer.root_element()
	assert renderer.state['q'] or { openui_null() }.string_value() == 'w'
}
