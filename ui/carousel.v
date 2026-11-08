module ui2

import math

pub enum CarouselDirection {
	right
	left
	top
	bottom
}

// CarouselControls places GPUI Kit's previous and next buttons: round outline
// buttons beside the slides, in room the carousel's frame keeps for them, or
// over the slides' edges.
pub enum CarouselControls {
	none
	outside
	inside
}

// CarouselIndicators is the pagination under the slides (beside them when the
// carousel is vertical): a dot per position, or a numbered button per position.
pub enum CarouselIndicators {
	none
	dots
	numbers
}

pub struct CarouselConfig {
pub:
	id                          string
	frame                       Rect
	box                         BoxStyle
	index                       int
	direction                   CarouselDirection
	loop                        bool
	min_move                    f64 = 0.2
	ignore_perpendicular_swipes bool
	slides                      []Element
	// GPUI Kit's options. Any of controls, indicators, per_view above one, gap,
	// clip, draggable or focused puts the slides in a clipping viewport
	// (see component_disclosure_carousel.v), which carousel_animate can slide.
	per_view            int = 1 // slides shown at once; index is the first of them
	gap                 f64 // space between neighbouring slides
	controls            CarouselControls
	indicators          CarouselIndicators
	clip                bool // clipping viewport without controls or indicators
	draggable           bool // the slides follow a drag: carousel_drag_event
	drag_offset         f64  // how far a drag in progress has moved the slides
	focused             bool // draw the keyboard focus ring
	enabled             bool          = true
	previous_label      string        = 'Previous slide'
	next_label          string        = 'Next slide'
	accessibility_label string        = 'Carousel'
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub fn carousel_direction(value string) !CarouselDirection {
	return match value {
		'', 'right' { .right }
		'left' { .left }
		'top' { .top }
		'bottom' { .bottom }
		else {
			return error('unknown carousel direction `${value}`')
		}
	}
}

fn carousel_validate(config CarouselConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('carousel dimensions cannot be negative')
	}
	if config.min_move < 0 {
		return error('carousel minimum move cannot be negative')
	}
	if config.per_view < 1 {
		return error('carousel must show at least one slide per view')
	}
	if !component_finite(config.gap) || config.gap < 0 || !component_finite(config.drag_offset) {
		return error('carousel gap must be finite and non-negative, and its drag offset finite')
	}
}

pub fn carousel_index(index int, slide_count int, loop bool) int {
	if slide_count <= 0 {
		return 0
	}
	if loop {
		wrapped := index % slide_count
		return (wrapped + slide_count) % slide_count
	}
	if index < 0 {
		return 0
	}
	return if index < slide_count { index } else { slide_count - 1 }
}

pub fn carousel_next(index int, slide_count int, loop bool) int {
	return carousel_index(index + 1, slide_count, loop)
}

pub fn carousel_previous(index int, slide_count int, loop bool) int {
	return carousel_index(index - 1, slide_count, loop)
}

fn carousel_abs(value f64) f64 {
	return if value < 0 { -value } else { value }
}

// carousel_index_after_swipe resolves a completed drag in UI2's top-left
// coordinate system. Crossing min_move (a fraction of a slide's step) advances
// one position in the configured direction.
pub fn carousel_index_after_swipe(config CarouselConfig, delta_x f64, delta_y f64) !int {
	carousel_validate(config)!
	current := carousel_current(config)
	horizontal := carousel_horizontal(config)
	main_delta := if horizontal { delta_x } else { delta_y }
	cross_delta := if horizontal { delta_y } else { delta_x }
	extent := carousel_step(config)
	if extent <= 0 || (config.ignore_perpendicular_swipes
		&& carousel_abs(cross_delta) > carousel_abs(main_delta))
		|| carousel_abs(main_delta) / extent <= config.min_move {
		return current
	}
	advance := carousel_advance_distance(config, delta_x, delta_y) > 0
	return if advance {
		carousel_next_index(config) or { current }
	} else {
		carousel_previous_index(config) or { current }
	}
}

fn carousel_loop_offset(index int, current int, count int) int {
	if count <= 1 {
		return 0
	}
	raw := (index - current) % count
	forward := (raw + count) % count
	backward := forward - count
	return if forward <= -backward { forward } else { backward }
}

// carousel_view_offset is how many positions after the first visible slide a
// looping carousel places a slide: the visible ones ahead, the rest on the
// nearer side, so either neighbour is ready to slide in.
fn carousel_view_offset(index int, current int, count int, per_view int) int {
	forward := ((index - current) % count + count) % count
	if forward < per_view {
		return forward
	}
	return carousel_loop_offset(index, current, count)
}

// ── Geometry shared by both carousels ───────────────────────────────

fn carousel_horizontal(config CarouselConfig) bool {
	return config.direction in [.right, .left]
}

// carousel_loops reports whether navigation wraps: looping needs more slides
// than one view shows.
fn carousel_loops(config CarouselConfig) bool {
	return config.loop && config.slides.len > math.max(config.per_view, 1)
}

// carousel_max_index is the last index the carousel can rest on: the last
// slide when looping, otherwise the first slide of the last full view.
pub fn carousel_max_index(config CarouselConfig) int {
	count := config.slides.len
	if count == 0 {
		return 0
	}
	if carousel_loops(config) {
		return count - 1
	}
	return math.max(0, count - math.max(config.per_view, 1))
}

