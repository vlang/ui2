from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str) -> None:
    p = ROOT / path
    text = p.read_text()
    if old not in text:
        raise SystemExit(f"expected source fragment not found in {path}: {old[:80]!r}")
    p.write_text(text.replace(old, new, 1))


def write(path: str, content: str) -> None:
    p = ROOT / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content)


# Shared menu/dropdown icon data.
replace(
    "ui/ui.v",
    """pub struct MenuEntry {\npub:\n\tid    string\n\ttitle string\n}\n""",
    """pub struct MenuEntry {\npub:\n\tid         string\n\ttitle      string\n\timage_path string\n}\n""",
)
replace(
    "ui/ui.v",
    """pub fn dropdown(id string, selected string, options []string, frame Rect, box_ BoxStyle, style TextStyle) Element {\n\tmut entries := []MenuEntry{}\n\tfor option in options {\n\t\tentries << MenuEntry{\n\t\t\tid: option\n\t\t\ttitle: option\n\t\t}\n\t}\n\treturn Element{\n\t\tkind: .dropdown\n\t\tid: id\n\t\ttext: selected\n\t\tframe: frame\n\t\tbox: box_\n\t\ttext_style: style\n\t\tmenu: entries\n\t}\n}\n""",
    """pub fn dropdown(id string, selected string, options []string, frame Rect, box_ BoxStyle, style TextStyle) Element {\n\tmut entries := []MenuEntry{}\n\tfor option in options {\n\t\tentries << MenuEntry{\n\t\t\tid: option\n\t\t\ttitle: option\n\t\t}\n\t}\n\treturn dropdown_entries(id, selected, entries, frame, box_, style)\n}\n\npub fn dropdown_entries(id string, selected string, entries []MenuEntry, frame Rect, box_ BoxStyle, style TextStyle) Element {\n\treturn Element{\n\t\tkind: .dropdown\n\t\tid: id\n\t\ttext: selected\n\t\tframe: frame\n\t\tbox: box_\n\t\ttext_style: style\n\t\tmenu: entries\n\t}\n}\n""",
)

replace(
    "ui/menu.v",
    """\tshortcut  string\n\tseparator bool\n\tchecked   bool\n\tenabled   bool = true\n\titems     []MenuItem\n""",
    """\tshortcut string\n\t// icon is an image path. macOS also accepts `symbol:<SF Symbol name>`.\n\ticon      string\n\tseparator bool\n\tchecked   bool\n\tenabled   bool = true\n\titems     []MenuItem\n""",
)
replace(
    "ui/menu.v",
    """\t\tif item.separator {\n\t\t\tif item.id.len > 0 || item.title.len > 0 || item.items.len > 0 {\n\t\t\t\treturn error('separator at ${here} cannot carry a title, id or submenu')\n""",
    """\t\tif item.separator {\n\t\t\tif item.id.len > 0 || item.title.len > 0 || item.icon.len > 0 || item.items.len > 0 {\n\t\t\t\treturn error('separator at ${here} cannot carry a title, id, icon or submenu')\n""",
)

