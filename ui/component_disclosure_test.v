module ui2

import time

// ── Helpers ─────────────────────────────────────────────────────────

fn disclosure_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := disclosure_test_find(child, id) {
			return found
		}
	}
	return none
}

fn disclosure_test_images(el Element) []string {
	mut names := []string{}
	if el.kind == .image {
		names << el.image_path
	}
	for child in el.children {
		names << disclosure_test_images(child)
	}
	return names
}

fn disclosure_test_content(height f64) Element {
	return view('', rect(0, 0, 200, height), BoxStyle{ transparent: true }, []Element{})
}

fn disclosure_test_accordion() AccordionConfig {
	return AccordionConfig{
		id:     'faq'
		frame:  rect(10, 20, 300, 0)
		layout: .stack
		open:   [0]
		items:  [
			AccordionItem{
				title:   'First'
				icon:    'bell'
				content: disclosure_test_content(30)
			},
			AccordionItem{
				title:   'Second'
				content: disclosure_test_content(50)
			},
			AccordionItem{
				title:   'Locked'
				enabled: false
				content: disclosure_test_content(10)
			},
			AccordionItem{
				title:   'Last'
				content: disclosure_test_content(20)
			},
		]
	}
}

fn disclosure_test_slides(count int) []Element {
	return []Element{len: count, init: view('slide_${index}', rect(0, 0, 1, 1), BoxStyle{}, []Element{})}
}

fn disclosure_test_carousel() CarouselConfig {
	return CarouselConfig{
		id:         'hero'
		frame:      rect(0, 0, 400, 200)
		controls:   .outside
		indicators: .dots
		slides:     disclosure_test_slides(4)
	}
}

// ── Accordion: stack layout ─────────────────────────────────────────

fn test_accordion_stack_layout_sizes_open_panels_to_their_content() {
	layout := accordion_stack_layout(disclosure_test_accordion()) or { panic(err) }
	m := accordion_stack_metrics(.medium)
	// Bordered: one point of border around the items, a rule between them.
	assert layout.titles[0] == rect(1, 1, 298, m.title_height)
	assert layout.panels[0] == rect(1, 1 + m.title_height, 298, 30 + m.pad_bottom)
	assert layout.items[1].y == 1 + m.title_height + 30 + m.pad_bottom
	assert layout.titles[1].y == layout.items[1].y + 1
	assert layout.panels[1].height == 0
	assert layout.height == 2 + 4 * m.title_height + 3 + 30 + m.pad_bottom
	assert layout.body_width == 298 - 2 * m.pad_x
	assert accordion_body_width(300, .medium, true) == layout.body_width
	plain := accordion_stack_layout(AccordionConfig{
		...disclosure_test_accordion()
		bordered: false
		open:     []
	}) or { panic(err) }
	assert plain.titles[0] == rect(0, 0, 300, m.title_height)
	assert plain.height == 4 * m.title_height + 3
	small := accordion_stack_layout(AccordionConfig{
		...disclosure_test_accordion()
		size: .small
	}) or { panic(err) }
	assert small.height < layout.height
}

fn test_accordion_open_items_normalizes_the_open_list() {
	base := disclosure_test_accordion()
	assert accordion_open_items(AccordionConfig{ ...base, open: [3, -1, 9, 1, 3], multiple: true }) == [
		1,
		3,
	]
	// One at a time keeps the first valid index the application listed.
	assert accordion_open_items(AccordionConfig{ ...base, open: [9, 3, 1] }) == [3]
	assert accordion_open_items(AccordionConfig{ ...base, open: [] }) == []
}

