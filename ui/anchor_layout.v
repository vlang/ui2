module ui2

pub enum HorizontalAnchor {
	left
	center
	right
}

pub enum VerticalAnchor {
	top
	center
	bottom
}

pub struct AnchorPadding {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

pub struct AnchorLayoutConfig {
pub:
	id       string
	frame    Rect
	box      BoxStyle
	anchor_x HorizontalAnchor = .center
	anchor_y VerticalAnchor   = .center
	padding  AnchorPadding
	children []Element
}

pub fn horizontal_anchor(value string) !HorizontalAnchor {
	return match value {
		'', 'center' { .center }
		'left' { .left }
		'right' { .right }
		else { return error('unknown horizontal anchor `${value}`') }
	}
}

pub fn vertical_anchor(value string) !VerticalAnchor {
	return match value {
		'', 'center' { .center }
		'top' { .top }
		'bottom' { .bottom }
		else { return error('unknown vertical anchor `${value}`') }
	}
}

// anchor_layout_frame positions one child inside the layout's local bounds.
// The child's width and height are preserved even when they exceed the bounds.
pub fn anchor_layout_frame(config AnchorLayoutConfig, child Rect) Rect {
	inner_width := config.frame.width - config.padding.left - config.padding.right
	inner_height := config.frame.height - config.padding.top - config.padding.bottom
	x := match config.anchor_x {
		.left { config.padding.left }
		.center { config.padding.left + (inner_width - child.width) / 2 }
		.right { config.frame.width - config.padding.right - child.width }
	}
	y := match config.anchor_y {
		.top { config.padding.top }
		.center { config.padding.top + (inner_height - child.height) / 2 }
		.bottom { config.frame.height - config.padding.bottom - child.height }
	}
	return rect(x, y, child.width, child.height)
}

// anchor_layout aligns every child to the same configured horizontal and
// vertical anchor. Child sizes are taken from their declared frames.
pub fn anchor_layout(config AnchorLayoutConfig) Element {
	mut children := []Element{cap: config.children.len}
	for child in config.children {
		children << Element{
			...child
			frame: anchor_layout_frame(config, child.frame)
		}
	}
	return view(config.id, config.frame, config.box, children)
}
