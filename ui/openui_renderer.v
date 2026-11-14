module ui2

// OpenUI Lang renderer: parsed tree to `Element`, directly usable as a
// `run_window` build function. Re-parsing the full text on every chunk gives
// streaming for free; unresolved references resolve when their statements
// arrive.

pub type OpenuiActionHandler = fn (event OpenuiActionEvent)
pub type OpenuiErrorHandler = fn (errors []OpenuiError)

pub struct OpenuiActionEvent {
pub:
	kind       string
	message    string
	params     map[string]OpenuiValue
	form_state map[string]OpenuiValue
}

pub struct OpenuiRenderInfo {
pub:
	errors   []OpenuiError
	orphaned []string
}

pub struct OpenuiRenderer {
pub:
	library OpenuiLibrary
pub mut:
	tools     map[string]OpenuiToolFn
	funcs     map[string]OpenuiFuncImpl
	on_action OpenuiActionHandler = fn (_ OpenuiActionEvent) {}
	on_error  OpenuiErrorHandler  = fn (_ []OpenuiError) {}
	width     f64                 = 800.0
	state     map[string]OpenuiValue
	response  string
	streaming bool
mut:
	action_slots map[string][]OpenuiActionCall
	action_seq   int
	node_seq     int
	last_info    OpenuiRenderInfo
}

pub fn new_openui_renderer(library OpenuiLibrary) OpenuiRenderer {
	return OpenuiRenderer{
		library: library
	}
}

pub fn (mut renderer OpenuiRenderer) set_tool(name string, tool OpenuiToolFn) {
	renderer.tools[name] = tool
}

pub fn (mut renderer OpenuiRenderer) set_function(name string, func OpenuiFuncImpl) {
	renderer.funcs[name] = func
}

// set_response stores streamed text; render again to rebuild.

pub fn (mut renderer OpenuiRenderer) set_response(response string, streaming bool) {
	renderer.response = response
	renderer.streaming = streaming
}

fn (mut renderer OpenuiRenderer) register_action(steps []OpenuiActionCall) string {
	renderer.action_seq++
	id := 'openui_action_${renderer.action_seq}'
	renderer.action_slots[id] = steps.clone()
	return id
}

// ctx_action_id registers an action prop and returns the event identity for
// `with_action`. Component authors call it from render callbacks.

pub fn (mut renderer OpenuiRenderer) ctx_action_id(value OpenuiValue) string {
	if value.kind != .action {
		return ''
	}
	return renderer.register_action(value.steps)
}

fn (renderer &OpenuiRenderer) form_state() map[string]OpenuiValue {
	return renderer.state.clone()
}

// render parses, evaluates, and maps the root node to an `Element`. It never
// fails: problems come back as errors plus a fallback element.

pub fn (mut renderer OpenuiRenderer) render() (Element, OpenuiRenderInfo) {
	renderer.action_slots = map[string][]OpenuiActionCall{}
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or {
		info := OpenuiRenderInfo{
			errors: [OpenuiError{
				code:    openui_err_parse_failed
				message: err.msg()
			}]
		}
		renderer.last_info = info
		if !renderer.streaming {
			renderer.on_error(info.errors)
		}
		return renderer.fallback('No UI yet'), info
	}
	mut scope := new_openui_scope(renderer.library)
	scope.tools = renderer.tools.clone()
	scope.funcs = renderer.funcs.clone()
	for key, value in renderer.state {
		scope.state_values[key] = value
	}
	openui_eval_program(statements, mut scope)
	for key, value in scope.state_values {
		renderer.state[key] = value
	}
	root_value, entry_errors := renderer.find_root(statements, scope)
	mut errors := scope.errors.clone()
	errors << entry_errors
	if root_value.kind == .null_ || root_value.kind == .invalid || !openui_is_node(root_value) {
		info := OpenuiRenderInfo{
			errors:   errors
			orphaned: openui_orphaned(statements, scope)
		}
		renderer.last_info = info
		if !renderer.streaming {
			renderer.on_error(info.errors)
		}
		return renderer.fallback('Nothing to show'), info
	}
	element := renderer.render_node(root_value, 0, 0, renderer.width)
	info := OpenuiRenderInfo{
		errors:   errors
		orphaned: openui_orphaned(statements, scope)
	}
	renderer.last_info = info
	if !renderer.streaming {
		renderer.on_error(info.errors)
	}
	return element, info
}

