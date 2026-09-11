module ui2

import math

enum VValueKind {
	invalid
	string_
	number
	bool_
	object
	list
}

struct VValue {
	kind   VValueKind
	text   string
	number f64
	bool_  bool
	items  []VValue
mut:
	fields map[string]VValue
}

struct VSchema {
	kind    VValueKind
	element &VSchema = unsafe { nil }
mut:
	fields map[string]VSchema
}

fn v_string(value string) VValue {
	return VValue{
		kind: .string_
		text: value
	}
}

fn v_number(value f64, text string) VValue {
	return VValue{
		kind:   .number
		number: value
		text:   text
	}
}

fn v_bool(value bool) VValue {
	return VValue{
		kind:  .bool_
		bool_: value
	}
}

fn v_object(fields map[string]VValue) VValue {
	return VValue{
		kind:   .object
		fields: fields
	}
}

fn v_list(items []VValue) VValue {
	return VValue{
		kind:  .list
		items: items
	}
}

fn v_value_from[T](value T) VValue {
	$if T is string {
		return v_string(value)
	} $else $if T is bool {
		return v_bool(value)
	} $else $if T is $int {
		return v_number(f64(value), value.str())
	} $else $if T is $float {
		return v_number(f64(value), value.str())
	} $else $if T is $array {
		mut items := []VValue{cap: value.len}
		for item in value {
			items << v_value_from(item)
		}
		return v_list(items)
	} $else $if T is $struct {
		mut fields := map[string]VValue{}
		$for field in T.fields {
			$if field.is_pub {
				fields[field.name] = v_value_from(value.$(field.name))
			}
		}
		return v_object(fields)
	} $else {
		return VValue{}
	}
}

fn v_array_element_schema[E](_ []E) VSchema {
	$if E is $struct {
		return v_schema_from(E{})
	} $else {
		return v_schema_from($zero(E))
	}
}

fn v_schema_from[T](value T) VSchema {
	$if T is string {
		return VSchema{
			kind: .string_
		}
	} $else $if T is bool {
		return VSchema{
			kind: .bool_
		}
	} $else $if T is $int || T is $float {
		return VSchema{
			kind: .number
		}
	} $else $if T is $array {
		element := v_array_element_schema(value)
		return VSchema{
			kind:    .list
			element: &element
		}
	} $else $if T is $struct {
		mut fields := map[string]VSchema{}
		$for field in T.fields {
			$if field.is_pub {
				fields[field.name] = v_schema_from(value.$(field.name))
			}
		}
		return VSchema{
			kind:   .object
			fields: fields
		}
	} $else {
		return VSchema{}
	}
}

fn (value VValue) string_value() string {
	return match value.kind {
		.string_, .number {
			value.text
		}
		.bool_ {
			if value.bool_ {
				'true'
			} else {
				'false'
			}
		}
		.list {
			value.items.len.str()
		}
		.object {
			''
		}
		.invalid {
			''
		}
	}
}

fn (value VValue) truthy() bool {
	return match value.kind {
		.bool_ { value.bool_ }
		.number { value.number != 0 }
		.string_ { value.text.len > 0 && value.text != 'false' }
		.list { value.items.len > 0 }
		.object { true }
		.invalid { false }
	}
}

fn (value VValue) numeric(line int) !f64 {
	if value.kind == .number {
		return value.number
	}
	if value.kind == .string_ && value.text.len > 0 {
		return value.text.f64()
	}
	return error('expected a number at line ${line}')
}

fn v_lookup(scope map[string]VValue, path string, line int) !VValue {
	parts := path.split('.')
	if parts.len == 0 {
		return error('empty property path at line ${line}')
	}
	mut value := scope[parts[0]] or {
		// Unresolved single identifiers are VML enum/string literals such as
		// `center`, `decimal`, and `#FFFFFF`.
		if parts.len == 1 {
			return v_string(path)
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
				v_number(f64(value.items.len), value.items.len.str())
			}
			.string_ {
				if part != 'len' {
					return error('unknown string property `${part}` in `${path}` at line ${line}')
				}
				length := rune_len(value.text)
				v_number(f64(length), length.str())
			}
			else {
				return error('cannot read `${part}` from `${path}` at line ${line}')
			}
		}
	}
	return value
}

fn v_schema_lookup(scope map[string]VSchema, path string, line int) !VSchema {
	parts := path.split('.')
	if parts.len == 0 {
		return error('empty property path at line ${line}')
	}
	mut schema := scope[parts[0]] or {
		// Bare VML enum and color values are string-like literals. Qualified
		// paths must always resolve against the schema.
		if parts.len == 1 {
			return VSchema{
				kind: .string_
			}
		}
		return error('unknown property path `${path}` at line ${line}')
	}
	for part in parts[1..] {
		schema = match schema.kind {
			.object {
				schema.fields[part] or {
					return error('unknown property path `${path}` at line ${line}')
				}
			}
			.list {
				if part != 'len' {
					return error('unknown collection property `${part}` in `${path}` at line ${line}')
				}
				VSchema{
					kind: .number
				}
			}
			.string_ {
				if part != 'len' {
					return error('unknown string property `${part}` in `${path}` at line ${line}')
				}
				VSchema{
					kind: .number
				}
			}
			else {
				return error('cannot read `${part}` from `${path}` at line ${line}')
			}
		}
	}
	return schema
}

fn v_require_schema(schema VSchema, expected VValueKind, line int) ! {
	if schema.kind != expected {
		return error('expected ${expected} expression at line ${line}')
	}
}

