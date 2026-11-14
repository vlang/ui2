module ui2

// OpenUI Lang evaluator: turns parsed statements into values and nodes.
//
// Component calls become node objects (an object carrying `$component`,
// scalar props as fields, and child slots under `$slots`). Everything else
// becomes plain `OpenuiValue`s. Forward references resolve by lazy
// recursion; last definition wins for duplicate names.

pub struct OpenuiError {
pub:
	code      string
	message   string
	statement string
}

pub const openui_err_unknown_component = 'unknown-component'
pub const openui_err_missing_required = 'missing-required'
pub const openui_err_null_required = 'null-required'
pub const openui_err_type_mismatch = 'type-mismatch'
pub const openui_err_excess_args = 'excess-args'
pub const openui_err_inline_reserved = 'inline-reserved'
pub const openui_err_unknown_function = 'unknown-function'
pub const openui_err_no_root = 'no-root'
pub const openui_err_parse_failed = 'parse-failed'
pub const openui_err_runtime = 'runtime-error'
pub const openui_err_tool_not_found = 'tool-not-found'
pub const openui_err_tool_error = 'tool-error'

pub type OpenuiFuncImpl = fn (args map[string]OpenuiValue) OpenuiValue
pub type OpenuiToolFn = fn (args map[string]OpenuiValue) OpenuiValue

const openui_node_tag = '\$component'
const openui_node_slots = '\$slots'

pub fn openui_is_node(value OpenuiValue) bool {
	if value.kind != .object {
		return false
	}
	marker := value.fields[openui_node_tag] or { return false }
	return marker.kind == .string_ && marker.text.len > 0
}

pub fn openui_node_name(value OpenuiValue) string {
	marker := value.fields[openui_node_tag] or { return '' }
	return marker.text
}

pub fn openui_node_props(value OpenuiValue) map[string]OpenuiValue {
	mut props := map[string]OpenuiValue{}
	for key, field in value.fields {
		if key == openui_node_tag || key == openui_node_slots {
			continue
		}
		props[key] = field
	}
	return props
}

pub fn openui_node_slots(value OpenuiValue) map[string][]OpenuiValue {
	mut slots := map[string][]OpenuiValue{}
	raw := value.fields[openui_node_slots] or { return slots }
	if raw.kind != .object {
		return slots
	}
	for key, field in raw.fields {
		if field.kind == .list {
			slots[key] = field.items.clone()
		} else if openui_is_node(field) {
			slots[key] = [field]
		}
	}
	return slots
}

fn openui_make_node(component string, props map[string]OpenuiValue, slots map[string][]OpenuiValue) OpenuiValue {
	mut fields := map[string]OpenuiValue{}
	for key, value in props {
		fields[key] = value
	}
	fields[openui_node_tag] = openui_string(component)
	mut slot_fields := map[string]OpenuiValue{}
	for key, items in slots {
		slot_fields[key] = openui_list(items)
	}
	fields[openui_node_slots] = openui_object(slot_fields)
	return openui_object(fields)
}

// OpenuiScope carries everything evaluation needs. Tools and custom
// functions are sync and pure; async hosts re-render after fetching.

pub struct OpenuiScope {
pub mut:
	library        OpenuiLibrary
	tools          map[string]OpenuiToolFn
	funcs          map[string]OpenuiFuncImpl
	statements     map[string]&OpenuiExpr
	statement_line map[string]int
	state_defaults map[string]OpenuiValue
	state_values   map[string]OpenuiValue
	query_defs     map[string]&OpenuiExpr
	query_values   map[string]OpenuiValue
	mutation_defs  map[string]&OpenuiExpr
	values         map[string]OpenuiValue
	resolved       map[string]bool
	visiting       map[string]bool
	errors         []OpenuiError
	nested         int
}

pub fn new_openui_scope(library OpenuiLibrary) OpenuiScope {
	return OpenuiScope{
		library: library
	}
}

fn (mut scope OpenuiScope) fail(code string, statement string, message string) {
	scope.errors << OpenuiError{
		code:      code
		message:   message
		statement: statement
	}
}