fn test_accordion_stack_builds_rows_panels_and_card() {
	el := accordion(disclosure_test_accordion()) or { panic(err) }
	layout := accordion_stack_layout(disclosure_test_accordion()) or { panic(err) }
	// A zero frame height fits the items.
	assert el.frame == rect(10, 20, 300, layout.height)
	assert el.accessibility_role == 'group'
	card := disclosure_test_find(el, component_part_id('faq', 'card')) or { panic('no card') }
	assert card.frame.height == layout.height
	first := disclosure_test_find(el, accordion_item_action_id('faq', 0)) or { panic('no row') }
	assert first.button_behavior
	assert first.hoverable
	assert first.accessibility_label == 'First'
	assert first.accessibility_value == 'expanded'
	assert 'symbol:bell' in disclosure_test_images(first)
	assert 'symbol:chevron.up' in disclosure_test_images(first)
	second := disclosure_test_find(el, accordion_item_action_id('faq', 1)) or { panic('no row') }
	assert second.accessibility_value == 'collapsed'
	assert 'symbol:chevron.down' in disclosure_test_images(second)
	// Only open items mount their content, inside a clipping panel.
	panel := disclosure_test_find(el, accordion_panel_id('faq', 0)) or { panic('no panel') }
	assert panel.kind == .scroll
	assert panel.frame.height == layout.panels[0].height
	assert panel.children[0].frame.x == accordion_stack_metrics(.medium).pad_x
	assert disclosure_test_find(el, accordion_panel_id('faq', 1)) == none
	// A disabled item is not a button and shows no chevron.
	assert disclosure_test_find(el, accordion_item_action_id('faq', 2)) == none
	fixed := accordion(AccordionConfig{
		...disclosure_test_accordion()
		frame: rect(0, 0, 300, 400)
	}) or { panic(err) }
	assert fixed.frame.height == 400
}

fn test_accordion_stack_marks_hover_and_focus() {
	el := accordion(AccordionConfig{
		...disclosure_test_accordion()
		hovered: 1
		focused: 3
	}) or { panic(err) }
	assert disclosure_test_find(el, component_part_id('faq', 'focus:3')) != none
	assert disclosure_test_find(el, component_part_id('faq', 'focus:1')) == none
	row := disclosure_test_find(el, accordion_item_action_id('faq', 1)) or { panic('no row') }
	assert row.children[0].box.bg == ComponentTheme{}.muted
}

fn test_accordion_stack_requires_an_id_and_keeps_the_fill_layout() {
	if _ := accordion(AccordionConfig{ ...disclosure_test_accordion(), id: '' }) {
		assert false, 'a stacked accordion without an id was accepted'
	}
	// The fill layout is still the default and still fills its frame.
	fill := accordion(
		id:        'fill'
		frame:     rect(0, 0, 300, 200)
		min_space: 40
		items:     [AccordionItem{
			id:      'a'
			title:   'A'
			content: view('content_a', rect(0, 0, 1, 1), BoxStyle{}, [])
		}]
	) or { panic(err) }
	assert fill.children[0].id == 'content_a'
	assert fill.children[0].frame == rect(40, 0, 260, 200)
}

fn test_accordion_open_from_action_toggles_one_or_many() {
	config := disclosure_test_accordion()
	// One at a time: opening an item closes the others, clicking the open one closes it.
	assert accordion_open_from_action(config, accordion_item_action_id('faq', 1))? == [1]
	assert accordion_open_from_action(config, accordion_item_action_id('faq', 0))? == []
	many := AccordionConfig{
		...config
		multiple: true
		open:     [3]
	}
	assert accordion_open_from_action(many, accordion_item_action_id('faq', 0))? == [
		0,
		3,
	]
	assert accordion_open_from_action(many, accordion_item_action_id('faq', 3))? == []
	for action in [accordion_item_action_id('faq', 2), accordion_item_action_id('faq', 4),
		accordion_item_action_id('other', 0), 'faq:component:item:01', 'faq:component:item:',
		'faq:component:item:-1', 'faq'] {
		assert accordion_open_from_action(config, action) == none, action
	}
	assert accordion_open_from_action(AccordionConfig{ ...config, enabled: false }, accordion_item_action_id('faq',
		0)) == none
	assert accordion_open_from_action(AccordionConfig{ ...config, layout: .fill }, accordion_item_action_id('faq',
		0)) == none
}

