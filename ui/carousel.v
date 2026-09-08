module ui2

pub enum CarouselDirection {
	right
	left
	top
	bottom
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
// coordinate system. Crossing min_move advances in the configured direction.
pub fn carousel_index_after_swipe(config CarouselConfig, delta_x f64, delta_y f64) !int {
	carousel_validate(config)!
	current := carousel_index(config.index, config.slides.len, config.loop)
	horizontal := config.direction in [.right, .left]
	main_delta := if horizontal { delta_x } else { delta_y }
	cross_delta := if horizontal { delta_y } else { delta_x }
	extent := if horizontal { config.frame.width } else { config.frame.height }
	if extent <= 0 || (config.ignore_perpendicular_swipes
		&& carousel_abs(cross_delta) > carousel_abs(main_delta))
		|| carousel_abs(main_delta) / extent <= config.min_move {
		return current
	}
	advance := match config.direction {
		.right { main_delta < 0 }
		.left { main_delta > 0 }
		.top { main_delta > 0 }
		.bottom { main_delta < 0 }
	}
	return if advance {
		carousel_next(current, config.slides.len, config.loop)
	} else {
		carousel_previous(current, config.slides.len, config.loop)
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

// carousel_frames places slides in their configured sequence around the
// current slide. The current frame is always the carousel's local bounds.
pub fn carousel_frames(config CarouselConfig) ![]Rect {
	carousel_validate(config)!
	if config.slides.len == 0 {
		return []
	}
	current := carousel_index(config.index, config.slides.len, config.loop)
	mut frames := []Rect{cap: config.slides.len}
	for index in 0 .. config.slides.len {
		offset := if config.loop {
			carousel_loop_offset(index, current, config.slides.len)
		} else {
			index - current
		}
		frames << match config.direction {
			.right {
				rect(f64(offset) * config.frame.width, 0, config.frame.width, config.frame.height)
			}
			.left {
				rect(f64(-offset) * config.frame.width, 0, config.frame.width, config.frame.height)
			}
			.top {
				rect(0, f64(-offset) * config.frame.height, config.frame.width, config.frame.height)
			}
			.bottom {
				rect(0, f64(offset) * config.frame.height, config.frame.width, config.frame.height)
			}
		}
	}
	return frames
}

pub fn carousel(config CarouselConfig) !Element {
	frames := carousel_frames(config)!
	current := carousel_index(config.index, config.slides.len, config.loop)
	mut slides := []Element{cap: config.slides.len}
	for index, slide in config.slides {
		slides << Element{
			...slide
			frame: frames[index]
			hidden: slide.hidden || index != current
		}
	}
	return Element{
		...view(config.id, config.frame, config.box, slides)
		accessibility_role: 'group'
		accessibility_value: if slides.len == 0 {
			'No slides'
		} else {
			'Slide ${current + 1} of ${slides.len}'
		}
	}
}
