module ui2

fn vml_style_doc(body string) string {
	return 'Screen {\n\tid: root\n\twidth: 400\n\theight: 300\n${body}\n}'
}

fn test_vml_style_block_parses_to_source() {
	node := parse_vml(vml_style_doc('\tStyle {\n\t\tButton.primary { background: #3478D4; }\n\t}\n\tButton {\n\t\tid: b\n\t}')) or {
		panic(err)
	}
	assert node.children.len == 2
	style := node.children[0]
	assert style.tag == 'Style'
	assert style.prop('source').contains('Button.primary')
	assert style.prop('source').contains('#3478D4')
	assert node.children[1].tag == 'Button'
}

fn test_vml_style_block_ignores_braces_in_strings() {
	node := parse_vml(vml_style_doc('\tStyle {\n\t\tLabel { text: "a { b }"; color: red; }\n\t}\n')) or {
		panic(err)
	}
	style := node.children[0]
	assert style.tag == 'Style'
	assert style.prop('source').contains('"a { b }"')
}

fn test_vml_style_block_ignores_braces_in_comments() {
	node := parse_vml(vml_style_doc('\tStyle {\n\t\t// a } brace in a comment\n\t\t/* and { another } */\n\t\tButton { background: red; }\n\t}\n')) or {
		panic(err)
	}
	assert node.children[0].tag == 'Style'
}

fn test_vml_style_block_unclosed_errors() {
	// The inner rule never closes, so the document's final brace only
	// brings the Style block back to depth one.
	if _ := parse_vml(vml_style_doc('\tStyle {\n\t\tButton { background: red;\n')) {
		assert false, 'unclosed Style must fail'
	} else {
		assert err.msg().contains('unclosed `Style`')
	}
}

fn test_vml_lowercase_style_stays_prop() {
	// `style:` is the inline-declarations prop, not a block.
	node := parse_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "opacity: 0.5;"\n\t}')) or {
		panic(err)
	}
	button := node.children[0]
	assert button.tag == 'Button'
	assert button.prop('style') == 'opacity: 0.5;'
}

fn test_vml_class_prop_reaches_element() {
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tclass: "primary big"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].classes == ['primary', 'big']
}

