module ui2

import math

// Diff: the model behind GPUI Kit's Diff (crates/component/src/diff/). Upstream
// only displays patches; ui2's Diff also computes them. This file holds the
// document types, the line diff of two texts (Myers' algorithm in linear
// space), unified hunks with any amount of context, unified patch output and
// the word or character emphasis of a changed line pair. Parsing patches and
// conflict markers is in component_diff_parse.v, the controlled state in
// component_diff_state.v and the view in component_diff_view.v. All of it is
// new ui2 code.

// DiffSide names a version of a file.
pub enum DiffSide {
	original // The old version: removed and unchanged lines.
	modified // The new version: added and unchanged lines.
}

// other is the opposite version.
pub fn (side DiffSide) other() DiffSide {
	return if side == .original { DiffSide.modified } else { DiffSide.original }
}

pub enum DiffLineKind {
	context // In both versions.
	removed // Only in the original.
	added   // Only in the modified version.
}

// DiffLine is one line of a hunk.
pub struct DiffLine {
pub:
	kind     DiffLineKind
	old_line int    // One-based line in the original; 0 for an added line.
	new_line int    // One-based line in the modified version; 0 for a removed line.
	text     string // The source, without the patch prefix or the line ending.
	// no_newline is set on the last line of a version that does not end with a
	// newline, which a patch marks with `\ No newline at end of file`.
	no_newline bool
}

// number is the line's one-based number in a version, or 0 when the line is not in it.
pub fn (line DiffLine) number(side DiffSide) int {
	return if side == .original { line.old_line } else { line.new_line }
}

// changed reports a removed or added line.
pub fn (line DiffLine) changed() bool {
	return line.kind != .context
}

// DiffHunk is a run of lines with the `@@ -old_start,old_count +new_start,new_count @@`
// coordinates of a unified diff. A count of zero means the version has no line
// there and its start names the line before.
pub struct DiffHunk {
pub:
	old_start int
	old_count int
	new_start int
	new_count int
	section   string // What follows the closing @@: usually the enclosing function.
	lines     []DiffLine
}

// header is the hunk's `@@` line.
pub fn (hunk DiffHunk) header() string {
	mut out := '@@ -${diff_range_text(hunk.old_start, hunk.old_count)} +${diff_range_text(hunk.new_start, hunk.new_count)} @@'
	if hunk.section.len > 0 {
		out += ' ' + hunk.section
	}
	return out
}

fn diff_range_text(start int, count int) string {
	return if count == 1 { start.str() } else { '${start},${count}' }
}

// changes counts the hunk's removed and added lines.
pub fn (hunk DiffHunk) changes() (int, int) {
	mut removed := 0
	mut added := 0
	for line in hunk.lines {
		match line.kind {
			.removed { removed++ }
			.added { added++ }
			.context {}
		}
	}
	return removed, added
}

pub enum DiffFileStatus {
	modified
	added
	deleted
	renamed
	copied
	unchanged  // A whole file shown for reference (diff_file_unchanged).
	conflicted // A working file with merge conflict markers (parse_diff_conflicts).
}

// DiffConflict is a merge-conflict region: `<<<<<<<`, the current ("ours")
// lines, optionally `|||||||` and the diff3 base, `=======`, the incoming
// ("theirs") lines and `>>>>>>>`. Positions are indices into the lines of hunk
// `hunk`, with exclusive ends, so an empty part has start == end; removed
// lines a patch interleaves are not part of the working file and are skipped.
pub struct DiffConflict {
pub:
	hunk         int
	start        int // The `<<<<<<<` line.
	end          int // Just past the `>>>>>>>` line.
	ours_start   int
	ours_end     int
	base_start   int = -1 // -1 for a two-way conflict.
	base_end     int = -1
	theirs_start int
	theirs_end   int
	ours_label   string // The text after `<<<<<<<`, such as HEAD.
	base_label   string
	theirs_label string // The text after `>>>>>>>`, such as a branch name.
	first_line   int    // One-based working-file line of `<<<<<<<`.
	last_line    int    // One-based working-file line of `>>>>>>>`.
}

// has_base reports a diff3 conflict, which shows the common ancestor too.
pub fn (conflict DiffConflict) has_base() bool {
	return conflict.base_start >= 0
}

