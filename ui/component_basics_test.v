// SPDX-License-Identifier: Apache-2.0
// The label highlight cases follow the inputs and expectations of GPUI Kit's
// crates/component/src/label.rs tests (Longbridge, copyright 2024 - 2026);
// the other tests are new. See third_party/gpui-kit.
module ui2

import math
import os

// ── Helpers ─────────────────────────────────────────────────────────

fn basics_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := basics_find(child, id) {
			return found
		}
	}
	return none
}

fn basics_collect(el Element, kind Kind) []Element {
	mut found := []Element{}
	if el.kind == kind {
		found << el
	}
	for child in el.children {
		found << basics_collect(child, kind)
	}
	return found
}

fn basics_texts(el Element) []string {
	return basics_collect(el, .label).map(it.text)
}

fn basics_close(a f64, b f64) bool {
	return math.abs(a - b) < 1e-6
}

fn basics_rect_close(a Rect, b Rect) bool {
	return basics_close(a.x, b.x) && basics_close(a.y, b.y) && basics_close(a.width, b.width)
		&& basics_close(a.height, b.height)
}

fn basics_temp_dir() string {
	dir := os.join_path(os.vtmp_dir(), 'ui2_basics_test_${os.getpid()}')
	os.mkdir_all(dir) or { panic(err) }
	return dir
}

// ── Image ───────────────────────────────────────────────────────────

fn test_image_fit_rect_follows_object_fit() {
	// A 200 x 100 image in a 100 x 100 frame.
	assert basics_rect_close(image_fit_rect(.contain, 100, 100, 200, 100, 0.5, 0.5), rect(0,
		25, 100, 50))
	assert basics_rect_close(image_fit_rect(.cover, 100, 100, 200, 100, 0.5, 0.5), rect(-50,
		0, 200, 100))
	assert basics_rect_close(image_fit_rect(.fill, 100, 100, 200, 100, 0.5, 0.5), rect(0, 0,
		100, 100))
	assert basics_rect_close(image_fit_rect(.none, 100, 100, 200, 100, 0.5, 0.5), rect(-50, 0,
		200, 100))
	// scale_down never enlarges a small image, but shrinks a large one.
	assert basics_rect_close(image_fit_rect(.scale_down, 100, 100, 40, 20, 0.5, 0.5), rect(30,
		40, 40, 20))
	assert basics_rect_close(image_fit_rect(.scale_down, 100, 100, 200, 100, 0.5, 0.5),
		image_fit_rect(.contain, 100, 100, 200, 100, 0.5, 0.5))
	// The position picks the part a crop keeps and where spare room goes.
	assert basics_rect_close(image_fit_rect(.cover, 100, 100, 200, 100, 0, 0.5), rect(0, 0, 200,
		100))
	assert basics_rect_close(image_fit_rect(.cover, 100, 100, 200, 100, 1, 0.5), rect(-100, 0,
		200, 100))
	assert basics_rect_close(image_fit_rect(.contain, 100, 100, 200, 100, 0.5, 0), rect(0, 0,
		100, 50))
	// Out-of-range and non-finite positions are held to the frame or centered.
	assert basics_rect_close(image_fit_rect(.contain, 100, 100, 200, 100, 7, math.nan()),
		rect(0, 25, 100, 50))
	// An unknown size fills the frame.
	assert basics_rect_close(image_fit_rect(.cover, 80, 60, 0, 100, 0.5, 0.5), rect(0, 0, 80,
		60))
	assert basics_rect_close(image_fit_rect(.contain, 80, 60, math.inf(1), 10, 0.5, 0.5),
		rect(0, 0, 80, 60))
}

fn basics_write(path string, bytes []u8) {
	os.write_file_array(path, bytes) or { panic(err) }
}