fn openui_check_value(value OpenuiValue, schema OpenuiSchema) bool {
	if value.kind == .null_ || value.kind == .invalid {
		return schema.optional
	}
	match schema.kind {
		.string_ {
			if schema.enum_values.len > 0 {
				if value.kind != .string_ {
					return false
				}
				return value.text in schema.enum_values
			}
			return value.kind == .string_
		}
		.number {
			if value.kind == .number {
				return true
			}
			if value.kind == .string_ && value.text.len > 0 {
				_ := value.text.f64()
				return true
			}
			return false
		}
		.bool_ {
			return value.kind == .bool_
		}
		.list {
			return value.kind == .list
		}
		.action {
			return value.kind == .action
		}
		.object {
			return true
		}
		.null_ {
			return value.kind == .null_
		}
		.invalid {
			return false
		}
	}
}

fn openui_coerce(value OpenuiValue) OpenuiValue {
	if value.kind == .string_ {
		trimmed := value.text.trim_space()
		if trimmed.len > 0 {
			mut numeric := true
			mut saw_digit := false
			mut saw_dot := false
			for index, c in trimmed.bytes() {
				if c >= `0` && c <= `9` {
					saw_digit = true
				} else if c == `.` && !saw_dot && index > 0 {
					saw_dot = true
				} else if c == `-` && index == 0 {
					continue
				} else {
					numeric = false
					break
				}
			}
			if numeric && saw_digit {
				return openui_number(trimmed.f64())
			}
		}
	}
	return value
}

// eval_program evaluates every statement; last definition wins for
// duplicates. `$name` statements seed state, `Query` runs tools (or
// defaults), `Mutation` registers without running.

pub fn openui_eval_program(statements []OpenuiStatement, mut scope OpenuiScope) {
	for statement in statements {
		scope.statements[statement.name] = statement.expr
		scope.statement_line[statement.name] = statement.line
	}
	for statement in statements {
		if statement.name.starts_with('\$') {
			key := statement.name[1..]
			scope.nested++
			value := scope.eval_expr(statement.expr, statement.name)
			scope.nested--
			scope.state_defaults[key] = value
			if key !in scope.state_values {
				scope.state_values[key] = value
			}
			scope.values[statement.name] = value
			scope.resolved[statement.name] = true
		}
	}
	for statement in statements {
		if statement.name.starts_with('\$') {
			continue
		}
		scope.eval_statement(statement.name)
	}
}

fn (mut scope OpenuiScope) eval_statement(name string) OpenuiValue {
	if done := scope.resolved[name] {
		if done {
			return scope.values[name] or { openui_null() }
		}
	}
	if name in scope.visiting {
		scope.fail(openui_err_runtime, name, 'circular reference `${name}`')
		return openui_null()
	}
	expr := scope.statements[name] or { return openui_null() }
	scope.visiting[name] = true
	scope.nested++
	value := scope.eval_expr(expr, name)
	scope.nested--
	scope.visiting.delete(name)
	scope.values[name] = value
	scope.resolved[name] = true
	return value
}

fn (mut scope OpenuiScope) eval_expr(expr &OpenuiExpr, statement string) OpenuiValue {
	match expr.kind {
		.literal {
			if expr.is_null {
				return openui_null()
			}
			if expr.is_bool {
				return openui_bool(expr.bool_value)
			}
			if expr.quoted {
				return openui_string(expr.value)
			}
			return openui_number(expr.value.f64())
		}
		.ref {
			if value := scope.values[expr.value] {
				if scope.resolved[expr.value] {
					return value
				}
			}
			if expr.value in scope.statements {
				return scope.eval_statement(expr.value)
			}
			return openui_string(expr.value)
		}
		.state_ref {
			key := expr.value.split('.')[0]
			if value := scope.state_values[key] {
				if expr.value.contains('.') {
					return openui_member_path(value, expr.value.all_after('.'))
				}
				return value
			}
			if default_ := scope.state_defaults[key] {
				return default_
			}
			return openui_null()
		}
		.member {
			target := scope.eval_expr(expr.target, statement)
			return openui_member_lookup(target, expr.field)
		}
		.array {
			mut items := []OpenuiValue{cap: expr.args.len}
			for item in expr.args {
				items << scope.eval_expr(item, statement)
			}
			return openui_list(items)
		}
		.object {
			mut fields := map[string]OpenuiValue{}
			for key in expr.field_order {
				fields[key] = scope.eval_expr(expr.fields[key] or { continue }, statement)
			}
			return openui_object(fields)
		}
		.unary {
			operand := scope.eval_expr(expr.left, statement)
			if expr.value == '!' {
				return openui_bool(!operand.truthy())
			}
			number := operand.numeric() or {
				scope.fail(openui_err_runtime, statement, 'cannot negate at line ${expr.line}')
				return openui_null()
			}
			return openui_number(-number)
		}
		.binary {
			return scope.eval_binary(expr, statement)
		}
		.ternary {
			cond := scope.eval_expr(expr.left, statement)
			if cond.truthy() {
				return scope.eval_expr(expr.middle, statement)
			}
			return scope.eval_expr(expr.right, statement)
		}
		.call {
			return scope.eval_component(expr.value, expr.args, expr.line, statement)
		}
		.at_call {
			return scope.eval_at_call(expr.value, expr.args, expr.line, statement)
		}
		.action_list {
			return scope.eval_action_list(expr.args, expr.line, statement)
		}
		.query {
			return scope.eval_query(expr, statement)
		}
		.mutation {
			return scope.eval_mutation(expr, statement)
		}
	}
}

