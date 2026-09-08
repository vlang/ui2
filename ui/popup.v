module ui2

pub struct PopupConfig {
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
	surface_box       BoxStyle
	title             string
	title_height      f64 = 48.0
	title_style       TextStyle
	separator_height  f64 = 1.0
	separator_box     BoxStyle
	content           Element
}

pub struct PopupGeometry {
pub:
	overlay   Rect
	surface   Rect
	title     Rect
	separator Rect
	body      Rect
}

pub fn popup_geometry(config PopupConfig) !PopupGeometry {
	if config.title_height < 0 || config.separator_height < 0 {
		return error('popup title and separator heights cannot be negative')
	}
	modal_geometry := modal_view_geometry(
		frame: config.frame
		content_width: config.content_width
		content_height: config.content_height
		size_hint_x: config.size_hint_x
		size_hint_y: config.size_hint_y
	)!
	if config.title_height + config.separator_height > modal_geometry.content.height {
		return error('popup title and separator exceed its content height')
	}
	return PopupGeometry{
		overlay: modal_geometry.overlay
		surface: modal_geometry.content
		title: rect(0, 0, modal_geometry.content.width, config.title_height)
		separator: rect(0, config.title_height, modal_geometry.content.width, config.separator_height)
		body: rect(0, config.title_height + config.separator_height, modal_geometry.content.width, modal_geometry.content.height - config.title_height - config.separator_height)
	}
}

fn popup_id(id string, suffix string) string {
	return if id.len > 0 { '${id}__${suffix}' } else { '' }
}

pub fn popup(config PopupConfig) !Element {
	geometry := popup_geometry(config)!
	title := label(popup_id(config.id, 'title'), config.title, geometry.title, config.title_style)
	separator := view(popup_id(config.id, 'separator'), geometry.separator, config.separator_box, [])
	content_source := if config.content.kind == .screen && config.content.id.len == 0
		&& config.content.children.len == 0 {
		view('', rect(0, 0, 0, 0), BoxStyle{ transparent: true }, [])
	} else {
		config.content
	}
	content := Element{
		...content_source
		frame: geometry.body
	}
	surface_content := view(popup_id(config.id, 'content'), rect(0, 0, geometry.surface.width, geometry.surface.height), BoxStyle{ transparent: true }, [
		title,
		separator,
		content,
	])
	return modal_view(
		id: config.id
		frame: config.frame
		open: config.open
		auto_dismiss: config.auto_dismiss
		dismiss_action_id: config.dismiss_action_id
		content_width: geometry.surface.width
		content_height: geometry.surface.height
		overlay_box: config.overlay_box
		content_box: config.surface_box
		content: surface_content
	)!
}
