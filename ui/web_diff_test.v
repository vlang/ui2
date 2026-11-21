module ui2

fn web_diff_root(children []Element) Element {
	return screen(0xffffff, children)
}

fn web_diff_label(id string, text string) Element {
	return label(id, text, rect(0, 0, 40, 20), TextStyle{})
}

fn test_web_diff_no_change_emits_no_ops() {
	root := web_diff_root([web_diff_label('a', 'A'), web_diff_label('b', 'B')])
	assert web_diff_trees(root, root).len == 0
}

fn test_web_diff_root_scalar_change_is_one_update() {
	old := web_diff_root([])
	new := Element{ ...old, box: BoxStyle{ ...old.box, bg: 0x000000 } }
	ops := web_diff_trees(old, new)
	assert ops.len == 1
	assert ops[0].kind == .update
	assert ops[0].path.len == 0
	assert ops[0].element.box.bg == 0x000000
}

fn test_web_diff_child_scalar_change_uses_child_path() {
	old := web_diff_root([web_diff_label('a', 'A'), web_diff_label('b', 'B')])
	mut children := old.children.clone()
	children[1] = Element{ ...children[1], text: 'C' }
	new := Element{ ...old, children: children }
	ops := web_diff_trees(old, new)
	assert ops.len == 1
	assert ops[0].kind == .update
	assert ops[0].path == [1]
	assert ops[0].element.text == 'C'
}

fn test_web_diff_keyed_children_update_in_place() {
	mut first := web_diff_label('a', 'A')
	first = Element{ ...first, key: 'a' }
	mut second := web_diff_label('b', 'B')
	second = Element{ ...second, key: 'b' }
	old := web_diff_root([first, second])

	new_first := Element{ ...first, text: 'A!' }
	new_second := Element{ ...second, text: 'B!' }
	new := web_diff_root([new_first, new_second])

	ops := web_diff_trees(old, new)
	assert ops.len == 2
	assert ops[0].kind == .update
	assert ops[0].path == [0]
	assert ops[1].path == [1]
	assert web_apply_patch(old, WebPatch{ seq: 1, ops: ops })! == new
}

fn test_web_diff_insert_or_remove_replaces_children() {
	old := web_diff_root([web_diff_label('a', 'A')])
	new := web_diff_root([web_diff_label('a', 'A'), web_diff_label('b', 'B')])
	insert_ops := web_diff_trees(old, new)
	assert insert_ops.len == 1
	assert insert_ops[0].kind == .replace_children
	assert insert_ops[0].path.len == 0
	assert insert_ops[0].children.len == 2
	assert web_apply_patch(old, WebPatch{ seq: 1, ops: insert_ops })! == new

	remove_ops := web_diff_trees(new, old)
	assert remove_ops.len == 1
	assert remove_ops[0].kind == .replace_children
	assert web_apply_patch(new, WebPatch{ seq: 2, ops: remove_ops })! == old
}

fn test_web_diff_key_change_replaces_children() {
	old := web_diff_root([web_diff_label('a', 'A')])
	renamed := Element{ ...old.children[0], key: 'renamed' }
	new := web_diff_root([renamed])
	ops := web_diff_trees(old, new)
	assert ops.len == 1
	assert ops[0].kind == .replace_children
}

fn test_web_diff_nested_path_and_reordered_children() {
	inner_old := view('box', rect(0, 0, 100, 100), BoxStyle{}, [web_diff_label('x', 'X')])
	inner_new := view('box', rect(0, 0, 100, 100), BoxStyle{}, [
		web_diff_label('y', 'Y'),
		web_diff_label('x', 'X'),
	])
	old := web_diff_root([inner_old])
	new := web_diff_root([inner_new])
	ops := web_diff_trees(old, new)
	assert ops.len == 1
	assert ops[0].kind == .replace_children
	assert ops[0].path == [0]
	assert web_apply_patch(old, WebPatch{ seq: 3, ops: ops })! == new
}

fn test_web_diff_apply_patch_update_keeps_children() {
	old := web_diff_root([web_diff_label('a', 'A')])
	changed := Element{ ...old.children[0], text: 'Changed' }
	new := web_diff_root([changed])
	ops := web_diff_trees(old, new)
	result := web_apply_patch(old, WebPatch{ seq: 5, ops: ops })!
	assert result == new
	assert result.children[0].children.len == 0
}

fn test_web_apply_patch_out_of_range_path_errors() {
	root := web_diff_root([web_diff_label('a', 'A')])
	too_far := WebPatch{ seq: 1, ops: [PatchOp{ kind: .update, path: [5], element: root }] }
	web_apply_patch(root, too_far) or {
		assert err.msg().contains('out of range')
		return
	}
	assert false, 'expected an out-of-range patch path to fail'

	negative := WebPatch{ seq: 1, ops: [PatchOp{ kind: .replace_children, path: [-1], children: [] }] }
	web_apply_patch(root, negative) or {
		assert err.msg().contains('out of range')
		return
	}
	assert false, 'expected a negative patch path to fail'
}

fn test_web_apply_patch_nested_update_preserves_siblings() {
	sibling := web_diff_label('s', 'S')
	inner_old := view('box', rect(0, 0, 100, 100), BoxStyle{}, [
		web_diff_label('a', 'A'),
		sibling,
	])
	old := web_diff_root([inner_old])

	inner_new := Element{
		...inner_old
		children: [
			Element{ ...inner_old.children[0], text: 'A2' },
			sibling,
		]
	}
	new := Element{ ...old, children: [inner_new] }
	ops := web_diff_trees(old, new)
	assert ops.len == 1
	assert ops[0].path == [0, 0]
	result := web_apply_patch(old, WebPatch{ seq: 1, ops: ops })!
	assert result == new
	assert result.children[0].children[1].text == 'S'
}

fn test_web_apply_patch_replace_children_of_leaf() {
	old := web_diff_root([web_diff_label('a', 'A')])
	new_child := web_diff_label('b', 'B')
	ops := [PatchOp{ kind: .replace_children, path: [0], children: [new_child] }]
	result := web_apply_patch(old, WebPatch{ seq: 1, ops: ops })!
	assert result.children[0].children.len == 1
	assert result.children[0].children[0] == new_child
	// The leaf's own scalar fields survive the structural swap.
	assert result.children[0].id == 'a'
}

fn test_web_diff_f64_fields_compare_correctly() {
	old := web_diff_root([])
	subtle := Element{ ...old, box: BoxStyle{ ...old.box, radius: 0.5 } }
	assert web_diff_trees(old, subtle).len == 1
	assert web_diff_trees(old, subtle)[0].element.box.radius == 0.5

	slider_old := slider(SliderConfig{
		id:    's'
		frame: rect(0, 0, 100, 10)
		min:   0
		max:   100
		value: 1.25
		style: SliderStyle{}
	})
	slider_new := Element{ ...slider_old, value: 2.5 }
	assert web_diff_trees(slider_old, slider_new).len == 1
	assert web_diff_trees(slider_old, slider_old).len == 0
}

fn test_web_diff_detects_scalar_changes_across_nested_structs() {
	base := web_diff_root([])
	changes := [
		Element{ ...base, submit_id: 'go' },
		Element{ ...base, box: BoxStyle{ ...base.box, opacity: 0.25 } },
		Element{ ...base, text_style: TextStyle{ ...base.text_style, size: 21.0 } },
		Element{ ...base, min_value: 0.5 },
		Element{ ...base, padding_left: 4.0 },
	]
	for changed in changes {
		assert web_diff_trees(base, changed).len == 1
	}
}
