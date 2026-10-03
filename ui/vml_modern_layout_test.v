module ui2

import math

pub struct ModernLayoutItem {
pub:
	id    int
	title string
	basis f64
	grow  f64
}

pub struct ModernLayoutProject {
pub:
	id          int
	title       string
	description string
}

pub struct ModernLayoutApp {
pub mut:
	caption  string = 'Save'
	query    string = 'initial'
	calls    int
	selected int
	created  int
	items    []ModernLayoutItem
	projects []ModernLayoutProject
}

pub fn (mut app ModernLayoutApp) select(id int) {
	app.selected = id
	app.calls++
}

pub fn (mut app ModernLayoutApp) expand_caption() {
	app.caption = 'Save every pending change'
	app.calls++
}

pub fn (mut app ModernLayoutApp) create_project() {
	app.created++
}

fn modern_layout_find(element Element, id string) ?Element {
	if element.id == id { return element }
	for child in element.children {
		if found := modern_layout_find(child, id) { return found }
	}
	return none
}

fn modern_layout_near(actual f64, expected f64) {
	assert math.abs(actual - expected) < 0.00001, '${actual} != ${expected}'
}

fn modern_layout_assert_siblings_fit(element Element) {
	for index, child in element.children {
		assert child.frame.width >= 0 && child.frame.height >= 0, child.id
		assert child.frame.x >= -0.00001 && child.frame.y >= -0.00001, child.id
		assert child.frame.x + child.frame.width <= element.frame.width + 0.00001, '${child.id}: ${child.frame} outside ${element.id}: ${element.frame}'
		assert child.frame.y + child.frame.height <= element.frame.height + 0.00001, '${child.id}: ${child.frame} outside ${element.id}: ${element.frame}'
		for other in element.children[index + 1..] {
			if child.frame.width == 0 || child.frame.height == 0 || other.frame.width == 0
				|| other.frame.height == 0 {
				continue
			}
			assert child.frame.x + child.frame.width <= other.frame.x + 0.00001
				|| other.frame.x + other.frame.width <= child.frame.x + 0.00001
				|| child.frame.y + child.frame.height <= other.frame.y + 0.00001
				|| other.frame.y + other.frame.height <= child.frame.y + 0.00001, 'overlap: ${child.id} ${child.frame} and ${other.id} ${other.frame}'
		}
	}
}

fn test_vml_flex_parent_owns_final_frame_with_explicit_preferred_dimensions() {
	source := 'FlexLayout {
		gap: 10
		Button { id: first text: "First" width: 100 height: 20 flex_grow: 1 min_width: 80 }
		Button { id: second text: "Second" width: 200 height: 20 flex_grow: 1 }
	}'
	for width in [150.0, 410.0] {
		direct := element_from_vml(source, rect(20, 30, width, 50)) or { panic(err) }
		modeled := element_from_vml_model(source, ModernLayoutApp{}, rect(20, 30, width, 50)) or { panic(err) }
		assert direct.children.map(it.frame) == modeled.children.map(it.frame)
		assert direct.children[0].frame == if width == 150 {
			rect(0, 0, 80, 50)
		} else {
			rect(0, 0, 150, 50)
		}
		assert direct.children[1].frame == if width == 150 {
			rect(90, 0, 60, 50)
		} else {
			rect(160, 0, 250, 50)
		}
		modern_layout_assert_siblings_fit(direct)
	}
}

fn test_vml_nested_flex_expressions_see_assigned_parent_size() {
	source := 'FlexLayout {
		gap: 20
		FlexLayout {
			id: content
			width: 100
			flex_grow: 1
			orientation: vertical
			Label { id: probe text: "width=" + content.width width: content.width height: 20 }
		}
		View { width: 80 flex_shrink: 0 }
	}'
	for width in [300.0, 500.0] {
		root := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, width, 100)) or { panic(err) }
		content := modern_layout_find(root, 'content') or { panic('missing content') }
		probe := modern_layout_find(root, 'probe') or { panic('missing probe') }
		assert content.frame.width == width - 100
		assert probe.frame.width == content.frame.width
		assert probe.text.starts_with('width=')
		assert probe.text.all_after('=').f64() == content.frame.width
		modern_layout_assert_siblings_fit(root)
		modern_layout_assert_siblings_fit(content)
	}
}

