module ui2

import math

// The carousel's GPUI Kit parts: a clipping viewport whose track can slide,
// previous and next buttons, dot or numbered indicators, a focus ring, and the
// decoders, key helper, drag tracking and animation that go with them. The
// basic carousel (slides only, inactive ones hidden) is in carousel.v and stays
// what it was when none of these options is set.

const carousel_indicator_gap = 12.0
const carousel_inside_margin = 12.0
const carousel_slide_duration = 0.3

// carousel_composed reports whether the carousel uses the viewport layout.
fn carousel_composed(config CarouselConfig) bool {
	return config.controls != .none || config.indicators != .none || config.per_view > 1
		|| config.gap > 0 || config.clip || config.draggable || config.focused
}

// CarouselLayout places a carousel's parts, relative to the carousel.
pub struct CarouselLayout {
pub:
	viewport   Rect   // where the slides show
	previous   Rect   // previous button; empty without controls
	next       Rect   // next button; empty without controls
	indicators Rect   // the strip the indicators sit in; empty without them
	pages      []Rect // each indicator's clickable frame, in page order
	extent     f64    // a slide's length along the axis
	step       f64    // distance between the starts of neighbouring slides
}

fn carousel_control_size(size ComponentSize) f64 {
	return component_metrics(size).height
}

fn carousel_control_gap(size ComponentSize) f64 {
	return if size == .small { 12.0 } else { 16.0 }
}

// carousel_indicator_thickness is how much room the indicator strip takes
// across the carousel's axis.
fn carousel_indicator_thickness(indicators CarouselIndicators) f64 {
	return match indicators {
		.none { 0.0 }
		.dots { 16.0 }
		.numbers { 24.0 }
	}
}

fn carousel_viewport(config CarouselConfig) Rect {
	w := math.max(0.0, config.frame.width)
	h := math.max(0.0, config.frame.height)
	if !carousel_composed(config) {
		return rect(0, 0, w, h)
	}
	control := carousel_control_size(config.size)
	controls := if config.controls == .outside {
		control + carousel_control_gap(config.size)
	} else {
		0.0
	}
	strip := if config.indicators == .none {
		0.0
	} else {
		carousel_indicator_gap + carousel_indicator_thickness(config.indicators)
	}
	if carousel_horizontal(config) {
		x := math.min(controls, w / 2)
		return rect(x, 0, w - 2 * x, math.max(0.0, h - strip))
	}
	y := math.min(controls, h / 2)
	return rect(0, y, math.max(0.0, w - strip), h - 2 * y)
}

// carousel_page_cell is the clickable size of indicator `page`: a dot's cell is
// wider for the current page, whose dot is drawn as a pill.
fn carousel_page_cell(config CarouselConfig, current bool) f64 {
	return match config.indicators {
		.none { 0.0 }
		.dots {
			if current { 28.0 } else { 16.0 }
		}
		.numbers { 28.0 }
	}
}

