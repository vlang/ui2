module ui2

import math

fn bars_assert_inside(el Element) {
	component_validate_frame(el.frame) or { panic(err) }
	for child in el.children {
		assert child.frame.x >= -1e-9 && child.frame.y >= -1e-9, 'child at ${child.frame} leaves ${el.frame}'
		assert child.frame.x + child.frame.width <= el.frame.width + 1e-9, 'child ${child.frame} wider than ${el.frame}'
		assert child.frame.y + child.frame.height <= el.frame.height + 1e-9, 'child ${child.frame} taller than ${el.frame}'
		bars_assert_inside(child)
	}
}

// bars_buttons collects the elements that answer a click, in tree order.
fn bars_buttons(el Element) []Element {
	mut found := []Element{}
	if el.button_behavior {
		found << el
	}
	for child in el.children {
		found << bars_buttons(child)
	}
	return found
}

fn bars_texts(el Element) []string {
	mut found := []string{}
	if el.kind == .label {
		found << el.text
	}
	for child in el.children {
		found << bars_texts(child)
	}
	return found
}

fn bars_find_key(el Element, key string) ?Element {
	for child in el.children {
		if child.key == key {
			return child
		}
		if found := bars_find_key(child, key) {
			return found
		}
	}
	return none
}

fn bars_editor_items() []BarItem {
	return [
		bar_command('new', 'New', 'plus'),
		bar_separator(),
		toolbar_group('history', 'History', [
			bar_icon_command('undo', 'arrow.uturn.backward', 'Undo'),
			bar_icon_command('redo', 'arrow.uturn.forward', 'Redo'),
		]),
		bar_separator(),
		BarItem{
			...bar_icon_command('bold', 'textformat', 'Bold')
			selected: true
		},
		BarItem{
			...bar_icon_command('italic', 'textformat.abc', 'Italic')
			enabled: false
		},
		bar_spacer(),
		bar_label('Saved'),
		bar_icon_command('more', 'ellipsis', 'More options'),
	]
}

fn bars_editor_toolbar() ToolbarConfig {
	return ToolbarConfig{
		id:    'editor'
		frame: rect(10, 20, 600, 32)
		items: bars_editor_items()
		label: 'Editor'
	}
}

// ── Shared ──────────────────────────────────────────────────────────

fn test_bar_metrics_follow_the_upstream_sizes() {
	assert bar_metrics(.toolbar, .small).height == 28
	assert bar_metrics(.toolbar, .medium).height == 32
	assert bar_metrics(.toolbar, .large).height == 48
	assert bar_metrics(.title_bar, .medium).height == 34
	for kind in [BarKind.toolbar, .status_bar, .title_bar] {
		small := bar_metrics(kind, .small)
		medium := bar_metrics(kind, .medium)
		large := bar_metrics(kind, .large)
		assert small.height < medium.height && medium.height < large.height
		for m in [small, medium, large] {
			assert m.control < m.height
			assert m.icon <= m.control
		}
	}
	assert bar_metrics(.title_bar, .medium).window_button > bar_metrics(.title_bar, .medium).height
}

fn test_bar_item_constructors() {
	command := bar_command('save', 'Save', 'square.and.arrow.down')
	assert command.kind == .command && command.label == 'Save' && command.enabled
	icon := bar_icon_command('find', 'magnifyingglass', 'Find')
	assert icon.label == '' && icon.tooltip == 'Find'
	assert bar_label('Ready').kind == .label
	assert bar_separator().kind == .separator
	assert bar_spacer().kind == .spacer
	custom := bar_custom('search', 180, []Element{})
	assert custom.kind == .custom && custom.width == 180
	group := toolbar_group('g', 'History', [icon])
	assert group.kind == .group && group.items.len == 1
	assert bar_item_action('bar', 'save') == 'bar:component:item:' + 'save'.bytes().hex()
	for item in bars_flatten(bars_editor_items()) {
		if item.icon.len > 0 {
			assert symbol_known(item.icon), item.icon
		}
	}
}

