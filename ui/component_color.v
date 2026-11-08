module ui2

import math

// Color picker: a saturation and brightness area with hue and alpha sliders,
// GPUI Kit's palette and HSLA panels, a hex field and a preview, shown inline
// or opened from a swatch or a field (GPUI Kit's ColorPicker and ColorSelect).
//
// This file holds the configuration, the layout every other part is computed
// from, and the decoders that turn actions, pointer events and keys back into
// colors. The elements are built in component_color_view.v, the triggers and
// the popover in component_color_trigger.v, and the color model itself in
// component_color_model.v.

// color_picker_max_swatches bounds the featured and palette swatches a picker
// draws, whatever the application passes.
pub const color_picker_max_swatches = 512

pub enum ColorPickerPanel {
	spectrum // The saturation and brightness area, hue and alpha sliders and featured colors.
	palette  // The featured colors and the palette families, as GPUI Kit's Palette tab.
	sliders  // Hue, saturation, lightness and alpha sliders, as GPUI Kit's HSLA tab.
}

// ColorPickerPart names a draggable part of the panel.
pub enum ColorPickerPart {
	area       // Saturation along x, brightness (HSV value) along y.
	hue        // 0 to 360 degrees.
	alpha      // 0 to 1.
	saturation // HSL saturation, on the sliders panel.
	lightness  // HSL lightness, on the sliders panel.
}

pub enum ColorPickerVariant {
	inline // The panel itself, drawn at frame.
	swatch // A color square (or an icon) and an optional label; opens the panel in a popover.
	field  // A framed field with a swatch, the hex value and a caret, as GPUI Kit's ColorSelect.
}

// ColorPickerAnchor is the corner of the popover that meets the trigger, as in
// GPUI Kit: top_left puts the popover's top-left corner under the trigger's
// bottom-left one, so it opens down and to the right.
pub enum ColorPickerAnchor {
	top_left
	top_right
	bottom_left
	bottom_right
}

pub struct ColorPickerConfig {
pub:
	id    string
	frame Rect // The panel (inline) or the trigger (swatch, field), parent-local.
	// Pointer events carry window coordinates. origin is the window position of
	// the element frame is relative to: zero for a child of the screen, the
	// parent's window position for a picker nested in views.
	origin_x f64
	origin_y f64
	value    ColorHsva  // Controlled: the application stores every change and rebuilds.
	empty    bool       // No color chosen yet: the trigger shows the placeholder, the hex field is blank.
	hex_text ?string    // What the hex field holds while the user types; none shows value.hex().
	preview  ?ColorHsva // A swatch under the pointer, shown in the preview and the hex field.
	variant  ColorPickerVariant
	open     bool // Swatch and field variants: whether the popover is open.
	panel    ColorPickerPanel
	// panels are the tabs, in order; with one or none the tab bar is hidden.
	panels []ColorPickerPanel = [ColorPickerPanel.spectrum, .palette, .sliders]
	// alpha shows the alpha slider and keeps the alpha; false keeps every color
	// the picker produces opaque.
	alpha    bool = true
	featured []u32          // 0xRRGGBB; empty uses color_default_featured().
	palettes []ColorPalette // Empty uses color_default_palettes().
	// area_height is the height of the saturation and brightness area. Zero
	// makes it at least 0.6 of the panel's inner width, and tall enough that
	// the spectrum tab is as tall as the others.
	area_height f64
	// opaque_gradients draws the area as horizontal bands of opaque gradients
	// and the alpha ramp as precomposited cells, so no gradient needs per-stop
	// opacity. Native Windows always draws both this way, and the custom
	// renderer the area (see component_color_view.v).
	opaque_gradients bool
	panel_width      f64 = 288 // Popover panel width; the inline panel takes frame.width.
	anchor           ColorPickerAnchor
	window           Rect   // Popover: the window, ui2.bounds(), for placement and the dismiss backdrop.
	label            string // Text beside the swatch trigger.
	icon             string // Swatch trigger: a symbol (see symbol_known) instead of the square.
	placeholder      string = 'Select a color' // Field trigger with no color.
	enabled          bool   = true
	// focused_part draws a focus ring round the part arrow keys adjust (see
	// color_picker_value_after_key); the application tracks it.
	focused_part        ?ColorPickerPart
	accessibility_label string
	size                ComponentSize = .medium
	theme               ComponentTheme
}