fn test_image_natural_size_reads_headers() {
	dir := basics_temp_dir()
	defer {
		os.rmdir_all(dir) or {}
	}
	mut png := [u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, `I`, `H`, `D`, `R`]
	png << [u8(0), 0, 0x01, 0x40, 0, 0, 0, 0xb4] // 320 x 180
	png << []u8{len: 13}
	basics_write(os.join_path(dir, 'a.png'), png)
	size := image_natural_size(os.join_path(dir, 'a.png')) or { panic('png') }
	assert size.width == 320 && size.height == 180
	mut gif := 'GIF89a'.bytes()
	gif << [u8(0x10), 0, 0x20, 0] // 16 x 32
	gif << []u8{len: 10}
	basics_write(os.join_path(dir, 'b.gif'), gif)
	g := image_natural_size(os.join_path(dir, 'b.gif')) or { panic('gif') }
	assert g.width == 16 && g.height == 32
	// A top-down BMP stores a negative height.
	mut bmp := 'BM'.bytes()
	bmp << []u8{len: 12}
	bmp << [u8(40), 0, 0, 0, 0x64, 0, 0, 0, 0xce, 0xff, 0xff, 0xff] // 100 x -50
	bmp << []u8{len: 8}
	basics_write(os.join_path(dir, 'c.bmp'), bmp)
	b := image_natural_size(os.join_path(dir, 'c.bmp')) or { panic('bmp') }
	assert b.width == 100 && b.height == 50
	// JPEG: SOI, an APP0 segment to skip, then SOF0 with height 240, width 427.
	mut jpg := [u8(0xff), 0xd8, 0xff, 0xe0, 0, 6, `J`, `F`, `I`, `F`, 0xff, 0xc0, 0, 17, 8, 0,
		0xf0, 0x01, 0xab]
	jpg << []u8{len: 20}
	basics_write(os.join_path(dir, 'd.jpg'), jpg)
	j := image_natural_size(os.join_path(dir, 'd.jpg')) or { panic('jpg') }
	assert j.width == 427 && j.height == 240
	// WebP, extended (VP8X): 1 + 639 by 1 + 359.
	mut webp := 'RIFF'.bytes()
	webp << [u8(0), 0, 0, 0]
	webp << 'WEBPVP8X'.bytes()
	webp << []u8{len: 8}
	webp << [u8(0x7f), 0x02, 0, 0x67, 0x01, 0]
	basics_write(os.join_path(dir, 'e.webp'), webp)
	w := image_natural_size(os.join_path(dir, 'e.webp')) or { panic('webp') }
	assert w.width == 640 && w.height == 360
	// Unknown formats, short files, missing files and zero sizes are none.
	basics_write(os.join_path(dir, 'f.txt'), 'hello there, not an image'.bytes())
	for name in ['f.txt', 'missing.png'] {
		if _ := image_natural_size(os.join_path(dir, name)) {
			assert false, '${name} has a size'
		}
	}
	mut empty_png := png.clone()
	empty_png[16] = 0
	empty_png[17] = 0
	empty_png[18] = 0
	empty_png[19] = 0
	basics_write(os.join_path(dir, 'g.png'), empty_png)
	if _ := image_natural_size(os.join_path(dir, 'g.png')) {
		assert false, 'zero width accepted'
	}
	// A truncated JPEG never reaches a frame.
	basics_write(os.join_path(dir, 'h.jpg'), [u8(0xff), 0xd8, 0xff, 0xe0, 0x40, 0, 1, 2, 3, 4,
		5, 6])
	if _ := image_natural_size(os.join_path(dir, 'h.jpg')) {
		assert false, 'truncated jpeg has a size'
	}
	sym := image_natural_size('symbol:photo') or { panic('symbol') }
	assert sym.width == sym.height
}

fn test_image_box_states_and_fit_frames() {
	dir := basics_temp_dir()
	defer {
		os.rmdir_all(dir) or {}
	}
	path := os.join_path(dir, 'wide.gif')
	mut gif := 'GIF89a'.bytes()
	gif << [u8(200), 0, 100, 0]
	gif << []u8{len: 10}
	basics_write(path, gif)
	// Contain: the image keeps its shape in the middle of the frame.
	contained := image_box(id: 'pic', frame: rect(10, 20, 100, 100), path: path, alt: 'Wide')!
	pictures := basics_collect(contained, .image)
	assert pictures.len == 1
	assert basics_rect_close(pictures[0].frame, rect(0, 25, 100, 50))
	assert contained.accessibility_role == 'img'
	assert contained.accessibility_label == 'Wide'
	assert image_box_status(ImageBoxConfig{ path: path }) == .ready
	// Cover crops: the image sits in an id-less Scroll whose one child ends at
	// its right edge, so it clips without anything to scroll.
	covered := image_box(id: 'cover', frame: rect(0, 0, 100, 100), path: path, fit: .cover)!
	scrolls := basics_collect(covered, .scroll)
	assert scrolls.len == 1
	assert scrolls[0].id == ''
	assert scrolls[0].scroll_mode == .horizontal_only
	assert scrolls[0].box.transparent
	content := scrolls[0].children[0]
	assert basics_close(content.frame.x + content.frame.width, 100)
	assert basics_close(content.frame.x, -50)
	assert basics_collect(covered, .image)[0].frame.width == 200
	// A natural size given in the config wins over the header.
	given := image_box(
		frame:          rect(0, 0, 100, 100)
		path:           path
		natural_width:  100
		natural_height: 200
	)!
	assert basics_rect_close(basics_collect(given, .image)[0].frame, rect(25, 0, 50, 100))
	// Rounded corners are painted over with the backdrop, in an even-odd shape.
	rounded := image_box(id: 'round', frame: rect(0, 0, 64, 64), path: path, circle: true)!
	mask := basics_find(rounded, component_part_id('round', 'corners')) or { panic('no mask') }
	assert mask.shape_style.fill_rule == .even_odd
	assert (mask.shape_style.fill or { 0 }) == ComponentTheme{}.background
	assert image_box_corner_radius(ImageBoxConfig{ frame: rect(0, 0, 64, 40), circle: true }) == 20
	assert image_box_corner_radius(ImageBoxConfig{ frame: rect(0, 0, 64, 40), radius: 50 }) == 20
	// A missing file shows the fallback: a muted box with the icon and text.
	missing := image_box(
		frame:         rect(0, 0, 120, 90)
		path:          os.join_path(dir, 'nope.png')
		fallback_text: 'Image unavailable'
	)!
	assert basics_collect(missing, .image)[0].image_path == 'symbol:photo'
	assert 'Image unavailable' in basics_texts(missing)
	assert missing.accessibility_label == 'Image unavailable'
	assert image_box_status(ImageBoxConfig{ path: 'symbol:not-a-symbol' }) == .failed
	assert image_box_status(ImageBoxConfig{ path: 'symbol:photo' }) == .ready
	assert image_box_status(ImageBoxConfig{ path: '' }) == .failed
	// Loading keeps the box: a shimmer with an id, a static fill without one.
	loading := image_box(id: 'load', frame: rect(0, 0, 80, 60), path: path, loading: true)!
	assert basics_collect(loading, .image).len == 0
	assert image_box_status(ImageBoxConfig{ path: path, loading: true }) == .loading
	sweep := component_part_id(component_part_id('load', 'loading'), '')
	mut parts := []string{}
	for v in basics_collect(loading, .view) {
		if v.id.starts_with(sweep) {
			parts << v.id
		}
	}
	assert parts.len > 0
	image_box_stop_loading('load')
	for part in parts {
		assert animation_info(part).status == .idle
	}
	still := image_box(
		frame:        rect(0, 0, 80, 60)
		path:         path
		loading:      true
		loading_text: 'Loading…'
	)!
	assert 'Loading…' in basics_texts(still)
	assert still.accessibility_label == 'Loading…'
	// failed wins over loading.
	assert image_box_status(ImageBoxConfig{ path: path, loading: true, failed: true }) == .failed
	// With an action it is a button, ringed when selected.
	thumb := image_box(
		id:       't1'
		frame:    rect(0, 0, 48, 48)
		path:     path
		action:   'pick:1'
		selected: true
		alt:      'Show wide'
	)!
	assert thumb.button_behavior
	assert thumb.action_id == 'pick:1'
	assert thumb.accessibility_role == 'button'
	assert thumb.accessibility_value == 'selected'
	assert basics_find(thumb, component_part_id('t1', 'ring')) != none
	if _ := image_box(frame: rect(0, 0, 10, 10), path: path, action: 'x') {
		assert false, 'action without id accepted'
	}
	if _ := image_box(frame: rect(0, 0, 10, 10), path: path, radius: -1) {
		assert false, 'negative radius accepted'
	}
	if _ := image_box(frame: rect(0, 0, -10, 10), path: path) {
		assert false, 'negative frame accepted'
	}
	// A decorative image is presentation.
	plain := image_box(frame: rect(0, 0, 10, 10), path: path)!
	assert plain.accessibility_role == 'presentation'
}

