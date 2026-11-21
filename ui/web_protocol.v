module ui2

import json2

// Web protocol v0. The browser and the V server exchange three JSON envelopes:
//   * WebSnapshotMessage  full frame (HTTP GET /snapshot and WS "snapshot")
//   * WebPatchMessage     keyed reconciliation ops (WS "patch")
//   * WebEvent            browser input, mapped back onto the exact strings an
//                         EventFn receives on the desktop backends.
//
// These types stay unguarded (no veb/net dependency) so the wire and the event
// mapping can be unit-tested without a headless build.

pub const web_msg_snapshot = 'snapshot'
pub const web_msg_patch = 'patch'
pub const web_msg_error = 'error'

pub const web_event_tap = 'tap'
pub const web_event_change = 'change'
pub const web_event_pointer = 'pointer'
pub const web_event_scroll = 'scroll'
pub const web_event_key = 'key'
pub const web_event_resize = 'resize'
pub const web_event_focus = 'focus'
pub const web_event_blur = 'blur'

pub const web_pointer_down = 'down'
pub const web_pointer_up = 'up'
pub const web_pointer_move = 'move'
pub const web_pointer_enter = 'enter'
pub const web_pointer_leave = 'leave'
pub const web_pointer_drag = 'drag'

// WebSnapshotMessage is a full frame on the wire. It is the v0 envelope from
// web_snapshot.v plus a discriminator the renderer dispatches on.
pub struct WebSnapshotMessage {
	typ    string @[json: 'type']
	title  string
	width  int
	height int
	dpr    f64
	seq    u64
	root   Element
}

pub fn web_snapshot_message(title string, width int, height int, dpr f64, seq u64, root Element) string {
	return json2.encode(WebSnapshotMessage{
		typ:    web_msg_snapshot
		title:  title
		width:  width
		height: height
		dpr:    dpr
		seq:    seq
		root:   root
	})
}

// PatchOpKind selects how the browser applies one reconciliation op.
// update changes an element's scalar fields in place; replace_children swaps
// the whole child list of the node at `path` (used when keys/ids/order change).
pub enum PatchOpKind {
	update
	replace_children
}

// PatchOp is one keyed reconciliation operation. `path` is a list of child
// indices from the root; an empty path addresses the root element itself.
pub struct PatchOp {
	kind     PatchOpKind
	path     []int
	element  Element
	children []Element
}

pub struct WebPatch {
	seq u64
	ops []PatchOp
}

pub struct WebPatchMessage {
	typ string @[json: 'type']
	seq u64
	ops []PatchOp
}

pub fn web_patch_message(seq u64, ops []PatchOp) string {
	return json2.encode(WebPatchMessage{
		typ: web_msg_patch
		seq: seq
		ops: ops
	})
}

// WebEvent is one browser input. The renderer sends only the fields that matter
// for an event type; zeros and empty strings are harmless defaults.
pub struct WebEvent {
	typ string @[json: 'type']
	id  string
	// action is the desktop EventFn identity. The renderer sends action_id
	// (falling back to id) so wire strings match element_action_id(); state
	// lookup still uses id. Empty means "use id".
	action string @[json: 'action']
	value  string
	x      f64
	y      f64
	dx     f64
	dy     f64
	key    string
	code   int
	shift  bool
	ctrl   bool
	alt    bool
	cmd    bool
	token  string
}

pub fn web_event_decode(data string) !WebEvent {
	event := json2.decode[WebEvent](data)!
	if event.typ.len == 0 {
		return error('web event is missing `type`')
	}
	return event
}

// web_event_string maps a browser event to the string an EventFn receives on
// the native backends. Simple actions keep their bare id, so an app's on_event
// does not have to change between desktop and web. Pointer events reuse the
// `pointer:<phase>:<action>:<x>:<y>` format from ui_immediate.c.v; key events
// reuse the normalized shortcut strings accepted by KeyFn.
pub fn web_event_string(event WebEvent) string {
	return match event.typ {
		web_event_tap, web_event_change {
			web_event_action(event)
		}
		web_event_pointer {
			phase := if event.value.len > 0 { event.value } else { web_pointer_down }
			'pointer:${phase}:${web_event_action(event)}:${event.x}:${event.y}'
		}
		web_event_scroll {
			'scroll:${web_event_action(event)}:${event.dx}:${event.dy}'
		}
		web_event_key {
			web_key_string(event)
		}
		web_event_focus {
			'focus:${event.id}'
		}
		web_event_blur {
			'blur:${event.id}'
		}
		web_event_resize {
			'resize:${int(event.x)}:${int(event.y)}'
		}
		else {
			event.id
		}
	}
}

// web_event_action returns the desktop EventFn identity for an event: the
// explicit action_id when the renderer supplied one, otherwise the element id.
// This mirrors element_action_id() in ui.v so web strings match the desktop.
fn web_event_action(event WebEvent) string {
	return if event.action.len > 0 { event.action } else { event.id }
}

// web_key_string normalizes a browser key into the shortcut strings ui2 apps
// already handle. Bare printable keys keep their lowercase name; named keys
// are passed through; modifiers are prefixed in a stable cmd+ctrl+alt+shift
// order so the string is deterministic across browsers.
fn web_key_string(event WebEvent) string {
	mut key := event.key
	if key.len == 0 {
		return ''
	}
	// Each pass prepends, so iterate in reverse of the desired final order.
	if event.shift {
		key = 'shift+' + key
	}
	if event.alt {
		key = 'alt+' + key
	}
	if event.ctrl {
		key = 'ctrl+' + key
	}
	if event.cmd {
		key = 'cmd+' + key
	}
	return key
}
