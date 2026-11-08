module main

import os
import math
import ui2

// A gallery of the basics: image_box (object fit, corners, loading and
// fallback states, a gallery with selectable thumbnails), styled_label
// (secondary text, highlights, masking, alignment, wrapping), textarea (rows,
// auto-grow, counter, sizes and states), tooltip_popup (timed hover tooltips
// with shortcuts, rich content and tones) and scrollable (both axes, stacking,
// scroll-to helpers, a position readout and a themed scrollbar of its own).
// The photos are drawn by the program into the user's cache directory.

const window_width = 1280
const window_height = 880

const col_a = 24.0
const col_b = 440.0
const col_c = 856.0
const col_w = 392.0

// Where each tooltip trigger sits, in window coordinates: everything is a direct
// child of the screen, so a trigger's frame is also its tooltip's anchor.
struct Tool {
	key      string
	symbol   string
	tip      string
	shortcut string
	keys     []string
}

const tools = [
	Tool{'new', 'plus', 'New file', 'cmd+n', []string{}},
	Tool{'open', 'folder', 'Open file', 'cmd+o', []string{}},
	Tool{'save', 'square.and.arrow.down', 'Save file', 'cmd+s', []string{}},
	Tool{'undo', 'arrow.uturn.backward', 'Undo the last action', 'cmd+z', []string{}},
	Tool{'delete', 'trash', 'Delete this item permanently', '', ['Delete']},
]

struct Status {
	key   string
	name  string
	tip   string
	color int // 0 success, 1 warning, 2 danger
}

const statuses = [
	Status{'online', 'Online', 'Connected to server', 0},
	Status{'limited', 'Limited', 'Limited connectivity', 1},
	Status{'offline', 'Offline', 'No connection', 2},
]

struct Photo {
	file string
	name string
	alt  string
}

const photos = [
	Photo{'lake.bmp', 'Lake', 'Sunset over a mountain lake'},
	Photo{'forest.bmp', 'Forest', 'Pine trees under the moon'},
	Photo{'portrait.bmp', 'Portrait', 'A portrait on a blue background'},
]

@[heap]
struct Gallery {
mut:
	dark   bool
	status string = 'Hover the toolbar, the status dots and the file; type in the fields; scroll the panes.'
	dir    string
	// Image
	selected int
	// Label
	query  string = 'hello'
	masked bool   = true
	// Textarea
	notes   string
	message string = 'Thanks for the update!\nThe new build looks right on both renderers.\nShipping it today.'
	// Tooltips: the toolbar and the status dots share one group, the file another.
	// Both start open, so the gallery shows them before anything is hovered.
	tips       ui2.TooltipGroup = ui2.TooltipGroup{
		open:    true
		current: 'save'
	}
	tips_timer ui2.TimerId
	info       ui2.TooltipGroup = ui2.TooltipGroup{
		open:    true
		current: 'file'
	}
	info_timer ui2.TimerId
	email      string = 'ada@example'
	// Scrollable
	files_offset f64
	cards_offset f64
	bar_mode     ui2.ScrollbarMode = .always
	bar_drag     ui2.ScrollbarDrag
	bar_hovered  bool
	files_hover  bool
	files_active bool
	files_timer  ui2.TimerId
}

const gallery_state = &Gallery{}

fn gallery() &Gallery {
	return unsafe { gallery_state }
}

// ── Pictures ─────────────────────────────────────────────────────────

fn mix(a u32, b u32, t f64) u32 {
	k := math.min(math.max(t, 0), 1)
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		ca := f64((a >> shift) & 0xff)
		cb := f64((b >> shift) & 0xff)
		out |= u32(math.round(ca + (cb - ca) * k)) << shift
	}
	return out
}

fn put32(mut data []u8, at int, value int) {
	data[at] = u8(value & 0xff)
	data[at + 1] = u8((value >> 8) & 0xff)
	data[at + 2] = u8((value >> 16) & 0xff)
	data[at + 3] = u8((value >> 24) & 0xff)
}

// write_bmp saves a 24-bit BMP, which every backend decodes.
fn write_bmp(path string, width int, height int, pixel fn (x int, y int) u32) ! {
	row := (width * 3 + 3) / 4 * 4
	size := 54 + row * height
	mut data := []u8{len: size}
	data[0] = `B`
	data[1] = `M`
	put32(mut data, 2, size)
	put32(mut data, 10, 54)
	put32(mut data, 14, 40)
	put32(mut data, 18, width)
	put32(mut data, 22, height)
	data[26] = 1
	data[28] = 24
	put32(mut data, 34, row * height)
	for y in 0 .. height {
		base := 54 + (height - 1 - y) * row
		for x in 0 .. width {
			c := pixel(x, y)
			data[base + x * 3] = u8(c & 0xff)
			data[base + x * 3 + 1] = u8((c >> 8) & 0xff)
			data[base + x * 3 + 2] = u8((c >> 16) & 0xff)
		}
	}
	os.write_file_array(path, data)!
}