pub enum ColorPickerEventKind {
	change      // A drag or click on the area or a slider: store value. done is set on release.
	select      // A swatch was clicked: store value; open is false, as upstream closes the popover.
	hex_change  // The hex field was edited: read text(color_picker_hex_field_id(id)).
	hex_submit  // Return in the hex field: commit the text with color_picker_hex_value.
	preview     // The pointer entered a swatch: value is that swatch's color.
	preview_end // The pointer left a swatch.
	panel       // A tab was chosen: panel holds it.
	toggle      // The trigger was pressed: open holds the requested state.
	dismiss     // A click outside the open popover: open is false.
}

pub struct ColorPickerEvent {
pub:
	kind  ColorPickerEventKind
	value ColorHsva        // The new color (change, select) or the previewed one.
	part  ColorPickerPart  // change: the part that was dragged.
	done  bool             // change: the pointer was released, ending the drag.
	panel ColorPickerPanel // panel: the chosen tab.
	open  bool             // The popover's open state after this event.
}

// ── Metrics and layout ──────────────────────────────────────────────

struct ColorPickerMetrics {
	padding    f64
	gap        f64
	swatch     f64
	swatch_gap f64
	track      f64
	thumb      f64
	font       f64
	control    f64 // Height of the tab bar and the hex row.
	radius     f64
}

fn color_picker_metrics(size ComponentSize) ColorPickerMetrics {
	base := component_metrics(size)
	return match size {
		.small {
			ColorPickerMetrics{
				padding:    10
				gap:        8
				swatch:     16
				swatch_gap: 3
				track:      8
				thumb:      14
				font:       11
				control:    base.height
				radius:     base.radius
			}
		}
		.medium {
			ColorPickerMetrics{
				padding:    12
				gap:        10
				swatch:     20
				swatch_gap: 4
				track:      10
				thumb:      16
				font:       12
				control:    base.height
				radius:     base.radius
			}
		}
		.large {
			ColorPickerMetrics{
				padding:    14
				gap:        12
				swatch:     24
				swatch_gap: 5
				track:      12
				thumb:      20
				font:       14
				control:    base.height
				radius:     base.radius
			}
		}
	}
}

// ColorPickerSlider is one slider of the current panel, in panel coordinates.
struct ColorPickerSlider {
	part    ColorPickerPart
	track   Rect
	caption Rect // Sliders panel: the name on the left. Empty on the spectrum panel.
	readout Rect // Sliders panel: the value on the right.
}

// ColorPickerSwatch is one swatch of the current panel, in panel coordinates.
struct ColorPickerSwatch {
	part  string // What follows `swatch:` in its action.
	color u32
	frame Rect
	name  string // Accessibility label.
}

struct ColorPickerLayout {
	width    f64
	height   f64
	panel    ColorPickerPanel
	tabs     Rect // Empty when the tab bar is hidden.
	area     Rect // Empty unless the spectrum panel is shown.
	sliders  []ColorPickerSlider
	swatches []ColorPickerSwatch
	divider  Rect // Palette panel: the line between featured colors and palettes.
	footer   Rect // The line above the preview and the hex field.
	preview  Rect
	hex      Rect
}

// color_picker_panels is the tabs in order, without repeats; with none listed
// the current panel is the only one.
fn color_picker_panels(config ColorPickerConfig) []ColorPickerPanel {
	mut shown := []ColorPickerPanel{}
	for item in config.panels {
		if item !in shown {
			shown << item
		}
	}
	if shown.len == 0 {
		shown << config.panel
	}
	return shown
}

// color_picker_current_panel is config.panel, or the first tab when it is not
// one of them.
fn color_picker_current_panel(config ColorPickerConfig) ColorPickerPanel {
	shown := color_picker_panels(config)
	return if config.panel in shown { config.panel } else { shown[0] }
}

fn color_picker_featured(config ColorPickerConfig) []u32 {
	return if config.featured.len > 0 { config.featured } else { color_default_featured() }
}

fn color_picker_palettes(config ColorPickerConfig) []ColorPalette {
	return if config.palettes.len > 0 { config.palettes } else { color_default_palettes() }
}

