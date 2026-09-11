// vfmt off
// Keep gg imports out of the native AppKit/Win32 and headless builds.
@[has_globals]
module ui2

$if (android || linux || ((macos || windows) && ui2_custom_rendering ?)) && !ui2_headless ? {
	import gg
	import math

	const text_area_vertical_padding = 8.0
	const anonymous_text_area_scroll_prefix = '@text-area-key:'

	struct TextAreaLineRange {
		start int
		end   int
	}

	fn reset_scroll_frame() {
		g_scroll_areas = map[string]Rect{}
		g_scroll_viewports = map[string]Rect{}
		g_scroll_order = []string{}
		g_scroll_parents = map[string]string{}
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
		return register_scroll_view_in_parent(id, '', frame, clip, content_height, enabled,
			show_scrollbar, persistent)
	}

	fn register_scroll_view_in_parent(id string, parent_id string, frame Rect, clip Rect, content_height f64, enabled bool, show_scrollbar bool, persistent bool) f64 {
		if id.len == 0 {
			return 0.0
		}
		g_active_scrolls[id] = true
		g_scroll_viewports[id] = frame
		g_scroll_content_h[id] = content_height
		if parent_id.len > 0 {
			g_scroll_parents[id] = parent_id
		}
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

	// Rendering skips subtrees outside a scroll viewport, but those elements are
	// still mounted. Keep their scroll-backed state active so unmount cleanup
	// does not discard positions that must be restored when they re-enter view.
	fn retain_culled_scroll_state(el Element) {
		if el.hidden {
			return
		}
		if el.kind == .scroll {
			if el.id.len > 0 {
				g_active_scrolls[el.id] = true
			}
		} else if el.kind == .text_area {
			id := text_area_scroll_id(el)
			if id.len > 0 {
				g_active_scrolls[id] = true
			}
		}
		for child in el.children {
			retain_culled_scroll_state(child)
		}
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
			// A fitted child has nowhere to scroll. Let its scrollable parent
			// receive the wheel or drag instead of trapping the gesture here.
			if scroll_maximum(id) > 0 && scroll_rect_contains(area, x, y) {
				return id
			}
		}
		return ''
	}

	fn scroll_ancestor_chain(id string) []string {
		mut chain := []string{}
		mut current_id := id
		for _ in 0 .. g_scroll_viewports.len {
			if current_id.len == 0 {
				break
			}
			chain << current_id
			current_id = g_scroll_parents[current_id] or { '' }
		}
		return chain
	}

	// Apply a scroll delta to the innermost available pane first, then pass any
	// distance left at its boundary to each available ancestor. Touch input
	// captures this chain on pointer-down so frame culling cannot sever it.
	fn apply_scroll_chain(chain []string, delta f64) {
		mut remaining := delta
		for id in chain {
			if math.abs(remaining) < 0.000001 {
				return
			}
			if id !in g_scroll_areas {
				continue
			}
			before := scroll_offset(id)
			set_scroll_offset(id, before + remaining, scroll_maximum(id))
			remaining -= scroll_offset(id) - before
		}
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

	fn text_area_scroll_id(el Element) string {
		if el.id.len > 0 {
			return el.id
		}
		// Keyed repeater children do not need public ids for reconciliation, but
		// the immediate backend still needs stable private state to scroll them.
		// Prefix the key so it cannot alias a normal VML id in the scroll maps.
		if el.key.len > 0 {
			return anonymous_text_area_scroll_prefix + el.key
		}
		return ''
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

	// normalized_text_area_runes returns the renderer's newline-normalized runes
	// and the corresponding original source offset for every rune boundary.
	// Keeping this map makes selection offsets correct for CRLF input.
	fn normalized_text_area_runes(value string) ([]rune, []int) {
		source := value.runes()
		mut normalized := []rune{cap: source.len}
		mut source_offsets := []int{cap: source.len + 1}
		mut source_index := 0
		for source_index < source.len {
			source_offsets << source_index
			if source[source_index] == `\r` {
				normalized << `\n`
				if source_index + 1 < source.len && source[source_index + 1] == `\n` {
					source_index += 2
				} else {
					source_index++
				}
			} else {
				normalized << source[source_index]
				source_index++
			}
		}
		source_offsets << source.len
		return normalized, source_offsets
	}

	// text_area_line_rune_ranges maps rendered wrapped lines back to their
	// original source rune offsets. Whitespace discarded at wrap points is
	// intentionally outside every line range.
	fn text_area_line_rune_ranges(value string, lines []string) []TextAreaLineRange {
		runes, source_offsets := normalized_text_area_runes(value)
		mut ranges := []TextAreaLineRange{cap: lines.len}
		mut cursor := 0
		for line in lines {
			line_runes := line.runes()
			if line_runes.len == 0 {
				ranges << TextAreaLineRange{
					start: source_offsets[cursor]
					end: source_offsets[cursor]
				}
				continue
			}
			mut start := cursor
			for candidate := cursor; candidate + line_runes.len <= runes.len; candidate++ {
				mut matches := true
				for index in 0 .. line_runes.len {
					if runes[candidate + index] != line_runes[index] {
						matches = false
						break
					}
				}
				if matches {
					start = candidate
					break
				}
			}
			end := start + line_runes.len
			ranges << TextAreaLineRange{
				start: source_offsets[start]
				end: source_offsets[end]
			}
			cursor = end
		}
		return ranges
	}

	fn focused_text_area_line_index(ranges []TextAreaLineRange, caret int) int {
		for index, line in ranges {
			if caret <= line.end {
				return index
			}
		}
		return ranges.len - 1
	}

	fn move_focused_text_area_caret(mut editor TextEditor, direction int, extend bool) bool {
		layout := g_text_area_layouts[g_focused_field] or { return false }
		if layout.text != editor.text || layout.lines.len == 0 {
			return false
		}
		if !extend && !editor.selection.collapsed() {
			start, end := editor.selection.ordered()
			editor.set_caret(if direction < 0 { start } else { end })
			return true
		}
		ranges := text_area_line_rune_ranges(editor.text, layout.lines)
		if ranges.len == 0 {
			return false
		}
		current := focused_text_area_line_index(ranges, editor.selection.caret)
		next := clamp_int(current + direction, 0, ranges.len - 1)
		column := clamp_int(editor.selection.caret - ranges[current].start, 0,
			ranges[current].end - ranges[current].start)
		editor.move_caret_to(ranges[next].start + clamp_int(column, 0,
			ranges[next].end - ranges[next].start), extend)
		return true
	}

	fn move_focused_text_area_line_boundary(mut editor TextEditor, end bool, extend bool) bool {
		layout := g_text_area_layouts[g_focused_field] or { return false }
		if layout.text != editor.text || layout.lines.len == 0 {
			return false
		}
		ranges := text_area_line_rune_ranges(editor.text, layout.lines)
		if ranges.len == 0 {
			return false
		}
		line := ranges[focused_text_area_line_index(ranges, editor.selection.caret)]
		editor.move_caret_to(if end { line.end } else { line.start }, extend)
		return true
	}

	fn visible_text_area_rows(count int, top f64, line_height f64, offset f64, clip Rect) (int, int) {
		if count <= 0 || line_height <= 0 || clip.width <= 0 || clip.height <= 0 {
			return 0, 0
		}
		first := int(math.max(0.0, math.min(f64(count), math.floor((clip.y - top + offset) / line_height))))
		last := int(math.max(f64(first), math.min(f64(count), math.ceil((clip.y + clip.height - top + offset) / line_height))))
		return first, last
	}

	fn draw_text_area_content(ctx &gg.Context, el Element, value string, x f64, y f64, clip Rect, scroll_parent_id string) {
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
		line_ranges := text_area_line_rune_ranges(value, lines)
		editor := g_text_editors[el.id] or { text_editor(value.clone()) }
		selection_start, selection_end := editor.selection.ordered()
		show_selection := g_focused_field == el.id && selection_start != selection_end
		line_height := math.max(1.0, font_line_height(style.size))
		content_height := f64(lines.len) * line_height + text_area_vertical_padding * 2
		// Read-only means not editable, not unscrollable. disable_scroll only
		// hides the scroller, matching Element's documented/native behavior.
		scroll_id := text_area_scroll_id(el)
		offset := register_scroll_view_in_parent(scroll_id, scroll_parent_id, frame, clip, content_height, el.enabled,
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
				if show_selection && index < line_ranges.len {
					line_range := line_ranges[index]
					from := if selection_start > line_range.start { selection_start } else { line_range.start }
					to := if selection_end < line_range.end { selection_end } else { line_range.end }
					if to > from {
						line_runes := lines[index].runes()
						prefix := line_runes[..from - line_range.start].string()
						selected := line_runes[from - line_range.start..to - line_range.start].string()
						line_width := f64(ctx.text_width_f(lines[index]))
						line_origin := text_field_aligned_text_origin(content.x, content.width, line_width,
							style.align)
						draw_rect(ctx, line_origin + f64(ctx.text_width_f(prefix)), text_y - line_height / 2,
							f64(ctx.text_width_f(selected)), line_height, 0xb8d7ff, 0)
					}
				}
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