// DiffFile is one file of a diff: its paths, its status in Git's terms and its
// hunks. Build one with diff_texts, parse_diff, diff_file_unchanged or
// parse_diff_conflicts.
pub struct DiffFile {
pub:
	old_path   string // Empty for an added file (/dev/null).
	new_path   string // Empty for a deleted file.
	status     DiffFileStatus
	binary     bool
	old_mode   string // From Git's `old mode` or `deleted file mode` header.
	new_mode   string // From `new mode` or `new file mode`.
	similarity int = -1 // A rename's or copy's `similarity index`, in percent.
	headers    []string // Git's extended header lines, as the patch wrote them.
	hunks      []DiffHunk
	additions  int
	deletions  int
	// complete files hold every line of both versions (diff_texts and the
	// whole-file constructors), so unchanged lines between changes are all
	// there to reveal. A parsed patch only has the context it carries.
	complete  bool
	conflicts []DiffConflict
}

// path is the path to show and identifies the file: the modified path, or the
// original one for a deleted file.
pub fn (file DiffFile) path() string {
	return if file.new_path.len > 0 { file.new_path } else { file.old_path }
}

// has_source reports whether the file has any source lines to show. A binary
// file, a mode change or a pure rename has none.
pub fn (file DiffFile) has_source() bool {
	for hunk in file.hunks {
		if hunk.lines.len > 0 {
			return true
		}
	}
	return false
}

// single_column reports a file shown in one column in every display mode: a
// reference file and a working file with conflicts have one version only.
pub fn (file DiffFile) single_column() bool {
	return file.status in [.unchanged, .conflicted]
}

// summary describes a file without source lines, in place of its rows.
pub fn (file DiffFile) summary() string {
	if file.binary {
		return match file.status {
			.added { 'Binary file added' }
			.deleted { 'Binary file deleted' }
			else { 'Binary file not shown' }
		}
	}
	if file.status == .renamed {
		return 'File renamed without changes'
	}
	if file.status == .copied {
		return 'File copied without changes'
	}
	if file.old_mode.len > 0 && file.new_mode.len > 0 && file.old_mode != file.new_mode {
		return 'File mode changed from ${file.old_mode} to ${file.new_mode}'
	}
	return match file.status {
		.added { 'Empty file added' }
		.deleted { 'Empty file deleted' }
		else { 'No changes' }
	}
}

// text is the status as a short word for a badge.
pub fn (status DiffFileStatus) text() string {
	return match status {
		.modified { 'Modified' }
		.added { 'Added' }
		.deleted { 'Deleted' }
		.renamed { 'Renamed' }
		.copied { 'Copied' }
		.unchanged { 'Unchanged' }
		.conflicted { 'Conflicted' }
	}
}

// ── Computing a diff ────────────────────────────────────────────────

// DiffEdit is one step of an edit script: keep, remove or add one line.
pub struct DiffEdit {
pub:
	kind      DiffLineKind
	old_index int = -1 // Zero-based index in the original, or -1.
	new_index int = -1 // Zero-based index in the modified version, or -1.
}

// diff_edits returns a shortest edit script turning `old` into `new`, one edit
// per line in patch order: within a change, removals come before additions.
// It is Myers' O(ND) algorithm in linear space. Lines found on one side only
// are set aside first, which costs nothing in quality and makes unrelated
// texts cheap; a sub-problem that needs very many edits is split at the best
// point reached instead of the optimal one, which keeps the time near-linear
// for huge, very different inputs. Changes are then slid to end on a blank
// line where they can, the way most diff tools present them.
pub fn diff_edits(old []string, new []string) []DiffEdit {
	return diff_edits_ending(old, new, false, false)
}

// diff_edits_ending is diff_edits where the last line of a version may lack a
// newline: such a line differs from the same text with one.
fn diff_edits_ending(old []string, new []string, old_open bool, new_open bool) []DiffEdit {
	mut ids := map[string]int{}
	mut blank := []bool{}
	a := diff_intern(old, old_open, mut ids, mut blank)
	b := diff_intern(new, new_open, mut ids, mut blank)
	del, ins := diff_changes(a, b, blank)
	return diff_script(del, ins)
}

fn diff_intern(lines []string, open_end bool, mut ids map[string]int, mut blank []bool) []int {
	mut out := []int{cap: lines.len}
	for i, line in lines {
		// A line never contains a newline, so one marks the unterminated last line.
		key := if open_end && i == lines.len - 1 { line + '\n' } else { line }
		mut id := ids[key] or { -1 }
		if id < 0 {
			id = blank.len
			ids[key] = id
			blank << line.trim_space().len == 0
		}
		out << id
	}
	return out
}

