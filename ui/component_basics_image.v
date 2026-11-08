module ui2

import math
import os

// image_box is GPUI Kit's img() on top of ui2's image element: object fit,
// rounded and circular corners, a border, a selected ring for gallery
// thumbnails, and loading and fallback states that keep the image's box.
//
// The backends scale an image differently when left to themselves (AppKit keeps
// its aspect ratio inside the frame, the custom renderer stretches it to the
// frame), so image_box works out the rectangle the image covers itself, from
// its natural size, and hands the backend a frame of exactly the image's
// shape. A fit that crops (cover, or none on a large image) puts the image in
// an id-less Scroll element, the one ui2 element that clips, with nothing to
// scroll. ui2 views do not clip their children to rounded corners on every
// renderer either, so rounded corners are painted over with the color around
// the image (`backdrop`).

// ImageFit decides how an image is drawn inside its frame, after CSS's
// object-fit and GPUI's ObjectFit.
pub enum ImageFit {
	contain    // the whole image, aspect ratio kept; spare room stays empty
	cover      // fills the frame, aspect ratio kept; edges are cropped
	fill       // stretched to the frame; may distort
	scale_down // like contain, but never enlarged past its own size
	none       // its own size, cropped when larger than the frame
}

// ImageSize is an image's own size in pixels, drawn one point per pixel.
pub struct ImageSize {
pub:
	width  f64
	height f64
}

// ImageBoxStatus is what an image_box shows.
pub enum ImageBoxStatus {
	ready   // the image
	loading // the loading placeholder
	failed  // the fallback
}

pub struct ImageBoxConfig {
pub:
	id    string // Required with an action; names the loading shimmer and the corner mask.
	frame Rect
	path  string // An image file, or `symbol:<name>` for an icon.
	// alt describes an informative image to assistive technology. Leave it empty
	// for a decorative image.
	alt string
	fit ImageFit = .contain
	// position_x and position_y place the image in the room fit leaves, and pick
	// the part a crop keeps: 0 is the left or top edge, 0.5 the middle, 1 the
	// right or bottom edge (CSS object-position).
	position_x f64 = 0.5
	position_y f64 = 0.5
	// natural_width and natural_height are the image's own size. Zero reads it
	// from the file's header on every build; pass it in (image_natural_size reads
	// it once) for a grid of many images.
	natural_width  f64
	natural_height f64
	radius         f64  // Rounds the frame's corners.
	circle         bool // Rounds the shorter side fully: a circle in a square frame.
	bordered       bool
	// background fills the frame behind the image, showing in the room a
	// contained image leaves. None leaves it clear.
	background ?u32
	// backdrop is the color around the image, painted over the corners a radius
	// cuts away. It defaults to the theme's background.
	backdrop ?u32
	// tint colors a `symbol:` icon; it defaults to the theme's foreground.
	tint ?u32
	// loading shows the loading placeholder in the image's box, for an image the
	// application is still fetching or decoding.
	loading      bool
	loading_text string
	// failed shows the fallback, as a missing file or unknown symbol does.
	failed        bool
	fallback_text string
	fallback_icon string = 'photo' // A symbol name; empty shows the text alone.
	reduce_motion bool // The loading placeholder rests instead of shimmering.
	// action makes the image a button emitting it, such as a gallery thumbnail;
	// selected rings it in the primary color.
	action   string
	selected bool
	size     ComponentSize = .medium
	theme    ComponentTheme
}

// image_fit_rect is where an image natural_width x natural_height draws inside
// a frame width x height under fit, in the frame's coordinates. The result can
// reach past the frame (cover, or none on a large image); image_box clips it.
// position_x and position_y place it in the spare room, or choose which part a
// crop keeps, from 0 (left, top) to 1 (right, bottom). An unknown natural size
// fills the frame.
pub fn image_fit_rect(fit ImageFit, width f64, height f64, natural_width f64, natural_height f64, position_x f64, position_y f64) Rect {
	if !component_finite(natural_width) || !component_finite(natural_height)
		|| natural_width <= 0 || natural_height <= 0 || width <= 0 || height <= 0 {
		return rect(0, 0, math.max(width, 0), math.max(height, 0))
	}
	if fit == .fill {
		return rect(0, 0, width, height)
	}
	contain := math.min(width / natural_width, height / natural_height)
	scale := match fit {
		.contain { contain }
		.cover { math.max(width / natural_width, height / natural_height) }
		.scale_down { math.min(contain, 1.0) }
		.none { 1.0 }
		.fill { 1.0 }
	}
	drawn_w := natural_width * scale
	drawn_h := natural_height * scale
	px := basics_clamp(if component_finite(position_x) { position_x } else { 0.5 }, 0, 1)
	py := basics_clamp(if component_finite(position_y) { position_y } else { 0.5 }, 0, 1)
	return rect((width - drawn_w) * px, (height - drawn_h) * py, drawn_w, drawn_h)
}