fn v_schema_expression(expr &VExpression, scope map[string]VSchema) !VSchema {
	return match expr.kind {
		.literal {
			if expr.quoted {
				VSchema{
					kind: .string_
				}
			} else if expr.value in ['true', 'false'] {
				VSchema{
					kind: .bool_
				}
			} else {
				VSchema{
					kind: .number
				}
			}
		}
		.path {
			v_schema_lookup(scope, expr.value, expr.line)!
		}
		.call {
			return error('calls are only allowed in event handlers at line ${expr.line}')
		}
		.assignment {
			return error('assignments are only allowed in event handlers at line ${expr.line}')
		}
		.unary {
			value := v_schema_expression(expr.left, scope)!
			match expr.value {
				'!' {
					VSchema{
						kind: .bool_
					}
				}
				'-' {
					v_require_schema(value, .number, expr.line)!
					VSchema{
						kind: .number
					}
				}
				else {
					return error('unknown unary operator `${expr.value}` at line ${expr.line}')
				}
			}
		}
		.binary {
			v_schema_binary(expr, scope)!
		}
		.conditional {
			v_schema_expression(expr.left, scope)!
			when_true := v_schema_expression(expr.right, scope)!
			when_false := v_schema_expression(expr.third, scope)!
			if when_true.kind != when_false.kind {
				return error('conditional branches have different types at line ${expr.line}')
			}
			when_true
		}
		.interpolation {
			for part in expr.parts {
				if !isnil(part.expr) {
					v_schema_expression(part.expr, scope)!
				}
			}
			VSchema{
				kind: .string_
			}
		}
	}
}

fn v_schema_binary(expr &VExpression, scope map[string]VSchema) !VSchema {
	left := v_schema_expression(expr.left, scope)!
	right := v_schema_expression(expr.right, scope)!
	return match expr.value {
		'+' {
			if left.kind == .string_ || right.kind == .string_ {
				VSchema{
					kind: .string_
				}
			} else {
				v_require_schema(left, .number, expr.line)!
				v_require_schema(right, .number, expr.line)!
				VSchema{
					kind: .number
				}
			}
		}
		'-', '*', '/', '%' {
			v_require_schema(left, .number, expr.line)!
			v_require_schema(right, .number, expr.line)!
			VSchema{
				kind: .number
			}
		}
		'<', '<=', '>', '>=' {
			v_require_schema(left, .number, expr.line)!
			v_require_schema(right, .number, expr.line)!
			VSchema{
				kind: .bool_
			}
		}
		'==', '!=', '&&', '||' {
			VSchema{
				kind: .bool_
			}
		}
		else {
			return error('unknown operator `${expr.value}` at line ${expr.line}')
		}
	}
}

fn v_values_equal(left VValue, right VValue) bool {
	if left.kind == .number && right.kind == .number {
		return left.number == right.number
	}
	if left.kind == .bool_ && right.kind == .bool_ {
		return left.bool_ == right.bool_
	}
	return left.string_value() == right.string_value()
}

fn v_validate_declared_property(name string, type_name string, value VValue, line int) ! {
	valid := match type_name {
		'bool' {
			value.kind == .bool_
		}
		'string' {
			value.kind == .string_
		}
		'int', 'f32', 'f64' {
			value.kind == .number
		}
		else {
			return error('unsupported property type `${type_name}` at line ${line}')
		}
	}

	if !valid {
		return error('property `${name}` expects `${type_name}` at line ${line}')
	}
}

fn v_eval(expr &VExpression, scope map[string]VValue) !VValue {
	return match expr.kind {
		.literal {
			if expr.quoted {
				v_string(expr.value)
			} else if expr.value == 'true' {
				v_bool(true)
			} else if expr.value == 'false' {
				v_bool(false)
			} else {
				v_number(expr.value.f64(), expr.value)
			}
		}
		.path {
			v_lookup(scope, expr.value, expr.line)!
		}
		.call {
			return error('calls are only allowed in event handlers at line ${expr.line}')
		}
		.assignment {
			return error('assignments are only allowed in event handlers at line ${expr.line}')
		}
		.unary {
			value := v_eval(expr.left, scope)!
			match expr.value {
				'!' {
					v_bool(!value.truthy())
				}
				'-' {
					number := -value.numeric(expr.line)!
					v_number(number, number.str())
				}
				else {
					return error('unknown unary operator `${expr.value}` at line ${expr.line}')
				}
			}
		}
		.binary {
			v_eval_binary(expr, scope)!
		}
		.conditional {
			if v_eval(expr.left, scope)!.truthy() {
				v_eval(expr.right, scope)!
			} else {
				v_eval(expr.third, scope)!
			}
		}
		.interpolation {
			mut output := ''
			for part in expr.parts {
				if isnil(part.expr) {
					output += part.text
				} else {
					output += v_eval(part.expr, scope)!.string_value()
				}
			}
			v_string(output)
		}
	}
}

fn v_eval_binary(expr &VExpression, scope map[string]VValue) !VValue {
	left := v_eval(expr.left, scope)!
	if expr.value == '&&' && !left.truthy() {
		return v_bool(false)
	}
	if expr.value == '||' && left.truthy() {
		return v_bool(true)
	}
	right := v_eval(expr.right, scope)!
	return match expr.value {
		'+' {
			if left.kind == .string_ || right.kind == .string_ {
				v_string(left.string_value() + right.string_value())
			} else {
				value := left.numeric(expr.line)! + right.numeric(expr.line)!
				v_number(value, value.str())
			}
		}
		'-' {
			value := left.numeric(expr.line)! - right.numeric(expr.line)!
			v_number(value, value.str())
		}
		'*' {
			value := left.numeric(expr.line)! * right.numeric(expr.line)!
			v_number(value, value.str())
		}
		'/' {
			divisor := right.numeric(expr.line)!
			if divisor == 0 {
				return error('division by zero at line ${expr.line}')
			}
			value := left.numeric(expr.line)! / divisor
			v_number(value, value.str())
		}
		'%' {
			divisor := right.numeric(expr.line)!
			if divisor == 0 {
				return error('division by zero at line ${expr.line}')
			}
			value := math.fmod(left.numeric(expr.line)!, divisor)
			v_number(value, value.str())
		}
		'==' {
			v_bool(v_values_equal(left, right))
		}
		'!=' {
			v_bool(!v_values_equal(left, right))
		}
		'<' {
			v_bool(left.numeric(expr.line)! < right.numeric(expr.line)!)
		}
		'<=' {
			v_bool(left.numeric(expr.line)! <= right.numeric(expr.line)!)
		}
		'>' {
			v_bool(left.numeric(expr.line)! > right.numeric(expr.line)!)
		}
		'>=' {
			v_bool(left.numeric(expr.line)! >= right.numeric(expr.line)!)
		}
		'&&' {
			v_bool(left.truthy() && right.truthy())
		}
		'||' {
			v_bool(left.truthy() || right.truthy())
		}
		else {
			return error('unknown operator `${expr.value}` at line ${expr.line}')
		}
	}
}