// diff_script turns the change marks of both sequences into edits.
fn diff_script(del []bool, ins []bool) []DiffEdit {
	mut out := []DiffEdit{cap: del.len + ins.len}
	mut i := 0
	mut j := 0
	for i < del.len || j < ins.len {
		if i < del.len && del[i] {
			out << DiffEdit{
				kind:      .removed
				old_index: i
			}
			i++
		} else if j < ins.len && ins[j] {
			out << DiffEdit{
				kind:      .added
				new_index: j
			}
			j++
		} else if i < del.len && j < ins.len {
			out << DiffEdit{
				kind:      .context
				old_index: i
				new_index: j
			}
			i++
			j++
		} else {
			// Unreachable: both sides keep the same number of elements.
			break
		}
	}
	return out
}

// diff_changes marks the elements of a to delete and of b to insert in a
// shortest edit script. blank, indexed by element value, says which values are
// blank lines; pass an empty array to slide changes without that preference.
fn diff_changes(a []int, b []int, blank []bool) ([]bool, []bool) {
	mut del := []bool{len: a.len}
	mut ins := []bool{len: b.len}
	if a.len == 0 || b.len == 0 {
		for i in 0 .. a.len {
			del[i] = true
		}
		for j in 0 .. b.len {
			ins[j] = true
		}
		return del, ins
	}
	// Values found on one side only are changes whatever else happens, and no
	// longest common subsequence uses them, so the search runs without them.
	mut top := 0
	for v in a {
		top = math.max(top, v)
	}
	for v in b {
		top = math.max(top, v)
	}
	mut in_a := []bool{len: top + 1}
	mut in_b := []bool{len: top + 1}
	for v in a {
		in_a[v] = true
	}
	for v in b {
		in_b[v] = true
	}
	mut fa := []int{cap: a.len}
	mut map_a := []int{cap: a.len}
	for i, v in a {
		if in_b[v] {
			fa << v
			map_a << i
		} else {
			del[i] = true
		}
	}
	mut fb := []int{cap: b.len}
	mut map_b := []int{cap: b.len}
	for j, v in b {
		if in_a[v] {
			fb << v
			map_b << j
		} else {
			ins[j] = true
		}
	}
	mut search := DiffSearch{
		a:     fa
		b:     fb
		limit: diff_cost_limit(fa.len + fb.len)
		del:   []bool{len: fa.len}
		ins:   []bool{len: fb.len}
		fwd:   []int{len: fa.len + fb.len + 3}
		bwd:   []int{len: fa.len + fb.len + 3}
		zero:  fb.len + 1
	}
	search.run()
	for i, mark in search.del {
		if mark {
			del[map_a[i]] = true
		}
	}
	for j, mark in search.ins {
		if mark {
			ins[map_b[j]] = true
		}
	}
	diff_slide(a, mut del, blank)
	diff_slide(b, mut ins, blank)
	return del, ins
}

// diff_cost_limit is the number of edits after which a sub-problem stops
// looking for the optimal split: about the square root of its size, and never
// less than 256, so ordinary changes are always optimal.
fn diff_cost_limit(size int) int {
	mut limit := 1
	mut n := size + 3
	for n > 0 {
		n >>= 2
		limit <<= 1
	}
	return math.max(256, limit)
}

// diff_unreached marks a diagonal the backward search has not reached.
const diff_unreached = 2147483647

// DiffSearch is Myers' linear-space search over a and b. fwd and bwd hold the
// furthest x reached on each diagonal k = x - y, stored at zero + k.
struct DiffSearch {
	a     []int
	b     []int
	limit int
mut:
	del  []bool
	ins  []bool
	fwd  []int
	bwd  []int
	zero int
}

struct DiffBox {
	xoff int
	xlim int
	yoff int
	ylim int
}