# QML: icon-bearing controls/options and declaration-only application menus.
replace(
    "ui/qml.v",
    """fn q_menu(node &QNode) []MenuEntry {\n\tmut out := []MenuEntry{}\n\tfor child in node.children {\n\t\tif child.tag == 'MenuItem' {\n\t\t\tout << MenuEntry{\n\t\t\t\tid: child.prop_or('on_tap', child.id)\n\t\t\t\ttitle: child.prop('text')\n\t\t\t}\n\t\t}\n\t}\n\treturn out\n}\n""",
    """fn q_menu(node &QNode) []MenuEntry {\n\tmut out := []MenuEntry{}\n\tfor child in node.children {\n\t\tif child.tag == 'MenuItem' {\n\t\t\tout << MenuEntry{\n\t\t\t\tid: child.prop_or('on_tap', child.id)\n\t\t\t\ttitle: child.prop('text')\n\t\t\t\timage_path: q_icon_source(child)\n\t\t\t}\n\t\t}\n\t}\n\treturn out\n}\n\nfn q_icon_source(node &QNode) string {\n\tfor key in ['icon', 'icon.source', 'image', 'image_path'] {\n\t\tvalue := node.prop(key)\n\t\tif value.len > 0 {\n\t\t\treturn value\n\t\t}\n\t}\n\treturn ''\n}\n\nfn q_declaration_only_tag(tag string) bool {\n\treturn tag in ['MenuBar', 'Menu', 'MenuItem', 'MenuSeparator', 'Option']\n}\n""",
)
replace(
    "ui/qml.v",
    """\t\t'Button' {\n\t\t\treturn Element{\n\t\t\t\t...button(node.id, node.prop('text'), frame, q_box(node), q_text_style(node))\n\t\t\t\taction_id: node.prop('on_tap')\n\t\t\t}\n\t\t}\n""",
    """\t\t'Button' {\n\t\t\treturn Element{\n\t\t\t\t...button(node.id, node.prop('text'), frame, q_box(node), q_text_style(node))\n\t\t\t\taction_id: node.prop('on_tap')\n\t\t\t\timage_path: q_icon_source(node)\n\t\t\t}\n\t\t}\n""",
)
replace(
    "ui/qml.v",
    """\t\t\treturn Element{\n\t\t\t\t...dropdown(node.id, node.prop('text'), q_options(node), frame, q_box(node), q_text_style(node))\n\t\t\t\taction_id: action_id\n\t\t\t}\n""",
    """\t\t\treturn Element{\n\t\t\t\t...dropdown_entries(node.id, node.prop('text'), q_option_entries(node), frame, q_box(node), q_text_style(node))\n\t\t\t\taction_id: action_id\n\t\t\t}\n""",
)
replace(
    "ui/qml.v",
    """fn q_children(node &QNode, frame Rect) ![]Element {\n\tmut out := []Element{}\n\tfor child in node.children {\n\t\tif child.tag == 'MenuItem' || child.tag == 'Option' {\n\t\t\tcontinue // context menu entries, not child views\n\t\t}\n\t\tout << node_to_element(child, frame)!\n\t}\n\treturn out\n}\n\nfn q_options(node &QNode) []string {\n\tmut options := []string{}\n\tfor child in node.children {\n\t\tif child.tag == 'Option' {\n\t\t\toptions << child.prop('text')\n\t\t}\n\t}\n\treturn options\n}\n""",
    """fn q_children(node &QNode, frame Rect) ![]Element {\n\tmut out := []Element{}\n\tfor child in node.children {\n\t\tif q_declaration_only_tag(child.tag) {\n\t\t\tcontinue\n\t\t}\n\t\tout << node_to_element(child, frame)!\n\t}\n\treturn out\n}\n\nfn q_option_entries(node &QNode) []MenuEntry {\n\tmut options := []MenuEntry{}\n\tfor child in node.children {\n\t\tif child.tag == 'Option' {\n\t\t\ttitle := child.prop('text')\n\t\t\toptions << MenuEntry{\n\t\t\t\tid: child.prop_or('value', child.prop_or('id', title))\n\t\t\t\ttitle: title\n\t\t\t\timage_path: q_icon_source(child)\n\t\t\t}\n\t\t}\n\t}\n\treturn options\n}\n\nfn q_options(node &QNode) []string {\n\treturn q_option_entries(node).map(it.title)\n}\n""",
)
replace(
    "ui/qml.v",
    """\tfor child in node.children {\n\t\tif child.tag == 'MenuItem' || child.tag == 'Option' {\n\t\t\tcontinue\n\t\t}\n\t\tchild_h := q_dimension(child, 'height', 32)\n""",
    """\tfor child in node.children {\n\t\tif q_declaration_only_tag(child.tag) {\n\t\t\tcontinue\n\t\t}\n\t\tchild_h := q_dimension(child, 'height', 32)\n""",
)
replace(
    "ui/qml.v",
    """\tfor child in node.children {\n\t\tif child.tag == 'MenuItem' || child.tag == 'Option' {\n\t\t\tcontinue\n\t\t}\n\t\tchild_w := q_dimension(child, 'width', 80)\n""",
    """\tfor child in node.children {\n\t\tif q_declaration_only_tag(child.tag) {\n\t\t\tcontinue\n\t\t}\n\t\tchild_w := q_dimension(child, 'width', 80)\n""",
)

write(
    "ui/qml_menu.v",
    r'''module ui2

// menus_from_qml extracts a static MenuBar declaration from a QML document.
// Model-backed documents should use menus_from_qml_model or run_qml.
pub fn menus_from_qml(source string) ![]Menu {
	root := parse_qml(source)!
	return qml_menus_from_qnode(root)!
}

// menus_from_qml_model evaluates MenuBar properties against the same typed
// model used by run_qml, including checked/enabled state and action handlers.
pub fn menus_from_qml_model[T](source string, model T, frame Rect) ![]Menu {
	template := parse_qml(source)!
	q_validate_template[T](template, model)!
	resolved, _ := q_evaluate_template(template, model, frame)!
	return qml_menus_from_qnode(resolved)!
}

fn qml_menus_from_qnode(root &QNode) ![]Menu {
	bar := qml_find_menu_bar(root) or { return []Menu{} }
	mut menus := []Menu{}
	for child in bar.children {
		if child.tag != 'Menu' {
			continue
		}
		menus << Menu{
			title: qml_menu_title(child)
			items: qml_menu_items_from_node(child)!
		}
	}
	validate_menus(menus)!
	return menus
}

fn qml_find_menu_bar(node &QNode) ?&QNode {
	if node.tag == 'MenuBar' {
		return unsafe { node }
	}
	for child in node.children {
		if found := qml_find_menu_bar(child) {
			return found
		}
	}
	return none
}

fn qml_menu_title(node &QNode) string {
	return node.prop_or('title', node.prop('text'))
}

fn qml_menu_items_from_node(node &QNode) ![]MenuItem {
	mut items := []MenuItem{}
	for child in node.children {
		match child.tag {
			'MenuSeparator' {
				items << menu_separator()
			}
			'Menu' {
				items << MenuItem{
					title: qml_menu_title(child)
					icon: q_icon_source(child)
					enabled: child.prop('enabled') != 'false'
					items: qml_menu_items_from_node(child)!
				}
			}
			'MenuItem' {
				children := qml_menu_items_from_node(child)!
				items << MenuItem{
					id: if children.len > 0 { '' } else { child.prop_or('on_tap', child.id) }
					title: qml_menu_title(child)
					shortcut: child.prop('shortcut')
					icon: q_icon_source(child)
					checked: child.prop_bool('checked')
					enabled: child.prop('enabled') != 'false'
					items: children
				}
			}
			else {}
		}
	}
	return items
}

fn qml_menu_signature(menus []Menu) string {
	mut out := ''
	for menu in menus {
		out += 'M${qml_signature_field(menu.title)}'
		qml_menu_items_signature(menu.items, mut out)
	}
	return out
}

fn qml_menu_items_signature(items []MenuItem, mut out string) {
	for item in items {
		out += 'I${qml_signature_field(item.id)}${qml_signature_field(item.title)}${qml_signature_field(item.shortcut)}${qml_signature_field(item.icon)}'
		out += if item.separator { '1' } else { '0' }
		out += if item.checked { '1' } else { '0' }
		out += if item.enabled { '1' } else { '0' }
		qml_menu_items_signature(item.items, mut out)
		out += ';'
	}
}

fn qml_signature_field(value string) string {
	return '${value.len}:${value}'
}
''',
)