fn test_accordion_hover_from_event() {
	config := disclosure_test_accordion()
	action := accordion_item_action_id('faq', 1)
	assert accordion_hover_from_event(config, 'pointer:enter:${action}:4:5')? == 1
	hovered := AccordionConfig{
		...config
		hovered: 1
	}
	assert accordion_hover_from_event(hovered, 'pointer:enter:${action}:4:5') == none
	assert accordion_hover_from_event(hovered, 'pointer:leave:${action}:4:5')? == -1
	assert accordion_hover_from_event(hovered, 'pointer:leave:${accordion_item_action_id('faq', 0)}:4:5') == none
	assert accordion_hover_from_event(config, 'pointer:enter:${accordion_item_action_id('faq', 2)}:4:5') == none
	assert accordion_hover_from_event(config, action) == none
}

fn test_accordion_keys_move_focus_and_toggle() {
	config := disclosure_test_accordion()
	// Down from nowhere starts at the first row; disabled rows are skipped; it wraps.
	assert accordion_focus_after_key(config, .down)? == 0
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 1 }, .down)? == 3
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 3 }, .down)? == 0
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 0 }, .up)? == 3
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 1 }, .home)? == 0
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 1 }, .end)? == 3
	assert accordion_focus_after_key(AccordionConfig{ ...config, focused: 3 }, .end) == none
	assert accordion_focus_after_key(config, .left) == none
	focused := AccordionConfig{
		...config
		focused: 1
	}
	assert accordion_open_after_key(focused, .enter)? == [1]
	assert accordion_open_after_key(focused, .space)? == [1]
	assert accordion_open_after_key(focused, .a) == none
	assert accordion_open_after_key(AccordionConfig{ ...config, focused: 2 }, .enter) == none
	assert accordion_open_after_key(config, .enter) == none
}

fn test_accordion_animate_glides_rows_and_unrolls_the_panel() {
	reset_widget_animations()
	before := disclosure_test_accordion()
	after := AccordionConfig{
		...before
		open: [1]
	}
	from := accordion_stack_layout(before) or { panic(err) }
	to := accordion_stack_layout(after) or { panic(err) }
	now := time.ticks()
	accordion_animate(before, after) or { panic(err) }
	root := screen(0xffffff, [accordion(after) or { panic(err) }])
	first := apply_widget_animations_at(root, now)
	section := disclosure_test_find(first, component_part_id('faq', 'section:1')) or {
		panic('no section')
	}
	assert section.frame.y == from.items[1].y
	panel := disclosure_test_find(first, accordion_panel_id('faq', 1)) or { panic('no panel') }
	assert panel.frame.height == 0
	card := disclosure_test_find(first, component_part_id('faq', 'card')) or { panic('no card') }
	assert card.frame.height == from.height
	// A row that does not move is left alone.
	assert animation_info(component_part_id('faq', 'section:0')).status == .idle
	last := apply_widget_animations_at(root, now + 2_000)
	settled := disclosure_test_find(last, component_part_id('faq', 'section:1')) or {
		panic('no section')
	}
	assert settled.frame.y == to.items[1].y
	assert animation_info(component_part_id('faq', 'section:1')).status == .idle
	reset_widget_animations()
}

// ── Carousel: geometry and navigation ───────────────────────────────

fn test_carousel_per_view_and_gap_place_several_slides() {
	config := CarouselConfig{
		frame:    rect(0, 0, 320, 100)
		per_view: 3
		gap:      10
		index:    1
		slides:   disclosure_test_slides(5)
	}
	frames := carousel_frames(config) or { panic(err) }
	assert frames[1] == rect(0, 0, 100, 100)
	assert frames[2] == rect(110, 0, 100, 100)
	assert frames[0] == rect(-110, 0, 100, 100)
	assert carousel_max_index(config) == 2
	assert carousel_page_count(config) == 3
	assert carousel_current(CarouselConfig{ ...config, index: 7 }) == 2
	assert carousel_next_index(CarouselConfig{ ...config, index: 2 }) == none
	assert carousel_previous_index(config)? == 0
	assert carousel_has_previous(config)
	// Slides come from the left when the next one is on the left.
	left := carousel_frames(CarouselConfig{ ...config, direction: .left }) or { panic(err) }
	assert left[1] == rect(220, 0, 100, 100)
	assert left[2] == rect(110, 0, 100, 100)
}