// ── Label ───────────────────────────────────────────────────────────

fn test_label_highlight_ranges_match_upstream_cases() {
	assert label_highlight_ranges('Hello World', '', .full).len == 0
	assert label_highlight_ranges('Hello World', 'xyz', .full).len == 0
	assert label_highlight_ranges('Hello World', 'WORLD', .full) == [LabelRange{6, 11}]
	assert label_highlight_ranges('Hello Hello Hello', 'Hello', .full) == [
		LabelRange{0, 5},
		LabelRange{6, 11},
		LabelRange{12, 17},
	]
	overlapping := label_highlight_ranges('aaaa', 'aa', .full)
	assert overlapping.len == 3
	assert overlapping[1] == LabelRange{1, 3}
	// Rune offsets, not bytes.
	assert label_highlight_ranges('你好世界，Hello World', '世界', .full) == [
		LabelRange{2, 4},
	]
	assert label_highlight_ranges('Hello Hello', 'Hello', .prefix) == [LabelRange{0, 5}]
	assert label_highlight_ranges('Hello hello HELLO', 'hello', .prefix) == [
		LabelRange{0, 5},
	]
	assert label_highlight_ranges('xyz Hello', 'Hello', .prefix).len == 0
	assert label_highlight_ranges('ab', 'abc', .prefix).len == 0
	assert label_highlight_ranges('ab', 'abc', .full).len == 0
	assert label_highlight_ranges('你好世界你好', '你好', .prefix) == [LabelRange{0, 2}]
	// Case folding beyond ASCII.
	assert label_highlight_ranges('ÄPFEL und äpfel', 'äpfel', .full).len == 2
	assert label_full_text('Hello', 'World') == 'Hello World'
	assert label_full_text('Hello', '') == 'Hello'
	assert label_masked_text('é🙂 世界') == '•••••'
}

fn test_styled_label_runs_secondary_highlight_and_mask() {
	el := styled_label(
		id:        'company'
		frame:     rect(0, 0, 400, 24)
		text:      'Company Name'
		secondary: '(optional)'
		highlight: 'company'
	)!
	assert el.accessibility_label == 'Company Name (optional)'
	assert basics_texts(el) == ['Company', ' Name', ' (optional)']
	labels := basics_collect(el, .label)
	theme := ComponentTheme{}
	assert labels[0].text_style.color == theme.primary
	assert labels[1].text_style.color == theme.foreground
	assert labels[2].text_style.color == theme.muted_foreground
	// Runs follow one another from the left.
	assert labels[0].frame.x == 0
	assert labels[1].frame.x > labels[0].frame.x
	assert labels[2].frame.x > labels[1].frame.x
	// A highlight running into the secondary text is cut at the boundary.
	across := styled_label(
		frame:     rect(0, 0, 400, 24)
		text:      'Hello'
		secondary: 'World'
		highlight: 'o W'
	)!
	assert basics_texts(across) == ['Hell', 'o', ' W', 'orld']
	// Masked: bullets, no highlight, a neutral accessibility label.
	masked := styled_label(
		frame:     rect(0, 0, 300, 30)
		text:      '9,182.50 USD'
		highlight: '9'
		masked:    true
	)!
	assert basics_texts(masked) == ['••••••••••••']
	assert masked.accessibility_label == 'Hidden'
	// The soft mark lays a view behind each match.
	marked := styled_label(
		frame:                rect(0, 0, 300, 24)
		text:                 'a b a'
		highlight:            'a'
		highlight_background: true
	)!
	assert basics_collect(marked, .view).len == 3
	if _ := styled_label(frame: rect(0, 0, 10, 10), text: 'x', font_size: math.nan()) {
		assert false, 'NaN font size accepted'
	}
}