fn lake_pixel(x int, y int) u32 {
	fx := f64(x)
	fy := f64(y)
	horizon := 168.0
	far_ridge := 118 + 26 * math.sin(fx * 0.021) + 14 * math.sin(fx * 0.057 + 1.3)
	near_ridge := 140 + 18 * math.sin(fx * 0.034 + 2.1) + 8 * math.sin(fx * 0.11)
	if fy < horizon {
		sun := math.hypot(fx - 330, fy - 112)
		if sun < 30 {
			return 0xfff4d6
		}
		if fy > near_ridge {
			return mix(0x2e2450, 0x1b1633, (fy - near_ridge) / 40)
		}
		if fy > far_ridge {
			return mix(0x6b5b95, 0x4c3f73, (fy - far_ridge) / 50)
		}
		glow := math.max(0, 1 - sun / 140) * 0.5
		return mix(mix(0x1e3a8a, 0xf59e0b, fy / horizon), 0xfde68a, glow)
	}
	depth := (fy - horizon) / (270 - horizon)
	water := mix(0x7c5a8c, 0x0f1b3d, depth)
	if math.abs(fx - 330) < 26 - depth * 12 && int(fy) % 7 < 3 {
		return mix(water, 0xfde68a, 0.65 - depth * 0.4)
	}
	return water
}

fn forest_pixel(x int, y int) u32 {
	fx := f64(x)
	fy := f64(y)
	if math.hypot(fx - 172, fy - 70) < 26 {
		return 0xf1f5f9
	}
	mut color := mix(0x0b1e3f, 0x2a6f6b, fy / 360)
	for i, tree_x in [30.0, 92, 150, 210] {
		top := [150.0, 110, 175, 135][i]
		half := (fy - top) * 0.32
		if fy > top && fy < 330 && math.abs(fx - tree_x) < half {
			color = mix(0x0f3d2e, 0x06241b, f64(i % 2) * 0.6)
		}
	}
	if fy >= 320 {
		color = mix(0x14532d, 0x052e16, (fy - 320) / 40)
	}
	return color
}

fn portrait_pixel(x int, y int) u32 {
	fx := f64(x)
	fy := f64(y)
	if math.hypot(fx - 80, fy - 66) < 31 {
		return 0xfcd9b6
	}
	shoulders := math.hypot((fx - 80) / 58, (fy - 168) / 52)
	if shoulders < 1 {
		return 0x1e293b
	}
	return mix(0x93c5fd, 0x6366f1, (fx + fy) / 320)
}

fn badge_pixel(x int, y int) u32 {
	d := math.hypot(f64(x) - 19.5, f64(y) - 19.5)
	if d < 9 {
		return 0xffffff
	}
	return mix(0x10b981, 0x0e7490, f64(x + y) / 80)
}

fn ensure_pictures() string {
	dir := os.join_path(os.cache_dir(), 'ui2-gpui-basics')
	os.mkdir_all(dir) or {}
	write_bmp(os.join_path(dir, 'lake.bmp'), 480, 270, lake_pixel) or {}
	write_bmp(os.join_path(dir, 'forest.bmp'), 240, 360, forest_pixel) or {}
	write_bmp(os.join_path(dir, 'portrait.bmp'), 160, 160, portrait_pixel) or {}
	write_bmp(os.join_path(dir, 'badge.bmp'), 40, 40, badge_pixel) or {}
	return dir
}

fn (app &Gallery) picture(name string) string {
	return os.join_path(app.dir, name)
}

// ── Small pieces ─────────────────────────────────────────────────────

