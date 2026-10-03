module ui2

fn adaptive_test_element(root Element, id string) ?Element {
	if root.id == id { return root }
	for child in root.children {
		if found := adaptive_test_element(child, id) { return found }
	}
	return none
}

fn test_adaptive_vml_resizes_against_actual_window_bounds() {
	source := 'Screen { adaptive: true width: 760 height: 520
		Button { id: pinned x: 624 y: 460 width: 112 height: 36 layout_x: end layout_y: end }
		TextField { id: wide x: 24 y: 24 width: 712 height: 36 layout_x: stretch }
		Label { id: centered x: 320 y: 248 width: 120 height: 24 layout_x: center layout_y: center }
	}'
	root := element_from_vml(source, rect(0, 0, 390, 844))!
	assert adaptive_test_element(root, 'pinned')?.frame == rect(254, 784, 112, 36)
	assert adaptive_test_element(root, 'wide')?.frame == rect(24, 24, 342, 36)
	assert adaptive_test_element(root, 'centered')?.frame == rect(135, 410, 120, 24)
	validate_element_tree(root)!
}

fn test_adaptive_vml_metadata_does_not_render_and_does_not_mutate_source() {
	source := 'Screen { adaptive: true width: 760 height: 520
		Button { id: action x: 620.5 y: 460.25 width: 112.5 height: 36.25 layout_x: end layout_y: end
			LayoutVariation { width_class: compact reference_width: 390 reference_height: 844
				x: 24.5 y: 784.25 width: 341 height: 36.25 layout_x: stretch layout_y: end }
		}
	}'
	node := parse_vml(source)!
	before := node.children[0].props.clone()
	for width in [390.0, 1280.0, 320.0, 600.0, 390.0] {
		root := element_from_vnode(node, rect(0, 0, width, 844))!
		control := adaptive_test_element(root, 'action')?
		assert control.children.len == 0
		assert node.children[0].props == before
		assert node.children[0].children.len == 1
		if width < 600 {
			assert control.frame.x == 24.5
			assert control.frame.width == width - 49
		} else {
			assert control.frame.x == width - 139.5
			assert control.frame.width == 112.5
		}
	}
}

fn test_adaptive_vml_selects_exact_class_then_width_then_height() {
	source := 'Screen { adaptive: true width: 760 height: 520
		Label { id: choice x: 1 y: 2 width: 80 height: 24 text: "Shared"
			LayoutVariation { height_class: compact reference_width: 760 reference_height: 520 x: 10 y: 2 width: 80 height: 24 }
			LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 20 y: 2 width: 80 height: 24 }
			LayoutVariation { width_class: compact height_class: compact reference_width: 390 reference_height: 320 x: 30 y: 2 width: 80 height: 24 hidden: true }
		}
	}'
	for size, expected_x in {
		'800x800': 1.0
		'800x400': 10.0
		'400x800': 20.0
		'400x400': 30.0
	} {
		parts := size.split('x')
		root := element_from_vml(source, rect(0, 0, parts[0].f64(), parts[1].f64()))!
		control := adaptive_test_element(root, 'choice')?
		assert control.frame.x == expected_x
		assert control.text == 'Shared'
		assert control.hidden == (size == '400x400')
	}
}

fn test_adaptive_vml_width_wins_single_axis_tie_independent_of_source_order() {
	for variants in [
		'LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 20 y: 2 width: 80 height: 24 }
		 LayoutVariation { height_class: compact reference_width: 760 reference_height: 520 x: 10 y: 2 width: 80 height: 24 }',
		'LayoutVariation { height_class: compact reference_width: 760 reference_height: 520 x: 10 y: 2 width: 80 height: 24 }
		 LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 20 y: 2 width: 80 height: 24 }',
	] {
		root := element_from_vml('Screen { adaptive: true width: 760 height: 520 Label { id: choice width: 80 height: 24 ${variants} } }', rect(0,
			0, 400, 400))!
		assert adaptive_test_element(root, 'choice')?.frame.x == 20
	}
}

fn test_adaptive_vml_is_opt_in_and_retains_dropdown_options() {
	root := element_from_vml('Screen { width: 760 height: 520
		Dropdown { id: choices x: 24 y: 30 width: 180 height: 36 layout_x: end
			Option { text: "One" } Option { text: "Two" }
			LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 10 y: 10 width: 100 height: 36 }
		}
	}', rect(0,
		0, 390, 844))!
	control := adaptive_test_element(root, 'choices')?
	assert control.frame == rect(24, 30, 180, 36)
	assert control.children.len == 0
}