fn color_picker_panel_width(config ColorPickerConfig) f64 {
	return if config.variant == .inline { config.frame.width } else { config.panel_width }
}

fn color_picker_part_name(part ColorPickerPart) string {
	return match part {
		.area { 'area' }
		.hue { 'hue' }
		.alpha { 'alpha' }
		.saturation { 'saturation' }
		.lightness { 'lightness' }
	}
}

fn color_picker_part_from_name(name string) ?ColorPickerPart {
	return match name {
		'area' { ColorPickerPart.area }
		'hue' { ColorPickerPart.hue }
		'alpha' { ColorPickerPart.alpha }
		'saturation' { ColorPickerPart.saturation }
		'lightness' { ColorPickerPart.lightness }
		else { none }
	}
}

fn color_picker_panel_name(panel ColorPickerPanel) string {
	return match panel {
		.spectrum { 'spectrum' }
		.palette { 'palette' }
		.sliders { 'sliders' }
	}
}

fn color_picker_panel_from_name(name string) ?ColorPickerPanel {
	return match name {
		'spectrum' { ColorPickerPanel.spectrum }
		'palette' { ColorPickerPanel.palette }
		'sliders' { ColorPickerPanel.sliders }
		else { none }
	}
}

// ColorPickerGrid places swatches in rows of `columns`, centered in the panel.
struct ColorPickerGrid {
	columns int
	side    f64
	gap     f64
	x       f64
}

// color_picker_grid fits the longest palette on one row when swatches can
// stay at least 12 points wide, and wraps every row at that many columns.
fn color_picker_grid(config ColorPickerConfig, m ColorPickerMetrics, x f64, width f64) ColorPickerGrid {
	mut longest := 1
	for palette in color_picker_palettes(config) {
		longest = math.max(longest, palette.colors.len)
	}
	fit := int(math.floor((width + m.swatch_gap) / (12 + m.swatch_gap)))
	columns := math.max(1, math.min(longest, fit))
	side := math.floor(math.max(0.0, math.min(m.swatch, (width - f64(columns - 1) * m.swatch_gap) / f64(columns))))
	used := f64(columns) * side + f64(columns - 1) * m.swatch_gap
	return ColorPickerGrid{
		columns: columns
		side:    side
		gap:     m.swatch_gap
		x:       math.round(x + math.max(0.0, (width - used) / 2))
	}
}

fn (grid ColorPickerGrid) block_height(count int) f64 {
	if count <= 0 {
		return 0
	}
	rows := (count + grid.columns - 1) / grid.columns
	return f64(rows) * grid.side + f64(rows - 1) * grid.gap
}

// place lays colors out from top, wrapping at the grid's column count. Each
// swatch's part is `prefix` followed by its index in colors.
fn (grid ColorPickerGrid) place(colors []u32, prefix string, group string, top f64) []ColorPickerSwatch {
	mut placed := []ColorPickerSwatch{cap: colors.len}
	for index, color in colors {
		row := index / grid.columns
		col := index % grid.columns
		hex := color_hex(color, 1)
		placed << ColorPickerSwatch{
			part:  prefix + index.str()
			color: color & 0xffffff
			frame: rect(grid.x + f64(col) * (grid.side + grid.gap), top + f64(row) * (grid.side +
				grid.gap), grid.side, grid.side)
			name:  if group.len > 0 { '${group} ${hex}' } else { hex }
		}
	}
	return placed
}

// color_picker_spectrum_rest is the height of the spectrum panel below its
// area: the sliders and the featured row.
fn color_picker_spectrum_rest(config ColorPickerConfig, m ColorPickerMetrics, grid ColorPickerGrid) f64 {
	mut height := m.gap + m.thumb
	if config.alpha {
		height += m.gap / 2 + m.thumb
	}
	return height + m.gap + grid.side
}

// color_picker_area_height is config.area_height, or else at least 0.6 of the
// inner width and tall enough that the spectrum panel fills the height the
// other tabs need.
fn color_picker_area_height(config ColorPickerConfig, m ColorPickerMetrics, grid ColorPickerGrid, inner_width f64) f64 {
	if config.area_height > 0 {
		return config.area_height
	}
	mut others := 0.0
	for item in color_picker_panels(config) {
		if item != .spectrum {
			others = math.max(others, color_picker_content_height(config, item, m, grid,
				inner_width))
		}
	}
	return math.max(math.round(inner_width * 0.6), others - color_picker_spectrum_rest(config,
		m, grid))
}

