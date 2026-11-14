module ui2

// OpenUI Lang renderer: parsed tree to `Element`, directly usable as a
// `run_window` build function. Re-parsing the full text on every chunk gives
// streaming for free; unresolved references resolve when their statements
// arrive.

pub type OpenuiActionHandler = fn (event OpenuiActionEvent)
pub type OpenuiErrorHandler = fn (errors []OpenuiError)

// openui_default_live_text reads the live control value. It returns ''
// for ids with no mounted control, which includes every headless render.

fn openui_default_live_text(id string) string {
	return text(id)
}

pub type OpenuiLiveTextFn = fn (id string) string

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
	// live_text reads the live control value for write-back. Hosts and
	// tests can inject a source (e.g. seeded headless state); the default
	// reads the mounted control and returns '' when there is none.
	live_text OpenuiLiveTextFn = openui_default_live_text
mut:
	action_slots map[string][]OpenuiActionCall
	action_seq   int
	node_seq     int
	// Ids are deterministic per render: counters restart on every render
	// so the same tree mints the same element and action ids. Events are
	// dispatched synchronously against the live tree, so a stale id can
	// only come from replaying an id across a rebuild — and handle_event's
	// false return flags exactly that.
	// input_bindings maps a rendered element id to the `$variable` key its
	// edits write back to. Rebuilt on every render like action_slots.
	input_bindings map[string]string
	// dirty tracks `$variable`s the user changed (Set actions, input
	// write-backs). Only dirty keys survive a re-render; the rest take
	// the response's current defaults. Reset clears the dirty mark.
	dirty     map[string]bool
	last_info OpenuiRenderInfo
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
	renderer.input_bindings = map[string]string{}
	renderer.action_seq = 0
	renderer.node_seq = 0
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
	// Only user-edited keys survive a re-render, seeded into the fresh
	// scope. Everything else takes the response's current defaults, so a
	// revised `$default` applies on the next render while edits persist.
	// Dirty marks clear only on Reset, never automatically: an edit
	// outlives any number of streaming chunks until explicitly reset.
	for key, _ in renderer.dirty {
		if value := renderer.state[key] {
			scope.state_values[key] = value
		}
	}
	openui_eval_program(statements, mut scope)
	renderer.state = scope.state_values.clone()
	root_value, entry_errors := renderer.find_root(statements, scope)
	mut errors := scope.errors.clone()
	errors << entry_errors
	if root_value.kind == .null_ || root_value.kind == .invalid || !openui_is_node(root_value) {
		info := OpenuiRenderInfo{
			errors:   errors
			orphaned: openui_orphaned(statements, scope, renderer.library.root)
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
		orphaned: openui_orphaned(statements, scope, renderer.library.root)
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

fn openui_orphaned(statements []OpenuiStatement, scope OpenuiScope, root_component string) []string {
	mut reachable := map[string]bool{}
	mut stack := []string{}
	if 'root' in scope.values {
		stack << 'root'
	}
	// Without `root`, seed from the first node calling the root component
	// (the same rule `find_root` uses), else the entry itself is reported
	// orphaned. Fall back to the first node of any kind.
	mut seeded := false
	for statement in statements {
		value := scope.values[statement.name] or { continue }
		if openui_is_node(value) && openui_node_name(value) == root_component {
			stack << statement.name
			seeded = true
			break
		}
	}
	if !seeded {
		for statement in statements {
			value := scope.values[statement.name] or { continue }
			if openui_is_node(value) {
				stack << statement.name
				break
			}
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
	renderer.wire_binds(value, ctx.id)
	return renderer.wire_action(component, props, rendered)
}

// wire_binds records `$variable` write-back targets for the rendered id.

fn (mut renderer OpenuiRenderer) wire_binds(value OpenuiValue, id string) {
	binds := openui_node_binds(value)
	if binds.len == 0 {
		return
	}
	if key := binds['value'] {
		renderer.input_bindings[id] = key
		return
	}
	for _, key in binds {
		renderer.input_bindings[id] = key
		return
	}
}

fn (mut renderer OpenuiRenderer) wire_action(component OpenuiComponent, props map[string]OpenuiValue, rendered Element) Element {
	// Attaches the first action prop to the element identity, so taps
	// arrive at handle_event without component authors writing wiring.
	// Steps register under the element id itself (not a fresh id) so an
	// Input with `on_change` writes back and runs its steps on the same
	// event. Anonymous elements (no id) keep a minted identity.
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
		if rendered.id.len > 0 {
			renderer.action_slots[rendered.id] = action.steps.clone()
			return with_action(rendered, rendered.id)
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
	steps := renderer.action_slots[event_id] or { []OpenuiActionCall{} }
	var_key := renderer.input_bindings[event_id] or { '' }
	if steps.len == 0 && var_key.len == 0 {
		return false
	}
	// Control edits land in the bound `$variable` before actions run, so
	// `@ToAssistant` and `@Run` observe the fresh value. The mark keeps
	// the edit across re-renders; Reset clears it.
	if var_key.len > 0 {
		renderer.state[var_key] = openui_string(renderer.live_text(event_id))
		renderer.dirty[var_key] = true
	}
	for step in steps {
		match step.name {
			'Set' {
				if step.args.len == 2 {
					key := step.args[0].text
					renderer.state[key] = step.args[1]
					renderer.dirty[key] = true
				}
			}
			'Reset' {
				defaults := renderer.fresh_defaults()
				for arg in step.args {
					if default_ := defaults[arg.text] {
						renderer.state[arg.text] = default_
						renderer.dirty.delete(arg.text)
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

// fresh_defaults evaluates the current response once in a clean scope and
// returns its `$variable` defaults. Reset restores from here (single
// parse+eval per event, not per key) instead of the live edited state.

fn (mut renderer OpenuiRenderer) fresh_defaults() map[string]OpenuiValue {
	mut defaults := map[string]OpenuiValue{}
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or { return defaults }
	mut scope := new_openui_scope(renderer.library)
	scope.tools = renderer.tools.clone()
	scope.funcs = renderer.funcs.clone()
	openui_eval_program(statements, mut scope)
	return scope.state_defaults.clone()
}

fn (mut renderer OpenuiRenderer) run_tool(name string) {
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or { return }
	mut scope := new_openui_scope(renderer.library)
	scope.tools = renderer.tools.clone()
	scope.funcs = renderer.funcs.clone()
	for key, _ in renderer.dirty {
		if value := renderer.state[key] {
			scope.state_values[key] = value
		}
	}
	// Re-evaluation re-runs Queries with current `$var` args by itself;
	// a Mutation needs an explicit tool call here.
	openui_eval_program(statements, mut scope)
	for key, value in scope.state_values {
		renderer.state[key] = value
	}
	mutation := scope.statements[name] or { return }
	if mutation.kind != .mutation || mutation.args.len == 0 {
		return
	}
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
