module main

import math
import ui2

// A git-history view built on the Diff component. The commit below is real
// `git format-patch` output, parsed with parse_diff: a modified file with an
// annotation, a rename, a file whose merge still has conflicts (accept either
// side or both in place), a binary file, a mode change and a deleted file. A
// 3,000-line generated file is diffed at start-up and appended as a patch with
// its whole text as context, so its unchanged lines fold away and can be
// revealed, and only the rows on screen are built while it scrolls.
//
// Click a line number (or a line's code) to select it and Shift-click another
// to extend the range; copy it as source, the old or the new version, or
// patch text. Keys: F7 / Shift+F7 next and previous change, Alt+Down / Alt+Up
// next and previous hunk, Shift+Up / Shift+Down extend the selection,
// Cmd+C (Ctrl+C) copy, Cmd+A (Ctrl+A) select the file, arrows and Page Up /
// Page Down scroll, Escape clears the selection.

const commit_patch = r'From 6a9a392750b6485ba3e3031830a81c17ec62c3d7 Mon Sep 17 00:00:00 2001
From: Ada Lovelace <ada@example.com>
Date: Fri, 16 Oct 2026 09:21:44 +0200
Subject: [PATCH] Retry requests that time out and move the string helpers

Requests that fail are now retried up to three times, waiting twice
as long after each attempt. The string helpers move from util to the
text module and count runes rather than bytes.

The merge of feature/env-config still has two conflicts in the config
loader; resolve them before tagging 1.5.0.
---
 CHANGELOG.md                 |   8 +++++++-
 assets/icon.png              | Bin 17 -> 34 bytes
 docs/legacy-api.md           |   4 ----
 scripts/release.sh           |   0
 src/config/loader.v          |  13 +++++++++++++
 src/net/client.v             |  27 ++++++++++++++++++++++-----
 src/{util => text}/strings.v |   7 ++++---
 7 files changed, 46 insertions(+), 13 deletions(-)
 delete mode 100644 docs/legacy-api.md
 mode change 100644 => 100755 scripts/release.sh
 rename src/{util => text}/strings.v (81%)

diff --git a/src/net/client.v b/src/net/client.v
index 7bd142c..ee59e3e 100644
--- a/src/net/client.v
+++ b/src/net/client.v
@@ -3,11 +3,13 @@ module net
 import net.http
 import time
 import json
+import math
 