fn color_picker_row_height(m ColorPickerMetrics) f64 {
	return math.max(m.thumb, math.ceil(font_line_height(m.font)))
}

fn color_picker_slider_parts(config ColorPickerConfig) []ColorPickerPart {
	mut parts := [ColorPickerPart.hue, .saturation, .lightness]
	if config.alpha {
		parts << .alpha
	}
	return parts
}

fn color_picker_palettes_height(config ColorPickerConfig, grid ColorPickerGrid) f64 {
	mut height := 0.0
	mut blocks := 0
	for palette in color_picker_palettes(config) {
		if palette.colors.len == 0 {
			continue
		}
		height += grid.block_height(palette.colors.len)
		blocks++
	}
	return height + f64(math.max(blocks - 1, 0)) * grid.gap
}

fn color_picker_content_height(config ColorPickerConfig, panel ColorPickerPanel, m ColorPickerMetrics, grid ColorPickerGrid, inner_width f64) f64 {
	match panel {
		.spectrum {
			return color_picker_area_height(config, m, grid, inner_width) +
				color_picker_spectrum_rest(config, m, grid)
		}
		.palette {
			featured := grid.block_height(color_picker_featured(config).len)
			return featured + 2 * m.gap + 1 + color_picker_palettes_height(config, grid)
		}
		.sliders {
			rows := color_picker_slider_parts(config).len
			return f64(rows) * color_picker_row_height(m) + f64(rows - 1) * m.gap / 2
		}
	}
}

// color_picker_bare_slider is a slider row of the spectrum panel: a track as
// wide as the panel, centered in a row as tall as the thumb.
fn color_picker_bare_slider(part ColorPickerPart, x f64, y f64, width f64, m ColorPickerMetrics) ColorPickerSlider {
	return ColorPickerSlider{
		part:  part
		track: rect(x, y + (m.thumb - m.track) / 2, width, m.track)
	}
}

fn color_picker_caption(part ColorPickerPart) string {
	return match part {
		.area { 'Saturation and brightness' }
		.hue { 'Hue' }
		.alpha { 'Alpha' }
		.saturation { 'Saturation' }
		.lightness { 'Lightness' }
	}
}