# Model evaluation skips app-level declarations during layout and keeps the
# installed menu bar reconciled with model state.
replace(
    "ui/qml_model.v",
    """fn (mut layout QChildLayout) advance(child &QNode) {\n\tif child.tag in ['MenuItem', 'Option'] {\n\t\treturn\n\t}\n""",
    """fn (mut layout QChildLayout) advance(child &QNode) {\n\tif q_declaration_only_tag(child.tag) {\n\t\treturn\n\t}\n""",
)
replace(
    "ui/qml_model.v",
    """struct QmlController[T] {\n\ttemplate &QNode\nmut:\n\tmodel  T\n\tevents map[string]QmlEvent\n}\n""",
    """struct QmlController[T] {\n\ttemplate &QNode\nmut:\n\tmodel          T\n\tevents         map[string]QmlEvent\n\tmenu_signature string\n}\n""",
)
replace(
    "ui/qml_model.v",
    """\tcontroller.events = events.clone()\n\treturn element_from_qnode(resolved, rect(0, 0, frame.width, frame.height)) or {\n""",
    """\tcontroller.events = events.clone()\n\tmenus := qml_menus_from_qnode(resolved) or {\n\t\teprintln('ui2 QML menu conversion failed: ${err}')\n\t\treturn screen(0xffffff, [])\n\t}\n\tmenu_signature := qml_menu_signature(menus)\n\tif menu_signature != controller.menu_signature {\n\t\tset_menu_bar(menus)\n\t\tcontroller.menu_signature = menu_signature\n\t}\n\treturn element_from_qnode(resolved, rect(0, 0, frame.width, frame.height)) or {\n""",
)
replace(
    "ui/qml_model.v",
    """\tresolved, events := q_evaluate_template(template, config.model, initial_frame)!\n\tvalidate_element_tree(element_from_qnode(resolved, initial_frame)!)!\n\tmut controller := &QmlController[T]{\n\t\ttemplate: template\n\t\tmodel: config.model\n\t\tevents: events\n\t}\n""",
    """\tresolved, events := q_evaluate_template(template, config.model, initial_frame)!\n\tvalidate_element_tree(element_from_qnode(resolved, initial_frame)!)!\n\tmenus := qml_menus_from_qnode(resolved)!\n\tset_menu_bar(menus)\n\tmut controller := &QmlController[T]{\n\t\ttemplate: template\n\t\tmodel: config.model\n\t\tevents: events\n\t\tmenu_signature: qml_menu_signature(menus)\n\t}\n""",
)

