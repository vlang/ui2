module ui2

// OpenUI Lang renderer: parsed tree to `Element`, directly usable as a
// `run_window` build function. Re-parsing the full text on every chunk gives
// streaming for free; unresolved references resolve when their statements
// arrive.

pub type OpenuiActionHandler = fn (event OpenuiActionEvent)
pub type OpenuiErrorHandler = fn (errors []OpenuiError)

// A single node reference can expand to two children, so a short program can
// otherwise build exponentially many Elements. Bound both fan-out and depth.
const openui_max_render_nodes = 512
const openui_max_render_depth = 32
const openui_max_query_cache_entries = 128

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
	// last_good_response is replayed when a streaming chunk is truncated
	// mid-token; the completed prefix stays on screen until it parses.
	last_good_response string
	// query_cache memoizes tool calls by tool name + effective arguments.
	// Queries in later renders (including Reset/Run's re-evaluation) reuse
	// the value until an argument changes or @Run refetches explicitly.
	query_cache     map[string]OpenuiValue
	render_nodes    int
	render_overflow bool
}

pub fn new_openui_renderer(library OpenuiLibrary) OpenuiRenderer {
	return OpenuiRenderer{
		library: library
	}
}

pub fn (mut renderer OpenuiRenderer) set_tool(name string, tool OpenuiToolFn) {
	renderer.tools[name] = tool
	// A replacement tool must not inherit memoized results from the old one.
	renderer.query_cache = map[string]OpenuiValue{}
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

// Cache keys are canonical so two renders with the same effective tool
// arguments share one result, while any changed argument refetches.

fn openui_value_cache_key(value OpenuiValue) string {
	mut key := value.kind.str() + ':'
	match value.kind {
		.string_, .bind {
			key += value.text
		}
		.number {
			key += value.number.str()
		}
		.bool_ {
			key += value.bool_.str()
		}
		.list {
			for item in value.items {
				key += '[' + openui_value_cache_key(item) + ']'
			}
		}
		.object {
			mut fields := value.fields.keys()
			fields.sort()
			for field in fields {
				item := value.fields[field] or { openui_null() }
				key += field + '=' + openui_value_cache_key(item) + ';'
			}
		}
		.action {
			for step in value.steps {
				key += step.name + '('
				for arg in step.args {
					key += openui_value_cache_key(arg) + ','
				}
				key += ');'
			}
		}
		.null_, .invalid {}
	}
	return key
}

fn openui_args_cache_key(args map[string]OpenuiValue) string {
	mut keys := args.keys()
	keys.sort()
	mut parts := []string{cap: keys.len}
	for key in keys {
		value := args[key] or { openui_null() }
		parts << '${key}=${openui_value_cache_key(value)}'
	}
	return parts.join('&')
}

// eval_scope builds a fresh evaluation scope whose tools memoize by
// arguments. Every render, Reset, and Run re-evaluates the program, but only
// a Query with new arguments reaches the host tool again.

fn (mut renderer OpenuiRenderer) eval_scope() OpenuiScope {
	mut scope := new_openui_scope(renderer.library)
	mut cache := renderer.query_cache
	for name, tool in renderer.tools {
		scope.tools[name] = fn [mut cache, name, tool] (args map[string]OpenuiValue) OpenuiValue {
			key := name + '|' + openui_args_cache_key(args)
			if cached := cache[key] {
				return cached
			}
			value := tool(args)
			if cache.len < openui_max_query_cache_entries {
				cache[key] = value
			}
			return value
		}
	}
	scope.funcs = renderer.funcs.clone()
	return scope
}

fn (mut renderer OpenuiRenderer) report_errors(errors []OpenuiError) {
	if !renderer.streaming {
		renderer.on_error(errors)
	}
}

// render parses, evaluates, and maps the root node to an `Element`. It never
// fails: problems come back as errors plus a fallback element.

fn (mut renderer OpenuiRenderer) parse_failure(message string) (Element, OpenuiRenderInfo) {
	info := OpenuiRenderInfo{
		errors: [OpenuiError{
			code:    openui_err_parse_failed
			message: message
		}]
	}
	renderer.last_info = info
	renderer.report_errors(info.errors)
	return renderer.fallback('No UI yet'), info
}

pub fn (mut renderer OpenuiRenderer) render() (Element, OpenuiRenderInfo) {
	renderer.action_slots = map[string][]OpenuiActionCall{}
	renderer.input_bindings = map[string]string{}
	renderer.action_seq = 0
	renderer.node_seq = 0
	renderer.render_nodes = 0
	renderer.render_overflow = false
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or {
		// A token stream frequently ends inside a string or call. Replay the
		// last complete program while streaming so normal token chunks never
		// blank a finished layout; the final response still fails strictly.
		if renderer.streaming && renderer.last_good_response.len > 0 {
			parse_openui_program(renderer.last_good_response) or {
				return renderer.parse_failure(err.msg())
			}
		} else {
			return renderer.parse_failure(err.msg())
		}
	}
	renderer.last_good_response = content
	mut scope := renderer.eval_scope()
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
		renderer.report_errors(info.errors)
		return renderer.fallback('Nothing to show'), info
	}
	element := renderer.render_node(root_value, 0, 0, renderer.width, 0)
	if renderer.render_overflow {
		errors << OpenuiError{
			code:      openui_err_runtime
			message:   'render budget exceeded: too many shared nodes'
			statement: 'root'
		}
	}
	info := OpenuiRenderInfo{
		errors:   errors
		orphaned: openui_orphaned(statements, scope, renderer.library.root)
	}
	renderer.last_info = info
	renderer.report_errors(info.errors)
	if renderer.render_overflow {
		return renderer.fallback('Too many nodes'), info
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
	explicit_root := 'root' in scope.values
	if explicit_root {
		stack << 'root'
	}
	// Fallback seeding applies only when there is no explicit root. Seeding
	// anyway would mark an unused root-component sibling reachable.
	if !explicit_root {
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
	return openui_expr_refs_at(expr, 0)
}

// openui_expr_refs_at walks an expression with a depth budget so deeply
// nested input cannot overflow the C stack.
fn openui_expr_refs_at(expr &OpenuiExpr, depth int) []string {
	mut refs := []string{}
	if depth > 64 {
		return refs
	}
	match expr.kind {
		.ref {
			refs << expr.value
		}
		.state_ref, .literal {
		}
		.member {
			refs << openui_expr_refs_at(expr.target, depth + 1)
		}
		.unary {
			refs << openui_expr_refs_at(expr.left, depth + 1)
		}
		.binary {
			refs << openui_expr_refs_at(expr.left, depth + 1)
			refs << openui_expr_refs_at(expr.right, depth + 1)
		}
		.ternary {
			refs << openui_expr_refs_at(expr.left, depth + 1)
			refs << openui_expr_refs_at(expr.middle, depth + 1)
			refs << openui_expr_refs_at(expr.right, depth + 1)
		}
		.call, .at_call, .action_list {
			for arg in expr.args {
				refs << openui_expr_refs_at(arg, depth + 1)
			}
		}
		.array {
			for arg in expr.args {
				refs << openui_expr_refs_at(arg, depth + 1)
			}
		}
		.object {
			for key in expr.field_order {
				refs << openui_expr_refs_at(expr.fields[key] or { continue }, depth + 1)
			}
		}
		.query, .mutation {
			for arg in expr.args {
				refs << openui_expr_refs_at(arg, depth + 1)
			}
		}
	}
	return refs
}

// render_node maps one evaluated node to an `Element`, stacking slot
// children vertically inside the component frame.

fn (mut renderer OpenuiRenderer) render_node(value OpenuiValue, x f64, y f64, width f64, depth int) Element {
	// Shared references can expand exponentially; fail closed instead of
	// recursing until the process runs out of stack or memory.
	if renderer.render_nodes >= openui_max_render_nodes || depth > openui_max_render_depth {
		renderer.render_overflow = true
		return view('openui_budget', rect(x, y, width, 24), BoxStyle{}, [])
	}
	renderer.render_nodes++
	component := renderer.library.find(openui_node_name(value)) or {
		return view('openui_unknown', rect(x, y, width, 24), BoxStyle{}, [])
	}
	props := openui_node_props(value)
	slots := openui_node_slots(value)
	mut kids := []Element{}
	// Child frames are relative to their parent in ui2: the backend adds
	// the parent position when drawing them. Keep both cursor and child
	// frames local, with only ctx.frame using absolute coordinates.
	mut cursor := 8.0
	inner_x := 8.0
	inner_width := if width > 16 { width - 16 } else { width }
	for param in component.params {
		// node_slots() normalizes scalar node params to a single-item list too,
		// so render every param whose slot holds node values, not just lists.
		items := slots[param.name] or { continue }
		for item in items {
			if !openui_is_node(item) {
				continue
			}
			child := renderer.render_node(item, inner_x, cursor, inner_width, depth + 1)
			cursor += child.frame.height + 8
			kids << child
		}
	}
	height := if kids.len > 0 {
		cursor + 8
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

// refresh_action_steps re-evaluates the action expressions against the
// current state. Arguments are evaluated during the build, so without this
// a bound control's edit (or an earlier @Set) would never be observed by a
// later step. Rebuild silently: the host still owns the real refresh.

fn (mut renderer OpenuiRenderer) refresh_action_steps(event_id string, fallback []OpenuiActionCall) []OpenuiActionCall {
	was_streaming := renderer.streaming
	renderer.streaming = true
	_, _ = renderer.render()
	renderer.streaming = was_streaming
	return renderer.action_slots[event_id] or { fallback }
}

// handle_event runs the action steps registered for an event id. It returns
// true when the id was known. State-changing steps (`@Set`, `@Reset`,
// `@Run`) mean the host should rebuild, usually via `refresh()`.

pub fn (mut renderer OpenuiRenderer) handle_event(event_id string) bool {
	mut steps := renderer.action_slots[event_id] or { []OpenuiActionCall{} }
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
	if var_key.len > 0 && steps.len > 0 {
		steps = renderer.refresh_action_steps(event_id, steps)
	}
	for index := 0; index < steps.len; index++ {
		step := steps[index]
		match step.name {
			'Set' {
				if step.args.len == 2 {
					key := step.args[0].text
					renderer.state[key] = step.args[1]
					renderer.dirty[key] = true
					// Later steps must see this write, not the pre-event value.
					steps = renderer.refresh_action_steps(event_id, steps)
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
				steps = renderer.refresh_action_steps(event_id, steps)
			}
			'Run' {
				if step.args.len == 1 {
					if !renderer.run_tool(step.args[0].text) {
						// A failed tool stops the rest of the sequence.
						return true
					}
					steps = renderer.refresh_action_steps(event_id, steps)
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
	mut scope := renderer.eval_scope()
	openui_eval_program(statements, mut scope)
	return scope.state_defaults.clone()
}

fn (mut renderer OpenuiRenderer) report_tool_error(code string, message string, statement string) {
	renderer.report_errors([OpenuiError{
		code:      code
		message:   message
		statement: statement
	}])
}

// run_tool reports execution failures instead of swallowing them, so a
// failed mutation stops @Run's remaining steps and reaches on_error.

fn (mut renderer OpenuiRenderer) run_tool(name string) bool {
	content := strip_openui_markers(renderer.response)
	statements := parse_openui_program(content) or {
		renderer.report_tool_error(openui_err_parse_failed, err.msg(), name)
		return false
	}
	mut scope := renderer.eval_scope()
	for key, _ in renderer.dirty {
		if value := renderer.state[key] {
			scope.state_values[key] = value
		}
	}
	openui_eval_program(statements, mut scope)
	for key, value in scope.state_values {
		renderer.state[key] = value
	}
	statement := scope.statements[name] or {
		// @Run on an ordinary statement is a harmless no-op.
		return true
	}
	if statement.kind != .query && statement.kind != .mutation {
		return true
	}
	if statement.args.len == 0 {
		return true
	}
	tool_name := scope.eval_expr(statement.args[0], name)
	if tool_name.kind != .string_ || tool_name.text.len == 0 {
		renderer.report_tool_error(openui_err_type_mismatch, 'bad tool name for `${name}`', name)
		return false
	}
	mut plain := map[string]OpenuiValue{}
	if statement.args.len > 1 {
		call_args := scope.eval_expr(statement.args[1], name)
		if call_args.kind == .object {
			for key, value in call_args.fields {
				plain[key] = value
			}
		}
	}
	// Explicit refetch: drop the memo entry so this call reaches the tool,
	// then cache the fresh value for subsequent renders.
	cache_key := tool_name.text + '|' + openui_args_cache_key(plain)
	renderer.query_cache.delete(cache_key)
	if tool := renderer.tools[tool_name.text] {
		value := tool(plain)
		if renderer.query_cache.len < openui_max_query_cache_entries {
			renderer.query_cache[cache_key] = value
		}
		return true
	}
	renderer.report_tool_error(openui_err_tool_not_found, 'unknown tool `${tool_name.text}`', name)
	return false
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