// color_picker_layout computes every part of the panel in panel coordinates.
// The build and the decoders share it, so a pointer is mapped onto exactly
// the track that was drawn. The content area is as tall as the tallest panel,
// so switching tabs neither resizes the panel nor moves a popover.
fn color_picker_layout(config ColorPickerConfig) ColorPickerLayout {
	m := color_picker_metrics(config.size)
	width := math.max(color_picker_panel_width(config), 0)
	p := math.min(m.padding, width / 2)
	inner := width - 2 * p
	grid := color_picker_grid(config, m, p, inner)
	shown := color_picker_panels(config)
	current := color_picker_current_panel(config)
	mut y := p
	mut tabs := Rect{}
	if shown.len > 1 {
		tabs = rect(p, y, inner, m.control)
		y += m.control + m.gap
	}
	top := y
	mut content := 0.0
	for item in shown {
		content = math.max(content, color_picker_content_height(config, item, m, grid, inner))
	}
	mut area := Rect{}
	mut sliders := []ColorPickerSlider{}
	mut swatches := []ColorPickerSwatch{}
	mut divider := Rect{}
	featured := color_picker_featured(config)
	match current {
		.spectrum {
			area_height := color_picker_area_height(config, m, grid, inner)
			area = rect(p, top, inner, area_height)
			mut row := top + area_height + m.gap
			sliders << color_picker_bare_slider(.hue, p, row, inner, m)
			row += m.thumb
			if config.alpha {
				row += m.gap / 2
				sliders << color_picker_bare_slider(.alpha, p, row, inner, m)
				row += m.thumb
			}
			row += m.gap
			swatches << grid.place(featured[..math.min(featured.len, grid.columns)], 'f:',
				'', row)
		}
		.palette {
			swatches << grid.place(featured, 'f:', '', top)
			mut row := top + grid.block_height(featured.len) + m.gap
			divider = rect(p, row, inner, 1)
			row += 1 + m.gap
			for index, palette in color_picker_palettes(config) {
				if palette.colors.len == 0 {
					continue
				}
				swatches << grid.place(palette.colors, 'p:${index}:', palette.name, row)
				row += grid.block_height(palette.colors.len) + grid.gap
			}
		}
		.sliders {
			row_height := color_picker_row_height(m)
			mut caption_width := 0.0
			for name in ['Hue', 'Saturation', 'Lightness', 'Alpha'] {
				caption_width = math.max(caption_width, component_text_width_estimate(name,
					m.font))
			}
			caption_width = math.ceil(caption_width + 4)
			readout_width := math.ceil(component_text_width_estimate('100%', m.font) + 6)
			track_x := p + caption_width + m.gap
			track_width := math.max(inner - caption_width - readout_width - 2 * m.gap, 0)
			for index, part in color_picker_slider_parts(config) {
				row := top + f64(index) * (row_height + m.gap / 2)
				sliders << ColorPickerSlider{
					part:    part
					track:   rect(track_x, row + (row_height - m.track) / 2, track_width,
						m.track)
					caption: rect(p, row, caption_width, row_height)
					readout: rect(p + inner - readout_width, row, readout_width, row_height)
				}
			}
		}
	}
	y = top + content + m.gap
	footer := rect(p, y, inner, 1)
	y += 1 + m.gap
	preview := rect(p, y, m.control, m.control)
	hex := rect(p + m.control + m.gap, y, math.max(inner - m.control - m.gap, 0), m.control)
	y += m.control + p
	return ColorPickerLayout{
		width:    width
		height:   y
		panel:    current
		tabs:     tabs
		area:     area
		sliders:  sliders
		swatches: swatches
		divider:  divider
		footer:   footer
		preview:  preview
		hex:      hex
	}
}

// color_picker_height is the height the panel needs: give it to an inline
// picker's frame. The popover panel is panel_width by this.
pub fn color_picker_height(config ColorPickerConfig) f64 {
	return color_picker_layout(config).height
}

// ── Placement ───────────────────────────────────────────────────────

// color_picker_popover_frame places a width x height popover beside anchor,
// both in window coordinates, with `corner` of the popover meeting the
// matching corner of the anchor 4 points away. When window is not empty the
// popover opens on the other side if only that side has room, and is slid
// back inside the window, 8 points from its edges. Swap this function out to
// use a shared popover positioner.
pub fn color_picker_popover_frame(anchor Rect, window Rect, width f64, height f64, corner ColorPickerAnchor) Rect {
	// The shared positioner flips and shifts the same way every popover does.
	if window.width > 0 && window.height > 0 {
		if placed := popover_place(PopoverPlacementConfig{
			anchor: anchor
			window: window
			width:  width
			height: height
			side:   if corner == .top_left || corner == .top_right {
				PopoverSide.bottom
			} else {
				.top
			}
			align:  if corner == .top_left || corner == .bottom_left {
				PopoverAlign.start
			} else {
				.end
			}
			offset: 4
			margin: 8
		})
		{
			return rect(math.round(placed.frame.x), math.round(placed.frame.y), width, height)
		}
	}
	gap := 4.0
	margin := 8.0
	opens_down := corner == .top_left || corner == .top_right
	from_left := corner == .top_left || corner == .bottom_left
	below := anchor.y + anchor.height + gap
	above := anchor.y - gap - height
	mut x := if from_left { anchor.x } else { anchor.x + anchor.width - width }
	mut y := if opens_down { below } else { above }
	if window.width > 0 && window.height > 0 {
		top := window.y + margin
		bottom := window.y + window.height - margin
		room_below := bottom - below
		room_above := above + height - top
		if opens_down && height > room_below && room_above > room_below {
			y = above
		} else if !opens_down && height > room_above && room_below > room_above {
			y = below
		}
		// Slide back inside; when the popover is larger than the window its
		// top-left corner wins, so the tabs stay reachable.
		x = math.max(math.min(x, window.x + window.width - margin - width), window.x + margin)
		y = math.max(math.min(y, bottom - height), top)
	}
	return rect(math.round(x), math.round(y), width, height)
}

