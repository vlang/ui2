module ui2_c

struct Probe {
mut:
	invalid bool
	builds  int
	events  []string
}

fn probe_build(data voidptr) &C.ui2_node {
	mut probe := unsafe { &Probe(data) }
	probe.builds++
	root := create(0, unsafe { nil }, 0, 0, 0, 0)
	text := create(2, c'label', 10, 20, 200, 30)
	mut buffer := [u8(`o`), `w`, `n`, `e`, `d`, 0]
	set_text(text, unsafe { &char(buffer.data) })
	buffer[0] = `X`
	set_action(text, c'label-action')
	style := C.ui2_text_style{
		color:       0x123456
		size:        22
		font_family: c'Helvetica'
		bold:        1
		align:       2
		valign:      0
		lines:       3
	}
	set_text_style(text, &style)
	add(root, text)
	scroll := create(9, c'scroll', 0, 60, 300, 200)
	set_scroll_mode(scroll, 2)
	add(root, scroll)
	if probe.invalid { add(root, create(2, c'label', 0, 0, 1, 1)) }
	return root
}

fn probe_event(data voidptr, id &char) {
	mut probe := unsafe { &Probe(data) }
	probe.events << input(id)
}

fn media_probe_build(data voidptr) &C.ui2_node {
	mut probe := unsafe { &Probe(data) }
	probe.builds++
	root := create(0, unsafe { nil }, 0, 0, 0, 0)
	clip := create(14, c'clip', 0, 0, 100, 100)
	set_media(clip, 1, c'clip.mp4', 1)
	add(root, clip)
	return root
}

fn test_media_node_is_configured_in_build() {
	mut probe := &Probe{}
	config := C.ui2_config{
		build:     media_probe_build
		user_data: probe
	}
	assert configure(&config)
	defer { release_callbacks() }
	tree := build_tree()
	assert state().last_error == ''
	assert tree.children.len == 1
	clip := tree.children[0]
	assert clip.kind == .media
	assert clip.media_kind == .video
	assert clip.media_src == 'clip.mp4'
	assert clip.autoplay
}

fn test_tree_copies_foreign_buffers_and_preserves_last_valid_build() {
	mut probe := &Probe{}
	config := C.ui2_config{
		build:     probe_build
		user_data: probe
		width:     640
		height:    480
	}
	assert configure(&config)
	defer { release_callbacks() }
	first := build_tree()
	assert first.children.len == 2
	label := first.children[0]
	assert label.text == 'owned'
	assert label.action_id == 'label-action'
	assert label.frame.x == 10
	assert label.text_style.color == 0x123456
	assert label.text_style.size == 22
	assert label.text_style.bold
	assert label.text_style.font_family == 'Helvetica'
	assert label.text_style.align == .right
	assert label.text_style.valign == .top
	assert label.text_style.lines == 3
	assert first.children[1].scroll_mode == .both
	assert !state().building
	assert state().nodes.len == 0
	mut width := 0.0
	mut height := 0.0
	bounds(&width, &height)
	assert width == 640
	assert height == 480
	probe.invalid = true
	rejected := build_tree()
	assert rejected == first
	assert state().last_error.contains('duplicate element id')
	probe.invalid = false
	assert build_tree() == first
	assert state().last_error == ''
	assert probe.builds == 3
}

fn test_callbacks_forward_userdata_and_utf8_then_release_foreign_roots() {
	mut probe := &Probe{}
	config := C.ui2_config{
		build:     probe_build
		event:     probe_event
		key:       probe_event
		scroll:    probe_event
		user_data: probe
	}
	assert configure(&config)
	dispatch_event('save:世界')
	dispatch_key('ctrl+s')
	dispatch_scroll('canvas')
	assert probe.events == ['save:世界', 'ctrl+s', 'canvas']
	release_callbacks()
	assert state().user_data == unsafe { nil }
	assert state().build == unsafe { nil }
	assert state().event == unsafe { nil }
	assert state().key == unsafe { nil }
	assert state().scroll == unsafe { nil }
}