# Custom renderer: buttons, dropdown options, and menu rows render icons.
replace(
    "ui/ui_immediate.c.v",
    """\t\tdropdown    bool\n\t\toptions     []string\n""",
    """\t\tdropdown    bool\n\t\toptions     []string\n\t\toption_icons []string\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\trow_height f64\n\t\toptions    []string\n\t\tselected   int = -1\n""",
    """\t\trow_height f64\n\t\toptions    []string\n\t\ticons      []string\n\t\tselected   int = -1\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\tdraw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)\n\t\t\tif el.enabled {\n""",
    """\t\t\tif el.image_path.len > 0 {\n\t\t\t\tmut icon_size := 18.0\n\t\t\t\tif el.frame.height - 8 < icon_size {\n\t\t\t\t\ticon_size = el.frame.height - 8\n\t\t\t\t}\n\t\t\t\tif icon_size > 0 {\n\t\t\t\t\ticon_x := if el.text.len > 0 { x + 8 } else { x + (el.frame.width - icon_size) / 2 }\n\t\t\t\t\t_ = draw_cached_image(ctx, el.image_path, icon_x, y + (el.frame.height - icon_size) / 2, icon_size, icon_size, 0)\n\t\t\t\t\tif el.text.len > 0 {\n\t\t\t\t\t\ttext_x := x + icon_size + 12\n\t\t\t\t\t\tdraw_text_centered(ctx, el.text, text_x, y, el.frame.width - icon_size - 16, el.frame.height, el.text_style)\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t} else {\n\t\t\t\tdraw_text_centered(ctx, el.text, x, y, el.frame.width, el.frame.height, el.text_style)\n\t\t\t}\n\t\t\tif el.enabled {\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\tpadding := if el.padding_left > 0 { el.padding_left } else { 12.0 }\n\t\t\ttext_width := if el.frame.width > padding + 32 { el.frame.width - padding - 32 } else { 0.0 }\n\t\t\tdraw_text(ctx, selected, x + padding, y, text_width, el.frame.height, el.text_style)\n""",
    """\t\t\tpadding := if el.padding_left > 0 { el.padding_left } else { 12.0 }\n\t\t\tmut text_x := x + padding\n\t\t\tmut text_width := if el.frame.width > padding + 32 { el.frame.width - padding - 32 } else { 0.0 }\n\t\t\tfor entry in el.menu {\n\t\t\t\tif entry.title == selected && entry.image_path.len > 0 {\n\t\t\t\t\ticon_size := if el.frame.height > 24 { 16.0 } else { el.frame.height - 8 }\n\t\t\t\t\tif icon_size > 0 {\n\t\t\t\t\t\t_ = draw_cached_image(ctx, entry.image_path, text_x, y + (el.frame.height - icon_size) / 2, icon_size, icon_size, 0)\n\t\t\t\t\t\ttext_x += icon_size + 6\n\t\t\t\t\t\ttext_width -= icon_size + 6\n\t\t\t\t\t}\n\t\t\t\t\tbreak\n\t\t\t\t}\n\t\t\t}\n\t\t\tdraw_text(ctx, selected, text_x, y, text_width, el.frame.height, el.text_style)\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\t\tmut options := []string{cap: el.menu.len}\n\t\t\t\tfor entry in el.menu {\n\t\t\t\t\toptions << entry.title\n\t\t\t\t}\n""",
    """\t\t\t\tmut options := []string{cap: el.menu.len}\n\t\t\t\tmut option_icons := []string{cap: el.menu.len}\n\t\t\t\tfor entry in el.menu {\n\t\t\t\t\toptions << entry.title\n\t\t\t\t\toption_icons << entry.image_path\n\t\t\t\t}\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\t\t\tdropdown: true\n\t\t\t\t\toptions: options\n\t\t\t\t}, clip)\n""",
    """\t\t\t\t\tdropdown: true\n\t\t\t\t\toptions: options\n\t\t\t\t\toption_icons: option_icons\n\t\t\t\t}, clip)\n""",
)
replace(
    "ui/ui_immediate.c.v",
    "track_dropdown_popup(el, x, y, options, selected)",
    "track_dropdown_popup(el, x, y, options, option_icons, selected)",
)
replace(
    "ui/ui_immediate.c.v",
    "fn track_dropdown_popup(el Element, x f64, y f64, options []string, selected string) {",
    "fn track_dropdown_popup(el Element, x f64, y f64, options []string, icons []string, selected string) {",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\toptions: options\n\t\tselected: selected_index\n""",
    """\t\toptions: options\n\t\ticons: icons\n\t\tselected: selected_index\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\tdraw_text(ctx, option, popup.x + 26, row_y, popup.width - 34, popup.row_height,\n\t\t\t\trow_style)\n""",
    """\t\t\tmut label_x := popup.x + 26\n\t\t\tif index < popup.icons.len && popup.icons[index].len > 0 {\n\t\t\t\ticon_size := if popup.row_height > 24 { 16.0 } else { popup.row_height - 8 }\n\t\t\t\tif icon_size > 0 {\n\t\t\t\t\t_ = draw_cached_image(ctx, popup.icons[index], label_x, row_y + (popup.row_height - icon_size) / 2, icon_size, icon_size, 0)\n\t\t\t\t\tlabel_x += icon_size + 6\n\t\t\t\t}\n\t\t\t}\n\t\t\tdraw_text(ctx, option, label_x, row_y, popup.x + popup.width - 8 - label_x, popup.row_height,\n\t\t\t\trow_style)\n""",
)
replace(
    "ui/ui_immediate.c.v",
    """\t\t\t\toption_index: index\n\t\t\t\toptions: popup.options\n""",
    """\t\t\t\toption_index: index\n\t\t\t\toptions: popup.options\n\t\t\t\toption_icons: popup.icons\n""",
)

replace(
    "ui/menu_custom.c.v",
    "\tconst menubar_row_tail = 26.0\n",
    "\tconst menubar_row_tail = 26.0\n\tconst menubar_icon_size = 16.0\n",
)
replace(
    "ui/menu_custom.c.v",
    """\t\t\tlabel_width := width - menubar_row_indent - menubar_row_tail\n\t\t\tdraw_text(ctx, item.title, x + menubar_row_indent, row_y, label_width, menubar_row_height,\n\t\t\t\tmenu_bar_row_style(item.enabled))\n""",
    """\t\t\tmut label_x := x + menubar_row_indent\n\t\t\tif item.icon.len > 0 {\n\t\t\t\t_ = draw_cached_image(ctx, item.icon, label_x, row_y + (menubar_row_height - menubar_icon_size) / 2, menubar_icon_size, menubar_icon_size, 0)\n\t\t\t\tlabel_x += menubar_icon_size + 5\n\t\t\t}\n\t\t\tlabel_width := x + width - menubar_row_tail - label_x\n\t\t\tdraw_text(ctx, item.title, label_x, row_y, label_width, menubar_row_height,\n\t\t\t\tmenu_bar_row_style(item.enabled))\n""",
)
replace(
    "ui/menu_custom.c.v",
    """\t\t\tmut needed := menubar_row_indent + menubar_row_tail +\n\t\t\t\tmenu_text_width(ctx, item.title, menu_bar_row_style(item.enabled))\n""",
    """\t\t\tmut needed := menubar_row_indent + menubar_row_tail +\n\t\t\t\tmenu_text_width(ctx, item.title, menu_bar_row_style(item.enabled))\n\t\t\tif item.icon.len > 0 {\n\t\t\t\tneeded += menubar_icon_size + 5\n\t\t\t}\n""",
)

# AppKit already understands button images. Reuse its menu-image loader for
# native application/context menu rows and include images in reconciliation.
replace(
    "ui/menu_darwin.v",
    """\t\tmacos.msg_void_bool(parent, 'setEnabled:', item.enabled)\n\t\tmacos.msg_void1(menu, 'addItem:', parent)\n""",
    """\t\tmacos.msg_void_bool(parent, 'setEnabled:', item.enabled)\n\t\tif item.icon.len > 0 {\n\t\t\tmacos.msg_void1(parent, 'setImage:', macos_status_image(item.icon))\n\t\t}\n\t\tmacos.msg_void1(menu, 'addItem:', parent)\n""",
)
replace(
    "ui/menu_darwin.v",
    """\tmacos.msg_void_i64(row, 'setState:', if item.checked { ns_control_state_on } else { ns_control_state_off })\n\t// Bind by sender pointer rather than by a positional tag, so a retained\n""",
    """\tmacos.msg_void_i64(row, 'setState:', if item.checked { ns_control_state_on } else { ns_control_state_off })\n\tif item.icon.len > 0 {\n\t\tmacos.msg_void1(row, 'setImage:', macos_status_image(item.icon))\n\t}\n\t// Bind by sender pointer rather than by a positional tag, so a retained\n""",
)
replace(
    "appkit/ui_macos_darwin.v",
    "signature += '${entry.id.len}:${entry.id}${entry.title.len}:${entry.title};'",
    "signature += '${entry.id.len}:${entry.id}${entry.title.len}:${entry.title}${entry.image_path.len}:${entry.image_path};'",
)
replace(
    "appkit/ui_macos_darwin.v",
    """\t\tmacos.msg_void1(item, 'setTarget:', st.button_handler)\n\t\tpointer := u64(voidptr(item))\n""",
    """\t\tmacos.msg_void1(item, 'setTarget:', st.button_handler)\n\t\tif e.image_path.len > 0 {\n\t\t\tmacos.msg_void1(item, 'setImage:', macos_status_image(e.image_path))\n\t\t}\n\t\tpointer := u64(voidptr(item))\n""",
)