// color_picker_anchor_frame is the trigger in window coordinates.
fn color_picker_anchor_frame(config ColorPickerConfig) Rect {
	return rect(config.origin_x + config.frame.x, config.origin_y + config.frame.y, config.frame.width,
		config.frame.height)
}

// color_picker_panel_frame is where the panel is drawn, in window
// coordinates: the inline frame offset by origin, or the popover placed by
// color_picker_popover_frame.
pub fn color_picker_panel_frame(config ColorPickerConfig) Rect {
	layout := color_picker_layout(config)
	if config.variant == .inline {
		height := if config.frame.height > 0 { config.frame.height } else { layout.height }
		anchor := color_picker_anchor_frame(config)
		return rect(anchor.x, anchor.y, anchor.width, height)
	}
	return color_picker_popover_frame(color_picker_anchor_frame(config), config.window,
		layout.width, layout.height, config.anchor)
}

// color_picker_panel_visible is whether the panel is on screen, so its parts
// can emit actions.
fn color_picker_panel_visible(config ColorPickerConfig) bool {
	return config.enabled && (config.variant == .inline || config.open)
}

fn color_picker_part_rect(layout ColorPickerLayout, part ColorPickerPart) ?Rect {
	if part == .area {
		return if layout.area.width > 0 && layout.area.height > 0 { layout.area } else { none }
	}
	for item in layout.sliders {
		if item.part == part {
			return item.track
		}
	}
	return none
}

// color_picker_part_frame is the gradient of the area or the track of a
// slider in window coordinates, or none when the current panel does not show
// it. Pointer positions map onto this rectangle.
pub fn color_picker_part_frame(config ColorPickerConfig, part ColorPickerPart) ?Rect {
	local := color_picker_part_rect(color_picker_layout(config), part)?
	panel := color_picker_panel_frame(config)
	return rect(panel.x + local.x, panel.y + local.y, local.width, local.height)
}

// ── Values ──────────────────────────────────────────────────────────

fn color_picker_fraction(position f64, start f64, length f64) f64 {
	return if length <= 0 { 0.0 } else { unit_clamp((position - start) / length) }
}

// color_picker_value_at is the color a press at window point (x, y) on part
// asks for: saturation and brightness on the area, the hue, alpha, HSL
// saturation or lightness on a slider. Points outside clamp to the nearest
// edge, so a drag can leave the part. None when the part is not shown.
pub fn color_picker_value_at(config ColorPickerConfig, part ColorPickerPart, x f64, y f64) ?ColorHsva {
	if !component_finite(x) || !component_finite(y) {
		return none
	}
	if part == .alpha && !config.alpha {
		return none
	}
	track := color_picker_part_frame(config, part)?
	current := config.value.normalized()
	tx := color_picker_fraction(x, track.x, track.width)
	match part {
		.area {
			return ColorHsva{
				...current
				s: tx
				v: 1 - color_picker_fraction(y, track.y, track.height)
			}
		}
		.hue {
			return ColorHsva{
				...current
				h: tx * 360
			}
		}
		.alpha {
			return ColorHsva{
				...current
				a: tx
			}
		}
		.saturation {
			return ColorHsla{
				...current.hsla()
				s: tx
			}.hsva()
		}
		.lightness {
			return ColorHsla{
				...current.hsla()
				l: tx
			}.hsva()
		}
	}
}

// color_picker_same is whether two colors are the same picker state.
fn color_picker_same(a ColorHsva, b ColorHsva) bool {
	x := a.normalized()
	y := b.normalized()
	return x.h == y.h && x.s == y.s && x.v == y.v && x.a == y.a
}

// color_picker_hex_field_id is the id of the hex field, for text(), set_text()
// and focus(). It is also the action the field emits on each edit.
pub fn color_picker_hex_field_id(id string) string {
	return component_part_id(id, 'hex')
}

// color_picker_hex_value is the color typed hex text names, or none while it
// is not a complete `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`. A gray keeps
// the current hue, and without the alpha slider the color stays opaque.
pub fn color_picker_hex_value(config ColorPickerConfig, typed string) ?ColorHsva {
	rgba := color_parse_hex(typed)?
	next := config.value.with_rgba(rgba)
	return if config.alpha { next } else { next.with_alpha(1) }
}