fn test_vml_nested_wrapping_flex_measures_height_at_assigned_width() {
	source := 'FlexLayout {
		gap: 10 align_items: start
		FlexLayout {
			id: wrapped flex_basis: 0 flex_grow: 1 wrap: true gap: 10
			Button { text: "First" width: 80 height: 30 }
			Button { text: "Second" width: 80 height: 30 }
		}
		View { flex_basis: 0 flex_grow: 1 }
	}'
	for width in [300.0, 500.0] {
		root := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, width, 200)) or { panic(err) }
		wrapped := root.children[0]
		assert wrapped.frame.width == (width - 10) / 2
		assert wrapped.frame.height == if width == 300 { 70 } else { 30 }
		modern_layout_assert_siblings_fit(wrapped)
	}
}

fn test_vml_flex_remeasures_multiline_and_width_dependent_text() {
	source := 'FlexLayout {
		gap: 10 align_items: start
		Label { id: caption flex_basis: 0 flex_grow: 1 lines: 10
			text: caption.width < 200 ? "A longer caption that needs several lines when the allocated width becomes narrow" : "Short"
		}
		View { flex_basis: 0 flex_grow: 1 }
	}'
	root := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, 300, 300)) or { panic(err) }
	caption := root.children[0]
	assert caption.frame.width == 145
	assert caption.text.starts_with('A longer')
	measured := measure_layout_text(caption.text, caption.text_style, caption.frame.width) or { panic(err) }
	assert measured.height > measure_layout_text('Short', caption.text_style, 145)!.height
	modern_layout_near(caption.frame.height, measured.height)
}

fn test_vml_vertical_flex_measures_height_after_cross_axis_maximum() {
	source := 'FlexLayout {
		orientation: vertical align_items: start
		FlexLayout { wrap: true gap: 10 max_width: 150
			Button { text: "First" width: 80 height: 30 }
			Button { text: "Second" width: 80 height: 30 }
		}
	}'
	for modeled in [false, true] {
		root := if modeled {
			element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, 500, 300))!
		} else {
			element_from_vml(source, rect(0, 0, 500, 300))!
		}
		assert root.children[0].frame == rect(0, 0, 150, 70)
		modern_layout_assert_siblings_fit(root.children[0])
	}
}

fn test_vml_intrinsic_grid_measures_rows_at_assigned_cell_width() {
	source := 'FlexLayout { orientation: vertical
		GridLayout { columns: 2 spacing: 10
			Label { text: "A caption long enough to wrap into multiple lines inside its narrow grid cell" lines: 10 }
			Label { text: "Another caption long enough to wrap into multiple lines inside its grid cell" lines: 10 }
		}
	}'
	for modeled in [false, true] {
		root := if modeled {
			element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, 300, 300))!
		} else {
			element_from_vml(source, rect(0, 0, 300, 300))!
		}
		grid := root.children[0]
		mut expected_height := 0.0
		for child in grid.children {
			assert child.frame.width == 145
			measured := measure_layout_text(child.text, child.text_style, child.frame.width)!
			expected_height = math.max(expected_height, measured.height)
		}
		modern_layout_near(grid.frame.height, expected_height)
		modern_layout_assert_siblings_fit(grid)
	}
}

fn test_vml_adaptive_screen_reflows_modern_children_after_resizing() {
	for tag in ['FlexLayout', 'GridLayout'] {
		source := 'Screen { adaptive: true width: 760 height: 520
			${tag} { id: body x: 24 y: 20 width: 712 height: 100 layout_x: stretch
				columns: 2 spacing: 10 gap: 10
				Button { text: "First" flex_basis: 0 flex_grow: 1 }
				Button { text: "Second" flex_basis: 0 flex_grow: 1 }
			}
		}'
		for width in [390.0, 1000.0] {
			direct := element_from_vml(source, rect(0, 0, width, 780)) or { panic(err) }
			modeled := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, width, 780)) or { panic(err) }
			body := modeled.children[0]
			assert body.frame.width == width - 48
			assert body.children.map(it.frame) == direct.children[0].children.map(it.frame), tag
			modern_layout_assert_siblings_fit(body)
		}
	}
}