# The menubar example now keeps the complete UI declaration in QML.
write(
    "examples/menubar/menubar.qml",
    r'''Screen {
    id: root
    background: #F1F5F9

    MenuBar {
        Menu {
            title: "File"
            MenuItem { text: "New Note" shortcut: "cmd+n" on_tap: app.choose_action("file_new") }
            MenuItem { text: "Open…" shortcut: "cmd+o" on_tap: app.choose_action("file_open") }
            MenuSeparator {}
            MenuItem { text: "Save" shortcut: "cmd+s" on_tap: app.choose_action("file_save") }
            MenuItem { text: "Revert" enabled: false on_tap: app.choose_action("file_revert") }
            MenuSeparator {}
            MenuItem { text: "Close Window" shortcut: "cmd+w" on_tap: app.choose_action("file_close") }
        }
        Menu {
            title: "Edit"
            MenuItem { text: "Undo" shortcut: "cmd+z" on_tap: app.choose_action("edit_undo") }
            MenuItem { text: "Redo" shortcut: "cmd+shift+z" on_tap: app.choose_action("edit_redo") }
            MenuSeparator {}
            Menu {
                title: "Find"
                MenuItem { text: "Find…" shortcut: "cmd+f" on_tap: app.choose_action("find_open") }
                MenuItem { text: "Find Next" shortcut: "cmd+g" on_tap: app.choose_action("find_next") }
                MenuItem { text: "Find Previous" shortcut: "cmd+shift+g" on_tap: app.choose_action("find_previous") }
            }
        }
        Menu {
            title: "View"
            MenuItem { text: "Show Details" checked: app.show_details on_tap: app.choose_action("view_details") }
            MenuItem { text: "Word Wrap" checked: app.word_wrap on_tap: app.choose_action("view_wrap") }
            MenuSeparator {}
            Menu {
                title: "Zoom"
                MenuItem { text: "Zoom In" shortcut: "cmd+=" on_tap: app.choose_action("zoom_in") }
                MenuItem { text: "Zoom Out" shortcut: "cmd+-" on_tap: app.choose_action("zoom_out") }
                MenuItem { text: "Actual Size" shortcut: "cmd+0" on_tap: app.choose_action("zoom_reset") }
            }
        }
        Menu {
            title: "Help"
            MenuItem { text: "About This Demo" on_tap: app.choose_action("help_about") }
        }
    }

    Rectangle {
        id: card
        x: 16
        y: 16
        width: root.width - 32
        height: root.height - 32
        background: #FFFFFF
        corner_radius: 10

        Label { text: "Menu bar" x: 18 y: 14 width: card.width - 36 height: 28 color: #111827 font_size: 18 bold: true }
        Label { id: backend_note text: app.backend_note x: 18 y: 44 width: card.width - 36 height: 20 color: #64748B font_size: 12 }

        Rectangle { x: 18 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Show Details" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: details_state text: app.show_details ? "on" : "off" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 178 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Word Wrap" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: wrap_state text: app.word_wrap ? "on" : "off" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }
        Rectangle { x: 338 y: 74 width: 150 height: 54 background: #EFF6FF corner_radius: 8
            Label { text: "Zoom" x: 12 y: 8 width: 126 height: 16 color: #1D4ED8 font_size: 11 }
            Label { id: zoom_state text: "${app.zoom}%" x: 12 y: 26 width: 126 height: 20 color: #1E3A8A font_size: 15 bold: true }
        }

        Rectangle { x: 18 y: 142 width: card.width - 36 height: 48 background: #DCFCE7 corner_radius: 8
            Label { id: last_action text: app.last_action x: 14 y: 0 width: card.width - 64 height: 48 color: #166534 font_size: 13 }
        }

        Label { text: "Chosen rows" x: 18 y: 202 width: card.width - 36 height: 18 color: #64748B font_size: 12 }

        TextArea {
            id: menu_log
            text: app.log
            editable: false
            x: 18
            y: 224
            width: card.width - 36
            height: card.height - 286
            background: #F8FAFC
            color: #334155
            font_size: 13
            corner_radius: 7
        }

        Button { id: reset text: "Clear log" on_tap: app.reset() native: true enabled: app.chosen > 0 x: 18 y: card.height - 52 width: 110 height: 34 }
        Label { id: chosen_count text: "${app.chosen} chosen" x: 140 y: card.height - 46 width: card.width - 176 height: 22 color: #94A3B8 font_size: 12 }
    }
}
''',
)

