// vfmt off
// Keep shared scroll types before ui_immediate.c.v in the module's file order.
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	struct ScrollbarGeometry {
		track Rect
		thumb Rect
	}

	struct TextAreaLayout {
		text          string
		width         f64
		style         TextStyle
		rendered_size int
		lines         []string
	}

	// Viewports are full layout boxes; areas are their visible, hittable parts.
	// Using the clipped height for the range makes nested panes overscroll.
}
