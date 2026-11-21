module ui2

// Regressions for the Copilot findings fixed on the OpenUI Lang renderer,
// parser, prompt, and predefined components.

struct OpenuiFixCounter {
mut:
	n int
}

struct OpenuiFixSink {
mut:
	messages []string
	errors   []OpenuiError
}

fn openui_fix_live_text(_ string) string {
	return 'typed!'
}

fn test_openui_fix_numeric_rejects_invalid_text() {
	valid := openui_string('12').numeric() or { -999.0 }
	assert valid == 12.0
	invalid := openui_string('abc').numeric() or { -999.0 }
	assert invalid == -999.0
	trailing := openui_string('12abc').numeric() or { -999.0 }
	assert trailing == -999.0
}

fn test_openui_fix_single_comparison_operators_tokenize() {
	statements := parse_openui_program('big = 2 > 1\nsmall = 1 < 2')!
	assert statements.len == 2
	mut scope := new_openui_scope(new_openui_default_library())
	openui_eval_program(statements, mut scope)
	assert scope.errors.len == 0
	assert (scope.values['big'] or { openui_null() }).bool_
	assert (scope.values['small'] or { openui_null() }).bool_
}

fn test_openui_fix_optional_preserves_node_slot() {
	schema := openui_optional(openui_node_schema(), openui_null())
	assert schema.node_slot
	list := openui_list_schema(schema)
	assert !isnil(list.element)
	assert list.element.node_slot
}

