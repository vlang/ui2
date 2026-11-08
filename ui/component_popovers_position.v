// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/base/src/positioner.rs and the arrow geometry in
// crates/component/src/popover.rs. The side choice (the preferred side, else the
// opposite one, else the roomier one), alignment, window clamping and keeping an
// arrow clear of rounded corners are ported to V; the arrow built from strips and
// the rest of this file are new UI2 code. See third_party/gpui-kit.
module ui2

import math

// PopoverSide is the side of its anchor a floating surface opens on.
pub enum PopoverSide {
	top
	bottom
	left
	right
}

// PopoverAlign lines a surface up with its anchor along the side it opens on:
// the leading edges, the centers, or the trailing edges.
pub enum PopoverAlign {
	start
	center
	end
}

// PopoverPlacementConfig describes a surface of width x height to be placed next
// to anchor, all in window coordinates.
pub struct PopoverPlacementConfig {
pub:
	anchor Rect // The trigger, in window coordinates.
	window Rect // What the surface stays inside: pass ui2.bounds().
	width  f64
	height f64
	side   PopoverSide  = .bottom
	align  PopoverAlign = .start
	offset f64          = 4 // Gap between the anchor and the surface, or the arrow tip.
	margin f64          = 8 // Kept clear along every window edge.
	arrow  f64 // Arrow depth, added to the gap; zero means no arrow.
	radius f64 // Corner radius of the surface, which the arrow keeps clear of.
	flip   bool = true // Open on the opposite side when the preferred one has no room.
	shift  bool = true // Slide back inside the window when the surface would leave it.
}

pub struct PopoverPlacement {
pub:
	frame   Rect        // The surface, in window coordinates.
	side    PopoverSide // The side it opened on, after flipping.
	flipped bool
	// arrow is where the arrow tip sits along the edge facing the anchor: an x
	// for top and bottom placements, a y for left and right ones.
	arrow f64
}

fn popover_opposite_side(side PopoverSide) PopoverSide {
	return match side {
		.top { PopoverSide.bottom }
		.bottom { PopoverSide.top }
		.left { PopoverSide.right }
		.right { PopoverSide.left }
	}
}

fn popover_side_is_vertical(side PopoverSide) bool {
	return side == .top || side == .bottom
}

// PopoverLimits is the part of the window a surface may cover.
struct PopoverLimits {
	left   f64
	top    f64
	right  f64
	bottom f64
}

fn popover_limits(window Rect, margin f64) PopoverLimits {
	left := window.x + margin
	top := window.y + margin
	return PopoverLimits{
		left:   left
		top:    top
		right:  math.max(window.x + window.width - margin, left)
		bottom: math.max(window.y + window.height - margin, top)
	}
}

// popover_room is how much space the window leaves on one side of the anchor.
fn popover_room(side PopoverSide, anchor Rect, limits PopoverLimits) f64 {
	room := match side {
		.top { anchor.y - limits.top }
		.bottom { limits.bottom - (anchor.y + anchor.height) }
		.left { anchor.x - limits.left }
		.right { limits.right - (anchor.x + anchor.width) }
	}
	return math.max(room, 0)
}

// popover_resolve_side keeps the preferred side when the surface fits there,
// takes the opposite one when it fits there instead, and otherwise takes
// whichever of the two has more room.
fn popover_resolve_side(config PopoverPlacementConfig, limits PopoverLimits) PopoverSide {
	preferred := config.side
	if !config.flip {
		return preferred
	}
	other := popover_opposite_side(preferred)
	extent := if popover_side_is_vertical(preferred) { config.height } else { config.width }
	need := extent + config.offset + config.arrow
	preferred_room := popover_room(preferred, config.anchor, limits)
	other_room := popover_room(other, config.anchor, limits)
	if need <= preferred_room {
		return preferred
	}
	if need <= other_room || other_room > preferred_room {
		return other
	}
	return preferred
}

fn popover_aligned(align PopoverAlign, start f64, length f64, extent f64) f64 {
	return match align {
		.start { start }
		.center { start + (length - extent) / 2 }
		.end { start + length - extent }
	}
}

// popover_clamp slides a span inside [low, high]. When it is longer than the
// room it has, its start wins, so the leading content stays visible.
fn popover_clamp(start f64, extent f64, low f64, high f64) f64 {
	mut value := start
	if value + extent > high {
		value = high - extent
	}
	if value < low {
		value = low
	}
	return value
}