fn openui_member_path(value OpenuiValue, path string) OpenuiValue {
	mut current := value
	for part in path.split('.') {
		current = openui_member_lookup(current, part)
	}
	return current
}

fn openui_member_lookup(target OpenuiValue, field string) OpenuiValue {
	match target.kind {
		.object {
			if openui_is_node(target) {
				props := openui_node_props(target)
				if value := props[field] {
					return value
				}
			}
			if value := target.fields[field] {
				return value
			}
			return openui_null()
		}
		.list {
			if field == 'len' {
				return openui_number(f64(target.items.len))
			}
			mut plucked := []OpenuiValue{}
			for item in target.items {
				if item.kind == .object {
					if value := item.fields[field] {
						plucked << value
						continue
					}
				}
				plucked << openui_null()
			}
			return openui_list(plucked)
		}
		.string_ {
			if field == 'len' {
				return openui_number(f64(target.text.runes().len))
			}
			return openui_null()
		}
		else {
			return openui_null()
		}
	}
}

fn openui_values_equal(left OpenuiValue, right OpenuiValue) bool {
	if left.kind == .number && right.kind == .number {
		return left.number == right.number
	}
	if left.kind == .bool_ && right.kind == .bool_ {
		return left.bool_ == right.bool_
	}
	return left.string_value() == right.string_value()
}

fn (mut scope OpenuiScope) eval_binary(expr &OpenuiExpr, statement string) OpenuiValue {
	left := scope.eval_expr(expr.left, statement)
	if expr.value == '&&' && !left.truthy() {
		return openui_bool(false)
	}
	if expr.value == '||' && left.truthy() {
		return openui_bool(true)
	}
	right := scope.eval_expr(expr.right, statement)
	match expr.value {
		'+' {
			if left.kind == .string_ || right.kind == .string_ {
				return openui_string(left.string_value() + right.string_value())
			}
			left_num := left.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `+` operands at line ${expr.line}')
				return openui_null()
			}
			right_num := right.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `+` operands at line ${expr.line}')
				return openui_null()
			}
			return openui_number(left_num + right_num)
		}
		'-' {
			left_num := left.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `-` operands at line ${expr.line}')
				return openui_null()
			}
			right_num := right.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `-` operands at line ${expr.line}')
				return openui_null()
			}
			return openui_number(left_num - right_num)
		}
		'*' {
			left_num := left.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `*` operands at line ${expr.line}')
				return openui_null()
			}
			right_num := right.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `*` operands at line ${expr.line}')
				return openui_null()
			}
			return openui_number(left_num * right_num)
		}
		'/' {
			left_num := left.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `/` operands at line ${expr.line}')
				return openui_null()
			}
			right_num := right.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `/` operands at line ${expr.line}')
				return openui_null()
			}
			if right_num == 0 {
				scope.fail(openui_err_runtime, statement, 'division by zero at line ${expr.line}')
				return openui_null()
			}
			return openui_number(left_num / right_num)
		}
		'%' {
			left_num := left.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `%` operands at line ${expr.line}')
				return openui_null()
			}
			right_num := right.numeric() or {
				scope.fail(openui_err_runtime, statement, 'bad `%` operands at line ${expr.line}')
				return openui_null()
			}
			if right_num == 0 {
				scope.fail(openui_err_runtime, statement, 'division by zero at line ${expr.line}')
				return openui_null()
			}
			return openui_number(left_num - f64(i64(left_num / right_num)) * right_num)
		}
		'==' {
			return openui_bool(openui_values_equal(left, right))
		}
		'!=' {
			return openui_bool(!openui_values_equal(left, right))
		}
		'<' {
			left_num := left.numeric() or { return openui_bool(left.string_value() < right.string_value()) }
			right_num := right.numeric() or { return openui_bool(left.string_value() < right.string_value()) }
			return openui_bool(left_num < right_num)
		}
		'<=' {
			left_num := left.numeric() or { return openui_bool(left.string_value() <= right.string_value()) }
			right_num := right.numeric() or { return openui_bool(left.string_value() <= right.string_value()) }
			return openui_bool(left_num <= right_num)
		}
		'>' {
			left_num := left.numeric() or { return openui_bool(left.string_value() > right.string_value()) }
			right_num := right.numeric() or { return openui_bool(left.string_value() > right.string_value()) }
			return openui_bool(left_num > right_num)
		}
		'>=' {
			left_num := left.numeric() or { return openui_bool(left.string_value() >= right.string_value()) }
			right_num := right.numeric() or { return openui_bool(left.string_value() >= right.string_value()) }
			return openui_bool(left_num >= right_num)
		}
		'&&' {
			return openui_bool(left.truthy() && right.truthy())
		}
		'||' {
			return openui_bool(left.truthy() || right.truthy())
		}
		else {
			scope.fail(openui_err_runtime, statement, 'unknown operator at line ${expr.line}')
			return openui_null()
		}
	}
}