fn (mut s DiffSearch) run() {
	mut stack := [DiffBox{0, s.a.len, 0, s.b.len}]
	for stack.len > 0 {
		box := stack.pop()
		mut xoff := box.xoff
		mut xlim := box.xlim
		mut yoff := box.yoff
		mut ylim := box.ylim
		for xoff < xlim && yoff < ylim && s.a[xoff] == s.b[yoff] {
			xoff++
			yoff++
		}
		for xlim > xoff && ylim > yoff && s.a[xlim - 1] == s.b[ylim - 1] {
			xlim--
			ylim--
		}
		if xoff == xlim {
			for y in yoff .. ylim {
				s.ins[y] = true
			}
			continue
		}
		if yoff == ylim {
			for x in xoff .. xlim {
				s.del[x] = true
			}
			continue
		}
		x, y := s.split(xoff, xlim, yoff, ylim)
		if (x == xoff && y == yoff) || (x == xlim && y == ylim) {
			// No progress (cannot happen with a correct split): give up on
			// this box rather than loop.
			for i in xoff .. xlim {
				s.del[i] = true
			}
			for j in yoff .. ylim {
				s.ins[j] = true
			}
			continue
		}
		stack << DiffBox{x, xlim, y, ylim}
		stack << DiffBox{xoff, x, yoff, y}
	}
}

// split finds a point on a shortest path through the box, where the forward
// search from its top left meets the backward one from its bottom right, both
// on diagonals inside the box. Past `limit` edits it settles for the point that
// got furthest.
fn (mut s DiffSearch) split(xoff int, xlim int, yoff int, ylim int) (int, int) {
	lo := xoff - ylim
	hi := xlim - yoff
	fmid := xoff - yoff
	bmid := xlim - ylim
	odd := ((fmid - bmid) & 1) != 0
	z := s.zero
	s.fwd[z + fmid] = xoff
	s.bwd[z + bmid] = xlim
	mut fmin := fmid
	mut fmax := fmid
	mut bmin := bmid
	mut bmax := bmid
	unreached := diff_unreached
	for cost := 1; cost <= xlim - xoff + ylim - yoff + 1; cost++ {
		// Forward: every diagonal reached gets one more edit. A diagonal beyond
		// the box's edge is out of reach; its neighbour is fenced off instead.
		if fmin > lo {
			fmin--
			s.fwd[z + fmin - 1] = -1
		} else {
			fmin++
		}
		if fmax < hi {
			fmax++
			s.fwd[z + fmax + 1] = -1
		} else {
			fmax--
		}
		for d := fmax; d >= fmin; d -= 2 {
			left := s.fwd[z + d - 1] // Reached with a deletion from diagonal d - 1.
			up := s.fwd[z + d + 1] // Reached with an insertion from diagonal d + 1.
			mut x := -1
			if left >= 0 && left + 1 <= xlim {
				x = left + 1
			}
			if up >= 0 && up - d <= ylim && up > x {
				x = up
			}
			if x < 0 {
				s.fwd[z + d] = -1
				continue
			}
			mut y := x - d
			for x < xlim && y < ylim && s.a[x] == s.b[y] {
				x++
				y++
			}
			s.fwd[z + d] = x
			if odd && d >= bmin && d <= bmax && s.bwd[z + d] != unreached && s.bwd[z + d] <= x {
				return x, y
			}
		}
		// Backward, from the bottom right corner.
		if bmin > lo {
			bmin--
			s.bwd[z + bmin - 1] = unreached
		} else {
			bmin++
		}
		if bmax < hi {
			bmax++
			s.bwd[z + bmax + 1] = unreached
		} else {
			bmax--
		}
		for d := bmax; d >= bmin; d -= 2 {
			left := s.bwd[z + d - 1] // Undo an insertion: same x, one line up.
			up := s.bwd[z + d + 1] // Undo a deletion: one column left.
			mut x := unreached
			if up != unreached && up - 1 >= xoff {
				x = up - 1
			}
			if left != unreached && left - d >= yoff && left < x {
				x = left
			}
			if x == unreached {
				s.bwd[z + d] = unreached
				continue
			}
			mut y := x - d
			for x > xoff && y > yoff && s.a[x - 1] == s.b[y - 1] {
				x--
				y--
			}
			s.bwd[z + d] = x
			if !odd && d >= fmin && d <= fmax && s.fwd[z + d] >= 0 && x <= s.fwd[z + d] {
				return x, y
			}
		}
		if cost >= s.limit {
			return s.best_split(xoff, xlim, yoff, ylim, fmin, fmax, bmin, bmax)
		}
	}
	return xoff + (xlim - xoff) / 2, yoff + (ylim - yoff) / 2
}