fn test_openui_fix_inferred_columns_show_truncation_footer() {
	mut renderer := new_openui_renderer(new_openui_default_library())
	mut cells := []string{}
	for i := 0; i < 40; i++ {
		cells << '"c${i}": "${i}"'
	}
	renderer.set_response('rows = [{${cells.join(', ')}}]\nroot = Stack([grid])\ngrid = Table(rows)', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	grid := element.children[0]
	footer := grid.children[grid.children.len - 1]
	assert footer.text.contains('columns'), footer.text
}

fn test_openui_fix_empty_table_has_unique_empty_id() {
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.set_response('root = Stack([grid])\ngrid = Table([])', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	grid := element.children[0]
	assert grid.children.len == 1
	assert grid.children[0].id != grid.id
}

fn test_openui_fix_prompt_emits_ungrouped_components() {
	mut lib := new_openui_default_library()
	lib.groups = [OpenuiGroup{
		name:       'Layout'
		components: ['Stack']
	}]
	derived := lib.extend(OpenuiExtendConfig{
		add_components: [OpenuiComponent{
			name:        'Badge'
			description: 'A small badge.'
			params:      []
			render:      openui_render_text_content
		}]
	})
	prompt := generate_system_prompt(derived, OpenuiPromptOptions{})
	assert prompt.contains('Badge(')
	assert prompt.contains('TextContent(')
	assert prompt.contains('### Other components')
	assert prompt.contains('bare calls')
}

fn test_openui_fix_explicit_root_keeps_siblings_orphaned() {
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.set_response('unused = Stack([extra])\nextra = TextContent("x")\nroot = Stack([title])\ntitle = TextContent("Hi")', false)
	_, info := renderer.render()
	assert 'unused' in info.orphaned
	assert 'extra' in info.orphaned
}

fn test_openui_fix_render_budget_fails_closed() {
	mut lines := ['a0 = TextContent("x")']
	for i := 1; i < 12; i++ {
		lines << 'a${i} = Stack([a${i - 1}, a${i - 1}])'
	}
	lines << 'root = a11'
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.set_response(lines.join('\n'), false)
	_, info := renderer.render()
	assert info.errors.any(it.code == openui_err_runtime)
}

fn test_openui_fix_nested_child_frames_are_local() {
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.set_response('root = Stack([outer])\nouter = Stack([inner])\ninner = TextContent("Hi")', false)
	element := renderer.root_element()
	assert renderer.last_info.errors.len == 0
	outer := element.children[0]
	assert outer.children.len == 1
	inner := outer.children[0]
	assert inner.frame.x == 8
	assert inner.frame.y == 8
	assert outer.frame.height > inner.frame.height
}

fn test_openui_fix_streaming_truncated_chunk_keeps_ui() {
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.set_response('root = Stack([title])\ntitle = TextContent("Hello")', true)
	head := renderer.root_element()
	assert head.children.len == 1
	renderer.set_response('root = Stack([title])\ntitle = TextContent("Hel', true)
	mid := renderer.root_element()
	assert mid.children.len == 1
	assert mid.children[0].text == 'Hello'
	renderer.set_response('root = TextContent("abc)', false)
	_, info := renderer.render()
	assert info.errors.any(it.code == openui_err_parse_failed)
}

fn test_openui_fix_query_cached_across_renders() {
	mut counter := &OpenuiFixCounter{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	tool := fn [mut counter] (_ map[string]OpenuiValue) OpenuiValue {
		counter.n++
		return openui_object({
			'rows': openui_list([openui_object({
				'status': openui_string('open')
			})])
		})
	}
	renderer.set_tool('list', tool)
	renderer.set_response('$f = "open"\ndata = Query("list", {f: $f}, {rows: []})\nroot = Stack([n])\nn = TextContent("x " + @Count(data.rows))', false)
	_ = renderer.root_element()
	assert counter.n == 1
	_ = renderer.root_element()
	assert counter.n == 1, 'unchanged Query args must reuse the cached result'
	// A changed dependency is a new effective argument.
	renderer.set_response('$f = "shut"\ndata = Query("list", {f: $f}, {rows: []})\nroot = Stack([n])\nn = TextContent("x " + @Count(data.rows))', false)
	_ = renderer.root_element()
	assert counter.n == 2
}

fn test_openui_fix_query_explicit_refetch() {
	mut counter := &OpenuiFixCounter{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	tool := fn [mut counter] (_ map[string]OpenuiValue) OpenuiValue {
		counter.n++
		return openui_object({
			'rows': openui_list([openui_object({
				'status': openui_string('open')
			})])
		})
	}
	renderer.set_tool('list', tool)
	renderer.set_response('data = Query("list", {}, {rows: []})\nroot = Stack([go])\ngo = Button("Go", @Run(data))', false)
	element := renderer.root_element()
	assert counter.n == 1
	button := element.children[0]
	assert renderer.handle_event(button.action_id)
	assert counter.n == 2
}

fn test_openui_fix_action_args_use_current_state() {
	mut sink := &OpenuiFixSink{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.live_text = openui_fix_live_text
	renderer.on_action = fn [mut sink] (event OpenuiActionEvent) {
		sink.messages << event.message
	}
	renderer.set_response('$q = "before"\nroot = Stack([search])\nsearch = Input($q, "Search", @ToAssistant($q))', false)
	element := renderer.root_element()
	field := element.children[0]
	assert renderer.handle_event(field.id)
	assert sink.messages.len == 1
	assert sink.messages[0] == 'typed!'
}

fn test_openui_fix_sequential_set_action_sees_current_state() {
	mut sink := &OpenuiFixSink{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.on_action = fn [mut sink] (event OpenuiActionEvent) {
		sink.messages << event.message
	}
	renderer.set_response('$q = "a"\nroot = Stack([go])\ngo = Button("Go", Action([@Set($q, "b"), @ToAssistant($q)]))', false)
	element := renderer.root_element()
	button := element.children[0]
	assert renderer.handle_event(button.action_id)
	assert sink.messages.len == 1
	assert sink.messages[0] == 'b'
}

fn test_openui_fix_missing_mutation_tool_reports_error() {
	mut sink := &OpenuiFixSink{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.on_error = fn [mut sink] (errors []OpenuiError) {
		sink.errors << errors.clone()
	}
	renderer.set_response('m = Mutation("missing_tool", {})\nroot = Stack([go])\ngo = Button("Go", @Run(m))', false)
	element := renderer.root_element()
	sink.errors.clear()
	button := element.children[0]
	assert renderer.handle_event(button.action_id)
	assert sink.errors.any(it.code == openui_err_tool_not_found)
}

fn test_openui_fix_failed_mutation_stops_action_sequence() {
	mut sink := &OpenuiFixSink{}
	mut renderer := new_openui_renderer(new_openui_default_library())
	renderer.on_action = fn [mut sink] (event OpenuiActionEvent) {
		sink.messages << event.message
	}
	renderer.on_error = fn [mut sink] (errors []OpenuiError) {
		sink.errors << errors.clone()
	}
	renderer.set_response('m = Mutation("missing_tool", {})\nroot = Stack([go])\ngo = Button("Go", Action([@Run(m), @ToAssistant("done")]))', false)
	element := renderer.root_element()
	sink.errors.clear()
	button := element.children[0]
	assert renderer.handle_event(button.action_id)
	assert sink.errors.any(it.code == openui_err_tool_not_found)
	assert sink.messages.len == 0, 'a failed mutation must stop later steps'
}