write(
    "examples/menubar/main.v",
    r'''// A window whose complete menu hierarchy and body are declared in QML.
module main

import ui2

const menubar_width = 660
const menubar_height = 470
const menubar_qml_source = $embed_file('menubar.qml').to_string()

const menubar_action_titles = {
	'file_new':      'New Note'
	'file_open':     'Open…'
	'file_save':     'Save'
	'file_revert':   'Revert'
	'file_close':    'Close Window'
	'edit_undo':     'Undo'
	'edit_redo':     'Redo'
	'find_open':     'Find…'
	'find_next':     'Find Next'
	'find_previous': 'Find Previous'
	'view_details':  'Show Details'
	'view_wrap':     'Word Wrap'
	'zoom_in':       'Zoom In'
	'zoom_out':      'Zoom Out'
	'zoom_reset':    'Actual Size'
	'help_about':    'About This Demo'
}

@[heap]
pub struct MenubarDemo {
pub mut:
	last_action  string = 'Choose something from the menu bar.'
	log          string
	chosen       int
	show_details bool = true
	word_wrap    bool
	zoom         int = 100
	backend_note string
}

pub fn (mut app MenubarDemo) choose_action(id string) {
	app.choose(id)
}

pub fn (mut app MenubarDemo) choose(id string) bool {
	title := menubar_action_titles[id] or { return false }
	app.chosen++
	mut detail := title
	match id {
		'view_details' {
			app.show_details = !app.show_details
			detail = '${title} is now ${on_off(app.show_details)}'
		}
		'view_wrap' {
			app.word_wrap = !app.word_wrap
			detail = '${title} is now ${on_off(app.word_wrap)}'
		}
		'zoom_in' {
			app.zoom = if app.zoom < 200 { app.zoom + 10 } else { 200 }
			detail = 'Zoomed to ${app.zoom}%'
		}
		'zoom_out' {
			app.zoom = if app.zoom > 50 { app.zoom - 10 } else { 50 }
			detail = 'Zoomed to ${app.zoom}%'
		}
		'zoom_reset' {
			app.zoom = 100
			detail = 'Zoom reset to 100%'
		}
		else {}
	}
	app.last_action = detail
	app.prepend_log('${app.chosen:2}. ${detail}')
	return true
}

pub fn (mut app MenubarDemo) reset() {
	app.chosen = 0
	app.log = ''
	app.last_action = 'Choose something from the menu bar.'
}

fn (mut app MenubarDemo) prepend_log(line string) {
	mut lines := if app.log.len == 0 { []string{} } else { app.log.split_into_lines() }
	lines.insert(0, line)
	if lines.len > 12 {
		lines = lines[..12].clone()
	}
	app.log = lines.join('\n')
}

fn on_off(value bool) string {
	return if value { 'on' } else { 'off' }
}

fn main() {
	mut app := MenubarDemo{}
	app.backend_note = if ui2.menu_bar_supported() {
		'This backend has a real menu bar.'
	} else {
		'This backend has no menu bar; the declaration is ignored.'
	}
	ui2.run_qml[MenubarDemo](
		source: menubar_qml_source
		model: app
		title: 'Menu Bar'
		width: menubar_width
		height: menubar_height
	) or { panic(err) }
}
''',
)