-// Client sends requests to one service.
+// Client sends requests to one service, retrying the ones that time out.
 pub struct Client {
 	base_url string
-	timeout  int = 30
+	timeout  time.Duration = 30 * time.second
+	retries  int = 3
 }
 
 pub fn new_client(base_url string) Client {
@@ -25,8 +27,18 @@ pub struct Response {
 // get fetches a path and decodes the response.
 pub fn (c Client) get(path string) !Response {
 	url := c.base_url + path
-	resp := http.get(url) or { return error("request failed: ${err}") }
-	return parse_response(resp)
+	mut attempt := 0
+	for {
+		resp := http.get(url) or {
+			attempt++
+			if attempt > c.retries {
+				return error("request failed after ${attempt} attempts: ${err}")
+			}
+			time.sleep(backoff(attempt))
+			continue
+		}
+		return parse_response(resp)
+	}
 }
 
 // post sends a JSON body to a path.
@@ -36,9 +48,14 @@ pub fn (c Client) post(path string, body string) !Response {
 	return parse_response(resp)
 }
 
+// backoff doubles the wait after each failed attempt, up to eight seconds.
+fn backoff(attempt int) time.Duration {
+	return time.Duration(math.min(8000, 250 * math.pow(2, attempt - 1))) * time.millisecond
+}
+
 fn parse_response(resp http.Response) !Response {
 	if resp.status_code != 200 {
-		return error("unexpected status ${resp.status_code}")
+		return error("unexpected status ${resp.status_code} from ${resp.url}")
 	}
 	return json.decode(Response, resp.body)!
 }
diff --git a/src/util/strings.v b/src/text/strings.v
similarity index 81%
rename from src/util/strings.v
rename to src/text/strings.v
index c05f3a5..7f9b576 100644
--- a/src/util/strings.v
+++ b/src/text/strings.v
@@ -1,11 +1,12 @@
-module util
+module text
 
 // truncate shortens s to at most max characters, ending with an ellipsis.
 pub fn truncate(s string, max int) string {
-	if s.len <= max {
+	runes := s.runes()
+	if runes.len <= max {
 		return s
 	}
-	return s[..max - 1] + "…"
+	return runes[..max - 1].string() + "…"
 }
 
 // slug lowercases s and joins its words with dashes.
diff --git a/src/config/loader.v b/src/config/loader.v
index 1df82a4..c409c7b 100644
--- a/src/config/loader.v
+++ b/src/config/loader.v
@@ -1,6 +1,11 @@
 module config
 
+<<<<<<< HEAD
 import os
+=======
+import os
+import runtime
+>>>>>>> feature/env-config
 
 // Config holds the settings the service starts with.
 pub struct Config {
@@ -14,7 +19,15 @@ pub:
 pub fn load() Config {
 	return Config{
 		port:    os.getenv_opt("PORT") or { "8080" }.int()
+<<<<<<< HEAD
+		log_dir: os.getenv_opt("LOG_DIR") or { os.join_path(os.home_dir(), ".app", "logs") }
+		workers: 4
+||||||| merged common ancestors
 		log_dir: os.getenv_opt("LOG_DIR") or { "/var/log/app" }
 		workers: 4
+=======
+		log_dir: os.getenv_opt("LOG_DIR") or { "/var/log/app" }
+		workers: os.getenv_opt("WORKERS") or { "${runtime.nr_cpus()}" }.int()
+>>>>>>> feature/env-config
 	}
 }
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 6c964ff..6dbb576 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -1,6 +1,12 @@
 # Changelog
 
+## 1.5.0
+
+- Retry requests that time out, with exponential backoff.
+- Move the string helpers to the text module.
+
 ## 1.4.0
 
 - Add a request timeout.
-- Fix the log directory on Windows.
\ No newline at end of file
+- Fix the log directory on Windows.
+- Document the WORKERS setting.
\ No newline at end of file
diff --git a/assets/icon.png b/assets/icon.png
index 34336875661e65ca7c5d76db6dd4e124a9804160..80ba1de6c4d5b371b7ba887efa7943538023fd6e 100644
GIT binary patch
literal 34
pcmWIWb7x>=V$Mq~*Ue1M&(kf>EXmN#%`ZyTO{y$OEoS)l9{{f~3?={o

literal 17
YcmWIWb7x>=V$RP=(alWG&tv!x03(+L00000

diff --git a/docs/legacy-api.md b/docs/legacy-api.md
deleted file mode 100644
index a73c146..0000000
--- a/docs/legacy-api.md
+++ /dev/null
@@ -1,4 +0,0 @@
-# Legacy API
-
-The v1 endpoints answer with XML. They are kept for old clients
-and will be removed in 2.0; use the JSON endpoints instead.
diff --git a/scripts/release.sh b/scripts/release.sh
old mode 100644
new mode 100755
-- 
2.50.1 (Apple Git-155)

'

const diff_id = 'commit-diff'
const default_width = 1280.0
const default_height = 820.0
const top_height = 64.0
const sidebar_width = 296.0
const status_height = 30.0
const gap = 12.0

@[heap]
struct App {
mut:
	dark        bool
	header      ui2.DiffPatchHeader
	diff        ui2.DiffState
	parse_error string
	notice      string
	notice_id   ui2.TimerId
}

const app = &App{}

// The generated file: a table of code point ranges, of which the new version
// changes a few scattered entries, inserts some and drops some.
fn generated_versions() (string, string) {
	widths := [0, 2, 2, 1, 0]
	mut old := ['module gen', '',
		'// Code generated by tools/gen_width.v from Unicode 15.1. DO NOT EDIT.', '',
		'// WidthRange is a run of code points that do not take one cell.', 'pub struct WidthRange {',
		'\tstart u32', '\tend   u32', '\twidth int', '}', '', 'pub const width_ranges = [']
	mut new := old.clone()
	new[2] = '// Code generated by tools/gen_width.v from Unicode 16.0. DO NOT EDIT.'
	for i in 0 .. 3000 {
		start := 0x0300 + i * 7
		entry := '\tWidthRange{ start: 0x${start:05x}, end: 0x${start + 3:05x}, width: ${widths[i % widths.len]} },'
		old << entry
		if i % 263 == 131 {
			new << '\tWidthRange{ start: 0x${start:05x}, end: 0x${start + 4:05x}, width: ${widths[(i + 1) % widths.len]} },'
		} else if i >= 2410 && i < 2413 {
			continue
		} else {
			new << entry
		}
		if i == 1700 {
			for k in 0 .. 4 {
				new << '\tWidthRange{ start: 0x${0x1f900 + k * 16:05x}, end: 0x${0x1f90f + k * 16:05x}, width: 2 }, // Unicode 16.0'
			}
		}
	}
	old << ']'
	new << ']'
	return old.join('\n') + '\n', new.join('\n') + '\n'
}

fn init_app() {
	mut state := unsafe { app }
	old_text, new_text := generated_versions()
	generated := ui2.diff_texts('src/gen/width_table.v', 'src/gen/width_table.v', old_text,
		new_text)
	// The whole file goes in as context, as `git show -U100000` would write it.
	patch := commit_patch.replace('\n-- \n', '\n' + ui2.diff_unified_text(generated, -1) + '-- \n')
	state.header = ui2.parse_diff_header(patch)
	files := ui2.parse_diff(patch) or {
		state.parse_error = err.msg()
		[]ui2.DiffFile{}
	}
	state.diff = ui2.diff_state(files)
	state.diff.set_annotations([
		ui2.DiffAnnotation{
			id:    'review-1'
			path:  'src/net/client.v'
			side:  .modified
			line:  12
			title: 'Grace Hopper · review'
			text:  'Three retries with doubling waits can hold a request for almost two seconds. Should the retry count come from the config loader instead of being fixed here?'
			tone:  .primary
		},
		ui2.DiffAnnotation{
			id:    'note-generated'
			path:  'src/gen/width_table.v'
			line:  0
			title: 'Generated file'
			text:  'Regenerate it with tools/gen_width.v instead of editing it by hand.'
			tone:  .warning
		},
	])
}

fn window_size() (f64, f64) {
	b := ui2.bounds()
	w := if b.width > 0 { b.width } else { default_width }
	h := if b.height > 0 { b.height } else { default_height }
	return math.max(w, 900.0), math.max(h, 560.0)
}

fn diff_frame() ui2.Rect {
	w, h := window_size()
	return ui2.rect(sidebar_width + gap, top_height, w - sidebar_width - 2 * gap, h - top_height -
		status_height - gap)
}

fn diff_config(state &App) ui2.DiffViewConfig {
	return ui2.DiffViewConfig{
		id:       diff_id
		frame:    diff_frame()
		state:    state.diff
		scroll_y: ui2.scroll_offset(ui2.diff_body_id(diff_id))
		theme:    ui2.component_theme(state.dark)
	}
}

fn mode_config(state &App) ui2.ButtonGroupConfig {
	w, _ := window_size()
	return ui2.ButtonGroupConfig{
		id:      'mode'
		frame:   ui2.rect(w - 640, 16, 156, 32)
		items:   [
			ui2.ButtonGroupItem{
				value:    'unified'
				label:    'Unified'
				selected: state.diff.mode() == .unified
			},
			ui2.ButtonGroupItem{
				value:    'split'
				label:    'Split'
				selected: state.diff.mode() == .split
			},
		]
		outline: true
		theme:   ui2.component_theme(state.dark)
	}
}

fn copy_config(state &App) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:      'copy'
		frame:   ui2.rect(gap, 0, sidebar_width - gap, 28)
		items:   [
			ui2.ButtonGroupItem{
				value: 'source'
				label: 'Lines'
				icon:  'doc.on.doc'
			},
			ui2.ButtonGroupItem{
				value: 'original'
				label: 'Old'
			},
			ui2.ButtonGroupItem{
				value: 'modified'
				label: 'New'
			},
			ui2.ButtonGroupItem{
				value: 'patch'
				label: 'Patch'
			},
		]
		fill:    true
		enabled: has_selection(state)
		size:    .small
		theme:   ui2.component_theme(state.dark)
	}
}

fn has_selection(state &App) bool {
	if _ := state.diff.selected_lines() {
		return true
	}
	return false
}

fn tool_button(id string, caption string, icon string, x f64, width f64, selected bool, enabled bool, state &App) ui2.Element {
	return ui2.styled_button(
		id:                  id
		frame:               ui2.rect(x, 16, width, 32)
		label:               caption
		icon:                icon
		outline:             true
		selected:            selected
		enabled:             enabled
		accessibility_label: if caption.len > 0 { caption } else { id }
		theme:               ui2.component_theme(state.dark)
	) or { panic(err) }
}

fn status_letter(file ui2.DiffFile, theme ui2.ComponentTheme) (string, u32) {
	if file.conflicts.len > 0 {
		return 'U', theme.warning
	}
	letter := match file.status {
		.added { 'A' }
		.deleted { 'D' }
		.renamed { 'R' }
		.copied { 'C' }
		else { 'M' }
	}
	color := match file.status {
		.added { theme.success }
		.deleted { theme.danger }
		.renamed, .copied { theme.primary }
		else { theme.muted_foreground }
	}
	return letter, color
}

fn file_list(state &App, y0 f64, height f64) []ui2.Element {
	theme := ui2.component_theme(state.dark)
	files := state.diff.files()
	row_h := 30.0
	mut out := []ui2.Element{}
	out << ui2.label('', 'Files changed (${files.len})', ui2.rect(gap, y0, sidebar_width - gap,
		22), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		bold:  true
	})
	for i, file in files {
		y := y0 + 26 + f64(i) * row_h
		if y + row_h > y0 + height {
			break
		}
		letter, color := status_letter(file, theme)
		path := file.path()
		slash := path.last_index('/') or { -1 }
		name := path[slash + 1..]
		dir := if slash > 0 { path[..slash] } else { '' }
		counts := if file.binary { 'bin' } else { '+${file.additions} −${file.deletions}' }
		count_style := ui2.TextStyle{
			color: theme.muted_foreground
			size:  11
			align: .right
		}
		cw := ui2.measure_text_width(counts, count_style)
		name_style := ui2.TextStyle{
			color: theme.foreground
			size:  13
		}
		nw := math.min(ui2.measure_text_width(name, name_style), sidebar_width - gap - 40 - cw - 8)
		mut children := [
			ui2.view('', ui2.rect(6, (row_h - 18) / 2, 18, 18), ui2.BoxStyle{
				bg:     mix(theme.background, color, 0.18)
				radius: 4
			}, [
				ui2.label('', letter, ui2.rect(0, 0, 18, 18), ui2.TextStyle{
					color: color
					size:  11
					bold:  true
					align: .center
				}),
			]),
			ui2.label('', name, ui2.rect(30, 0, nw, row_h), name_style),
			ui2.label('', dir, ui2.rect(30 + nw + 6, 0, math.max(0.0, sidebar_width - gap - 30 -
				nw - 6 - cw - 10), row_h), ui2.TextStyle{
				color: theme.muted_foreground
				size:  11
			}),
			ui2.label('', counts, ui2.rect(sidebar_width - gap - cw - 8, 0, cw, row_h), count_style),
		]
		out << ui2.with_action(ui2.button_view('file-${i}', ui2.rect(gap - 6, y, sidebar_width - gap +
			6, row_h), ui2.BoxStyle{
			bg:     theme.background
			radius: 6
		}, children), 'goto:${i}')
	}
	return out
}

fn sidebar(state &App, height f64) []ui2.Element {
	theme := ui2.component_theme(state.dark)
	header := state.header
	mut out := []ui2.Element{}
	files_h := 26 + 30.0 * f64(state.diff.files().len) + 8
	out << file_list(state, top_height, files_h)
	mut y := top_height + files_h + 8
	out << ui2.view('', ui2.rect(gap, y, sidebar_width - gap, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	y += 12
	out << ui2.label('', 'Commit message', ui2.rect(gap, y, sidebar_width - gap, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		bold:  true
	})
	y += 24
	body_style := ui2.TextStyle{
		color: theme.foreground
		size:  12
	}
	for paragraph in header.message.split('\n\n') {
		for line in ui2.wrap_text_to_width(paragraph.replace('\n', ' '), body_style, sidebar_width - gap) {
			if y + 18 > height - 120 {
				break
			}
			out << ui2.label('', line, ui2.rect(gap, y, sidebar_width - gap, 18), body_style)
			y += 18
		}
		y += 8
	}
	// The selection, and copying it.
	y = math.max(y + 4, height - 112)
	out << ui2.view('', ui2.rect(gap, y, sidebar_width - gap, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	y += 12
	out << ui2.label('', 'Selection', ui2.rect(gap, y, sidebar_width - gap, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		bold:  true
	})
	y += 22
	selection := if range := state.diff.selected_lines() {
		side := if range.crosses {
			'across both versions'
		} else if range.side == .original {
			'old version'
		} else {
			'new version'
		}
		count := if range.crosses {
			'lines ${range.start}–${range.end}'
		} else if range.start == range.end {
			'line ${range.start}'
		} else {
			'lines ${range.start}–${range.end}'
		}
		'${range.path.all_after_last('/')}: ${count}, ${side}'
	} else {
		'Click a line number; Shift-click to extend.'
	}
	out << ui2.label('', selection, ui2.rect(gap, y, sidebar_width - gap, 20), ui2.TextStyle{
		color: theme.foreground
		size:  12
	})
	y += 28
	out << ui2.label('', 'Copy as', ui2.rect(gap, y, 60, 28), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
	copy_group := copy_config(state)
	out << ui2.button_group(ui2.ButtonGroupConfig{
		...copy_group
		frame: ui2.rect(gap + 60, y, sidebar_width - gap - 60, 28)
	}) or { panic(err) }
	return out
}

fn short_date(date string) string {
	// `Fri, 16 Oct 2026 09:21:44 +0200` reads as `16 Oct 2026 09:21`.
	parts := date.split(' ')
	if parts.len >= 5 {
		return '${parts[1]} ${parts[2]} ${parts[3]} ${parts[4][..5]}'
	}
	return date
}

fn build() ui2.Element {
	state := unsafe { app }
	theme := ui2.component_theme(state.dark)
	w, h := window_size()
	config := diff_config(state)
	mut children := []ui2.Element{}
	// The commit.
	children << ui2.view('', ui2.rect(gap, 14, 36, 36), ui2.BoxStyle{
		bg:     mix(theme.background, theme.primary, 0.14)
		radius: 18
	}, [
		ui2.Element{
			...ui2.image('', 'symbol:arrow.triangle.2.circlepath', ui2.rect(9, 9, 18, 18))
			text_style: ui2.TextStyle{
				color: theme.primary
			}
		},
	])
	subject := if state.header.subject.len > 0 { state.header.subject } else { 'Commit' }
	children << ui2.label('', subject, ui2.rect(gap + 46, 12, w - 700, 22), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
	meta := '${state.header.author.all_before(' <')} committed ${short_date(state.header.date)} · ${state.header.commit[..math.min(8, state.header.commit.len)]}'
	children << ui2.label('', meta, ui2.rect(gap + 46, 34, w - 700, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
	// The toolbar.
	children << ui2.button_group(mode_config(state)) or { panic(err) }
	mut x := w - 476
	children << ui2.label('', 'Context', ui2.rect(x, 16, 54, 32), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		align: .right
	})
	x += 60
	context := state.diff.context_lines()
	children << tool_button('context-less', '', 'minus', x, 32, false, context > 0, state)
	children << ui2.label('', if context < 0 { 'all' } else { context.str() }, ui2.rect(x + 32,
		16, 30, 32), ui2.TextStyle{
		color: theme.foreground
		size:  13
		bold:  true
		align: .center
	})
	children << tool_button('context-more', '', 'plus', x + 62, 32, false, context >= 0 && context < 25,
		state)
	x += 104
	children << tool_button('expand', 'Expand', 'arrow.up.and.down', x, 92, state.diff.unchanged_expanded(),
		true, state)
	x += 104
	children << tool_button('prev', '', 'chevron.up', x, 32, false, true, state)
	children << tool_button('next', '', 'chevron.down', x + 34, 32, false, true, state)
	x += 80
	children << tool_button('theme', '', if state.dark { 'sun.max' } else { 'moon' }, x, 32,
		false, true, state)
	children << ui2.view('', ui2.rect(0, top_height - 6, w, 1), ui2.BoxStyle{
		bg: theme.border
	}, []ui2.Element{})
	children << sidebar(state, h - status_height)
	if state.parse_error.len > 0 {
		children << ui2.label('', 'Could not read the patch: ${state.parse_error}', config.frame,
			ui2.TextStyle{
				color: theme.danger
				size:  13
				align: .center
			})
	} else {
		children << ui2.diff_view(config) or { panic(err) }
	}
	// The status bar.
	layout := ui2.diff_view_layout(config)
	rows := state.diff.rows().len
	open := state.diff.unresolved_conflicts()
	conflicts := if open == 0 {
		'conflicts resolved'
	} else if open == 1 {
		'1 conflict to resolve'
	} else {
		'${open} conflicts to resolve'
	}
	status := if state.notice.len > 0 {
		state.notice
	} else {
		'Rows ${layout.range.start + 1}–${layout.range.end} of ${rows} built · ${conflicts} · F7 next change · Alt+↓ next hunk · Cmd+C copy'
	}
	children << ui2.view('', ui2.rect(0, h - status_height, w, status_height), ui2.BoxStyle{
		bg:           theme.muted
		border_color: theme.border
		border_top:   1
	}, [
		ui2.label('', status, ui2.rect(gap, 0, w - 2 * gap, status_height), ui2.TextStyle{
			color: theme.muted_foreground
			size:  12
		}),
	])
	return ui2.screen(theme.background, children)
}

fn mix(a u32, b u32, t f64) u32 {
	mut out := u32(0)
	for shift in [u32(16), 8, 0] {
		from := f64((a >> shift) & 0xff)
		to := f64((b >> shift) & 0xff)
		out |= u32(math.round(from + (to - from) * t)) << shift
	}
	return out
}

fn notify(text string) {
	mut state := unsafe { app }
	state.notice = text
	ui2.cancel_timer(state.notice_id)
	state.notice_id = ui2.after(2.5, fn () {
		mut s := unsafe { app }
		s.notice = ''
	})
}

fn copy_selection(format ui2.DiffCopyFormat) {
	state := unsafe { app }
	copied := state.diff.selected_text(format)
	if copied.len == 0 {
		notify('Select some lines first.')
		return
	}
	lines := copied.count('\n')
	what := match format {
		.source { 'the selected lines' }
		.original { 'the old version' }
		.modified { 'the new version' }
		.patch { 'patch text' }
	}
	if ui2.diff_copy_selection(state.diff, format) {
		notify('Copied ${what} (${lines} ${if lines == 1 { 'line' } else { 'lines' }}).')
	} else {
		notify('This platform has no clipboard to copy to.')
	}
}

// keep_position runs a change that rebuilds the rows (a mode, the context) and
// scrolls back to the source line that was at the top.
fn keep_position(change fn (mut s ui2.DiffState)) {
	mut state := unsafe { app }
	before := ui2.diff_top_position(diff_config(state))
	change(mut state.diff)
	if pos := before {
		if row := state.diff.row_for_line(pos) {
			ui2.scroll_to_offset(ui2.diff_body_id(diff_id), ui2.diff_scroll_offset_for_row(diff_config(state),
				row, .start))
		}
	}
}

fn handle_diff_event(e ui2.DiffEvent, from_key bool) {
	mut state := unsafe { app }
	body := ui2.diff_body_id(diff_id)
	match e.kind {
		.copy {
			copy_selection(e.format)
		}
		.scroll {
			ui2.scroll_to_offset(body, e.offset)
		}
		.navigate {
			state.diff.apply(e)
			ui2.scroll_to_offset(body, e.offset)
		}
		.select {
			state.diff.apply(e)
			if from_key && e.row >= 0 {
				ui2.scroll_to_offset(body, e.offset)
			}
		}
		.conflict_resolved {
			state.diff.apply(e)
			open := state.diff.unresolved_conflicts()
			notify(if open == 0 {
				'Every conflict is resolved; the merged file is ready to save.'
			} else if e.undo {
				'Conflict reopened.'
			} else {
				'Conflict resolved. ${open} left.'
			})
		}
		else {
			state.diff.apply(e)
		}
	}
}

fn on_event(event string) {
	mut state := unsafe { app }
	config := diff_config(state)
	match event {
		'theme' {
			state.dark = !state.dark
		}
		'context-less' {
			keep_position(fn (mut s ui2.DiffState) {
				s.set_context_lines(s.context_lines() - 1)
			})
		}
		'context-more' {
			keep_position(fn (mut s ui2.DiffState) {
				s.set_context_lines(s.context_lines() + 1)
			})
		}
		'expand' {
			keep_position(fn (mut s ui2.DiffState) {
				if s.unchanged_expanded() {
					s.collapse_unchanged()
				} else {
					s.expand_unchanged()
				}
			})
		}
		'prev', 'next' {
			if e := ui2.diff_navigate(config, event == 'next', false) {
				handle_diff_event(e, false)
			}
		}
		else {
			if event.starts_with('goto:') {
				index := event['goto:'.len..].int()
				files := state.diff.files()
				if index >= 0 && index < files.len {
					state.diff.set_file_collapsed(files[index].path(), false)
					if row := state.diff.file_row(files[index].path()) {
						ui2.scroll_to_offset(ui2.diff_body_id(diff_id), ui2.diff_scroll_offset_for_row(diff_config(state),
							row, .start))
					}
				}
			} else if mode := ui2.button_group_value_from_action(mode_config(state), event) {
				keep_position(fn [mode] (mut s ui2.DiffState) {
					s.set_mode(if mode == 'split' {
						ui2.DiffMode.split
					} else {
						ui2.DiffMode.unified
					})
				})
			} else if format := ui2.button_group_value_from_action(copy_config(state), event) {
				copy_selection(match format {
					'original' { ui2.DiffCopyFormat.original }
					'modified' { ui2.DiffCopyFormat.modified }
					'patch' { ui2.DiffCopyFormat.patch }
					else { ui2.DiffCopyFormat.source }
				})
			} else if e := ui2.diff_event_from_action(config, event) {
				handle_diff_event(e, false)
			} else {
				return
			}
		}
	}
	ui2.refresh()
}

fn on_key_event(event ui2.KeyEvent) {
	state := unsafe { app }
	e := ui2.diff_event_from_key(diff_config(state), event) or { return }
	ui2.consume_key()
	handle_diff_event(e, true)
	ui2.refresh()
}

fn on_scroll(id string) {
	// The rows built follow the body's offset, so a vertical scroll rebuilds. A
	// scroll can be reported while a build is going on screen, so ask for the
	// rebuild rather than running it here. (The custom renderer rebuilds every
	// frame.) The code columns scroll sideways on their own.
	if id == ui2.diff_body_id(diff_id) {
		ui2.request_refresh()
	}
}

fn main() {
	init_app()
	ui2.on_key_event(on_key_event)
	ui2.on_scroll(on_scroll)
	ui2.run_window('UI2 Diff', int(default_width), int(default_height), build, on_event)
}
