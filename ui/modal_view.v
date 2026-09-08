module ui2

pub struct ModalViewConfig {
pub:
	id                string
	frame             Rect
	open              bool
	auto_dismiss      bool = true
	dismiss_action_id string
	content_width     f64 = -1.0
	content_height    f64 = -1.0
	size_hint_x       f64 = 0.8
	size_hint_y       f64 = 0.8
	overlay_box       BoxStyle
	content_box       BoxStyle
	content           Element
}

pub struct ModalViewGeometry {
pub:
	overlay Rect
	content Rect
}

fn modal_view_validate(config ModalViewConfig) ! {
	if config.frame.width < 0 || config.frame.height < 0 {
		return error('modal view dimensions cannot be negative')
	}
	if config.content_width < -1 || config.content_height < -1 {
		return error('modal content dimensions must be non-negative or -1')
	}
	if config.size_hint_x < 0 || config.size_hint_y < 0 {
		return error('modal size hints cannot be negative')
	}
}

fn modal_clamp_extent(value f64, available f64) f64 {
	if value < 0 {
		return 0
	}
	return if value < available { value } else { available }
}

pub fn modal_view_geometry(config ModalViewConfig) !ModalViewGeometry {
	modal_view_validate(config)!
	requested_width := if config.content_width >= 0 {
		config.content_width
	} else {
		config.frame.width * config.size_hint_x
	}
	requested_height := if config.content_height >= 0 {
		config.content_height
	} else {
		config.frame.height * config.size_hint_y
	}
	width := modal_clamp_extent(requested_width, config.frame.width)
	height := modal_clamp_extent(requested_height, config.frame.height)
	return ModalViewGeometry{
		overlay: rect(0, 0, config.frame.width, config.frame.height)
		content: rect((config.frame.width - width) / 2, (config.frame.height - height) / 2, width, height)
	}
}

fn modal_view_id(id string, suffix string) string {
	return if id.len > 0 { '${id}__${suffix}' } else { '' }
}

pub fn modal_view(config ModalViewConfig) !Element {
	geometry := modal_view_geometry(config)!
	backdrop := Element{
		...button(modal_view_id(config.id, 'backdrop'), '', geometry.overlay, config.overlay_box, TextStyle{})
		action_id: if config.auto_dismiss { config.dismiss_action_id } else { '' }
		accessibility_role: 'presentation'
	}
	// The surface button sits above the backdrop and consumes clicks in blank
	// content space; interactive content is rendered above it.
	surface := Element{
		...button(modal_view_id(config.id, 'surface'), '', geometry.content, config.content_box, TextStyle{})
		accessibility_role: 'presentation'
	}
	content_source := if config.content.kind == .screen && config.content.id.len == 0
		&& config.content.children.len == 0 {
		view('', rect(0, 0, 0, 0), BoxStyle{ transparent: true }, [])
	} else {
		config.content
	}
	content := Element{
		...content_source
		frame: geometry.content
	}
	return Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, [backdrop, surface, content])
		hidden: !config.open
		accessibility_role: 'dialog'
	}
}
