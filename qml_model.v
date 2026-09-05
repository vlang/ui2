module ui2

import math

enum QValueKind {
	invalid
	string_
	number
	bool_
	object
	list
}

struct QValue {
	kind    QValueKind
	text    string
	number  f64
	bool_   bool
	items   []QValue
	element &QValue = unsafe { nil }
mut:
	fields map[string]QValue
}

fn q_string(value string) QValue {
	return QValue{ kind: .string_, text: value }
}

fn q_number(value f64, text string) QValue {
	return QValue{ kind: .number, number: value, text: text }
}

fn q_bool(value bool) QValue {
	return QValue{ kind: .bool_, bool_: value }
}

fn q_object(fields map[string]QValue) QValue {
	return QValue{ kind: .object, fields: fields }
}

fn q_list(items []QValue, element QValue) QValue {
	return QValue{ kind: .list, items: items, element: &element }
}

fn q_value_from[T](value T) QValue {
	$if T is string {
		return q_string(value)
	} $else $if T is bool {
		return q_bool(value)
	} $else $if T is $int {
		return q_number(f64(value), value.str())
	} $else $if T is $float {
		return q_number(f64(value), value.str())
	} $else $if T is $array {
		mut items := []QValue{cap: value.len}
		for item in value {
			items << q_value_from(item)
		}
		element := q_value_from($zero(T.element_type))
		return q_list(items, element)
	} $else $if T is $struct {
		mut fields := map[string]QValue{}
		$for field in T.fields {
			$if field.is_pub {
				fields[field.name] = q_value_from(value.$(field.name))
			}
		}
		return q_object(fields)
	} $else {
		return QValue{}
	}
}

fn (value QValue) string_value() string {
	return match value.kind {
		.string_, .number { value.text }
		.bool_ {
			if value.bool_ { 'true' } else { 'false' }
		}
		.list { value.items.len.str() }
		.object { '' }
		.invalid { '' }
	}
}

fn (value QValue) truthy() bool {
	return match value.kind {
		.bool_ { value.bool_ }
		.number { value.number != 0 }
		.string_ { value.text.len > 0 && value.text != 'false' }
		.list { value.items.len > 0 }
		.object { true }
		.invalid { false }
	}
}

fn (value QValue) numeric(line int) !f64 {
	if value.kind == .number {
		return value.number
	}
	if value.kind == .string_ && value.text.len > 0 {
		return value.text.f64()
	}
	return error('expected a number at line ${line}')
}

fn q_lookup(scope map[string]QValue, path string, line int) !QValue {
	parts := path.split('.')
	if parts.len == 0 {
		return error('empty property path at line ${line}')
	}
	mut value := scope[parts[0]] or {
		// Unresolved single identifiers are QML enum/string literals such as
		// `center`, `decimal`, and `#FFFFFF`.
		if parts.len == 1 {
			return q_string(path)
		}
		return error('unknown property path `${path}` at line ${line}')
	}
	for part in parts[1..] {
		value = match value.kind {
			.object {
				value.fields[part] or {
					return error('unknown property path `${path}` at line ${line}')
				}
			}
			.list {
				if part != 'len' {
					return error('unknown collection property `${part}` in `${path}` at line ${line}')
				}
				q_number(f64(value.items.len), value.items.len.str())
			}
			.string_ {
				if part != 'len' {
					return error('unknown string property `${part}` in `${path}` at line ${line}')
				}
				length := rune_len(value.text)
				q_number(f64(length), length.str())
			}
			else {
				return error('cannot read `${part}` from `${path}` at line ${line}')
			}
		}
	}
	return value
}

fn q_values_equal(left QValue, right QValue) bool {
	if left.kind == .number && right.kind == .number {
		return left.number == right.number
	}
	if left.kind == .bool_ && right.kind == .bool_ {
		return left.bool_ == right.bool_
	}
	return left.string_value() == right.string_value()
}

fn q_validate_declared_property(name string, type_name string, value QValue, line int) ! {
	valid := match type_name {
		'bool' { value.kind == .bool_ }
		'string' { value.kind == .string_ }
		'int', 'f32', 'f64' { value.kind == .number }
		else {
			return error('unsupported property type `${type_name}` at line ${line}')
		}
	}
	if !valid {
		return error('property `${name}` expects `${type_name}` at line ${line}')
	}
}