// image_natural_size reads an image's own size from its file header: PNG,
// JPEG, GIF, BMP and WebP. It returns none for a file it cannot open or a
// format it does not know, and 1 x 1 for a `symbol:` icon, which is square.
// JPEG's EXIF orientation is not applied.
pub fn image_natural_size(path string) ?ImageSize {
	if _ := symbol_name(path) {
		return ImageSize{1, 1}
	}
	if path.trim_space().len == 0 {
		return none
	}
	mut f := os.open(path) or { return none }
	defer {
		f.close()
	}
	head := f.read_bytes_at(32, 0)
	if head.len < 10 {
		return none
	}
	if head.len >= 24 && head[0] == 0x89 && head[1] == `P` && head[2] == `N` && head[3] == `G` {
		return image_size_checked(basics_be32(head, 16), basics_be32(head, 20))
	}
	if head[0] == `G` && head[1] == `I` && head[2] == `F` {
		return image_size_checked(basics_le16(head, 6), basics_le16(head, 8))
	}
	if head[0] == `B` && head[1] == `M` && head.len >= 26 {
		if basics_le32(head, 14) == 12 {
			return image_size_checked(basics_le16(head, 18), basics_le16(head, 20))
		}
		height := i32(u32(basics_le32(head, 22)))
		return image_size_checked(basics_le32(head, 18), math.abs(i64(height)))
	}
	if head.len >= 30 && head[0] == `R` && head[1] == `I` && head[2] == `F` && head[3] == `F`
		&& head[8] == `W` && head[9] == `E` && head[10] == `B` && head[11] == `P` {
		return image_webp_size(head)
	}
	if head[0] == 0xff && head[1] == 0xd8 {
		return image_jpeg_size(f)
	}
	return none
}

fn image_size_checked(width i64, height i64) ?ImageSize {
	if width <= 0 || height <= 0 {
		return none
	}
	return ImageSize{f64(width), f64(height)}
}

fn basics_be32(b []u8, at int) i64 {
	return (i64(b[at]) << 24) | (i64(b[at + 1]) << 16) | (i64(b[at + 2]) << 8) | i64(b[at + 3])
}

fn basics_be16(b []u8, at int) i64 {
	return (i64(b[at]) << 8) | i64(b[at + 1])
}

fn basics_le16(b []u8, at int) i64 {
	return i64(b[at]) | (i64(b[at + 1]) << 8)
}

fn basics_le24(b []u8, at int) i64 {
	return i64(b[at]) | (i64(b[at + 1]) << 8) | (i64(b[at + 2]) << 16)
}

fn basics_le32(b []u8, at int) i64 {
	return i64(b[at]) | (i64(b[at + 1]) << 8) | (i64(b[at + 2]) << 16) | (i64(b[at + 3]) << 24)
}

// image_webp_size reads the first chunk of a WebP file: lossy (VP8), lossless
// (VP8L) or extended (VP8X).
fn image_webp_size(head []u8) ?ImageSize {
	chunk := head[12..16].bytestr()
	match chunk {
		'VP8 ' {
			return image_size_checked(basics_le16(head, 26) & 0x3fff, basics_le16(head, 28) & 0x3fff)
		}
		'VP8L' {
			if head[20] != 0x2f {
				return none
			}
			b1 := i64(head[22])
			b2 := i64(head[23])
			b3 := i64(head[24])
			width := 1 + (i64(head[21]) | ((b1 & 0x3f) << 8))
			height := 1 + ((b1 >> 6) | (b2 << 2) | ((b3 & 0x0f) << 10))
			return image_size_checked(width, height)
		}
		'VP8X' {
			return image_size_checked(1 + basics_le24(head, 24), 1 + basics_le24(head, 27))
		}
		else {
			return none
		}
	}
}

