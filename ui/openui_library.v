module ui2

// OpenUI Lang support: component registry, values, and schemas.
//
// OpenUI Lang is the contract between a model and the application: the app
// defines the components the model may use, generates prompt instructions
// from those definitions, and streams the model's response into a renderer.
// This file carries the V equivalent of Zod schemas + `defineComponent` /
// `createLibrary`: semantic prop values, ordered param lists (positional
// mapping follows declaration order, `null` skips an optional), and the
// render callbacks that turn props into `Element`.

pub enum OpenuiValueKind {
	invalid
	string_
	number
	bool_
	list
	object
	action
	bind
	null_
}

pub struct OpenuiActionCall {
pub:
	name string
	args []OpenuiValue
}

pub struct OpenuiValue {
pub:
	kind   OpenuiValueKind
	text   string
	number f64
	bool_  bool
	items  []OpenuiValue
	fields map[string]OpenuiValue
	steps  []OpenuiActionCall
}

pub fn openui_string(value string) OpenuiValue {
	return OpenuiValue{
		kind: .string_
		text: value
	}
}

pub fn openui_number(value f64) OpenuiValue {
	return OpenuiValue{
		kind:   .number
		number: value
		text:   if value == f64(i64(value)) && value < 1e15 && value > -1e15 {
			i64(value).str()
		} else {
			value.str()
		}
	}
}

pub fn openui_bool(value bool) OpenuiValue {
	return OpenuiValue{
		kind:  .bool_
		bool_: value
	}
}

pub fn openui_null() OpenuiValue {
	return OpenuiValue{
		kind: .null_
	}
}

pub fn openui_list(items []OpenuiValue) OpenuiValue {
	return OpenuiValue{
		kind:  .list
		items: items.clone()
	}
}

pub fn openui_object(fields map[string]OpenuiValue) OpenuiValue {
	return OpenuiValue{
		kind:   .object
		fields: fields.clone()
	}
}

pub fn openui_action(steps []OpenuiActionCall) OpenuiValue {
	return OpenuiValue{
		kind:  .action
		steps: steps.clone()
	}
}

pub fn (value OpenuiValue) string_value() string {
	return match value.kind {
		.string_, .number { value.text }
		.bool_ {
			if value.bool_ { 'true' } else { 'false' }
		}
		.list { value.items.len.str() }
		.object { '' }
		.action { '' }
		.bind { '' }
		.null_, .invalid { '' }
	}
}

pub fn (value OpenuiValue) truthy() bool {
	return match value.kind {
		.bool_ { value.bool_ }
		.number { value.number != 0 }
		.string_ { value.text.len > 0 && value.text != 'false' }
		.list { value.items.len > 0 }
		.object { true }
		.action { value.steps.len > 0 }
		.bind { false }
		.null_, .invalid { false }
	}
}

pub fn (value OpenuiValue) numeric() !f64 {
	if value.kind == .number {
		return value.number
	}
	if value.kind == .string_ && value.text.len > 0 {
		return value.text.f64()
	}
	return error('expected a number')
}

// OpenuiSchema is the V equivalent of a Zod schema. `element` describes list
// items, `enum_values` restricts a string, `ref_component` names the child
// component a slot accepts (the `.ref` composition pattern).

pub struct OpenuiSchema {
pub:
	kind          OpenuiValueKind
	enum_values   []string
	ref_component string
	optional      bool
mut:
	element  &OpenuiSchema = unsafe { nil }
	default_ OpenuiValue
}

pub fn openui_string_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .string_
	}
}

pub fn openui_number_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .number
	}
}

pub fn openui_bool_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .bool_
	}
}

pub fn openui_schema_enum(values []string) OpenuiSchema {
	return OpenuiSchema{
		kind:        .string_
		enum_values: values.clone()
	}
}

pub fn openui_any_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .object
	}
}

pub fn openui_list_schema(element OpenuiSchema) OpenuiSchema {
	return OpenuiSchema{
		kind:    .list
		element: &element
	}
}

pub fn openui_action_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .action
	}
}

// openui_bind_schema marks a slot that takes a `$variable` reference. The
// renderer passes the current value as the prop and writes edits back.

pub fn openui_bind_schema() OpenuiSchema {
	return OpenuiSchema{
		kind: .bind
	}
}

pub fn openui_optional(schema OpenuiSchema, default_ OpenuiValue) OpenuiSchema {
	return OpenuiSchema{
		kind:          schema.kind
		enum_values:   schema.enum_values.clone()
		ref_component: schema.ref_component
		optional:      true
		element:       schema.element
		default_:      default_
	}
}

