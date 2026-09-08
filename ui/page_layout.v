module ui2

pub struct PageLayoutConfig {
pub:
	id              string
	frame           Rect
	box             BoxStyle
	page            int
	border          f64 = 50.0
	swipe_threshold f64 = 0.5
	children        []Element
}

pub fn page_layout_page(page int, child_count int) int {
	if child_count <= 0 || page < 0 {
		return 0
	}
	return if page < child_count { page } else { child_count - 1 }
}

pub fn page_layout_next(page int, child_count int) int {
	return page_layout_page(page + 1, child_count)
}

pub fn page_layout_previous(page int, child_count int) int {
	return page_layout_page(page - 1, child_count)
}

fn page_abs(value f64) f64 {
	return if value < 0 { -value } else { value }
}

// page_layout_page_after_swipe converts a horizontal drag into a page index.
// Negative deltas advance and positive deltas return to the previous page.
pub fn page_layout_page_after_swipe(page int, child_count int, delta_x f64, width f64, threshold f64) int {
	current := page_layout_page(page, child_count)
	if width <= 0 || threshold < 0 || page_abs(delta_x) / width <= threshold {
		return current
	}
	return if delta_x < 0 {
		page_layout_next(current, child_count)
	} else {
		page_layout_previous(current, child_count)
	}
}

fn page_layout_validate(config PageLayoutConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('page layout dimensions cannot be negative (${config.frame.width}x${config.frame.height})')
	}
	if config.border < 0 || config.border > config.frame.width {
		return error('page layout border must be within its width')
	}
	if config.swipe_threshold < 0 {
		return error('page layout swipe threshold cannot be negative')
	}
}

// page_layout_frames exposes the current page and, where available, a border
// strip of the preceding and following pages. Frames are layout-local.
pub fn page_layout_frames(config PageLayoutConfig) ![]Rect {
	page_layout_validate(config)!
	if config.children.len == 0 {
		return []
	}
	page := page_layout_page(config.page, config.children.len)
	last := config.children.len - 1
	page_width := config.frame.width - config.border
	half_border := config.border / 2
	mut frames := []Rect{cap: config.children.len}
	for index in 0 .. config.children.len {
		x := if index < page {
			0.0
		} else if index == page {
			if page == 0 {
				0.0
			} else if page != last {
				half_border
			} else {
				config.border
			}
		} else if index == page + 1 {
			if page == 0 { config.frame.width - config.border } else { config.frame.width - half_border }
		} else {
			config.frame.width
		}
		frames << rect(x, 0, page_width, config.frame.height)
	}
	return frames
}

pub fn page_layout(config PageLayoutConfig) !Element {
	frames := page_layout_frames(config)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