// image_jpeg_size walks a JPEG's segments to its start-of-frame code, seeking
// past the ones in between (EXIF thumbnails can be large).
fn image_jpeg_size(f os.File) ?ImageSize {
	mut pos := u64(2)
	for _ in 0 .. 1024 {
		seg := f.read_bytes_at(9, pos)
		if seg.len < 4 || seg[0] != 0xff {
			return none
		}
		code := seg[1]
		if code == 0xff {
			pos++
			continue
		}
		if code == 0x01 || (code >= 0xd0 && code <= 0xd8) {
			pos += 2
			continue
		}
		if code == 0xd9 || code == 0xda {
			return none
		}
		is_frame := code >= 0xc0 && code <= 0xcf && code != 0xc4 && code != 0xc8
			&& code != 0xcc
		if is_frame {
			if seg.len < 9 {
				return none
			}
			return image_size_checked(basics_be16(seg, 7), basics_be16(seg, 5))
		}
		pos += 2 + u64(basics_be16(seg, 2))
	}
	return none
}

// image_box_status is what an image_box built from config shows: the
// fallback when it failed or its file or symbol is missing, the placeholder
// while it loads, the image otherwise.
pub fn image_box_status(config ImageBoxConfig) ImageBoxStatus {
	if config.failed {
		return .failed
	}
	if config.loading {
		return .loading
	}
	if name := symbol_name(config.path) {
		return if symbol_known(name) { .ready } else { .failed }
	}
	if config.path.trim_space().len == 0 || !os.is_file(config.path) {
		return .failed
	}
	return .ready
}

// image_box_stop_loading ends the shimmer an image_box with an id runs while
// it is loading. Call it once the image arrives (or fails): like every looping
// feedback animation, the sweep otherwise keeps the window redrawing after the
// placeholder has left the tree.
pub fn image_box_stop_loading(id string) {
	stop_feedback_animations(component_part_id(id, 'loading'))
}

// image_box_corner_radius is the radius image_box rounds its frame with.
pub fn image_box_corner_radius(config ImageBoxConfig) f64 {
	limit := math.min(config.frame.width, config.frame.height) / 2
	if config.circle {
		return limit
	}
	return math.min(math.max(config.radius, 0), limit)
}

fn image_box_natural(config ImageBoxConfig) ?ImageSize {
	if component_finite(config.natural_width) && component_finite(config.natural_height)
		&& config.natural_width > 0 && config.natural_height > 0 {
		return ImageSize{config.natural_width, config.natural_height}
	}
	return image_natural_size(config.path)
}

// image_box_picture is the image placed by fit, inside a clipping Scroll
// element when it reaches past the frame. The Scroll's one child ends exactly
// at its right edge and is no taller than the overflow it hides, so there is
// nothing to scroll.
fn image_box_picture(config ImageBoxConfig, local Rect) Element {
	drawn := if natural := image_box_natural(config) {
		image_fit_rect(config.fit, local.width, local.height, natural.width, natural.height,
			config.position_x, config.position_y)
	} else {
		local
	}
	picture := Element{
		...image('', config.path, drawn)
		text_style: TextStyle{
			color: config.tint or { config.theme.foreground }
		}
	}
	slack := 0.01
	if drawn.x >= -slack && drawn.y >= -slack && drawn.x + drawn.width <= local.width + slack
		&& drawn.y + drawn.height <= local.height + slack {
		return picture
	}
	content := view('', rect(drawn.x, drawn.y, local.width - drawn.x, drawn.height), BoxStyle{
		transparent: true
	}, [
		Element{
			...picture
			frame: rect(0, 0, drawn.width, drawn.height)
		},
	])
	return Element{
		...scroll_with_mode('', local, 0, .horizontal_only, [content])
		box: BoxStyle{
			transparent: true
		}
	}
}

fn image_box_loading(config ImageBoxConfig, local Rect, radius f64) ![]Element {
	mut children := []Element{}
	if config.id.len > 0 && !config.reduce_motion {
		children << shimmer(
			id:     component_part_id(config.id, 'loading')
			frame:  local
			shapes: [ShimmerShape{
				frame:  local
				radius: radius
			}]
			theme:  config.theme
		)!
	} else {
		children << view('', local, BoxStyle{
			bg:     config.theme.muted
			radius: radius
		}, []Element{})
	}
	if config.loading_text.len > 0 {
		children << image_box_caption(config.loading_text, local, local.height / 2 - 10,
			config)
	}
	return children
}

