// vfmt off
// Keep gg imports out of the native AppKit/Win32 and headless builds.
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import math

	const text_area_vertical_padding = 8.0

	fn reset_scroll_frame() {
		g_scroll_areas = map[string]Rect{}
		g_scroll_viewports = map[string]Rect{}
		g_scroll_order = []string{}
		g_scrollbar_geometries = map[string]ScrollbarGeometry{}
	}

	fn scroll_maximum(id string) f64 {
		frame := g_scroll_viewports[id] or { return 0.0 }
		if frame.width <= 0 || frame.height <= 0 {
			return 0.0
		}
		content_height := g_scroll_content_h[id] or { 0.0 }
		return if content_height > frame.height { content_height - frame.height } else { 0.0 }
	}

	fn register_scroll_view(id string, frame Rect, clip Rect, content_height f64, enabled bool, show_scrollbar bool, persistent bool) f64 {
		if id.len == 0 {
			return 0.0
		}
		g_active_scrolls[id] = true
		g_scroll_viewports[id] = frame
		g_scroll_content_h[id] = content_height
		// Preserve the position across rebuilds and resizes, only clamping when
		// the content or viewport changes the available range.
		set_scroll_offset(id, scroll_offset(id), scroll_maximum(id))
		offset := scroll_offset(id)
		area := intersect_rect(frame, clip)
		if enabled && area.width > 0 && area.height > 0 {
			g_scroll_areas[id] = area
			g_scroll_order << id
			if show_scrollbar {
				g_scrollbar_geometries[id] = scrollbar_geometry(frame, content_height, offset,
					persistent)
			}
		}
		return offset
	}

	fn scroll_rect_contains(r Rect, x f64, y f64) bool {
		return r.width > 0 && r.height > 0 && x >= r.x && x < r.x + r.width
			&& y >= r.y && y < r.y + r.height
	}

	fn scroll_hit_test(x f64, y f64) string {
		// Children and later-painted panes get the event before their parents.
		for index := g_scroll_order.len - 1; index >= 0; index-- {
			id := g_scroll_order[index]
			area := g_scroll_areas[id] or { continue }
			if scroll_rect_contains(area, x, y) {
				return id
			}
		}
		return ''
	}

	fn scrollbar_geometry(frame Rect, content_height f64, offset f64, persistent bool) ScrollbarGeometry {
		if frame.width < 12 || frame.height < 16 {
			return ScrollbarGeometry{}
		}
		maximum := if content_height > frame.height { content_height - frame.height } else { 0.0 }
		if !persistent && maximum <= 0 {
			return ScrollbarGeometry{}
		}
		track := rect(frame.x + frame.width - 9, frame.y + 4, 5, frame.height - 8)
		content := if content_height > frame.height { content_height } else { frame.height }
		thumb_height := math.min(track.height, math.max(28.0, track.height * frame.height / content))
		progress := if maximum > 0 { math.max(0.0, math.min(offset, maximum)) / maximum } else { 0.0 }
		return ScrollbarGeometry{
			track: track
			thumb: rect(track.x, track.y + (track.height - thumb_height) * progress,
				track.width, thumb_height)
		}
	}

	fn begin_scrollbar_drag(x f64, y f64) bool {
		id := g_touch.scroll_id
		bar := g_scrollbar_geometries[id] or { return false }
		// Give the narrow drawn track a slightly wider pointer target.
		target := rect(bar.track.x - 3, bar.track.y, 12, bar.track.height)
		if !scroll_rect_contains(target, x, y) || scroll_maximum(id) <= 0
			|| bar.track.height <= bar.thumb.height {
			return false
		}
		g_touch.scrollbar_drag = true
		if y >= bar.thumb.y && y < bar.thumb.y + bar.thumb.height {
			g_touch.scrollbar_grab_y = y - bar.thumb.y
		} else {
			g_touch.scrollbar_grab_y = bar.thumb.height / 2
			drag_scrollbar(y)
		}
		return true
	}

	fn drag_scrollbar(y f64) {
		id := g_touch.scroll_id
		bar := g_scrollbar_geometries[id] or { return }
		travel := bar.track.height - bar.thumb.height
		if travel <= 0 {
			return
		}
		maximum := scroll_maximum(id)
		set_scroll_offset(id, (y - bar.track.y - g_touch.scrollbar_grab_y) / travel * maximum,
			maximum)
	}

	fn text_area_content_rect(frame Rect, padding_left f64, show_scrollbar bool) Rect {
		left := math.max(2.0, padding_left)
		// Reserve the gutter even when the text currently fits, avoiding a
		// wrap/scrollbar feedback loop as the window is resized.
		right := if show_scrollbar { 12.0 } else { 8.0 }
		return rect(frame.x + left, frame.y + text_area_vertical_padding,
			math.max(0.0, frame.width - left - right),
			math.max(0.0, frame.height - text_area_vertical_padding * 2))
	}

	// Wrap using the same font measurement as drawing. Explicit blank lines
	// survive, and an unbroken word is split only at UTF-8 rune boundaries.
	fn wrap_text_area_lines(value string, width f64, measure fn (string) f64) []string {
		if width <= 0 {
			return []string{}
		}
		mut lines := []string{}
		for paragraph in value.replace('\r\n', '\n').replace('\r', '\n').split('\n') {
			if paragraph.len == 0 {
				lines << ''
				continue
			}
			runes := paragraph.runes()
			mut start := 0
			for start < runes.len {
				rest := runes[start..].string()
				if measure(rest) <= width {
					lines << rest
					break
				}
				mut low := 0
				mut high := runes.len - start
				for low < high {
					mid := (low + high + 1) / 2
					if measure(runes[start..start + mid].string()) <= width {
						low = mid
					} else {
						high = mid - 1
					}
				}
				// A glyph wider than the pane is clipped, but must still advance.
				kept := if low > 0 { low } else { 1 }
				mut end := start + kept
				mut next := end
				if end < runes.len {
					mut space := end
					for space > start && runes[space] != ` ` && runes[space] != `\t` {
						space--
					}
					if space > start {
						end = space
						next = space + 1
						for next < runes.len && (runes[next] == ` ` || runes[next] == `\t`) {
							next++
						}
					}
				}
				lines << runes[start..end].string()
				start = next
			}
		}
		return lines
	}

	fn text_area_lines(id string, value string, width f64, style TextStyle, rendered_size int, measure fn (string) f64) []string {
		if id.len > 0 {
			if cached := g_text_area_layouts[id] {
				if cached.text == value && cached.width == width && cached.style == style
					&& cached.rendered_size == rendered_size {
					return cached.lines
				}
			}
		}
		lines := wrap_text_area_lines(value, width, measure)
		if id.len > 0 {
			g_text_area_layouts[id] = TextAreaLayout{
				text: value
				width: width
				style: style
				rendered_size: rendered_size
				lines: lines
			}
		}
		return lines
	}

	fn visible_text_area_rows(count int, top f64, line_height f64, offset f64, clip Rect) (int, int) {
		if count <= 0 || line_height <= 0 || clip.width <= 0 || clip.height <= 0 {
			return 0, 0
		}
		first := int(math.max(0.0, math.min(f64(count), math.floor((clip.y - top + offset) / line_height))))
		last := int(math.max(f64(first), math.min(f64(count), math.ceil((clip.y + clip.height - top + offset) / line_height))))
		return first, last
	}

	fn draw_text_area_content(ctx &gg.Context, el Element, value string, x f64, y f64, clip Rect) {
		frame := rect(x, y, el.frame.width, el.frame.height)
		content := text_area_content_rect(frame, el.padding_left, !el.disable_scroll)
		style := el.text_style
		family := text_font_file(style.font_family, style.bold, style.italic)
		ensure_family_fallbacks(ctx, family)
		cfg := gg.TextCfg{
			color: hex_color(style.color)
			size: int(font_render_size(style.size, text_font_metrics(family)) + 0.5)
			bold: style.bold
			italic: style.italic
			family: family
			align: text_align(style.align)
			vertical_align: .middle
		}
		ctx.set_text_cfg(cfg)
		lines := text_area_lines(el.id, value, content.width, style, cfg.size, fn [ctx] (line string) f64 {
			return f64(ctx.text_width_f(line))
		})
		line_height := math.max(1.0, font_line_height(style.size))
		content_height := f64(lines.len) * line_height + text_area_vertical_padding * 2
		// Read-only means not editable, not unscrollable. disable_scroll only
		// hides the scroller, matching Element's documented/native behavior.
		offset := register_scroll_view(el.id, frame, clip, content_height, el.enabled,
			!el.disable_scroll, el.persistent_scrollbars)
		text_clip := intersect_rect(content, clip)
		if text_clip.width > 0 && text_clip.height > 0 {
			apply_clip(ctx, text_clip)
			text_x := match style.align {
				.left { content.x }
				.center { content.x + content.width / 2 }
				.right { content.x + content.width }
			}
			first, last := visible_text_area_rows(lines.len, content.y, line_height, offset, text_clip)
			for index in first .. last {
				text_y := content.y + (f64(index) + 0.5) * line_height - offset
				ctx.draw_text(int(text_x), int(text_y), lines[index], cfg)
			}
		}
		pane_clip := intersect_rect(frame, clip)
		if !el.disable_scroll && pane_clip.width > 0 && pane_clip.height > 0 {
			apply_clip(ctx, pane_clip)
			draw_scrollbar(ctx, x, y, frame.width, frame.height, content_height, offset,
				el.persistent_scrollbars)
		}
		// Neither the next sibling nor the pane's scrollbar inherits the text clip.
		apply_clip(ctx, clip)
	}
}