fn test_bars_pack_spacers_and_overflow() {
	m := bar_metrics(.toolbar, .medium)
	items := [bar_icon_command('a', 'plus', 'A'), bar_spacer(), bar_icon_command('b', 'minus', 'B')]
	placements := bars_pack(items, 4, 192, m, false)
	assert placements.all(it.shown)
	assert placements[0].offset == 4
	// The spacer pushes the last command against the far end.
	assert placements[2].offset + placements[2].extent == 196
	// Too little room: items go from the end, never overlapping.
	tight := bars_pack(items, 0, m.control * 1.5, m, false)
	assert tight[0].shown && !tight[2].shown
	end := bars_pack_end(items, 100, m.control * 1.5, m, false)
	assert end[2].shown && !end[0].shown
	assert end[2].offset + end[2].extent == 100
	// Offsets are whole points.
	for placement in bars_pack([bar_label('Unaligned text'), bar_label('More')], 0.3, 400,
		m, false) {
		assert placement.offset == f64(int(placement.offset))
	}
}

fn test_bar_validation_rejects_bad_items() {
	frame := rect(0, 0, 300, 32)
	if _ := toolbar(ToolbarConfig{ frame: frame, items: [bar_command('a', 'A', '')] }) {
		assert false, 'toolbar without id accepted'
	}
	if _ := toolbar(ToolbarConfig{ id: 't', frame: frame, items: [bar_command('', 'A', '')] }) {
		assert false, 'command without id accepted'
	}
	if _ := toolbar(ToolbarConfig{
		id:    't'
		frame: frame
		items: [bar_command('a', 'A', ''), toolbar_group('g', 'G', [
			bar_command('a', 'Again', ''),
		])]
	})
	{
		assert false, 'duplicate id across a group accepted'
	}
	if _ := toolbar(ToolbarConfig{
		id:    't'
		frame: frame
		items: [toolbar_group('g', 'G', [toolbar_group('h', 'H', [])])]
	})
	{
		assert false, 'nested group accepted'
	}
	if _ := toolbar(ToolbarConfig{
		id:    't'
		frame: frame
		items: [bar_custom('c', -1, [])]
	})
	{
		assert false, 'negative custom width accepted'
	}
	if _ := toolbar(ToolbarConfig{ id: 't', frame: rect(0, 0, -1, 32) }) {
		assert false, 'negative frame accepted'
	}
	// A status bar of labels needs no id; one with a command does.
	status_bar(StatusBarConfig{ frame: frame, leading: [bar_label('Ready')] }) or { panic(err) }
	if _ := status_bar(StatusBarConfig{
		frame:    frame
		trailing: [bar_command('ln', 'Ln 1', '')]
	})
	{
		assert false, 'status bar command without bar id accepted'
	}
	if _ := title_bar(TitleBarConfig{
		id:      'title'
		frame:   frame
		leading: [bar_command('window:close', 'X', '')]
	})
	{
		assert false, 'reserved title bar item id accepted'
	}
}

// ── Toolbar ─────────────────────────────────────────────────────────