// best_split is the point that got furthest: the forward one with the largest
// x + y or the backward one with the smallest, whichever covers more.
fn (s &DiffSearch) best_split(xoff int, xlim int, yoff int, ylim int, fmin int, fmax int, bmin int, bmax int) (int, int) {
	z := s.zero
	mut fbest := -1
	mut fx := xoff
	for d := fmax; d >= fmin; d -= 2 {
		x := s.fwd[z + d]
		if x < 0 {
			continue
		}
		y := x - d
		if x + y > fbest {
			fbest = x + y
			fx = x
		}
	}
	mut bbest := diff_unreached
	mut bx := xlim
	for d := bmax; d >= bmin; d -= 2 {
		x := s.bwd[z + d]
		if x == diff_unreached {
			continue
		}
		y := x - d
		if x + y < bbest {
			bbest = x + y
			bx = x
		}
	}
	if fbest >= 0 && (bbest == diff_unreached || (xlim + ylim) - bbest < fbest - (xoff + yoff)) {
		return fx, fbest - fx
	}
	if bbest != diff_unreached {
		return bx, bbest - bx
	}
	return xoff + (xlim - xoff) / 2, yoff + (ylim - yoff) / 2
}

// diff_slide moves each run of changed elements as far down as equal values
// allow, then back up to the nearest place where it ends on a blank line, if
// there is one. Both keep the unchanged elements' values in the same order, so
// the script stays a shortest one.
fn diff_slide(values []int, mut marks []bool, blank []bool) {
	n := values.len
	mut i := 0
	for i < n {
		if !marks[i] {
			i++
			continue
		}
		mut start := i
		mut end := i
		for end < n && marks[end] {
			end++
		}
		for end < n && values[start] == values[end] {
			marks[start] = false
			marks[end] = true
			start++
			end++
			for end < n && marks[end] {
				end++
			}
		}
		if blank.len > 0 && !diff_is_blank(values[end - 1], blank) {
			// Look upward for a position ending on a blank line, without
			// touching the run above.
			mut s := start
			mut e := end
			mut found := -1
			for s > 0 && !marks[s - 1] && (s < 2 || !marks[s - 2]) && values[s - 1] == values[e - 1] {
				s--
				e--
				if diff_is_blank(values[e - 1], blank) {
					found = s
					break
				}
			}
			if found >= 0 {
				for k in start .. end {
					marks[k] = false
				}
				for k in found .. found + (end - start) {
					marks[k] = true
				}
			}
		}
		i = end
	}
}

fn diff_is_blank(value int, blank []bool) bool {
	return value >= 0 && value < blank.len && blank[value]
}

// diff_split_lines splits text into lines without their line endings, and
// reports whether the last line has no newline. Empty text has no lines.
pub fn diff_split_lines(text string) ([]string, bool) {
	if text.len == 0 {
		return []string{}, false
	}
	mut lines := text.split('\n')
	open_end := !text.ends_with('\n')
	if !open_end {
		lines.delete_last()
	}
	return lines, open_end
}

// diff_texts compares two versions of a file. old_path or new_path is empty
// for an added or deleted file; different paths make a rename. The result is
// complete: one hunk holding every line, which the view folds to the state's
// context lines and diff_hunks cuts into ordinary unified hunks.
pub fn diff_texts(old_path string, new_path string, old_text string, new_text string) DiffFile {
	old, old_open := diff_split_lines(old_text)
	new, new_open := diff_split_lines(new_text)
	edits := diff_edits_ending(old, new, old_open, new_open)
	mut lines := []DiffLine{cap: edits.len}
	mut additions := 0
	mut deletions := 0
	for edit in edits {
		match edit.kind {
			.context {
				lines << DiffLine{
					kind:       .context
					old_line:   edit.old_index + 1
					new_line:   edit.new_index + 1
					text:       old[edit.old_index]
					no_newline: old_open && edit.old_index == old.len - 1
				}
			}
			.removed {
				deletions++
				lines << DiffLine{
					kind:       .removed
					old_line:   edit.old_index + 1
					text:       old[edit.old_index]
					no_newline: old_open && edit.old_index == old.len - 1
				}
			}
			.added {
				additions++
				lines << DiffLine{
					kind:       .added
					new_line:   edit.new_index + 1
					text:       new[edit.new_index]
					no_newline: new_open && edit.new_index == new.len - 1
				}
			}
		}
	}
	status := if old_path.len == 0 && new_path.len > 0 {
		DiffFileStatus.added
	} else if new_path.len == 0 && old_path.len > 0 {
		DiffFileStatus.deleted
	} else if old_path != new_path {
		DiffFileStatus.renamed
	} else {
		DiffFileStatus.modified
	}
	hunks := if lines.len == 0 {
		[]DiffHunk{}
	} else {
		[
			DiffHunk{
				old_start: if old.len > 0 { 1 } else { 0 }
				old_count: old.len
				new_start: if new.len > 0 { 1 } else { 0 }
				new_count: new.len
				lines:     lines
			},
		]
	}
	return DiffFile{
		old_path:  old_path
		new_path:  new_path
		status:    status
		hunks:     hunks
		additions: additions
		deletions: deletions
		complete:  true
	}
}