fn section_title(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, col_w, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(text string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 16), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn text_button(id string, title string, frame ui2.Rect, theme ui2.ComponentTheme, active bool) ui2.Element {
	return ui2.button(id, title, frame, ui2.BoxStyle{
		bg:     if active { theme.primary } else { theme.muted }
		radius: 6
	}, ui2.TextStyle{
		color: if active { theme.primary_foreground } else { theme.foreground }
		size:  13
		align: .center
	})
}

fn icon_button(id string, symbol string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	side := 16.0
	return ui2.Element{
		...ui2.button_view(id, frame, ui2.BoxStyle{
			bg:     theme.muted
			radius: 6
		}, [
			ui2.Element{
				...ui2.image('', 'symbol:' + symbol, ui2.rect((frame.width - side) / 2,
					(frame.height - side) / 2, side, side))
				text_style: ui2.TextStyle{
					color: theme.foreground
				}
			},
		])
		cursor: ui2.cursor_pointing_hand
	}
}

fn field_box(theme ui2.ComponentTheme, invalid bool) ui2.BoxStyle {
	border := if invalid { theme.danger } else { theme.border }
	return ui2.BoxStyle{
		bg:            theme.background
		radius:        6
		border_color:  border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}
}

fn tone_color(theme ui2.ComponentTheme, which int) u32 {
	return match which {
		0 { theme.success }
		1 {
			if theme.background == 0xffffff { u32(0xb45309) } else { theme.warning }
		}
		else { theme.danger }
	}
}

// ── Image ────────────────────────────────────────────────────────────

fn image_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	x := col_a
	children << section_title('Image', x, 64, theme)
	children << caption('object fit: a 16:9 photo, and a 40 × 40 badge for scale_down', x, 92,
		col_w, theme)
	fits := [ui2.ImageFit.contain, .cover, .fill, .scale_down, .none]
	names := ['contain', 'cover', 'fill', 'scale_down', 'none']
	for i, fit in fits {
		tx := x + f64(i) * 81
		children << ui2.image_box(
			id:         'fit-${i}'
			frame:      ui2.rect(tx, 112, 68, 68)
			path:       app.picture(if fit == .scale_down { 'badge.bmp' } else { 'lake.bmp' })
			alt:        'Lake, ${names[i]}'
			fit:        fit
			radius:     6
			bordered:   true
			background: theme.muted
			theme:      theme
		) or { panic(err) }
		children << ui2.label('', names[i], ui2.rect(tx - 6, 184, 80, 16), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			align: .center
		})
	}
	children << caption('corners, a border, and the loading and fallback states keep the box',
		x, 210, col_w, theme)
	tiles := [
		ui2.ImageBoxConfig{
			id:     'rounded'
			path:   app.picture('lake.bmp')
			alt:    'Lake'
			fit:    .cover
			radius: 16
		},
		ui2.ImageBoxConfig{
			id:     'circle'
			path:   app.picture('portrait.bmp')
			alt:    'Portrait'
			fit:    .cover
			circle: true
		},
		ui2.ImageBoxConfig{
			id:         'framed'
			path:       app.picture('forest.bmp')
			alt:        'Forest'
			radius:     8
			bordered:   true
			background: theme.muted
		},
		ui2.ImageBoxConfig{
			id:           'loading'
			path:         app.picture('lake.bmp')
			loading:      true
			loading_text: 'Loading…'
			radius:       8
		},
		ui2.ImageBoxConfig{
			id:            'missing'
			path:          app.picture('missing.png')
			fallback_text: 'Missing'
			radius:        8
		},
	]
	tile_names := ['radius 16', 'circle', 'bordered', 'loading', 'fallback']
	for i, tile in tiles {
		tx := x + f64(i) * 81
		children << ui2.image_box(ui2.ImageBoxConfig{
			...tile
			frame: ui2.rect(tx, 230, 68, 68)
			theme: theme
		}) or { panic(err) }
		children << ui2.label('', tile_names[i], ui2.rect(tx - 6, 302, 80, 16), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			align: .center
		})
	}
	photo := photos[app.selected]
	children << caption('A gallery: the thumbnails are buttons with a selected ring', x, 328,
		col_w, theme)
	children << ui2.image_box(
		id:         'gallery-main'
		frame:      ui2.rect(x, 348, col_w, 140)
		path:       app.picture(photo.file)
		alt:        photo.alt
		radius:     8
		background: theme.muted
		theme:      theme
	) or { panic(err) }
	for i, p in photos {
		children << ui2.image_box(
			id:       'thumb-${i}'
			frame:    ui2.rect(x + f64(i) * 58, 496, 48, 48)
			path:     app.picture(p.file)
			alt:      'Show ${p.name}'
			fit:      .cover
			radius:   6
			action:   'thumb:${i}'
			selected: i == app.selected
			theme:    theme
		) or { panic(err) }
	}
	children << ui2.label('', 'Selected: ${photo.name}', ui2.rect(x + 186, 508, 200, 22),
		ui2.TextStyle{
			color: theme.foreground
			size:  14
		})
}

// ── Label ────────────────────────────────────────────────────────────