fn test_toolbar_draws_commands_groups_and_states() {
	config := bars_editor_toolbar()
	el := toolbar(config) or { panic(err) }
	bars_assert_inside(el)
	assert el.accessibility_role == 'toolbar'
	assert el.accessibility_label == 'Editor'
	assert el.frame == config.frame
	buttons := bars_buttons(el)
	assert buttons.map(it.accessibility_label) == ['New', 'Undo', 'Redo', 'Bold', 'Italic',
		'More options']
	assert buttons.all(it.hoverable)
	assert buttons[0].action_id == bar_item_action('editor', 'new')
	assert buttons[3].accessibility_value == 'selected'
	assert !buttons[4].enabled
	assert buttons[5].tooltip == 'More options'
	group := bars_find_key(el, 'group:history') or { panic('group missing') }
	assert group.accessibility_role == 'group'
	assert group.accessibility_label == 'History'
	assert group.children.len == 2
	assert 'Saved' in bars_texts(el)
	assert 'New' in bars_texts(el)
	separators := el.children.filter(it.accessibility_role == 'separator')
	assert separators.len == 2
	// The more button sits against the trailing padding.
	more := toolbar_item_frame(config, 'more') or { panic('more missing') }
	assert more.x + more.width == config.frame.x + config.frame.width - bar_metrics(.toolbar,
		.medium).padding
	// Group members report frames in the toolbar's parent coordinates.
	redo := toolbar_item_frame(config, 'redo') or { panic('redo missing') }
	undo := toolbar_item_frame(config, 'undo') or { panic('undo missing') }
	assert redo.x > undo.x + undo.width - 1e-9
	assert redo.y == config.frame.y + (32 - 24) / 2
	assert toolbar_overflow(config).len == 0
	if _ := toolbar_item_frame(config, 'nothing') {
		assert false
	}
}

fn test_toolbar_hover_focus_and_style() {
	config := ToolbarConfig{
		...bars_editor_toolbar()
		hovered: 'new'
		focused: 'bold'
		style:   BarStyle{
			background: u32(0xeeeeee)
			edges:      .all
			radius:     8
		}
	}
	el := toolbar(config) or { panic(err) }
	bars_assert_inside(el)
	buttons := bars_buttons(el)
	// Hover adds a translucent overlay; focus a ring under it.
	assert buttons[0].children.any(it.kind == .view && it.box.opacity < 1)
	assert buttons[3].children.any(it.kind == .view && it.box.bg == config.theme.primary)
	assert !buttons[5].children.any(it.kind == .view && it.box.bg == config.theme.primary)
	// A rounded border is a border-colored shape under an inset fill.
	assert el.children[0].box.bg == bars_divider(config.theme)
	assert el.children[1].box.bg == 0xeeeeee
	assert el.children[1].frame == rect(1, 1, config.frame.width - 2, config.frame.height - 2)
	plain := toolbar(bars_editor_toolbar()) or { panic(err) }
	// Transparent and borderless by default: the first child is an item.
	assert plain.children[0].key == 'item:new'
}

fn test_toolbar_overflow_and_vertical_layout() {
	narrow := ToolbarConfig{
		...bars_editor_toolbar()
		frame: rect(0, 0, 150, 32)
	}
	el := toolbar(narrow) or { panic(err) }
	bars_assert_inside(el)
	hidden := toolbar_overflow(narrow)
	assert hidden.len > 0
	assert hidden.last() == 'more'
	for id in hidden {
		if _ := toolbar_item_frame(narrow, id) {
			assert false, '${id} is hidden but has a frame'
		}
	}
	assert 'more' !in toolbar_focus_order(narrow)
	vertical := ToolbarConfig{
		id:          'tools'
		frame:       rect(0, 0, 40, 300)
		orientation: .vertical
		items:       [bar_icon_command('select', 'cursorarrow', 'Select'), bar_separator(),
			bar_icon_command('crop', 'crop', 'Crop'), bar_spacer(),
			bar_icon_command('settings', 'gearshape', 'Settings')]
	}
	tools := toolbar(vertical) or { panic(err) }
	bars_assert_inside(tools)
	arrow_tool := toolbar_item_frame(vertical, 'select') or { panic('none') }
	crop := toolbar_item_frame(vertical, 'crop') or { panic('none') }
	settings := toolbar_item_frame(vertical, 'settings') or { panic('none') }
	assert arrow_tool.x == crop.x && arrow_tool.width == 24
	assert crop.y > arrow_tool.y + arrow_tool.height
	assert settings.y + settings.height == 300 - bar_metrics(.toolbar, .medium).padding
	line := tools.children.filter(it.accessibility_role == 'separator')[0].children[0]
	assert line.frame.height == 1 && line.frame.width > 1
}