write(
    "examples/menubar/menubar_test.v",
    r'''module main

import ui2

fn find_menubar_element(element ui2.Element, id string) ?ui2.Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		if found := find_menubar_element(child, id) {
			return found
		}
	}
	return none
}

fn find_menubar_item_title(items []ui2.MenuItem, title string) ?ui2.MenuItem {
	for item in items {
		if item.title == title {
			return item
		}
		if found := find_menubar_item_title(item.items, title) {
			return found
		}
	}
	return none
}

fn test_menubar_declaration_is_valid_and_complete() {
	menus := ui2.menus_from_qml_model(menubar_qml_source, MenubarDemo{}, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	assert menus.map(it.title) == ['File', 'Edit', 'View', 'Help']
	mut ids := []string{}
	for m in menus {
		ids << ui2.menu_item_ids(m.items)
	}
	assert ids.len == menubar_action_titles.len
}

fn test_menubar_declares_shortcuts_a_backend_can_bind() {
	menus := ui2.menus_from_qml_model(menubar_qml_source, MenubarDemo{}, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	save := find_menubar_item_title(menus[0].items, 'Save') or { panic('missing Save') }
	assert ui2.menu_shortcut_bindable(ui2.parse_menu_shortcut(save.shortcut))
	redo := find_menubar_item_title(menus[1].items, 'Redo') or { panic('missing Redo') }
	parsed := ui2.parse_menu_shortcut(redo.shortcut)
	assert parsed.cmd && parsed.shift && parsed.key == 'z'
	assert (find_menubar_item_title(menus[1].items, 'Find Next') or { panic('missing Find Next') }).shortcut == 'cmd+g'
	assert !(find_menubar_item_title(menus[0].items, 'Revert') or { panic('missing Revert') }).enabled
}

fn test_menubar_check_rows_follow_the_model() {
	mut app := MenubarDemo{}
	menus_before := ui2.menus_from_qml_model(menubar_qml_source, app, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	assert (find_menubar_item_title(menus_before[2].items, 'Show Details') or {
		panic('missing Show Details')
	}).checked
	assert app.choose('view_details')
	menus_after := ui2.menus_from_qml_model(menubar_qml_source, app, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	assert !(find_menubar_item_title(menus_after[2].items, 'Show Details') or {
		panic('missing Show Details')
	}).checked
}

fn test_menubar_choose_logs_and_ignores_unknown_ids() {
	mut app := MenubarDemo{}
	assert !app.choose('not_a_row')
	assert app.chosen == 0
	assert app.choose('file_new')
	assert app.last_action == 'New Note'
	assert app.log.contains('New Note')
	assert app.chosen == 1
	assert app.choose('zoom_out')
	assert app.zoom == 90
	assert app.last_action == 'Zoomed to 90%'
	assert app.choose('zoom_reset')
	assert app.zoom == 100
	app.reset()
	assert app.chosen == 0
	assert app.log == ''
}

fn test_menubar_zoom_stays_within_its_range() {
	mut app := MenubarDemo{}
	for _ in 0 .. 20 {
		app.choose('zoom_in')
	}
	assert app.zoom == 200
	for _ in 0 .. 40 {
		app.choose('zoom_out')
	}
	assert app.zoom == 50
}

fn test_menubar_log_keeps_only_the_recent_rows() {
	mut app := MenubarDemo{}
	for _ in 0 .. 20 {
		app.choose('file_save')
	}
	assert app.log.split_into_lines().len == 12
	assert app.log.split_into_lines()[0].contains('20.')
}

fn test_menubar_qml_shows_the_model_state() {
	root := ui2.element_from_qml_model(menubar_qml_source, MenubarDemo{}, ui2.rect(0, 0,
		menubar_width, menubar_height)) or { panic(err) }
	ui2.validate_element_tree(root) or { panic(err) }
	assert (find_menubar_element(root, 'details_state') or { panic('missing details chip') }).text == 'on'
	assert (find_menubar_element(root, 'zoom_state') or { panic('missing zoom chip') }).text == '100%'
	assert (find_menubar_element(root, 'menu_log') or { panic('missing log') }).readonly
	reset := find_menubar_element(root, 'reset') or { panic('missing reset button') }
	assert reset.native_style
	assert !reset.enabled
}
''',
)