fn q_eval(expr &QExpression, scope map[string]QValue) !QValue {
	return match expr.kind {
		.literal {
			if expr.quoted {
				q_string(expr.value)
			} else if expr.value == 'true' {
				q_bool(true)
			} else if expr.value == 'false' {
				q_bool(false)
			} else {
				q_number(expr.value.f64(), expr.value)
			}
		}
		.path { q_lookup(scope, expr.value, expr.line)! }
		.call {
			return error('calls are only allowed in event handlers at line ${expr.line}')
		}
		.unary {
			value := q_eval(expr.left, scope)!
			match expr.value {
				'!' { q_bool(!value.truthy()) }
				'-' {
					number := -value.numeric(expr.line)!
					q_number(number, number.str())
				}
				else {
					return error('unknown unary operator `${expr.value}` at line ${expr.line}')
				}
			}
		}
		.binary { q_eval_binary(expr, scope)! }
		.conditional {
			if q_eval(expr.left, scope)!.truthy() {
				q_eval(expr.right, scope)!
			} else {
				q_eval(expr.third, scope)!
			}
		}
		.interpolation {
			mut output := ''
			for part in expr.parts {
				if isnil(part.expr) {
					output += part.text
				} else {
					output += q_eval(part.expr, scope)!.string_value()
				}
			}
			q_string(output)
		}
	}
}

fn q_eval_binary(expr &QExpression, scope map[string]QValue) !QValue {
	left := q_eval(expr.left, scope)!
	if expr.value == '&&' && !left.truthy() {
		return q_bool(false)
	}
	if expr.value == '||' && left.truthy() {
		return q_bool(true)
	}
	right := q_eval(expr.right, scope)!
	return match expr.value {
		'+' {
			if left.kind == .string_ || right.kind == .string_ {
				q_string(left.string_value() + right.string_value())
			} else {
				value := left.numeric(expr.line)! + right.numeric(expr.line)!
				q_number(value, value.str())
			}
		}
		'-' {
			value := left.numeric(expr.line)! - right.numeric(expr.line)!
			q_number(value, value.str())
		}
		'*' {
			value := left.numeric(expr.line)! * right.numeric(expr.line)!
			q_number(value, value.str())
		}
		'/' {
			divisor := right.numeric(expr.line)!
			if divisor == 0 {
				return error('division by zero at line ${expr.line}')
			}
			value := left.numeric(expr.line)! / divisor
			q_number(value, value.str())
		}
		'%' {
			divisor := right.numeric(expr.line)!
			if divisor == 0 {
				return error('division by zero at line ${expr.line}')
			}
			value := math.fmod(left.numeric(expr.line)!, divisor)
			q_number(value, value.str())
		}
		'==' { q_bool(q_values_equal(left, right)) }
		'!=' { q_bool(!q_values_equal(left, right)) }
		'<' { q_bool(left.numeric(expr.line)! < right.numeric(expr.line)!) }
		'<=' { q_bool(left.numeric(expr.line)! <= right.numeric(expr.line)!) }
		'>' { q_bool(left.numeric(expr.line)! > right.numeric(expr.line)!) }
		'>=' { q_bool(left.numeric(expr.line)! >= right.numeric(expr.line)!) }
		'&&' { q_bool(left.truthy() && right.truthy()) }
		'||' { q_bool(left.truthy() || right.truthy()) }
		else {
			return error('unknown operator `${expr.value}` at line ${expr.line}')
		}
	}
}

struct QmlInvocation {
	name string
	args []QValue
	line int
}

struct QmlBinding {
	property string
	target   string
	control  string
}

struct QmlEvent {
	binding    ?QmlBinding
	invocation ?QmlInvocation
}

struct QmlEvaluation {
mut:
	events map[string]QmlEvent
}

fn q_action(expr &QExpression, scope map[string]QValue) !QmlInvocation {
	if expr.kind != .call || !expr.value.starts_with('app.') {
		return error('event handlers must call an app action at line ${expr.line}')
	}
	name := expr.value.all_after('app.')
	if name.len == 0 || name.contains('.') {
		return error('invalid app action `${expr.value}` at line ${expr.line}')
	}
	mut args := []QValue{cap: expr.args.len}
	for arg in expr.args {
		args << q_eval(arg, scope)!
	}
	return QmlInvocation{ name: name, args: args, line: expr.line }
}

fn q_event_id(node &QNode, scope map[string]QValue, property string) string {
	repeated := (scope['__repeat_key'] or { q_string('') }).string_value()
	return '__qml_event_${node.path.replace('.', '_')}_${property}_${repeated.bytes().hex()}'
}