fn label_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	x := col_b
	children << section_title('Label', x, 64, theme)
	children << caption('secondary text and a required marker', x, 92, col_w, theme)
	children << ui2.styled_label(
		frame:     ui2.rect(x, 110, col_w, 24)
		text:      'Company Address'
		secondary: '(optional)'
		theme:     theme
	) or { panic(err) }
	children << ui2.styled_label(
		frame:           ui2.rect(x, 134, col_w, 24)
		text:            'Email Address'
		secondary:       '*'
		secondary_color: theme.danger
		theme:           theme
	) or { panic(err) }
	children << ui2.styled_label(
		frame:     ui2.rect(x, 158, col_w, 24)
		text:      'Password'
		secondary: '(minimum 8 characters)'
		theme:     theme
	) or { panic(err) }
	children << caption('align left, center and right', x, 190, col_w, theme)
	for i, align in [ui2.Align.left, .center, .right] {
		bx := x + f64(i) * 134
		children << ui2.view('', ui2.rect(bx, 208, 124, 28), ui2.BoxStyle{
			bg:     theme.muted
			radius: 6
		}, [
			ui2.styled_label(
				frame: ui2.rect(8, 0, 108, 28)
				text:  ['Left', 'Center', 'Right'][i]
				align: align
				theme: theme
			) or { panic(err) },
		])
	}
	children << caption('highlights, ignoring case; type to search:', x, 250, 250, theme)
	children << ui2.text_field_with_change('query', 'Highlight', app.query, ui2.rect(x + 262,
		244, 130, 26), field_box(theme, false), ui2.TextStyle{
		color: theme.foreground
		size:  13
	}, ui2.keyboard_default)
	rows := [
		ui2.StyledLabelConfig{
			text: 'Hello World Hello Universe'
		},
		ui2.StyledLabelConfig{
			text:            'Hello World, hello again'
			highlight_match: .prefix
		},
		ui2.StyledLabelConfig{
			text:                 'Company Name, said hello'
			secondary:            '(optional)'
			highlight_background: true
		},
	]
	modes := ['every match', 'prefix only', 'with a mark']
	for i, row in rows {
		y := 278 + f64(i) * 24
		children << ui2.styled_label(ui2.StyledLabelConfig{
			...row
			frame:     ui2.rect(x, y, 300, 24)
			highlight: app.query
			theme:     theme
		}) or { panic(err) }
		children << ui2.label('', modes[i], ui2.rect(x + 300, y, 92, 24), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
			align: .right
		})
	}
	children << caption('masked, for sensitive values', x, 356, col_w, theme)
	children << ui2.styled_label(
		frame:     ui2.rect(x, 372, 240, 34)
		text:      '$9,182.50 USD'
		masked:    app.masked
		font_size: 24
		bold:      true
		theme:     theme
	) or { panic(err) }
	children << icon_button('mask', if app.masked { 'eye.slash' } else { 'eye' }, ui2.rect(x + 250,
		373, 32, 32), theme)
	children << caption('wraps at the frame, line height 20, highlights across lines', x,
		416, col_w, theme)
	children << ui2.styled_label(
		frame:       ui2.rect(x, 434, col_w, 60)
		text:        'Label should support text wrap by default: if the text is too long, it wraps to the next line, and a search such as hello stays highlighted wherever the line breaks.'
		highlight:   app.query
		line_height: 20
		valign:      .top
		theme:       theme
	) or { panic(err) }
	// Sizes, bottom-aligned on one line.
	mut sx := x
	for i, size in [24.0, 20, 16, 14, 12] {
		cfg := ui2.StyledLabelConfig{
			text:      ['2xl', 'Extra large', 'Medium', 'Small', 'Extra small'][i]
			font_size: size
			bold:      i == 0
			wrap:      false
			valign:    .bottom
			theme:     theme
		}
		w, _ := ui2.styled_label_size(cfg)
		children << ui2.styled_label(ui2.StyledLabelConfig{
			...cfg
			frame: ui2.rect(sx, 496, w, 32)
		}) or { panic(err) }
		sx += w + 10
	}
	for i, text in ['Verified', 'Pending review', 'Failed'] {
		sx2 := x + f64(i) * 134
		children << ui2.Element{
			...ui2.image('', 'symbol:' + ['checkmark.circle', 'exclamationmark.triangle', 'xmark.circle'][i], ui2.rect(sx2, 533, 16, 16))
			text_style: ui2.TextStyle{
				color: tone_color(theme, i)
			}
		}
		children << ui2.styled_label(
			frame: ui2.rect(sx2 + 21, 530, 110, 22)
			text:  text
			color: tone_color(theme, i)
			theme: theme
		) or { panic(err) }
	}
}

