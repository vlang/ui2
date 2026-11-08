module ui2

import math

// DiffState: the controlled state of a diff view, after GPUI Kit's DiffState.
// The application keeps one, passes it to diff_view, and changes it with its
// methods or with apply(event) for what the view emits. It owns the files, the
// display mode, context folding, collapsed files, the line selection, conflict
// resolutions and annotations, and caches the rows they produce, so a build
// costs the same for ten lines or a hundred thousand.

pub enum DiffMode {
	unified // Removed lines above added ones, with both line numbers.
	split   // The original on the left, the modified version on the right.
}

// DiffLinePosition names a source line: a file by its path, a version and a
// one-based line number. Display modes and folding never renumber it.
pub struct DiffLinePosition {
pub:
	path string
	side DiffSide = .modified
	line int
}

// DiffLineRange is an inclusive range of source lines of one file. It stays on
// one side unless `crosses`: then it starts on `side` and ends on the other,
// covering the patch body between the two lines, as Unified mode shows it.
pub struct DiffLineRange {
pub:
	path    string
	side    DiffSide = .modified
	start   int
	end     int
	crosses bool
}

// end_side is the version the range's last line is in.
pub fn (range DiffLineRange) end_side() DiffSide {
	return if range.crosses { range.side.other() } else { range.side }
}

// DiffCopyFormat is what copying a selection produces.
pub enum DiffCopyFormat {
	source   // The selected lines, as the selection's side has them.
	original // The original version of the span selected.
	modified // The modified version of the span selected.
	patch    // The span as unified-diff lines, with their +, - and space prefixes.
}

// DiffAnnotation is an application note attached to a source line, drawn under
// it, or to a whole file (line 0), drawn under its header. Keep comment threads
// and drafts in the application; the id is stable and unique.
pub struct DiffAnnotation {
pub:
	id     string
	path   string
	side   DiffSide = .modified
	line   int // One-based; 0 for the whole file.
	title  string
	text   string
	tone   ComponentTone = .primary
	height f64 // 0 sizes the card to its text; set it when render_annotation draws something else.
}

pub enum DiffRowKind {
	file_header
	file_summary // In place of the rows of a file without source: binary, a mode change, a pure rename.
	hunk         // A patch hunk's separator.
	fold         // Hidden unchanged lines, with buttons to reveal them.
	line         // Source: one line in Unified mode, a pair in Split mode.
	conflict     // A heading over a conflict part, or over a resolved conflict.
	annotation
}

pub enum DiffConflictPart {
	ours
	base
	theirs
	resolved
}

// DiffRow is one row of the view. Line indices are into the lines of hunk
// `hunk` of file `file`: `old` is shown on the original side and `new` on the
// modified side (the same index for an unchanged line, -1 for none), and in
// Unified mode `pair` is the changed line the row's line is compared with.
pub struct DiffRow {
pub:
	kind       DiffRowKind
	file       int
	hunk       int = -1
	old        int = -1
	new        int = -1
	pair       int = -1
	fold_start int // A fold hides lines [fold_start, fold_end) of its hunk.
	fold_end   int
	run        int = -1 // A fold's unchanged run starts here; it names the fold.
	above      bool // Source shows just above the fold, so lines can be revealed below it.
	below      bool // Source shows just below the fold.
	conflict   int = -1
	part       DiffConflictPart
	annotation int = -1
}

// DiffRevealEdge is which hidden lines of a fold to show.
pub enum DiffRevealEdge {
	top    // The lines just below the source above the fold.
	bottom // The lines just above the source below it.
	all
}

struct DiffReveal {
	top    int
	bottom int
	all    bool
}

// DiffStateOptions are a new state's settings; each has a setter too.
@[params]
pub struct DiffStateOptions {
pub:
	mode DiffMode
	// context_lines unchanged lines stay around each change; the rest fold away.
	// -1 shows every supplied line.
	context_lines          int            = 3
	expansion_lines        int            = 20 // Lines one reveal step shows.
	min_collapsed_lines    int            = 2  // Shorter unchanged ranges stay visible.
	inline_unit            DiffInlineUnit = .word
	inline_max_line_length int            = 1000 // Longer lines get no inline emphasis.
}

pub struct DiffState {
mut:
	files               []DiffFile
	mode                DiffMode
	context_lines       int            = 3
	expansion_lines     int            = 20
	min_collapsed_lines int            = 2
	inline_unit         DiffInlineUnit = .word
	inline_max          int            = 1000
	expanded            bool
	collapsed           map[string]bool
	reveals             map[string]DiffReveal
	has_selection       bool
	selection           DiffLineRange
	anchor              DiffLinePosition
	resolutions         map[string]DiffConflictResolution
	annotations         []DiffAnnotation
	current             int = -1
	rows                []DiffRow
	file_rows           []int
	columns             [][]int // Per file: the widest original and modified lines, in columns.
	max_line            int
}

// diff_state makes the state for some files.
pub fn diff_state(files []DiffFile, options DiffStateOptions) DiffState {
	mut s := DiffState{
		mode:                options.mode
		context_lines:       math.max(-1, options.context_lines)
		expansion_lines:     math.max(1, options.expansion_lines)
		min_collapsed_lines: math.max(1, options.min_collapsed_lines)
		inline_unit:         options.inline_unit
		inline_max:          math.max(0, options.inline_max_line_length)
	}
	s.set_files(files)
	return s
}