// carousel_current is config.index as the carousel shows it: wrapped when
// looping, otherwise clamped to 0..carousel_max_index.
pub fn carousel_current(config CarouselConfig) int {
	if config.slides.len == 0 {
		return 0
	}
	if carousel_loops(config) {
		return carousel_index(config.index, config.slides.len, true)
	}
	return math.max(0, math.min(config.index, carousel_max_index(config)))
}

// carousel_page_count is how many positions the carousel can rest on, the
// number of indicators it shows.
pub fn carousel_page_count(config CarouselConfig) int {
	return if config.slides.len == 0 { 0 } else { carousel_max_index(config) + 1 }
}

pub fn carousel_has_previous(config CarouselConfig) bool {
	return carousel_loops(config) || carousel_current(config) > 0
}

pub fn carousel_has_next(config CarouselConfig) bool {
	return carousel_loops(config) || carousel_current(config) < carousel_max_index(config)
}

// carousel_next_index is the index the next button selects, or none at the
// end of a carousel that does not loop.
pub fn carousel_next_index(config CarouselConfig) ?int {
	if config.slides.len == 0 || !carousel_has_next(config) {
		return none
	}
	current := carousel_current(config)
	return if current >= carousel_max_index(config) { 0 } else { current + 1 }
}

// carousel_previous_index is the index the previous button selects, or none
// at the start of a carousel that does not loop.
pub fn carousel_previous_index(config CarouselConfig) ?int {
	if config.slides.len == 0 || !carousel_has_previous(config) {
		return none
	}
	current := carousel_current(config)
	return if current <= 0 { carousel_max_index(config) } else { current - 1 }
}

// carousel_autoplay_index is where an autoplay tick goes: the next position,
// or back to the first after the last one of a carousel that does not loop.
// Schedule the ticks with `after`; see docs/gpui-kit/disclosure.md.
pub fn carousel_autoplay_index(config CarouselConfig) int {
	return carousel_next_index(config) or { 0 }
}

// carousel_advance_distance is how far a movement of the content goes toward
// the next slide: dragging the content left advances a carousel whose next
// slide is on the right.
fn carousel_advance_distance(config CarouselConfig, delta_x f64, delta_y f64) f64 {
	return match config.direction {
		.right { -delta_x }
		.left { delta_x }
		.bottom { -delta_y }
		.top { delta_y }
	}
}

// carousel_slide_extent is a slide's length along the carousel's axis.
fn carousel_slide_extent(config CarouselConfig, viewport Rect) f64 {
	per_view := math.max(config.per_view, 1)
	main := if carousel_horizontal(config) { viewport.width } else { viewport.height }
	return math.max(0.0, (main - f64(per_view - 1) * config.gap) / f64(per_view))
}

// carousel_step is the distance between the starts of neighbouring slides.
fn carousel_step(config CarouselConfig) f64 {
	viewport := carousel_viewport(config)
	return carousel_slide_extent(config, viewport) + config.gap
}

// carousel_frames places slides in their configured sequence around the
// current slide, relative to the viewport the slides are shown in (the whole
// frame unless controls or indicators take room; see carousel_layout). The
// current slide starts at the leading edge.
pub fn carousel_frames(config CarouselConfig) ![]Rect {
	carousel_validate(config)!
	if config.slides.len == 0 {
		return []
	}
	viewport := carousel_viewport(config)
	extent := carousel_slide_extent(config, viewport)
	step := extent + config.gap
	current := carousel_current(config)
	loops := carousel_loops(config)
	mut frames := []Rect{cap: config.slides.len}
	for index in 0 .. config.slides.len {
		offset := if loops {
			carousel_view_offset(index, current, config.slides.len, config.per_view)
		} else {
			index - current
		}
		position := f64(offset) * step
		frames << match config.direction {
			.right { rect(position, 0, extent, viewport.height) }
			.left { rect(viewport.width - extent - position, 0, extent, viewport.height) }
			.top { rect(0, viewport.height - extent - position, viewport.width, extent) }
			.bottom { rect(0, position, viewport.width, extent) }
		}
	}
	return frames
}

fn carousel_slide_label(index int, count int) string {
	return 'Slide ${index + 1} of ${count}'
}

// carousel_slide_semantics gives a slide the position upstream announces,
// unless the application named it.
fn carousel_slide_semantics(slide Element, index int, count int) Element {
	return Element{
		...slide
		accessibility_role:  if slide.accessibility_role.len > 0 {
			slide.accessibility_role
		} else {
			'group'
		}
		accessibility_label: if slide.accessibility_label.len > 0 {
			slide.accessibility_label
		} else {
			carousel_slide_label(index, count)
		}
	}
}

pub fn carousel(config CarouselConfig) !Element {
	if carousel_composed(config) {
		return carousel_compose(config)
	}
	frames := carousel_frames(config)!
	current := carousel_current(config)
	mut slides := []Element{cap: config.slides.len}
	for index, slide in config.slides {
		slides << Element{
			...carousel_slide_semantics(slide, index, config.slides.len)
			frame:  frames[index]
			hidden: slide.hidden || index != current
		}
	}
	return Element{
		...view(config.id, config.frame, config.box, slides)
		accessibility_role:  'group'
		accessibility_label: config.accessibility_label
		accessibility_value: if slides.len == 0 {
			'No slides'
		} else {
			carousel_slide_label(current, slides.len)
		}
	}
}