// eval_component maps positional args to params by declaration order and
// validates them like Zod schemas. Unknown components drop with an error;
// excess args drop with `excess-args`.

fn (mut scope OpenuiScope) eval_component(name string, args []&OpenuiExpr, line int, statement string) OpenuiValue {
	component := scope.library.find(name) or {
		scope.fail(openui_err_unknown_component, statement, 'unknown component `${name}` at line ${line}')
		return openui_null()
	}
	if args.len > component.params.len {
		scope.fail(openui_err_excess_args, statement, 'too many args for `${name}` at line ${line}')
	}
	mut props := map[string]OpenuiValue{}
	mut slots := map[string][]OpenuiValue{}
	mut saw_null_runtime := false
	for index, param in component.params {
		if index >= args.len {
			if param.schema.optional {
				props[param.name] = param.schema.default_
				continue
			}
			scope.fail(openui_err_missing_required, statement, 'missing `${param.name}` for `${name}` at line ${line}')
			return openui_null()
		}
		raw := scope.eval_expr(args[index], statement)
		if raw.kind == .null_ || raw.kind == .invalid {
			if param.schema.optional {
				props[param.name] = param.schema.default_
				continue
			}
			arg := args[index]
			if arg.kind == .literal && arg.is_null {
				scope.fail(openui_err_null_required, statement, 'null `${param.name}` for `${name}` at line ${line}')
				return openui_null()
			}
			saw_null_runtime = true
			continue
		}
		if param.schema.kind == .list {
			if raw.kind == .list {
				slots[param.name] = raw.items.clone()
				continue
			}
			if openui_is_node(raw) {
				slots[param.name] = [raw]
				continue
			}
			scope.fail(openui_err_type_mismatch, statement, '`${param.name}` wants a list at line ${line}')
			return openui_null()
		}
		if param.schema.kind == .action {
			if raw.kind != .action {
				scope.fail(openui_err_type_mismatch, statement, '`${param.name}` wants an action at line ${line}')
				return openui_null()
			}
			props[param.name] = raw
			continue
		}
		if openui_is_node(raw) && param.schema.kind != .object {
			scope.fail(openui_err_type_mismatch, statement, '`${param.name}` wants ${param.schema.kind} at line ${line}')
			return openui_null()
		}
		if !openui_check_value(raw, param.schema) {
			if param.schema.optional {
				props[param.name] = param.schema.default_
				continue
			}
			scope.fail(openui_err_type_mismatch, statement, 'bad `${param.name}` for `${name}` at line ${line}')
			return openui_null()
		}
		props[param.name] = openui_coerce(raw)
	}
	if saw_null_runtime {
		return openui_null()
	}
	return openui_make_node(name, props, slots)
}