// diff_file_unchanged is a whole file shown for reference: every line
// unchanged, never folded, in one column.
pub fn diff_file_unchanged(path string, text string) DiffFile {
	lines, open_end := diff_split_lines(text)
	mut out := []DiffLine{cap: lines.len}
	for i, line in lines {
		out << DiffLine{
			kind:       .context
			old_line:   i + 1
			new_line:   i + 1
			text:       line
			no_newline: open_end && i == lines.len - 1
		}
	}
	return DiffFile{
		old_path: path
		new_path: path
		status:   .unchanged
		hunks:    if out.len == 0 {
			[]DiffHunk{}
		} else {
			[
				DiffHunk{
					old_start: 1
					old_count: out.len
					new_start: 1
					new_count: out.len
					lines:     out
				},
			]
		}
		complete: true
	}
}

// ── Hunks and unified output ────────────────────────────────────────

// diff_hunks cuts the file's lines into unified hunks with `context` unchanged
// lines around each change, as `diff -U<context>` does; changes closer than
// twice that share a hunk. A hunk never gets more context than the file
// supplies. A negative context returns the hunks as they are.
pub fn diff_hunks(file DiffFile, context int) []DiffHunk {
	if context < 0 {
		return file.hunks
	}
	mut out := []DiffHunk{}
	for hunk in file.hunks {
		lines := hunk.lines
		mut i := 0
		for i < lines.len {
			// The next change, and how far its hunk reaches.
			mut first := i
			for first < lines.len && !lines[first].changed() {
				first++
			}
			if first == lines.len {
				break
			}
			start := math.max(i, first - context)
			mut last := first
			mut k := first
			for k < lines.len {
				if lines[k].changed() {
					last = k
					k++
					continue
				}
				// An unchanged run: does another change follow within reach?
				mut next := k
				for next < lines.len && !lines[next].changed() {
					next++
				}
				if next < lines.len && next - k <= 2 * context {
					k = next
					continue
				}
				break
			}
			end := math.min(lines.len, last + 1 + context)
			out << diff_hunk_of(hunk, start, end, file)
			i = end
		}
	}
	return out
}

// diff_hunk_of makes a hunk of lines [start, end) of another hunk.
fn diff_hunk_of(whole DiffHunk, start int, end int, file DiffFile) DiffHunk {
	lines := whole.lines[start..end]
	mut old_count := 0
	mut new_count := 0
	mut old_first := 0
	mut new_first := 0
	for line in lines {
		if line.old_line > 0 {
			old_count++
			if old_first == 0 {
				old_first = line.old_line
			}
		}
		if line.new_line > 0 {
			new_count++
			if new_first == 0 {
				new_first = line.new_line
			}
		}
	}
	// A version with no line here names the line before the change.
	old_start := if old_count > 0 { old_first } else { diff_line_before(whole, start, .original) }
	new_start := if new_count > 0 { new_first } else { diff_line_before(whole, start, .modified) }
	return DiffHunk{
		old_start: old_start
		old_count: old_count
		new_start: new_start
		new_count: new_count
		section:   if file.complete {
			diff_section_before(whole, old_start)
		} else {
			whole.section
		}
		lines:     lines.clone()
	}
}

// diff_line_before is the last line of a version before line `start` of a
// hunk, for the start of a hunk that has none of that version's lines.
fn diff_line_before(whole DiffHunk, start int, side DiffSide) int {
	mut last := if side == .original {
		whole.old_start - if whole.old_count > 0 { 1 } else { 0 }
	} else {
		whole.new_start - if whole.new_count > 0 { 1 } else { 0 }
	}
	for line in whole.lines[..start] {
		n := line.number(side)
		if n > 0 {
			last = n
		}
	}
	return math.max(last, 0)
}