fn q_control_id(node &QNode, scope map[string]QValue) string {
	repeated := (scope['__repeat_key'] or { q_string('') }).string_value()
	return '__qml_control_${node.path.replace('.', '_')}_${repeated.bytes().hex()}'
}

fn q_eval_node(node &QNode, incoming_scope map[string]QValue, frame Rect, mut evaluation QmlEvaluation) !&QNode {
	mut scope := incoming_scope.clone()
	mut resolved := &QNode{
		tag: node.tag
		id: node.id
		line: node.line
		path: node.path
	}

	// Root ids are available while evaluating root-level declared properties.
	if node.id.len > 0 {
		scope[node.id] = q_object({
			'x':      q_number(frame.x, frame.x.str())
			'y':      q_number(frame.y, frame.y.str())
			'width':  q_number(frame.width, frame.width.str())
			'height': q_number(frame.height, frame.height.str())
		})
	}
	for name in node.property_order {
		expr := node.expressions[name] or { continue }
		value := q_eval(expr, scope)!
		q_validate_declared_property(name, node.property_types[name], value, expr.line)!
		resolved.props[name] = value.string_value()
		resolved.property_types[name] = node.property_types[name]
		resolved.property_order << name
		if node.id.len > 0 {
			mut object := scope[node.id] or {
				return error('internal QML scope error for `${node.id}` at line ${node.line}')
			}
			object.fields[name] = value
			scope[node.id] = object
		}
	}

	mut binding := ?QmlBinding(none)
	for key, expr in node.expressions {
		if key == 'id' || key in node.property_types || key.starts_with('bind.')
			|| key in ['on_tap', 'on_change', 'on_submit'] {
			continue
		}
		resolved.props[key] = q_eval(expr, scope)!.string_value()
	}
	for key, expr in node.expressions {
		if !key.starts_with('bind.') {
			continue
		}
		if binding != none {
			return error('an element can only have one two-way binding at line ${node.line}')
		}
		property := key.all_after('bind.')
		if expr.kind != .path || !expr.value.starts_with('app.') || expr.value.count('.') != 1 {
			return error('`${key}` must target a mutable top-level app field at line ${expr.line}')
		}
		resolved.props[property] = q_eval(expr, scope)!.string_value()
		if resolved.id.len == 0 {
			resolved.id = q_control_id(node, scope)
		}
		binding = QmlBinding{ property: property, target: expr.value, control: resolved.id }
	}

	mut binding_event_property := ''
	if b := binding {
		binding_event_property = match b.property {
			'checked' { 'on_tap' }
			'text' { 'on_change' }
			else {
				return error('two-way binding is not supported for `${b.property}` at line ${node.line}')
			}
		}
		event_id := q_event_id(node, scope, binding_event_property)
		resolved.props[binding_event_property] = event_id
		evaluation.events[event_id] = QmlEvent{ binding: binding }
	}
	for property in ['on_tap', 'on_change', 'on_submit'] {
		expr := node.expressions[property] or { continue }
		if expr.kind == .call {
			event_id := q_event_id(node, scope, property)
			existing := evaluation.events[event_id] or { QmlEvent{} }
			resolved.props[property] = event_id
			evaluation.events[event_id] = QmlEvent{
				binding: existing.binding
				invocation: q_action(expr, scope)!
			}
		} else {
			if property == binding_event_property {
				return error('a bound `${property}` handler must call an app action at line ${expr.line}')
			}
			resolved.props[property] = expression_text(expr)
		}
	}

	for child in node.children {
		if child.tag == 'Repeater' {
			q_expand_repeater(child, scope, frame, mut resolved.children, mut evaluation)!
		} else {
			resolved.children << q_eval_node(child, scope, frame, mut evaluation)!
		}
	}
	return resolved
}