fn test_adaptive_vml_rejects_invalid_constraints_and_variations() {
	invalid := [
		'Screen { adaptive: true width: 0 height: 520 }',
		'Screen { adaptive: true width: 760 height: 520 layout_breakpoint_width: 0 }',
		'Screen { adaptive: true width: 760 height: 520 Button { layout_x: sideways } }',
		'Screen { adaptive: true width: 760 height: 520 Button { width: -1 } }',
		'Screen { adaptive: true width: 760 height: 520 Button { layout_min_width: 100 layout_max_width: 50 } }',
		'Screen { adaptive: true width: 760 height: 520 Button { LayoutVariation { width_class: giant } } }',
		'Screen { adaptive: true width: 760 height: 520 Button { LayoutVariation { width_class: any height_class: any } } }',
		'Screen { adaptive: true width: 760 height: 520 Button { LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 0 y: 0 width: 100 height: 30 mystery: 1 } } }',
		'Screen { adaptive: true width: 760 height: 520 Button { LayoutVariation { width_class: compact } } }',
		'Screen { adaptive: true width: 760 height: 520 LayoutVariation {} }',
	]
	for source in invalid {
		if _ := element_from_vml(source, rect(0, 0, 390, 844)) {
			assert false, 'expected an invalid adaptive document to fail: ${source}'
		}
	}
}

fn test_adaptive_vml_duplicate_class_is_an_error() {
	variation := 'LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 0 y: 0 width: 100 height: 30 }'
	source := 'Screen { adaptive: true width: 760 height: 520 Button { ${variation} ${variation} } }'
	if _ := element_from_vml(source, rect(0, 0, 390, 844)) {
		assert false
	} else {
		assert err.msg().contains('duplicate LayoutVariation')
	}
}

fn test_adaptive_vml_omitted_dimensions_use_the_reference_canvas_once() {
	node := parse_vml('Screen { adaptive: true width: 760 height: 520
		Rectangle { id: full layout_x: stretch layout_y: stretch }
		Rectangle { id: wide height: 48 layout_x: stretch }
		Rectangle { id: tall width: 64 layout_y: stretch }
	}')!
	for size in [rect(0, 0, 760, 520), rect(0, 0, 390, 844), rect(0, 0, 320, 240),
		rect(0, 0, 1280, 900), rect(0, 0, 390, 844)] {
		root := element_from_vnode(node, size)!
		assert adaptive_test_element(root, 'full')?.frame == size
		assert adaptive_test_element(root, 'wide')?.frame == rect(0, 0, size.width, 48)
		assert adaptive_test_element(root, 'tall')?.frame == rect(0, 0, 64, size.height)
		// Rendering must not fill defaults into the saved document on resize.
		assert node.children[0].prop('width') == ''
		assert node.children[0].prop('height') == ''
		assert node.children[1].prop('width') == ''
		assert node.children[2].prop('height') == ''
		validate_element_tree(root)!
	}
}

fn test_adaptive_vml_omitted_dimensions_support_all_parent_pins() {
	for axis in ['start', 'end', 'center', 'stretch'] {
		node := parse_vml('Screen { adaptive: true width: 760 height: 520
			Rectangle { id: fill x: 14 y: 18 layout_x: ${axis} layout_y: ${axis} }
		}')!
		for size in [rect(0, 0, 390, 240), rect(0, 0, 1280, 900)] {
			dx := size.width - 760
			dy := size.height - 520
			expected := match axis {
				'end' { rect(14 + dx, 18 + dy, 760, 520) }
				'center' { rect(14 + dx / 2, 18 + dy / 2, 760, 520) }
				'stretch' { rect(14, 18, size.width, size.height) }
				else { rect(14, 18, 760, 520) }
			}

			root := element_from_vnode(node, size)!
			assert adaptive_test_element(root, 'fill')?.frame == expected, axis
		}
	}
}

fn test_adaptive_vml_omitted_base_dimensions_preserve_explicit_variations() {
	mut node := parse_vml('Screen { adaptive: true width: 760 height: 520
		Rectangle { id: fill layout_x: stretch layout_y: stretch
			LayoutVariation { width_class: compact reference_width: 390 reference_height: 844
				x: 5 y: 6 width: 300 height: 400 }
		}
	}')!
	for size in [rect(0, 0, 390, 844), rect(0, 0, 500, 700), rect(0, 0, 800, 900),
		rect(0, 0, 390, 844)] {
		root := element_from_vnode(node, size)!
		expected := if size.width < 600 {
			rect(5, 6, size.width - 90, size.height - 444)
		} else {
			size
		}
		assert adaptive_test_element(root, 'fill')?.frame == expected
		assert node.children[0].prop('width') == ''
		assert node.children[0].children.len == 1
	}
	// Fixed-coordinate Screens still use their declared size, not runtime bounds.
	node.props['adaptive'] = 'false'
	fixed := element_from_vnode(node, rect(0, 0, 390, 844))!
	assert adaptive_test_element(fixed, 'fill')?.frame == rect(0, 0, 760, 520)
}