fn test_vml_adaptive_repeater_variations_preserve_hidden_state_and_actions() {
	source := 'Screen { id: root adaptive: true width: 760 height: 520
		Repeater { model: app.items key: item.id
			FlexLayout { x: 24 y: index * 120 width: 712 height: 100 layout_x: stretch
				LayoutVariation { width_class: compact reference_width: 390 reference_height: 780
					x: 10 y: index * 110 width: 370 height: 100 layout_x: stretch hidden: index == 1 }
				Button { text: item.title flex_basis: 0 flex_grow: 1 on_tap: app.select(item.id) }
				Label { text: root.width flex_basis: 0 flex_grow: 1 }
			}
		}
	}'
	mut app := new_vml_app(source, ModernLayoutApp{
		items: [
			ModernLayoutItem{ id: 7, title: 'First' },
			ModernLayoutItem{ id: 9, title: 'Second' },
		]
	}) or { panic(err) }
	root := app.build(rect(0, 0, 390, 780)) or { panic(err) }
	assert root.children.len == 2
	assert root.children[0].frame == rect(10, 0, 370, 100)
	assert root.children[1].frame == rect(10, 110, 370, 100)
	assert !root.children[0].hidden
	assert root.children[1].hidden
	assert root.children[0].children[0].frame.width == 185
	assert root.children[0].children[1].text.f64() == 390
	assert app.events.len == 2
	app.handle(root.children[0].children[0].action_id) or { panic(err) }
	assert app.state().selected == 7
	assert app.state().calls == 1
	if _ := element_from_vml_model('Screen { adaptive: true width: 0 height: 520 }',
		ModernLayoutApp{}, rect(0, 0, 390, 780)) {
		assert false, 'invalid empty adaptive screens must still fail'
	}
}

fn test_vml_flex_wrap_uses_intrinsic_text_sizes_without_window() {
	source := 'FlexLayout {
		wrap: true gap: 9 align_items: start
		Button { id: first text: "Publish changes" }
		Button { id: second text: "Publish changes" }
	}'
	wide := element_from_vml(source, rect(0, 0, 1000, 200)) or { panic(err) }
	first := wide.children[0]
	assert first.frame.width > 30
	assert first.frame.height > 12
	assert wide.children[1].frame.y == 0
	modern_layout_near(wide.children[1].frame.x, first.frame.width + 9)
	narrow_width := first.frame.width + 1
	narrow := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, narrow_width, 200)) or { panic(err) }
	modern_layout_near(narrow.children[0].frame.width, first.frame.width)
	assert narrow.children[1].frame.x == 0
	modern_layout_near(narrow.children[1].frame.y, first.frame.height + 9)
	modern_layout_assert_siblings_fit(narrow)
}

fn test_vml_flex_repeater_resolves_weights_and_preserves_keyed_actions() {
	source := 'FlexLayout {
		gap: 10
		Repeater {
			model: app.items
			key: item.id
			Button { text: item.title flex_basis: item.basis flex_grow: item.grow on_tap: app.select(item.id) }
		}
	}'
	model := ModernLayoutApp{
		items: [
			ModernLayoutItem{ id: 7, title: 'First', basis: 40, grow: 1 },
			ModernLayoutItem{ id: 9, title: 'Second', basis: 80, grow: 3 },
		]
	}
	root := element_from_vml_model(source, model, rect(0, 0, 300, 50)) or { panic(err) }
	assert root.children[0].frame == rect(0, 0, 82.5, 50)
	assert root.children[1].frame == rect(92.5, 0, 207.5, 50)
	assert root.children.map(it.key) == ['7', '9']
	assert root.children[0].action_id != root.children[1].action_id
	reordered := element_from_vml_model(source, ModernLayoutApp{ items: model.items.reverse() },
		rect(0, 0, 300, 50)) or { panic(err) }
	assert reordered.children[0].key == '9'
	assert reordered.children[0].action_id == root.children[1].action_id
	assert reordered.children[1].action_id == root.children[0].action_id
	mut app := new_vml_app(source, model) or { panic(err) }
	for width in [300.0, 500.0, 150.0] {
		built := app.build(rect(0, 0, width, 50)) or { panic(err) }
		assert built.children.map(it.action_id) == root.children.map(it.action_id)
		assert app.state().calls == 0
		assert app.events.len == 2
		modern_layout_assert_siblings_fit(built)
	}
	app.handle(root.children[1].action_id) or { panic(err) }
	assert app.state().selected == 9
	assert app.state().calls == 1
}

fn modern_layout_control_text(_ string) string {
	return 'edited'
}