fn (mut scope OpenuiScope) eval_at_call(name string, args []&OpenuiExpr, line int, statement string) OpenuiValue {
	if value := scope.eval_builtin(name, args, line, statement) {
		return value
	}
	if impl := scope.funcs[name] {
		return scope.eval_custom_func(name, impl, args, line, statement)
	}
	step := scope.eval_action_step(name, args, line, statement, true) or { return openui_null() }
	return openui_action([step])
}

fn (mut scope OpenuiScope) eval_builtin(name string, args []&OpenuiExpr, line int, statement string) ?OpenuiValue {
	match name {
		'Count', 'Sum', 'Avg', 'Min', 'Max', 'First', 'Last' {
			if args.len != 1 {
				scope.fail(openui_err_type_mismatch, statement, '`@${name}` wants 1 arg at line ${line}')
				return openui_null()
			}
			items := scope.eval_expr(args[0], statement)
			if items.kind != .list {
				scope.fail(openui_err_runtime, statement, '`@${name}` wants an array at line ${line}')
				return openui_null()
			}
			return openui_builtin_aggregate(name, items.items)
		}
		'Filter', 'Sort' {
			return scope.eval_builtin_filter_sort(name, args, line, statement)
		}
		'Round', 'Abs', 'Floor', 'Ceil' {
			return scope.eval_builtin_math(name, args, line, statement)
		}
		'Each' {
			return scope.eval_builtin_each(args, line, statement)
		}
		else {
			return none
		}
	}
}

fn openui_builtin_aggregate(name string, items []OpenuiValue) OpenuiValue {
	match name {
		'Count' {
			return openui_number(f64(items.len))
		}
		'Sum' {
			mut total := 0.0
			for item in items {
				number := item.numeric() or { continue }
				total += number
			}
			return openui_number(total)
		}
		'Avg' {
			if items.len == 0 {
				return openui_null()
			}
			mut total := 0.0
			mut count := 0
			for item in items {
				number := item.numeric() or { continue }
				total += number
				count++
			}
			if count == 0 {
				return openui_null()
			}
			return openui_number(total / f64(count))
		}
		'Min' {
			if items.len == 0 {
				return openui_null()
			}
			mut best := 0.0
			mut have := false
			for item in items {
				number := item.numeric() or { continue }
				if !have || number < best {
					best = number
					have = true
				}
			}
			if !have {
				return openui_null()
			}
			return openui_number(best)
		}
		'Max' {
			if items.len == 0 {
				return openui_null()
			}
			mut best := 0.0
			mut have := false
			for item in items {
				number := item.numeric() or { continue }
				if !have || number > best {
					best = number
					have = true
				}
			}
			if !have {
				return openui_null()
			}
			return openui_number(best)
		}
		'First' {
			if items.len == 0 {
				return openui_null()
			}
			return items[0]
		}
		'Last' {
			if items.len == 0 {
				return openui_null()
			}
			return items[items.len - 1]
		}
		else {
			return openui_null()
		}
	}
}

fn openui_filter_match(item OpenuiValue, field string, op string, want OpenuiValue) bool {
	value := if item.kind == .object {
		item.fields[field] or { openui_null() }
	} else {
		item
	}
	match op {
		'==' {
			return openui_values_equal(value, want)
		}
		'!=' {
			return !openui_values_equal(value, want)
		}
		'contains' {
			if value.kind == .list {
				for entry in value.items {
					if openui_values_equal(entry, want) {
						return true
					}
				}
				return false
			}
			return value.string_value().contains(want.string_value())
		}
		'>', '<', '>=', '<=' {
			left := value.numeric() or { return false }
			right := want.numeric() or { return false }
			if op == '>' {
				return left > right
			}
			if op == '<' {
				return left < right
			}
			if op == '>=' {
				return left >= right
			}
			return left <= right
		}
		else {
			return false
		}
	}
}