fn test_toolbar_decoders_reject_foreign_forged_and_disabled_actions() {
	config := bars_editor_toolbar()
	item := toolbar_item_from_action(config, bar_item_action('editor', 'bold')) or {
		panic('bold not decoded')
	}
	assert item.id == 'bold' && item.selected
	redo := toolbar_item_from_action(config, bar_item_action('editor', 'redo')) or {
		panic('group member not decoded')
	}
	assert redo.id == 'redo'
	for action in [bar_item_action('editor', 'italic'), bar_item_action('other', 'bold'),
		bar_item_action('editor', 'nothing'), 'editor:component:item:zz', 'editor:component:item:',
		'', 'bold'] {
		if got := toolbar_item_from_action(config, action) {
			assert false, 'decoded ${action} as ${got.id}'
		}
	}
	disabled := ToolbarConfig{
		...config
		enabled: false
	}
	if _ := toolbar_item_from_action(disabled, bar_item_action('editor', 'new')) {
		assert false, 'disabled toolbar answered'
	}
	custom := ToolbarConfig{
		...config
		items: [BarItem{
			...bar_command('open', 'Open', 'folder')
			action_id: 'open-file'
		}]
	}
	assert (toolbar_item_from_action(custom, 'open-file') or { panic('none') }).id == 'open'
	if _ := toolbar_item_from_action(custom, bar_item_action('editor', 'open')) {
		assert false, 'replaced action still answered'
	}
}

fn test_toolbar_hover_from_event() {
	config := bars_editor_toolbar()
	action := bar_item_action('editor', 'new')
	assert (toolbar_hover_from_event(config, 'pointer:enter:${action}:3:4') or { 'none' }) == 'new'
	hovered := ToolbarConfig{
		...config
		hovered: 'new'
	}
	if _ := toolbar_hover_from_event(hovered, 'pointer:enter:${action}:3:4') {
		assert false, 'unchanged hover reported'
	}
	assert (toolbar_hover_from_event(hovered, 'pointer:leave:${action}:3:4') or { 'none' }) == ''
	// Leaving something that is not hovered changes nothing.
	redo := bar_item_action('editor', 'redo')
	if _ := toolbar_hover_from_event(hovered, 'pointer:leave:${redo}:0:0') {
		assert false
	}
	for event in ['pointer:down:${action}:1:1', action, 'pointer:enter:other:1:1'] {
		if _ := toolbar_hover_from_event(config, event) {
			assert false, event
		}
	}
}

fn test_toolbar_key_roves_focus() {
	base := bars_editor_toolbar()
	key := fn (code KeyCode) KeyEvent {
		return KeyEvent{
			code: code
		}
	}
	assert toolbar_focus_order(base) == ['new', 'undo', 'redo', 'bold', 'more']
	// Unfocused, the toolbar leaves keys alone.
	if _ := toolbar_key(base, key(.right)) {
		assert false
	}
	at := fn [base] (id string) ToolbarConfig {
		return ToolbarConfig{
			...base
			focused: id
		}
	}
	assert (toolbar_key(at('new'), key(.right)) or { panic('none') }).focused == 'undo'
	assert (toolbar_key(at('bold'), key(.right)) or { panic('none') }).focused == 'more'
	assert (toolbar_key(at('more'), key(.right)) or { panic('none') }).focused == 'new'
	assert (toolbar_key(at('new'), key(.left)) or { panic('none') }).focused == 'more'
	assert (toolbar_key(at('redo'), key(.home)) or { panic('none') }).focused == 'new'
	assert (toolbar_key(at('redo'), key(.end)) or { panic('none') }).focused == 'more'
	// A horizontal toolbar leaves Up and Down alone, and modified keys.
	if _ := toolbar_key(at('new'), key(.down)) {
		assert false
	}
	if _ := toolbar_key(at('new'), KeyEvent{ code: .right, cmd: true }) {
		assert false
	}
	if _ := toolbar_key(at('new'), key(.home)) {
		assert false, 'a move to where focus already is reported'
	}
	step := toolbar_key(at('bold'), key(.enter)) or { panic('none') }
	assert step.activated && step.item.id == 'bold' && step.focused == 'bold'
	assert (toolbar_key(at('bold'), key(.space)) or { panic('none') }).activated
	left := toolbar_key(at('bold'), key(.escape)) or { panic('none') }
	assert left.focused == '' && !left.activated
	// Focus on something that went away re-enters at an end.
	assert (toolbar_key(at('italic'), key(.right)) or { panic('none') }).focused == 'new'
	vertical := ToolbarConfig{
		...at('undo')
		orientation: .vertical
		frame:       rect(0, 0, 40, 400)
	}
	assert (toolbar_key(vertical, key(.down)) or { panic('none') }).focused == 'redo'
	assert (toolbar_key(vertical, key(.up)) or { panic('none') }).focused == 'new'
	if _ := toolbar_key(vertical, key(.right)) {
		assert false
	}
	disabled := ToolbarConfig{
		...at('new')
		enabled: false
	}
	assert toolbar_focus_order(disabled).len == 0
	if _ := toolbar_key(disabled, key(.right)) {
		assert false
	}
}