fn q_expand_repeater(node &QNode, scope map[string]QValue, frame Rect, mut output []&QNode, mut evaluation QmlEvaluation) ! {
	model_expr := node.expressions['model'] or {
		return error('Repeater requires `model` at line ${node.line}')
	}
	key_expr := node.expressions['key'] or {
		return error('Repeater requires a stable `key` at line ${node.line}')
	}
	items := q_eval(model_expr, scope)!
	if items.kind != .list {
		return error('Repeater model must be a collection at line ${model_expr.line}')
	}
	if items.items.len == 0 && !isnil(items.element) {
		// Evaluate an element schema without producing UI so paths and action
		// signatures inside an initially-empty repeater still fail at load time.
		mut schema_scope := scope.clone()
		schema_scope['item'] = *items.element
		schema_scope['index'] = q_number(0, '0')
		schema_scope['__repeat_key'] = q_string('__schema__')
		q_eval(key_expr, schema_scope)!
		for child in node.children {
			q_eval_node(child, schema_scope, frame, mut evaluation)!
		}
	}
	mut keys := map[string]bool{}
	for index, item in items.items {
		mut item_scope := scope.clone()
		item_scope['item'] = item
		item_scope['index'] = q_number(f64(index), index.str())
		key := q_eval(key_expr, item_scope)!.string_value()
		if key.len == 0 {
			return error('Repeater key cannot be empty at line ${key_expr.line}')
		}
		if key in keys {
			return error('duplicate Repeater key `${key}` at line ${key_expr.line}')
		}
		keys[key] = true
		parent_key := (scope['__repeat_key'] or { q_string('') }).string_value()
		item_scope['__repeat_key'] = q_string(if parent_key.len > 0 {
			'${parent_key}/${key}'
		} else {
			key
		})
		for child_index, child in node.children {
			mut repeated := q_eval_node(child, item_scope, frame, mut evaluation)!
			if repeated.props['key'].len == 0 {
				repeated.props['key'] = if node.children.len == 1 {
					key
				} else {
					'${key}:${child_index}'
				}
			}
			output << repeated
		}
	}
}

fn q_evaluate_template[T](root &QNode, model T, frame Rect) !(&QNode, map[string]QmlEvent) {
	mut evaluation := QmlEvaluation{ events: map[string]QmlEvent{} }
	scope := {
		'app': q_value_from(model)
	}
	resolved := q_eval_node(root, scope, frame, mut evaluation)!
	return resolved, evaluation.events
}

// element_from_qml_model evaluates a QML document against a typed V model.
// It is useful for previews and tests; run_qml keeps the parsed document cached
// and additionally wires two-way bindings and actions to the live model.
pub fn element_from_qml_model[T](source string, model T, frame Rect) !Element {
	template := parse_qml(source)!
	resolved, events := q_evaluate_template(template, model, frame)!
	qml_validate_events[T](events)!
	element := element_from_qnode(resolved, frame)!
	validate_element_tree(element)!
	return element
}

fn qml_validate_events[T](events map[string]QmlEvent) ! {
	for _, event in events {
		if binding := event.binding {
			target := binding.target.all_after('app.')
			type_name := qml_writable_field_type[T](target)!
			if binding.property == 'checked' && type_name != 'bool' {
				return error('bind.checked requires a bool field, got `${target}` (${type_name})')
			}
		}
		if invocation := event.invocation {
			type_check_invocation[T](invocation)!
		}
	}
}

fn qml_writable_field_type[T](name string) !string {
	$for field in T.fields {
		if field.name == name {
			$if !field.is_pub {
				return error('app field `${name}` is not public')
			} $else $if !field.is_mut {
				return error('app field `${name}` is not mutable')
			} $else {
				return typeof(field).name
			}
		}
	}
	return error('unknown app field `${name}`')
}

fn type_check_invocation[T](invocation QmlInvocation) ! {
	$for method in T.methods {
		if method.name == invocation.name {
			$if !method.is_pub {
				return error('app action `${invocation.name}` is not public')
			} $else $if method.typ is fn ( ) {
				if invocation.args.len != 0 {
					return error('app action `${invocation.name}` expects no arguments at line ${invocation.line}')
				}
				return
			} $else $if method.typ is fn ( int ) {
				if invocation.args.len != 1 || invocation.args[0].kind != .number {
					return error('app action `${invocation.name}` expects one int argument at line ${invocation.line}')
				}
				return
			} $else $if method.typ is fn ( string ) {
				if invocation.args.len != 1 {
					return error('app action `${invocation.name}` expects one string argument at line ${invocation.line}')
				}
				return
			} $else {
				return error('app action `${invocation.name}` has an unsupported signature at line ${invocation.line}')
			}
		}
	}
	return error('unknown app action `${invocation.name}` at line ${invocation.line}')
}

