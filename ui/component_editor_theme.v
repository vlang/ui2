// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The light and dark syntax and editor colors are GPUI Kit's default highlight
// themes (crates/component/src/theme/default-theme.json): editor foreground,
// background, active line, line numbers and the syntax captures. The status
// colors fill in where the light theme leaves them out. Turning tokens into
// text runs, and the decoration styling, are new UI2 code. See
// third_party/gpui-kit.
module ui2

import math

// CodeEditorTheme is the code editor's palette: the editor surface, the gutter,
// the syntax colors, the search and diagnostic highlights, and `ui`, the
// component theme its search bar and completion popup are drawn with. Pass
// code_editor_theme(dark) or adjust one.
pub struct CodeEditorTheme {
pub:
	dark                   bool
	background             u32 = 0xffffff
	foreground             u32 = 0x000000
	border                 u32 = 0xe5e5e5
	gutter_background      u32 = 0xffffff
	line_number            u32 = 0x929292
	active_line_number     u32 = 0x000000
	active_line_background u32 = 0xf5f5f5
	caret                  u32 = 0x000000
	fold_marker            u32 = 0x929292
	indent_guide           u32 = 0xe3e3e3
	// Search matches, and the current one.
	match_background         u32 = 0xfff1b8
	current_match_background u32 = 0xffc94d
	// Diagnostics: the underline and gutter marker color, and the tint behind
	// the range.
	error              u32 = 0xc5060b
	error_background   u32 = 0xfde7e7
	warning            u32 = 0xc99401
	warning_background u32 = 0xfff4d1
	info               u32 = 0x1642ff
	info_background    u32 = 0xe5ecff
	hint               u32 = 0x9e5dff
	hint_background    u32 = 0xf1e8ff
	// Syntax.
	comment          u32 = 0x007fff
	keyword          u32 = 0x0433ff
	string           u32 = 0x036a07
	string_escape    u32 = 0x036a07
	number           u32 = 0x0433ff
	constant         u32 = 0xc5060b
	type             u32 = 0x6f42c1
	function         u32 = 0x0000a2
	property         u32 = 0x333333
	attribute        u32 = 0x957931
	operator         u32 = 0x000000
	punctuation      u32 = 0x000000
	variable_special u32 = 0xc5060b
	embedded         u32 = 0x333333
	title            u32 = 0x0433ff
	link_text        u32 = 0x0000a2
	link_uri         u32 = 0x6a7293
	code_span        u32 = 0x6f42c1
	tag              u32 = 0x0433ff
	// ui is the component theme of the search bar and the completion popup.
	ui ComponentTheme = ComponentTheme{
		background:       0xffffff
		foreground:       0x0a0a0a
		muted:            0xf5f5f5
		muted_foreground: 0x737373
		border:           0xe5e5e5
		primary:          0x2563eb
	}
}

// code_editor_theme returns GPUI Kit's default light or dark editor palette.
pub fn code_editor_theme(dark bool) CodeEditorTheme {
	if !dark {
		return CodeEditorTheme{}
	}
	return CodeEditorTheme{
		dark:                     true
		background:               0x0a0a0a
		foreground:               0xcaccca
		border:                   0x2e2e2e
		gutter_background:        0x0a0a0a
		line_number:              0x8f8f8f
		active_line_number:       0xdddddd
		active_line_background:   0x171717
		caret:                    0xe6e6e6
		fold_marker:              0x8f8f8f
		indent_guide:             0x262626
		match_background:         0x3a3412
		current_match_background: 0x7a6008
		error:                    0xe44a4f
		error_background:         0x46190c
		warning:                  0xd2a32c
		warning_background:       0x3a310e
		info:                     0x5b9cff
		info_background:          0x0b2a55
		hint:                     0xb283f8
		hint_background:          0x250c4b
		comment:                  0x9d9d9d
		keyword:                  0x87b1f6
		string:                   0xa3e09f
		string_escape:            0x68dc7c
		number:                   0xcc9e00
		constant:                 0xcc9e00
		type:                     0xcba6f7
		function:                 0xb3c5f3
		property:                 0xbcc4e0
		attribute:                0x7faef9
		operator:                 0xcaccca
		punctuation:              0xcaccca
		variable_special:         0x419cff
		embedded:                 0xcaccca
		title:                    0xcc9e00
		link_text:                0x419cff
		link_uri:                 0x7faef9
		code_span:                0xa3e09f
		tag:                      0x419cff
		ui:                       ComponentTheme{
			background:         0x171717
			foreground:         0xe5e5e5
			muted:              0x262626
			muted_foreground:   0xa3a3a3
			border:             0x333333
			primary:            0x60a5fa
			primary_foreground: 0x0a0a0a
			success:            0x86efac
			success_foreground: 0x0a0a0a
			warning:            0xfbbf24
			warning_foreground: 0x0a0a0a
			danger:             0xfca5a5
			danger_foreground:  0x0a0a0a
		}
	}
}