fn test_carousel_loop_keeps_the_visible_slides_ahead() {
	config := CarouselConfig{
		frame:    rect(0, 0, 300, 100)
		per_view: 2
		loop:     true
		index:    4
		slides:   disclosure_test_slides(5)
	}
	frames := carousel_frames(config) or { panic(err) }
	assert frames[4].x == 0
	assert frames[0].x == 150 // second visible slide wraps around
	assert frames[3].x == -150 // previous one waits on the left
	assert carousel_next_index(config)? == 0
	assert carousel_max_index(config) == 4
	// Looping needs more slides than a view shows.
	assert !carousel_has_next(CarouselConfig{ ...config, slides: disclosure_test_slides(2) })
}

fn test_carousel_autoplay_wraps_without_loop() {
	config := CarouselConfig{
		frame:  rect(0, 0, 300, 100)
		index:  2
		slides: disclosure_test_slides(3)
	}
	assert carousel_autoplay_index(config) == 0
	assert carousel_autoplay_index(CarouselConfig{ ...config, index: 0 }) == 1
}

fn test_carousel_validates_per_view_and_gap() {
	for config in [CarouselConfig{
		per_view: 0
	}, CarouselConfig{
		gap: -1
	}] {
		if _ := carousel_frames(config) {
			assert false, 'invalid carousel accepted'
		}
	}
	if _ := carousel(CarouselConfig{ controls: .outside, slides: disclosure_test_slides(2) }) {
		assert false, 'a composed carousel without an id was accepted'
	}
}

fn test_carousel_swipe_moves_one_step_of_a_multi_slide_view() {
	config := CarouselConfig{
		frame:    rect(0, 0, 320, 100)
		per_view: 3
		gap:      10
		slides:   disclosure_test_slides(5)
	}
	// One slide plus its gap is 110 points; a fifth of it is the threshold.
	assert carousel_index_after_swipe(config, -23, 0)! == 1
	assert carousel_index_after_swipe(config, -21, 0)! == 0
}

// ── Carousel: composed viewport ─────────────────────────────────────

fn test_carousel_layout_reserves_room_for_controls_and_dots() {
	layout := carousel_layout(disclosure_test_carousel()) or { panic(err) }
	b := component_metrics(.medium).height
	assert layout.viewport == rect(b + 16, 0, 400 - 2 * (b + 16), 200 - 28)
	assert layout.previous == rect(0, (172 - b) / 2, b, b)
	assert layout.next == rect(400 - b, (172 - b) / 2, b, b)
	assert layout.indicators.y == 172 + 12
	assert layout.pages.len == 4
	assert layout.pages[0].width > layout.pages[1].width // the current dot is a pill
	assert layout.pages[1].x == layout.pages[0].x + layout.pages[0].width
	reversed := carousel_layout(CarouselConfig{ ...disclosure_test_carousel(), direction: .left }) or {
		panic(err)
	}
	assert reversed.next.x == 0
	assert reversed.pages[0].x > reversed.pages[3].x
	vertical := carousel_layout(CarouselConfig{
		...disclosure_test_carousel()
		direction: .bottom
		controls:  .inside
	}) or { panic(err) }
	assert vertical.viewport == rect(0, 0, 400 - 28, 200)
	assert vertical.previous.y == 12
	assert vertical.next.y == 200 - 12 - b
	assert vertical.indicators.x == 372 + 12
}