// ── Status bar ──────────────────────────────────────────────────────

fn bars_status(leading []BarItem, center []BarItem, trailing []BarItem) StatusBarConfig {
	return StatusBarConfig{
		id:       'status'
		frame:    rect(0, 500, 800, 28)
		leading:  leading
		center:   center
		trailing: trailing
	}
}

fn test_status_bar_regions_and_center_alignment() {
	branch := bar_command('branch', 'main', 'arrow.triangle.2.circlepath')
	position := BarItem{
		...bar_command('position', 'Ln 1, Col 1', '')
		tooltip: 'Go to Line/Column'
	}
	file := BarItem{
		...bar_label('README.md')
		id: 'file'
	}
	both := bars_status([branch], [file], [position])
	el := status_bar(both) or { panic(err) }
	bars_assert_inside(el)
	assert el.accessibility_role == 'status'
	assert el.accessibility_label == 'Status'
	// A top divider and a fill by default.
	assert el.children.any(it.frame == rect(0, 0, 800, 1))
	branch_frame := status_bar_item_frame(both, 'branch') or { panic('none') }
	position_frame := status_bar_item_frame(both, 'position') or { panic('none') }
	m := bar_metrics(.status_bar, .medium)
	assert branch_frame.x == m.padding
	assert position_frame.x + position_frame.width == 800 - m.padding
	assert branch_frame.y == 500 + (28 - m.control) / 2
	center := status_bar_item_frame(both, 'file') or { panic('none') }
	low := branch_frame.x + branch_frame.width + m.gap
	high := position_frame.x - m.gap
	// Centered in the room between the ends.
	assert center.x - low - (high - (center.x + center.width)) <= 1
	assert center.x - low - (high - (center.x + center.width)) >= -1
	only_leading := bars_status([branch], [file], [])
	end := status_bar_item_frame(only_leading, 'file') or { panic('none') }
	assert end.x + end.width == 800 - m.padding
	only_trailing := bars_status([], [file], [position])
	start := status_bar_item_frame(only_trailing, 'file') or { panic('none') }
	assert start.x == m.padding
	neither := bars_status([], [file], [])
	plain := status_bar_item_frame(neither, 'file') or { panic('none') }
	assert plain.x == m.padding
	// Commands decode; labels do not answer.
	got := status_bar_item_from_action(both, bar_item_action('status', 'position')) or {
		panic('none')
	}
	assert got.id == 'position'
	if _ := status_bar_item_from_action(both, bar_item_action('status', 'file')) {
		assert false, 'a label answered'
	}
	hover := status_bar_hover_from_event(both, 'pointer:enter:${bar_item_action('status', 'branch')}:1:1') or { panic('none') }
	assert hover == 'branch'
}