// ── Files ───────────────────────────────────────────────────────────

pub fn (s &DiffState) files() []DiffFile {
	return s.files
}

// set_files installs a new revision. It resets revealed lines, the selection
// and conflict resolutions, whose coordinates belong to the old files, but a
// file collapsed before stays collapsed when its path is still there.
pub fn (mut s DiffState) set_files(files []DiffFile) {
	s.files = files
	s.reveals = map[string]DiffReveal{}
	s.resolutions = map[string]DiffConflictResolution{}
	s.has_selection = false
	s.selection = DiffLineRange{}
	s.anchor = DiffLinePosition{}
	mut paths := map[string]bool{}
	for file in files {
		paths[file.path()] = true
	}
	for path in s.collapsed.keys() {
		if path !in paths {
			s.collapsed.delete(path)
		}
	}
	s.columns = [][]int{cap: files.len}
	s.max_line = 0
	for file in files {
		mut widest := [0, 0]
		for hunk in file.hunks {
			for line in hunk.lines {
				cols := diff_display_columns(line.text)
				if line.old_line > 0 {
					widest[0] = math.max(widest[0], cols)
				}
				if line.new_line > 0 {
					widest[1] = math.max(widest[1], cols)
				}
				s.max_line = math.max(s.max_line, math.max(line.old_line, line.new_line))
			}
		}
		s.columns << widest
	}
	s.rebuild()
}

// file_index is the index of the file with a path, or none.
pub fn (s &DiffState) file_index(path string) ?int {
	for i, file in s.files {
		if file.path() == path {
			return i
		}
	}
	return none
}

pub fn (s &DiffState) mode() DiffMode {
	return s.mode
}

pub fn (mut s DiffState) set_mode(mode DiffMode) {
	if s.mode != mode {
		s.mode = mode
		s.rebuild()
	}
}

pub fn (s &DiffState) context_lines() int {
	return s.context_lines
}

// set_context_lines sets how many unchanged lines stay around each change;
// -1 shows every supplied line.
pub fn (mut s DiffState) set_context_lines(lines int) {
	value := math.max(-1, lines)
	if s.context_lines != value {
		s.context_lines = value
		s.rebuild()
	}
}

pub fn (s &DiffState) expansion_lines() int {
	return s.expansion_lines
}

pub fn (mut s DiffState) set_expansion_lines(lines int) {
	s.expansion_lines = math.max(1, lines)
}

pub fn (s &DiffState) min_collapsed_lines() int {
	return s.min_collapsed_lines
}

pub fn (mut s DiffState) set_min_collapsed_lines(lines int) {
	value := math.max(1, lines)
	if s.min_collapsed_lines != value {
		s.min_collapsed_lines = value
		s.rebuild()
	}
}

pub fn (s &DiffState) inline_unit() DiffInlineUnit {
	return s.inline_unit
}

pub fn (mut s DiffState) set_inline_unit(unit DiffInlineUnit) {
	s.inline_unit = unit
}

pub fn (s &DiffState) inline_max_line_length() int {
	return s.inline_max
}

pub fn (mut s DiffState) set_inline_max_line_length(length int) {
	s.inline_max = math.max(0, length)
}

// expand_unchanged shows every supplied unchanged line without changing the
// context setting; collapse_unchanged folds them again and forgets reveals.
pub fn (mut s DiffState) expand_unchanged() {
	if !s.expanded {
		s.expanded = true
		s.rebuild()
	}
}

pub fn (mut s DiffState) collapse_unchanged() {
	s.expanded = false
	s.reveals = map[string]DiffReveal{}
	s.rebuild()
}

pub fn (s &DiffState) unchanged_expanded() bool {
	return s.expanded
}

pub fn (s &DiffState) is_file_collapsed(path string) bool {
	return s.collapsed[path]
}

// set_file_collapsed shows only a file's header, or all of it again.
pub fn (mut s DiffState) set_file_collapsed(path string, collapsed bool) {
	if s.collapsed[path] == collapsed {
		return
	}
	if collapsed {
		s.collapsed[path] = true
	} else {
		s.collapsed.delete(path)
	}
	s.rebuild()
}

pub fn (s &DiffState) annotations() []DiffAnnotation {
	return s.annotations
}

// set_annotations replaces the annotations. One on a hidden line shows when
// the line is revealed; one on a line that is not in the file never shows.
pub fn (mut s DiffState) set_annotations(annotations []DiffAnnotation) {
	s.annotations = annotations
	s.rebuild()
}

// rows are the view's rows, rebuilt whenever something they depend on changes.
pub fn (s &DiffState) rows() []DiffRow {
	return s.rows
}

// file_row is the header row of a file.
pub fn (s &DiffState) file_row(path string) ?int {
	fi := s.file_index(path)?
	return s.file_rows[fi]
}

// current_row is the change or hunk navigation last went to, which the view
// marks; -1 for none. Any change to the rows clears it.
pub fn (s &DiffState) current_row() int {
	return s.current
}