write(
    "ui/qml_menu_test.v",
    r'''module ui2

struct QmlMenuModel {
pub mut:
	checked bool = true
	enabled bool = true
}

pub fn (mut app QmlMenuModel) choose(_ string) {}

fn test_qml_menu_bar_is_recursive_and_model_driven() {
	source := 'Screen { MenuBar { Menu { title: "File" MenuItem { text: "Open" shortcut: "cmd+o" icon: "open.png" on_tap: app.choose("open") } MenuSeparator {} Menu { title: "Export" MenuItem { text: "PDF" on_tap: app.choose("pdf") } } } Menu { title: "View" MenuItem { text: "Checked" checked: app.checked enabled: app.enabled on_tap: app.choose("checked") } } } }'
	menus := menus_from_qml_model(source, QmlMenuModel{}, rect(0, 0, 400, 300)) or { panic(err) }
	assert menus.len == 2
	assert menus[0].title == 'File'
	assert menus[0].items[0].title == 'Open'
	assert menus[0].items[0].shortcut == 'cmd+o'
	assert menus[0].items[0].icon == 'open.png'
	assert menus[0].items[1].separator
	assert menus[0].items[2].title == 'Export'
	assert menus[0].items[2].items[0].title == 'PDF'
	assert menus[1].items[0].checked
	assert menus[1].items[0].enabled
	assert menus[0].items[0].id.starts_with('__qml_event_')
}

fn test_qml_menu_model_refresh_changes_declared_state() {
	source := 'Screen { MenuBar { Menu { title: "View" MenuItem { text: "Checked" checked: app.checked enabled: app.enabled on_tap: app.choose("checked") } } } }'
	mut app := QmlMenuModel{}
	before := menus_from_qml_model(source, app, rect(0, 0, 400, 300)) or { panic(err) }
	assert before[0].items[0].checked
	app.checked = false
	app.enabled = false
	after := menus_from_qml_model(source, app, rect(0, 0, 400, 300)) or { panic(err) }
	assert !after[0].items[0].checked
	assert !after[0].items[0].enabled
	assert qml_menu_signature(before) != qml_menu_signature(after)
}

fn test_qml_button_and_dropdown_options_keep_icons() {
	source := 'Screen { Button { id: open text: "Open" icon.source: "open.png" x: 0 y: 0 width: 100 height: 32 } Dropdown { id: kind text: "PNG" x: 0 y: 40 width: 140 height: 32 Option { value: "png" text: "PNG" icon: "png.png" } Option { value: "pdf" text: "PDF" icon: "pdf.png" } } }'
	root := element_from_qml(source, rect(0, 0, 300, 200)) or { panic(err) }
	assert root.children.len == 2
	assert root.children[0].image_path == 'open.png'
	assert root.children[1].menu.len == 2
	assert root.children[1].menu[0].id == 'png'
	assert root.children[1].menu[0].image_path == 'png.png'
	assert root.children[1].menu[1].image_path == 'pdf.png'
}

fn test_menu_bar_nodes_do_not_become_window_views() {
	source := 'Screen { MenuBar { Menu { title: "File" MenuItem { id: open text: "Open" } } } Label { id: body text: "Body" x: 0 y: 0 width: 80 height: 20 } }'
	root := element_from_qml(source, rect(0, 0, 300, 200)) or { panic(err) }
	assert root.children.len == 1
	assert root.children[0].id == 'body'
}
''',
)

write(
    "cmd/ui2-qml/main.v",
    r'''module main

import os
import ui2

struct PreviewModel {}

fn main() {
	if os.args.len != 2 {
		eprintln('usage: ui2-qml <file.qml>')
		exit(2)
	}
	path := os.real_path(os.args[1])
	source := os.read_file(path) or {
		eprintln('ui2-qml: ${err}')
		exit(1)
	}
	ui2.run_qml[PreviewModel](
		source: source
		model: PreviewModel{}
		title: os.file_name(path)
		width: 800
		height: 600
	) or {
		eprintln('ui2-qml: ${err}')
		exit(1)
	}
}
''',
)

# Documentation is intentionally appended as one focused section so the static
# preview command and icon/menu syntax stay discoverable together.
readme_marker = "## Examples\n"
readme_insert = r'''## QML application menus, icons, and preview

A QML document can own the complete desktop menu hierarchy. `run_qml` evaluates
`MenuBar`, nested `Menu`, `MenuItem`, and `MenuSeparator` declarations against
the same typed `app` model as the window body, installs the result through the
native/custom menu backend, and refreshes checked/enabled state after actions:

```qml
MenuBar {
    Menu {
        title: "File"
        MenuItem { text: "Open" shortcut: "cmd+o" on_tap: app.open() }
        MenuSeparator {}
        Menu {
            title: "Export"
            MenuItem { text: "PDF" on_tap: app.export_pdf() }
        }
    }
    Menu {
        title: "View"
        MenuItem { text: "Word Wrap" checked: app.word_wrap on_tap: app.toggle_wrap() }
    }
}
```

Images can be attached to controls with `icon` (or `icon.source`). Buttons use
the existing `image_path` channel, dropdown `Option` declarations keep an image
beside each row, and application/context `MenuItem` declarations carry the same
image path. The custom renderer draws all three; AppKit also renders button and
menu images. Backends that cannot attach an image to a particular native row
still preserve its text, shortcut, state, and action. macOS menu rows also
accept `symbol:<SF Symbol name>`.

```qml
Button { text: "Open" icon: "assets/open.png" on_tap: app.open() }
Dropdown {
    text: "PNG"
    Option { value: "png" text: "PNG" icon: "assets/png.png" }
    Option { value: "pdf" text: "PDF" icon: "assets/pdf.png" }
}
```

For model-free documents, build or run the small preview executable directly:

```sh
v run cmd/ui2-qml myApp.qml
# or
v -o ui2-qml cmd/ui2-qml
./ui2-qml myApp.qml
```

The previewer uses ui2's own QML parser and renderer rather than Qt's QML engine,
so what it shows follows the same control and menu conversion paths as the app.
Documents that depend on application-specific `app` fields or methods should be
previewed through their typed `run_qml` model (fixture/model injection can be
layered on top of the same loader later).

'''
p = ROOT / "README.md"
text = p.read_text()
if readme_marker not in text:
    raise SystemExit("README examples marker missing")
p.write_text(text.replace(readme_marker, readme_insert + readme_marker, 1))