// diff_section_before finds the text Git shows after a hunk's @@: the nearest
// original line above the hunk that starts with a letter, `_` or `$`, Git's
// default function-name rule, cut to 80 bytes.
fn diff_section_before(whole DiffHunk, old_start int) string {
	mut found := ''
	for line in whole.lines {
		if line.old_line <= 0 {
			continue
		}
		if line.old_line >= old_start {
			break
		}
		if line.text.len > 0 {
			c := line.text[0]
			if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || c == `$` {
				found = line.text
			}
		}
	}
	found = found.trim_right(' \t\r')
	if found.len > 80 {
		mut cut := 80
		for cut > 0 && (found[cut] & 0xc0) == 0x80 {
			cut--
		}
		found = found[..cut]
	}
	return found
}

// diff_unified_text writes the file as a Git patch with `context` lines of
// context (negative keeps the hunks as they are), which parse_diff reads back.
pub fn diff_unified_text(file DiffFile, context int) string {
	mut sb := []string{}
	old_name := if file.old_path.len > 0 { file.old_path } else { file.new_path }
	new_name := if file.new_path.len > 0 { file.new_path } else { file.old_path }
	sb << 'diff --git ${diff_quote_path('a/' + old_name)} ${diff_quote_path('b/' + new_name)}'
	if file.status == .added {
		sb << 'new file mode ${if file.new_mode.len > 0 { file.new_mode } else { '100644' }}'
	} else if file.status == .deleted {
		sb << 'deleted file mode ${if file.old_mode.len > 0 { file.old_mode } else { '100644' }}'
	} else if file.old_mode.len > 0 && file.new_mode.len > 0 && file.old_mode != file.new_mode {
		sb << 'old mode ${file.old_mode}'
		sb << 'new mode ${file.new_mode}'
	}
	if file.status in [.renamed, .copied] {
		word := if file.status == .renamed { 'rename' } else { 'copy' }
		if file.similarity >= 0 {
			sb << 'similarity index ${file.similarity}%'
		}
		sb << '${word} from ${diff_quote_path(file.old_path)}'
		sb << '${word} to ${diff_quote_path(file.new_path)}'
	}
	if file.binary {
		sb << 'Binary files ${if file.old_path.len > 0 {
			diff_quote_path('a/' + file.old_path)
		} else {
			'/dev/null'
		}} and ${if file.new_path.len > 0 {
			diff_quote_path('b/' + file.new_path)
		} else {
			'/dev/null'
		}} differ'
		return sb.join('\n') + '\n'
	}
	hunks := diff_hunks(file, context)
	if hunks.len > 0 {
		sb << '--- ${if file.old_path.len > 0 {
			diff_quote_path('a/' + file.old_path)
		} else {
			'/dev/null'
		}}'
		sb << '+++ ${if file.new_path.len > 0 {
			diff_quote_path('b/' + file.new_path)
		} else {
			'/dev/null'
		}}'
	}
	for hunk in hunks {
		sb << hunk.header()
		for line in hunk.lines {
			prefix := match line.kind {
				.context { ' ' }
				.removed { '-' }
				.added { '+' }
			}
			sb << prefix + line.text
			if line.no_newline {
				sb << '\\ No newline at end of file'
			}
		}
	}
	return sb.join('\n') + '\n'
}

// diff_quote_path quotes a path the way Git does when it has a quote, a
// backslash, a control character or a byte outside ASCII.
fn diff_quote_path(path string) string {
	mut needs := false
	for c in path.bytes() {
		if c < 0x20 || c >= 0x7f || c == `"` || c == `\\` {
			needs = true
			break
		}
	}
	if !needs {
		return path
	}
	mut out := []u8{cap: path.len + 8}
	out << `"`
	for c in path.bytes() {
		match c {
			`"`, `\\` {
				out << `\\`
				out << c
			}
			`\n` {
				out << `\\`
				out << `n`
			}
			`\t` {
				out << `\\`
				out << `t`
			}
			`\r` {
				out << `\\`
				out << `r`
			}
			else {
				if c < 0x20 || c >= 0x7f {
					out << `\\`
					out << `0` + ((c >> 6) & 7)
					out << `0` + ((c >> 3) & 7)
					out << `0` + (c & 7)
				} else {
					out << c
				}
			}
		}
	}
	out << `"`
	return out.bytestr()
}

