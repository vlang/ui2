module ui2

import math

// IconName lists GPUI Kit's Lucide icon names that have a counterpart every ui2
// backend can draw: an SF Symbol on AppKit and UIKit that ui/symbols.v also maps
// to a Material Icons glyph of the same meaning for the other renderers. The
// first group is from GPUI's default component set, the second from the wider
// Lucide catalog. `padlock` is Lucide's Lock, which is a V keyword.
pub enum IconName {
	a_large_small
	case_sensitive
	chevrons_up_down
	circle_user
	close
	copy
	dash
	delete
	ellipsis
	eye
	eye_off
	folder
	folder_closed
	info
	layout_dashboard
	menu
	minus
	palette
	panel_right
	plus
	redo
	redo_2
	refresh_cw
	rotate_cw
	search
	settings
	settings_2
	star
	undo
	undo_2
	window_close
	window_minimize
	align_justify
	align_left
	align_right
	badge
	book_a
	box
	braces
	chart_column
	clipboard_list
	cloud_download
	cloud_upload
	columns_3
	copy_plus
	crop
	download
	file_plus
	file_up
	hash
	history
	image
	indent_increase
	layers
	layout_grid
	list_ordered
	message_square_text
	mouse_pointer
	move_horizontal
	move_vertical
	padlock
	paintbrush
	pencil
	printer
	repeat
	scissors
	share
	square_function
	square_minus
	square_plus
	table
	tag
	user_round_plus
	users
}

// symbol is the SF Symbol an icon draws as; symbol_known is true for each.
pub fn (name IconName) symbol() string {
	return match name {
		.a_large_small { 'textformat.size' }
		.case_sensitive { 'textformat' }
		.chevrons_up_down, .move_vertical { 'arrow.up.and.down' }
		.circle_user { 'person.crop.circle' }
		.close, .window_close { 'xmark' }
		.copy { 'doc.on.doc' }
		.dash, .minus, .window_minimize { 'minus' }
		.delete { 'trash' }
		.ellipsis { 'ellipsis' }
		.eye { 'eye' }
		.eye_off { 'eye.slash' }
		.folder, .folder_closed { 'folder' }
		.info { 'info.circle' }
		.layout_dashboard { 'rectangle.3.group' }
		.menu { 'line.3.horizontal' }
		.palette { 'paintpalette' }
		.panel_right { 'sidebar.right' }
		.plus { 'plus' }
		.redo, .redo_2 { 'arrow.uturn.forward' }
		.refresh_cw, .rotate_cw { 'arrow.clockwise' }
		.search { 'magnifyingglass' }
		.settings { 'gearshape' }
		.settings_2 { 'slider.horizontal.3' }
		.star { 'star' }
		.undo, .undo_2 { 'arrow.uturn.backward' }
		.align_justify { 'text.justify' }
		.align_left { 'text.alignleft' }
		.align_right { 'text.alignright' }
		.badge { 'seal' }
		.book_a { 'character.book.closed' }
		.box { 'cube.transparent' }
		.braces { 'curlybraces' }
		.chart_column { 'chart.bar' }
		.clipboard_list { 'list.bullet.clipboard' }
		.cloud_download { 'icloud.and.arrow.down' }
		.cloud_upload { 'icloud.and.arrow.up' }
		.columns_3 { 'rectangle.split.3x1' }
		.copy_plus { 'plus.square.on.square' }
		.crop { 'crop' }
		.download { 'arrow.down.to.line' }
		.file_plus { 'doc.badge.plus' }
		.file_up { 'doc.badge.arrow.up' }
		.hash { 'number' }
		.history { 'clock.arrow.circlepath' }
		.image { 'photo' }
		.indent_increase { 'increase.indent' }
		.layers { 'square.stack.3d.up' }
		.layout_grid { 'rectangle.grid.2x2' }
		.list_ordered { 'list.number' }
		.message_square_text { 'text.bubble' }
		.mouse_pointer { 'cursorarrow' }
		.move_horizontal { 'arrow.left.and.right' }
		.padlock { 'lock' }
		.paintbrush { 'paintbrush' }
		.pencil { 'pencil' }
		.printer { 'printer' }
		.repeat { 'arrow.2.squarepath' }
		.scissors { 'scissors' }
		.share { 'square.and.arrow.up' }
		.square_function { 'function' }
		.square_minus { 'minus.rectangle' }
		.square_plus { 'plus.rectangle' }
		.table { 'tablecells' }
		.tag { 'tag' }
		.user_round_plus { 'person.crop.circle.badge.plus' }
		.users { 'person.2' }
	}
}

// title is the icon's name in words, its default accessibility label.
pub fn (name IconName) title() string {
	words := name.str().replace('_', ' ')
	return words[..1].to_upper() + words[1..]
}

// icon_names lists every IconName, in declaration order.
pub fn icon_names() []IconName {
	mut names := []IconName{}
	$for value in IconName.values {
		names << value.value
	}
	return names
}

// icon_pixel_size returns GPUI's icon size for a size preset.
pub fn icon_pixel_size(size ComponentSize) f64 {
	return match size {
		.small { 14 }
		.medium { 16 }
		.large { 24 }
	}
}

pub struct IconConfig {
pub:
	id    string
	frame Rect
	name  IconName
	// symbol draws this SF Symbol instead of name. It must be a name
	// symbol_known accepts, so it renders on every backend.
	symbol string
	// pixel_size is the icon's side, centered in frame and limited to it. Zero
	// uses the size preset: small 14, medium 16, large 24 (GPUI's xsmall is 12).
	pixel_size f64
	color      ?u32 // Defaults to the theme's foreground.
	// rotation turns the icon clockwise, in degrees. The custom renderer draws
	// symbols upright, so rotation is honored by AppKit and UIKit only.
	rotation            f64
	size                ComponentSize = .medium
	accessibility_label string // Defaults to the icon's title.
	theme               ComponentTheme
}

// named_icon draws a named icon as a symbol image tinted with its color. The
// returned image is the icon's square, centered in frame. GPUI's Icon also
// takes SVG paths and bytes; ui2 draws arbitrary files with image().
pub fn named_icon(config IconConfig) !Element {
	component_validate_frame(config.frame)!
	feedback_validate_length('icon size', config.pixel_size)!
	if !component_finite(config.rotation) {
		return error('icon rotation must be finite')
	}
	symbol := if config.symbol.len > 0 { config.symbol } else { config.name.symbol() }
	if !symbol_known(symbol) {
		return error('icon symbol `${symbol}` is not drawn on every backend; see symbol_names()')
	}
	side := math.min(if config.pixel_size > 0 {
		config.pixel_size
	} else {
		icon_pixel_size(config.size)
	}, math.min(config.frame.width, config.frame.height))
	color := config.color or { config.theme.foreground }
	return component_finish(Element{
		...image(config.id, 'symbol:' + symbol, rect(config.frame.x + (config.frame.width - side) / 2,
			config.frame.y + (config.frame.height - side) / 2, side, side))
		text_style:          TextStyle{
			color: color
			size:  side
		}
		rotation:            config.rotation
		accessibility_role:  'img'
		accessibility_label: if config.accessibility_label.len > 0 {
			config.accessibility_label
		} else if config.symbol.len > 0 {
			config.symbol
		} else {
			config.name.title()
		}
	})
}
