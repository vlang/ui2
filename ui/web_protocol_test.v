module ui2

import json2

fn test_web_event_decode_and_mapping() {
	raw := '{"type":"pointer","id":"canvas","value":"down","x":12.5,"y":7}'
	event := web_event_decode(raw)!
	assert event.typ == web_event_pointer
	assert event.id == 'canvas'
	assert web_event_string(event) == 'pointer:down:canvas:12.5:7.0'
}

fn test_web_event_decode_rejects_missing_type() {
	web_event_decode('{"id":"x"}') or {
		assert err.msg().contains('type')
		return
	}
	assert false, 'expected an event without a type to be rejected'
}

fn test_web_event_string_keeps_bare_actions() {
	tap := WebEvent{ typ: web_event_tap, id: 'inc' }
	assert web_event_string(tap) == 'inc'
	change := WebEvent{ typ: web_event_change, id: 'name', value: 'Ada' }
	assert web_event_string(change) == 'name'
}

fn test_web_event_string_scroll_and_keys() {
	scroll := WebEvent{ typ: web_event_scroll, id: 'list', dx: 0, dy: -24 }
	assert web_event_string(scroll) == 'scroll:list:0.0:-24.0'

	plain := WebEvent{ typ: web_event_key, key: 'f5' }
	assert web_event_string(plain) == 'f5'
	shortcut := WebEvent{ typ: web_event_key, key: 'n', cmd: true, shift: true }
	assert web_event_string(shortcut) == 'cmd+shift+n'
}

fn test_web_event_string_resize_and_focus() {
	resize := WebEvent{ typ: web_event_resize, x: 900, y: 600 }
	assert web_event_string(resize) == 'resize:900:600'
	assert web_event_string(WebEvent{ typ: web_event_focus, id: 'name' }) == 'focus:name'
	assert web_event_string(WebEvent{ typ: web_event_blur, id: 'name' }) == 'blur:name'
}

fn test_web_snapshot_message_round_trips_with_v0_envelope() {
	root := screen(0xffffff, [label('title', 'Hi', rect(0, 0, 40, 20), TextStyle{})])
	raw := web_snapshot_message('App', 320, 240, 1.5, 9, root)
	assert raw.contains('"type":"snapshot"')
	snap := web_snapshot_decode(raw)!
	assert snap.title == 'App'
	assert snap.dpr == 1.5
	assert snap.seq == 9
	assert snap.root == root
}

fn test_web_patch_message_wire_pins_type_and_ops() {
	root := screen(0xffffff, [])
	patch := WebPatch{
		seq: 4
		ops: [PatchOp{ kind: .update, path: [], element: root }]
	}
	raw := web_patch_message(patch.seq, patch.ops)
	assert raw.contains('"type":"patch"')
	assert raw.contains('"seq":4')
	assert raw.contains('"kind":"update"')

	decoded := json2.decode[WebPatchMessage](raw)!
	assert decoded.typ == web_msg_patch
	assert decoded.ops.len == 1
	assert decoded.ops[0].kind == .update
}

fn test_web_event_unknown_type_falls_back_to_id() {
	event := WebEvent{ typ: 'custom', id: 'custom-action' }
	assert web_event_string(event) == 'custom-action'
}

// WebProtocolErrorWire pins the one server -> client envelope without a V type.
struct WebProtocolErrorWire {
	typ     string @[json: 'type']
	message string
}

fn test_web_event_action_fallback_and_override() {
	// action is the desktop EventFn identity; id remains the state lookup key.
	plain := WebEvent{ typ: web_event_tap, id: 'inc' }
	assert web_event_string(plain) == 'inc'

	override := WebEvent{ typ: web_event_tap, id: 'inc', action: 'save', value: 'inc' }
	assert web_event_string(override) == 'save'
	assert web_event_string(WebEvent{ typ: web_event_change, id: 'name', action: 'commit' }) == 'commit'
	assert web_event_string(WebEvent{
		typ:    web_event_pointer
		id:     'canvas'
		action: 'paint'
		value:  web_pointer_down
		x:      1
		y:      2
	}) == 'pointer:down:paint:1.0:2.0'
	assert web_event_string(WebEvent{
		typ:    web_event_scroll
		id:     'list'
		action: 'page'
		dy:     -5
	}) == 'scroll:page:0.0:-5.0'

	// focus/blur stay keyed on id even when an action is supplied.
	assert web_event_string(WebEvent{ typ: web_event_focus, id: 'name', action: 'other' }) == 'focus:name'
}

fn test_web_event_decode_action_and_unknown_type_fallback() {
	raw := '{"type":"custom","id":"state-key","action":"event-key"}'
	event := web_event_decode(raw)!
	assert event.id == 'state-key'
	assert event.action == 'event-key'
	// Unknown types keep the bare-id fallback; `action` only applies to the
	// element event types listed in web_event_string().
	assert web_event_string(event) == 'state-key'
}

fn test_web_key_modifier_order_is_deterministic() {
	// Modifiers are always cmd+ctrl+alt+shift regardless of wire order.
	a := WebEvent{ typ: web_event_key, key: 's', shift: true, alt: true, ctrl: true, cmd: true }
	b := WebEvent{ typ: web_event_key, key: 's', cmd: true, ctrl: true, alt: true, shift: true }
	assert web_event_string(a) == 'cmd+ctrl+alt+shift+s'
	assert web_event_string(b) == 'cmd+ctrl+alt+shift+s'
	assert web_event_string(WebEvent{ typ: web_event_key, key: 'k', shift: true, ctrl: true }) == 'ctrl+shift+k'
}

fn test_web_patch_message_decodes_update_and_replace_children() {
	ops := [
		PatchOp{
			kind:    .update
			path:    [0, 1]
			element: label('x', 'X', rect(0, 0, 10, 10), TextStyle{})
		},
		PatchOp{
			kind:     .replace_children
			path:     []
			children: [label('y', 'Y', rect(0, 0, 10, 10), TextStyle{})]
		},
	]
	raw := web_patch_message(7, ops)
	msg := json2.decode[WebPatchMessage](raw)!
	assert msg.typ == web_msg_patch
	assert msg.seq == 7
	assert msg.ops.len == 2
	assert msg.ops[0].kind == .update
	assert msg.ops[0].path == [0, 1]
	assert msg.ops[0].element.text == 'X'
	assert msg.ops[1].kind == .replace_children
	assert msg.ops[1].path.len == 0
	assert msg.ops[1].children.len == 1
	assert msg.ops[1].children[0].id == 'y'
}

fn test_web_error_message_wire_shape() {
	assert web_msg_error == 'error'
	wire := json2.decode[WebProtocolErrorWire]('{"type":"error","message":"boom"}')!
	assert wire.typ == web_msg_error
	assert wire.message == 'boom'
}