fn test_carousel_composed_structure() {
	el := carousel(CarouselConfig{
		...disclosure_test_carousel()
		draggable: true
		focused:   true
	}) or { panic(err) }
	assert el.accessibility_label == 'Carousel'
	assert el.accessibility_value == 'Slide 1 of 4'
	track := disclosure_test_find(el, carousel_track_id('hero')) or { panic('no track') }
	assert track.draggable
	assert track.children.len == 4
	// Slides stay mounted; the viewport clips them.
	assert !track.children.any(it.hidden)
	assert track.children[1].frame.x == track.children[0].frame.width
	assert track.children[2].accessibility_label == 'Slide 3 of 4'
	assert el.children[1].kind == .scroll
	assert el.children[1].children[0].id == carousel_track_id('hero')
	// At the start, previous is inert and next is a button.
	assert disclosure_test_find(el, carousel_previous_action_id('hero')) == none
	next := disclosure_test_find(el, carousel_next_action_id('hero')) or { panic('no next') }
	assert next.button_behavior
	assert next.accessibility_label == 'Next slide'
	assert disclosure_test_find(el, carousel_page_action_id('hero', 0)) == none
	assert disclosure_test_find(el, carousel_page_action_id('hero', 3)) != none
	assert disclosure_test_find(el, component_part_id('hero', 'focus')) != none
	moved := carousel(CarouselConfig{
		...disclosure_test_carousel()
		drag_offset: 40
	}) or { panic(err) }
	moved_track := disclosure_test_find(moved, carousel_track_id('hero')) or { panic('no track') }
	viewport := carousel_layout(disclosure_test_carousel()) or { panic(err) }.viewport
	// Moving right gives up width, so the track never reaches past the viewport.
	assert moved_track.frame == rect(40, 0, viewport.width - 40, viewport.height)
}

fn test_carousel_numbers_and_classic_semantics() {
	el := carousel(CarouselConfig{
		...disclosure_test_carousel()
		indicators: .numbers
		index:      2
	}) or { panic(err) }
	labels := el.children.last().children.map(it.children.filter(it.kind == .label).map(it.text))
	assert labels.len == 4
	assert labels[2] == ['3']
	classic := carousel(frame: rect(0, 0, 100, 100), slides: disclosure_test_slides(2)) or {
		panic(err)
	}
	assert classic.children.len == 2
	assert classic.children[1].hidden
	assert classic.children[0].accessibility_label == 'Slide 1 of 2'
	assert classic.accessibility_label == 'Carousel'
}

fn test_carousel_index_from_action() {
	config := CarouselConfig{
		...disclosure_test_carousel()
		index: 1
	}
	assert carousel_index_from_action(config, carousel_next_action_id('hero'))? == 2
	assert carousel_index_from_action(config, carousel_previous_action_id('hero'))? == 0
	assert carousel_index_from_action(config, carousel_page_action_id('hero', 3))? == 3
	assert carousel_index_from_action(config, carousel_page_action_id('hero', 1)) == none
	assert carousel_index_from_action(CarouselConfig{ ...config, index: 3 }, carousel_next_action_id('hero')) == none
	assert carousel_index_from_action(CarouselConfig{ ...config, index: 3, loop: true },
		carousel_next_action_id('hero'))? == 0
	for action in [carousel_page_action_id('hero', 4), 'hero:component:page:01',
		carousel_next_action_id('other'), 'hero:component:track'] {
		assert carousel_index_from_action(config, action) == none, action
	}
	assert carousel_index_from_action(CarouselConfig{ ...config, enabled: false }, carousel_next_action_id('hero')) == none
	assert carousel_index_from_action(CarouselConfig{ ...config, controls: .none }, carousel_next_action_id('hero')) == none
}