// color_picker_swatch_value is the color a swatch selects: its own, with the
// current alpha, as GPUI Kit keeps the alpha while the palette changes the color.
fn color_picker_swatch_value(config ColorPickerConfig, color u32) ColorHsva {
	return config.value.with_rgba(ColorRgba{
		r: u8(color >> 16)
		g: u8(color >> 8)
		b: u8(color)
		a: if config.alpha { config.value.normalized().a } else { 1.0 }
	})
}

fn color_picker_find_swatch(layout ColorPickerLayout, part string) ?ColorPickerSwatch {
	for swatch in layout.swatches {
		if swatch.part == part {
			return swatch
		}
	}
	return none
}

// color_picker_event decodes what the picker emitted: actions from the
// trigger, tabs, swatches and hex field, and the `pointer:` events of its
// area, sliders and swatches. It takes the config the picker was built with
// and rejects foreign, forged and malformed events, everything while disabled,
// panel events while a popover is closed, configs color_picker would reject,
// parts the current panel does not show, tabs that are already current and
// drags that do not change the color.
// A press and a release are reported even when the color stays, so an
// application can track which part has keyboard focus and when a drag ends.
pub fn color_picker_event(config ColorPickerConfig, event string) ?ColorPickerEvent {
	if !config.enabled {
		return none
	}
	color_picker_validate(config) or { return none }
	visible := color_picker_panel_visible(config)
	if pointer := parse_pointer_event(event) {
		part := component_action_part(config.id, pointer.action) or { return none }
		if !visible {
			return none
		}
		layout := color_picker_layout(config)
		if part.starts_with('swatch:') {
			swatch := color_picker_find_swatch(layout, part['swatch:'.len..])?
			if pointer.phase == 'enter' {
				return ColorPickerEvent{
					kind:  .preview
					value: color_picker_swatch_value(config, swatch.color)
					open:  config.open
				}
			}
			if pointer.phase == 'leave' {
				return ColorPickerEvent{
					kind:  .preview_end
					value: config.value
					open:  config.open
				}
			}
			return none
		}
		dragged := color_picker_part_from_name(part)?
		if pointer.phase !in ['down', 'drag', 'up'] {
			return none
		}
		next := color_picker_value_at(config, dragged, pointer.x, pointer.y)?
		if pointer.phase == 'drag' && color_picker_same(next, config.value) {
			return none
		}
		return ColorPickerEvent{
			kind:  .change
			value: next
			part:  dragged
			done:  pointer.phase == 'up'
			open:  config.open
		}
	}
	part := component_action_part(config.id, event) or { return none }
	if part == 'trigger' {
		if config.variant == .inline {
			return none
		}
		return ColorPickerEvent{
			kind:  .toggle
			value: config.value
			open:  !config.open
		}
	}
	if !visible {
		return none
	}
	match part {
		'dismiss' {
			if config.variant == .inline {
				return none
			}
			return ColorPickerEvent{
				kind:  .dismiss
				value: config.value
			}
		}
		'hex' {
			return ColorPickerEvent{
				kind:  .hex_change
				value: config.value
				open:  config.open
			}
		}
		'hex:submit' {
			return ColorPickerEvent{
				kind:  .hex_submit
				value: config.value
			}
		}
		else {}
	}
	if part.starts_with('panel:') {
		chosen := color_picker_panel_from_name(part['panel:'.len..])?
		if chosen !in color_picker_panels(config) || chosen == color_picker_current_panel(config) {
			return none
		}
		return ColorPickerEvent{
			kind:  .panel
			value: config.value
			panel: chosen
			open:  config.open
		}
	}
	if part.starts_with('swatch:') {
		swatch := color_picker_find_swatch(color_picker_layout(config), part['swatch:'.len..])?
		return ColorPickerEvent{
			kind:  .select
			value: color_picker_swatch_value(config, swatch.color)
		}
	}
	return none
}

// color_picker_value_from_pointer is the color a pointer event on the area or
// a slider asks for, or none for any other event.
pub fn color_picker_value_from_pointer(config ColorPickerConfig, event string) ?ColorHsva {
	decoded := color_picker_event(config, event)?
	return if decoded.kind == .change { decoded.value } else { none }
}