// carousel_layout places the viewport, the controls and the indicators.
pub fn carousel_layout(config CarouselConfig) !CarouselLayout {
	carousel_validate(config)!
	viewport := carousel_viewport(config)
	extent := carousel_slide_extent(config, viewport)
	horizontal := carousel_horizontal(config)
	mut previous := Rect{}
	mut next := Rect{}
	if carousel_composed(config) && config.controls != .none {
		b := carousel_control_size(config.size)
		outside := config.controls == .outside
		// The buttons sit on the side their slides come from: a carousel whose next
		// slide is on the left has its next button on the left.
		mut start := Rect{}
		mut end := Rect{}
		if horizontal {
			y := viewport.y + (viewport.height - b) / 2
			start = rect(if outside { 0.0 } else { viewport.x + carousel_inside_margin }, y,
				b, b)
			end = rect(if outside {
				config.frame.width - b
			} else {
				viewport.x + viewport.width - carousel_inside_margin - b
			}, y, b, b)
		} else {
			x := viewport.x + (viewport.width - b) / 2
			start = rect(x, if outside { 0.0 } else { viewport.y + carousel_inside_margin },
				b, b)
			end = rect(x, if outside {
				config.frame.height - b
			} else {
				viewport.y + viewport.height - carousel_inside_margin - b
			}, b, b)
		}
		reversed := config.direction in [.left, .top]
		previous = if reversed { end } else { start }
		next = if reversed { start } else { end }
	}
	mut strip := Rect{}
	mut cells := []Rect{}
	if carousel_composed(config) && config.indicators != .none && config.slides.len > 0 {
		thickness := carousel_indicator_thickness(config.indicators)
		strip = if horizontal {
			rect(viewport.x, viewport.y + viewport.height + carousel_indicator_gap, viewport.width,
				thickness)
		} else {
			rect(viewport.x + viewport.width + carousel_indicator_gap, viewport.y, thickness,
				viewport.height)
		}
		count := carousel_page_count(config)
		current := carousel_current(config)
		mut total := 0.0
		for page in 0 .. count {
			total += carousel_page_cell(config, page == current)
		}
		main := if horizontal { strip.width } else { strip.height }
		mut cursor := (main - total) / 2
		cells = []Rect{len: count}
		order := if config.direction in [.left, .top] {
			[]int{len: count, init: count - 1 - index}
		} else {
			[]int{len: count, init: index}
		}
		for page in order {
			cell := carousel_page_cell(config, page == current)
			cells[page] = if horizontal {
				rect(strip.x + cursor, strip.y, cell, thickness)
			} else {
				rect(strip.x, strip.y + cursor, thickness, cell)
			}
			cursor += cell
		}
	}
	return CarouselLayout{
		viewport:   viewport
		previous:   previous
		next:       next
		indicators: strip
		pages:      cells
		extent:     extent
		step:       extent + config.gap
	}
}

pub fn carousel_previous_action_id(id string) string {
	return component_part_id(id, 'previous')
}

pub fn carousel_next_action_id(id string) string {
	return component_part_id(id, 'next')
}

pub fn carousel_page_action_id(id string, page int) string {
	return component_part_id(id, 'page:${page}')
}

// carousel_track_id names the view that holds the slides inside the viewport;
// carousel_drag_event expects the drags it reports.
pub fn carousel_track_id(id string) string {
	return component_part_id(id, 'track')
}

// carousel_track_frame is where the track sits for a given offset along the
// axis. A horizontal track that moves right gives up as much width, so it never
// reaches past the viewport and gives the viewport nothing to scroll.
fn carousel_track_frame(config CarouselConfig, viewport Rect, offset f64) Rect {
	if carousel_horizontal(config) {
		return rect(offset, 0, math.max(0.0, viewport.width - math.max(offset, 0.0)), viewport.height)
	}
	return rect(0, offset, viewport.width, viewport.height)
}

fn carousel_compose(config CarouselConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	layout := carousel_layout(config)!
	frames := carousel_frames(config)!
	theme := config.theme
	viewport := layout.viewport
	count := config.slides.len
	current := carousel_current(config)
	mut slides := []Element{cap: count}
	for index, slide in config.slides {
		slides << Element{
			...carousel_slide_semantics(slide, index, count)
			frame: frames[index]
		}
	}
	mut children := []Element{}
	children << view(component_part_id(config.id, 'viewport'), viewport, config.box, []Element{})
	track := Element{
		...view(carousel_track_id(config.id), carousel_track_frame(config, viewport, config.drag_offset),
			BoxStyle{ transparent: true }, slides)
		draggable: config.draggable && config.enabled && count > 1
	}
	// An anonymous scroll is a clip on every renderer: the custom renderer gives
	// it no scroll range, and AppKit's document never outgrows the track.
	children << Element{
		...scroll_with_mode('', viewport, 0, .horizontal_only, [track])
		box:                 BoxStyle{
			transparent: true
		}
		accessibility_role:  'group'
		accessibility_label: 'Slides'
	}
	if config.controls != .none {
		children << carousel_control(config, layout.previous, false)
		children << carousel_control(config, layout.next, true)
	}
	if config.indicators != .none && count > 0 {
		children << carousel_indicators(config, layout)
	}
	if config.focused && viewport.width > 0 && viewport.height > 0 {
		ring := rect(viewport.x - 3, viewport.y - 3, viewport.width + 6, viewport.height + 6)
		children << shape(component_part_id(config.id, 'focus'), ring, path_rounded_rect(rect(1,
			1, ring.width - 2, ring.height - 2), config.box.radius + 3), ShapeStyle{
			stroke:       theme.primary
			stroke_width: 2
		})
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
		accessibility_value: if count == 0 {
			'No slides'
		} else {
			carousel_slide_label(current, count)
		}
	})
}

