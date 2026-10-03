// vfmt off
// Keep shared scroll state before ui_immediate.c.v in the module's file order.
// Globals inside a later file's platform $if are not visible to earlier uses.
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
	__global g_scroll_viewports = map[string]Rect{}
	// Offsets asked for before their scroll view existed. They are kept apart from
	// g_scroll_offsets because prune_unmounted_state drops the offset of every view
	// missing from a frame, which is exactly what a view that has not mounted yet is.
	__global g_pending_scroll = map[string]f64{}
	__global g_scroll_order = []string{}
	__global g_scroll_parents = map[string]string{}
	__global g_scrollbar_geometries = map[string]ScrollbarGeometry{}
	// The sideways axis of a Scroll element keeps the same state as the vertical
	// one, in maps of its own so a pane that only scrolls vertically pays nothing.
	__global g_scroll_offsets_x = map[string]f64{}
	__global g_scroll_content_w = map[string]f64{}
	__global g_pending_scroll_x = map[string]f64{}
	__global g_scrollbar_geometries_x = map[string]ScrollbarGeometry{}
	__global g_text_area_layouts = map[string]TextAreaLayout{}
}