fn test_styled_label_alignment_wrapping_and_truncation() {
	style := TextStyle{
		size: 14
	}
	width := basics_text_width('Short', style)
	right := styled_label(frame: rect(0, 0, 200, 20), text: 'Short', align: .right)!
	r := basics_collect(right, .label)[0]
	assert basics_close(r.frame.x, 200 - width)
	center := styled_label(frame: rect(0, 0, 200, 20), text: 'Short', align: .center)!
	assert basics_close(basics_collect(center, .label)[0].frame.x, (200 - width) / 2)
	// Wrapping cuts runs along the lines.
	words := 'one two three four five six seven eight nine ten'
	wrapped := styled_label(
		frame:     rect(0, 0, 120, 200)
		text:      words
		highlight: 'four'
		valign:    .top
	)!
	lines := basics_collect(wrapped, .label)
	mut ys := map[f64]bool{}
	for l in lines {
		ys[l.frame.y] = true
	}
	assert ys.len > 2
	assert lines.filter(it.text == 'four').len == 1
	w, h := styled_label_size(StyledLabelConfig{
		frame: rect(0, 0, 120, 0)
		text:  words
	})
	assert w <= 120
	assert basics_close(h, f64(ys.len) * styled_label_line_height(StyledLabelConfig{}))
	// A frame two lines tall ends on a line carrying the rest of the text.
	lh := styled_label_line_height(StyledLabelConfig{})
	short := styled_label(frame: rect(0, 0, 120, lh * 2), text: words)!
	shown := basics_collect(short, .label)
	assert shown.len == 2
	assert shown[1].text.ends_with('ten')
	assert basics_close(shown[1].frame.x + shown[1].frame.width, 120)
	// Without wrapping only newlines break.
	single := styled_label(frame: rect(0, 0, 50, 100), text: 'a long line\nnext', wrap: false)!
	assert basics_texts(single) == ['a long line', 'next']
	// The block is centered in a taller frame by default.
	middle := styled_label(frame: rect(0, 0, 200, 100), text: 'x')!
	assert basics_collect(middle, .label)[0].frame.y > 0
	// Spans keep their rune offsets, swallowing the break's space.
	spans := basics_wrap_spans('ab cd\nef'.runes(), 2.5, fn (s string) f64 {
		return f64(s.runes().len)
	})
	assert spans == [BasicsSpan{0, 2}, BasicsSpan{3, 5}, BasicsSpan{6, 8}]
	assert basics_wrap_spans([]rune{}, 10, fn (s string) f64 {
		return 0
	}) == [BasicsSpan{0, 0}]
	assert basics_wrap_spans('x\n'.runes(), 10, fn (s string) f64 {
		return 0
	}) == [BasicsSpan{0, 1}, BasicsSpan{2, 2}]
}

// ── Textarea ────────────────────────────────────────────────────────

fn test_textarea_limit_counter_and_rows() {
	assert textarea_limit('héllo wörld', 5) == 'héllo'
	assert textarea_limit('abc', 0) == 'abc'
	assert textarea_limit('abc', 3) == 'abc'
	assert textarea_count_text('héllo', 200) == '5 / 200'
	assert textarea_count_text('héllo', 0) == '5'
	assert textarea_over_limit('abcd', 3)
	assert !textarea_over_limit('abc', 3)
	assert !textarea_over_limit('abcd', 0)
	lh := textarea_line_height(.medium)
	fixed := TextareaConfig{
		id:    'notes'
		frame: rect(0, 0, 300, 0)
		rows:  5
	}
	assert textarea_rows(fixed) == 5
	assert basics_close(textarea_box_height(fixed), 5 * lh + 2 * textarea_text_top(.medium))
	// Auto-grow: one line of text sits at min_rows, many lines stop at max_rows.
	grow := TextareaConfig{
		id:       'msg'
		frame:    rect(0, 0, 300, 0)
		min_rows: 2
		max_rows: 4
		text:     'hi'
	}
	assert textarea_rows(grow) == 2
	assert textarea_rows(TextareaConfig{ ...grow, text: 'a\nb\nc' }) == 3
	assert textarea_rows(TextareaConfig{ ...grow, text: 'a\nb\nc\nd\ne\nf' }) == 4
	long := 'word '.repeat(80)
	assert textarea_line_count(TextareaConfig{ ...grow, text: long }) > 4
	assert textarea_rows(TextareaConfig{ ...grow, text: long }) == 4
	// A trailing newline starts a line of its own.
	assert textarea_line_count(TextareaConfig{ ...grow, text: 'a\n' }) == 2
	// With neither, the frame's height is the box.
	free := TextareaConfig{
		id:    'free'
		frame: rect(0, 0, 300, 120)
	}
	assert textarea_box_height(free) == 120
	assert textarea_height(TextareaConfig{ ...free, max_length: 10 }) == 120 + 4 + 16
}

