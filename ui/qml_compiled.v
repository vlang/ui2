module ui2

const compiled_qml_event_prefix = '__ui2_compiled_qml:'
const compiled_qml_app_path_argument = 'app-path'

// compiled_qml_event packages a no-argument compile-time QML action and optional binding into an
// Element action id. It is emitted by `$qml()`; applications normally only need
// handle_compiled_qml_event or run_compiled_qml.
pub fn compiled_qml_event(control string, binding_property string, binding_target string, action_name string) string {
	parts := [control, binding_property, binding_target, action_name]
	return compiled_qml_event_prefix + parts.map(it.bytes().hex()).join(':')
}

// compiled_qml_event_arg is the one-argument form emitted for a typed QML action.
pub fn compiled_qml_event_arg(control string, binding_property string, binding_target string, action_name string, argument string) string {
	parts := [control, binding_property, binding_target, action_name, argument]
	return compiled_qml_event_prefix + parts.map(it.bytes().hex()).join(':')
}

// compiled_qml_event_arg_path is emitted when an action argument reads the app model. The path is
// resolved after a two-way binding is applied, matching runtime QML event ordering.
pub fn compiled_qml_event_arg_path(control string, binding_property string, binding_target string, action_name string, path string) string {
	parts := [control, binding_property, binding_target, action_name, compiled_qml_app_path_argument,
		path]
	return compiled_qml_event_prefix + parts.map(it.bytes().hex()).join(':')
}

fn qml_hex_nibble(value u8) ?u8 {
	return match value {
		`0`...`9` { value - `0` }
		`a`...`f` { value - `a` + 10 }
		`A`...`F` { value - `A` + 10 }
		else { none }
	}
}

fn qml_decode_hex(value string) !string {
	if value.len % 2 != 0 {
		return error('invalid compiled QML event')
	}
	mut decoded := []u8{cap: value.len / 2}
	for i := 0; i < value.len; i += 2 {
		high := qml_hex_nibble(value[i]) or { return error('invalid compiled QML event') }
		low := qml_hex_nibble(value[i + 1]) or { return error('invalid compiled QML event') }
		decoded << (high << 4) | low
	}
	return decoded.bytestr()
}

fn qml_dispatch_compiled[T](mut model T, name string, arguments []string) ! {
	$for method in T.methods {
		if method.name == name {
			$if method.is_pub && method.typ is fn ( ) {
				if arguments.len != 0 {
					return error('app action `${name}` expects no arguments')
				}
				model.$method()
				return
			} $else $if method.is_pub && method.typ is fn ( int ) {
				if arguments.len != 1 {
					return error('app action `${name}` expects one int argument')
				}
				model.$method(arguments[0].int())
				return
			} $else $if method.is_pub && method.typ is fn ( string ) {
				if arguments.len != 1 {
					return error('app action `${name}` expects one string argument')
				}
				model.$method(arguments[0])
				return
			} $else {
				return error('app action `${name}` has an unsupported signature')
			}
		}
	}
	return error('unknown app action `${name}`')
}

// handle_compiled_qml_event applies an event emitted by an Element tree built with `$qml()`.
// It returns false for an ordinary non-QML action id so callers can route that event elsewhere.
pub fn handle_compiled_qml_event[T](mut model T, event_id string) !bool {
	if !event_id.starts_with(compiled_qml_event_prefix) {
		return false
	}
	encoded := event_id[compiled_qml_event_prefix.len..].split(':')
	if encoded.len < 4 {
		return error('invalid compiled QML event')
	}
	mut parts := []string{cap: encoded.len}
	for part in encoded {
		parts << qml_decode_hex(part)!
	}
	control := parts[0]
	binding_property := parts[1]
	binding_target := parts[2]
	action_name := parts[3]
	if binding_property.len > 0 {
		field_name := binding_target.all_after('app.')
		value := if binding_property in ['checked', 'active'] {
			current := q_lookup({
				'app': q_value_from(model)
			}, binding_target, 0)!
			q_bool(!current.truthy())
		} else if binding_property == 'text' {
			q_string(text(control))
		} else if binding_property == 'value' {
			live := slider_value(control)
			q_number(live, slider_number(live))
		} else if binding_property == 'pressed' {
			q_bool(toggle_button_pressed(control))
		} else {
			return error('unsupported compiled QML binding `${binding_property}`')
		}
		qml_set_field[T](mut model, field_name, value)!
	}
	mut arguments := parts[4..]
	if arguments.len == 2 && arguments[0] == compiled_qml_app_path_argument {
		argument := q_lookup({
			'app': q_value_from(model)
		}, arguments[1], 0)!
		arguments = [argument.string_value()]
	}
	if action_name.len > 0 {
		qml_dispatch_compiled[T](mut model, action_name, arguments)!
	}
	return true
}

// CompiledQmlRunConfig configures a window backed by a typed model and a `$qml()` build function.
pub struct CompiledQmlRunConfig[T] {
pub:
	model  T
	build  fn (&T) Element = unsafe { nil }
	title  string = 'App'
	width  int = 400
	height int = 800
}

@[heap]
struct CompiledQmlController[T] {
	build fn (&T) Element = unsafe { nil }
mut:
	model T
}

@[heap]
struct CompiledQmlRuntime {
mut:
	controller voidptr
}

const compiled_qml_runtime_singleton = &CompiledQmlRuntime{}

fn compiled_qml_runtime() &CompiledQmlRuntime {
	return unsafe { compiled_qml_runtime_singleton }
}

fn compiled_qml_controller_build[T]() Element {
	runtime := compiled_qml_runtime()
	controller := unsafe { &CompiledQmlController[T](runtime.controller) }
	return controller.build(&controller.model)
}

fn compiled_qml_controller_handle[T](event_id string) {
	runtime := compiled_qml_runtime()
	mut controller := unsafe { &CompiledQmlController[T](runtime.controller) }
	handled := handle_compiled_qml_event[T](mut controller.model, event_id) or {
		eprintln('ui2 compiled QML event failed: ${err}')
		return
	}
	if handled {
		refresh()
	}
}

// run_compiled_qml owns a typed model and displays a `$qml()`-generated Element tree. QML is
// parsed and lowered by the v3 compiler, so building or refreshing the window does no QML work.
pub fn run_compiled_qml[T](config CompiledQmlRunConfig[T]) ! {
	if config.build == unsafe { nil } {
		return error('compiled QML requires a build function')
	}
	mut controller := &CompiledQmlController[T]{
		build: config.build
		model: config.model
	}
	validate_element_tree(controller.build(&controller.model))!
	mut runtime := compiled_qml_runtime()
	runtime.controller = voidptr(controller)
	$if macos || windows || linux {
		run_window(config.title, config.width, config.height, compiled_qml_controller_build[T], compiled_qml_controller_handle[T])
	} $else {
		run(compiled_qml_controller_build[T], compiled_qml_controller_handle[T])
	}
}