// ── Textarea ─────────────────────────────────────────────────────────

fn textarea_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	x := col_c
	w := 400.0
	children << section_title('Textarea', x, 64, theme)
	children << caption('rows: 4, a placeholder', x, 92, w, theme)
	children << ui2.textarea(
		id:          'notes'
		frame:       ui2.rect(x, 110, w, 0)
		text:        app.notes
		rows:        4
		placeholder: 'Write some notes…'
		theme:       theme
	) or { panic(err) }
	children << caption('auto-grow from 2 to 6 rows, max_length 200 and a counter', x, 212,
		w, theme)
	children << ui2.textarea(
		id:          'message'
		frame:       ui2.rect(x, 230, w, 0)
		text:        app.message
		min_rows:    2
		max_rows:    6
		max_length:  200
		placeholder: 'Write a message'
		theme:       theme
	) or { panic(err) }
	half := (w - 12) / 2
	children << caption('small and disabled', x, 388, half, theme)
	children << caption('large and read-only', x + half + 12, 388, half, theme)
	children << ui2.textarea(
		id:      'small'
		frame:   ui2.rect(x, 406, half, 0)
		text:    'A disabled textarea dims its text and fill.'
		rows:    3
		enabled: false
		size:    .small
		theme:   theme
	) or { panic(err) }
	children << ui2.textarea(
		id:       'large'
		frame:    ui2.rect(x + half + 12, 406, half, 0)
		text:     'Read-only text looks as usual and can be copied.'
		rows:     3
		readonly: true
		size:     .large
		theme:    theme
	) or { panic(err) }
	children << caption('invalid', x, 498, half, theme)
	children << caption('bordered: false', x + half + 12, 498, half, theme)
	children << ui2.textarea(
		id:      'invalid'
		frame:   ui2.rect(x, 516, half, 0)
		text:    'Needs a fix'
		rows:    1
		invalid: true
		theme:   theme
	) or { panic(err) }
	children << ui2.textarea(
		id:          'plain'
		frame:       ui2.rect(x + half + 12, 516, half, 0)
		rows:        1
		bordered:    false
		placeholder: 'No border, muted fill'
		theme:       ui2.ComponentTheme{
			...theme
			background: theme.muted
		}
	) or { panic(err) }
}

// ── Tooltip ──────────────────────────────────────────────────────────

fn tool_frame(i int) ui2.Rect {
	return ui2.rect(col_a + f64(i) * 40, 616, 32, 32)
}

fn status_frame(i int) ui2.Rect {
	return ui2.rect(col_a + 236 + f64(i) * 20, 626, 12, 12)
}

const instant_frame = ui2.rect(col_a + 212 + 80, 616, 100, 32)

const file_frame = ui2.rect(col_a, 718, 180, 36)

const email_frame = ui2.rect(col_a, 812, 180, 28)

fn email_valid(email string) bool {
	at := email.index('@') or { return false }
	return at > 0 && email[at + 1..].contains('.') && !email.ends_with('.')
}

fn tooltip_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	x := col_a
	children << section_title('Tooltip', x, 568, theme)
	children << caption('500 ms to open, 300 ms grace, then switching at once', x, 596, col_w,
		theme)
	for i, tool in tools {
		children << ui2.tooltip_trigger('tips', tool.key, -1, icon_button('tool:${tool.key}',
			tool.symbol, tool_frame(i), theme)) or { panic(err) }
	}
	for i, s in statuses {
		children << ui2.tooltip_trigger('tips', s.key, -1, ui2.view('dot:${s.key}', status_frame(i),
			ui2.BoxStyle{
				bg:     tone_color(theme, s.color)
				radius: 6
			}, []ui2.Element{})) or { panic(err) }
	}
	children << ui2.tooltip_trigger('tips', 'instant', 0, text_button('instant', 'No delay',
		instant_frame, theme, false)) or { panic(err) }
	// A file row with a rich tooltip of its own.
	children << ui2.tooltip_trigger('info', 'file', -1, ui2.view('file', file_frame, field_box(theme,
		false), [
		ui2.Element{
			...ui2.image('', 'symbol:doc.fill', ui2.rect(10, 10, 16, 16))
			text_style: ui2.TextStyle{
				color: theme.primary
			}
		},
		ui2.label('', 'document.txt', ui2.rect(34, 0, 140, 36), ui2.TextStyle{
			color: theme.foreground
			size:  13
		}),
	])) or { panic(err) }
	children << caption('rich content: an icon, a title, a description and a key', x, 698,
		col_w, theme)
	children << caption('a tone and an arrow, shown while the email is invalid', x, 792, col_w,
		theme)
	children << caption('A click hides a tooltip until the pointer leaves; Escape hides it.',
		x, 848, col_w, theme)
	children << ui2.text_field_with_change('email', 'Email', app.email, email_frame, field_box(theme,
		!email_valid(app.email)), ui2.TextStyle{
		color: theme.foreground
		size:  13
	}, ui2.keyboard_default)
}

