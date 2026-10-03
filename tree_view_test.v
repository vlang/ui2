module ui2

fn tree_view_test_nodes(expanded bool) []TreeViewNode {
	return [
		TreeViewNode{
			id: 'docs'
			text: 'Documentation'
			expanded: expanded
			children: [
				TreeViewNode{
					id: 'guide'
					text: 'Guide'
					children: [
						TreeViewNode{ id: 'install', text: 'Install', selected: true },
					]
				},
				TreeViewNode{ id: 'api', text: 'API' },
			]
		},
		TreeViewNode{ id: 'license', text: 'License' },
	]
}

fn test_tree_view_rows_flatten_only_expanded_nodes() {
	collapsed := tree_view_rows(
		frame: rect(0, 0, 300, 200)
		row_height: 32
		spacing: 4
		nodes: tree_view_test_nodes(false)
	) or { panic(err) }
	assert collapsed.len == 2
	assert collapsed[1].node.id == 'license'

	expanded := tree_view_rows(
		frame: rect(0, 0, 300, 200)
		row_height: 32
		spacing: 4
		nodes: tree_view_test_nodes(true)
	) or { panic(err) }
	assert expanded.len == 4
	assert expanded[1].node.id == 'guide'
	assert expanded[1].depth == 1
	assert expanded[2].node.id == 'api'
	assert expanded[3].frame == rect(0, 108, 300, 32)
}

fn test_tree_view_nested_expansion_and_content_height() {
	nodes := [TreeViewNode{
		id: 'root'
		text: 'Root'
		expanded: true
		children: [TreeViewNode{
			id: 'branch'
			text: 'Branch'
			expanded: true
			children: [TreeViewNode{ id: 'leaf', text: 'Leaf' }]
		}]
	}]
	config := TreeViewConfig{
		frame: rect(0, 0, 240, 200)
		row_height: 30
		spacing: 3
		nodes: nodes
	}
	rows := tree_view_rows(config) or { panic(err) }
	assert rows[2].depth == 2
	assert tree_view_content_height(config)! == 96
}

fn test_tree_view_constructor_builds_disclosure_and_selection_controls() {
	view_element := tree_view(
		id: 'navigation'
		frame: rect(10, 20, 300, 200)
		row_height: 32
		spacing: 4
		indent: 20
		disclosure_width: 24
		selected_row_box: BoxStyle{ bg: 0xdbeafe }
		nodes: [TreeViewNode{
			id: 'docs'
			text: 'Documentation'
			toggle_action_id: 'toggle_docs'
			expanded: true
			children: [TreeViewNode{
				id: 'guide'
				text: 'Guide'
				action_id: 'select_guide'
				selected: true
			}]
		}]
	) or { panic(err) }
	assert view_element.accessibility_role == 'tree'
	assert view_element.children.len == 2
	assert view_element.children[0].children[0].action_id == 'toggle_docs'
	assert view_element.children[0].children[0].accessibility_value == 'expanded'
	assert view_element.children[1].children[1].frame == rect(44, 0, 256, 32)
	assert view_element.children[1].children[1].box.bg == u32(0xdbeafe)
	assert view_element.children[1].children[1].action_id == 'select_guide'
	assert view_element.children[1].children[1].accessibility_value == 'selected'
}

fn test_tree_view_rejects_negative_geometry() {
	if _ := tree_view_rows(frame: rect(0, 0, 100, 100), indent: -1) {
		assert false, 'negative tree geometry must fail'
	} else {
		assert err.msg().contains('geometry')
	}
}