// carousel_control draws an outline circle with a chevron toward the side its
// slides come from. At the end of a carousel that does not loop it is dimmed
// and inert, as upstream's disabled button.
fn carousel_control(config CarouselConfig, frame Rect, next bool) Element {
	theme := config.theme
	enabled := config.enabled && config.slides.len > 0 && if next {
		carousel_has_next(config)
	} else {
		carousel_has_previous(config)
	}
	reversed := config.direction in [.left, .top]
	toward_start := next == reversed
	symbol := if carousel_horizontal(config) {
		if toward_start { 'chevron.left' } else { 'chevron.right' }
	} else {
		if toward_start { 'chevron.up' } else { 'chevron.down' }
	}
	local := rect(0, 0, frame.width, frame.height)
	border := if enabled { theme.border } else { choice_mix(theme.border, theme.background, 0.4) }
	glyph := if enabled { theme.foreground } else { choice_disabled_text(theme) }
	mut parts := choice_ring(local, frame.width / 2, border, theme.background, .all, false)
	icon := math.round(frame.width * 0.45)
	parts << choice_icon(symbol, rect((frame.width - icon) / 2, (frame.height - icon) / 2, icon,
		icon), glyph)
	caption := if next { config.next_label } else { config.previous_label }
	if !enabled {
		return Element{
			...view('', frame, BoxStyle{ transparent: true }, parts)
			key:                 if next { 'next' } else { 'previous' }
			enabled:             false
			accessibility_role:  'button'
			accessibility_label: caption
		}
	}
	return Element{
		...button_view(if next {
			carousel_next_action_id(config.id)
		} else {
			carousel_previous_action_id(config.id)
		}, frame, BoxStyle{ transparent: true }, parts)
		key:                 if next { 'next' } else { 'previous' }
		tooltip:             caption
		accessibility_label: caption
	}
}

fn carousel_indicators(config CarouselConfig, layout CarouselLayout) Element {
	theme := config.theme
	current := carousel_current(config)
	strip := layout.indicators
	horizontal := carousel_horizontal(config)
	mut items := []Element{cap: layout.pages.len}
	for page, cell in layout.pages {
		selected := page == current
		local := rect(cell.x - strip.x, cell.y - strip.y, cell.width, cell.height)
		mut parts := []Element{}
		if config.indicators == .dots {
			long := if selected { 20.0 } else { 8.0 }
			dot := if horizontal {
				rect((cell.width - long) / 2, (cell.height - 8) / 2, long, 8)
			} else {
				rect((cell.width - 8) / 2, (cell.height - long) / 2, 8, long)
			}
			mut color := if selected {
				theme.primary
			} else {
				choice_mix(theme.border, theme.muted_foreground,
					0.25)
			}
			if !config.enabled {
				color = choice_mix(color, theme.background, 0.5)
			}
			parts << view('', dot, BoxStyle{
				bg:     color
				radius: 4
			}, []Element{})
		} else {
			face := rect((cell.width - 24) / 2, (cell.height - 24) / 2, 24, 24)
			if selected {
				parts << view('', face, BoxStyle{
					bg:     if config.enabled {
						theme.primary
					} else {
						choice_mix(theme.primary, theme.background, 0.5)
					}
					radius: 6
				}, []Element{})
			}
			text_color := if !config.enabled {
				choice_disabled_text(theme)
			} else if selected {
				theme.primary_foreground
			} else {
				theme.muted_foreground
			}
			parts << label('', '${page + 1}', face, TextStyle{
				color: text_color
				size:  12
				bold:  selected
				align: .center
			})
		}
		caption := 'Go to slide ${page + 1}'
		value := if selected { 'current' } else { '' }
		if !config.enabled || selected {
			items << Element{
				...view('', local, BoxStyle{ transparent: true }, parts)
				key:                 'page:${page}'
				enabled:             config.enabled
				accessibility_role:  'button'
				accessibility_label: caption
				accessibility_value: value
			}
			continue
		}
		items << Element{
			...button_view(carousel_page_action_id(config.id, page), local, BoxStyle{
				transparent: true
			}, parts)
			key:                 'page:${page}'
			accessibility_label: caption
		}
	}
	return Element{
		...view('', strip, BoxStyle{ transparent: true }, items)
		accessibility_role:  'group'
		accessibility_label: 'Slide picker'
	}
}