struct VmlInvocation {
	name  string
	args  []&VExpression
	scope map[string]VValue
	line  int
}

struct VmlAssignment {
	target string
	value  &VExpression
	scope  map[string]VValue
	line   int
}

struct VmlBinding {
	property           string
	target             string
	control            string
	group              string
	allow_no_selection bool = true
}

struct VmlEvent {
	binding        ?VmlBinding
	group_bindings []VmlBinding
	invocation     ?VmlInvocation
	assignment     ?VmlAssignment
}

struct VmlEvaluation {
mut:
	events                map[string]VmlEvent
	toggle_group_bindings map[string][]VmlBinding
}

fn v_action(expr &VExpression, scope map[string]VValue) !VmlInvocation {
	if expr.kind != .call || !expr.value.starts_with('app.') {
		return error('event handlers must call an app action at line ${expr.line}')
	}
	name := expr.value.all_after('app.')
	if name.len == 0 || name.contains('.') {
		return error('invalid app action `${expr.value}` at line ${expr.line}')
	}
	mut action_scope := scope.clone()
	action_scope.delete('app')
	return VmlInvocation{
		name:  name
		args:  expr.args.clone()
		scope: action_scope
		line:  expr.line
	}
}

fn v_assignment(expr &VExpression, scope map[string]VValue) !VmlAssignment {
	if expr.kind != .assignment || expr.left.kind != .path || !expr.left.value.starts_with('app.')
		|| expr.left.value.count('.') != 1 {
		return error('event assignments must target a mutable top-level app field at line ${expr.line}')
	}
	mut assignment_scope := scope.clone()
	assignment_scope.delete('app')
	return VmlAssignment{
		target: expr.left.value.all_after('app.')
		value:  expr.right
		scope:  assignment_scope
		line:   expr.line
	}
}

fn v_event_id(node &VNode, scope map[string]VValue, property string) string {
	repeated := (scope['__repeat_key'] or { v_string('') }).string_value()
	return '__vml_event_${node.path.replace('.', '_')}_${property}_${repeated.bytes().hex()}'
}

fn v_control_id(node &VNode, scope map[string]VValue) string {
	repeated := (scope['__repeat_key'] or { v_string('') }).string_value()
	return '__vml_control_${node.path.replace('.', '_')}_${repeated.bytes().hex()}'
}

fn v_repeat_identity(parent string, key string) string {
	// Encode each key independently. Encoding only the final joined path makes
	// (`a/b`, `c`) indistinguishable from (`a`, `b/c`).
	segment := key.bytes().hex()
	return if parent.len > 0 { '${parent}/${segment}' } else { segment }
}

enum VChildLayoutKind {
	overlay
	column
	row
	box
	float
	grid
	anchor
	stack
	page
	tabs
	accordion
}

struct VLayoutChildMetrics {
	frame            Rect
	size_hint_x      f64 = 1.0
	size_hint_y      f64 = 1.0
	minimum_width    f64 = -1.0
	minimum_height   f64 = -1.0
	maximum_width    f64 = -1.0
	maximum_height   f64 = -1.0
	horizontal_align BoxAlignment
	vertical_align   BoxAlignment
	x_hint           FloatAxisHint
	y_hint           FloatAxisHint
}

struct VChildLayout {
	kind    VChildLayoutKind
	frame   Rect
	padding f64
	spacing f64
	cells   []Rect
	anchor  AnchorLayoutConfig
mut:
	cursor f64
	index  int
}