// OpenuiParam is one positional slot. Declaration order is the positional
// order the model writes; required params come first.

pub struct OpenuiParam {
pub:
	name   string
	schema OpenuiSchema
}

// OpenuiCtx is what a render callback receives: the statement id, resolved
// semantic props, already-rendered children, and the frame the renderer
// assigned. Component authors never compute layout.

pub struct OpenuiCtx {
pub:
	id       string
	props    map[string]OpenuiValue
	children []Element
	frame    Rect
}

pub fn (ctx OpenuiCtx) string_prop(name string) string {
	value := ctx.props[name] or { return '' }
	return value.string_value()
}

pub fn (ctx OpenuiCtx) number_prop(name string, fallback f64) f64 {
	value := ctx.props[name] or { return fallback }
	number := value.numeric() or { return fallback }
	return number
}

pub fn (ctx OpenuiCtx) bool_prop(name string) bool {
	value := ctx.props[name] or { return false }
	return value.truthy()
}

pub fn (ctx OpenuiCtx) list_prop(name string) []OpenuiValue {
	value := ctx.props[name] or { return []OpenuiValue{} }
	if value.kind == .list {
		return value.items.clone()
	}
	return []OpenuiValue{}
}

pub fn (ctx OpenuiCtx) text_style() TextStyle {
	return TextStyle{}
}

pub fn (ctx OpenuiCtx) box_style() BoxStyle {
	return BoxStyle{}
}

pub type OpenuiRenderFn = fn (ctx OpenuiCtx) Element

pub type OpenuiHeightFn = fn (props map[string]OpenuiValue) f64

pub struct OpenuiComponent {
pub:
	name        string
	description string
	params      []OpenuiParam
	height      f64 = 32
mut:
	render           OpenuiRenderFn
	height_for_props ?OpenuiHeightFn
}

pub struct OpenuiFuncParam {
pub:
	name     string
	schema   OpenuiSchema
	optional bool
}

pub struct OpenuiFunction {
pub:
	name        string
	description string
	params      []OpenuiFuncParam
}

pub struct OpenuiCustomAction {
pub:
	name        string
	description string
	params      []OpenuiFuncParam
}

pub struct OpenuiGroup {
pub:
	name       string
	components []string
	notes      []string
}

pub struct OpenuiLibrary {
pub:
	root string
pub mut:
	components []OpenuiComponent
	functions  []OpenuiFunction
	actions    []OpenuiCustomAction
	groups     []OpenuiGroup
}

pub fn new_openui_library(root string, components []OpenuiComponent) OpenuiLibrary {
	return OpenuiLibrary{
		root:       root
		components: components.clone()
	}
}

pub fn (lib OpenuiLibrary) find(name string) ?OpenuiComponent {
	for component in lib.components {
		if component.name == name {
			return component
		}
	}
	return none
}

pub fn (mut lib OpenuiLibrary) register(component OpenuiComponent) {
	for index, existing in lib.components {
		if existing.name == component.name {
			lib.components[index] = component
			return
		}
	}
	lib.components << component
}

pub fn (mut lib OpenuiLibrary) remove(name string) {
	for index, existing in lib.components {
		if existing.name == name {
			lib.components.delete(index)
			return
		}
	}
}

// extend derives a new library: added components render in new slots,
// overridden names replace, removed names drop out. The base is unchanged.

pub struct OpenuiExtendConfig {
pub:
	add_components []OpenuiComponent
	override       []OpenuiComponent
	remove         []string
	add_functions  []OpenuiFunction
	add_actions    []OpenuiCustomAction
}

pub fn (lib OpenuiLibrary) extend(config OpenuiExtendConfig) OpenuiLibrary {
	mut components := lib.components.clone()
	for name in config.remove {
		for index, existing in components {
			if existing.name == name {
				components.delete(index)
				break
			}
		}
	}
	for component in config.override {
		for index, existing in components {
			if existing.name == component.name {
				components[index] = component
				break
			}
		}
	}
	for component in config.add_components {
		mut replaced := false
		for index, existing in components {
			if existing.name == component.name {
				components[index] = component
				replaced = true
				break
			}
		}
		if !replaced {
			components << component
		}
	}
	mut functions := lib.functions.clone()
	functions << config.add_functions
	mut actions := lib.actions.clone()
	actions << config.add_actions
	return OpenuiLibrary{
		root:       lib.root
		components: components
		functions:  functions
		actions:    actions
		groups:     lib.groups.clone()
	}
}