fn test_textarea_builds_placeholder_counter_and_states() {
	el := textarea(
		id:          'bio'
		frame:       rect(10, 20, 320, 0)
		rows:        4
		placeholder: 'Tell us about yourself'
		max_length:  100
		label:       'Bio'
	)!
	assert el.frame.x == 10 && el.frame.y == 20
	assert basics_close(el.frame.height, textarea_height(TextareaConfig{
		id:         'bio'
		frame:      rect(10, 20, 320, 0)
		rows:       4
		max_length: 100
	}))
	area := basics_find(el, 'bio') or { panic('no text area') }
	assert area.kind == .text_area
	assert area.accessibility_label == 'Bio'
	assert 'Tell us about yourself' in basics_texts(el)
	assert '0 / 100' in basics_texts(el)
	box := basics_find(el, component_part_id('bio', 'box')) or { panic('no box') }
	placeholder_index := box.children.map(it.text).index('Tell us about yourself')
	area_index := box.children.map(it.id).index('bio')
	theme := ComponentTheme{}
	if textarea_painted() {
		// The renderer paints the text area's box, so the placeholder and the
		// border are drawn over it.
		assert area.frame == rect(0, 0, 320, box.frame.height)
		assert !area.box.transparent && area.box.bg == theme.background
		assert area_index >= 0 && area_index < placeholder_index
		border := basics_find(box, component_part_id('bio', 'border')) or { panic('no border') }
		assert (border.shape_style.stroke or { 0 }) == theme.border
	} else {
		// A clear text area over the placeholder, inset by the padding.
		assert area.box.transparent
		assert placeholder_index >= 0 && placeholder_index < area_index
		assert box.box.bg == theme.border
	}
	// Text hides the placeholder; over the limit the counter and border turn danger.
	over := textarea(
		id:          'bio'
		frame:       rect(0, 0, 320, 0)
		rows:        3
		text:        'x'.repeat(12)
		max_length:  10
		placeholder: 'P'
	)!
	assert 'P' !in basics_texts(over)
	counter := basics_collect(over, .label).filter(it.text == '12 / 10')
	assert counter.len == 1 && counter[0].text_style.color == theme.danger
	over_box := basics_find(over, component_part_id('bio', 'box')) or { panic('no box') }
	if textarea_painted() {
		border := basics_find(over_box, component_part_id('bio', 'border')) or { panic('none') }
		assert (border.shape_style.stroke or { 0 }) == theme.danger
	} else {
		assert over_box.box.bg == theme.danger
	}
	// Disabled and read-only reach the native text area.
	disabled := textarea(
		id:       'd'
		frame:    rect(0, 0, 200, 0)
		rows:     2
		enabled:  false
		readonly: true
	)!
	d := basics_find(disabled, 'd') or { panic('no area') }
	assert !d.enabled && d.readonly
	assert d.text_style.color == theme.muted_foreground
	// Without a border the edge takes the fill's color.
	plain := textarea(id: 'p', frame: rect(0, 0, 200, 0), rows: 2, bordered: false)!
	plain_box := basics_find(plain, component_part_id('p', 'box')) or { panic('no box') }
	if textarea_painted() {
		edge := basics_find(plain_box, component_part_id('p', 'border')) or { panic('none') }
		assert (edge.shape_style.stroke or { 0 }) == theme.background
	} else {
		assert plain_box.box.bg == theme.background
	}
	if _ := textarea(frame: rect(0, 0, 100, 100)) {
		assert false, 'textarea without id accepted'
	}
	if _ := textarea(id: 'x', frame: rect(0, 0, 100, 100), rows: -1) {
		assert false, 'negative rows accepted'
	}
}

// ── Tooltip ─────────────────────────────────────────────────────────

fn test_tooltip_state_delays_grace_and_switching() {
	s0 := TooltipGroup{}
	// Entering waits for the show delay.
	s1 := s0.entered('save', -1)
	assert s1.schedule && !s1.cancel
	assert s1.delay == 0.5
	assert !s1.state.open && s1.state.current == 'save'
	// A stale timer changes nothing; the right one opens it.
	assert !s1.state.timer_fired(s1.state.generation + 1).state.open
	s2 := s1.state.timer_fired(s1.state.generation)
	assert s2.state.shows('save')
	// Leaving starts the grace period; the tooltip stays meanwhile.
	s3 := s2.state.left('save')
	assert s3.schedule && s3.delay == 0.3
	assert s3.state.shows('save')
	assert s3.state.pending == .hide
	// Entering another trigger within the grace period switches at once.
	s4 := s3.state.entered('open', -1)
	assert s4.cancel && !s4.schedule
	assert s4.state.shows('open')
	assert !s4.state.shows('save')
	// After the grace period runs out, the tooltip closes.
	s5 := s4.state.left('open')
	s6 := s5.state.timer_fired(s5.state.generation)
	assert !s6.state.open && s6.state.current == ''
	// Then the next trigger waits again.
	assert s6.state.entered('new', -1).schedule
	// Sweeping across a trigger never opens it.
	s7 := s0.entered('x', -1)
	s8 := s7.state.left('x')
	assert s8.cancel && !s8.state.open && s8.state.current == ''
	assert !s8.state.timer_fired(s7.state.generation).state.open
	// A zero delay opens at once; a trigger's own delay wins over the state's.
	assert s0.entered('now', 0).state.shows('now')
	assert s0.entered('slow', 1.5).delay == 1.5
	// A zero grace period closes at once.
	quick := TooltipGroup{
		grace_period: 0
	}.entered('a', 0)
	assert !quick.state.left('a').state.open
	// A press hides it until the pointer leaves that trigger.
	p := s2.state.pressed('save')
	assert !p.state.open && p.state.suppressed == 'save'
	assert !p.state.entered('save', -1).state.open
	assert !p.state.entered('save', -1).schedule
	again := p.state.left('save').state.entered('save', -1)
	assert again.schedule
	// Escape.
	assert !s2.state.dismissed().state.open
	// Leaving a trigger that is not current leaves the open tooltip alone.
	assert s2.state.left('other').state.shows('save')
}

