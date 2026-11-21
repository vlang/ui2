module ui2

// on_pointer_event is the optional hook a VML model can declare to observe raw
// pointer events. Backends report touch input as the same `down`, `drag` and
// `up` phases used for a mouse, so this is how a typed model handles dragging
// and swiping in a VML document.
//
// The method must be public and take either one PointerEvent (phase, action and
// coordinates already decoded) or one string (the raw event id). A model that
// declares no such method keeps ignoring raw pointer events, as it always has.
const vml_pointer_hook_name = 'on_pointer_event'

@[markused]
fn vml_validate_pointer_hook[T]() ! {
	$for method in T.methods {
		if method.name == vml_pointer_hook_name {
			$if !method.is_pub {
				return error('VML pointer hook `${vml_pointer_hook_name}` must be public')
			} $else $if method.typ is fn(PointerEvent) {
				return
			} $else $if method.typ is fn(string) {
				return
			} $else {
				return error('VML pointer hook `${vml_pointer_hook_name}` must take one PointerEvent or one string argument')
			}
		}
	}
}

@[markused]
fn vml_call_pointer_hook[T](mut model T, raw string, pointer PointerEvent) {
	$for method in T.methods {
		if method.name == vml_pointer_hook_name {
			$if method.is_pub && method.typ is fn(PointerEvent) {
				model.$method(pointer)
				return
			} $else $if method.is_pub && method.typ is fn(string) {
				model.$method(raw)
				return
			}
		}
	}
}