fn qml_set_field[T](mut model T, name string, value QValue) ! {
	$for field in T.fields {
		if field.name == name {
			$if !field.is_pub {
				return error('app field `${name}` is not public')
			} $else $if !field.is_mut {
				return error('app field `${name}` is not mutable')
			} $else $if field.typ is string {
				model.$(field.name) = value.string_value()
				return
			} $else $if field.typ is bool {
				model.$(field.name) = value.truthy()
				return
			} $else $if field.typ is int {
				model.$(field.name) = int(value.numeric(0)!)
				return
			} $else $if field.typ is f64 {
				model.$(field.name) = value.numeric(0)!
				return
			} $else $if field.typ is f32 {
				model.$(field.name) = f32(value.numeric(0)!)
				return
			} $else {
				return error('two-way binding does not support app field `${name}` of type `${typeof(field).name}`')
			}
		}
	}
	return error('unknown app field `${name}`')
}

fn qml_dispatch[T](mut model T, invocation QmlInvocation) ! {
	$for method in T.methods {
		if method.name == invocation.name {
			$if method.is_pub && method.typ is fn ( ) {
				model.$method()
				return
			} $else $if method.is_pub && method.typ is fn ( int ) {
				model.$method(int(invocation.args[0].numeric(0)!))
				return
			} $else $if method.is_pub && method.typ is fn ( string ) {
				model.$method(invocation.args[0].string_value())
				return
			}
		}
	}
	return error('unknown or unsupported app action `${invocation.name}`')
}

pub struct QmlRunConfig[T] {
pub:
	source string
	model  T
	title  string = 'App'
	width  int = 400
	height int = 800
}

@[heap]
struct QmlController[T] {
	template &QNode
mut:
	model  T
	events map[string]QmlEvent
}

@[heap]
struct QmlRuntime {
mut:
	controller voidptr
}

const qml_runtime_singleton = &QmlRuntime{}

fn qml_runtime() &QmlRuntime {
	return unsafe { qml_runtime_singleton }
}

fn qml_controller_build[T]() Element {
	runtime := qml_runtime()
	mut controller := unsafe { &QmlController[T](runtime.controller) }
	return controller.build()
}

fn qml_controller_handle[T](event_id string) {
	runtime := qml_runtime()
	mut controller := unsafe { &QmlController[T](runtime.controller) }
	controller.handle(event_id)
}

fn (mut controller QmlController[T]) build() Element {
	frame := bounds()
	resolved, events := q_evaluate_template(controller.template, controller.model, rect(0, 0, frame.width, frame.height)) or {
		eprintln('ui2 QML evaluation failed: ${err}')
		return screen(0xffffff, [])
	}
	controller.events = events.clone()
	return element_from_qnode(resolved, rect(0, 0, frame.width, frame.height)) or {
		eprintln('ui2 QML element conversion failed: ${err}')
		screen(0xffffff, [])
	}
}

fn (mut controller QmlController[T]) handle(event_id string) {
	event := controller.events[event_id] or { return }
	if binding := event.binding {
		field_name := binding.target.all_after('app.')
		value := if binding.property == 'checked' {
			current := q_lookup({
				'app': q_value_from(controller.model)
			}, binding.target, 0) or {
				eprintln('ui2 QML binding failed: ${err}')
				return
			}
			q_bool(!current.truthy())
		} else {
			q_string(text(binding.control))
		}
		qml_set_field[T](mut controller.model, field_name, value) or {
			eprintln('ui2 QML binding failed: ${err}')
			return
		}
	}
	if invocation := event.invocation {
		qml_dispatch[T](mut controller.model, invocation) or {
			eprintln('ui2 QML action failed: ${err}')
			return
		}
	}
	refresh()
}

// run_qml owns one typed model for the window, exposes it to QML as `app`, and
// reconciles the cached document after each binding write or app action.
pub fn run_qml[T](config QmlRunConfig[T]) ! {
	template := parse_qml(config.source)!
	initial_frame := rect(0, 0, f64(config.width), f64(config.height))
	resolved, events := q_evaluate_template(template, config.model, initial_frame)!
	qml_validate_events[T](events)!
	validate_element_tree(element_from_qnode(resolved, initial_frame)!)!
	mut controller := &QmlController[T]{
		template: template
		model: config.model
		events: events
	}
	mut runtime := qml_runtime()
	runtime.controller = voidptr(controller)
	$if macos || windows || linux {
		run_window(config.title, config.width, config.height, qml_controller_build[T], qml_controller_handle[T])
	} $else {
		run(qml_controller_build[T], qml_controller_handle[T])
	}
}