fn (mut scope OpenuiScope) eval_builtin_filter_sort(name string, args []&OpenuiExpr, line int, statement string) OpenuiValue {
	if name == 'Filter' {
		if args.len != 4 {
			scope.fail(openui_err_type_mismatch, statement, '`@Filter` wants 4 args at line ${line}')
			return openui_null()
		}
		items := scope.eval_expr(args[0], statement)
		field := scope.eval_expr(args[1], statement)
		op := scope.eval_expr(args[2], statement)
		want := scope.eval_expr(args[3], statement)
		if items.kind != .list || field.kind != .string_ || op.kind != .string_ {
			scope.fail(openui_err_runtime, statement, 'bad `@Filter` args at line ${line}')
			return openui_null()
		}
		if op.text !in ['==', '!=', '>', '<', '>=', '<=', 'contains'] {
			scope.fail(openui_err_runtime, statement, 'bad `@Filter` operator at line ${line}')
			return openui_null()
		}
		mut kept := []OpenuiValue{}
		for item in items.items {
			if openui_filter_match(item, field.text, op.text, want) {
				kept << item
			}
		}
		return openui_list(kept)
	}
	if args.len < 2 || args.len > 3 {
		scope.fail(openui_err_type_mismatch, statement, '`@Sort` wants 2-3 args at line ${line}')
		return openui_null()
	}
	items := scope.eval_expr(args[0], statement)
	field := scope.eval_expr(args[1], statement)
	mut descending := false
	if args.len == 3 {
		dir := scope.eval_expr(args[2], statement)
		if dir.kind != .string_ || (dir.text != 'asc' && dir.text != 'desc') {
			scope.fail(openui_err_runtime, statement, 'bad `@Sort` direction at line ${line}')
			return openui_null()
		}
		descending = dir.text == 'desc'
	}
	if items.kind != .list || field.kind != .string_ {
		scope.fail(openui_err_runtime, statement, 'bad `@Sort` args at line ${line}')
		return openui_null()
	}
	mut sorted := items.items.clone()
	field_name := field.text
	for i := 1; i < sorted.len; i++ {
		mut j := i
		for j > 0 {
			previous := openui_sort_key(sorted[j - 1], field_name)
			current := openui_sort_key(sorted[j], field_name)
			swap := if descending { current > previous } else { current < previous }
			if !swap {
				break
			}
			sorted[j - 1], sorted[j] = sorted[j], sorted[j - 1]
			j--
		}
	}
	return openui_list(sorted)
}

fn openui_sort_key(item OpenuiValue, field string) string {
	if item.kind == .object {
		value := item.fields[field] or { return '' }
		return value.string_value()
	}
	return item.string_value()
}

fn (mut scope OpenuiScope) eval_builtin_math(name string, args []&OpenuiExpr, line int, statement string) OpenuiValue {
	if args.len < 1 || args.len > 2 {
		scope.fail(openui_err_type_mismatch, statement, '`@${name}` wants 1-2 args at line ${line}')
		return openui_null()
	}
	target := scope.eval_expr(args[0], statement)
	mut decimals := 0
	if args.len == 2 {
		precision := scope.eval_expr(args[1], statement)
		decimals = int(precision.numeric() or {
			scope.fail(openui_err_runtime, statement, 'bad `@${name}` precision at line ${line}')
			return openui_null()
		})
	}
	apply := fn [name, decimals] (value OpenuiValue) OpenuiValue {
		number := value.numeric() or { return openui_null() }
		match name {
			'Round' {
				mut factor := 1.0
				for _ in 0 .. decimals {
					factor *= 10.0
				}
				rounded := f64(i64(number * factor + if number >= 0 { 0.5 } else { -0.5 })) / factor
				return openui_number(rounded)
			}
			'Abs' {
				if number < 0 {
					return openui_number(-number)
				}
				return openui_number(number)
			}
			'Floor' {
				return openui_number(f64(i64(number)) - if number < 0 && number != f64(i64(number)) {
					1.0
				} else {
					0.0
				})
			}
			else {
				whole := i64(number)
				return openui_number(f64(whole) + if number > f64(whole) { 1.0 } else { 0.0 })
			}
		}
	}
	if target.kind == .list {
		mut out := []OpenuiValue{cap: target.items.len}
		for item in target.items {
			out << apply(item)
		}
		return openui_list(out)
	}
	return apply(target)
}