fn test_status_bar_drops_the_innermost_items_when_narrow() {
	config := StatusBarConfig{
		...bars_status([bar_command('a', 'Alpha', ''), bar_command('b', 'Beta', '')], [
			bar_label('Center'),
		], [bar_command('c', 'Gamma', ''), bar_command('d', 'Delta', '')])
		frame: rect(0, 0, 260, 28)
	}
	el := status_bar(config) or { panic(err) }
	bars_assert_inside(el)
	hidden := status_bar_overflow(config)
	assert 'a' !in hidden
	assert 'd' !in hidden
	assert 'c' in hidden || 'b' in hidden
	// Keys stay unique when regions hold items of the same kind.
	keys := el.children.map(it.key).filter(it.len > 0)
	mut seen := map[string]bool{}
	for k in keys {
		assert k !in seen
		seen[k] = true
	}
}

// ── Title bar ───────────────────────────────────────────────────────

fn bars_title(window TitleBarWindow) TitleBarConfig {
	return TitleBarConfig{
		id:       'title'
		frame:    rect(0, 0, 900, 34)
		title:    'Untitled.v'
		leading:  [BarItem{
			...bar_command('file', 'File', '')
			dropdown: true
		}]
		trailing: [bar_icon_command('settings', 'gearshape', 'Settings')]
		window:   window
	}
}

fn test_title_bar_layout_inset_title_and_window_buttons() {
	config := bars_title(TitleBarWindow{
		leading_inset: 78
	})
	el := title_bar(config) or { panic(err) }
	bars_assert_inside(el)
	// The bar is the drag region.
	assert el.clickable
	assert el.action_id == title_bar_drag_action('title')
	assert el.accessibility_label == 'Untitled.v'
	file := title_bar_item_frame(config, 'file') or { panic('none') }
	assert file.x == 78
	// The title is centered on the whole bar, not on the room the ends leave.
	title := bars_find_key(el, 'title') or { panic('title missing') }
	assert title.text_style.align == .center
	assert title.frame.x + title.frame.width / 2 == 450
	assert title.frame.x >= file.x + file.width
	// No window buttons unless the window asks for them.
	assert bars_buttons(el).map(it.accessibility_label) == ['File', 'Settings']
	settings := title_bar_item_frame(config, 'settings') or { panic('none') }
	m := bar_metrics(.title_bar, .medium)
	assert settings.x + settings.width == 900 - m.padding
	drawn := bars_title(TitleBarWindow{
		controls:  true
		maximized: true
	})
	with_buttons := title_bar(drawn) or { panic('none') }
	bars_assert_inside(with_buttons)
	labels := bars_buttons(with_buttons).map(it.accessibility_label)
	assert labels == ['File', 'Settings', 'Minimize', 'Restore', 'Close']
	close := bars_find_key(with_buttons, 'window:close') or { panic('none') }
	assert close.frame.x + close.frame.width == 900
	assert close.frame.height == 34 && close.frame.width == m.window_button
	assert close.action_id == title_bar_button_action('title', .close)
	moved := title_bar_item_frame(drawn, 'settings') or { panic('none') }
	assert moved.x + moved.width == 900 - 3 * m.window_button - m.gap
	first := title_bar_item_frame(drawn, 'file') or { panic('none') }
	assert first.x == m.padding
	only_close := bars_title(TitleBarWindow{
		controls:    true
		minimizable: false
		maximizable: false
	})
	assert bars_buttons(title_bar(only_close) or { panic('none') }).map(it.accessibility_label).last() == 'Close'
	assert bars_buttons(title_bar(only_close) or { panic(err) }).len == 3
}

fn test_title_bar_glyphs_are_crisp_lines() {
	maximize := title_bar_glyph(.maximize, false, 46, 34, 10, 0x111111)
	assert maximize.len == 4
	restore := title_bar_glyph(.maximize, true, 46, 34, 10, 0x111111)
	assert restore.len == 6
	for line in maximize {
		assert line.frame.width == 1 || line.frame.height == 1
		assert line.frame.x == f64(int(line.frame.x)) && line.frame.y == f64(int(line.frame.y))
	}
	minimize := title_bar_glyph(.minimize, false, 46, 34, 10, 0x111111)
	assert minimize.len == 1 && minimize[0].frame.height == 1
	close := title_bar_glyph(.close, false, 46, 34, 10, 0x111111)
	assert close[0].image_path == 'symbol:xmark'
	assert symbol_known('xmark')
}

