module ui2

// menu_bar_from_vml loads a standalone Menu or MenuBar document. It returns a
// declaration without installing native menus; pass the result to set_menu_bar.
// Values are literal, and on_tap names an action id handled by run_window.
// App expressions, bindings and Screen documents belong to the visual VML
// runtime and are deliberately not evaluated by this loader.
pub fn menu_bar_from_vml(source string) ![]Menu {
	return menu_bar_from_vnode(parse_vml(source)!)!
}

// menu_bar_from_vnode converts a parsed, literal menu document. This is useful
// when loading a document once and updating its props in V before reinstalling
// the menu. The input tree is not changed.
pub fn menu_bar_from_vnode(node &VNode) ![]Menu {
	mut menus := []Menu{}
	match node.tag {
		'Menu' {
			menus << vml_application_menu(node)!
		}
		'MenuBar' {
			vml_menu_properties(node, []string{})!
			for child in node.children {
				if child.tag != 'Menu' {
					return error('MenuBar expects Menu children, got `${child.tag}` at line ${child.line}')
				}
				menus << vml_application_menu(child)!
			}
		}
		else {
			return error('menu VML requires a Menu or MenuBar root, got `${node.tag}` at line ${node.line}')
		}
	}
	validate_menus(menus)!
	return menus
}

fn vml_application_menu(node &VNode) !Menu {
	vml_menu_properties(node, ['title', 'text'])!
	return Menu{
		title: node.prop_or('title', node.prop('text'))
		items: vml_application_menu_items(node)!
	}
}

fn vml_application_menu_items(node &VNode) ![]MenuItem {
	mut items := []MenuItem{}
	for child in node.children {
		match child.tag {
			'Menu' {
				nested := vml_application_menu(child)!
				items << submenu(nested.title, nested.items)
			}
			'MenuSeparator' {
				vml_menu_properties(child, []string{})!
				if child.children.len > 0 {
					return error('MenuSeparator cannot have children at line ${child.line}')
				}
				items << menu_separator()
			}
			'MenuItem' {
				vml_menu_properties(child, ['id', 'title', 'text', 'on_tap', 'shortcut', 'checked',
					'enabled', 'separator'])!
				item := MenuItem{
					id:        child.prop_or('on_tap', child.id)
					title:     child.prop_or('title', child.prop('text'))
					shortcut:  child.prop('shortcut')
					separator: child.prop_bool('separator')
					checked:   child.prop_bool('checked')
					enabled:   child.prop('enabled') != 'false'
					items:     vml_application_menu_items(child)!
				}
				if item.separator && (item.id.len > 0 || item.title.len > 0
					|| item.shortcut.len > 0 || item.checked || !item.enabled
					|| item.items.len > 0) {
					return error('separator cannot carry an action, title, shortcut, state or submenu at line ${child.line}')
				}
				items << item
			}
			else {
				return error('unexpected `${child.tag}` in menu at line ${child.line}')
			}
		}
	}
	return items
}

fn vml_menu_properties(node &VNode, allowed []string) ! {
	if node.property_types.len > 0 {
		return error('menu VML does not support property declarations at line ${node.line}')
	}
	for key, value in node.props {
		if key !in allowed {
			return error('unsupported `${key}` on ${node.tag} at line ${node.line}')
		}
		if key in ['checked', 'enabled', 'separator'] && value !in ['true', 'false'] {
			return error('`${key}` must be true or false at line ${node.line}')
		}
	}
	for key, expr in node.expressions {
		if expr.kind !in [.literal, .path]
			|| (expr.kind == .path && expr.value.contains('.')) {
			return error('menu VML requires a literal `${key}` at line ${expr.line}; use an action id rather than an app expression')
		}
	}
}