fn test_carousel_index_after_key_follows_the_direction() {
	config := CarouselConfig{
		...disclosure_test_carousel()
		index: 1
	}
	assert carousel_index_after_key(config, .right)? == 2
	assert carousel_index_after_key(config, .left)? == 0
	assert carousel_index_after_key(config, .up) == none
	assert carousel_index_after_key(config, .end)? == 3
	assert carousel_index_after_key(config, .home)? == 0
	assert carousel_index_after_key(CarouselConfig{ ...config, index: 0 }, .home) == none
	assert carousel_index_after_key(CarouselConfig{ ...config, direction: .left }, .left)? == 2
	assert carousel_index_after_key(CarouselConfig{ ...config, direction: .bottom }, .down)? == 2
	assert carousel_index_after_key(CarouselConfig{ ...config, direction: .top }, .down)? == 0
	assert carousel_index_after_key(CarouselConfig{ ...config, direction: .top }, .right) == none
	assert carousel_index_after_key(CarouselConfig{ ...config, enabled: false }, .right) == none
}

fn test_carousel_drag_follows_and_snaps() {
	config := CarouselConfig{
		...disclosure_test_carousel()
		draggable: true
	}
	track := carousel_track_id('hero')
	start := carousel_drag_event(config, CarouselDrag{}, 'pointer:down:${track}:100:50')?
	assert start.phase == .start
	assert start.drag.active
	// Nothing comes before the first slide, so a drag that way gives a third.
	back := carousel_drag_event(config, start.drag, 'pointer:drag:${track}:130:50')?
	assert back.offset == 10
	along := carousel_drag_event(config, start.drag, 'pointer:drag:${track}:40:50')?
	assert along.phase == .move
	assert along.offset == -60
	assert carousel_drag_event(CarouselConfig{ ...config, drag_offset: -60 }, start.drag,
		'pointer:drag:${track}:40:50') == none
	step := carousel_step(config)
	short := carousel_drag_event(config, start.drag, 'pointer:up:${track}:${100 - step * 0.1}:50')?
	assert short.phase == .end
	assert short.index == 0
	assert !short.drag.active
	one := carousel_drag_event(config, start.drag, 'pointer:up:${track}:${100 - step * 0.3}:50')?
	assert one.index == 1
	two := carousel_drag_event(config, start.drag, 'pointer:up:${track}:${100 - step * 1.8}:50')?
	assert two.index == 2
	far := carousel_drag_event(config, start.drag, 'pointer:up:${track}:${100 - step * 9}:50')?
	assert far.index == 3
	assert carousel_drag_event(config, CarouselDrag{}, 'pointer:drag:${track}:40:50') == none
	assert carousel_drag_event(config, start.drag, 'pointer:drag:other:40:50') == none
	assert carousel_drag_event(CarouselConfig{ ...config, draggable: false }, CarouselDrag{},
		'pointer:down:${track}:100:50') == none
}

fn test_carousel_animate_slides_the_track() {
	reset_widget_animations()
	before := CarouselConfig{
		...disclosure_test_carousel()
		drag_offset: -30
	}
	after := CarouselConfig{
		...disclosure_test_carousel()
		index: 1
	}
	step := carousel_step(after)
	now := time.ticks()
	carousel_animate(before, after) or { panic(err) }
	root := screen(0xffffff, [carousel(after) or { panic(err) }])
	track_id := carousel_track_id('hero')
	first := disclosure_test_find(apply_widget_animations_at(root, now), track_id) or {
		panic('no track')
	}
	// It starts where the dragged slides were let go: one step back, less the drag.
	assert first.frame.x == step - 30
	last := disclosure_test_find(apply_widget_animations_at(root, now + 2_000), track_id) or {
		panic('no track')
	}
	assert last.frame.x == 0
	assert animation_info(track_id).status == .idle
	// The classic carousel has no viewport to slide in.
	carousel_animate(CarouselConfig{
		id:     'plain'
		slides: disclosure_test_slides(2)
	}, CarouselConfig{
		id:     'plain'
		index:  1
		slides: disclosure_test_slides(2)
	}) or { panic(err) }
	assert animation_info(carousel_track_id('plain')).status == .idle
	reset_widget_animations()
}