fn (mut renderer OpenuiRenderer) fallback(text string) Element {
	return screen(0xffffff, [
		label('openui_fallback', text, rect(16, 16, renderer.width - 32, 28), TextStyle{}),
	])
}

// find_root resolves the `root` statement; without one, the first statement
// calling the library root component is the entry with a `no-root` warning.

fn (mut renderer OpenuiRenderer) find_root(statements []OpenuiStatement, scope OpenuiScope) (OpenuiValue, []OpenuiError) {
	if 'root' in scope.values {
		return scope.values['root'] or { openui_null() }, []OpenuiError{}
	}
	for statement in statements {
		if statement.name.starts_with('\$') {
			continue
		}
		value := scope.values[statement.name] or { continue }
		if openui_is_node(value) && openui_node_name(value) == renderer.library.root {
			return value, [OpenuiError{
				code:      openui_err_no_root
				message:   'no `root` statement; using `${statement.name}`'
				statement: statement.name
			}]
		}
	}
	return openui_null(), [OpenuiError{
		code:    openui_err_no_root
		message: 'no usable entry statement'
	}]
}

fn openui_orphaned(statements []OpenuiStatement, scope OpenuiScope) []string {
	mut reachable := map[string]bool{}
	mut stack := []string{}
	if 'root' in scope.values {
		stack << 'root'
	}
	for statement in statements {
		value := scope.values[statement.name] or { continue }
		if openui_is_node(value) {
			stack << statement.name
			break
		}
	}
	for stack.len > 0 {
		name := stack.pop()
		if name in reachable {
			continue
		}
		reachable[name] = true
		expr := scope.statements[name] or { continue }
		for dep in openui_expr_refs(expr) {
			if dep !in reachable {
				stack << dep
			}
		}
	}
	mut orphaned := []string{}
	for statement in statements {
		if statement.name.starts_with('\$') {
			continue
		}
		if statement.name !in reachable {
			orphaned << statement.name
		}
	}
	return orphaned
}

fn openui_expr_refs(expr &OpenuiExpr) []string {
	mut refs := []string{}
	match expr.kind {
		.ref {
			refs << expr.value
		}
		.state_ref, .literal {
		}
		.member {
			refs << openui_expr_refs(expr.target)
		}
		.unary {
			refs << openui_expr_refs(expr.left)
		}
		.binary {
			refs << openui_expr_refs(expr.left)
			refs << openui_expr_refs(expr.right)
		}
		.ternary {
			refs << openui_expr_refs(expr.left)
			refs << openui_expr_refs(expr.middle)
			refs << openui_expr_refs(expr.right)
		}
		.call, .at_call, .action_list {
			for arg in expr.args {
				refs << openui_expr_refs(arg)
			}
		}
		.array {
			for arg in expr.args {
				refs << openui_expr_refs(arg)
			}
		}
		.object {
			for key in expr.field_order {
				refs << openui_expr_refs(expr.fields[key] or { continue })
			}
		}
		.query, .mutation {
			for arg in expr.args {
				refs << openui_expr_refs(arg)
			}
		}
	}
	return refs
}

// render_node maps one evaluated node to an `Element`, stacking slot
// children vertically inside the component frame.

fn (mut renderer OpenuiRenderer) render_node(value OpenuiValue, x f64, y f64, width f64) Element {
	component := renderer.library.find(openui_node_name(value)) or {
		return view('openui_unknown', rect(x, y, width, 24), BoxStyle{}, [])
	}
	props := openui_node_props(value)
	slots := openui_node_slots(value)
	mut kids := []Element{}
	mut cursor := y + 8
	inner_x := x + 8
	inner_width := if width > 16 { width - 16 } else { width }
	for param in component.params {
		if param.schema.kind != .list {
			continue
		}
		items := slots[param.name] or { continue }
		for item in items {
			if !openui_is_node(item) {
				continue
			}
			child := renderer.render_node(item, inner_x, cursor, inner_width)
			cursor += child.frame.height + 8
			kids << child
		}
	}
	height := if kids.len > 0 {
		cursor - y + 8
	} else if height_fn := component.height_for_props {
		height_fn(props)
	} else {
		component.height
	}
	renderer.node_seq++
	ctx := OpenuiCtx{
		id:       'openui_${component.name}_${renderer.node_seq}'
		props:    props
		children: kids
		frame:    rect(x, y, width, height)
	}
	rendered := component.render(ctx)
	return renderer.wire_action(component, props, rendered)
}

