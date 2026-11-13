module ui2

import math

// scaffold_content_rect returns the content box of a scaffold frame: the frame
// minus the top and bottom bar strips, clamped at zero so over-tall bars
// leave an empty box rather than a negative one. Bars keep their declared
// heights; the content absorbs the shortage.
pub fn scaffold_content_rect(frame Rect, top_bar_height f64, bottom_bar_height f64) Rect {
	top := if top_bar_height > 0 { top_bar_height } else { 0.0 }
	bottom := if bottom_bar_height > 0 { bottom_bar_height } else { 0.0 }
	return rect(frame.x, frame.y + top, frame.width, math.max(frame.height - top - bottom,
		0))
}

// scaffold_validate_sizes rejects bar heights and overlay margins that are
// negative or non-finite before they can warp a scaffold.
fn scaffold_validate_sizes(top_bar_height f64, bottom_bar_height f64, fab_margin f64, snackbar_margin f64) ! {
	for value in [top_bar_height, bottom_bar_height, fab_margin, snackbar_margin] {
		if !component_finite(value) || value < 0 {
			return error('scaffold bar heights and margins must be finite and non-negative')
		}
	}
}

// scaffold_place_end keeps an overlay's declared size and docks it at the
// content box's bottom end, inset by margin and clamped inside the box.
fn scaffold_place_end(content Rect, el Element, margin f64) Element {
	gap := if margin > 0 { margin } else { 0.0 }
	x := content.x + math.max(content.width - gap - el.frame.width, 0)
	y := content.y + math.max(content.height - gap - el.frame.height, 0)
	return Element{
		...el
		frame: rect(x, y, el.frame.width, el.frame.height)
	}
}

// scaffold_place_snackbar keeps a snackbar's declared height, stretches it
// across the content box inside margin, and docks it at the content bottom.
fn scaffold_place_snackbar(content Rect, el Element, margin f64) Element {
	gap := if margin > 0 { margin } else { 0.0 }
	width := math.max(content.width - 2 * gap, 0)
	y := content.y + math.max(content.height - gap - el.frame.height, 0)
	return Element{
		...el
		frame: rect(content.x + gap, y, width, el.frame.height)
	}
}

pub struct ScaffoldConfig {
pub:
	id    string
	frame Rect
	// top_bar_height and bottom_bar_height reserve the top and bottom strips.
	// The content box fills whatever is left between them.
	top_bar_height    f64
	bottom_bar_height f64
	// fab_margin insets the floating action from the content box's bottom end;
	// snackbar_margin insets the snackbar from the content box's sides and bottom.
	fab_margin      f64 = 16
	snackbar_margin f64 = 16
	// background paints the whole frame; the default stays transparent so the
	// scaffold only arranges and never covers what is behind it.
	background ?u32
	// top_bar children are positioned relative to the top strip, bottom_bar
	// children relative to the bottom strip, and content children relative to
	// the content box between the strips.
	top_bar    []Element
	content    []Element
	bottom_bar []Element
	// floating_action keeps its declared size and is docked at the content
	// box's bottom end; snackbar keeps its declared height, spans the content
	// width inside its margin, and docks at the content bottom. Both draw over
	// the content.
	floating_action ?Element
	snackbar        ?Element
	label           string // accessibility label
}

// scaffold lays a screen out the way Compose's Scaffold does: a top bar, a
// bottom bar, content filling the box between them, and optional floating
// action and snackbar overlays docked inside the content box. Slot elements
// keep their declared sizes; the scaffold chooses the strips they sit in and,
// for the overlays, their positions.
pub fn scaffold(config ScaffoldConfig) !Element {
	component_validate_frame(config.frame)!
	scaffold_validate_sizes(config.top_bar_height, config.bottom_bar_height, config.fab_margin,
		config.snackbar_margin)!
	local := component_local(config.frame)
	content := scaffold_content_rect(local, config.top_bar_height, config.bottom_bar_height)
	box := if bg := config.background {
		BoxStyle{ bg: bg }
	} else {
		BoxStyle{ transparent: true }
	}
	mut children := []Element{cap: 5}
	if config.top_bar_height > 0 || config.top_bar.len > 0 {
		children << view('', rect(0, 0, local.width, config.top_bar_height), BoxStyle{
			transparent: true
		}, config.top_bar)
	}
	children << view('', content, BoxStyle{ transparent: true }, config.content)
	if config.bottom_bar_height > 0 || config.bottom_bar.len > 0 {
		children << view('', rect(0, content.y + content.height, local.width, config.bottom_bar_height),
			BoxStyle{ transparent: true }, config.bottom_bar)
	}
	if fab := config.floating_action {
		children << scaffold_place_end(content, fab, config.fab_margin)
	}
	if bar := config.snackbar {
		children << scaffold_place_snackbar(content, bar, config.snackbar_margin)
	}
	return component_finish(Element{
		...view(config.id, config.frame, box, children)
		accessibility_label: config.label
	})
}