// ── Decoding ────────────────────────────────────────────────────────

// carousel_index_from_action returns the index a click on the previous or next
// button or an indicator selects. Pass the config the carousel was built with
// and store the result as `index`. It returns none for foreign, malformed or
// forged actions, a disabled carousel, a button at the end of a carousel that
// does not loop, and the indicator of the current position.
pub fn carousel_index_from_action(config CarouselConfig, action string) ?int {
	if !config.enabled || config.slides.len == 0 || !carousel_composed(config) {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	if part == 'previous' && config.controls != .none {
		return carousel_previous_index(config)
	}
	if part == 'next' && config.controls != .none {
		return carousel_next_index(config)
	}
	if part.starts_with('page:') && config.indicators != .none {
		page := component_parse_index(part['page:'.len..], carousel_max_index(config)) or {
			return none
		}
		return if page == carousel_current(config) { none } else { page }
	}
	return none
}

// carousel_index_after_key is for on_key_event, as upstream's key bindings:
// the arrows along the carousel's axis move toward the slides on that side,
// and Home and End go to the first and last position. Components cannot take
// focus, so call it while the application considers the carousel focused.
pub fn carousel_index_after_key(config CarouselConfig, code KeyCode) ?int {
	if !config.enabled || config.slides.len == 0 {
		return none
	}
	horizontal := carousel_horizontal(config)
	next := match code {
		.home {
			0
		}
		.end {
			carousel_max_index(config)
		}
		.left, .right, .up, .down {
			if horizontal != (code in [.left, .right]) {
				return none
			}
			// The arrow toward the side the next slides come from selects the next one.
			toward_next := match config.direction {
				.right { code == .right }
				.left { code == .left }
				.bottom { code == .down }
				.top { code == .up }
			}
			if toward_next {
				carousel_next_index(config)?
			} else {
				carousel_previous_index(config)?
			}
		}
		else {
			return none
		}
	}
	return if next == carousel_current(config) { none } else { next }
}

// CarouselDrag remembers where a drag of the slides began. Keep the one
// carousel_drag_event hands back in the model until the drag ends.
pub struct CarouselDrag {
pub:
	active  bool
	start_x f64 // window coordinates of the press
	start_y f64
}

pub enum CarouselDragPhase {
	start
	move
	end
}

pub struct CarouselDragEvent {
pub:
	phase  CarouselDragPhase
	drag   CarouselDrag // the drag to keep; inactive after .end
	offset f64          // the drag_offset to build with: 0 after .end
	index  int          // the index to build with: after .end, the slide it settled on
}

// carousel_drag_rubber_band slows a drag past the first or last position, so
// the slides give a little but show there is nothing more that way.
fn carousel_drag_rubber_band(config CarouselConfig, offset f64) f64 {
	// Only the axis's own coordinate counts, so the offset stands for both.
	advance := carousel_advance_distance(config, offset, offset)
	blocked := (advance > 0 && !carousel_has_next(config))
		|| (advance < 0 && !carousel_has_previous(config))
	return if blocked { offset / 3 } else { offset }
}

// carousel_drag_event decodes the pointer events the track of a draggable
// carousel reports. On .start and .move build with the returned offset as
// drag_offset, so the slides follow the pointer; on .end build with the
// returned index (and drag_offset 0), calling carousel_animate first so the
// slides glide from where they were let go. A drag that crosses min_move of a
// slide moves at least one position, and a longer one as many as it covered.
pub fn carousel_drag_event(config CarouselConfig, drag CarouselDrag, event string) ?CarouselDragEvent {
	if !config.enabled || !config.draggable || config.slides.len < 2 {
		return none
	}
	pointer := parse_pointer_event(event)?
	if pointer.action != carousel_track_id(config.id) || !component_finite(pointer.x)
		|| !component_finite(pointer.y) {
		return none
	}
	current := carousel_current(config)
	if pointer.phase == 'down' {
		return CarouselDragEvent{
			phase: .start
			drag:  CarouselDrag{
				active:  true
				start_x: pointer.x
				start_y: pointer.y
			}
			index: current
		}
	}
	if !drag.active || pointer.phase !in ['drag', 'up'] {
		return none
	}
	dx := pointer.x - drag.start_x
	dy := pointer.y - drag.start_y
	horizontal := carousel_horizontal(config)
	main := if horizontal { dx } else { dy }
	if pointer.phase == 'drag' {
		offset := carousel_drag_rubber_band(config, main)
		if math.abs(offset - config.drag_offset) < 0.01 {
			return none
		}
		return CarouselDragEvent{
			phase:  .move
			drag:   drag
			offset: offset
			index:  current
		}
	}
	step := carousel_step(config)
	cross := if horizontal { dy } else { dx }
	mut index := current
	if step > 0 && !(config.ignore_perpendicular_swipes && math.abs(cross) > math.abs(main)) {
		moved := carousel_advance_distance(config, dx, dy) / step
		if math.abs(moved) > config.min_move {
			steps := int(math.max(1.0, math.round(math.abs(moved))))
			for _ in 0 .. steps {
				index = if moved > 0 {
					carousel_next_index(CarouselConfig{
						...config
						index: index
					}) or { break }
				} else {
					carousel_previous_index(CarouselConfig{
						...config
						index: index
					}) or { break }
				}
			}
		}
	}
	return CarouselDragEvent{
		phase: .end
		index: index
	}
}

// carousel_animate starts the animation that slides a carousel's track from
// what `before` shows to what `after` does: call it with the config the
// carousel was built with and the one it is about to be rebuilt with, when a
// button, an indicator, a key, an autoplay tick or the end of a drag changes
// `index`. Looping carousels take the shorter way round. It needs the viewport
// layout (any GPUI Kit option, or `clip: true`) and does nothing otherwise.
pub fn carousel_animate(before CarouselConfig, after CarouselConfig) ! {
	if !carousel_composed(after) || !carousel_composed(before) || before.id != after.id
		|| after.id.len == 0 || after.slides.len == 0 || before.slides.len != after.slides.len {
		return
	}
	reference := carousel_current(before)
	from := carousel_frames(before)![reference]
	to := carousel_frames(after)![reference]
	horizontal := carousel_horizontal(after)
	shift := if horizontal {
		(from.x + before.drag_offset) - to.x
	} else {
		(from.y + before.drag_offset) - to.y
	}
	rest := after.drag_offset
	if math.abs(shift - rest) < 0.5 {
		return
	}
	viewport := carousel_viewport(after)
	start := carousel_track_frame(after, viewport, shift)
	end := carousel_track_frame(after, viewport, rest)
	id := carousel_track_id(after.id)
	if horizontal {
		jump := animation(duration: 0, x: start.x, width: start.width)
		glide := animation(
			duration:   carousel_slide_duration
			transition: .out_cubic
			x:          end.x
			width:      end.width
		)
		(jump + glide).with_event_handler(disclosure_release_animation).start(id)
	} else {
		disclosure_tween(id, .y, start.y, end.y, carousel_slide_duration)
	}
}