// token_style is the text style of a token kind over a base style (the font,
// size and default color of the editor).
pub fn (theme CodeEditorTheme) token_style(kind CodeTokenKind, base TextStyle) TextStyle {
	color := match kind {
		.plain { base.color }
		.comment, .comment_doc { theme.comment }
		.keyword { theme.keyword }
		.string { theme.string }
		.string_escape { theme.string_escape }
		.number { theme.number }
		.constant { theme.constant }
		.type { theme.type }
		.function { theme.function }
		.property { theme.property }
		.attribute { theme.attribute }
		.operator { theme.operator }
		.punctuation { theme.punctuation }
		.variable_special { theme.variable_special }
		.embedded { theme.embedded }
		.title { theme.title }
		.emphasis, .strong { base.color }
		.link_text { theme.link_text }
		.link_uri { theme.link_uri }
		.code_span { theme.code_span }
		.tag { theme.tag }
	}
	return TextStyle{
		...base
		color:  color
		bold:   base.bold || kind == .strong || (kind == .title && theme.dark)
		italic: base.italic || kind == .emphasis || kind == .link_uri
	}
}

// severity_colors returns a diagnostic severity's marker color and its
// background tint.
pub fn (theme CodeEditorTheme) severity_colors(severity CodeDiagnosticSeverity) (u32, u32) {
	return match severity {
		.error { theme.error, theme.error_background }
		.warning { theme.warning, theme.warning_background }
		.info { theme.info, theme.info_background }
		.hint { theme.hint, theme.hint_background }
	}
}

// code_blend mixes b into a by amount (0 keeps a, 1 gives b), per channel.
fn code_blend(a u32, b u32, amount f64) u32 {
	t := math.max(0.0, math.min(1.0, amount))
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		ca := f64((a >> shift) & 0xff)
		cb := f64((b >> shift) & 0xff)
		out |= u32(math.round(ca + (cb - ca) * t)) << shift
	}
	return out
}

// code_overlay_opacity is how much of `over` laid on `under` gives `target`,
// averaged over the channels: the opacity a translucent band in the foreground
// color needs to look like the active-line background.
fn code_overlay_opacity(under u32, over u32, target u32) f64 {
	mut total := 0.0
	mut count := 0
	for shift in [u32(16), 8, 0] {
		u := f64((under >> shift) & 0xff)
		o := f64((over >> shift) & 0xff)
		t := f64((target >> shift) & 0xff)
		if math.abs(o - u) > 8 {
			total += (t - u) / (o - u)
			count++
		}
	}
	return if count == 0 { 0.0 } else { math.max(0.0, math.min(1.0, total / count)) }
}

// ── Diagnostics and decorations ───────────────────────────────────────────

pub enum CodeDiagnosticSeverity {
	error
	warning
	info
	hint
}

// CodeDiagnostic marks a range of the text (rune offsets, end excluded) with a
// message, as a language server's diagnostics do. code_offset turns a line and
// column into an offset.
pub struct CodeDiagnostic {
pub:
	start    int
	end      int
	severity CodeDiagnosticSeverity
	message  string
	source   string // Who reported it, e.g. `vet`; shown before the message.
}

pub enum CodeDecorationStyle {
	frame // A one-point outline round the range.
	fill  // A background fill behind the range.
}

// CodeDecoration is a paint-only annotation of a range, after GPUI Kit's
// RangeDecoration: a frame or a fill. Without a color, frames use the editor
// foreground and fills that color at 12% opacity, so they follow the theme.
pub struct CodeDecoration {
pub:
	start int
	end   int
	style CodeDecorationStyle
	color ?u32
}

// CodeRange is a range of runes, end excluded.
pub struct CodeRange {
pub:
	start int
	end   int
}

pub fn (r CodeRange) is_empty() bool {
	return r.end <= r.start
}

// CodeRunOverlay restyles a range when the runs are built: a background, an
// underline (in the text's color: runs have no separate underline color), or
// both.
struct CodeRunOverlay {
	start      int
	end        int
	background u32
	has_bg     bool
	underline  bool
}

// CodeHighlightConfig is what code_highlight_runs needs to style a text.
pub struct CodeHighlightConfig {
pub:
	text        string
	language    CodeLanguage
	base        TextStyle
	theme       CodeEditorTheme
	highlight   bool = true // Color the syntax; off leaves only the overlays.
	matches     []CodeRange // Search matches, painted with match_background.
	current     int = -1 // The index in matches painted as the current one.
	diagnostics []CodeDiagnostic
	decorations []CodeDecoration
}