fn (mut scope OpenuiScope) eval_builtin_each(args []&OpenuiExpr, line int, statement string) OpenuiValue {
	if args.len != 3 {
		scope.fail(openui_err_type_mismatch, statement, '`@Each` wants 3 args at line ${line}')
		return openui_null()
	}
	items := scope.eval_expr(args[0], statement)
	loop_var := if args[1].kind == .ref {
		args[1].value
	} else if args[1].kind == .literal && args[1].quoted {
		args[1].value
	} else {
		scope.fail(openui_err_runtime, statement, '`@Each` loop var must be a name at line ${line}')
		return openui_null()
	}
	if items.kind != .list {
		scope.fail(openui_err_runtime, statement, '`@Each` wants an array at line ${line}')
		return openui_null()
	}
	template := args[2]
	mut out := []OpenuiValue{cap: items.items.len}
	had_previous := loop_var in scope.values
	previous := scope.values[loop_var] or { openui_null() }
	for item in items.items {
		scope.values[loop_var] = item
		scope.resolved[loop_var] = true
		out << scope.eval_expr(template, statement)
	}
	if had_previous {
		scope.values[loop_var] = previous
	} else {
		scope.values.delete(loop_var)
		scope.resolved.delete(loop_var)
	}
	return openui_list(out)
}

fn (mut scope OpenuiScope) eval_custom_func(name string, impl OpenuiFuncImpl, args []&OpenuiExpr, line int, statement string) OpenuiValue {
	mut metadata := OpenuiFunction{}
	mut found := false
	for function in scope.library.functions {
		if function.name == name {
			metadata = function
			found = true
			break
		}
	}
	mut call_args := map[string]OpenuiValue{}
	if found {
		if args.len > metadata.params.len {
			scope.fail(openui_err_excess_args, statement, 'too many args for `@${name}` at line ${line}')
		}
		for index, param in metadata.params {
			if index >= args.len {
				if param.optional {
					continue
				}
				scope.fail(openui_err_missing_required, statement, 'missing `${param.name}` for `@${name}` at line ${line}')
				return openui_null()
			}
			raw := scope.eval_expr(args[index], statement)
			if raw.kind == .null_ || raw.kind == .invalid {
				arg := args[index]
				if arg.kind == .literal && arg.is_null {
					scope.fail(openui_err_null_required, statement, 'null `${param.name}` for `@${name}` at line ${line}')
					return openui_null()
				}
				if !param.optional {
					return openui_null()
				}
				continue
			}
			if !openui_check_value(raw, param.schema) {
				if param.optional {
					continue
				}
				scope.fail(openui_err_type_mismatch, statement, 'bad `${param.name}` for `@${name}` at line ${line}')
				return openui_null()
			}
			call_args[param.name] = openui_coerce(raw)
		}
	} else {
		for index, arg in args {
			call_args['arg${index}'] = scope.eval_expr(arg, statement)
		}
	}
	return impl(call_args)
}

// eval_action_step builds one validated action step. Built-in mistakes are
// reported and skipped; custom actions with any invalid argument are a
// silent no-op; unknown names report `unknown-function`.

