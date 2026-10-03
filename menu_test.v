module ui2

fn sample_menus() []Menu {
	return [
		Menu{
			title: 'File'
			items: [
				menu_item_with_shortcut('new', 'New', 'cmd+n'),
				menu_separator(),
				disabled(menu_item('revert', 'Revert')),
				submenu('Export', [
					menu_item_with_shortcut('export_png', 'PNG', 'cmd+shift+p'),
					menu_item('export_pdf', 'PDF'),
				]),
			]
		},
		Menu{
			title: 'View'
			items: [
				menu_check_item('wrap', 'Word Wrap', true),
				menu_item_with_shortcut('refresh', 'Refresh', 'f5'),
			]
		},
	]
}

fn test_validate_menus_accepts_a_well_formed_declaration() {
	validate_menus(sample_menus()) or { panic(err) }
}

fn test_validate_menus_rejects_untitled_menus_and_rows() {
	validate_menus([Menu{ items: [menu_item('a', 'A')] }]) or {
		assert err.msg().contains('menu 0 has no title')
		validate_menus([Menu{
			title: 'File'
			items: [MenuItem{ id: 'a' }]
		}]) or {
			assert err.msg().contains('has no title')
			return
		}
		assert false, 'a titleless row should not validate'
		return
	}
	assert false, 'a titleless menu should not validate'
}

fn test_validate_menus_rejects_silent_and_duplicated_rows() {
	validate_menus([Menu{
		title: 'File'
		items: [MenuItem{ title: 'Quiet' }]
	}]) or {
		assert err.msg().contains('emits no id')
		validate_menus([Menu{
			title: 'File'
			items: [menu_item('same', 'One'), menu_item('same', 'Two')]
		}]) or {
			assert err.msg().contains('duplicate menu item id `same`')
			return
		}
		assert false, 'a duplicated id should not validate'
		return
	}
	assert false, 'a row emitting nothing should not validate'
}

fn test_validate_menus_rejects_a_submenu_that_also_emits() {
	validate_menus([Menu{
		title: 'File'
		items: [
			MenuItem{
				id: 'export'
				title: 'Export'
				items: [menu_item('export_pdf', 'PDF')]
			},
		]
	}]) or {
		assert err.msg().contains('cannot also emit an id')
		return
	}
	assert false, 'a submenu with an id should not validate'
}

fn test_validate_menus_rejects_a_decorated_separator() {
	validate_menus([Menu{
		title: 'File'
		items: [MenuItem{
			separator: true
			title: 'Nope'
		}]
	}]) or {
		assert err.msg().contains('separator')
		return
	}
	assert false, 'a titled separator should not validate'
}

fn test_parse_menu_shortcut_reads_modifiers_in_any_order() {
	parsed := parse_menu_shortcut('Shift+CMD+s')
	assert parsed.cmd
	assert parsed.shift
	assert !parsed.ctrl
	assert !parsed.alt
	assert parsed.key == 's'
	assert parse_menu_shortcut('option+f5').alt
	assert parse_menu_shortcut('option+f5').key == 'f5'
	assert parse_menu_shortcut('').key == ''
	assert parse_menu_shortcut('   ').key == ''
	// '+' is the separator and a bindable key at once.
	assert parse_menu_shortcut('cmd++').key == '+'
}

fn test_menu_shortcut_bindable_needs_a_modifier_or_a_function_key() {
	assert menu_shortcut_bindable(parse_menu_shortcut('cmd+n'))
	assert menu_shortcut_bindable(parse_menu_shortcut('f5'))
	assert !menu_shortcut_bindable(parse_menu_shortcut('n'))
	assert !menu_shortcut_bindable(parse_menu_shortcut('fish'))
	assert !menu_shortcut_bindable(parse_menu_shortcut(''))
}

fn test_menu_shortcut_matches_folds_cmd_onto_ctrl_off_macos() {
	declared := parse_menu_shortcut('cmd+s')
	assert menu_shortcut_matches(declared, parse_menu_shortcut('cmd+s'))
	assert !menu_shortcut_matches(declared, parse_menu_shortcut('cmd+shift+s'))
	assert !menu_shortcut_matches(declared, parse_menu_shortcut('cmd+d'))
	$if macos {
		assert !menu_shortcut_matches(declared, parse_menu_shortcut('ctrl+s'))
	} $else {
		assert menu_shortcut_matches(declared, parse_menu_shortcut('ctrl+s'))
	}
}

fn test_menu_shortcut_label_writes_the_platform_spelling() {
	assert menu_shortcut_label('') == ''
	$if macos {
		assert menu_shortcut_label('cmd+shift+s') == '⇧⌘S'
		assert menu_shortcut_label('cmd+left') == '⌘←'
	} $else {
		assert menu_shortcut_label('cmd+shift+s') == 'Ctrl+Shift+S'
		assert menu_shortcut_label('alt+f5') == 'Alt+F5'
	}
}

fn test_menu_item_ids_walks_submenus_and_skips_separators() {
	assert menu_item_ids(sample_menus()[0].items) == ['new', 'revert', 'export_png', 'export_pdf']
}

fn test_find_menu_item_reaches_into_a_submenu() {
	items := sample_menus()[0].items
	assert (find_menu_item(items, 'export_pdf') or { panic('missing row') }).title == 'PDF'
	assert !(find_menu_item(items, 'revert') or { panic('missing row') }).enabled
	if _ := find_menu_item(items, 'nope') {
		assert false, 'an unknown id should not resolve'
	}
}

fn test_find_menu_shortcut_skips_disabled_rows() {
	menus := sample_menus()
	found := find_menu_shortcut(menus[0].items, parse_menu_shortcut('cmd+shift+p')) or {
		panic('missing shortcut')
	}
	assert found.id == 'export_png'
	assert (find_menu_shortcut(menus[1].items, parse_menu_shortcut('f5')) or {
		panic('missing shortcut')
	}).id == 'refresh'
	if _ := find_menu_shortcut(menus[0].items, parse_menu_shortcut('cmd+q')) {
		assert false, 'an unbound chord should not resolve'
	}
}

fn test_disabled_keeps_the_rest_of_the_row() {
	row := disabled(menu_item_with_shortcut('save', 'Save', 'cmd+s'))
	assert row.id == 'save'
	assert row.title == 'Save'
	assert row.shortcut == 'cmd+s'
	assert !row.enabled
}