fn v_child_layout(node &VNode, actual Rect, metrics []VLayoutChildMetrics) !VChildLayout {
	kind := match node.tag {
		'Column' { VChildLayoutKind.column }
		'Row' { VChildLayoutKind.row }
		'BoxLayout' { VChildLayoutKind.box }
		'FloatLayout', 'RelativeLayout' { VChildLayoutKind.float }
		'GridLayout' { VChildLayoutKind.grid }
		'AnchorLayout' { VChildLayoutKind.anchor }
		'StackLayout' { VChildLayoutKind.stack }
		'PageLayout' { VChildLayoutKind.page }
		'TabbedPanel' { VChildLayoutKind.tabs }
		'Accordion' { VChildLayoutKind.accordion }
		else { VChildLayoutKind.overlay }
	}

	padding := node.prop_or('padding', '0').f64()
	local := rect(0, 0, actual.width, actual.height)
	mut child_sizes := []Rect{cap: metrics.len}
	mut box_children := []BoxLayoutChild{cap: metrics.len}
	mut float_children := []FloatLayoutChild{cap: metrics.len}
	mut panel_tabs := []TabbedPanelTab{cap: metrics.len}
	mut accordion_items := []AccordionItem{cap: metrics.len}
	for metric in metrics {
		child_sizes << metric.frame
		if kind == .box {
			box_children << BoxLayoutChild{
				element:          Element{
					frame: metric.frame
				}
				size_hint_x:      metric.size_hint_x
				size_hint_y:      metric.size_hint_y
				minimum_width:    metric.minimum_width
				minimum_height:   metric.minimum_height
				maximum_width:    metric.maximum_width
				maximum_height:   metric.maximum_height
				horizontal_align: metric.horizontal_align
				vertical_align:   metric.vertical_align
			}
		} else if kind == .float {
			float_children << FloatLayoutChild{
				element:        Element{
					frame: metric.frame
				}
				size_hint_x:    metric.size_hint_x
				size_hint_y:    metric.size_hint_y
				minimum_width:  metric.minimum_width
				minimum_height: metric.minimum_height
				maximum_width:  metric.maximum_width
				maximum_height: metric.maximum_height
				x_hint:         metric.x_hint
				y_hint:         metric.y_hint
			}
		} else if kind == .tabs {
			panel_tabs << TabbedPanelTab{}
		} else if kind == .accordion {
			accordion_items << AccordionItem{}
		}
	}
	mut cells := []Rect{}
	if kind == .grid {
		cells = grid_layout_frames(v_grid_config(node, local)!, child_sizes.len)!
	} else if kind == .box {
		cells = box_layout_frames(v_box_layout_config(node, local, box_children)!)!
	} else if kind == .float {
		cells = float_layout_frames(v_float_layout_config(node, local, float_children))!
	} else if kind == .stack {
		cells = stack_layout_frames(v_stack_config(node, local)!, child_sizes)!
	} else if kind == .page {
		cells = page_layout_frames(v_page_layout_config(node, local, child_sizes.len))!
	} else if kind == .tabs {
		geometry := tabbed_panel_geometry(v_tabbed_panel_config(node, local, panel_tabs)!)!
		cells = []Rect{len: panel_tabs.len, init: geometry.content}
	} else if kind == .accordion {
		geometry := accordion_geometry(v_accordion_config(node, local, accordion_items)!)!
		cells = []Rect{len: accordion_items.len, init: geometry.content}
	}
	return VChildLayout{
		kind:    kind
		frame:   local
		padding: padding
		spacing: node.prop_or('spacing', '0').f64()
		cursor:  padding
		cells:   cells
		anchor:  if kind == .anchor {
			v_anchor_config(node, local)!
		} else {
			AnchorLayoutConfig{}
		}
	}
}

fn v_layout_dimension(node &VNode, key string, scope map[string]VValue, fallback f64) !f64 {
	if expr := node.expressions[key] {
		return v_eval(expr, scope)!.numeric(expr.line)!
	}
	return v_dimension(node, key, fallback)
}