pub fn (mut s DiffState) set_current_row(row int) {
	s.current = if row >= 0 && row < s.rows.len { row } else { -1 }
}

// ── Rows ────────────────────────────────────────────────────────────

fn diff_fold_key(path string, hunk int, run int) string {
	return '${path}\n${hunk}\n${run}'
}

fn diff_conflict_key(path string, ix int) string {
	return '${path}\n${ix}'
}

enum DiffSegmentKind {
	run      // Unchanged lines.
	change   // Removed and added lines.
	conflict // A conflict region.
}

struct DiffSegment {
	kind     DiffSegmentKind
	start    int
	end      int
	conflict int = -1
}

// diff_hunk_segments splits a hunk into unchanged runs, changes and conflict
// regions, in order. A run starts and ends at a change, a conflict or the
// hunk's edge, and its start names it.
fn diff_hunk_segments(file DiffFile, hi int) []DiffSegment {
	lines := file.hunks[hi].lines
	mut regions := []int{}
	for ci, c in file.conflicts {
		if c.hunk == hi {
			regions << ci
		}
	}
	mut out := []DiffSegment{}
	mut next := 0
	mut i := 0
	for i < lines.len {
		if next < regions.len && file.conflicts[regions[next]].start <= i {
			ci := regions[next]
			out << DiffSegment{
				kind:     .conflict
				start:    i
				end:      math.max(i + 1, file.conflicts[ci].end)
				conflict: ci
			}
			i = math.max(i + 1, file.conflicts[ci].end)
			next++
			continue
		}
		limit := if next < regions.len { file.conflicts[regions[next]].start } else { lines.len }
		context := lines[i].kind == .context
		mut j := i + 1
		for j < limit && (lines[j].kind == .context) == context {
			j++
		}
		out << DiffSegment{
			kind:  if context { DiffSegmentKind.run } else { DiffSegmentKind.change }
			start: i
			end:   j
		}
		i = j
	}
	return out
}

fn (mut s DiffState) rebuild() {
	mut rows := []DiffRow{cap: 64}
	mut file_rows := []int{cap: s.files.len}
	for fi, file in s.files {
		file_rows << rows.len
		rows << DiffRow{
			kind: .file_header
			file: fi
		}
		path := file.path()
		if s.collapsed[path] {
			continue
		}
		mut notes := map[string][]int{}
		for ai, note in s.annotations {
			if note.path != path {
				continue
			}
			if note.line <= 0 {
				rows << DiffRow{
					kind:       .annotation
					file:       fi
					annotation: ai
				}
				continue
			}
			key := diff_note_key(note.side, note.line)
			notes[key] << ai
		}
		if !file.has_source() {
			rows << DiffRow{
				kind: .file_summary
				file: fi
			}
			continue
		}
		for hi, hunk in file.hunks {
			if hunk.lines.len == 0 {
				continue
			}
			if !file.complete {
				rows << DiffRow{
					kind: .hunk
					file: fi
					hunk: hi
				}
			}
			for segment in diff_hunk_segments(file, hi) {
				match segment.kind {
					.run { s.emit_run(mut rows, fi, file, hi, segment, notes) }
					.change { s.emit_change(mut rows, fi, file, hi, segment, notes) }
					.conflict { s.emit_conflict(mut rows, fi, file, segment.conflict, notes) }
				}
			}
		}
	}
	s.rows = rows
	s.file_rows = file_rows
	s.current = -1
}

fn diff_note_key(side DiffSide, line int) string {
	return if side == .original { 'o${line}' } else { 'm${line}' }
}

fn diff_emit_notes(mut rows []DiffRow, fi int, line DiffLine, sides []DiffSide, notes map[string][]int) {
	for side in sides {
		n := line.number(side)
		if n <= 0 {
			continue
		}
		for ai in notes[diff_note_key(side, n)] {
			rows << DiffRow{
				kind:       .annotation
				file:       fi
				annotation: ai
			}
		}
	}
}

fn (s &DiffState) emit_context(mut rows []DiffRow, fi int, file DiffFile, hi int, start int, end int, notes map[string][]int) {
	lines := file.hunks[hi].lines
	for k in start .. end {
		rows << DiffRow{
			kind: .line
			file: fi
			hunk: hi
			old:  k
			new:  k
		}
		diff_emit_notes(mut rows, fi, lines[k], [DiffSide.original, .modified], notes)
	}
}

fn (s &DiffState) emit_run(mut rows []DiffRow, fi int, file DiffFile, hi int, segment DiffSegment, notes map[string][]int) {
	lines := file.hunks[hi].lines
	i := segment.start
	j := segment.end
	has_before := i > 0
	has_after := j < lines.len
	ctx := s.context_lines
	if ctx >= 0 && !s.expanded && file.status != .unchanged {
		keep_top := if has_before { ctx } else { 0 }
		keep_bottom := if has_after { ctx } else { 0 }
		fold_start := i + keep_top
		fold_end := j - keep_bottom
		least := math.max(1, s.min_collapsed_lines)
		if fold_end - fold_start >= least {
			reveal := s.reveals[diff_fold_key(file.path(), hi, i)] or { DiffReveal{} }
			if !reveal.all {
				hidden_start := fold_start + reveal.top
				hidden_end := fold_end - reveal.bottom
				if hidden_end - hidden_start >= least {
					s.emit_context(mut rows, fi, file, hi, i, hidden_start, notes)
					rows << DiffRow{
						kind:       .fold
						file:       fi
						hunk:       hi
						fold_start: hidden_start
						fold_end:   hidden_end
						run:        i
						above:      hidden_start > i || has_before
						below:      hidden_end < j || has_after
					}
					s.emit_context(mut rows, fi, file, hi, hidden_end, j, notes)
					return
				}
			}
		}
	}
	s.emit_context(mut rows, fi, file, hi, i, j, notes)
}

