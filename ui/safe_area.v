module ui2

import math

// SafeInsets carries the operating-system intrusions around the edges of the
// window in logical units: the status bar, display notch, camera housing and
// home indicator on phones, and whatever similar chrome the desktop reserves.
// Sides without an intrusion report zero. Values come from safe_area_insets,
// which queries the platform, so they reflect the window the application runs
// in rather than a constant per device.
pub struct SafeInsets {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

// safe_side resolves one edge of the effective safe padding: the system inset
// when that side is enabled, the caller-supplied minimum otherwise, whichever
// is larger. Negative or non-finite inputs behave as zero.
fn safe_side(system f64, minimum f64, enabled bool) f64 {
	sys := if component_finite(system) && system > 0 { system } else { 0.0 }
	min := if component_finite(minimum) && minimum > 0 { minimum } else { 0.0 }
	if enabled && sys > min {
		return sys
	}
	return min
}

// safe_area_padding resolves the padding a safe container insets its content
// by, after Flutter's SafeArea: each enabled side takes the system intrusion,
// every side keeps at least its share of minimum, and the greater of the two
// wins. A disabled side contributes its minimum only.
pub fn safe_area_padding(left bool, top bool, right bool, bottom bool, minimum LayoutPadding) LayoutPadding {
	insets := safe_area_insets()
	return LayoutPadding{
		left:   safe_side(insets.left, minimum.left, left)
		top:    safe_side(insets.top, minimum.top, top)
		right:  safe_side(insets.right, minimum.right, right)
		bottom: safe_side(insets.bottom, minimum.bottom, bottom)
	}
}

// safe_validate_minimum rejects a minimum padding with negative or
// non-finite edges before it can shrink a safe container.
fn safe_validate_minimum(minimum LayoutPadding) ! {
	for value in [minimum.left, minimum.top, minimum.right, minimum.bottom] {
		if !component_finite(value) || value < 0 {
			return error('safe area minimum insets must be finite and non-negative')
		}
	}
}

// safe_content_rect insets frame by padding, clamping the remainder at zero
// so an intrusion larger than the frame leaves an empty box, not a negative one.
pub fn safe_content_rect(frame Rect, padding LayoutPadding) Rect {
	left := if padding.left > 0 { padding.left } else { 0.0 }
	top := if padding.top > 0 { padding.top } else { 0.0 }
	right := if padding.right > 0 { padding.right } else { 0.0 }
	bottom := if padding.bottom > 0 { padding.bottom } else { 0.0 }
	return rect(frame.x + left, frame.y + top, math.max(frame.width - left - right, 0),
		math.max(frame.height - top - bottom, 0))
}

pub struct SafeAreaConfig {
pub:
	id    string
	frame Rect
	// left, top, right and bottom choose which intrusions to avoid, after
	// Flutter's SafeArea flags of the same names. A skipped side still keeps
	// its share of minimum.
	left   bool = true
	top    bool = true
	right  bool = true
	bottom bool = true
	// minimum guarantees at least this much room on every side, even where the
	// platform reports no intrusion.
	minimum LayoutPadding
	// background paints the whole frame; the default stays transparent so the
	// container only adds room and never covers what is behind it.
	background ?u32
	// children are positioned relative to the safe content box: the frame
	// minus the resolved padding.
	children []Element
	label    string // accessibility label
}

// safe_area insets its children by the operating-system intrusions, after
// Flutter's SafeArea. The outer view keeps config.frame; the children live in
// a transparent content view inset by the resolved padding, so coordinates
// declared for them start at the safe top-left corner rather than the frame's.
pub fn safe_area(config SafeAreaConfig) !Element {
	component_validate_frame(config.frame)!
	safe_validate_minimum(config.minimum)!
	pad := safe_area_padding(config.left, config.top, config.right, config.bottom,
		config.minimum)
	inner := safe_content_rect(component_local(config.frame), pad)
	box := if bg := config.background {
		BoxStyle{ bg: bg }
	} else {
		BoxStyle{ transparent: true }
	}
	content := view('', inner, BoxStyle{ transparent: true }, config.children)
	return component_finish(Element{
		...view(config.id, config.frame, box, [content])
		accessibility_role:  'group'
		accessibility_label: config.label
	})
}

pub struct SafeViewportConfig {
pub:
	id    string
	frame Rect
	// left, top, right and bottom choose which intrusions to avoid, after
	// Flutter's SliverSafeArea flags of the same names. A skipped side still
	// keeps its share of minimum.
	left   bool = true
	top    bool = true
	right  bool = true
	bottom bool = true
	// minimum guarantees at least this much room on every side, even where the
	// platform reports no intrusion.
	minimum LayoutPadding
	// axis chooses the scrolled axes, as in scroll_with_mode.
	axis ScrollMode = .vertical_only
	// background paints the whole frame; the default stays transparent.
	background            ?u32
	persistent_scrollbars bool // keep a legacy always-visible scroller, as in scroll_persistent
	// children are positioned relative to the safe content origin: the frame's
	// top-left corner moved by the resolved top and left padding. The trailing
	// right and bottom padding extend the scroll range past the last child.
	children []Element
	label    string // accessibility label
}

// safe_viewport is a Scroll whose content clears the operating-system
// intrusions, after Flutter's SliverSafeArea. The scroll pane itself spans the
// whole frame, so scrollers run edge to edge, while the children start past
// the top and left padding and the scroll range covers the right and bottom
// padding past the last child.
pub fn safe_viewport(config SafeViewportConfig) !Element {
	component_validate_frame(config.frame)!
	safe_validate_minimum(config.minimum)!
	pad := safe_area_padding(config.left, config.top, config.right, config.bottom,
		config.minimum)
	mut content := []Element{cap: config.children.len + 1}
	mut reach_x := 0.0
	mut reach_y := 0.0
	for child in config.children {
		shifted := Element{
			...child
			frame: rect(child.frame.x + pad.left, child.frame.y + pad.top, child.frame.width,
				child.frame.height)
		}
		if !child.hidden {
			reach_x = math.max(reach_x, shifted.frame.x + shifted.frame.width)
			reach_y = math.max(reach_y, shifted.frame.y + shifted.frame.height)
		}
		content << shifted
	}
	width := reach_x + pad.right
	height := reach_y + pad.bottom
	if pad.right > 0 || pad.bottom > 0 {
		// A spacer at the far corner carries the trailing padding into the
		// scroll range, which reaches only as far as the children do.
		content << view('', rect(math.max(width - 1, 0), math.max(height - 1, 0), 1, 1),
			BoxStyle{ transparent: true }, []Element{})
	}
	box := if bg := config.background {
		BoxStyle{ bg: bg }
	} else {
		BoxStyle{ transparent: true }
	}
	return component_finish(Element{
		...scroll_with_mode(config.id, component_local(config.frame), 0xffffff, config.axis, content)
		box:                   box
		persistent_scrollbars: config.persistent_scrollbars
		accessibility_label:   config.label
	})
}