fn popover_clamp_value(value f64, low f64, high f64) f64 {
	return if high < low { (low + high) / 2 } else { math.min(math.max(value, low), high) }
}

// popover_place resolves where a floating surface goes: on the preferred side of
// its anchor, flipped to the opposite side when only that one has room, aligned
// along the side, and slid back inside the window. Coordinates are rounded to
// whole points so its edges and the arrow stay crisp.
pub fn popover_place(config PopoverPlacementConfig) !PopoverPlacement {
	component_validate_frame(config.anchor)!
	component_validate_frame(config.window)!
	for value in [config.width, config.height, config.margin, config.arrow, config.radius] {
		if !component_finite(value) || value < 0 {
			return error('popover size, margin, arrow and radius must be finite and non-negative')
		}
	}
	if !component_finite(config.offset) {
		return error('popover offset must be finite')
	}
	limits := popover_limits(config.window, config.margin)
	side := popover_resolve_side(config, limits)
	gap := config.offset + config.arrow
	anchor := config.anchor
	vertical := popover_side_is_vertical(side)
	mut x := 0.0
	mut y := 0.0
	if vertical {
		x = popover_aligned(config.align, anchor.x, anchor.width, config.width)
		y = if side == .bottom {
			anchor.y + anchor.height + gap
		} else {
			anchor.y - gap - config.height
		}
	} else {
		y = popover_aligned(config.align, anchor.y, anchor.height, config.height)
		x = if side == .right {
			anchor.x + anchor.width + gap
		} else {
			anchor.x - gap - config.width
		}
	}
	if config.shift {
		x = popover_clamp(x, config.width, limits.left, limits.right)
		y = popover_clamp(y, config.height, limits.top, limits.bottom)
	}
	x = math.round(x)
	y = math.round(y)
	mut arrow := 0.0
	if config.arrow > 0 {
		start := if vertical { x } else { y }
		length := if vertical { config.width } else { config.height }
		target := if vertical {
			anchor.x + anchor.width / 2
		} else {
			anchor.y + anchor.height / 2
		}
		half := math.min(config.arrow, length / 2)
		inset := math.min(config.radius + half, length / 2)
		arrow = math.round(popover_clamp_value(target, start + inset, start + length - inset))
	}
	return PopoverPlacement{
		frame:   rect(x, y, config.width, config.height)
		side:    side
		flipped: side != config.side
		arrow:   arrow
	}
}

// popover_arrow_strips stacks thin rectangles into a right-angled triangle whose
// base lies on the surface edge at `edge`, centered on `center`, and whose tip
// points `depth` away from the surface, toward the anchor. ui2 draws rectangles
// rather than paths, so the triangle is built from strips `step` thick.
//
// inset shrinks the triangle by a border width and extends its base that far
// into the surface: drawn in the surface color over a border-colored triangle,
// it leaves the border running along both slopes and opens the surface's own
// border where the arrow joins it.
fn popover_arrow_strips(side PopoverSide, edge f64, center f64, depth f64, inset f64, step f64) []Rect {
	mut strips := []Rect{}
	if depth <= 0 || step <= 0 {
		return strips
	}
	slope_inset := inset * math.sqrt2
	end := depth + inset
	mut distance := math.ceil(slope_inset / step) * step
	for distance < end - 1e-9 {
		next := math.min(distance + step, end)
		half := math.min((distance + next) / 2, depth) - slope_inset
		if half > 0 {
			thickness := next - distance
			strips << match side {
				// The surface is below its anchor: the arrow points up from its top edge.
				.bottom { rect(center - half, edge - depth + distance, 2 * half, thickness) }
				.top { rect(center - half, edge + depth - next, 2 * half, thickness) }
				.right { rect(edge - depth + distance, center - half, thickness, 2 * half) }
				.left { rect(edge + depth - next, center - half, thickness, 2 * half) }
			}
		}
		distance = next
	}
	return strips
}

// popover_union is the smallest rectangle covering both a and b.
fn popover_union(a Rect, b Rect) Rect {
	left := math.min(a.x, b.x)
	top := math.min(a.y, b.y)
	right := math.max(a.x + a.width, b.x + b.width)
	bottom := math.max(a.y + a.height, b.y + b.height)
	return rect(left, top, right - left, bottom - top)
}