// ── Keyboard ────────────────────────────────────────────────────────

fn color_picker_step(value f64, delta f64, grid f64, low f64, high f64) f64 {
	return math.max(low, math.min(high, math.round((value + delta) / grid) * grid))
}

// color_picker_value_after_key nudges a part with the arrow keys: left and
// right move the area's saturation and up and down its brightness; on a
// slider left/down lower and right/up raise it, and Home and End go to its
// ends. Steps are 1% (1 degree of hue), or 10% (10 degrees) with Shift.
// Components cannot capture keys: call it from on_key_event for the part the
// application considers focused, unless a text field has focus. None for
// other keys, modified keys, parts not shown and keys that change nothing.
pub fn color_picker_value_after_key(config ColorPickerConfig, part ColorPickerPart, event KeyEvent) ?ColorHsva {
	if !color_picker_panel_visible(config) || event.ctrl || event.alt || event.cmd {
		return none
	}
	if part == .alpha && !config.alpha {
		return none
	}
	color_picker_validate(config) or { return none }
	color_picker_part_rect(color_picker_layout(config), part)?
	current := config.value.normalized()
	unit := if event.shift { 0.1 } else { 0.01 }
	down := event.code in [.left, .down]
	up := event.code in [.right, .up]
	mut next := current
	match part {
		.area {
			next = match event.code {
				.left, .right {
					ColorHsva{
						...current
						s: color_picker_step(current.s, if up { unit } else { -unit }, 0.01, 0,
							1)
					}
				}
				.up, .down {
					ColorHsva{
						...current
						v: color_picker_step(current.v, if up { unit } else { -unit }, 0.01, 0,
							1)
					}
				}
				else {
					return none
				}
			}
		}
		else {
			mut fraction := 0.0
			match part {
				.hue { fraction = current.h / 360 }
				.alpha { fraction = current.a }
				.saturation { fraction = current.hsla().s }
				else { fraction = current.hsla().l }
			}
			// Hue steps whole degrees; the others whole percent.
			grid := if part == .hue { 1.0 / 360 } else { 0.01 }
			step := if part == .hue { unit * 100 * grid } else { unit }
			target := match event.code {
				.home {
					0.0
				}
				.end {
					1.0
				}
				else {
					if !down && !up {
						return none
					}
					color_picker_step(fraction, if up { step } else { -step }, grid, 0, 1)
				}
			}
			next = match part {
				.hue {
					ColorHsva{
						...current
						h: math.round(target * 360)
					}
				}
				.alpha {
					ColorHsva{
						...current
						a: target
					}
				}
				.saturation {
					ColorHsla{
						...current.hsla()
						s: target
					}.hsva()
				}
				else {
					ColorHsla{
						...current.hsla()
						l: target
					}.hsva()
				}
			}
		}
	}
	if color_picker_same(next, current) {
		return none
	}
	return next
}

// color_picker_dismiss_on_key reports whether a key closes the open popover:
// Escape without modifiers.
pub fn color_picker_dismiss_on_key(config ColorPickerConfig, event KeyEvent) bool {
	return config.variant != .inline && config.open && event.code == .escape && !event.shift
		&& !event.ctrl && !event.alt && !event.cmd
}

// ── Validation ──────────────────────────────────────────────────────

fn color_picker_validate(config ColorPickerConfig) ! {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	if !component_finite(config.origin_x) || !component_finite(config.origin_y) {
		return error('color picker origin must be finite')
	}
	if !component_finite(config.area_height) || config.area_height < 0 {
		return error('color picker area height must be finite and non-negative')
	}
	if !component_finite(config.panel_width) || config.panel_width <= 0 {
		return error('color picker panel width must be finite and positive')
	}
	component_validate_frame(config.window)!
	mut count := config.featured.len
	for palette in config.palettes {
		count += palette.colors.len
	}
	if count > color_picker_max_swatches {
		return error('color picker shows at most ${color_picker_max_swatches} swatches')
	}
	if config.icon.len > 0 && !symbol_known(config.icon) {
		return error('color picker icon `${config.icon}` is not drawn by every renderer; pick a name from symbol_names()')
	}
}
