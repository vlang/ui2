// Hosting a VML application inside something that is not a platform window.
//
// `run_vml` is shaped for the usual case: one document, one window, and a call
// that blocks until that window closes. A window manager can use none of that.
// It has several applications open at once, it owns the event loop itself, and
// it — not the platform — decides how large each application's content area
// is. `VmlApp` is the same machinery with those three assumptions removed, so
// an embedder can hold as many as it likes and drive them from its own loop.
module ui2

// VmlApp holds a parsed VML document together with its model and turns the two
// into an element tree on demand. It draws nothing and waits for nothing: the
// embedder asks for a tree, renders it however it likes, and reports back the
// action id of whatever the user hit.
@[heap]
pub struct VmlApp[T] {
	template &VNode
mut:
	model  T
	events map[string]VmlEvent
pub mut:
	// control_text answers with the live text of a named control, which a
	// two-way `bind.text` needs in order to write an edit back to the model.
	// An embedder that hosts no text input can leave it unset; the binding
	// then writes an empty string, which is what a backend carrying no such
	// control has to say anyway.
	control_text fn (id string) string = unsafe { nil }
	// control_value answers with the live value of a named numeric control.
	// It is the embedding counterpart to the platform slider_value function
	// used by two-way `bind.value` in a normal window.
	control_value fn (id string) f64 = unsafe { nil }
}

// new_vml_app parses and type-checks the document against the model up front,
// so a mistake in either is reported when the application is created rather
// than on the first frame the embedder tries to draw.
pub fn new_vml_app[T](source string, model T) !&VmlApp[T] {
	template := parse_vml(source)!
	return new_vml_app_from_template[T](template, model)
}

// new_vml_app_file creates an embeddable VML application from a file. Unlike
// new_vml_app, it can resolve imports declared by that document.
pub fn new_vml_app_file[T](path string, model T) !&VmlApp[T] {
	template := parse_vml_file(path)!
	return new_vml_app_from_template[T](template, model)
}

fn new_vml_app_from_template[T](template &VNode, model T) !&VmlApp[T] {
	v_validate_template[T](template, model)!
	// Evaluate once against a representative nominal frame. Responsive layouts
	// commonly subtract margins from the root size, so a 1x1 probe can turn
	// otherwise valid child dimensions negative before anything is drawn.
	probe := rect(0, 0, 1024, 768)
	resolved, _ := v_evaluate_template(template, model, probe)!
	validate_element_tree(element_from_vnode(resolved, probe)!)!
	return &VmlApp[T]{
		template: template
		model: model
	}
}

// build evaluates the document against the current model for a content area of
// `size`. That size is what the document sees as `root.width` and
// `root.height`, so one application lays itself out to fit whatever window the
// embedder has given it.
//
// The returned tree's root is the document's `Screen`, whose own frame is
// empty: an embedder places the children itself and takes the background from
// `box.bg`, since a screen inside someone else's window is a content area, not
// a display.
pub fn (mut app VmlApp[T]) build(size Rect) !Element {
	frame := rect(0, 0, size.width, size.height)
	resolved, events := v_evaluate_template(app.template, app.model, frame)!
	app.events = events.clone()
	return element_from_vnode(resolved, frame)!
}

// handle applies whatever action or binding an element's id names. The ids come
// from the tree `build` returned, so an embedder can pass through whatever its
// own hit testing produced without having to know what any of it means. An id
// that names nothing is ignored, which is what lets an embedder route every
// click it did not recognise here.
pub fn (mut app VmlApp[T]) handle(event_id string) ! {
	event := app.events[event_id] or { return }
	if binding := event.binding {
		field_name := binding.target.all_after('app.')
		value := match binding.property {
			'checked', 'active' {
				current := v_lookup({
					'app': v_value_from(app.model)
				}, binding.target, 0)!
				v_bool(!current.truthy())
			}
			'pressed' {
				current := v_lookup({
					'app': v_value_from(app.model)
				}, binding.target, 0)!
				if binding.group.len > 0 && current.truthy() && !binding.allow_no_selection {
					v_bool(true)
				} else {
					v_bool(!current.truthy())
				}
			}
			'value' {
				live := app.value_of(binding.control)
				v_number(live, slider_number(live))
			}
			else {
				v_string(app.text_of(binding.control))
			}
		}
		vml_set_field[T](mut app.model, field_name, value)!
		if binding.property == 'pressed' && value.truthy() {
			for peer in event.group_bindings {
				if peer.control == binding.control || peer.target == binding.target {
					continue
				}
				target := peer.target.all_after('app.')
				type_name := vml_writable_field_type[T](target)!
				if type_name != 'bool' {
					return error('bind.pressed requires a bool field, got `${target}` (${type_name})')
				}
				vml_set_field[T](mut app.model, target, v_bool(false))!
			}
		}
	}
	if invocation := event.invocation {
		vml_dispatch[T](mut app.model, invocation)!
	}
}

fn (app &VmlApp[T]) text_of(id string) string {
	handler := app.control_text
	if handler == unsafe { nil } {
		return ''
	}
	return handler(id)
}

fn (app &VmlApp[T]) value_of(id string) f64 {
	handler := app.control_value
	if handler == unsafe { nil } {
		return 0
	}
	return handler(id)
}

// state is the application's model as it now stands, for an embedder that
// wants to show something about it outside the window — in a title bar, say.
pub fn (app &VmlApp[T]) state() T {
	return app.model
}
