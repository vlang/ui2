module ui2

// web_diff_trees computes a keyed reconciliation from old_root to new_root.
// It is deliberately conservative: scalar changes become in-place `update`
// ops, and any change to a child's key, id, kind or order becomes one
// `replace_children` op for that parent. key/id reconciliation follows the
// same rules as the native backends (see reconciliation_child_key in ui.v);
// an element with neither falls back to its child index.
pub fn web_diff_trees(old_root Element, new_root Element) []PatchOp {
	mut ops := []PatchOp{}
	web_diff_node(old_root, new_root, [], mut ops)
	return ops
}

fn web_diff_node(old Element, new Element, path []int, mut ops []PatchOp) {
	if !web_same_scalars(old, new) {
		ops << PatchOp{
			kind:    .update
			path:    path.clone()
			element: new
		}
	}

	old_keys := web_child_keys(old.children)
	new_keys := web_child_keys(new.children)
	if web_same_keys(old_keys, new_keys) {
		for index, child in new.children {
			mut child_path := path.clone()
			child_path << index
			web_diff_node(old.children[index], child, child_path, mut ops)
		}
		return
	}

	if old.children.len > 0 || new.children.len > 0 {
		ops << PatchOp{
			kind:     .replace_children
			path:     path.clone()
			children: new.children.clone()
		}
	}
}

// web_same_scalars compares every Element field except `children`. V derives
// struct equality from the complete field list, so this is exhaustive by
// construction (a field added to Element is covered automatically) and far
// cheaper than JSON-encoding the whole element at every node. The shallow
// copies only replace the children slice; V compares all other fields —
// including nested structs, slices and maps — by value.
fn web_same_scalars(a Element, b Element) bool {
	return Element{ ...a, children: [] } == Element{ ...b, children: [] }
}

fn web_child_keys(children []Element) []string {
	mut keys := []string{len: children.len}
	for index, child in children {
		keys[index] = if child.key.len > 0 {
			'k:' + child.key
		} else if child.id.len > 0 {
			'i:' + child.id
		} else {
			'p:${index}'
		}
	}
	return keys
}

fn web_same_keys(a []string, b []string) bool {
	if a.len != b.len {
		return false
	}
	for i, key in a {
		if key != b[i] {
			return false
		}
	}
	return true
}

// web_apply_patch applies a patch to a tree and returns the resulting tree.
// The renderer implements the same semantics in JavaScript; this reference
// implementation lets the protocol be tested without a browser and gives the
// server a way to keep its own tree in step with the client.
pub fn web_apply_patch(root Element, patch WebPatch) !Element {
	mut result := root
	for op in patch.ops {
		result = web_apply_op(result, op)!
	}
	return result
}

fn web_apply_op(root Element, op PatchOp) !Element {
	if op.path.len == 0 {
		return match op.kind {
			.update {
				Element{ ...op.element, children: root.children }
			}
			.replace_children {
				Element{ ...root, children: op.children.clone() }
			}
		}
	}

	index := op.path[0]
	if index < 0 || index >= root.children.len {
		return error('web patch path ${op.path} is out of range')
	}
	mut children := root.children.clone()
	children[index] = web_apply_op(root.children[index], PatchOp{
		...op
		path: op.path[1..]
	})!
	return Element{ ...root, children: children }
}