// ── Inline emphasis ─────────────────────────────────────────────────

pub enum DiffInlineUnit {
	none      // Emphasize whole lines only.
	word      // Words, runs of spaces and single punctuation marks.
	character // Single characters.
}

// DiffInlineRange is a span of changed text in a line, in runes [start, end).
pub struct DiffInlineRange {
pub:
	start int
	end   int
}

// diff_inline_min_similarity is how much of a changed pair must be unchanged
// for inline emphasis to be shown: marking nearly every word only adds noise.
const diff_inline_min_similarity = 0.5

// diff_inline_ranges compares a removed line with the added line paired with
// it and returns the spans that differ on each side, in runes. Both are empty
// when the unit is none, the lines are equal, or they have too little in
// common for emphasis to help.
pub fn diff_inline_ranges(old_text string, new_text string, unit DiffInlineUnit) ([]DiffInlineRange, []DiffInlineRange) {
	if unit == .none || old_text == new_text {
		return []DiffInlineRange{}, []DiffInlineRange{}
	}
	a_tokens := diff_tokens(old_text, unit)
	b_tokens := diff_tokens(new_text, unit)
	mut ids := map[string]int{}
	mut a := []int{cap: a_tokens.len}
	mut b := []int{cap: b_tokens.len}
	for token in a_tokens {
		a << diff_token_id(token.text, mut ids)
	}
	for token in b_tokens {
		b << diff_token_id(token.text, mut ids)
	}
	del, ins := diff_changes(a, b, []bool{})
	mut kept := 0
	mut total := 0
	for i, token in a_tokens {
		total += token.runes
		if !del[i] {
			kept += token.runes
		}
	}
	for j, token in b_tokens {
		total += token.runes
		if !ins[j] {
			kept += token.runes
		}
	}
	if total == 0 || f64(kept) / f64(total) < diff_inline_min_similarity {
		return []DiffInlineRange{}, []DiffInlineRange{}
	}
	return diff_token_ranges(a_tokens, del), diff_token_ranges(b_tokens, ins)
}

struct DiffToken {
	text  string
	runes int
	space bool
}

fn diff_token_id(text string, mut ids map[string]int) int {
	if id := ids[text] {
		return id
	}
	id := ids.len
	ids[text] = id
	return id
}

fn diff_word_rune(r rune) bool {
	return (r >= `a` && r <= `z`) || (r >= `A` && r <= `Z`) || (r >= `0` && r <= `9`) || r == `_`
		|| r >= 0x80
}

fn diff_space_rune(r rune) bool {
	return r == ` ` || r == `\t`
}

fn diff_tokens(text string, unit DiffInlineUnit) []DiffToken {
	runes := text.runes()
	mut out := []DiffToken{cap: runes.len}
	if unit == .character {
		for r in runes {
			out << DiffToken{
				text:  r.str()
				runes: 1
				space: diff_space_rune(r)
			}
		}
		return out
	}
	mut i := 0
	for i < runes.len {
		r := runes[i]
		mut j := i + 1
		if diff_word_rune(r) {
			for j < runes.len && diff_word_rune(runes[j]) {
				j++
			}
		} else if diff_space_rune(r) {
			for j < runes.len && diff_space_rune(runes[j]) {
				j++
			}
		}
		out << DiffToken{
			text:  runes[i..j].string()
			runes: j - i
			space: diff_space_rune(r)
		}
		i = j
	}
	return out
}

// diff_token_ranges joins marked tokens into rune ranges. Changed words with
// only spaces between them make one range, which reads as one change.
fn diff_token_ranges(tokens []DiffToken, marks []bool) []DiffInlineRange {
	mut out := []DiffInlineRange{}
	mut offset := 0
	mut i := 0
	for i < tokens.len {
		if !marks[i] {
			offset += tokens[i].runes
			i++
			continue
		}
		start := offset
		for i < tokens.len {
			if marks[i] {
				offset += tokens[i].runes
				i++
				continue
			}
			if tokens[i].space && i + 1 < tokens.len && marks[i + 1] {
				offset += tokens[i].runes
				i++
				continue
			}
			break
		}
		out << DiffInlineRange{start, offset}
	}
	return out
}