fn test_tooltip_trigger_actions_and_decoding() {
	assert tooltip_trigger_action('tips', 'save', -1) == 'tips:component:trigger:save'
	assert tooltip_trigger_action('tips', 'save', 0) == 'tips:component:trigger@0:save'
	assert tooltip_trigger_action('tips', 'a:b', 0.25) == 'tips:component:trigger@250:a:b'
	enter := tooltip_trigger_event('tips', 'pointer:enter:tips:component:trigger:save:10:20') or {
		panic('no event')
	}
	assert enter.key == 'save' && enter.entered && enter.delay < 0
	delayed := tooltip_trigger_event('tips', 'pointer:leave:tips:component:trigger@250:a:b:1:2') or {
		panic('no event')
	}
	assert delayed.key == 'a:b' && !delayed.entered && delayed.delay == 0.25
	for bad in ['pointer:down:tips:component:trigger:save:1:2',
		'pointer:enter:other:component:trigger:save:1:2', 'pointer:enter:tips:component:trigger::1:2',
		'pointer:enter:tips:component:trigger@x:save:1:2',
		'pointer:enter:tips:component:trigger@99999999:save:1:2',
		'pointer:enter:tips:component:other:1:2', 'tips:component:trigger:save',
		'pointer:enter:tips:component:trigger@05:k:1:2'] {
		if _ := tooltip_trigger_event('tips', bad) {
			assert false, 'decoded ${bad}'
		}
	}
	step := tooltip_step('tips', TooltipGroup{}, 'pointer:enter:tips:component:trigger@0:save:1:2') or {
		panic('no step')
	}
	assert step.state.shows('save')
	wrapped := tooltip_trigger('tips', 'save', -1, button('save', 'Save', rect(40, 50, 80, 28),
		BoxStyle{}, TextStyle{}))!
	assert wrapped.hoverable
	assert wrapped.id == 'tips:component:trigger:save'
	assert wrapped.frame == rect(40, 50, 80, 28)
	assert wrapped.children[0].frame == rect(0, 0, 80, 28)
	assert wrapped.children[0].id == 'save'
	if _ := tooltip_trigger('tips', '', -1, button('b', 'B', rect(0, 0, 1, 1), BoxStyle{},
		TextStyle{})) {
		assert false, 'empty key accepted'
	}
}

fn test_tooltip_surface_text_shortcut_rich_and_placement() {
	window := rect(0, 0, 800, 600)
	anchor := rect(100, 100, 80, 28)
	closed := tooltip_popup(id: 'tip', anchor: anchor, window: window, text: 'Save')!
	assert closed.hidden
	el := tooltip_popup(
		id:       'tip'
		open:     true
		anchor:   anchor
		window:   window
		text:     'Save the document'
		shortcut: 'cmd+s'
	)!
	assert !el.hidden
	surface := basics_find(el, component_part_id('tip', 'surface')) or { panic('no surface') }
	assert surface.accessibility_role == 'tooltip'
	assert surface.accessibility_label == 'Save the document'
	texts := basics_texts(el)
	assert 'Save the document' in texts
	assert menu_shortcut_label('cmd+s') in texts
	// Below the anchor, centered, by default.
	w, h := tooltip_popup_size(TooltipPopupConfig{
		text:     'Save the document'
		shortcut: 'cmd+s'
	})
	assert el.frame.width == w && el.frame.height == h
	assert el.frame.y >= anchor.y + anchor.height
	assert math.abs(el.frame.x + w / 2 - (anchor.x + anchor.width / 2)) <= 1
	// Placement flips at the window's edge.
	low := tooltip_popup(
		id:     'tip'
		open:   true
		anchor: rect(100, 580, 80, 16)
		window: window
		text:   'x'
	)!
	assert low.frame.y + low.frame.height <= 580
	left := tooltip_popup(
		id:     'tip'
		open:   true
		anchor: anchor
		window: window
		text:   'x'
		side:   .left
	)!
	assert left.frame.x + left.frame.width <= anchor.x
	// Long text wraps at max_width.
	long := 'A tooltip with a much longer message that has to wrap onto several lines'
	wrapped := tooltip_popup(
		id:        'tip'
		open:      true
		anchor:    anchor
		window:    window
		text:      long
		max_width: 180
	)!
	assert wrapped.frame.width <= 180
	assert basics_texts(wrapped).len > 1
	// Rich: icon, bold title, text and muted description.
	rich := tooltip_popup(
		id:          'rich'
		open:        true
		anchor:      anchor
		window:      window
		icon:        'doc.fill'
		title:       'document.txt'
		text:        'Size: 2.4 KB'
		description: 'Modified 2 hours ago'
		keys:        ['Enter']
	)!
	rich_labels := basics_collect(rich, .label)
	assert rich_labels[0].text == 'document.txt' && rich_labels[0].text_style.bold
	assert rich_labels.map(it.text) == ['document.txt', 'Size: 2.4 KB', 'Modified 2 hours ago',
		'Enter']
	assert basics_collect(rich, .image)[0].image_path == 'symbol:doc.fill'
	// Custom children get their own box under the text.
	custom := tooltip_popup(
		id:             'custom'
		open:           true
		anchor:         anchor
		window:         window
		text:           'Status'
		children:       [view('dot', rect(0, 0, 10, 10), BoxStyle{}, []Element{})]
		content_width:  120
		content_height: 30
	)!
	cw, ch := tooltip_popup_size(TooltipPopupConfig{
		text:           'Status'
		children:       [view('', rect(0, 0, 10, 10), BoxStyle{}, []Element{})]
		content_width:  120
		content_height: 30
	})
	assert cw >= 120 && ch >= 30
	assert basics_find(custom, 'dot') != none
	// A tone paints the surface; an arrow adds to the chrome.
	danger := tooltip_popup(
		id:     'err'
		open:   true
		anchor: anchor
		window: window
		text:   'Required'
		tone:   .danger
		arrow:  true
	)!
	err_surface := basics_find(danger, component_part_id('err', 'surface')) or { panic('none') }
	assert err_surface.box.bg == ComponentTheme{}.danger
	assert danger.children.len > 1
	if _ := tooltip_popup(open: true, anchor: anchor, window: window) {
		assert false, 'tooltip without id accepted'
	}
	if _ := tooltip_popup(id: 'x', anchor: anchor, window: window, max_width: math.inf(1)) {
		assert false, 'infinite width accepted'
	}
}