fn test_vml_flex_measurement_preserves_binding_and_never_invokes_action() {
	source := 'FlexLayout {
		gap: 12 align_items: center
		Button { id: save text: app.caption on_tap: app.expand_caption() }
		TextField { id: query bind.text: app.query flex_grow: 1 }
	}'
	mut app := new_vml_app(source, ModernLayoutApp{}) or { panic(err) }
	app.control_text = modern_layout_control_text
	first := app.build(rect(0, 0, 700, 80)) or { panic(err) }
	assert app.state().calls == 0
	assert app.state().query == 'initial'
	assert app.events.len == 2
	assert first.children[0].frame.width > 24
	assert first.children[1].text == 'initial'
	app.handle(first.children[1].action_id) or { panic(err) }
	assert app.state().query == 'edited'
	app.handle(first.children[0].action_id) or { panic(err) }
	second := app.build(rect(0, 0, 700, 80)) or { panic(err) }
	assert app.state().calls == 1
	assert second.children[0].frame.width > first.children[0].frame.width
	assert second.children[1].frame.width < first.children[1].frame.width
	assert second.children[0].action_id == first.children[0].action_id
	assert second.children[1].action_id == first.children[1].action_id
	assert second.children[1].text == 'edited'
	modern_layout_assert_siblings_fit(second)
}

fn test_vml_grid_auto_columns_spans_nested_flex_and_metadata_resize_together() {
	source := 'GridLayout {
		auto_columns_min_width: 180 max_columns: 3 spacing: 10
		LayoutVariation { width_class: compact width: 20 height: 20 }
		FlexLayout {
			id: featured column_span: 2 row_span: 2 gap: 10 width: 1 height: 1
			Button { id: left text: "Left" width: 60 flex_grow: 1 }
			LayoutVariation { width_class: compact width: 20 height: 20 }
			Button { id: right text: "Right" width: 60 flex_grow: 1 }
		}
		Button { id: second text: "Second" width: 1 height: 1 }
		Button { id: third text: "Third" width: 1 height: 1 }
	}'
	for width in [620.0, 250.0] {
		direct := element_from_vml(source, rect(0, 0, width, 300)) or { panic(err) }
		modeled := element_from_vml_model(source, ModernLayoutApp{}, rect(0, 0, width, 300)) or { panic(err) }
		assert direct.children.len == 3
		assert modeled.children.len == 3
		assert direct.children.map(it.frame) == modeled.children.map(it.frame)
		featured := direct.children[0]
		assert featured.children.len == 2
		assert featured.frame.width == if width == 620 { 410 } else { 250 }
		assert direct.children[1].frame.x == if width == 620 { 420 } else { 0 }
		assert direct.children[1].frame.width == if width == 620 { 200 } else { 250 }
		modern_layout_near(featured.children[0].frame.width, (featured.frame.width - 10) / 2)
		modern_layout_assert_siblings_fit(direct)
		modern_layout_assert_siblings_fit(featured)
		modern_layout_assert_siblings_fit(modeled.children[0])
	}
}

fn test_responsive_example_fits_wide_and_compact_windows_and_keeps_actions() {
	source := $embed_file('../examples/responsive_layout/responsive_layout.vml').to_string()
	model := ModernLayoutApp{
		projects: [
			ModernLayoutProject{ id: 1, title: 'Design system', description: 'Shared controls and typography' },
			ModernLayoutProject{ id: 2, title: 'Desktop app', description: 'One layout across window sizes' },
		]
	}
	mut app := new_vml_app(source, model) or { panic(err) }
	mut action_id := ''
	for width in [1000.0, 390.0, 1000.0] {
		root := app.build(rect(0, 0, width, 780)) or { panic(err) }
		validate_element_tree(root) or { panic(err) }
		page := modern_layout_find(root, 'page') or { panic('missing page') }
		projects := modern_layout_find(root, 'projects') or { panic('missing projects') }
		toolbar := modern_layout_find(root, 'toolbar') or { panic('missing toolbar') }
		searchbar := modern_layout_find(root, 'searchbar') or { panic('missing searchbar') }
		create := modern_layout_find(root, 'create') or { panic('missing action') }
		assert page.frame.width == width
		assert projects.frame.width == width - 48
		assert projects.children.len == 3
		assert projects.children[1].key == '1'
		assert projects.children[2].key == '2'
		if width == 390 {
			assert projects.children.all(it.frame.x == 0)
			assert projects.children.all(it.frame.width == projects.frame.width)
			assert projects.children[1].frame.y > projects.children[0].frame.y
		} else {
			assert projects.children[0].frame.width > projects.children[1].frame.width
		}
		for container in [page, toolbar, searchbar, projects] {
			modern_layout_assert_siblings_fit(container)
		}
		for card in projects.children {
			modern_layout_assert_siblings_fit(card)
		}
		if action_id.len > 0 {
			assert create.action_id == action_id
		}
		action_id = create.action_id
		assert app.state().created == 0
	}
	app.handle(action_id) or { panic(err) }
	assert app.state().created == 1
}