fn test_vml_style_block_applies_by_class() {
	root := element_from_vml(vml_style_doc('\tStyle {\n\t\tButton.primary { background: #3478D4; color: white; }\n\t}\n\tButton {\n\t\tid: a\n\t\tclass: primary\n\t}\n\tButton {\n\t\tid: b\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.bg == 0x3478d4
	assert root.children[0].text_style.color == 0xffffff
	assert root.children[1].box.bg == 0xffffff
}

fn test_vml_style_scopes_to_subtree() {
	root := element_from_vml(vml_style_doc('\tView {\n\t\tid: card\n\t\tStyle {\n\t\t\tLabel { color: #ff0000; }\n\t\t}\n\t\tLabel {\n\t\t\tid: inner\n\t\t\ttext: "x"\n\t\t}\n\t}\n\tLabel {\n\t\tid: outer\n\t\ttext: "y"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].children[0].text_style.color == 0xff0000
	assert root.children[1].text_style.color == 0x111111
}

fn test_vml_style_blocks_merge_in_order() {
	root := element_from_vml(vml_style_doc('\tStyle {\n\t\tButton { background: #ff0000; }\n\t}\n\tStyle {\n\t\tButton { background: #0000ff; }\n\t}\n\tButton {\n\t\tid: b\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.bg == 0x0000ff
}

fn test_vml_style_block_variables_work() {
	root := element_from_vml(vml_style_doc('\tStyle {\n\t\t@brand: #3478D4;\n\t\tButton { background: @brand; }\n\t}\n\tButton {\n\t\tid: b\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.bg == 0x3478d4
}

fn test_vml_style_block_import_errors_clearly() {
	if _ := element_from_vml(vml_style_doc('\tStyle {\n\t\t@import "theme.vss";\n\t}\n'), rect(0, 0, 400, 300)) {
		assert false, '@import in a Style block must fail'
	} else {
		assert err.msg().contains('@import')
	}
}

fn test_vml_style_block_bad_css_errors() {
	if _ := element_from_vml(vml_style_doc('\tStyle {\n\t\tButton { background red; }\n\t}\n'), rect(0, 0, 400, 300)) {
		assert false, 'bad sheet must fail'
	} else {
		assert err.msg().contains('Style')
	}
}

fn test_vml_inline_style_applies() {
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "opacity: 0.5; border-radius: 9px;"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.opacity == 0.5
	assert root.children[0].box.radius == 9.0
}

fn test_vml_native_prop_beats_inline_style() {
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tbackground: #ff0000\n\t\tstyle: "background: #0000ff;"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.bg == 0xff0000
}

fn test_vml_inline_style_bad_decl_errors() {
	if _ := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "background: ;"\n\t}'), rect(0, 0, 400, 300)) {
		assert false, 'bad inline style must fail'
	} else {
		assert err.msg().contains('style')
	}
}

fn test_vml_inline_style_unknown_prop_is_skipped() {
	// Like a `Style` block, inline declarations warn and skip; a typo does
	// not fail the whole document.
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "frobnicate: 1; border-radius: 9px;"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.radius == 9.0
}

fn test_vml_inline_style_layout_prop_is_skipped() {
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "margin: 8px; opacity: 0.5;"\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.opacity == 0.5
}

fn test_vml_inline_style_follows_dark_mode() {
	set_stylesheet_dark(true)
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "background: light-dark(#ffffff, #101010);"\n\t}'), rect(0, 0, 400, 300)) or {
		set_stylesheet_follow_system(true)
		panic(err)
	}
	set_stylesheet_follow_system(true)
	assert root.children[0].box.bg == 0x101010
}

fn test_vml_style_block_in_adaptive_screen_is_not_a_view() {
	doc := 'Screen {\n\tid: root\n\tadaptive: true\n\twidth: 400\n\theight: 300\n\tStyle {\n\t\tButton { background: #123456; }\n\t}\n\tButton {\n\t\tid: b\n\t\ttext: "b"\n\t}\n}'
	root := element_from_vml(doc, rect(0, 0, 400, 300)) or { panic(err) }
	assert root.children.len == 1
	assert root.children[0].id == 'b'
	assert root.children[0].box.bg == 0x123456
}

fn test_vml_tree_built_in_frame_is_styled_once() {
	// Inside a backend build the VML boundary defers to the frame pass, so
	// interaction pseudos can still override base rules.
	set_global_stylesheet(parse_stylesheet('Button { background: #111111; } Button:hover { background: #222222; }') or {
		panic(err)
	})
	built := stylesheet_frame_build(fn () Element {
		return element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t}'), rect(0, 0, 400, 300)) or {
			panic(err)
		}
	})
	assert built.children[0].box.bg == 0xffffff
	hovered := stylesheet_apply_frame(built, stylesheet_frame_env('b', '', ''))
	plain := stylesheet_apply_frame(built, stylesheet_frame_env('', '', ''))
	clear_global_stylesheet()
	assert hovered.children[0].box.bg == 0x222222
	assert plain.children[0].box.bg == 0x111111
}

fn test_vml_inline_style_custom_prop_errors() {
	if _ := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tstyle: "--x: 1;"\n\t}'), rect(0, 0, 400, 300)) {
		assert false, 'inline custom props must fail'
	} else {
		assert err.msg().contains('custom properties')
	}
}

fn test_vml_style_block_keeps_layout_slots() {
	plain := element_from_vml('Screen {\n\tid: root\n\twidth: 400\n\theight: 300\n\tColumn {\n\t\tLabel {\n\t\t\tid: a\n\t\t\ttext: "a"\n\t\t}\n\t\tLabel {\n\t\t\tid: b\n\t\t\ttext: "b"\n\t\t}\n\t}\n}', rect(0, 0, 400, 300)) or {
		panic(err)
	}
	styled := element_from_vml('Screen {\n\tid: root\n\twidth: 400\n\theight: 300\n\tColumn {\n\t\tStyle {\n\t\t\tLabel { color: #ff0000; }\n\t\t}\n\t\tLabel {\n\t\t\tid: a\n\t\t\ttext: "a"\n\t\t}\n\t\tLabel {\n\t\t\tid: b\n\t\t\ttext: "b"\n\t\t}\n\t}\n}', rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert styled.children[0].children.len == 2
	assert styled.children[0].children[0].frame == plain.children[0].children[0].frame
	assert styled.children[0].children[1].frame == plain.children[0].children[1].frame
	assert styled.children[0].children[0].text_style.color == 0xff0000
}

fn test_vml_global_sheet_applies_when_set() {
	set_global_stylesheet(parse_stylesheet('Button { background: #123456; }') or { panic(err) })
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t}'), rect(0, 0, 400, 300)) or {
		clear_global_stylesheet()
		panic(err)
	}
	assert root.children[0].box.bg == 0x123456
	clear_global_stylesheet()
}

fn test_vml_unstyled_tree_unchanged() {
	root := element_from_vml(vml_style_doc('\tButton {\n\t\tid: b\n\t\tbackground: #ff0000\n\t}'), rect(0, 0, 400, 300)) or {
		panic(err)
	}
	assert root.children[0].box.bg == 0xff0000
	assert root.children[0].classes.len == 0
}
