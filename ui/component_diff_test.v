module ui2

import rand
import time

// ── Fixtures ────────────────────────────────────────────────────────

// diff_test_patch is real `git format-patch -M` output: a modified file, a
// rename, a merge with diff3 conflict markers, a file without a final newline,
// a binary file, a deleted file and a mode change.
const diff_test_patch = r'From 6a9a392750b6485ba3e3031830a81c17ec62c3d7 Mon Sep 17 00:00:00 2001
From: Ada Lovelace <ada@example.com>
Date: Fri, 16 Oct 2026 09:21:44 +0200
Subject: [PATCH] Retry requests that time out and move the string helpers

Requests that fail are now retried up to three times.

The merge still has two conflicts.
---
 CHANGELOG.md                 |   8 +++++++-
 src/{util => text}/strings.v |   7 ++++---
 2 files changed, 10 insertions(+), 4 deletions(-)

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
@@ -36,9 +38,9 @@ pub fn (c Client) post(path string, body string) !Response {
 	return parse_response(resp)
 }

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
@@ -1,4 +1,5 @@
-module util
+module text

 // truncate shortens s to at most max characters, ending with an ellipsis.
 pub fn truncate(s string, max int) string {
+	runes := s.runes()
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
@@ -1,6 +1,9 @@
 # Changelog

+## 1.5.0
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
@@ -1,2 +0,0 @@
-# Legacy API
-The v1 endpoints answer with XML.
diff --git a/scripts/release.sh b/scripts/release.sh
old mode 100644
new mode 100755
--
2.50.1 (Apple Git-155)
'

fn diff_test_files() []DiffFile {
	return parse_diff(diff_test_patch) or { panic(err) }
}

// diff_test_numbered is `count` lines `line 1` ... `line count`, with a newline.
fn diff_test_numbered(count int) []string {
	mut out := []string{cap: count}
	for i in 1 .. count + 1 {
		out << 'line ${i}'
	}
	return out
}

fn diff_test_text(lines []string) string {
	return lines.join('\n') + '\n'
}

// diff_test_complete is a 40-line file with line 10 changed and line 30
// removed: two changes far apart in one complete hunk.
fn diff_test_complete() DiffFile {
	old := diff_test_numbered(40)
	mut new := old.clone()
	new[9] = 'line 10 changed'
	new.delete(29)
	return diff_texts('a.txt', 'a.txt', diff_test_text(old), diff_test_text(new))
}

fn diff_test_rows_of(s DiffState, kind DiffRowKind) []int {
	mut out := []int{}
	for i, row in s.rows() {
		if row.kind == kind {
			out << i
		}
	}
	return out
}

fn diff_test_config(s DiffState) DiffViewConfig {
	return DiffViewConfig{
		id:    'review'
		frame: rect(0, 0, 900, 600)
		state: s
	}
}

fn diff_test_find(el Element, pred fn (Element) bool) []Element {
	mut out := []Element{}
	if pred(el) {
		out << el
	}
	for child in el.children {
		out << diff_test_find(child, pred)
	}
	return out
}

fn lcs_len(a []string, b []string) int {
	mut dp := [][]int{len: a.len + 1, init: []int{len: b.len + 1}}
	for i := a.len - 1; i >= 0; i-- {
		for j := b.len - 1; j >= 0; j-- {
			dp[i][j] = if a[i] == b[j] {
				dp[i + 1][j + 1] + 1
			} else if dp[i + 1][j] > dp[i][j + 1] {
				dp[i + 1][j]
			} else {
				dp[i][j + 1]
			}
		}
	}
	return dp[0][0]
}

// check_script asserts edits turn a into b and returns how many lines it keeps.
fn check_script(a []string, b []string, edits []DiffEdit) int {
	mut i := 0
	mut j := 0
	mut kept := 0
	for e in edits {
		match e.kind {
			.context {
				assert e.old_index == i && e.new_index == j
				assert a[i] == b[j]
				i++
				j++
				kept++
			}
			.removed {
				assert e.old_index == i
				i++
			}
			.added {
				assert e.new_index == j
				j++
			}
		}
	}
	assert i == a.len && j == b.len
	return kept
}

// ── The algorithm ───────────────────────────────────────────────────

fn test_diff_edits_are_shortest_on_random_inputs() {
	rand.seed([u32(7), 11])
	for round in 0 .. 1500 {
		alphabet := 1 + rand.intn(6) or { 0 }
		mut a := []string{}
		mut b := []string{}
		for _ in 0 .. rand.intn(14) or { 0 } {
			a << 'l${rand.intn(alphabet) or { 0 }}'
		}
		for _ in 0 .. rand.intn(14) or { 0 } {
			b << 'l${rand.intn(alphabet) or { 0 }}'
		}
		kept := check_script(a, b, diff_edits(a, b))
		assert kept == lcs_len(a, b), 'round ${round}: ${a} -> ${b}'
	}
	// Edited copies, closer to real files.
	for round in 0 .. 150 {
		alphabet := 2 + rand.intn(20) or { 0 }
		mut a := []string{}
		for _ in 0 .. rand.intn(120) or { 0 } {
			a << 'l${rand.intn(alphabet) or { 0 }}'
		}
		mut b := a.clone()
		for _ in 0 .. rand.intn(30) or { 0 } {
			op := rand.intn(3) or { 0 }
			if op == 0 && b.len > 0 {
				b.delete(rand.intn(b.len) or { 0 })
			} else if op == 1 {
				b.insert(rand.intn(b.len + 1) or { 0 }, 'x${rand.intn(alphabet) or { 0 }}')
			} else if b.len > 0 {
				b[rand.intn(b.len) or { 0 }] = 'l${rand.intn(alphabet) or { 0 }}'
			}
		}
		kept := check_script(a, b, diff_edits(a, b))
		assert kept == lcs_len(a, b), 'edited round ${round}'
	}
}

fn test_diff_edits_put_removals_before_additions_and_handle_empty_sides() {
	edits := diff_edits(['a', 'b', 'c'], ['a', 'x', 'y', 'c'])
	assert edits.map(it.kind) == [DiffLineKind.context, .removed, .added, .added, .context]
	assert diff_edits([]string{}, ['a']).map(it.kind) == [DiffLineKind.added]
	assert diff_edits(['a'], []string{}).map(it.kind) == [DiffLineKind.removed]
	assert diff_edits([]string{}, []string{}).len == 0
}

fn test_diff_edits_slide_changes_to_end_on_a_blank_line() {
	old := ['fn a() {', '}', '', 'fn c() {', '}']
	new := ['fn a() {', '}', '', 'fn b() {', '}', '', 'fn c() {', '}']
	added := diff_edits(old, new).filter(it.kind == .added).map(it.new_index)
	// The inserted function and the blank line after it, not `}`, ``, `fn b() {`.
	assert added == [3, 4, 5]
}

fn test_diff_edits_stay_fast_on_large_inputs() {
	mut a := []string{}
	for i in 0 .. 100000 {
		a << 'entry ${i % 977} ${i % 13}'
	}
	mut b := a.clone()
	for k in 0 .. 1000 {
		b[(k * 97) % b.len] = 'changed ${k}'
	}
	mut sw := time.new_stopwatch()
	scattered := diff_edits(a, b)
	assert check_script(a, b, scattered) == a.len - 1000
	assert sw.elapsed().milliseconds() < 3000
	// Every line shuffled: the cost limit splits instead of searching on.
	mut c := a[..20000].clone()
	rand.seed([u32(1), 2])
	rand.shuffle(mut c) or {}
	sw.restart()
	check_script(a[..20000], c, diff_edits(a[..20000], c))
	assert sw.elapsed().milliseconds() < 4000
	// Nothing in common: everything is set aside before the search.
	other := []string{len: 100000, init: 'other ${index}'}
	sw.restart()
	unrelated := diff_edits(a, other)
	assert unrelated.len == 200000
	assert sw.elapsed().milliseconds() < 2000
}

fn test_diff_texts_numbers_lines_and_marks_a_missing_final_newline() {
	file := diff_texts('a.txt', 'a.txt', 'one\ntwo\nthree', 'one\n2\nthree\n')
	assert file.status == .modified
	assert file.complete
	assert file.additions == 2 && file.deletions == 2
	lines := file.hunks[0].lines
	assert lines.map(it.kind) == [DiffLineKind.context, .removed, .removed, .added, .added]
	assert lines[1].old_line == 2 && lines[1].new_line == 0
	// `three` without a newline differs from `three` with one.
	assert lines[2].text == 'three' && lines[2].no_newline
	assert lines[4].text == 'three' && !lines[4].no_newline
	assert lines[3].new_line == 2
	assert diff_texts('', 'b.txt', '', 'x\n').status == .added
	assert diff_texts('b.txt', '', 'x\n', '').status == .deleted
	renamed := diff_texts('old.txt', 'new.txt', 'x\n', 'x\n')
	assert renamed.status == .renamed
	assert renamed.path() == 'new.txt'
	assert diff_texts('e', 'e', '', '').hunks.len == 0
}

fn test_diff_hunks_cut_merge_and_number_like_unified_diff() {
	file := diff_test_complete()
	three := diff_hunks(file, 3)
	assert three.len == 2
	// Git's default function-name rule takes any line starting with a letter.
	assert three[0].header() == '@@ -7,7 +7,7 @@ line 6'
	assert three[1].header() == '@@ -27,7 +27,6 @@ line 26'
	// With 10 lines of context the changes 20 lines apart share one hunk.
	assert diff_hunks(file, 10).len == 1
	zero := diff_hunks(file, 0)
	assert zero[1].header() == '@@ -30 +29,0 @@ line 29'
	assert zero[1].lines.len == 1
	// A complete file's hunk names the function it is in, as Git does.
	src := diff_texts('m.v', 'm.v', 'fn main() {\n\ta := 1\n\tb := 2\n\tc := 3\n\td := 4\n}\n',
		'fn main() {\n\ta := 1\n\tb := 2\n\tc := 30\n\td := 4\n}\n')
	assert diff_hunks(src, 1)[0].header() == '@@ -3,3 +3,3 @@ fn main() {'
	// Negative context keeps the stored hunks.
	assert diff_hunks(file, -1).len == 1
}

fn test_diff_unified_text_round_trips_through_parse_diff() {
	file := diff_test_complete()
	patch := diff_unified_text(file, 3)
	assert patch.starts_with('diff --git a/a.txt b/a.txt\n--- a/a.txt\n+++ b/a.txt\n@@ -7,7 +7,7 @@')
	parsed := parse_diff(patch) or { panic(err) }
	assert parsed.len == 1
	assert parsed[0].hunks == diff_hunks(file, 3)
	assert parsed[0].additions == file.additions && parsed[0].deletions == file.deletions
	// The final-newline marker and a rename survive the trip.
	open_end := diff_texts('x.txt', 'y.txt', 'a\nb', 'a\nc')
	text := diff_unified_text(open_end, 3)
	assert text.contains('\\ No newline at end of file')
	back := parse_diff(text) or { panic(err) }
	assert back[0].status == .renamed
	assert back[0].old_path == 'x.txt' && back[0].new_path == 'y.txt'
	assert back[0].hunks[0].lines.filter(it.no_newline).len == 2
	// Paths Git has to quote.
	odd := diff_unified_text(diff_texts('dir/sp ace "q".txt', 'dir/sp ace "q".txt', 'a\n',
		'b\n'), 3)
	assert odd.contains('"a/dir/sp ace \\"q\\".txt"')
	assert (parse_diff(odd) or { panic(err) })[0].path() == 'dir/sp ace "q".txt'
}

fn test_diff_inline_ranges_mark_changed_words_or_characters() {
	old, new := diff_inline_ranges('\ttimeout  int = 30', '\ttimeout  time.Duration = 30 * time.second',
		.word)
	// The tab is rune 0: `int` is [10, 13); ` * time.second` is one range.
	assert old == [DiffInlineRange{10, 13}]
	assert new == [DiffInlineRange{10, 23}, DiffInlineRange{28, 42}]
	chars_old, chars_new := diff_inline_ranges('version 15.1', 'version 16.0', .character)
	assert chars_old == [DiffInlineRange{9, 10}, DiffInlineRange{11, 12}]
	assert chars_new == [DiffInlineRange{9, 10}, DiffInlineRange{11, 12}]
	// Changed words with only a space between them are one range.
	a, b := diff_inline_ranges('let a = old value here', 'let a = new thing here', .word)
	assert a == [DiffInlineRange{8, 17}]
	assert b == [DiffInlineRange{8, 17}]
	// Too little in common, equal lines and no unit: no emphasis.
	x, y := diff_inline_ranges('return x', 'let total = compute(values)', .word)
	assert x.len == 0 && y.len == 0
	p, q := diff_inline_ranges('same', 'same', .word)
	assert p.len == 0 && q.len == 0
	r, t := diff_inline_ranges('a b', 'a c', .none)
	assert r.len == 0 && t.len == 0
	// Offsets are in runes, so text beyond ASCII lines up.
	u, v := diff_inline_ranges('über alles', 'über alle', .character)
	assert u == [DiffInlineRange{9, 10}]
	assert v.len == 0
}

// ── Parsing ─────────────────────────────────────────────────────────

fn test_parse_diff_reads_a_git_format_patch() {
	files := diff_test_files()
	assert files.map(it.path()) == ['src/net/client.v', 'src/text/strings.v', 'src/config/loader.v',
		'CHANGELOG.md', 'assets/icon.png', 'docs/legacy-api.md', 'scripts/release.sh']
	client := files[0]
	assert client.status == .modified
	assert client.hunks.len == 2
	assert client.hunks[0].section == 'module net'
	assert client.additions == 5 && client.deletions == 3
	assert !client.complete
	assert client.headers == ['index 7bd142c..ee59e3e 100644']
	// An empty context line whose space was stripped still counts.
	assert client.hunks[0].lines[4].kind == .context && client.hunks[0].lines[4].text == ''
	renamed := files[1]
	assert renamed.status == .renamed
	assert renamed.old_path == 'src/util/strings.v' && renamed.new_path == 'src/text/strings.v'
	assert renamed.similarity == 81
	loader := files[2]
	assert loader.conflicts.len == 2
	assert !loader.conflicts[0].has_base() && loader.conflicts[1].has_base()
	assert loader.conflicts[1].ours_label == 'HEAD'
	assert loader.conflicts[1].base_label == 'merged common ancestors'
	assert loader.conflicts[1].theirs_label == 'feature/env-config'
	assert loader.conflicts[1].first_line == 22 && loader.conflicts[1].last_line == 31
	changelog := files[3]
	last := changelog.hunks[0].lines
	assert last[last.len - 3].kind == .removed && last[last.len - 3].no_newline
	assert last.last().kind == .added && last.last().no_newline
	binary := files[4]
	assert binary.binary && !binary.has_source()
	assert binary.summary() == 'Binary file not shown'
	deleted := files[5]
	assert deleted.status == .deleted && deleted.new_path == '' && deleted.old_mode == '100644'
	mode := files[6]
	assert mode.summary() == 'File mode changed from 100644 to 100755'
	assert mode.old_mode == '100644' && mode.new_mode == '100755'
}

fn test_parse_diff_header_reads_the_commit() {
	header := parse_diff_header(diff_test_patch)
	assert header.commit == '6a9a392750b6485ba3e3031830a81c17ec62c3d7'
	assert header.author == 'Ada Lovelace <ada@example.com>'
	assert header.date == 'Fri, 16 Oct 2026 09:21:44 +0200'
	assert header.subject == 'Retry requests that time out and move the string helpers'
	assert header.message == 'Requests that fail are now retried up to three times.\n\nThe merge still has two conflicts.'
	shown := parse_diff_header('commit abc123 (HEAD -> main)\nAuthor: Grace <g@example.com>\nDate:   Mon Oct 12 10:00:00 2026\n\n    Fix the build\n\n    It was broken.\n\ndiff --git a/x b/x\n')
	assert shown.commit == 'abc123'
	assert shown.author == 'Grace <g@example.com>'
	assert shown.subject == 'Fix the build'
	assert shown.message == 'It was broken.'
}

fn test_parse_diff_handles_prefixes_quoting_and_transport() {
	// diff.noprefix, diff.mnemonicPrefix, a plain unified diff with timestamps.
	noprefix := parse_diff('diff --git src/a.v src/a.v\n--- src/a.v\n+++ src/a.v\n@@ -1 +1 @@\n-a\n+b\n') or {
		panic(err)
	}
	assert noprefix[0].path() == 'src/a.v'
	mnemonic := parse_diff('diff --git i/x y.txt w/x y.txt\n--- i/x y.txt\n+++ w/x y.txt\n@@ -1 +1 @@\n-a\n+b\n') or {
		panic(err)
	}
	assert mnemonic[0].path() == 'x y.txt'
	plain := parse_diff('--- a/x.c\t2026-10-01 10:00:00\n+++ b/x.c\t2026-10-02 10:00:00\n@@ -1,2 +1,2 @@\n a\n-b\n+c\n--- old/y.c\n+++ new/y.c\n@@ -1 +1 @@\n-y\n+z\n') or {
		panic(err)
	}
	assert plain.map(it.path()) == ['x.c', 'new/y.c']
	assert plain[1].old_path == 'old/y.c'
	quoted := parse_diff('diff --git "a/caf\\303\\251 \\"x\\".txt" "b/caf\\303\\251 \\"x\\".txt"\nnew file mode 100644\n--- /dev/null\n+++ "b/caf\\303\\251 \\"x\\".txt"\n@@ -0,0 +1 @@\n+hi\n') or {
		panic(err)
	}
	assert quoted[0].path() == 'café "x".txt'
	assert quoted[0].status == .added
	assert quoted[0].hunks[0].header() == '@@ -0,0 +1 @@'
	// CRLF transport: records end in CR, which is not part of the source.
	crlf := parse_diff('diff --git a/w.txt b/w.txt\r\n--- a/w.txt\r\n+++ b/w.txt\r\n@@ -1 +1 @@\r\n-a\r\n+b\r\n') or {
		panic(err)
	}
	assert crlf[0].hunks[0].lines[1].text == 'b'
	// A pure rename and an empty new file have no hunks.
	moves := parse_diff('diff --git a/x b/y\nsimilarity index 100%\nrename from x\nrename to y\ndiff --git a/e b/e\nnew file mode 100644\nindex 0000000..e69de29\n') or {
		panic(err)
	}
	assert moves[0].summary() == 'File renamed without changes'
	assert moves[1].status == .added && moves[1].summary() == 'Empty file added'
	// No text, no files.
	empty := parse_diff('  \n') or { panic(err) }
	assert empty.len == 0
}

fn diff_test_parse_error(patch string) DiffParseError {
	parse_diff(patch) or {
		if err is DiffParseError {
			return err
		}
		panic('not a DiffParseError: ${err}')
	}
	panic('accepted: ${patch}')
}

fn test_parse_diff_reports_malformed_patches_with_their_line() {
	head := '--- a/x\n+++ b/x\n'
	mut e := diff_test_parse_error(head + '@@ -1,2 +1,2 @@\n a\n-b\n')
	assert e.line == 6 && e.message == 'hunk ended before its declared line counts'
	e = diff_test_parse_error(head + '@@ -1 +1 @@\n-a\n-b\n+c\n')
	assert e.line == 5
	e = diff_test_parse_error(head + '@@ -1,x +1 @@\n')
	assert e.line == 3 && e.message == 'invalid hunk header'
	e = diff_test_parse_error('diff --cc file\n')
	assert e.message == 'combined diffs are not supported'
	e = diff_test_parse_error('diff --git a/x b/x\n@@ -1 +1 @@\n-a\n+b\n')
	assert e.line == 2 && e.message == 'hunk requires original and modified file headers'
	e = diff_test_parse_error(head + '@@ -1 +1 @@\n-a\n+b\n+c\n')
	assert e.line == 6 && e.message == 'source line outside a hunk'
	e = diff_test_parse_error(head + '@@ -1,2 +1,2 @@\n-a\n\\ No newline at end of file\n-b\n+c\n+d\n')
	assert e.message == 'source continues after an unterminated final line'
	e = diff_test_parse_error(head + '@@ -5 +5 @@\n-a\n+b\n@@ -3 +3 @@\n-c\n+d\n')
	assert e.message == 'overlapping or unordered hunks'
	e = diff_test_parse_error('just some text\nwithout a diff\n')
	assert e.line == 1
	assert e.msg() == 'patch line 1: expected a unified or Git diff'
}

fn test_parse_diff_conflicts_reads_a_working_file_and_resolves_it() {
	text := 'a\n<<<<<<< HEAD\nours 1\nours 2\n||||||| base\nbase\n=======\ntheirs\n>>>>>>> topic\nb\n<<<<<<< HEAD\nx\n=======\n>>>>>>> topic\n'
	file := parse_diff_conflicts('w.txt', text) or { panic(err) }
	assert file.status == .conflicted && file.complete && file.single_column()
	assert file.conflicts.len == 2
	c := file.conflicts[0]
	assert c.first_line == 2 && c.last_line == 9
	assert c.ours_label == 'HEAD' && c.base_label == 'base' && c.theirs_label == 'topic'
	assert diff_conflict_kept(file, c, .ours) == ['ours 1', 'ours 2']
	assert diff_conflict_kept(file, c, .theirs) == ['theirs']
	assert diff_conflict_kept(file, c, .both) == ['ours 1', 'ours 2', 'theirs']
	// The second conflict's incoming part is empty.
	assert diff_conflict_kept(file, file.conflicts[1], .theirs).len == 0
	one := {
		0: DiffConflictResolution.ours
	}
	if _ := diff_resolve_text(file, one) {
		assert false, 'resolved with a conflict left'
	}
	both := {
		0: DiffConflictResolution.theirs
		1: .both
	}
	resolved := diff_resolve_text(file, both) or { panic('unresolved') }
	assert resolved == 'a\ntheirs\nb\nx\n'
	// A patch does not hold the whole file, so it cannot be written out.
	all_ours := {
		0: DiffConflictResolution.ours
		1: .ours
	}
	if _ := diff_resolve_text(diff_test_files()[2], all_ours) {
		assert false, 'resolved a patch'
	}
	// Markers that do not balance.
	if _ := parse_diff_conflicts('w', 'a\n<<<<<<< HEAD\nb\n') {
		assert false, 'unclosed conflict accepted'
	}
	if _ := parse_diff_conflicts('w', '<<<<<<< a\n>>>>>>> b\n') {
		assert false, 'conflict without separator accepted'
	}
	// A line of equals signs outside a conflict is just text.
	plain := parse_diff_conflicts('w', '=======\ntext\n') or { panic(err) }
	assert plain.conflicts.len == 0
}

// ── State and rows ──────────────────────────────────────────────────

fn test_unified_rows_show_removals_then_additions_with_pairs() {
	s := diff_state(diff_test_files())
	rows := s.rows()
	assert rows[0].kind == .file_header && rows[1].kind == .hunk
	hunk := s.files()[0].hunks[0]
	// `// Client sends ...` changed: the removed row pairs with the added one.
	mut removed := -1
	for i, row in rows {
		if row.kind == .line && row.file == 0 && row.hunk == 0 && row.new < 0 {
			removed = i
			break
		}
	}
	assert hunk.lines[rows[removed].old].text == '// Client sends requests to one service.'
	partner := rows[removed].pair
	assert hunk.lines[partner].text.ends_with('retrying the ones that time out.')
	assert rows[removed + 1].new == partner && rows[removed + 1].pair == rows[removed].old
}

fn test_split_rows_pair_removed_and_added_lines() {
	s := diff_state(diff_test_files(), mode: .split)
	rows := s.rows().filter(it.kind == .line && it.file == 0 && it.hunk == 0)
	lines := s.files()[0].hunks[0].lines
	// `timeout int` is replaced by two lines: one pair, then an added line alone.
	mut found := false
	for i, row in rows {
		if row.old >= 0 && lines[row.old].text.contains('timeout  int') {
			assert lines[row.new].text.contains('time.Duration')
			assert rows[i + 1].old < 0 && lines[rows[i + 1].new].text.contains('retries')
			found = true
		}
	}
	assert found
	// A context row shows the same line on both sides.
	assert rows[0].old == rows[0].new
}

fn test_unchanged_runs_fold_to_the_context_lines_and_reveal() {
	mut s := diff_state([diff_test_complete()], context_lines: 3)
	folds := diff_test_rows_of(s, .fold)
	assert folds.len == 3
	rows := s.rows()
	// Lines 1-6 above the first change, 14-26 between the changes, 34-40 below.
	assert [rows[folds[0]].fold_start, rows[folds[0]].fold_end] == [0, 6]
	assert !rows[folds[0]].above && rows[folds[0]].below
	assert rows[folds[1]].above && rows[folds[1]].below
	assert rows[folds[1]].fold_end - rows[folds[1]].fold_start == 13
	assert rows[folds[2]].above && !rows[folds[2]].below
	// Revealing 5 lines at the top of the middle fold leaves 8 hidden.
	s.set_expansion_lines(5)
	assert s.reveal(folds[1], .top)
	middle := s.rows()[diff_test_rows_of(s, .fold)[1]]
	assert middle.fold_end - middle.fold_start == 8
	assert s.reveal(diff_test_rows_of(s, .fold)[1], .bottom)
	// Three left, fewer than nothing to fold? No: 3 >= min_collapsed (2).
	assert s.rows()[diff_test_rows_of(s, .fold)[1]].fold_end - s.rows()[diff_test_rows_of(s, .fold)[1]].fold_start == 3
	assert s.reveal(diff_test_rows_of(s, .fold)[1], .all)
	assert diff_test_rows_of(s, .fold).len == 2
	// Ranges shorter than min_collapsed_lines stay visible.
	s.collapse_unchanged()
	s.set_min_collapsed_lines(8)
	assert diff_test_rows_of(s, .fold).len == 1
	s.set_min_collapsed_lines(2)
	s.expand_unchanged()
	assert diff_test_rows_of(s, .fold).len == 0
	assert s.unchanged_expanded()
	s.collapse_unchanged()
	assert diff_test_rows_of(s, .fold).len == 3
	s.set_context_lines(-1)
	assert diff_test_rows_of(s, .fold).len == 0
	assert s.rows().filter(it.kind == .line).len == 41
	// A reference file never folds.
	reference := diff_state([diff_file_unchanged('r.txt', diff_test_text(diff_test_numbered(50)))])
	assert diff_test_rows_of(reference, .fold).len == 0
}

fn test_patch_folds_only_the_context_it_supplies() {
	mut s := diff_state(diff_test_files(), context_lines: 1)
	rows := s.rows()
	folds := diff_test_rows_of(s, .fold).filter(rows[it].file == 0)
	// Hunk 1 starts with three context lines; one stays, two fold, and with
	// nothing above them in the patch they can only be revealed upward.
	first := rows[folds[0]]
	assert first.hunk == 0 && first.fold_start == 0 && first.fold_end == 2
	assert !first.above && first.below
	if _ := diff_event_from_click(diff_test_config(s), 'review:component:fold:${folds[0]}:top',
		KeyModifiers{})
	{
		assert false, 'revealed toward source the patch does not have'
	}
	e := diff_event_from_click(diff_test_config(s), 'review:component:fold:${folds[0]}:bottom',
		KeyModifiers{}) or { panic('fold') }
	assert s.apply(e)
}

fn test_collapsed_files_show_only_their_header_and_survive_new_files() {
	mut s := diff_state(diff_test_files())
	s.set_file_collapsed('src/net/client.v', true)
	assert s.is_file_collapsed('src/net/client.v')
	assert s.rows()[1].kind == .file_header && s.rows()[1].file == 1
	files := diff_test_files()
	s.set_files(files)
	assert s.is_file_collapsed('src/net/client.v')
	s.set_files(files[1..])
	assert !s.is_file_collapsed('src/net/client.v')
	summaries := diff_test_rows_of(s, .file_summary)
	assert summaries.len == 2 // The binary file and the mode change.
}

fn test_source_coordinates_map_rows_to_lines_and_back() {
	mut s := diff_state([diff_test_complete()], context_lines: 2)
	row := s.row_for_line(DiffLinePosition{'a.txt', .modified, 10}) or { panic('row') }
	assert s.row_line(row, .modified) or { panic('line') }.text == 'line 10 changed'
	assert s.row_position(row, .modified) or { panic('pos') } == DiffLinePosition{'a.txt', .modified, 10}
	assert s.row_position(row, .original) == none
	// Line 20 is folded away until revealed; then it maps both ways.
	position := DiffLinePosition{'a.txt', .original, 20}
	assert s.row_for_line(position) == none
	s.set_file_collapsed('a.txt', true)
	revealed := s.reveal_line(position) or { panic('reveal') }
	assert !s.is_file_collapsed('a.txt')
	assert s.row_position(revealed, .original) or { panic('pos') } == position
	assert s.row_position(revealed, .modified) or { panic('pos') }.line == 20
	// A line the file does not have.
	assert s.reveal_line(DiffLinePosition{'a.txt', .modified, 400}) == none
	assert s.reveal_line(DiffLinePosition{'nope.txt', .modified, 1}) == none
}

fn test_navigation_moves_between_changes_and_hunks_and_wraps() {
	s := diff_state(diff_test_files())
	changes := s.change_rows()
	assert changes.len > 5
	first := changes[0]
	assert s.row_changed(first) && !s.row_changed(first - 1)
	assert s.next_change(-1) or { -1 } == first
	assert s.next_change(first) or { -1 } == changes[1]
	assert s.next_change(changes.last()) or { -1 } == first
	assert s.previous_change(first) or { -1 } == changes.last()
	assert s.previous_change(changes[1]) or { -1 } == first
	// A whole conflict, headings and all, is one change.
	loader_rows := s.rows().filter(it.file == 2 && it.kind == .conflict)
	assert loader_rows.len == 5
	hunks := s.hunk_rows()
	assert hunks.len == diff_test_rows_of(s, .hunk).len
	// In a complete file a hunk is each run of lines with a change between folds.
	complete := diff_state([diff_test_complete()])
	assert complete.hunk_rows().len == 2
	assert complete.next_hunk(complete.hunk_rows()[0]) or { -1 } == complete.hunk_rows()[1]
	empty := diff_state([]DiffFile{})
	assert empty.next_change(0) == none
}

fn test_selection_clips_crosses_and_copies_in_every_format() {
	mut s := diff_state(diff_test_files())
	// Original lines 4-12 of client.v: the patch has 3-13, so all of them.
	s.set_selected_lines(DiffLineRange{
		path:  'src/net/client.v'
		side:  .original
		start: 12
		end:   4
	})
	range := s.selected_lines() or { panic('none') }
	assert range.start == 4 && range.end == 12
	assert s.selected_text(.source).starts_with('import time\nimport json\n\n// Client sends requests to one service.\n')
	assert s.selected_text(.source).count('\n') == 9
	// The modified version of the same span has the added lines too.
	modified := s.selected_text(.modified)
	assert modified.contains('import math\n') && modified.contains('retries  int = 3\n')
	assert !modified.contains('timeout  int = 30')
	patch := s.selected_text(.patch)
	assert patch.contains('\n+import math\n') && patch.contains('\n-\ttimeout  int = 30\n')
	assert s.selected_text(.original).count('\n') == 9
	// Out of range lines are clipped away; none left clears the selection.
	s.set_selected_lines(DiffLineRange{
		path:  'src/net/client.v'
		side:  .modified
		start: 15
		end:   30
	})
	assert (s.selected_lines() or { panic('none') }).end == 15
	s.set_selected_lines(DiffLineRange{
		path:  'src/net/client.v'
		side:  .modified
		start: 20
		end:   30
	})
	assert s.selected_lines() == none
	assert s.selected_text(.source) == ''
	// Crossing from a removed line to an added one covers the body between.
	s.set_selected_lines(DiffLineRange{
		path:    'src/net/client.v'
		side:    .original
		start:   10
		end:     12
		crosses: true
	})
	assert s.selected_text(.source) == '\ttimeout  int = 30\n\ttimeout  time.Duration = 30 * time.second\n\tretries  int = 3\n'
	// The final-newline marker is part of patch text.
	s.set_selected_lines(DiffLineRange{
		path:  'CHANGELOG.md'
		side:  .modified
		start: 9
		end:   9
	})
	assert s.selected_text(.patch) == '+- Document the WORKERS setting.\n\\ No newline at end of file\n'
	s.clear_selection()
	assert !diff_copy_selection(s, .source)
}

fn test_clicks_select_and_shift_extends_from_the_anchor() {
	mut s := diff_state(diff_test_files())
	config := diff_test_config(s)
	row_of := fn [s] (side DiffSide, line int) int {
		return s.row_for_line(DiffLinePosition{'src/net/client.v', side, line}) or { -1 }
	}
	first := diff_event_from_click(config, 'review:component:line:${row_of(.modified, 9)}:m',
		KeyModifiers{}) or { panic('click') }
	assert first.kind == .select
	assert first.range == DiffLineRange{'src/net/client.v', .modified, 9, 9, false}
	assert s.apply(first)
	// The same click again changes nothing.
	if _ := diff_event_from_click(diff_test_config(s), 'review:component:line:${row_of(.modified, 9)}:m', KeyModifiers{})
	{
		assert false, 'no-op click decoded'
	}
	shift := KeyModifiers{
		shift: true
	}
	up := diff_event_from_click(diff_test_config(s), 'review:component:line:${row_of(.modified, 5)}:m', shift) or { panic('shift') }
	assert up.range.start == 5 && up.range.end == 9 && up.anchor.line == 9
	assert s.apply(up)
	// Shift-click on the other side crosses in Unified mode...
	cross := diff_event_from_click(diff_test_config(s), 'review:component:line:${row_of(.original, 10)}:o', shift) or { panic('cross') }
	assert cross.range.crosses && cross.range.side == .modified && cross.range.start == 9
	assert cross.range.end == 10
	// ...and starts over in Split mode.
	s.set_mode(.split)
	split_row := s.row_for_line(DiffLinePosition{'src/net/client.v', .original, 10}) or { -1 }
	fresh := diff_event_from_click(diff_test_config(s), 'review:component:line:${split_row}:o',
		shift) or { panic('fresh') }
	assert !fresh.range.crosses && fresh.range.start == 10 && fresh.range.end == 10
	// A side the row does not show.
	added := s.row_for_line(DiffLinePosition{'src/net/client.v', .modified, 6}) or { -1 }
	if _ := diff_event_from_click(diff_test_config(s), 'review:component:line:${added}:o',
		KeyModifiers{})
	{
		assert false, 'selected a missing side'
	}
}

fn test_events_decode_headers_folds_and_conflicts_and_reject_the_rest() {
	mut s := diff_state(diff_test_files())
	mut config := diff_test_config(s)
	toggle := diff_event_from_click(config, 'review:component:file:2', KeyModifiers{}) or {
		panic('file')
	}
	assert toggle.kind == .file_collapsed && toggle.path == 'src/config/loader.v' && toggle.collapsed
	assert s.apply(toggle)
	assert s.is_file_collapsed('src/config/loader.v')
	config = diff_test_config(s)
	again := diff_event_from_click(config, 'review:component:file:2', KeyModifiers{}) or {
		panic('file')
	}
	assert !again.collapsed
	s.apply(again)
	config = diff_test_config(s)
	accept := diff_event_from_click(config, 'review:component:conflict:2:1:theirs', KeyModifiers{}) or {
		panic('accept')
	}
	assert accept.kind == .conflict_resolved && accept.conflict == 1 && accept.resolution == .theirs
	assert s.apply(accept)
	assert s.conflict_resolution('src/config/loader.v', 1) or { panic('none') } == .theirs
	assert s.unresolved_conflicts() == 1
	config = diff_test_config(s)
	if _ := diff_event_from_click(config, 'review:component:conflict:2:1:theirs', KeyModifiers{}) {
		assert false, 'no-op resolution decoded'
	}
	if _ := diff_event_from_click(config, 'review:component:conflict:2:0:undo', KeyModifiers{}) {
		assert false, 'undid an unresolved conflict'
	}
	undo := diff_event_from_click(config, 'review:component:conflict:2:1:undo', KeyModifiers{}) or {
		panic('undo')
	}
	assert s.apply(undo)
	assert s.unresolved_conflicts() == 2
	// The resolved region shows only the kept lines, under a resolved heading.
	s.resolve_conflict('src/config/loader.v', 0, .both)
	resolved := s.rows().filter(it.file == 2 && it.conflict == 0)
	assert resolved[0].kind == .conflict && resolved[0].part == .resolved
	assert resolved.len == 4 // Heading, `import os`, `import os`, `import runtime`.
	assert s.resolved_text('src/config/loader.v') == none
	config = diff_test_config(s)
	for bad in ['review:component:file:9', 'review:component:file:01', 'review:component:file:',
		'other:component:file:0', 'review:component:fold:1:all', 'review:component:line:0:m',
		'review:component:line:3:x', 'review:component:conflict:2:5:ours',
		'review:component:conflict:2:0:maybe', 'review:component:conflict:2:0',
		'review:component:nothing', 'file:0'] {
		if e := diff_event_from_click(config, bad, KeyModifiers{}) {
			assert false, '${bad} decoded as ${e.kind}'
		}
	}
	// Forged row numbers beyond the rows.
	if _ := diff_event_from_click(config, 'review:component:line:99999999999:m', KeyModifiers{}) {
		assert false, 'overflow decoded'
	}
}

fn test_keys_scroll_select_copy_and_navigate() {
	mut s := diff_state(diff_test_files())
	mut config := diff_test_config(s)
	key := fn (code KeyCode, shift bool, alt bool, cmd bool) KeyEvent {
		return KeyEvent{
			code:  code
			shift: shift
			alt:   alt
			cmd:   cmd
		}
	}
	down := diff_event_from_key(config, key(.page_down, false, false, false)) or { panic('page') }
	assert down.kind == .scroll && down.offset > 0
	assert diff_event_from_key(config, key(.home, false, false, false)) == none
	end := diff_event_from_key(config, key(.end, false, false, false)) or { panic('end') }
	assert end.offset == diff_view_layout(config).max_offset()
	assert diff_event_from_key(config, key(.c, false, false, true)) == none
	assert diff_event_from_key(config, key(.escape, false, false, false)) == none
	// Shift+Down starts at the first line of the top file, then extends.
	start := diff_event_from_key(config, key(.down, true, false, false)) or { panic('shift') }
	assert start.kind == .select && start.range.path == 'src/net/client.v' && start.range.start == 3
	s.apply(start)
	config = diff_test_config(s)
	more := diff_event_from_key(config, key(.down, true, false, false)) or { panic('more') }
	assert more.range.start == 3 && more.range.end == 4
	s.apply(more)
	config = diff_test_config(s)
	copy_event := diff_event_from_key(config, key(.c, false, false, true)) or { panic('copy') }
	assert copy_event.kind == .copy && copy_event.format == .source
	all := diff_event_from_key(config, key(.a, false, false, true)) or { panic('all') }
	assert all.range.start == 3 && all.range.end == 46
	clear := diff_event_from_key(config, key(.escape, false, false, false)) or { panic('esc') }
	assert clear.kind == .clear_selection
	next := diff_event_from_key(config, key(.f7, false, false, false)) or { panic('f7') }
	assert next.kind == .navigate && next.row == s.change_rows()[0]
	s.apply(next)
	assert s.current_row() == next.row
	config = diff_test_config(s)
	after := diff_event_from_key(config, key(.f7, false, false, false)) or { panic('f7') }
	assert after.row == s.change_rows()[1]
	back := diff_event_from_key(config, key(.f7, true, false, false)) or { panic('shift f7') }
	assert back.row == s.change_rows().last()
	hunk := diff_event_from_key(config, key(.down, false, true, false)) or { panic('alt') }
	assert hunk.kind == .navigate && s.rows()[hunk.row].kind == .hunk
	// Keys with other modifiers belong to someone else.
	assert diff_event_from_key(config, key(.down, true, true, false)) == none
	assert diff_event_from_key(config, key(.x, false, false, true)) == none
}

// ── The view ────────────────────────────────────────────────────────

fn test_diff_view_builds_code_columns_and_places_inline_boxes() {
	// A measurer with 10-point characters and a 4-point label inset.
	configure_text_measurer(fn (text string, style TextStyle) f64 {
		return f64(text.runes().len) * 10 + 4
	})
	defer {
		configure_text_measurer(MeasureTextFn(unsafe { nil }))
	}
	s := diff_state([diff_texts('m.txt', 'm.txt', 'value = old\n', 'value = new\n')])
	config := diff_test_config(s)
	layout := diff_view_layout(config)
	assert layout.advance == 10 && layout.inset == 4
	el := diff_view(config) or { panic(err) }
	scrolls := diff_test_find(el, fn (e Element) bool {
		return e.kind == .scroll
	})
	assert scrolls.map(it.id) == ['review:component:body', 'review:component:code:0:m']
	column := scrolls[1]
	assert column.scroll_mode == .horizontal_only && column.box.transparent
	// `old` starts at rune 8: the box starts 8 characters past the code padding.
	boxes := diff_test_find(column, fn (e Element) bool {
		return e.key.starts_with('hl')
	})
	assert boxes.len == 2
	assert boxes[0].frame.x == diff_code_pad + 80 && boxes[0].frame.width == 30
	texts := diff_test_find(column, fn (e Element) bool {
		return e.kind == .label && e.key == 'text'
	})
	assert texts.map(it.text) == ['value = old', 'value = new']
	// The label sits half its inset left so its first glyph is at the padding.
	assert texts[0].frame.x == diff_code_pad - 2
	assert texts[0].text_style.font_family == 'monospace'
	// Split mode has a column per side.
	mut split := s
	split.set_mode(.split)
	split_el := diff_view(diff_test_config(split)) or { panic(err) }
	ids := diff_test_find(split_el, fn (e Element) bool {
		return e.kind == .scroll
	}).map(it.id)
	assert ids == ['review:component:body', 'review:component:code:0:o', 'review:component:code:0:m']
}

fn test_diff_view_builds_only_the_rows_in_view() {
	old := diff_test_numbered(20000)
	mut new := old.clone()
	for i := 100; i < new.len; i += 500 {
		new[i] = 'changed ${i}'
	}
	s := diff_state([diff_texts('big.txt', 'big.txt', diff_test_text(old), diff_test_text(new))],
		context_lines: -1
	)
	assert s.rows().len > 20000
	mut sw := time.new_stopwatch()
	el := diff_view(DiffViewConfig{
		...diff_test_config(s)
		scroll_y: 150000
	}) or { panic(err) }
	assert sw.elapsed().milliseconds() < 1500
	body := el.children[0]
	rows := body.children.filter(it.key.starts_with('row:'))
	assert rows.len > 20 && rows.len < 80
	layout := diff_view_layout(DiffViewConfig{
		...diff_test_config(s)
		scroll_y: 150000
	})
	assert layout.range.start > 7000
	assert body.children[0].frame.height == layout.content_height()
	// Scrolling to a row and back: the offset brings it to the top.
	row := s.row_for_line(DiffLinePosition{'big.txt', .modified, 15001}) or { panic('row') }
	offset := diff_scroll_offset_for_row(diff_test_config(s), row, .start)
	assert offset == layout.rows.item_start(row)
	assert diff_top_row(DiffViewConfig{
		...diff_test_config(s)
		scroll_y: offset
	}) == row
	top := diff_top_position(DiffViewConfig{
		...diff_test_config(s)
		scroll_y: offset
	}) or { panic('top') }
	assert top.line == 15001
}

fn test_diff_view_draws_headers_annotations_conflicts_and_themes() {
	mut s := diff_state(diff_test_files())
	s.set_annotations([
		DiffAnnotation{
			id:    'c1'
			path:  'src/net/client.v'
			line:  12
			title: 'Review'
			text:  'Should this be configurable?'
		},
		DiffAnnotation{
			id:   'f1'
			path: 'src/text/strings.v'
			text: 'Moved from util.'
		},
		DiffAnnotation{
			id:   'gone'
			path: 'src/net/client.v'
			line: 400
			text: 'Not in the patch.'
		},
	])
	notes := diff_test_rows_of(s, .annotation)
	assert notes.len == 2
	assert s.rows()[notes[0] - 1].kind == .line
	assert s.rows()[notes[1] - 1].kind == .file_header
	config := DiffViewConfig{
		...diff_test_config(s)
		frame: rect(0, 0, 900, 4000)
	}
	el := diff_view(config) or { panic(err) }
	assert el.accessibility_value == '7 files, 24 additions, 7 deletions'
	labels := diff_test_find(el, fn (e Element) bool {
		return e.kind == .label
	}).map(it.text)
	assert 'Review' in labels && 'Should this be configurable?' in labels
	assert 'src/util/strings.v' in labels && 'src/text/strings.v' in labels
	assert '2 conflicts' in labels && 'Renamed' in labels && 'Binary' in labels
	assert 'Current change' in labels && 'Common ancestor' in labels && 'Incoming change' in labels
	assert '@@ -3,11 +3,13 @@ module net' in labels
	assert 'File mode changed from 100644 to 100755' in labels
	accept := diff_test_find(el, fn (e Element) bool {
		return e.action_id == 'review:component:conflict:2:1:both'
	})
	assert accept.len == 1
	headers := diff_test_find(el, fn (e Element) bool {
		return e.action_id.starts_with('review:component:file:')
	})
	assert headers.len == 7 && headers[0].accessibility_label == 'Collapse src/net/client.v'
	// Dark and light differ; added and removed lines are tinted from the theme.
	light := diff_colors(component_theme(false))
	dark := diff_colors(component_theme(true))
	assert light.added != dark.added && light.removed != dark.removed
	assert light.added != light.surface && light.removed != light.surface
	// Custom annotation content with its own height.
	custom := diff_view(DiffViewConfig{
		...config
		render_annotation: fn (note DiffAnnotation, frame Rect) []Element {
			return [label('', 'custom ${note.id}', rect(0, 0, frame.width, 20), TextStyle{})]
		}
	}) or { panic(err) }
	assert diff_test_find(custom, fn (e Element) bool {
		return e.text == 'custom c1'
	}).len == 1
	// No files: the empty text.
	empty := diff_view(diff_test_config(diff_state([]DiffFile{}))) or { panic(err) }
	assert diff_test_find(empty, fn (e Element) bool {
		return e.text == 'No changes'
	}).len == 1
}

fn test_diff_view_marks_selection_and_current_change_and_validates() {
	mut s := diff_state(diff_test_files())
	s.set_selected_lines(DiffLineRange{
		path:  'src/net/client.v'
		side:  .modified
		start: 6
		end:   6
	})
	s.set_current_row(s.change_rows()[0])
	el := diff_view(diff_test_config(s)) or { panic(err) }
	current := diff_test_find(el, fn (e Element) bool {
		return e.key == 'current'
	})
	assert current.len == 1
	colors := diff_colors(component_theme(false))
	gutters := diff_test_find(el, fn (e Element) bool {
		return e.key == 'gutter'
	})
	assert gutters.filter(it.box.bg == colors.selected_gutter).len == 1
	if _ := diff_view(DiffViewConfig{
		...diff_test_config(s)
		id: ''
	})
	{
		assert false, 'missing id accepted'
	}
	if _ := diff_view(DiffViewConfig{
		...diff_test_config(s)
		frame: rect(0, 0, -1, 10)
	})
	{
		assert false, 'negative frame accepted'
	}
	// Without line numbers or signs the gutter shrinks.
	plain := diff_view_layout(DiffViewConfig{
		...diff_test_config(s)
		line_numbers:     false
		change_indicator: .bars
	})
	assert plain.number_width == 0 && plain.marker_width == 8
}

fn test_display_text_expands_tabs_and_cuts_long_lines() {
	assert diff_display_text('\tx') == '    x'
	assert diff_display_text('ab\tx') == 'ab  x'
	assert diff_display_text('a\r') == 'a'
	assert diff_display_text('plain') == 'plain'
	long := 'x'.repeat(3000)
	cut := diff_display_text(long)
	assert cut.runes().len == diff_max_display_runes + 1 && cut.ends_with('…')
	assert diff_display_columns('\tx') == 5
	assert diff_display_columns('漢字') == 4
}