// ── Scrollable ──────────────────────────────────────────────────────

fn test_scroll_metrics_reveal_page_follow_and_keys() {
	m := scroll_metrics(100, 1000, 200)
	assert m.max_offset() == 800
	assert m.scrolls() && !m.at_start() && !m.at_end()
	assert basics_close(m.progress(), 0.125)
	assert basics_close(m.visible_fraction(), 0.2)
	assert m.clamp(-5) == 0 && m.clamp(5000) == 800 && m.clamp(math.nan()) == 0
	// Reveal a 40-point row at 500.
	assert m.reveal(500, 40, .start) == 500
	assert m.reveal(500, 40, .end) == 340
	assert m.reveal(500, 40, .center) == 420
	assert m.reveal(500, 40, .nearest) == 340
	assert m.reveal(120, 40, .nearest) == 100 // already in view
	assert m.reveal(20, 40, .nearest) == 20
	assert m.reveal(980, 40, .start) == 800 // clamped
	assert m.page(1) == 280 && m.page(-1) == 0
	// Following: at the end it keeps to the end; elsewhere it stays put.
	at_end := scroll_metrics(800, 1000, 200)
	assert at_end.at_end()
	assert at_end.follow(1300) == 1100
	assert m.follow(1300) == 100
	assert m.follow(150) == 0
	fits := scroll_metrics(0, 100, 200)
	assert !fits.scrolls() && fits.progress() == 0 && fits.visible_fraction() == 1
	assert scroll_metrics(-1, math.nan(), 10) == ScrollMetrics{0, 0, 10}
	// Keys.
	down := KeyEvent{
		code: .down
	}
	assert scroll_key_offset(m, down, 40, false) or { -1.0 } == 140
	assert scroll_key_offset(m, KeyEvent{ code: .right }, 40, true) or { -1.0 } == 140
	assert scroll_key_offset(m, KeyEvent{ code: .right }, 40, false) == none
	assert scroll_key_offset(m, KeyEvent{ code: .page_down }, 40, false) or { -1.0 } == 280
	assert scroll_key_offset(m, KeyEvent{ code: .space, shift: true }, 40, false) or { -1.0 } == 0
	assert scroll_key_offset(m, KeyEvent{ code: .end }, 40, false) or { -1.0 } == 800
	assert scroll_key_offset(m, KeyEvent{ code: .up, cmd: true }, 40, false) or { -1.0 } == 0
	assert scroll_key_offset(m, KeyEvent{ code: .a, cmd: true }, 40, false) == none
	assert scroll_key_offset(m, KeyEvent{ code: .down, ctrl: true }, 40, false) == none
	// A key that would not move the content is not taken.
	assert scroll_key_offset(scroll_metrics(0, 1000, 200), KeyEvent{ code: .home }, 40, false) == none
}

fn test_scrollable_stacks_pads_and_names_its_scroll() {
	rows := [view('a', rect(0, 0, 0, 30), BoxStyle{}, []Element{}),
		view('b', rect(0, 0, 0, 30), BoxStyle{}, []Element{}), Element{
			...view('hidden', rect(0, 0, 0, 30), BoxStyle{}, []Element{})
			hidden: true
		}, view('c', rect(10, 0, 100, 30), BoxStyle{}, []Element{})]
	config := ScrollableConfig{
		id:        'files'
		frame:     rect(20, 30, 240, 100)
		padding:   8
		gap:       4
		stack:     .column
		bordered:  true
		scrollbar: .always
		children:  rows
	}
	el := scrollable(config)!
	assert el.id == 'files'
	pane := basics_find(el, scrollable_scroll_id('files')) or { panic('no scroll') }
	assert pane.kind == .scroll
	assert pane.persistent_scrollbars
	assert pane.frame == rect(1, 1, 238, 98)
	a := basics_find(pane, 'a') or { panic('a') }
	b := basics_find(pane, 'b') or { panic('b') }
	c := basics_find(pane, 'c') or { panic('c') }
	assert a.frame == rect(8, 8, 222, 30)
	assert b.frame == rect(8, 42, 222, 30)
	// The hidden row takes no room.
	assert c.frame == rect(18, 76, 100, 30)
	w, h := scrollable_content_size(config)
	assert h == 76 + 30 + 8
	assert w == 230 + 8
	// The padding reaches the scroll range through a spacer at the far corner.
	mut bottom := 0.0
	for child in pane.children {
		bottom = math.max(bottom, child.frame.y + child.frame.height)
	}
	assert bottom == h
	// A row of cards, horizontally.
	cards := scrollable(
		id:       'cards'
		frame:    rect(0, 0, 300, 120)
		axis:     .horizontal_only
		stack:    .row
		gap:      10
		children: [view('k1', rect(0, 0, 100, 0), BoxStyle{}, []Element{}),
			view('k2', rect(0, 0, 100, 0), BoxStyle{}, []Element{})]
	)!
	k2 := basics_find(cards, 'k2') or { panic('k2') }
	assert k2.frame == rect(110, 0, 100, 120)
	scroller := basics_find(cards, scrollable_scroll_id('cards')) or { panic('no scroll') }
	assert scroller.scroll_mode == .horizontal_only
	assert !scroller.persistent_scrollbars
	if _ := scrollable(frame: rect(0, 0, 10, 10)) {
		assert false, 'scrollable without id accepted'
	}
	if _ := scrollable(id: 'x', frame: rect(0, 0, 10, 10), gap: -1) {
		assert false, 'negative gap accepted'
	}
}