fn test_title_bar_center_items_follow_the_title() {
	config := TitleBarConfig{
		...bars_title(TitleBarWindow{})
		center: [bar_custom('search', 200, [])]
	}
	el := title_bar(config) or { panic(err) }
	bars_assert_inside(el)
	assert 'Untitled.v' in bars_texts(el)
	search := title_bar_item_frame(config, 'search') or { panic('none') }
	assert search.width == 200
	if _ := bars_find_key(el, 'title') {
		assert false, 'title drawn twice'
	}
}

fn test_title_bar_events_drag_double_click_and_buttons() {
	config := bars_title(TitleBarWindow{
		controls: true
	})
	down := 'pointer:down:${title_bar_drag_action('title')}:200:10'
	first := title_bar_event(config, down, TitleBarClick{}, 1000) or { panic('none') }
	assert first.kind == .drag
	assert first.click.count == 1 && first.click.x == 200
	second := title_bar_event(config, 'pointer:down:${title_bar_drag_action('title')}:202:11',
		first.click, 1300) or { panic('none') }
	assert second.kind == .toggle_maximize
	// A third press starts over rather than toggling back.
	third := title_bar_event(config, down, second.click, 1450) or { panic('none') }
	assert third.kind == .drag
	slow := title_bar_event(config, down, first.click, 1000 + title_bar_double_click_interval + 1) or {
		panic('none')
	}
	assert slow.kind == .drag
	far := title_bar_event(config, 'pointer:down:${title_bar_drag_action('title')}:260:10',
		first.click, 1100) or { panic('none') }
	assert far.kind == .drag
	assert !title_bar_is_double_click(TitleBarClick{}, TitleBarClick{ count: 1 })
	// A window that cannot maximize does not on a double click.
	fixed := TitleBarConfig{
		...config
		window: TitleBarWindow{
			maximizable: false
		}
	}
	assert (title_bar_event(fixed, down, first.click, 1100) or { panic('none') }).kind == .drag
	for phase in ['up', 'drag', 'enter'] {
		if _ := title_bar_event(config, 'pointer:${phase}:${title_bar_drag_action('title')}:1:1',
			TitleBarClick{}, 0)
		{
			assert false, phase
		}
	}
	assert (title_bar_event(config, title_bar_button_action('title', .minimize), TitleBarClick{},
		0) or { panic('none') }).kind == .minimize
	assert (title_bar_event(config, title_bar_button_action('title', .maximize), TitleBarClick{},
		0) or { panic('none') }).kind == .toggle_maximize
	assert (title_bar_event(config, title_bar_button_action('title', .close), TitleBarClick{},
		0) or { panic('none') }).kind == .close
	// Window buttons the bar does not draw cannot be forged.
	plain := bars_title(TitleBarWindow{})
	if _ := title_bar_event(plain, title_bar_button_action('title', .close), TitleBarClick{}, 0) {
		assert false, 'undrawn close button answered'
	}
	command := title_bar_event(config, bar_item_action('title', 'settings'), TitleBarClick{},
		0) or { panic('none') }
	assert command.kind == .command && command.item.id == 'settings'
	disabled := TitleBarConfig{
		...config
		enabled: false
	}
	if _ := title_bar_event(disabled, bar_item_action('title', 'settings'), TitleBarClick{}, 0) {
		assert false, 'disabled command answered'
	}
	// Dragging and the window buttons keep working on a disabled bar.
	assert (title_bar_event(disabled, down, TitleBarClick{}, 0) or { panic('none') }).kind == .drag
	assert (title_bar_event(disabled, title_bar_button_action('title', .close), TitleBarClick{},
		0) or { panic('none') }).kind == .close
	if _ := title_bar_event(config, 'unrelated', TitleBarClick{}, 0) {
		assert false
	}
}