fn tooltip_overlays(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	window := ui2.bounds()
	for i, tool in tools {
		children << ui2.tooltip_popup(
			id:       'tip:${tool.key}'
			open:     app.tips.shows(tool.key)
			anchor:   tool_frame(i)
			window:   window
			text:     tool.tip
			shortcut: tool.shortcut
			keys:     tool.keys
			theme:    theme
		) or { panic(err) }
	}
	for i, s in statuses {
		children << ui2.tooltip_popup(
			id:     'tip:${s.key}'
			open:   app.tips.shows(s.key)
			anchor: status_frame(i)
			window: window
			text:   s.tip
			side:   .top
			arrow:  true
			theme:  theme
		) or { panic(err) }
	}
	children << ui2.tooltip_popup(
		id:     'tip:instant'
		open:   app.tips.shows('instant')
		anchor: instant_frame
		window: window
		text:   'Opens without waiting'
		theme:  theme
	) or { panic(err) }
	children << ui2.tooltip_popup(
		id:          'tip:file'
		open:        app.info.shows('file')
		anchor:      file_frame
		window:      window
		side:        .right
		align:       .start
		icon:        'doc.fill'
		title:       'document.txt'
		text:        'Size: 2.4 KB'
		description: 'Modified 2 hours ago'
		keys:        ['Enter']
		max_width:   240
		theme:       theme
	) or { panic(err) }
	children << ui2.tooltip_popup(
		id:     'tip:email'
		open:   !email_valid(app.email)
		anchor: email_frame
		window: window
		side:   .right
		icon:   'exclamationmark.circle'
		text:   'Enter a valid email address'
		tone:   .danger
		arrow:  true
		theme:  theme
	) or { panic(err) }
}

// ── Scrollable ───────────────────────────────────────────────────────

const files_frame = ui2.rect(col_b, 616, 220, 236)

fn file_rows(theme ui2.ComponentTheme) []ui2.Element {
	kinds := ['doc.text.fill', 'photo', 'folder.fill', 'chart.bar']
	mut rows := []ui2.Element{cap: 40}
	for i in 0 .. 40 {
		rows << ui2.view('row-${i}', ui2.rect(0, 0, 0, 26), ui2.BoxStyle{
			bg:     if i % 2 == 0 { theme.muted } else { theme.background }
			radius: 4
		}, [
			ui2.Element{
				...ui2.image('', 'symbol:' + kinds[i % kinds.len], ui2.rect(8, 6, 14, 14))
				text_style: ui2.TextStyle{
					color: theme.muted_foreground
				}
			},
			ui2.label('', 'file-${i + 1:02}.txt', ui2.rect(30, 0, 120, 26), ui2.TextStyle{
				color: theme.foreground
				size:  13
			}),
		])
	}
	return rows
}

fn files_config(theme ui2.ComponentTheme) ui2.ScrollableConfig {
	return ui2.ScrollableConfig{
		id:        'files'
		frame:     files_frame
		padding:   6
		gap:       2
		stack:     .column
		bordered:  true
		scrollbar: .always
		children:  file_rows(theme)
		label:     'Files'
		theme:     theme
	}
}

fn files_metrics(app &Gallery, theme ui2.ComponentTheme) ui2.ScrollMetrics {
	config := files_config(theme)
	_, content := ui2.scrollable_content_size(config)
	return ui2.scroll_metrics(app.files_offset, content, ui2.scrollable_viewport(config).height)
}

fn files_bar(app &Gallery, theme ui2.ComponentTheme) ui2.ScrollbarConfig {
	m := files_metrics(app, theme)
	return ui2.ScrollbarConfig{
		id:       'files-bar'
		frame:    ui2.rect(files_frame.x + files_frame.width + 4, files_frame.y, 12, files_frame.height)
		offset:   m.offset
		content:  m.content
		viewport: m.viewport
		mode:     app.bar_mode
		active:   if app.bar_mode == .hover { app.files_hover } else { app.files_active }
		hovered:  app.bar_hovered
		dragging: app.bar_drag.active
		theme:    theme
	}
}

