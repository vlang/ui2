module ui2

pub struct RelativeLayoutConfig {
pub:
	id       string
	frame    Rect
	box      BoxStyle
	children []FloatLayoutChild
}

fn relative_as_float(config RelativeLayoutConfig) FloatLayoutConfig {
	return FloatLayoutConfig{
		id: config.id
		frame: config.frame
		box: config.box
		children: config.children
	}
}

// relative_layout_frames returns frames in layout-local coordinates. The
// layout's own x and y never leak into its child geometry.
pub fn relative_layout_frames(config RelativeLayoutConfig) ![]Rect {
	return float_layout_frames(relative_as_float(config))
}

pub fn relative_layout(config RelativeLayoutConfig) !Element {
	frames := relative_layout_frames(config)!
	mut children := []Element{cap: config.children.len}
	for index, child in config.children {
		children << Element{
			...child.element
			frame: frames[index]
		}
	}
	return view(config.id, config.frame, config.box, children)
}