fn (mut scope OpenuiScope) eval_action_step(name string, args []&OpenuiExpr, line int, statement string, value_position bool) ?OpenuiActionCall {
	match name {
		'ToAssistant' {
			if args.len < 1 || args.len > 2 {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@ToAssistant` args at line ${line}')
				return none
			}
			message := scope.eval_expr(args[0], statement)
			mut evaluated := [message]
			if args.len == 2 {
				evaluated << scope.eval_expr(args[1], statement)
			}
			return OpenuiActionCall{
				name: name
				args: evaluated
			}
		}
		'OpenUrl' {
			if args.len != 1 {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@OpenUrl` args at line ${line}')
				return none
			}
			target := scope.eval_expr(args[0], statement)
			if target.kind != .string_ {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@OpenUrl` url at line ${line}')
				return none
			}
			return OpenuiActionCall{
				name: name
				args: [target]
			}
		}
		'Set' {
			if args.len != 2 || args[0].kind != .state_ref {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@Set` args at line ${line}')
				return none
			}
			return OpenuiActionCall{
				name: name
				args: [openui_string(args[0].value), scope.eval_expr(args[1], statement)]
			}
		}
		'Reset' {
			if args.len == 0 {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@Reset` args at line ${line}')
				return none
			}
			mut names := []OpenuiValue{}
			for arg in args {
				if arg.kind != .state_ref {
					scope.fail(openui_err_type_mismatch, statement, 'bad `@Reset` args at line ${line}')
					return none
				}
				names << openui_string(arg.value)
			}
			return OpenuiActionCall{
				name: name
				args: names
			}
		}
		'Run' {
			if args.len != 1 || args[0].kind != .ref {
				scope.fail(openui_err_type_mismatch, statement, 'bad `@Run` target at line ${line}')
				return none
			}
			return OpenuiActionCall{
				name: name
				args: [openui_string(args[0].value)]
			}
		}
		else {
			for action in scope.library.actions {
				if action.name == name {
					return scope.eval_custom_action(action, args, line, statement)
				}
			}
			_ = value_position
			scope.fail(openui_err_unknown_function, statement, 'unknown `@${name}` at line ${line}')
			return none
		}
	}
}

fn (mut scope OpenuiScope) eval_custom_action(action OpenuiCustomAction, args []&OpenuiExpr, line int, statement string) ?OpenuiActionCall {
	if args.len > action.params.len {
		return none
	}
	mut evaluated := []OpenuiValue{}
	for index, param in action.params {
		if index >= args.len {
			if param.optional {
				continue
			}
			return none
		}
		raw := scope.eval_expr(args[index], statement)
		if raw.kind == .null_ || raw.kind == .invalid {
			return none
		}
		if !openui_check_value(raw, param.schema) {
			return none
		}
		evaluated << openui_coerce(raw)
	}
	return OpenuiActionCall{
		name: action.name
		args: evaluated
	}
}

fn (mut scope OpenuiScope) eval_action_list(args []&OpenuiExpr, line int, statement string) OpenuiValue {
	mut steps := []OpenuiActionCall{}
	for arg in args {
		if arg.kind != .at_call {
			mut plain := []OpenuiValue{}
			for item in args {
				plain << scope.eval_expr(item, statement)
			}
			return openui_list(plain)
		}
		step := scope.eval_action_step(arg.value, arg.args, arg.line, statement, false) or {
			continue
		}
		steps << step
	}
	return openui_action(steps)
}

fn (mut scope OpenuiScope) eval_query(expr &OpenuiExpr, statement string) OpenuiValue {
	if scope.nested > 1 {
		scope.fail(openui_err_inline_reserved, statement, '`Query` must be top-level at line ${expr.line}')
		return openui_null()
	}
	if expr.args.len < 2 || expr.args.len > 4 {
		scope.fail(openui_err_type_mismatch, statement, 'bad `Query` args at line ${expr.line}')
		return openui_null()
	}
	name_value := scope.eval_expr(expr.args[0], statement)
	call_args := scope.eval_expr(expr.args[1], statement)
	defaults := scope.eval_expr(expr.args[2], statement)
	if name_value.kind != .string_ {
		scope.fail(openui_err_type_mismatch, statement, 'bad `Query` name at line ${expr.line}')
		return openui_null()
	}
	scope.query_defs[statement] = expr
	if tool := scope.tools[name_value.text] {
		mut plain := map[string]OpenuiValue{}
		if call_args.kind == .object {
			for key, value in call_args.fields {
				plain[key] = value
			}
		}
		result := tool(plain)
		scope.query_values[statement] = result
		return result
	}
	scope.fail(openui_err_tool_not_found, statement, 'unknown tool `${name_value.text}` at line ${expr.line}')
	scope.query_values[statement] = defaults
	return defaults
}

fn (mut scope OpenuiScope) eval_mutation(expr &OpenuiExpr, statement string) OpenuiValue {
	if scope.nested > 1 {
		scope.fail(openui_err_inline_reserved, statement, '`Mutation` must be top-level at line ${expr.line}')
		return openui_null()
	}
	if expr.args.len < 1 || expr.args.len > 2 {
		scope.fail(openui_err_type_mismatch, statement, 'bad `Mutation` args at line ${expr.line}')
		return openui_null()
	}
	name_value := scope.eval_expr(expr.args[0], statement)
	if name_value.kind != .string_ {
		scope.fail(openui_err_type_mismatch, statement, 'bad `Mutation` name at line ${expr.line}')
		return openui_null()
	}
	scope.mutation_defs[statement] = expr
	return openui_object({
		'status': openui_string('idle')
	})
}