fn test_scrollbar_geometry_visibility_and_drag() {
	base := ScrollbarConfig{
		id:       'bar'
		frame:    rect(0, 0, 12, 200)
		offset:   0
		content:  1000
		viewport: 200
	}
	start, length := scrollbar_thumb(base)
	assert start == 0 && length == 40
	mid_start, _ := scrollbar_thumb(ScrollbarConfig{ ...base, offset: 400 })
	assert basics_close(mid_start, 80)
	end_start, _ := scrollbar_thumb(ScrollbarConfig{ ...base, offset: 800 })
	assert basics_close(end_start, 160)
	// The thumb never shrinks below min_thumb.
	_, least := scrollbar_thumb(ScrollbarConfig{ ...base, content: 100000 })
	assert least == 24
	// Visibility by mode.
	assert scrollbar_visible(base)
	assert !scrollbar_visible(ScrollbarConfig{ ...base, mode: .scrolling })
	assert scrollbar_visible(ScrollbarConfig{ ...base, mode: .scrolling, active: true })
	assert scrollbar_visible(ScrollbarConfig{ ...base, mode: .hover, hovered: true })
	assert !scrollbar_visible(ScrollbarConfig{ ...base, content: 150 })
	el := scrollbar(ScrollbarConfig{ ...base, offset: 400 })!
	thumb := basics_find(el, component_part_id('bar', 'thumb')) or { panic('no thumb') }
	assert thumb.draggable && !thumb.hidden
	assert basics_close(thumb.frame.y, 80) && thumb.frame.height == 40
	assert el.hoverable
	assert basics_find(el, component_part_id('bar', 'page:back')) != none
	assert basics_find(el, component_part_id('bar', 'page:forward')) != none
	hidden := scrollbar(ScrollbarConfig{ ...base, mode: .scrolling })!
	assert (basics_find(hidden, component_part_id('bar', 'thumb')) or { panic('') }).hidden
	horizontal := scrollbar(ScrollbarConfig{
		...base
		frame:       rect(0, 0, 200, 12)
		orientation: .horizontal
		offset:      800
	})!
	hthumb := basics_find(horizontal, component_part_id('bar', 'thumb')) or { panic('') }
	assert basics_close(hthumb.frame.x, 160) && hthumb.frame.width == 40
	// Dragging the thumb 80 points moves the content by 80 * 800 / 160.
	cfg := ScrollbarConfig{
		...base
		offset: 100
	}
	down := scrollbar_step(cfg, ScrollbarDrag{}, 'pointer:down:bar:component:thumb:5:50') or {
		panic('no down')
	}
	assert down.drag.active && down.drag.pointer == 50 && down.offset == 100
	moved := scrollbar_step(cfg, down.drag, 'pointer:drag:bar:component:thumb:5:130') or {
		panic('no drag')
	}
	assert basics_close(moved.offset, 500)
	beyond := scrollbar_step(cfg, down.drag, 'pointer:drag:bar:component:thumb:5:900') or {
		panic('no drag')
	}
	assert beyond.offset == 800
	up := scrollbar_step(cfg, down.drag, 'pointer:up:bar:component:thumb:5:130') or {
		panic('no up')
	}
	assert !up.drag.active
	// A drag without a press, and foreign events, decode to none.
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'pointer:drag:bar:component:thumb:5:130') == none
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'pointer:down:other:component:thumb:5:1') == none
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'bar:component:nothing') == none
	// Track clicks page; the bar reports hover.
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'bar:component:page:forward') or { panic('') }.offset == 280
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'bar:component:page:back') or { panic('') }.offset == 0
	assert scrollbar_step(cfg, ScrollbarDrag{}, 'pointer:enter:bar:component:bar:1:1') or {
		panic('')
	}.hovered
	assert !(scrollbar_step(ScrollbarConfig{ ...cfg, hovered: true }, ScrollbarDrag{}, 'pointer:leave:bar:component:bar:1:1') or {
		panic('')
	}.hovered)
	if _ := scrollbar(ScrollbarConfig{ ...base, id: '' }) {
		assert false, 'scrollbar without id accepted'
	}
	if _ := scrollbar(ScrollbarConfig{ ...base, offset: math.nan() }) {
		assert false, 'NaN offset accepted'
	}
}
