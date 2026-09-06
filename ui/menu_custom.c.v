// vfmt off
// The custom renderer has no platform menu bar to hand a declaration to, so it
// draws one across the top of the window and reserves that strip from the
// screen it lays elements out in. Keep the gg import inside the platform block
// for the same reason ui_immediate.c.v does.
@[has_globals]
module ui2

$if android || linux || ((macos || windows) && ui2_custom_rendering ?) {
	import gg

	const menubar_height = 26.0
	const menubar_title_padding = 12.0
	const menubar_row_height = 24.0
	const menubar_separator_height = 9.0
	const menubar_panel_padding = 4.0
	const menubar_panel_min_width = 168.0
	const menubar_panel_max_width = 420.0
	// Rows leave room for a check mark on the left and for the shortcut, or a
	// submenu arrow, on the right.
	const menubar_row_indent = 26.0
	const menubar_row_tail = 26.0
	const menubar_edge_margin = 2.0

	const menubar_background = u32(0xeef2f7)
	const menubar_border = u32(0xd7dee8)
	const menubar_text = u32(0x1f2937)
	const menubar_disabled_text = u32(0x9aa5b1)
	const menubar_highlight = u32(0xdbeafe)
	const menubar_panel_background = u32(0xffffff)
	const menubar_panel_shadow = u32(0xdbe2ea)
	const menubar_shortcut_text = u32(0x64748b)
	const menubar_separator_color = u32(0xe2e8f0)

	// MenuBarHit is one clickable region of the drawn bar. `path` locates it:
	// a one element path is a bar title, a longer one walks down the open
	// panels, so its last element is the row's index in the deepest one.
	struct MenuBarHit {
		x         f64
		y         f64
		w         f64
		h         f64
		path      []int
		id        string
		enabled   bool
		has_items bool
		is_title  bool
	}

	// g_menu_open_path holds one element per open panel: [m] is menu m's own
	// list, [m, r] adds the submenu opened from row r of that list.
	__global g_menu_open_path = []int{}
	__global g_menu_hover_path = []int{}
	__global g_menu_hits = []MenuBarHit{}
	__global g_menu_panels = []Rect{}
	// A press that only dismissed an open menu must not let the matching
	// release reach the control underneath it.
	__global g_menu_swallow_up = false

	// menu_bar_height is the strip the bar takes off the top of the window.
	// bounds() subtracts it and the screen is drawn below it, so an element at
	// y 0 sits under the bar rather than behind it.
	fn menu_bar_height() f64 {
		return if menu_bar().len == 0 { 0.0 } else { menubar_height }
	}

	fn menu_bar_open() bool {
		return g_menu_open_path.len > 0
	}

	fn close_menu_bar() {
		g_menu_open_path = []int{}
		g_menu_hover_path = []int{}
	}

	// ── Drawing ────────────────────────────────────────────────────────

	fn menu_bar_title_style() TextStyle {
		return TextStyle{
			color: menubar_text
			size: 13
			align: .left
		}
	}

	fn menu_bar_row_style(enabled bool) TextStyle {
		return TextStyle{
			color: if enabled { menubar_text } else { menubar_disabled_text }
			size: 13
			align: .left
		}
	}

	fn menu_bar_shortcut_style(enabled bool) TextStyle {
		return TextStyle{
			color: if enabled { menubar_shortcut_text } else { menubar_disabled_text }
			size: 12
			align: .right
		}
	}

	// menu_text_width measures a string the way draw_text will render it, so a
	// title's box is exactly as wide as its text needs.
	fn menu_text_width(ctx &gg.Context, t string, style TextStyle) f64 {
		if t.len == 0 {
			return 0.0
		}
		family := text_font_file(style.font_family, style.bold, style.italic)
		ensure_family_fallbacks(ctx, family)
		ctx.set_text_cfg(gg.TextCfg{
			color: hex_color(style.color)
			size: int(font_render_size(style.size, text_font_metrics(family)) + 0.5)
			bold: style.bold
			italic: style.italic
			family: family
			align: .left
			vertical_align: .middle
		})
		return f64(ctx.text_width_f(t))
	}

	// draw_menu_bar draws the bar and every open panel, and rebuilds the hit
	// list the pointer handlers read. It runs after the element tree so the
	// panels float above the window's own controls.
	fn draw_menu_bar(ctx &gg.Context) {
		menus := menu_bar()
		g_menu_hits = []MenuBarHit{}
		g_menu_panels = []Rect{}
		if menus.len == 0 {
			return
		}
		window := rect(0, 0, f64(ctx.width), f64(ctx.height))
		apply_clip(ctx, window)
		draw_rect(ctx, 0, 0, window.width, menubar_height, menubar_background, 0)
		draw_rect(ctx, 0, menubar_height - 1, window.width, 1, menubar_border, 0)
		style := menu_bar_title_style()
		mut x := menubar_edge_margin + 4.0
		mut open_x := x
		for index, m in menus {
			w := menu_text_width(ctx, m.title, style) + menubar_title_padding * 2
			if menu_bar_open() && g_menu_open_path[0] == index {
				draw_rect(ctx, x, 2, w, menubar_height - 5, menubar_highlight, 5)
				open_x = x
			}
			draw_text(ctx, m.title, x + menubar_title_padding, 0, w - menubar_title_padding * 2,
				menubar_height - 1, style)
			g_menu_hits << MenuBarHit{
				x: x
				y: 0
				w: w
				h: menubar_height
				path: [index]
				enabled: true
				has_items: m.items.len > 0
				is_title: true
			}
			x += w
		}
		if !menu_bar_open() {
			return
		}
		open := g_menu_open_path[0]
		if open < 0 || open >= menus.len {
			close_menu_bar()
			return
		}
		draw_menu_panel(ctx, menus[open].items, [open], open_x, menubar_height, window)
	}

	// draw_menu_panel draws one list and, when the open path goes deeper,
	// recurses into the submenu it names.
	fn draw_menu_panel(ctx &gg.Context, items []MenuItem, path []int, anchor_x f64, anchor_y f64, window Rect) {
		if items.len == 0 {
			return
		}
		width := menu_panel_width(ctx, items)
		height := menu_panel_height(items)
		x := clamp_menu_coordinate(anchor_x, width, window.width)
		y := clamp_menu_coordinate(anchor_y, height, window.height)
		g_menu_panels << rect(x, y, width, height)
		draw_rect(ctx, x + 1, y + 2, width, height, menubar_panel_shadow, 6)
		draw_rect(ctx, x, y, width, height, menubar_panel_background, 6)
		draw_outline(ctx, x, y, width, height, menubar_border, 6)
		mut row_y := y + menubar_panel_padding
		mut child_items := []MenuItem{}
		mut child_x := 0.0
		mut child_y := 0.0
		for index, item in items {
			if item.separator {
				draw_rect(ctx, x + 8, row_y + menubar_separator_height / 2, width - 16, 1,
					menubar_separator_color, 0)
				row_y += menubar_separator_height
				continue
			}
			row_path := arrays_append_int(path, index)
			hovered := int_paths_equal(g_menu_hover_path, row_path)
				|| (item.items.len > 0 && menu_path_starts_with(g_menu_open_path, row_path))
			if hovered && item.enabled {
				draw_rect(ctx, x + 2, row_y, width - 4, menubar_row_height, menubar_highlight,
					4)
			}
			if item.checked {
				mark := 13.0
				draw_check_mark(ctx, x + 7, row_y + (menubar_row_height - mark) / 2, mark,
					menu_bar_row_style(item.enabled).color)
			}
			label_width := width - menubar_row_indent - menubar_row_tail
			draw_text(ctx, item.title, x + menubar_row_indent, row_y, label_width, menubar_row_height,
				menu_bar_row_style(item.enabled))
			if item.items.len > 0 {
				draw_submenu_arrow(ctx, x + width - 14, row_y + menubar_row_height / 2,
					menu_bar_row_style(item.enabled).color)
			} else {
				shortcut := menu_shortcut_label(item.shortcut)
				if shortcut.len > 0 {
					draw_text(ctx, shortcut, x + width - menubar_row_tail - 60, row_y, 60,
						menubar_row_height, menu_bar_shortcut_style(item.enabled))
				}
			}
			g_menu_hits << MenuBarHit{
				x: x
				y: row_y
				w: width
				h: menubar_row_height
				path: row_path
				id: item.id
				enabled: item.enabled
				has_items: item.items.len > 0
			}
			if item.items.len > 0 && menu_path_starts_with(g_menu_open_path, row_path)
				&& g_menu_open_path.len > row_path.len - 1 {
				child_items = item.items.clone()
				child_x = x + width - menubar_panel_padding
				child_y = row_y - menubar_panel_padding
			}
			row_y += menubar_row_height
		}
		if child_items.len > 0 {
			draw_menu_panel(ctx, child_items, g_menu_open_path[..path.len + 1], child_x,
				child_y, window)
		}
	}

	fn draw_submenu_arrow(ctx &gg.Context, center_x f64, center_y f64, color_hex u32) {
		c := hex_color(color_hex)
		ctx.draw_triangle_filled(f32(center_x - 2), f32(center_y - 4), f32(center_x + 3),
			f32(center_y), f32(center_x - 2), f32(center_y + 4), c)
	}

	fn menu_panel_width(ctx &gg.Context, items []MenuItem) f64 {
		mut width := menubar_panel_min_width
		for item in items {
			if item.separator {
				continue
			}
			mut needed := menubar_row_indent + menubar_row_tail +
				menu_text_width(ctx, item.title, menu_bar_row_style(item.enabled))
			if item.items.len == 0 {
				shortcut := menu_shortcut_label(item.shortcut)
				if shortcut.len > 0 {
					needed += menu_text_width(ctx, shortcut, menu_bar_shortcut_style(item.enabled)) +
						menubar_panel_padding * 2
				}
			}
			if needed > width {
				width = needed
			}
		}
		return if width > menubar_panel_max_width { menubar_panel_max_width } else { width }
	}

	fn menu_panel_height(items []MenuItem) f64 {
		mut height := menubar_panel_padding * 2
		for item in items {
			height += if item.separator { menubar_separator_height } else { menubar_row_height }
		}
		return height
	}

	// clamp_menu_coordinate keeps a panel inside the window on one axis,
	// preferring to slide it back from the far edge over letting it overflow.
	fn clamp_menu_coordinate(wanted f64, size f64, available f64) f64 {
		mut value := wanted
		if value + size > available - menubar_edge_margin {
			value = available - menubar_edge_margin - size
		}
		return if value < menubar_edge_margin { menubar_edge_margin } else { value }
	}

	fn arrays_append_int(path []int, value int) []int {
		mut next := []int{cap: path.len + 1}
		next << path
		next << value
		return next
	}

	fn int_paths_equal(a []int, b []int) bool {
		if a.len != b.len {
			return false
		}
		for index, value in a {
			if value != b[index] {
				return false
			}
		}
		return true
	}

	fn menu_path_starts_with(path []int, prefix []int) bool {
		if path.len < prefix.len {
			return false
		}
		for index, value in prefix {
			if path[index] != value {
				return false
			}
		}
		return true
	}

	// ── Pointer and keyboard handling ──────────────────────────────────

	fn menu_bar_hit_at(x f64, y f64) ?MenuBarHit {
		for index := g_menu_hits.len - 1; index >= 0; index-- {
			hit := g_menu_hits[index]
			if x >= hit.x && x <= hit.x + hit.w && y >= hit.y && y <= hit.y + hit.h {
				return hit
			}
		}
		return none
	}

	fn menu_bar_inside_panels(x f64, y f64) bool {
		for panel in g_menu_panels {
			if x >= panel.x && x <= panel.x + panel.width && y >= panel.y
				&& y <= panel.y + panel.height {
				return true
			}
		}
		return false
	}

	// menu_bar_handle_down reports whether the press belonged to the bar. Rows
	// act on release, the way both platform menus do, so a press-drag-release
	// selects in one gesture.
	fn menu_bar_handle_down(x f64, y f64) bool {
		if menu_bar().len == 0 {
			return false
		}
		if hit := menu_bar_hit_at(x, y) {
			if hit.is_title {
				if menu_bar_open() && g_menu_open_path[0] == hit.path[0] {
					close_menu_bar()
				} else {
					g_menu_open_path = hit.path.clone()
					g_menu_hover_path = []int{}
				}
			}
			g_menu_swallow_up = true
			return true
		}
		if menu_bar_open() || y < menu_bar_height() {
			close_menu_bar()
			g_menu_swallow_up = true
			return true
		}
		return false
	}

	fn menu_bar_handle_move(x f64, y f64) bool {
		if !menu_bar_open() {
			return false
		}
		hit := menu_bar_hit_at(x, y) or {
			g_menu_hover_path = []int{}
			return menu_bar_inside_panels(x, y)
		}
		if hit.is_title {
			if hit.path[0] != g_menu_open_path[0] {
				g_menu_open_path = hit.path.clone()
			}
			g_menu_hover_path = []int{}
			return true
		}
		g_menu_hover_path = hit.path.clone()
		// Hovering a submenu row opens it; hovering a plain one closes the
		// panels below the row's own, which is what makes nesting navigable.
		g_menu_open_path = if hit.has_items {
			hit.path.clone()
		} else {
			hit.path[..hit.path.len - 1].clone()
		}
		return true
	}

	fn menu_bar_handle_up(x f64, y f64) bool {
		swallow := g_menu_swallow_up
		g_menu_swallow_up = false
		if menu_bar().len == 0 {
			return false
		}
		if hit := menu_bar_hit_at(x, y) {
			if !hit.is_title && hit.enabled && !hit.has_items {
				close_menu_bar()
				fire_event(hit.id)
			}
			return true
		}
		return swallow || menu_bar_inside_panels(x, y)
	}

	// menu_bar_handle_key runs Escape and the declared accelerators. It is
	// asked before the window's own key handler, so a menu shortcut wins over
	// an app binding on the same chord.
	fn menu_bar_handle_key(e &gg.Event) bool {
		if menu_bar_open() && e.key_code == .escape {
			close_menu_bar()
			return true
		}
		menus := menu_bar()
		if menus.len == 0 {
			return false
		}
		pressed := parse_menu_shortcut(immediate_normalized_key(e))
		if !menu_shortcut_bindable(pressed) {
			return false
		}
		for m in menus {
			item := find_menu_shortcut(m.items, pressed) or { continue }
			close_menu_bar()
			fire_event(item.id)
			return true
		}
		return false
	}
}