fn (s &DiffState) emit_change(mut rows []DiffRow, fi int, file DiffFile, hi int, segment DiffSegment, notes map[string][]int) {
	lines := file.hunks[hi].lines
	mut removed := []int{}
	mut added := []int{}
	for k in segment.start .. segment.end {
		if lines[k].kind == .removed {
			removed << k
		} else {
			added << k
		}
	}
	if s.mode == .split && !file.single_column() {
		for p in 0 .. math.max(removed.len, added.len) {
			o := if p < removed.len { removed[p] } else { -1 }
			a := if p < added.len { added[p] } else { -1 }
			rows << DiffRow{
				kind: .line
				file: fi
				hunk: hi
				old:  o
				new:  a
			}
			if o >= 0 {
				diff_emit_notes(mut rows, fi, lines[o], [DiffSide.original], notes)
			}
			if a >= 0 {
				diff_emit_notes(mut rows, fi, lines[a], [DiffSide.modified], notes)
			}
		}
		return
	}
	for p, k in removed {
		rows << DiffRow{
			kind: .line
			file: fi
			hunk: hi
			old:  k
			pair: if p < added.len { added[p] } else { -1 }
		}
		diff_emit_notes(mut rows, fi, lines[k], [DiffSide.original], notes)
	}
	for p, k in added {
		rows << DiffRow{
			kind: .line
			file: fi
			hunk: hi
			new:  k
			pair: if p < removed.len { removed[p] } else { -1 }
		}
		diff_emit_notes(mut rows, fi, lines[k], [DiffSide.modified], notes)
	}
}

fn (s &DiffState) emit_conflict(mut rows []DiffRow, fi int, file DiffFile, ci int, notes map[string][]int) {
	c := file.conflicts[ci]
	lines := file.hunks[c.hunk].lines
	// Removed lines a patch interleaves are not in the working file: they come first.
	for k in c.start .. c.end {
		if lines[k].kind == .removed {
			rows << DiffRow{
				kind: .line
				file: fi
				hunk: c.hunk
				old:  k
			}
			diff_emit_notes(mut rows, fi, lines[k], [DiffSide.original], notes)
		}
	}
	mut parts := [][]int{}
	mut kinds := []DiffConflictPart{}
	if resolution := s.resolutions[diff_conflict_key(file.path(), ci)] {
		rows << DiffRow{
			kind:     .conflict
			file:     fi
			hunk:     c.hunk
			conflict: ci
			part:     .resolved
		}
		if resolution in [.ours, .both] {
			parts << [c.ours_start, c.ours_end]
			kinds << .resolved
		}
		if resolution in [.theirs, .both] {
			parts << [c.theirs_start, c.theirs_end]
			kinds << .resolved
		}
	} else {
		parts << [c.ours_start, c.ours_end]
		kinds << .ours
		if c.has_base() {
			parts << [c.base_start, c.base_end]
			kinds << .base
		}
		parts << [c.theirs_start, c.theirs_end]
		kinds << .theirs
	}
	for p, span in parts {
		part := kinds[p]
		if part != .resolved {
			rows << DiffRow{
				kind:     .conflict
				file:     fi
				hunk:     c.hunk
				conflict: ci
				part:     part
			}
		}
		for k in span[0] .. span[1] {
			if lines[k].kind == .removed {
				continue
			}
			rows << DiffRow{
				kind:     .line
				file:     fi
				hunk:     c.hunk
				new:      k
				conflict: ci
				part:     part
			}
			diff_emit_notes(mut rows, fi, lines[k], [DiffSide.modified], notes)
		}
	}
}

// ── Source coordinates ──────────────────────────────────────────────

// row_line returns the line a row shows on a side, if it shows one there.
pub fn (s &DiffState) row_line(row int, side DiffSide) ?DiffLine {
	if row < 0 || row >= s.rows.len {
		return none
	}
	r := s.rows[row]
	if r.kind != .line {
		return none
	}
	k := if side == .original { r.old } else { r.new }
	if k < 0 {
		return none
	}
	line := s.files[r.file].hunks[r.hunk].lines[k]
	if line.number(side) <= 0 {
		return none
	}
	return line
}

// row_position maps a row to the source line it shows on a side.
pub fn (s &DiffState) row_position(row int, side DiffSide) ?DiffLinePosition {
	line := s.row_line(row, side)?
	return DiffLinePosition{
		path: s.files[s.rows[row].file].path()
		side: side
		line: line.number(side)
	}
}