// wire_action attaches the first action prop to the element identity, so
// taps arrive at handle_event without component authors writing wiring.

fn (mut renderer OpenuiRenderer) wire_action(component OpenuiComponent, props map[string]OpenuiValue, rendered Element) Element {
	if rendered.action_id.len > 0 {
		return rendered
	}
	for param in component.params {
		if param.schema.kind != .action {
			continue
		}
		action := props[param.name] or { continue }
		if action.kind != .action {
			continue
		}
		return with_action(rendered, renderer.register_action(action.steps))
	}
	return rendered
}

// root_element rebuilds from the latest response; use it as the build fn.

pub fn (mut renderer OpenuiRenderer) root_element() Element {
	element, _ := renderer.render()
	return element
}

// handle_event runs the action steps registered for an event id. It returns
// true when the id was known. State-changing steps (`@Set`, `@Reset`,
// `@Run`) mean the host should rebuild, usually via `refresh()`.

pub fn (mut renderer OpenuiRenderer) handle_event(event_id string) bool {
	steps := renderer.action_slots[event_id] or { return false }
	for step in steps {
		match step.name {
			'Set' {
				if step.args.len == 2 {
					key := step.args[0].text
					renderer.state[key] = step.args[1]
				}
			}
			'Reset' {
				for arg in step.args {
					if default_ := renderer.default_state(arg.text) {
						renderer.state[arg.text] = default_
					}
				}
			}
			'Run' {
				if step.args.len == 1 {
					renderer.run_tool(step.args[0].text)
				}
			}
			'ToAssistant' {
				mut params := map[string]OpenuiValue{}
				if step.args.len > 1 {
					params['context'] = step.args[1]
				}
				renderer.on_action(OpenuiActionEvent{
					kind:       'continue_conversation'
					message:    step.args[0].string_value()
					params:     params
					form_state: renderer.form_state()
				})
			}
			'OpenUrl' {
				renderer.on_action(OpenuiActionEvent{
					kind:       'open_url'
					message:    step.args[0].string_value()
					params:     {
						'url': step.args[0]
					}
					form_state: renderer.form_state()
				})
			}
			else {
				mut params := map[string]OpenuiValue{}
				action := renderer.library_action(step.name)
				for index, param in action.params {
					if index < step.args.len {
						params[param.name] = step.args[index]
					}
				}
				renderer.on_action(OpenuiActionEvent{
					kind:       step.name
					message:    ''
					params:     params
					form_state: renderer.form_state()
				})
			}
		}
	}
	return true
}

fn (renderer &OpenuiRenderer) default_state(key string) ?OpenuiValue {
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or { return none }
	for statement in statements {
		if statement.name == '\$' + key {
			mut scope := new_openui_scope(renderer.library)
			scope.tools = renderer.tools.clone()
			scope.funcs = renderer.funcs.clone()
			openui_eval_program(statements, mut scope)
			if value := scope.state_defaults[key] {
				return value
			}
			return none
		}
	}
	return none
}

fn (mut renderer OpenuiRenderer) run_tool(name string) {
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or { return }
	mut scope := new_openui_scope(renderer.library)
	scope.tools = renderer.tools.clone()
	scope.funcs = renderer.funcs.clone()
	for key, value in renderer.state {
		scope.state_values[key] = value
	}
	// Re-evaluation re-runs Queries with current `$var` args by itself;
	// a Mutation needs an explicit tool call here.
	openui_eval_program(statements, mut scope)
	for key, value in scope.state_values {
		renderer.state[key] = value
	}
	mutation := scope.statements[name] or { return }
	if mutation.kind != .mutation {
		return
	}
	scope.nested++
	tool_name := scope.eval_expr(mutation.args[0], name)
	mut plain := map[string]OpenuiValue{}
	if mutation.args.len > 1 {
		call_args := scope.eval_expr(mutation.args[1], name)
		if call_args.kind == .object {
			for key, value in call_args.fields {
				plain[key] = value
			}
		}
	}
	scope.nested--
	if tool := scope.tools[tool_name.text] {
		_ = tool(plain)
	}
}

fn (renderer &OpenuiRenderer) library_action(name string) OpenuiCustomAction {
	for action in renderer.library.actions {
		if action.name == name {
			return action
		}
	}
	return OpenuiCustomAction{
		name: name
	}
}
