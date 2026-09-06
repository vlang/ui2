// Hosting a QML application inside something that is not a platform window.
//
// `run_qml` is shaped for the usual case: one document, one window, and a call
// that blocks until that window closes. A window manager can use none of that.
// It has several applications open at once, it owns the event loop itself, and
// it — not the platform — decides how large each application's content area
// is. `QmlApp` is the same machinery with those three assumptions removed, so
// an embedder can hold as many as it likes and drive them from its own loop.
module ui2

// QmlApp holds a parsed QML document together with its model and turns the two
// into an element tree on demand. It draws nothing and waits for nothing: the
// embedder asks for a tree, renders it however it likes, and reports back the
// action id of whatever the user hit.
@[heap]
pub struct QmlApp[T] {
	template &QNode
mut:
	model  T
	events map[string]QmlEvent
pub mut:
	// control_text answers with the live text of a named control, which a
	// two-way `bind.text` needs in order to write an edit back to the model.
	// An embedder that hosts no text input can leave it unset; the binding
	// then writes an empty string, which is what a backend carrying no such
	// control has to say anyway.
	control_text fn (id string) string = unsafe { nil }
}

// new_qml_app parses and type-checks the document against the model up front,
// so a mistake in either is reported when the application is created rather
// than on the first frame the embedder tries to draw.
pub fn new_qml_app[T](source string, model T) !&QmlApp[T] {
	template := parse_qml(source)!
	q_validate_template[T](template, model)!
	// Evaluate once against a nominal frame. A document that cannot be
	// evaluated at all should fail here; one that merely lays out oddly at
	// this size is no concern, because nothing is drawn from it.
	probe := rect(0, 0, 1, 1)
	resolved, _ := q_evaluate_template(template, model, probe)!
	validate_element_tree(element_from_qnode(resolved, probe)!)!
	return &QmlApp[T]{
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
pub fn (mut app QmlApp[T]) build(size Rect) !Element {
	frame := rect(0, 0, size.width, size.height)
	resolved, events := q_evaluate_template(app.template, app.model, frame)!
	app.events = events.clone()
	return element_from_qnode(resolved, frame)!
}

// handle applies whatever action or binding an element's id names. The ids come
// from the tree `build` returned, so an embedder can pass through whatever its
// own hit testing produced without having to know what any of it means. An id
// that names nothing is ignored, which is what lets an embedder route every
// click it did not recognise here.
pub fn (mut app QmlApp[T]) handle(event_id string) ! {
	event := app.events[event_id] or { return }
	if binding := event.binding {
		field_name := binding.target.all_after('app.')
		value := if binding.property == 'checked' {
			current := q_lookup({
				'app': q_value_from(app.model)
			}, binding.target, 0)!
			q_bool(!current.truthy())
		} else {
			q_string(app.text_of(binding.control))
		}
		qml_set_field[T](mut app.model, field_name, value)!
	}
	if invocation := event.invocation {
		qml_dispatch[T](mut app.model, invocation)!
	}
}

fn (app &QmlApp[T]) text_of(id string) string {
	handler := app.control_text
	if handler == unsafe { nil } {
		return ''
	}
	return handler(id)
}

// state is the application's model as it now stands, for an embedder that
// wants to show something about it outside the window — in a title bar, say.
pub fn (app &QmlApp[T]) state() T {
	return app.model
}