// row_for_line maps a source line back to its row; none while it is folded
// away, its file is collapsed, or the patch does not have it.
pub fn (s &DiffState) row_for_line(position DiffLinePosition) ?int {
	fi := s.file_index(position.path)?
	start := s.file_rows[fi]
	end := if fi + 1 < s.file_rows.len { s.file_rows[fi + 1] } else { s.rows.len }
	for r in start .. end {
		row := s.rows[r]
		if row.kind != .line {
			continue
		}
		k := if position.side == .original { row.old } else { row.new }
		if k >= 0 && s.files[fi].hunks[row.hunk].lines[k].number(position.side) == position.line {
			return r
		}
	}
	return none
}

// reveal_line makes a source line visible, expanding its collapsed file and
// revealing the fold around it, and returns its row. It cannot show a line the
// patch does not have.
pub fn (mut s DiffState) reveal_line(position DiffLinePosition) ?int {
	fi := s.file_index(position.path)?
	file := s.files[fi]
	mut hi := -1
	mut k := -1
	for h, hunk in file.hunks {
		for idx, line in hunk.lines {
			if line.number(position.side) == position.line {
				hi = h
				k = idx
				break
			}
		}
		if hi >= 0 {
			break
		}
	}
	if hi < 0 {
		return none
	}
	mut changed := false
	if s.collapsed[file.path()] {
		s.collapsed.delete(file.path())
		changed = true
	}
	for segment in diff_hunk_segments(file, hi) {
		if segment.kind == .run && k >= segment.start && k < segment.end {
			key := diff_fold_key(file.path(), hi, segment.start)
			s.reveals[key] = DiffReveal{
				all: true
			}
			changed = true
		}
	}
	if changed {
		s.rebuild()
	}
	return s.row_for_line(position)
}

// reveal shows hidden lines of the fold at a row: expansion_lines more at an
// edge, or all of them.
pub fn (mut s DiffState) reveal(row int, edge DiffRevealEdge) bool {
	if row < 0 || row >= s.rows.len || s.rows[row].kind != .fold {
		return false
	}
	r := s.rows[row]
	key := diff_fold_key(s.files[r.file].path(), r.hunk, r.run)
	old := s.reveals[key] or { DiffReveal{} }
	s.reveals[key] = match edge {
		.top {
			DiffReveal{
				...old
				top: old.top + s.expansion_lines
			}
		}
		.bottom {
			DiffReveal{
				...old
				bottom: old.bottom + s.expansion_lines
			}
		}
		.all {
			DiffReveal{
				...old
				all: true
			}
		}
	}
	s.rebuild()
	return true
}

// ── Navigation ──────────────────────────────────────────────────────

// row_changed reports a row that is part of a change: a removed or added line,
// or an unresolved conflict.
pub fn (s &DiffState) row_changed(row int) bool {
	if row < 0 || row >= s.rows.len {
		return false
	}
	return s.row_is_change(s.rows[row])
}

fn (s &DiffState) row_is_change(row DiffRow) bool {
	match row.kind {
		.conflict {
			return row.part != .resolved
		}
		.line {
			if row.conflict >= 0 && row.part != .resolved {
				return true
			}
			lines := s.files[row.file].hunks[row.hunk].lines
			return (row.old >= 0 && lines[row.old].kind != .context)
				|| (row.new >= 0 && lines[row.new].kind != .context)
		}
		else {
			return false
		}
	}
}

// change_rows are the first rows of each group of changed rows, in order.
pub fn (s &DiffState) change_rows() []int {
	mut out := []int{}
	mut inside := false
	for r, row in s.rows {
		if row.kind == .annotation {
			continue
		}
		if s.row_is_change(row) {
			if !inside {
				out << r
			}
			inside = true
		} else {
			inside = false
		}
	}
	return out
}

// hunk_rows are where hunks start: a patch's hunk separators, and in a
// complete file each run of shown lines with a change, between folds.
pub fn (s &DiffState) hunk_rows() []int {
	mut out := []int{}
	mut start := -1
	mut counted := false
	for r, row in s.rows {
		match row.kind {
			.hunk {
				out << r
				start = r
				counted = true
			}
			.line, .conflict {
				if start < 0 {
					start = r
					counted = false
				}
				if !counted && s.files[row.file].complete && s.row_is_change(row) {
					out << start
					counted = true
				}
			}
			.annotation {}
			else {
				start = -1
				counted = false
			}
		}
	}
	return out
}

fn diff_next_in(list []int, from int) ?int {
	if list.len == 0 {
		return none
	}
	for r in list {
		if r > from {
			return r
		}
	}
	return list[0]
}

fn diff_previous_in(list []int, from int) ?int {
	if list.len == 0 {
		return none
	}
	for i := list.len - 1; i >= 0; i-- {
		if list[i] < from {
			return list[i]
		}
	}
	return list.last()
}

// next_change is the first change after row `from` across all files, wrapping
// to the first one; previous_change goes the other way. None without changes.
pub fn (s &DiffState) next_change(from int) ?int {
	return diff_next_in(s.change_rows(), from)
}

pub fn (s &DiffState) previous_change(from int) ?int {
	return diff_previous_in(s.change_rows(), from)
}

pub fn (s &DiffState) next_hunk(from int) ?int {
	return diff_next_in(s.hunk_rows(), from)
}

