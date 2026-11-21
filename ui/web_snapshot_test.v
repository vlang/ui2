module ui2

import json2

// web_snapshot_all_kinds builds one tree exercising every web-mapped Kind:
// screen, view (plain, shaped, button-behavior), label, image, button,
// checkbox, dropdown, text_field, text_area, scroll, slider, switch_control,
// toggle_button and opengl. All ids are unique so the tree validates.
fn web_snapshot_all_kinds() Element {
	styled_text := TextStyle{
		color: 0x111827
		size:  14.0
		bold:  true
		align: .center
	}
	card_box := BoxStyle{
		bg:           0xffffff
		radius:       12
		border_color: 0x28314a
		border_left:  1
		border_top:   1
		border_right: 1
		opacity:      0.95
		gradient:     linear_gradient(90, gradient_stop(0x2563eb, 0), gradient_stop(0x9333ea, 1))
		shadow:       box_shadow(0x000000, 0.18, 24, 8)
	}
	return screen(0xf4f6f8, [
		view('card', rect(16, 16, 480, 300), card_box, [
			label('title', 'Volume', rect(24, 24, 200, 24), styled_text),
			image('logo', 'assets/logo.png', rect(24, 56, 64, 64)),
			button('inc', 'Add', rect(24, 128, 120, 40), BoxStyle{
				bg:     0x2563eb
				radius: 8
			}, styled_text),
			checkbox('terms', 'Accept terms', true, rect(24, 176, 200, 24), styled_text),
			dropdown('city', 'Berlin', ['Berlin', 'Paris'], rect(240, 24, 200, 32), BoxStyle{
				bg: 0xffffff
			}, styled_text),
			text_field('name', 'Name', 'Ada', rect(240, 64, 200, 32), BoxStyle{
				bg: 0xffffff
			}, styled_text, keyboard_default),
			rich_text_area('bio', 'Hello', [TextRun{
				text:  'Hello'
				style: styled_text
			}], rect(240, 104, 200, 64), BoxStyle{
				bg: 0xffffff
			}, styled_text),
		]),
		scroll('list', rect(16, 328, 480, 120), 0xffffff, [
			label('row1', 'First row', rect(8, 8, 200, 24), styled_text),
			label('row2', 'Second row', rect(8, 40, 200, 24), styled_text),
		]),
		slider(SliderConfig{
			id:    'volume'
			frame: rect(16, 460, 200, 32)
			min:   0
			max:   100
			value: 75
			style: SliderStyle{}
		}),
		switch_control(SwitchConfig{
			id:     'wifi'
			frame:  rect(232, 460, 64, 32)
			active: true
		}),
		toggle_button(ToggleButtonConfig{
			id:      'bold'
			title:   'B'
			frame:   rect(312, 460, 48, 32)
			pressed: true
			box:     BoxStyle{
				bg: 0xffffff
			}
		}),
		shape('spark', rect(376, 460, 120, 32), [
			path_move_to(0, 28),
			path_line_to(120, 4),
		], ShapeStyle{
			stroke:       0x2563eb
			stroke_width: 2
		}),
		opengl('video', rect(512, 16, 160, 120)),
		with_tooltip(view('tip', rect(512, 144, 160, 32), BoxStyle{
			bg: 0xffffff
		}, []), 'preview help'),
		button_view('save_card', rect(512, 184, 160, 48), BoxStyle{
			bg:     0x2563eb
			radius: 8
		}, [
			label('save_caption', 'Save', rect(12, 12, 136, 24), TextStyle{
				color: 0xffffff
				bold:  true
			}),
		]),
	])
}

fn test_web_snapshot_round_trip_covers_every_kind() {
	root := web_snapshot_all_kinds()
	data := web_snapshot('Counter', 800, 600, 2.0, 7, root)!
	snap := web_snapshot_decode(data)!
	assert snap.title == 'Counter'
	assert snap.width == 800
	assert snap.height == 600
	assert snap.dpr == 2.0
	assert snap.seq == 7
	assert snap.root == root
	assert snap.root.children.len == 9
	assert snap.root.children[1].kind == .scroll
	assert snap.root.children[1].children.len == 2
	assert snap.root.children[2].kind == .slider
	assert snap.root.children[2].value == 75
	assert snap.root.children[3].kind == .switch_control
	assert snap.root.children[3].checked
	assert snap.root.children[4].kind == .toggle_button
	assert snap.root.children[4].text == 'B'
	assert snap.root.children[5].kind == .view
	assert snap.root.children[5].path.len == 2
	assert snap.root.children[6].kind == .opengl
	assert snap.root.children[8].button_behavior
	card := snap.root.children[0]
	assert card.children.len == 7
	assert card.children[0].kind == .label
	assert card.children[1].kind == .image
	assert card.children[2].kind == .button
	assert card.children[3].kind == .checkbox
	assert card.children[4].kind == .dropdown
	assert card.children[4].menu.len == 2
	assert card.children[5].kind == .text_field
	assert card.children[6].kind == .text_area
	assert card.children[6].text_runs.len == 1
	assert card.box.gradient.stops.len == 2
	assert card.box.shadow.blur == 24
}

fn test_web_snapshot_wire_pins_envelope_and_identity() {
	data := web_snapshot('Counter', 800, 600, 1.0, 1, screen(0xffffff, [
		button('inc', 'Add', rect(0, 0, 120, 40), BoxStyle{}, TextStyle{}),
	]))!
	assert data.contains('"title":"Counter"')
	assert data.contains('"id":"inc"')
	assert data.contains('"text":"Add"')
}

fn test_web_snapshot_rejects_duplicate_ids() {
	root := screen(0xffffff, [
		label('dup', 'one', rect(0, 0, 40, 20), TextStyle{}),
		label('dup', 'two', rect(0, 24, 40, 20), TextStyle{}),
	])
	web_snapshot('Bad', 100, 100, 1.0, 0, root) or {
		assert err.msg().contains('duplicate element id')
		return
	}
	assert false, 'expected duplicate element id to fail validation'
}

fn test_web_snapshot_decode_rejects_bad_payload() {
	web_snapshot_decode('not json') or {
		return
	}
	assert false, 'expected malformed JSON to fail decoding'
}

fn test_web_snapshot_decode_rejects_ambiguous_tree() {
	good := web_snapshot('Counter', 100, 100, 1.0, 0, screen(0xffffff, [
		label('ok', 'one', rect(0, 0, 40, 20), TextStyle{}),
	]))!
	snap := json2.decode[WebSnapshot](good)!
	mut children := snap.root.children.clone()
	children << label('ok', 'two', rect(0, 24, 40, 20), TextStyle{})
	bad := WebSnapshot{
		...snap
		root: Element{
			...snap.root
			children: children
		}
	}
	web_snapshot_decode(json2.encode(bad)) or {
		assert err.msg().contains('duplicate element id')
		return
	}
	assert false, 'expected ambiguous decoded tree to fail validation'
}

fn test_web_snapshot_message_with_type_field_decodes() {
	// The v0 envelope adds a `type` discriminator; web_snapshot_decode must
	// ignore it and still validate/return the inner WebSnapshot tree.
	root := screen(0xffffff, [label('ok', 'Hi', rect(0, 0, 40, 20), TextStyle{})])
	raw := web_snapshot_message('App', 640, 480, 1.25, 12, root)
	assert raw.contains('"type":"snapshot"')
	snap := web_snapshot_decode(raw)!
	assert snap.title == 'App'
	assert snap.width == 640
	assert snap.height == 480
	assert snap.dpr == 1.25
	assert snap.seq == 12
	assert snap.root == root
}
