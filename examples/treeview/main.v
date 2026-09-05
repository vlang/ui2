module main

import ui2

const treeview_width = 680
const treeview_height = 480
const treeview_qml_source = $embed_file('treeview.qml').to_string()

pub struct TreeNode {
pub:
	id        int
	parent_id int
	title     string
	depth     int
	folder    bool
	expanded  bool
}

pub struct TreeRow {
pub:
	id       int
	title    string
	depth    int
	folder   bool
	expanded bool
}

pub struct TreeviewDemo {
pub mut:
	nodes   []TreeNode
	visible []TreeRow
	status  string = 'Select a file or expand a folder.'
}

fn initial_treeview() TreeviewDemo {
	mut app := TreeviewDemo{
		nodes: [
			TreeNode{ id: 1, parent_id: -1, title: 'toto1', depth: 0, folder: true, expanded: true },
			TreeNode{ id: 2, parent_id: 1, title: 'file: ftftyty1', depth: 1 },
			TreeNode{ id: 3, parent_id: 1, title: 'file: hgyfyf1', depth: 1 },
			TreeNode{ id: 4, parent_id: 1, title: 'tttytyty1', depth: 1, folder: true },
			TreeNode{ id: 5, parent_id: 4, title: 'file: tutu2', depth: 2 },
			TreeNode{ id: 6, parent_id: 4, title: 'file: ytytyy2', depth: 2 },
			TreeNode{ id: 7, parent_id: -1, title: 'toto2', depth: 0, folder: true, expanded: true },
			TreeNode{ id: 8, parent_id: 7, title: 'file: ftftyty1', depth: 1 },
			TreeNode{ id: 9, parent_id: 7, title: 'file: hgyfyf1111', depth: 1 },
			TreeNode{ id: 10, parent_id: -1, title: 'toto3', depth: 0, folder: true, expanded: true },
			TreeNode{ id: 11, parent_id: 10, title: 'file: ftftyty2', depth: 1 },
			TreeNode{ id: 12, parent_id: 10, title: 'file: hgyfyf2222', depth: 1 },
		]
	}
	app.refresh_visible()
	return app
}

fn tree_node_visible(nodes []TreeNode, node TreeNode) bool {
	mut parent_id := node.parent_id
	for parent_id >= 0 {
		mut parent_found := false
		for parent in nodes {
			if parent.id == parent_id {
				if !parent.expanded {
					return false
				}
				parent_id = parent.parent_id
				parent_found = true
				break
			}
		}
		if !parent_found {
			return false
		}
	}
	return true
}

fn (mut app TreeviewDemo) refresh_visible() {
	mut rows := []TreeRow{}
	for node in app.nodes {
		if tree_node_visible(app.nodes, node) {
			rows << TreeRow{
				id: node.id
				title: node.title
				depth: node.depth
				folder: node.folder
				expanded: node.expanded
			}
		}
	}
	app.visible = rows
}

pub fn (mut app TreeviewDemo) select_node(id int) {
	for index, node in app.nodes {
		if node.id != id {
			continue
		}
		if node.folder {
			app.nodes[index] = TreeNode{
				...node
				expanded: !node.expanded
			}
			app.status = '${node.title} ${if node.expanded { 'collapsed' } else { 'expanded' }}.'
			app.refresh_visible()
		} else {
			app.status = '${node.title} selected.'
		}
		return
	}
}

fn main() {
	ui2.run_qml[TreeviewDemo](
		source: treeview_qml_source
		model: initial_treeview()
		title: 'Tree View'
		width: treeview_width
		height: treeview_height
	) or { panic(err) }
}