pub fn (s &DiffState) previous_hunk(from int) ?int {
	return diff_previous_in(s.hunk_rows(), from)
}

// ── Selection ───────────────────────────────────────────────────────

// diff_patch_position is the index, counting every line of every hunk in
// patch order, of the line numbered n on a side.
fn diff_patch_position(file DiffFile, side DiffSide, n int) ?int {
	mut pos := 0
	for hunk in file.hunks {
		for line in hunk.lines {
			if line.number(side) == n {
				return pos
			}
			pos++
		}
	}
	return none
}

// diff_side_lines lists the line numbers a file has on a side, in order.
fn diff_side_lines(file DiffFile, side DiffSide) []int {
	mut out := []int{}
	for hunk in file.hunks {
		for line in hunk.lines {
			n := line.number(side)
			if n > 0 {
				out << n
			}
		}
	}
	return out
}

pub fn (s &DiffState) selected_lines() ?DiffLineRange {
	if s.has_selection {
		return s.selection
	}
	return none
}

// set_selected_lines selects source lines, clipped to the lines the file has;
// a range with none of them clears the selection.
pub fn (mut s DiffState) set_selected_lines(range DiffLineRange) {
	clipped := s.clip_range(range) or {
		s.clear_selection()
		return
	}
	s.selection = clipped
	s.has_selection = true
	s.anchor = DiffLinePosition{clipped.path, clipped.side, clipped.start}
}

pub fn (mut s DiffState) clear_selection() {
	s.has_selection = false
	s.selection = DiffLineRange{}
	s.anchor = DiffLinePosition{}
}

fn (s &DiffState) clip_range(range DiffLineRange) ?DiffLineRange {
	fi := s.file_index(range.path)?
	file := s.files[fi]
	if range.crosses {
		start := diff_patch_position(file, range.side, range.start)?
		end := diff_patch_position(file, range.side.other(), range.end)?
		if end < start {
			return DiffLineRange{
				path:    range.path
				side:    range.side.other()
				start:   range.end
				end:     range.start
				crosses: true
			}
		}
		return range
	}
	lo := math.min(range.start, range.end)
	hi := math.max(range.start, range.end)
	mut first := 0
	mut last := 0
	for n in diff_side_lines(file, range.side) {
		if n >= lo && n <= hi {
			if first == 0 || n < first {
				first = n
			}
			last = math.max(last, n)
		}
	}
	if first == 0 {
		return none
	}
	return DiffLineRange{
		path:  range.path
		side:  range.side
		start: first
		end:   last
	}
}

// selection_span is the selected file and the first and last patch positions
// the selection covers.
fn (s &DiffState) selection_span() ?(int, int, int) {
	if !s.has_selection {
		return none
	}
	r := s.selection
	fi := s.file_index(r.path)?
	file := s.files[fi]
	first := diff_patch_position(file, r.side, r.start)?
	last := diff_patch_position(file, r.end_side(), r.end)?
	return fi, first, last
}

// selected_text is the selection's source as a format asks, one line per
// line, without line numbers, markers or annotations.
pub fn (s &DiffState) selected_text(format DiffCopyFormat) string {
	fi, first, last := s.selection_span() or { return '' }
	file := s.files[fi]
	r := s.selection
	mut out := []string{}
	mut pos := 0
	for hunk in file.hunks {
		for line in hunk.lines {
			if pos >= first && pos <= last {
				match format {
					.source {
						if r.crosses || line.number(r.side) > 0 {
							out << line.text
						}
					}
					.original {
						if line.old_line > 0 {
							out << line.text
						}
					}
					.modified {
						if line.new_line > 0 {
							out << line.text
						}
					}
					.patch {
						prefix := match line.kind {
							.context { ' ' }
							.removed { '-' }
							.added { '+' }
						}
						out << prefix + line.text
						if line.no_newline {
							out << '\\ No newline at end of file'
						}
					}
				}
			}
			pos++
		}
	}
	if out.len == 0 {
		return ''
	}
	return out.join('\n') + '\n'
}

// selection_contains reports whether the selection covers a line shown on a
// side of a file, for drawing it.
fn (s &DiffState) selection_contains(line DiffLine, side DiffSide, pos int, span_first int, span_last int) bool {
	if !s.has_selection {
		return false
	}
	r := s.selection
	if r.crosses {
		return pos >= span_first && pos <= span_last
	}
	if side != r.side {
		return false
	}
	n := line.number(side)
	return n > 0 && n >= r.start && n <= r.end
}