fn image_box_caption(text string, local Rect, y f64, config ImageBoxConfig) Element {
	short := math.min(local.width, local.height)
	font := basics_clamp(math.round(short * 0.17), 10, component_metrics(config.size).font_size - 1)
	return label('', text, rect(2, y, math.max(local.width - 4, 0), 20), TextStyle{
		color: config.theme.muted_foreground
		size:  font
		align: .center
	})
}

fn image_box_fallback(config ImageBoxConfig, local Rect, radius f64) []Element {
	mut children := [
		view('', local, BoxStyle{
			bg:     config.theme.muted
			radius: radius
		}, []Element{}),
	]
	has_icon := config.fallback_icon.len > 0 && symbol_known(config.fallback_icon)
	has_text := config.fallback_text.len > 0
	short := math.min(local.width, local.height)
	if has_icon {
		icon := math.round(basics_clamp(short * 0.36, 12, 32))
		text_room := has_text && local.height >= icon + 34
		top := if text_room {
			(local.height - icon - 22) / 2
		} else {
			(local.height - icon) / 2
		}
		children << basics_symbol(config.fallback_icon, rect((local.width - icon) / 2, top,
			icon, icon), config.theme.muted_foreground)
		if text_room {
			children << image_box_caption(config.fallback_text, local, top + icon + 4,
				config)
		}
	} else if has_text {
		children << label('', config.fallback_text, local, TextStyle{
			color: config.theme.muted_foreground
			size:  basics_clamp(short * 0.36, 11, 28)
			bold:  true
			align: .center
		})
	}
	return children
}

// image_box draws an image in its frame by fit, with optional rounded or
// circular corners, a border, and a selected ring, or the loading placeholder
// or fallback in the same box. With an action it is a button.
pub fn image_box(config ImageBoxConfig) !Element {
	component_validate_frame(config.frame)!
	if config.action.len > 0 {
		component_validate_id(config.id)!
	}
	if !component_finite(config.radius) || config.radius < 0 {
		return error('image radius must be finite and non-negative')
	}
	local := component_local(config.frame)
	radius := image_box_corner_radius(config)
	status := image_box_status(config)
	mut children := []Element{}
	match status {
		.loading {
			children << image_box_loading(config, local, radius)!
		}
		.failed {
			children << image_box_fallback(config, local, radius)
		}
		.ready {
			if bg := config.background {
				children << view('', local, BoxStyle{
					bg:     bg
					radius: radius
				}, []Element{})
			}
			children << image_box_picture(config, local)
			if radius > 0 {
				mut corners := path_rect(local)
				corners << path_rounded_rect(local, radius)
				children << shape(component_part_id(config.id, 'corners'), local, corners,
					ShapeStyle{
						fill:      config.backdrop or { config.theme.background }
						fill_rule: .even_odd
					})
			}
		}
	}
	if config.bordered && local.width > 1 && local.height > 1 {
		children << shape(component_part_id(config.id, 'border'), local, path_rounded_rect(rect(0.5,
			0.5, local.width - 1, local.height - 1), math.max(radius - 0.5, 0)), ShapeStyle{
			stroke:       config.theme.border
			stroke_width: 1
		})
	}
	if config.selected && local.width > 4 && local.height > 4 {
		children << shape(component_part_id(config.id, 'ring'), local, path_rounded_rect(rect(1,
			1, local.width - 2, local.height - 2), math.max(radius - 1, 0)), ShapeStyle{
			stroke:       config.theme.primary
			stroke_width: 2
		})
	}
	description := match status {
		.loading {
			if config.loading_text.len > 0 { config.loading_text } else { 'Loading image' }
		}
		.failed {
			if config.fallback_text.len > 0 { config.fallback_text } else { config.alt }
		}
		.ready { config.alt }
	}
	root := Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  if description.len > 0 { 'img' } else { 'presentation' }
		accessibility_label: description
		accessibility_value: if config.selected { 'selected' } else { '' }
	}
	if config.action.len == 0 {
		return component_finish(root)
	}
	return component_finish(Element{
		...with_button_behavior(root)
		action_id:           config.action
		cursor:              cursor_pointing_hand
		accessibility_role:  'button'
		accessibility_label: description
	})
}