fn test_title_bar_hover_covers_window_buttons() {
	config := bars_title(TitleBarWindow{
		controls: true
	})
	close := title_bar_button_action('title', .close)
	hovered := title_bar_hover_from_event(config, 'pointer:enter:${close}:880:10') or {
		panic('none')
	}
	assert hovered == 'window:close'
	over := TitleBarConfig{
		...config
		hovered: hovered
	}
	el := title_bar(over) or { panic('none') }
	button := bars_find_key(el, 'window:close') or { panic('none') }
	assert button.children[0].box.bg == config.theme.danger
	assert (title_bar_hover_from_event(over, 'pointer:leave:${close}:880:10') or { 'none' }) == ''
	settings := bar_item_action('title', 'settings')
	assert (title_bar_hover_from_event(config, 'pointer:enter:${settings}:1:1') or { 'none' }) == 'settings'
	plain := bars_title(TitleBarWindow{})
	if _ := title_bar_hover_from_event(plain, 'pointer:enter:${close}:880:10') {
		assert false, 'hover on an undrawn button'
	}
}

fn test_title_bar_window_without_hidden_chrome_is_plain() {
	window := title_bar_window(false)
	assert window.leading_inset == 0
	assert !window.controls
	assert !window.maximized
	assert window.minimizable && window.maximizable
}

fn test_bars_in_dark_theme_and_tiny_frames() {
	dark := component_theme(true)
	for size in [ComponentSize.small, .medium, .large] {
		for frame in [rect(0, 0, 0, 0), rect(0, 0, 30, 10), rect(0, 0, 640, 48)] {
			bars_assert_inside(toolbar(ToolbarConfig{
				...bars_editor_toolbar()
				frame: frame
				size:  size
				theme: dark
			}) or { panic(err) })
			bars_assert_inside(status_bar(StatusBarConfig{
				...bars_status([bar_label('Ready')], [bar_label('README.md')], [
					bar_command('ln', 'Ln 1', ''),
				])
				frame: frame
				size:  size
				theme: dark
			}) or { panic(err) })
			bars_assert_inside(title_bar(TitleBarConfig{
				...bars_title(TitleBarWindow{
					leading_inset: 78
					controls:      true
				})
				frame: frame
				size:  size
				theme: dark
			}) or { panic(err) })
		}
	}
}

fn test_bars_dropdown_chevron_follows_its_caption_inside_the_command() {
	assert bars_caption_extent('ill', 13) < bars_caption_extent('MWM', 13)
	assert bars_caption_extent('Insert', 13) < component_text_width_estimate('Insert', 13)
	m := bar_metrics(.toolbar, .medium)
	for caption in ['Insert', '100%', 'W', 'A rather long caption'] {
		item := BarItem{
			...bar_command('menu', caption, 'plus.rectangle')
			dropdown: true
		}
		width := bars_extent(item, m, false)
		content := bars_content(item, rect(0, 0, width, m.control), 0, m, true)
		chevron := content.filter(it.image_path == 'symbol:chevron.down')[0]
		text := content.filter(it.kind == .label)[0]
		assert chevron.frame.x + chevron.frame.width <= width - m.inner + 1e-9, caption
		assert chevron.frame.x >= text.frame.x + bars_caption_extent(caption, m.font_size), caption
		// The caption's frame may run under the chevron, never out of the command.
		assert text.frame.x + text.frame.width <= width - m.inner + 1e-9, caption
	}
	// A chevron alone is centered.
	alone := BarItem{
		...bar_command('menu', '', '')
		dropdown: true
	}
	only := bars_content(alone, rect(0, 0, 24, 24), 0, m, true)
	assert only.len == 1
	assert only[0].frame.x == math.round((24 - bars_chevron(m)) / 2)
}