// click_range is the selection a click on a source line makes: the line
// alone, or with extend (Shift held) the range from the anchor to it. In
// Unified mode that range may cross from one side to the other. None when the
// selection would not change.
pub fn (s &DiffState) click_range(position DiffLinePosition, extend bool) ?DiffLineRange {
	fi := s.file_index(position.path)?
	file := s.files[fi]
	mut range := DiffLineRange{
		path:  position.path
		side:  position.side
		start: position.line
		end:   position.line
	}
	anchor := s.anchor
	if extend && s.has_selection && anchor.path == position.path {
		if anchor.side == position.side {
			range = DiffLineRange{
				path:  position.path
				side:  position.side
				start: math.min(anchor.line, position.line)
				end:   math.max(anchor.line, position.line)
			}
		} else if s.mode == .unified {
			from := diff_patch_position(file, anchor.side, anchor.line)?
			to := diff_patch_position(file, position.side, position.line)?
			range = if from <= to {
				DiffLineRange{
					path:    position.path
					side:    anchor.side
					start:   anchor.line
					end:     position.line
					crosses: true
				}
			} else {
				DiffLineRange{
					path:    position.path
					side:    position.side
					start:   position.line
					end:     anchor.line
					crosses: true
				}
			}
		}
	}
	clipped := s.clip_range(range)?
	if s.has_selection && clipped == s.selection {
		return none
	}
	return clipped
}

// extended_range moves the end of the selection away from its anchor by one
// available line (Shift+Down for +1, Shift+Up for -1). Without a selection it
// starts at the first line of the file at row `top`: on the modified side when
// that file has one, otherwise the original.
pub fn (s &DiffState) extended_range(delta int, top int) ?DiffLineRange {
	if !s.has_selection {
		fi := s.file_at_row(top)?
		file := s.files[fi]
		mut side := DiffSide.modified
		mut numbers := diff_side_lines(file, side)
		if numbers.len == 0 {
			side = .original
			numbers = diff_side_lines(file, side)
		}
		if numbers.len == 0 {
			return none
		}
		return DiffLineRange{
			path:  file.path()
			side:  side
			start: numbers[0]
			end:   numbers[0]
		}
	}
	r := s.selection
	fi := s.file_index(r.path)?
	anchor_line := if s.anchor.side == r.side && s.anchor.path == r.path {
		s.anchor.line
	} else {
		r.start
	}
	moving := if anchor_line == r.start { r.end } else { r.start }
	numbers := diff_side_lines(s.files[fi], r.side)
	mut at := -1
	for i, n in numbers {
		if n == moving {
			at = i
			break
		}
	}
	if at < 0 {
		return none
	}
	next := at + if delta > 0 { 1 } else { -1 }
	if next < 0 || next >= numbers.len {
		return none
	}
	moved := numbers[next]
	return DiffLineRange{
		path:  r.path
		side:  r.side
		start: math.min(anchor_line, moved)
		end:   math.max(anchor_line, moved)
	}
}

// all_range selects every supplied line of the selected file's side, or of the
// file at row `top` (its modified side when it has one) without a selection.
pub fn (s &DiffState) all_range(top int) ?DiffLineRange {
	mut fi := -1
	mut side := DiffSide.modified
	if s.has_selection {
		fi = s.file_index(s.selection.path)?
		side = s.selection.end_side()
	} else {
		fi = s.file_at_row(top)?
		if diff_side_lines(s.files[fi], .modified).len == 0 {
			side = .original
		}
	}
	numbers := diff_side_lines(s.files[fi], side)
	if numbers.len == 0 {
		return none
	}
	range := DiffLineRange{
		path:  s.files[fi].path()
		side:  side
		start: numbers[0]
		end:   numbers.last()
	}
	if s.has_selection && range == s.selection {
		return none
	}
	return range
}

// file_at_row is the file a row belongs to.
pub fn (s &DiffState) file_at_row(row int) ?int {
	if s.rows.len == 0 {
		return none
	}
	r := math.min(math.max(row, 0), s.rows.len - 1)
	return s.rows[r].file
}

// ── Conflicts ───────────────────────────────────────────────────────

// conflict_resolution is how a conflict was resolved; none while unresolved
// or for an unknown file or index.
pub fn (s &DiffState) conflict_resolution(path string, ix int) ?DiffConflictResolution {
	return s.resolutions[diff_conflict_key(path, ix)] or { return none }
}

// resolve_conflict keeps one side, the other or both of a conflict; the
// application writes the result (resolved_text).
pub fn (mut s DiffState) resolve_conflict(path string, ix int, resolution DiffConflictResolution) bool {
	fi := s.file_index(path) or { return false }
	if ix < 0 || ix >= s.files[fi].conflicts.len {
		return false
	}
	key := diff_conflict_key(path, ix)
	if current := s.resolutions[key] {
		if current == resolution {
			return false
		}
	}
	s.resolutions[key] = resolution
	s.rebuild()
	return true
}

// unresolve_conflict undoes a resolution.
pub fn (mut s DiffState) unresolve_conflict(path string, ix int) bool {
	key := diff_conflict_key(path, ix)
	if key !in s.resolutions {
		return false
	}
	s.resolutions.delete(key)
	s.rebuild()
	return true
}

// unresolved_conflicts counts the conflicts without a resolution in every file.
pub fn (s &DiffState) unresolved_conflicts() int {
	mut count := 0
	for file in s.files {
		for ix in 0 .. file.conflicts.len {
			if diff_conflict_key(file.path(), ix) !in s.resolutions {
				count++
			}
		}
	}
	return count
}