fn assert_adaptive_container_metadata_is_nonvisual(tag string, first string, second string) ! {
	variations := [
		'LayoutVariation { width_class: compact reference_width: 390 reference_height: 844 x: 4 y: 8 width: 300 height: 240 }',
		'LayoutVariation { height_class: compact reference_width: 760 reference_height: 520 x: 4 y: 8 width: 300 height: 240 }',
		'LayoutVariation { width_class: regular height_class: regular reference_width: 800 reference_height: 800 x: 4 y: 8 width: 300 height: 240 }',
	]
	// Nonzero padding/spacing and non-first page/slide indices expose metadata
	// that is counted for layout even if the resulting blank element is hidden.
	properties := 'id: container x: 4 y: 8 width: 300 height: 240 padding: 8 spacing: 7 columns: 2 page: 1 index: 1'
	clean := '${tag} { ${properties} ${first} ${second} }'
	annotated := '${tag} { ${properties} ${variations[0]} ${first} ${variations[1]} ${second} ${variations[2]} }'
	mut node := parse_vml('Screen { width: 760 height: 520 ${annotated} }')!
	mut expected_node := parse_vml('Screen { width: 760 height: 520 ${clean} }')!
	before := node.children[0].props.clone()
	child_count := node.children[0].children.len
	// Exercise retained metadata when adaptive mode is absent, enabled, disabled,
	// and enabled again, reusing the same parsed document throughout.
	for mode in ['', 'true', 'false', 'true', 'false'] {
		if mode.len > 0 {
			node.props['adaptive'] = mode
			expected_node.props['adaptive'] = mode
		}
		root := element_from_vnode(node, rect(0, 0, 390, 844))!
		expected := element_from_vnode(expected_node, rect(0, 0, 390, 844))!
		assert root == expected, '${tag}: adaptive=${mode}'
		assert node.children[0].props == before
		assert node.children[0].children.len == child_count
		validate_element_tree(root)!
	}
	// Standalone containers and nested layouts also take specialized traversals.
	direct := element_from_vml(annotated, rect(0, 0, 390, 844))!
	assert direct == element_from_vml(clean, rect(0, 0, 390, 844))!, tag
	for mode in ['true', 'false'] {
		nested := 'Screen { adaptive: ${mode} width: 760 height: 520
			View { width: 500 height: 400 ${annotated} } }'
		expected := 'Screen { adaptive: ${mode} width: 760 height: 520
			View { width: 500 height: 400 ${clean} } }'
		assert element_from_vml(nested, rect(0, 0, 390, 844))! == element_from_vml(expected, rect(0,
			0, 390, 844))!, '${tag}: nested adaptive=${mode}'
	}
}

fn test_adaptive_vml_metadata_never_occupies_container_layout_slots() {
	for tag in ['Column', 'Row', 'BoxLayout', 'FloatLayout', 'RelativeLayout', 'GridLayout',
		'AnchorLayout', 'StackLayout', 'PageLayout', 'Carousel', 'View', 'Rectangle', 'Scroll'] {
		assert_adaptive_container_metadata_is_nonvisual(tag,
			'Label { id: first text: "First" width: 40 height: 24 }',
			'Label { id: second text: "Second" width: 40 height: 24 }')!
	}
}

fn test_adaptive_vml_metadata_is_inert_in_empty_layouts() {
	for tag in ['Column', 'Row', 'BoxLayout', 'FloatLayout', 'RelativeLayout', 'GridLayout',
		'AnchorLayout', 'StackLayout', 'PageLayout', 'Carousel', 'View', 'Rectangle', 'Scroll'] {
		assert_adaptive_container_metadata_is_nonvisual(tag, '', '')!
	}
}

fn test_adaptive_vml_metadata_preserves_specialized_content_options_and_menus() {
	cases := {
		'TabbedPanel':   [
			'Tab { id: one text: "One" Label { id: inside text: "Keep me" } }',
			'Tab { id: two text: "Two" }',
		]
		'Accordion':     [
			'AccordionItem { id: one title: "One" Label { id: inside text: "Keep me" } }',
			'AccordionItem { id: two title: "Two" }',
		]
		'TreeView':      ['TreeNode { id: one text: "One" }', 'TreeNode { id: two text: "Two" }']
		'ScreenManager': ['Screen { id: one Label { id: inside text: "Keep me" } }',
			'Screen { id: two }']
		'ModalView':     ['Label { id: inside text: "Keep me" }', '']
		'Popup':         ['Label { id: inside text: "Keep me" }', '']
		'MessageBox':    ['Button { id: ok text: "OK" }', 'Button { id: cancel text: "Cancel" }']
		'Dropdown':      ['Option { text: "One" }', 'Option { text: "Two" }']
		'Column':        ['MenuItem { id: inspect text: "Inspect" }',
			'Label { id: inside text: "Keep me" }']
	}
	for tag, content in cases {
		assert_adaptive_container_metadata_is_nonvisual(tag, content[0], content[1])!
	}
}