fn (layout &VChildLayout) fallback(child &VNode, scope map[string]VValue) !Rect {
	return match layout.kind {
		.overlay {
			layout.frame
		}
		.column {
			rect(layout.padding, layout.cursor, layout.frame.width - layout.padding * 2, 32)
		}
		.row {
			rect(layout.cursor, layout.padding, 80, layout.frame.height - layout.padding * 2)
		}
		.box {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.float {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.grid {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.anchor {
			anchor_layout_frame(layout.anchor, rect(0, 0, v_layout_dimension(child, 'width', scope,
				80)!, v_layout_dimension(child, 'height', scope, 32)!))
		}
		.stack {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.page {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.tabs {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
		.accordion {
			if layout.index < layout.cells.len {
				layout.cells[layout.index]
			} else {
				layout.frame
			}
		}
	}
}

fn (mut layout VChildLayout) advance(child &VNode) {
	if child.tag in ['MenuItem', 'Option'] {
		return
	}
	match layout.kind {
		.column {
			layout.cursor += v_dimension(child, 'height', 32) + layout.spacing
		}
		.row {
			layout.cursor += v_dimension(child, 'width', 80) + layout.spacing
		}
		.box {
			layout.index++
		}
		.float {
			layout.index++
		}
		.grid {
			layout.index++
		}
		.anchor {}
		.stack {
			layout.index++
		}
		.page {
			layout.index++
		}
		.tabs {
			layout.index++
		}
		.accordion {
			layout.index++
		}
		.overlay {}
	}
}

fn v_layout_alignment(node &VNode, key string, scope map[string]VValue) !BoxAlignment {
	if expr := node.expressions[key] {
		return box_alignment(v_eval(expr, scope)!.string_value())!
	}
	return box_alignment(node.prop_or(key, 'start'))!
}

fn v_layout_float_axis_hint(node &VNode, scope map[string]VValue, start_keys []string, center_key string, end_key string) !FloatAxisHint {
	for key in start_keys {
		if expr := node.expressions[key] {
			return FloatAxisHint{
				anchor: .start
				value:  v_eval(expr, scope)!.numeric(expr.line)!
			}
		}
	}
	if expr := node.expressions[center_key] {
		return FloatAxisHint{
			anchor: .center
			value:  v_eval(expr, scope)!.numeric(expr.line)!
		}
	}
	if expr := node.expressions[end_key] {
		return FloatAxisHint{
			anchor: .end
			value:  v_eval(expr, scope)!.numeric(expr.line)!
		}
	}
	return FloatAxisHint{}
}

fn v_layout_child_metric(node &VNode, scope map[string]VValue, box bool, floating bool) !VLayoutChildMetrics {
	if !box && !floating {
		return VLayoutChildMetrics{
			frame: rect(0, 0, v_layout_dimension(node, 'width', scope, 80)!, v_layout_dimension(node,
				'height', scope, 32)!)
		}
	}
	return VLayoutChildMetrics{
		frame:            rect(if floating { v_layout_dimension(node, 'x', scope, 0)! } else { 0.0 }, if floating {
			v_layout_dimension(node, 'y', scope, 0)!
		} else {
			0.0
		}, v_layout_dimension(node, 'width', scope, 80)!, v_layout_dimension(node, 'height', scope,
			32)!)
		size_hint_x:      v_layout_dimension(node, 'size_hint_x', scope, 1)!
		size_hint_y:      v_layout_dimension(node, 'size_hint_y', scope, 1)!
		minimum_width:    v_layout_dimension(node, 'size_hint_min_x', scope, -1)!
		minimum_height:   v_layout_dimension(node, 'size_hint_min_y', scope, -1)!
		maximum_width:    v_layout_dimension(node, 'size_hint_max_x', scope, -1)!
		maximum_height:   v_layout_dimension(node, 'size_hint_max_y', scope, -1)!
		horizontal_align: v_layout_alignment(node, 'align_x', scope)!
		vertical_align:   v_layout_alignment(node, 'align_y', scope)!
		x_hint:           if floating {
			v_layout_float_axis_hint(node, scope, ['pos_hint_x'], 'pos_hint_center_x',
				'pos_hint_right')!
		} else {
			FloatAxisHint{}
		}
		y_hint:           if floating {
			v_layout_float_axis_hint(node, scope, ['pos_hint_y', 'pos_hint_top'],
				'pos_hint_center_y', 'pos_hint_bottom')!
		} else {
			FloatAxisHint{}
		}
	}
}

fn v_layout_child_metrics(node &VNode, scope map[string]VValue) ![]VLayoutChildMetrics {
	mut metrics := []VLayoutChildMetrics{}
	box := node.tag == 'BoxLayout'
	floating := node.tag in ['FloatLayout', 'RelativeLayout']
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		if node.tag == 'TabbedPanel' && child.tag != 'Tab' {
			continue
		}
		if node.tag == 'Accordion' && child.tag != 'AccordionItem' {
			continue
		}
		if child.tag != 'Repeater' {
			metrics << v_layout_child_metric(child, scope, box, floating)!
			continue
		}
		model_expr := child.expressions['model'] or {
			return error('Repeater requires `model` at line ${child.line}')
		}
		items := v_eval(model_expr, scope)!
		if items.kind != .list {
			return error('Repeater model must be a collection at line ${model_expr.line}')
		}
		for index, item in items.items {
			mut item_scope := scope.clone()
			item_scope['item'] = item
			item_scope['index'] = v_number(f64(index), index.str())
			for repeated in child.children {
				if repeated.tag in ['MenuItem', 'Option'] {
					continue
				}
				metrics << v_layout_child_metric(repeated, item_scope, box, floating)!
			}
		}
	}
	return metrics
}

fn v_eval_node(node &VNode, incoming_scope map[string]VValue, frame Rect, mut evaluation VmlEvaluation) !&VNode {
	mut scope := incoming_scope.clone()
	mut resolved := &VNode{
		tag:  node.tag
		id:   node.id
		line: node.line
		path: node.path
	}

	// Root ids are available while evaluating root-level declared properties.
	if node.id.len > 0 {
		scope[node.id] = v_object({
			'x':      v_number(frame.x, frame.x.str())
			'y':      v_number(frame.y, frame.y.str())
			'width':  v_number(frame.width, frame.width.str())
			'height': v_number(frame.height, frame.height.str())
		})
	}
	for name in node.property_order {
		expr := node.expressions[name] or { continue }
		value := v_eval(expr, scope)!
		v_validate_declared_property(name, node.property_types[name], value, expr.line)!
		resolved.props[name] = value.string_value()
		resolved.property_types[name] = node.property_types[name]
		resolved.property_order << name
		if node.id.len > 0 {
			mut object := scope[node.id] or {
				return error('internal VML scope error for `${node.id}` at line ${node.line}')
			}
			object.fields[name] = value
			scope[node.id] = object
		}
	}

	mut binding := ?VmlBinding(none)
	for key, expr in node.expressions {
		if key == 'id' || key in node.property_types || key.starts_with('bind.')
			|| key in ['on_tap', 'on_change', 'on_active', 'on_state', 'on_text', 'on_submit', 'on_text_validate', 'on_select', 'on_toggle', 'on_dismiss'] {
			continue
		}
		resolved.props[key] = v_eval(expr, scope)!.string_value()
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
		resolved.props[property] = v_eval(expr, scope)!.string_value()
		if resolved.id.len == 0 {
			resolved.id = v_control_id(node, scope)
		}
		resolved_binding := VmlBinding{
			property:           property
			target:             expr.value
			control:            resolved.id
			group:              if node.tag == 'ToggleButton' && property == 'pressed' {
				resolved.prop('group')
			} else {
				''
			}
			allow_no_selection: resolved.prop_or('allow_no_selection', 'true') == 'true'
		}
		binding = resolved_binding
		if resolved_binding.group.len > 0 {
			mut group_bindings := evaluation.toggle_group_bindings[resolved_binding.group] or {
				[]VmlBinding{}
			}
			group_bindings << resolved_binding
			evaluation.toggle_group_bindings[resolved_binding.group] = group_bindings
		}
	}
	actual := v_frame(resolved, frame)
	if node.id.len > 0 {
		mut object := scope[node.id] or {
			return error('internal VML scope error for `${node.id}` at line ${node.line}')
		}
		object.fields['x'] = v_number(actual.x, actual.x.str())
		object.fields['y'] = v_number(actual.y, actual.y.str())
		object.fields['width'] = v_number(actual.width, actual.width.str())
		object.fields['height'] = v_number(actual.height, actual.height.str())
		scope[node.id] = object
	}

	mut binding_event_property := ''
	if b := binding {
		binding_event_property = match b.property {
			'checked' {
				'on_tap'
			}
			'active' {
				'on_active'
			}
			'pressed' {
				'on_state'
			}
			'text' {
				if node.tag == 'Spinner' { 'on_text' } else { 'on_change' }
			}
			'value' {
				'on_change'
			}
			else {
				return error('two-way binding is not supported for `${b.property}` at line ${node.line}')
			}
		}

		event_id := v_event_id(node, scope, binding_event_property)
		resolved.props[binding_event_property] = event_id
		evaluation.events[event_id] = VmlEvent{
			binding: binding
		}
	}
	for property in ['on_tap', 'on_change', 'on_active', 'on_state', 'on_text', 'on_submit',
		'on_text_validate', 'on_select', 'on_toggle', 'on_dismiss'] {
		expr := node.expressions[property] or { continue }
		if expr.kind == .call || expr.kind == .assignment {
			event_id := v_event_id(node, scope, property)
			existing := evaluation.events[event_id] or { VmlEvent{} }
			resolved.props[property] = event_id
			if expr.kind == .call {
				evaluation.events[event_id] = VmlEvent{
					binding:    existing.binding
					invocation: v_action(expr, scope)!
				}
			} else {
				evaluation.events[event_id] = VmlEvent{
					binding:    existing.binding
					assignment: v_assignment(expr, scope)!
				}
			}
		} else {
			if property == binding_event_property {
				return error('a bound `${property}` handler must call an app action or assign an app field at line ${expr.line}')
			}
			resolved.props[property] = expression_text(expr)
		}
	}

	child_metrics := v_layout_child_metrics(node, scope)!
	mut layout := v_child_layout(resolved, actual, child_metrics)!
	for child in node.children {
		if child.tag == 'Repeater' {
			v_expand_repeater(child, scope, mut resolved.children, mut evaluation, mut layout)!
		} else {
			resolved_child := v_eval_node(child, scope, layout.fallback(child, scope)!, mut
				evaluation)!
			resolved.children << resolved_child
			layout.advance(resolved_child)
		}
	}
	return resolved
}

fn v_expand_repeater(node &VNode, scope map[string]VValue, mut output []&VNode, mut evaluation VmlEvaluation, mut layout VChildLayout) ! {
	model_expr := node.expressions['model'] or {
		return error('Repeater requires `model` at line ${node.line}')
	}
	key_expr := node.expressions['key'] or {
		return error('Repeater requires a stable `key` at line ${node.line}')
	}
	items := v_eval(model_expr, scope)!
	if items.kind != .list {
		return error('Repeater model must be a collection at line ${model_expr.line}')
	}
	mut keys := map[string]bool{}
	for index, item in items.items {
		mut item_scope := scope.clone()
		item_scope['item'] = item
		item_scope['index'] = v_number(f64(index), index.str())
		key := v_eval(key_expr, item_scope)!.string_value()
		if key.len == 0 {
			return error('Repeater key cannot be empty at line ${key_expr.line}')
		}
		if key in keys {
			return error('duplicate Repeater key `${key}` at line ${key_expr.line}')
		}
		keys[key] = true
		parent_key := (scope['__repeat_key'] or { v_string('') }).string_value()
		item_scope['__repeat_key'] = v_string(v_repeat_identity(parent_key, key))
		for child_index, child in node.children {
			mut repeated := v_eval_node(child, item_scope, layout.fallback(child, item_scope)!, mut
				evaluation)!
			if repeated.props['key'].len == 0 {
				repeated.props['key'] = if node.children.len == 1 {
					key
				} else {
					'${key}:${child_index}'
				}
			}
			output << repeated
			layout.advance(repeated)
		}
	}
}

fn v_validate_declared_schema(name string, type_name string, schema VSchema, line int) ! {
	expected := match type_name {
		'bool' {
			VValueKind.bool_
		}
		'string' {
			VValueKind.string_
		}
		'int', 'f32', 'f64' {
			VValueKind.number
		}
		else {
			return error('unsupported property type `${type_name}` at line ${line}')
		}
	}

	if schema.kind != expected {
		return error('property `${name}` expects `${type_name}` at line ${line}')
	}
}

fn v_validate_action[T](expr &VExpression, scope map[string]VSchema) ! {
	if expr.kind != .call || !expr.value.starts_with('app.') {
		return error('event handlers must call an app action at line ${expr.line}')
	}
	name := expr.value.all_after('app.')
	if name.len == 0 || name.contains('.') {
		return error('invalid app action `${expr.value}` at line ${expr.line}')
	}
	mut args := []VSchema{cap: expr.args.len}
	for arg in expr.args {
		args << v_schema_expression(arg, scope)!
	}
	type_check_action[T](name, args, expr.line)!
}

fn v_validate_assignment[T](expr &VExpression, scope map[string]VSchema) ! {
	if expr.kind != .assignment || expr.left.kind != .path || !expr.left.value.starts_with('app.')
		|| expr.left.value.count('.') != 1 {
		return error('event assignments must target a mutable top-level app field at line ${expr.line}')
	}
	target := expr.left.value.all_after('app.')
	type_name := vml_writable_field_type[T](target)!
	schema := v_schema_expression(expr.right, scope)!
	v_validate_declared_schema(target, type_name, schema, expr.line)!
}

fn v_validate_repeater_schema[T](node &VNode, scope map[string]VSchema) ! {
	model_expr := node.expressions['model'] or {
		return error('Repeater requires `model` at line ${node.line}')
	}
	key_expr := node.expressions['key'] or {
		return error('Repeater requires a stable `key` at line ${node.line}')
	}
	items := v_schema_expression(model_expr, scope)!
	if items.kind != .list || isnil(items.element) {
		return error('Repeater model must be a collection at line ${model_expr.line}')
	}
	mut item_scope := scope.clone()
	item_scope['item'] = *items.element
	item_scope['index'] = VSchema{
		kind: .number
	}
	key := v_schema_expression(key_expr, item_scope)!
	if key.kind in [.invalid, .object, .list] {
		return error('Repeater key must be a scalar value at line ${key_expr.line}')
	}
	for child in node.children {
		v_validate_node_schema[T](child, item_scope)!
	}
}

fn v_validate_node_schema[T](node &VNode, incoming_scope map[string]VSchema) ! {
	mut scope := incoming_scope.clone()
	if node.id.len > 0 {
		scope[node.id] = VSchema{
			kind:   .object
			fields: {
				'x':      VSchema{
					kind: .number
				}
				'y':      VSchema{
					kind: .number
				}
				'width':  VSchema{
					kind: .number
				}
				'height': VSchema{
					kind: .number
				}
			}
		}
	}
	for name in node.property_order {
		expr := node.expressions[name] or { continue }
		schema := v_schema_expression(expr, scope)!
		v_validate_declared_schema(name, node.property_types[name], schema, expr.line)!
		if node.id.len > 0 {
			mut object := scope[node.id] or {
				return error('internal VML schema error for `${node.id}` at line ${node.line}')
			}
			object.fields[name] = schema
			scope[node.id] = object
		}
	}
	for key, expr in node.expressions {
		if key == 'id' || key in node.property_types || key.starts_with('bind.')
			|| key in ['on_tap', 'on_change', 'on_active', 'on_state', 'on_text', 'on_submit', 'on_text_validate', 'on_select', 'on_toggle', 'on_dismiss'] {
			continue
		}
		v_schema_expression(expr, scope)!
	}
	for key, expr in node.expressions {
		if !key.starts_with('bind.') {
			continue
		}
		property := key.all_after('bind.')
		if property !in ['text', 'checked', 'active', 'pressed', 'value'] {
			return error('two-way binding is not supported for `${property}` at line ${node.line}')
		}
		if expr.kind != .path || !expr.value.starts_with('app.') || expr.value.count('.') != 1 {
			return error('`${key}` must target a mutable top-level app field at line ${expr.line}')
		}
		v_schema_expression(expr, scope)!
		target := expr.value.all_after('app.')
		type_name := vml_writable_field_type[T](target)!
		if property in ['checked', 'active', 'pressed'] && type_name != 'bool' {
			return error('bind.${property} requires a bool field, got `${target}` (${type_name})')
		}
		if property == 'value' && type_name !in ['int', 'f32', 'f64'] {
			return error('bind.value requires a numeric field, got `${target}` (${type_name})')
		}
	}
	for property in ['on_tap', 'on_change', 'on_active', 'on_state', 'on_text', 'on_submit',
		'on_text_validate', 'on_select', 'on_toggle', 'on_dismiss'] {
		expr := node.expressions[property] or { continue }
		if expr.kind == .call {
			v_validate_action[T](expr, scope)!
		} else if expr.kind == .assignment {
			v_validate_assignment[T](expr, scope)!
		} else {
			v_schema_expression(expr, scope)!
		}
	}
	for child in node.children {
		if child.tag == 'Repeater' {
			v_validate_repeater_schema[T](child, scope)!
		} else {
			v_validate_node_schema[T](child, scope)!
		}
	}
}

fn v_validate_template[T](root &VNode, model T) ! {
	v_validate_node_schema[T](root, {
		'app': v_schema_from(model)
	})!
}

fn v_normalize_toggle_groups(node &VNode, mut selected map[string]bool) &VNode {
	mut props := node.props.clone()
	if node.tag == 'ToggleButton' {
		group := node.prop('group')
		pressed := node.prop_bool('pressed') || node.prop('state') == 'down'
		if group.len > 0 && pressed {
			if selected[group] or { false } {
				props['pressed'] = 'false'
				props['state'] = 'normal'
			} else {
				selected[group] = true
			}
		}
	}
	mut children := []&VNode{cap: node.children.len}
	for child in node.children {
		children << v_normalize_toggle_groups(child, mut selected)
	}
	return &VNode{
		tag:            node.tag
		id:             node.id
		props:          props
		children:       children
		expressions:    node.expressions
		property_types: node.property_types
		property_order: node.property_order
		line:           node.line
		path:           node.path
	}
}

fn v_evaluate_template[T](root &VNode, model T, frame Rect) !(&VNode, map[string]VmlEvent) {
	mut evaluation := VmlEvaluation{
		events:                map[string]VmlEvent{}
		toggle_group_bindings: map[string][]VmlBinding{}
	}
	scope := {
		'app': v_value_from(model)
	}
	resolved := v_eval_node(root, scope, frame, mut evaluation)!
	mut selected := map[string]bool{}
	normalized := v_normalize_toggle_groups(resolved, mut selected)
	mut events := evaluation.events.clone()
	for event_id, event in evaluation.events {
		if binding := event.binding {
			if binding.group.len > 0 {
				events[event_id] = VmlEvent{
					binding:        event.binding
					group_bindings: evaluation.toggle_group_bindings[binding.group].clone()
					invocation:     event.invocation
					assignment:     event.assignment
				}
			}
		}
	}
	return normalized, events
}

// element_from_vml_model evaluates a VML document against a typed V model.
// It is useful for previews and tests; run_vml keeps the parsed document cached
// and additionally wires two-way bindings and actions to the live model.
pub fn element_from_vml_model[T](source string, model T, frame Rect) !Element {
	template := parse_vml(source)!
	v_validate_template[T](template, model)!
	resolved, _ := v_evaluate_template(template, model, frame)!
	element := element_from_vnode(resolved, frame)!
	validate_element_tree(element)!
	return element
}

fn vml_writable_field_type[T](name string) !string {
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

fn type_check_action[T](name string, args []VSchema, line int) ! {
	$for method in T.methods {
		if method.name == name {
			$if !method.is_pub {
				return error('app action `${name}` is not public')
			} $else $if method.typ is fn () {
				if args.len != 0 {
					return error('app action `${name}` expects no arguments at line ${line}')
				}
				return
			} $else $if method.typ is fn (int) {
				if args.len != 1 || args[0].kind != .number {
					return error('app action `${name}` expects one int argument at line ${line}')
				}
				return
			} $else $if method.typ is fn (string) {
				if args.len != 1 || args[0].kind != .string_ {
					return error('app action `${name}` expects one string argument at line ${line}')
				}
				return
			} $else {
				return error('app action `${name}` has an unsupported signature at line ${line}')
			}
		}
	}
	return error('unknown app action `${name}` at line ${line}')
}

fn vml_set_field[T](mut model T, name string, value VValue) ! {
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

fn vml_dispatch[T](mut model T, invocation VmlInvocation) ! {
	mut scope := invocation.scope.clone()
	// The app object is intentionally refreshed here. Repeater-local values stay
	// attached to the stable event identity from the rendered instance.
	scope['app'] = v_value_from(model)
	mut args := []VValue{cap: invocation.args.len}
	for expr in invocation.args {
		args << v_eval(expr, scope)!
	}
	$for method in T.methods {
		if method.name == invocation.name {
			$if method.is_pub && method.typ is fn () {
				model.$method()
				return
			} $else $if method.is_pub && method.typ is fn (int) {
				model.$method(int(args[0].numeric(invocation.line)!))
				return
			} $else $if method.is_pub && method.typ is fn (string) {
				model.$method(args[0].string_value())
				return
			}
		}
	}
	return error('unknown or unsupported app action `${invocation.name}`')
}

fn vml_apply_assignment[T](mut model T, assignment VmlAssignment) ! {
	mut scope := assignment.scope.clone()
	scope['app'] = v_value_from(model)
	vml_set_field[T](mut model, assignment.target, v_eval(assignment.value, scope)!)!
}

pub struct VmlRunConfig[T] {
pub:
	source string
	model  T
	title  string = 'App'
	width  int    = 400
	height int    = 800
	min_width  int
	min_height int
}

@[heap]
struct VmlController[T] {
	template &VNode
mut:
	model  T
	events map[string]VmlEvent
}

@[heap]
struct VmlRuntime {
mut:
	controller voidptr
}

const vml_runtime_singleton = &VmlRuntime{}

fn vml_runtime() &VmlRuntime {
	return unsafe { vml_runtime_singleton }
}

fn vml_controller_build[T]() Element {
	runtime := vml_runtime()
	mut controller := unsafe { &VmlController[T](runtime.controller) }
	return controller.build()
}

fn vml_controller_handle[T](event_id string) {
	runtime := vml_runtime()
	mut controller := unsafe { &VmlController[T](runtime.controller) }
	controller.handle(event_id)
}

fn (mut controller VmlController[T]) build() Element {
	frame := bounds()
	resolved, events := v_evaluate_template(controller.template, controller.model, rect(0, 0,
		frame.width, frame.height)) or {
		eprintln('ui2 VML evaluation failed: ${err}')
		return screen(0xffffff, [])
	}
	controller.events = events.clone()
	return element_from_vnode(resolved, rect(0, 0, frame.width, frame.height)) or {
		eprintln('ui2 VML element conversion failed: ${err}')
		screen(0xffffff, [])
	}
}

fn (mut controller VmlController[T]) handle(event_id string) {
	event := controller.events[event_id] or { return }
	if binding := event.binding {
		field_name := binding.target.all_after('app.')
		value := match binding.property {
			'checked', 'active' {
				current := v_lookup({
					'app': v_value_from(controller.model)
				}, binding.target, 0) or {
					eprintln('ui2 VML binding failed: ${err}')
					return
				}
				v_bool(!current.truthy())
			}
			'pressed' {
				v_bool(toggle_button_pressed(binding.control))
			}
			'value' {
				live := slider_value(binding.control)
				v_number(live, slider_number(live))
			}
			else {
				v_string(text(binding.control))
			}
		}

		vml_set_field[T](mut controller.model, field_name, value) or {
			eprintln('ui2 VML binding failed: ${err}')
			return
		}
		if binding.property == 'pressed' && value.truthy() {
			for peer in event.group_bindings {
				if peer.control == binding.control || peer.target == binding.target {
					continue
				}
				vml_set_field[T](mut controller.model, peer.target.all_after('app.'), v_bool(false)) or {
					eprintln('ui2 VML group binding failed: ${err}')
					return
				}
			}
		}
	}
	if invocation := event.invocation {
		vml_dispatch[T](mut controller.model, invocation) or {
			eprintln('ui2 VML action failed: ${err}')
			return
		}
	}
	if assignment := event.assignment {
		vml_apply_assignment[T](mut controller.model, assignment) or {
			eprintln('ui2 VML assignment failed: ${err}')
			return
		}
	}
	refresh()
}

// run_vml owns one typed model for the window, exposes it to VML as `app`, and
// reconciles the cached document after each binding write or app action.
pub fn run_vml[T](config VmlRunConfig[T]) ! {
	template := parse_vml(config.source)!
	v_validate_template[T](template, config.model)!
	initial_frame := rect(0, 0, f64(config.width), f64(config.height))
	resolved, events := v_evaluate_template(template, config.model, initial_frame)!
	validate_element_tree(element_from_vnode(resolved, initial_frame)!)!
	mut controller := &VmlController[T]{
		template: template
		model:    config.model
		events:   events
	}
	mut runtime := vml_runtime()
	runtime.controller = voidptr(controller)
	$if macos || windows || linux {
		run_window_with_min_size(config.title, config.width, config.height, config.min_width,
			config.min_height, vml_controller_build[T], vml_controller_handle[T])
	} $else {
		run(vml_controller_build[T], vml_controller_handle[T])
	}
}