// code_highlight_runs turns a text into the text runs of a rich text area:
// syntax colors, search matches and the current match, diagnostic tints with
// an underline, and filled decorations. The runs cover the whole text in order,
// as text areas take them, and neighbours with the same style are merged.
// Highlights never cover a newline, which AppKit would paint as a sliver at the
// line end.
pub fn code_highlight_runs(config CodeHighlightConfig) []TextRun {
	runes := config.text.runes()
	if runes.len == 0 {
		return []TextRun{}
	}
	tokens := if config.highlight {
		code_tokens(config.text, config.language)
	} else {
		[]CodeToken{}
	}
	layers := code_run_overlays(config, runes.len)
	// Every place the style may change.
	mut cuts := []int{cap: tokens.len * 2 + 2}
	cuts << 0
	cuts << runes.len
	for t in tokens {
		cuts << t.start
		cuts << t.end
	}
	mut any_overlay := false
	for layer in layers {
		for o in layer {
			cuts << o.start
			cuts << o.end
			any_overlay = true
		}
	}
	if any_overlay {
		for index, r in runes {
			if r == `\n` {
				cuts << index
				cuts << index + 1
			}
		}
	}
	cuts.sort()
	mut unique := []int{cap: cuts.len}
	for cut in cuts {
		if unique.len == 0 || unique[unique.len - 1] != cut {
			unique << cut
		}
	}
	mut runs := []TextRun{}
	mut token_index := 0
	mut firsts := []int{len: layers.len}
	for k in 0 .. unique.len - 1 {
		cut := unique[k]
		stop := unique[k + 1]
		for token_index < tokens.len && tokens[token_index].end <= cut {
			token_index++
		}
		kind := if token_index < tokens.len && tokens[token_index].start <= cut {
			tokens[token_index].kind
		} else {
			CodeTokenKind.plain
		}
		mut style := config.theme.token_style(kind, config.base)
		if runes[cut] != `\n` {
			for layer_index, layer in layers {
				for firsts[layer_index] < layer.len && layer[firsts[layer_index]].end <= cut {
					firsts[layer_index]++
				}
				for o_index := firsts[layer_index]; o_index < layer.len
					&& layer[o_index].start <= cut; o_index++ {
					o := layer[o_index]
					if o.end < stop {
						continue
					}
					if o.has_bg {
						style = TextStyle{
							...style
							background_color: o.background
						}
					}
					if o.underline {
						style = TextStyle{
							...style
							underline: true
						}
					}
				}
			}
		}
		segment := runes[cut..stop].string()
		if runs.len > 0 && runs[runs.len - 1].style == style {
			runs[runs.len - 1] = TextRun{
				text:  runs[runs.len - 1].text + segment
				style: style
			}
		} else {
			runs << TextRun{
				text:  segment
				style: style
			}
		}
	}
	return runs
}

// code_run_overlays lists the restyled ranges in layers that apply in order:
// fills, then diagnostics, then search matches, so a match stays visible
// inside an error and the current match over the others. Each layer is sorted
// by start.
fn code_run_overlays(config CodeHighlightConfig, length int) [][]CodeRunOverlay {
	mut fills := []CodeRunOverlay{}
	for d in config.decorations {
		if d.style != .fill {
			continue
		}
		start, end := code_clamp_range(d.start, d.end, length)
		if end <= start {
			continue
		}
		color := d.color or { config.theme.foreground }
		fills << CodeRunOverlay{
			start:      start
			end:        end
			background: code_blend(config.theme.background, color, 0.12)
			has_bg:     true
		}
	}
	mut marks := []CodeRunOverlay{}
	for d in config.diagnostics {
		start, end := code_clamp_range(d.start, d.end, length)
		if end <= start {
			continue
		}
		_, tint := config.theme.severity_colors(d.severity)
		marks << CodeRunOverlay{
			start:      start
			end:        end
			background: tint
			has_bg:     true
			underline:  true
		}
	}
	mut found := []CodeRunOverlay{}
	for index, m in config.matches {
		start, end := code_clamp_range(m.start, m.end, length)
		if end <= start {
			continue
		}
		found << CodeRunOverlay{
			start:      start
			end:        end
			background: if index == config.current {
				config.theme.current_match_background
			} else {
				config.theme.match_background
			}
			has_bg:     true
		}
	}
	fills.sort(a.start < b.start)
	marks.sort(a.start < b.start)
	found.sort(a.start < b.start)
	return [fills, marks, found]
}

fn code_clamp_range(start int, end int, length int) (int, int) {
	s := clamp_int(start, 0, length)
	e := clamp_int(end, s, length)
	return s, e
}