// resolved_text is a conflicted working file with every conflict resolved; none
// while one is not, and for a file that is part of a patch rather than whole.
pub fn (s &DiffState) resolved_text(path string) ?string {
	fi := s.file_index(path)?
	file := s.files[fi]
	mut chosen := map[int]DiffConflictResolution{}
	for ix in 0 .. file.conflicts.len {
		if resolution := s.resolutions[diff_conflict_key(path, ix)] {
			chosen[ix] = resolution
		}
	}
	return diff_resolve_text(file, chosen)
}

// ── Events ──────────────────────────────────────────────────────────

pub enum DiffEventKind {
	file_collapsed // `path` was collapsed (`collapsed`) or expanded from its header.
	reveal         // Show hidden lines of the fold at `row`, at `edge`.
	select         // `range` is the new selection, `anchor` where a Shift range starts.
	clear_selection
	conflict_resolved // `path`'s conflict `conflict` now keeps `resolution`, or with `undo` none.
	copy              // Copy the selection as `format` (diff_copy_selection).
	scroll            // Scroll the body to `offset` (scroll_to_offset with diff_body_id).
	navigate          // Go to change or hunk `row`: scroll the body to `offset`.
}

// DiffEvent is a request decoded from what the view emitted or from a key.
// Apply the state's part with DiffState.apply; scroll and copy are the
// application's to carry out.
pub struct DiffEvent {
pub:
	kind       DiffEventKind
	path       string
	collapsed  bool
	row        int = -1
	edge       DiffRevealEdge
	range      DiffLineRange
	anchor     DiffLinePosition
	conflict   int = -1
	resolution DiffConflictResolution
	undo       bool
	format     DiffCopyFormat
	offset     f64
}

// apply changes the state as an event asks and reports whether it did.
// Scrolling and copying are left to the application.
pub fn (mut s DiffState) apply(event DiffEvent) bool {
	match event.kind {
		.file_collapsed {
			if s.collapsed[event.path] == event.collapsed {
				return false
			}
			s.set_file_collapsed(event.path, event.collapsed)
			return true
		}
		.reveal {
			return s.reveal(event.row, event.edge)
		}
		.select {
			clipped := s.clip_range(event.range) or { return false }
			s.selection = clipped
			s.has_selection = true
			s.anchor = if event.anchor.path.len > 0 {
				event.anchor
			} else {
				DiffLinePosition{clipped.path, clipped.side, clipped.start}
			}
			return true
		}
		.clear_selection {
			if !s.has_selection {
				return false
			}
			s.clear_selection()
			return true
		}
		.conflict_resolved {
			if event.undo {
				return s.unresolve_conflict(event.path, event.conflict)
			}
			return s.resolve_conflict(event.path, event.conflict, event.resolution)
		}
		.navigate {
			s.set_current_row(event.row)
			return true
		}
		.copy, .scroll {
			return false
		}
	}
}

// diff_copy_selection puts the selection on the clipboard in a format and
// reports whether there was something to copy and the platform took it.
pub fn diff_copy_selection(s DiffState, format DiffCopyFormat) bool {
	copied := s.selected_text(format)
	if copied.len == 0 {
		return false
	}
	return set_clipboard_text(copied)
}

// ── Display text ────────────────────────────────────────────────────

const diff_tab_width = 4
const diff_max_display_runes = 2000

// diff_wide_rune reports a rune a monospace face draws two cells wide.
fn diff_wide_rune(r rune) bool {
	return (r >= 0x1100 && r <= 0x115f) || (r >= 0x2e80 && r <= 0xa4cf) || (r >= 0xac00
		&& r <= 0xd7a3) || (r >= 0xf900 && r <= 0xfaff) || (r >= 0xfe30 && r <= 0xfe4f)
		|| (r >= 0xff00 && r <= 0xff60) || (r >= 0xffe0 && r <= 0xffe6) || (r >= 0x1f300
		&& r <= 0x1faff) || (r >= 0x20000 && r <= 0x3fffd)
}

// diff_display_columns is how many monospace cells a line takes once tabs are
// expanded.
fn diff_display_columns(text string) int {
	mut cols := 0
	mut count := 0
	for r in text.runes() {
		if count >= diff_max_display_runes {
			break
		}
		count++
		if r == `\t` {
			cols += diff_tab_width - cols % diff_tab_width
		} else if r == `\r` {
			continue
		} else {
			cols += if diff_wide_rune(r) { 2 } else { 1 }
		}
	}
	return cols
}

// diff_display_text is a line as the view draws it: tabs expanded to stops of
// four, a carriage return dropped, other control characters shown as a dot,
// and very long lines cut short.
fn diff_display_text(text string) string {
	mut ascii := true
	for c in text.bytes() {
		if c < 0x20 || c >= 0x80 {
			ascii = false
			break
		}
	}
	if ascii && text.len <= diff_max_display_runes {
		return text
	}
	mut out := []rune{cap: text.len}
	mut cols := 0
	for r in text.runes() {
		if out.len >= diff_max_display_runes {
			out << `…`
			break
		}
		if r == `\t` {
			n := diff_tab_width - cols % diff_tab_width
			for _ in 0 .. n {
				out << ` `
			}
			cols += n
		} else if r == `\r` {
			continue
		} else if r < 0x20 {
			out << `·`
			cols++
		} else {
			out << r
			cols += if diff_wide_rune(r) { 2 } else { 1 }
		}
	}
	return out.string()
}