fn scroll_section(mut children []ui2.Element, app &Gallery, theme ui2.ComponentTheme) {
	x := col_b
	children << section_title('Scrollable', x, 568, theme)
	children << caption('a padded column, its scroller kept on screen, a themed bar beside it', x,
		596, 400, theme)
	children << ui2.with_hover(ui2.with_action(ui2.scrollable(files_config(theme)) or {
		panic(err)
	}, 'files-area'))
	children << ui2.scrollbar(files_bar(app, theme)) or { panic(err) }
	m := files_metrics(app, theme)
	rx := files_frame.x + files_frame.width + 26
	children << ui2.label('', 'Offset ${int(m.offset)} of ${int(m.max_offset())}', ui2.rect(rx,
		616, 140, 18), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})
	children << ui2.label('', '${int(math.round(m.progress() * 100))}% · ${if m.at_end() {
		'at the end'
	} else if m.at_start() {
		'at the start'
	} else {
		'in between'
	}}', ui2.rect(rx, 636, 140, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
	for i, item in [['top', 'Top'], ['row25', 'Row 25, centered'], ['bottom', 'Bottom']] {
		children << text_button('scroll:${item[0]}', item[1], ui2.rect(rx, 664 + f64(i) * 34, 140,
			28), theme, false)
	}
	mode_name := match app.bar_mode {
		.always { 'always' }
		.hover { 'hover' }
		.scrolling { 'scrolling' }
	}
	children << text_button('bar-mode', 'Bar: ${mode_name}', ui2.rect(rx, 772, 140, 28),
		theme, true)
	// A row of cards, sideways.
	cx := col_c
	children << caption('a row of cards, sideways', cx, 596, 400, theme)
	mut cards := []ui2.Element{}
	for i in 0 .. 12 {
		color := [theme.primary, theme.success, tone_color(theme, 1), theme.danger][i % 4]
		cards << ui2.view('card-${i}', ui2.rect(0, 0, 110, 0), ui2.BoxStyle{
			bg:     mix(color, theme.background, 0.75)
			radius: 8
		}, [
			ui2.label('', 'Card ${i + 1}', ui2.rect(10, 8, 90, 20), ui2.TextStyle{
				color: theme.foreground
				size:  13
				bold:  true
			}),
			ui2.label('', '${(i + 1) * 3} items', ui2.rect(10, 30, 90, 18), ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
			}),
		])
	}
	children << ui2.scrollable(
		id:       'cards'
		frame:    ui2.rect(cx, 616, 400, 96)
		axis:     .horizontal_only
		stack:    .row
		padding:  10
		gap:      10
		bordered: true
		children: cards
		theme:    theme
	) or { panic(err) }
	// A grid larger than its pane both ways.
	children << caption('both axes: a 720 × 420 grid', cx, 722, 400, theme)
	mut cells := []ui2.Element{}
	for row in 0 .. 7 {
		for col in 0 .. 9 {
			shade := f64((row + col) % 4) * 0.18
			cells << ui2.view('', ui2.rect(f64(col) * 80, f64(row) * 60, 76, 56), ui2.BoxStyle{
				bg:     mix(theme.muted, theme.primary, shade)
				radius: 4
			}, [
				ui2.label('', '${rune(`A` + col)}${row + 1}', ui2.rect(0, 0, 76, 56),
					ui2.TextStyle{
						color: theme.foreground
						size:  13
						align: .center
					}),
			])
		}
	}
	children << ui2.scrollable(
		id:       'canvas'
		frame:    ui2.rect(cx, 740, 400, 112)
		axis:     .both
		padding:  4
		bordered: true
		children: cells
		theme:    theme
	) or { panic(err) }
}

// ── Build and events ─────────────────────────────────────────────────

