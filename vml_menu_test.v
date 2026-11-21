module ui2

fn test_menu_bar_from_vml_matches_native_declarations() {
	menus := menu_bar_from_vml('
		MenuBar {
			Menu {
				title: "File"
				MenuItem { id: new text: "New" shortcut: "cmd+n" }
				MenuSeparator {}
				MenuItem { id: revert title: "Revert" enabled: false }
				Menu {
					title: "Export"
					MenuItem { id: export_pdf title: "PDF" }
				}
			}
			Menu {
				text: "View"
				MenuItem { id: wrap text: "Word Wrap" checked: true }
			}
		}
	') or { panic(err) }
	assert menus == [
		Menu{
			title: 'File'
			items: [
				menu_item_with_shortcut('new', 'New', 'cmd+n'),
				menu_separator(),
				disabled(menu_item('revert', 'Revert')),
				submenu('Export', [menu_item('export_pdf', 'PDF')]),
			]
		},
		Menu{
			title: 'View'
			items: [menu_check_item('wrap', 'Word Wrap', true)]
		},
	]
}

fn test_menu_bar_from_vml_accepts_one_menu_and_action_ids() {
	menus := menu_bar_from_vml('
		Menu {
			title: "File"
			MenuItem { id: open_row text: "Open" on_tap: file_open }
			MenuItem { text: "Save" on_tap: "file.save" }
			MenuItem { id: quit text: "Quit" }
		}
	') or { panic(err) }
	assert menus.len == 1
	assert menu_item_ids(menus[0].items) == ['file_open', 'file.save', 'quit']
	assert menus[0].items[0].enabled
	assert !menus[0].items[0].checked
	assert !menus[0].items[0].separator
}

fn test_menu_bar_from_vml_accepts_item_submenus_and_separators() {
	menus := menu_bar_from_vml('
		Menu {
			title: "File"
			MenuItem {
				title: "Export"
				MenuItem { id: pdf text: "PDF" }
				MenuItem { separator: true }
				Menu { title: "More" MenuItem { id: png text: "PNG" } }
			}
		}
	') or { panic(err) }
	assert menus[0].items[0].id == ''
	assert menus[0].items[0].items[1].separator
	assert menus[0].items[0].items[2].items[0].id == 'png'
}

fn test_menu_bar_from_vml_accepts_an_explicit_empty_bar() {
	menus := menu_bar_from_vml('MenuBar {}') or { panic(err) }
	assert menus.len == 0
}

fn test_menu_bar_from_vnode_is_pure_and_can_be_reused() {
	mut root := parse_vml('Menu { title: "View" MenuItem { id: wrap text: "Wrap" checked: false } }') or {
		panic(err)
	}
	before := menu_bar().clone()
	first := menu_bar_from_vnode(root) or { panic(err) }
	assert !first[0].items[0].checked
	mut row := root.children[0]
	row.props['checked'] = 'true'
	second := menu_bar_from_vnode(root) or { panic(err) }
	assert second[0].items[0].checked
	assert !first[0].items[0].checked
	assert root.children[0].prop('checked') == 'true'
	assert menu_bar() == before
}

fn test_existing_vml_context_menu_entries_are_unchanged() {
	el := element_from_vml('
		View {
			MenuItem { id: context_row text: "Copy" on_tap: copy }
			Label { id: caption text: "Hello" }
		}
	', rect(0, 0, 300, 200)) or { panic(err) }
	assert el.menu.len == 1
	assert el.menu[0].id == 'copy'
	assert el.menu[0].title == 'Copy'
	assert el.children.len == 1
	assert el.children[0].id == 'caption'
}

struct VmlMenuErrorCase {
	source   string
	expected string
}

fn test_menu_bar_from_vml_rejects_invalid_declarations() {
	cases := [
		VmlMenuErrorCase{'Screen {}', 'Menu or MenuBar root'},
		VmlMenuErrorCase{'MenuBar { MenuItem { id: a text: "A" } }', 'MenuBar expects Menu'},
		VmlMenuErrorCase{'MenuBar { title: "No" }', 'unsupported `title`'},
		VmlMenuErrorCase{'Menu { title: "File" Button {} }', 'unexpected `Button`'},
		VmlMenuErrorCase{'Menu {}', 'has no title'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a } }', 'has no title'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { text: "A" } }', 'emits no id'},
		VmlMenuErrorCase{'Menu { title: "File" Menu { title: "Empty" } }', 'emits no id'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" checked: yes } }', '`checked` must be true or false'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" enabled: 1 } }', '`enabled` must be true or false'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { separator: yes } }', '`separator` must be true or false'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" on_click: a } }', 'unsupported `on_click`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuSeparator { text: "No" } }', 'unsupported `text`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuSeparator { MenuItem {} } }', 'MenuSeparator cannot have children'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { separator: true shortcut: "cmd+n" } }', 'separator cannot carry'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { separator: true checked: true } }', 'separator cannot carry'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { separator: true enabled: false } }', 'separator cannot carry'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { separator: true id: a text: "A" } }', 'separator cannot carry'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" MenuItem { id: b text: "B" } } }', 'cannot also emit an id'},
		VmlMenuErrorCase{'MenuBar { Menu { title: "File" MenuItem { id: same text: "A" } } Menu { title: "Edit" Menu { title: "Nested" MenuItem { id: same text: "B" } } } }', 'duplicate menu item id `same`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" on_tap: shared } MenuItem { id: b text: "B" on_tap: shared } }', 'duplicate menu item id `shared`'},
	]
	for item in cases {
		menu_bar_from_vml(item.source) or {
			assert err.msg().contains(item.expected), '${item.source}: ${err}'
			continue
		}
		assert false, 'accepted invalid menu: ${item.source}'
	}
}

fn test_menu_bar_from_vml_rejects_unevaluated_expressions() {
	cases := [
		VmlMenuErrorCase{'Menu { title: app.title }', 'requires a literal `title`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { text: "Open" on_tap: app.open() } }', 'requires a literal `on_tap`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" on_tap: app.count = 1 } }', 'requires a literal `on_tap`'},
		VmlMenuErrorCase{'Menu { title: "File" MenuItem { id: a text: "A" bind.checked: app.checked } }', 'unsupported `bind.checked`'},
		VmlMenuErrorCase{'Menu { property string title: "File" }', 'does not support property declarations'},
		VmlMenuErrorCase{'Menu { title: "File" + " menu" }', 'requires a literal `title`'},
		VmlMenuErrorCase{r'Menu { title: "${app.title}" }', 'requires a literal `title`'},
	]
	for item in cases {
		menu_bar_from_vml(item.source) or {
			assert err.msg().contains(item.expected), '${item.source}: ${err}'
			assert err.msg().contains('line 1')
			continue
		}
		assert false, 'accepted unevaluated expression: ${item.source}'
	}
}

fn test_menu_bar_from_vml_preserves_parser_errors() {
	menu_bar_from_vml('Menu { title: "File"') or {
		assert err.msg().contains('expected rbrace')
		return
	}
	assert false, 'an unclosed menu must fail to parse'
}
