module ui2

pub struct TreeViewNode {
pub:
	id               string
	text             string
	action_id        string
	toggle_action_id string
	expanded         bool
	selected         bool
	enabled          bool = true
	children         []TreeViewNode
}

pub struct TreeViewConfig {
pub:
	id                    string
	frame                 Rect
	box                   BoxStyle
	row_height            f64 = 36.0
	spacing               f64 = 2.0
	indent                f64 = 24.0
	disclosure_width      f64 = 28.0
	row_box               BoxStyle
	selected_row_box      BoxStyle
	disclosure_box        BoxStyle
	text_style            TextStyle
	selected_text_style   TextStyle
	disclosure_text_style TextStyle
	nodes                 []TreeViewNode
}

pub struct TreeViewRow {
pub:
	node  TreeViewNode
	depth int
	frame Rect
}

fn tree_view_append_rows(nodes []TreeViewNode, depth int, row_height f64, spacing f64, width f64, mut rows []TreeViewRow) {
	for node in nodes {
		y := f64(rows.len) * (row_height + spacing)
		rows << TreeViewRow{
			node: node
			depth: depth
			frame: rect(0, y, width, row_height)
		}
		if node.expanded {
			tree_view_append_rows(node.children, depth + 1, row_height, spacing, width, mut rows)
		}
	}
}

fn tree_view_validate(config TreeViewConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('tree view dimensions cannot be negative')
	}
	if config.row_height < 0 || config.spacing < 0 || config.indent < 0
		|| config.disclosure_width < 0 {
		return error('tree view geometry cannot be negative')
	}
}

// tree_view_rows flattens the expanded portion of a node hierarchy into
// parent-local row geometry.
pub fn tree_view_rows(config TreeViewConfig) ![]TreeViewRow {
	tree_view_validate(config)!
	mut rows := []TreeViewRow{}
	tree_view_append_rows(config.nodes, 0, config.row_height, config.spacing, config.frame.width, mut rows)
	return rows
}

pub fn tree_view_content_height(config TreeViewConfig) !f64 {
	rows := tree_view_rows(config)!
	if rows.len == 0 {
		return 0
	}
	return f64(rows.len) * config.row_height + f64(rows.len - 1) * config.spacing
}

fn tree_view_control_id(id string, suffix string) string {
	return if id.len > 0 { '${id}__${suffix}' } else { '' }
}

pub fn tree_view(config TreeViewConfig) !Element {
	rows := tree_view_rows(config)!
	mut children := []Element{cap: rows.len}
	for row in rows {
		indent_x := f64(row.depth) * config.indent
		label_x := indent_x + config.disclosure_width
		label_width := if config.frame.width > label_x {
			config.frame.width - label_x
		} else {
			0.0
		}
		selected_box := if row.node.selected { config.selected_row_box } else { config.row_box }
		selected_text := if row.node.selected {
			config.selected_text_style
		} else {
			config.text_style
		}
		mut row_children := []Element{cap: 2}
		if row.node.children.len > 0 {
			row_children << Element{
				...button(tree_view_control_id(row.node.id, 'toggle'), if row.node.expanded {
					'▾'
				} else {
					'▸'
				}, rect(indent_x, 0, config.disclosure_width, config.row_height), config.disclosure_box, config.disclosure_text_style)
				action_id: row.node.toggle_action_id
				enabled: row.node.enabled
				accessibility_role: 'button'
				accessibility_label: if row.node.expanded {
					'Collapse ${row.node.text}'
				} else {
					'Expand ${row.node.text}'
				}
				accessibility_value: if row.node.expanded { 'expanded' } else { 'collapsed' }
			}
		} else {
			row_children << view('', rect(indent_x, 0, config.disclosure_width, config.row_height), BoxStyle{ transparent: true }, [])
		}
		row_children << Element{
			...button(row.node.id, row.node.text, rect(label_x, 0, label_width, config.row_height), selected_box, selected_text)
			action_id: row.node.action_id
			enabled: row.node.enabled
			accessibility_role: 'treeitem'
			accessibility_label: row.node.text
			accessibility_value: if row.node.selected { 'selected' } else { 'not selected' }
		}
		children << view(tree_view_control_id(row.node.id, 'row'), row.frame, BoxStyle{ transparent: true }, row_children)
	}
	return Element{
		...view(config.id, config.frame, config.box, children)
		accessibility_role: 'tree'
	}
}