fn build() ui2.Element {
	app := gallery()
	theme := ui2.component_theme(app.dark)
	mut children := [
		ui2.label('', 'GPUI Kit basics', ui2.rect(24, 16, 300, 28), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
		ui2.label('', app.status, ui2.rect(220, 22, 900, 18), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
		text_button('theme', if app.dark { 'Light theme' } else { 'Dark theme' }, ui2.rect(window_width - 130,
			16, 106, 28), theme, app.dark),
	]
	image_section(mut children, app, theme)
	label_section(mut children, app, theme)
	textarea_section(mut children, app, theme)
	tooltip_section(mut children, app, theme)
	scroll_section(mut children, app, theme)
	tooltip_overlays(mut children, app, theme)
	return ui2.screen(theme.background, children)
}

// apply_tooltip stores a group's next state and runs the timer work it asks for.
fn apply_tooltip(which string, step ui2.TooltipStep) {
	mut app := gallery()
	if which == 'tips' {
		app.tips = step.state
	} else {
		app.info = step.state
	}
	timer := if which == 'tips' { app.tips_timer } else { app.info_timer }
	if step.cancel {
		ui2.cancel_timer(timer)
	}
	if step.schedule {
		generation := step.state.generation
		id := ui2.after(step.delay, fn [which, generation] () {
			latest := gallery()
			group := if which == 'tips' { latest.tips } else { latest.info }
			apply_tooltip(which, group.timer_fired(generation))
		})
		if which == 'tips' {
			app.tips_timer = id
		} else {
			app.info_timer = id
		}
	}
}

fn scroll_files_to(offset f64) {
	mut app := gallery()
	app.files_offset = offset
	ui2.scroll_to_offset(ui2.scrollable_scroll_id('files'), offset)
}

// files_scrolled shows a .scrolling bar for a moment after each move.
fn files_scrolled() {
	mut app := gallery()
	app.files_active = true
	ui2.cancel_timer(app.files_timer)
	app.files_timer = ui2.after(1.0, fn () {
		mut latest := gallery()
		latest.files_active = false
	})
}

fn (mut app Gallery) handle(event string) bool {
	if step := ui2.tooltip_step('tips', app.tips, event) {
		apply_tooltip('tips', step)
		return true
	}
	if step := ui2.tooltip_step('info', app.info, event) {
		apply_tooltip('info', step)
		return true
	}
	theme := ui2.component_theme(app.dark)
	if step := ui2.scrollbar_step(files_bar(app, theme), app.bar_drag, event) {
		app.bar_drag = step.drag
		app.bar_hovered = step.hovered
		if math.abs(step.offset - app.files_offset) > 0.01 {
			scroll_files_to(step.offset)
			files_scrolled()
		}
		return true
	}
	if pointer := ui2.parse_pointer_event(event) {
		if pointer.action == 'files-area' {
			app.files_hover = pointer.phase == 'enter'
			return true
		}
		return false
	}
	if event.starts_with('tool:') {
		key := event['tool:'.len..]
		apply_tooltip('tips', app.tips.pressed(key))
		app.status = 'Pressed ${key}; its tooltip stays hidden until the pointer leaves.'
		return true
	}
	if event.starts_with('thumb:') {
		app.selected = event['thumb:'.len..].int()
		app.status = 'Showing ${photos[app.selected].name}.'
		return true
	}
	m := files_metrics(app, theme)
	match event {
		'theme' {
			app.dark = !app.dark
		}
		'query' {
			app.query = ui2.text('query')
		}
		'mask' {
			app.masked = !app.masked
		}
		'notes' {
			app.notes = ui2.text('notes')
		}
		'message' {
			app.message = ui2.textarea_limit(ui2.text('message'), 200)
		}
		'email' {
			app.email = ui2.text('email')
		}
		'instant' {
			apply_tooltip('tips', app.tips.pressed('instant'))
		}
		'scroll:top' {
			scroll_files_to(0)
		}
		'scroll:row25' {
			// Row 25 starts after 24 rows of 26 points, 2 apart, below the padding.
			scroll_files_to(m.reveal(6 + 24 * 28, 26, .center))
		}
		'scroll:bottom' {
			scroll_files_to(m.max_offset())
		}
		'bar-mode' {
			app.bar_mode = match app.bar_mode {
				.always { ui2.ScrollbarMode.hover }
				.hover { .scrolling }
				.scrolling { .always }
			}
		}
		else {
			return false
		}
	}
	return true
}

fn on_event(event string) {
	mut app := gallery()
	if app.handle(event) {
		ui2.refresh()
	}
}

fn on_scroll(id string) {
	mut app := gallery()
	if id != ui2.scrollable_scroll_id('files') {
		return
	}
	app.files_offset = ui2.scroll_offset(id)
	files_scrolled()
	ui2.refresh()
}

fn on_key(event ui2.KeyEvent) {
	app := gallery()
	if event.code != .escape || (!app.tips.open && !app.info.open) {
		return
	}
	apply_tooltip('tips', app.tips.dismissed())
	apply_tooltip('info', app.info.dismissed())
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	mut app := gallery()
	app.dir = ensure_pictures()
	ui2.on_scroll(on_scroll)
	ui2.on_key_event(on_key)
	ui2.run_window('GPUI Kit basics', window_width, window_height, build, on_event)
}
