module ui2

// Reading diffs: unified and Git patches (several files, renames and copies,
// modes, binary markers, `\ No newline at end of file`, quoted paths, the
// prefixes of diff.noprefix and diff.mnemonicPrefix, and the mail around
// `git format-patch` output), and working files with merge-conflict markers.

// DiffParseError is a malformed or unsupported patch, with its one-based line.
pub struct DiffParseError {
	Error
pub:
	line    int
	message string
}

pub fn (err DiffParseError) msg() string {
	return 'patch line ${err.line}: ${err.message}'
}

fn diff_parse_error(line int, message string) IError {
	return DiffParseError{
		line:    line
		message: message
	}
}

// DiffPatchHeader is what `git format-patch` (or `git show`) writes before the
// first file: the commit, its author, its date and its message.
pub struct DiffPatchHeader {
pub:
	commit  string
	author  string
	date    string
	subject string
	message string // The body after the subject, without the diffstat.
}

// The source prefixes Git writes on each side: the default a/ and b/, the
// diff.mnemonicPrefix pairs, --no-index, and none for diff.noprefix.
const diff_git_prefixes = [['a/', 'b/'], ['i/', 'w/'], ['c/', 'w/'], ['c/', 'i/'], ['o/', 'w/'],
	['1/', '2/'], ['', '']]

struct DiffFileBuilder {
mut:
	old_path     string
	new_path     string
	has_old      bool = true
	has_new      bool = true
	old_prefix   string
	new_prefix   string
	git          bool // Started with `diff --git`, whose prefixes are known.
	file_headers bool // Saw `---` and `+++`.
	headers      []string
	binary       bool
	renamed      bool
	copied       bool
	old_mode     string
	new_mode     string
	similarity   int = -1
	hunks        []DiffHunk
	additions    int
	deletions    int
}

fn (b DiffFileBuilder) finish() DiffFile {
	status := if !b.has_old {
		DiffFileStatus.added
	} else if !b.has_new {
		DiffFileStatus.deleted
	} else if b.copied {
		DiffFileStatus.copied
	} else if b.renamed {
		DiffFileStatus.renamed
	} else {
		DiffFileStatus.modified
	}
	return DiffFile{
		old_path:   if b.has_old { b.old_path } else { '' }
		new_path:   if b.has_new { b.new_path } else { '' }
		status:     status
		binary:     b.binary
		old_mode:   b.old_mode
		new_mode:   b.new_mode
		similarity: b.similarity
		headers:    b.headers
		hunks:      b.hunks
		additions:  b.additions
		deletions:  b.deletions
		conflicts:  diff_find_conflicts(b.hunks, false) or { []DiffConflict{} }
	}
}

// diff_patch_lines splits a patch into lines. Git keeps a carriage return in
// source lines but writes its own records with bare newlines; a patch whose
// headers end in one went through a CRLF transport, and loses them all.
fn diff_patch_lines(patch string) []string {
	mut lines, _ := diff_split_lines(patch)
	mut crlf := false
	for line in lines {
		if line.starts_with('diff --git ') || line.starts_with('--- ') {
			crlf = line.ends_with('\r')
			break
		}
	}
	if crlf {
		for i, line in lines {
			if line.ends_with('\r') {
				lines[i] = line[..line.len - 1]
			}
		}
	}
	return lines
}

// parse_diff reads a unified diff or Git patch into one DiffFile per file. It
// returns a DiffParseError for a malformed hunk, a source line outside a hunk,
// or a combined diff (`diff --cc`), which it does not support. Text before the
// first file, such as a commit message, is skipped; parse_diff_header reads it.
pub fn parse_diff(patch string) ![]DiffFile {
	lines := diff_patch_lines(patch)
	mut files := []DiffFile{}
	mut cur := DiffFileBuilder{}
	mut open := false
	mut i := 0
	for i < lines.len {
		line := lines[i]
		number := i + 1
		if line.starts_with('diff --cc ') || line.starts_with('diff --combined ')
			|| line.starts_with('@@@ ') {
			return diff_parse_error(number, 'combined diffs are not supported')
		}
		if line.starts_with('diff --git ') {
			if open {
				files << cur.finish()
			}
			paths := diff_git_paths(line['diff --git '.len..]) or {
				return diff_parse_error(number, 'invalid Git file header')
			}
			cur = DiffFileBuilder{
				old_path:   paths[0]
				new_path:   paths[1]
				old_prefix: paths[2]
				new_prefix: paths[3]
				git:        true
			}
			open = true
			i++
			continue
		}
		// `git format-patch` ends a message with a `-- ` signature line.
		if line == '-- ' || line == '--' {
			if open {
				files << cur.finish()
				open = false
			}
			i++
			continue
		}
		if line.starts_with('--- ') {
			if i + 1 >= lines.len || !lines[i + 1].starts_with('+++ ') {
				if open && cur.file_headers {
					return diff_parse_error(number + 1, 'expected modified file header')
				}
				i++
				continue
			}
			if open && cur.file_headers {
				files << cur.finish()
				open = false
			}
			if !open {
				cur = DiffFileBuilder{}
				open = true
			}
			old := diff_header_path(line[4..], number)!
			new := diff_header_path(lines[i + 1][4..], number + 1)!
			if old.len == 0 && new.len == 0 {
				return diff_parse_error(number + 1, 'both file sides are missing')
			}
			mut old_prefix := cur.old_prefix
			mut new_prefix := cur.new_prefix
			if !cur.git {
				// Without a Git header, strip a/ and b/ only when the sides
				// that are present agree on that convention.
				if (old.len == 0 || old.starts_with('a/')) && (new.len == 0 || new.starts_with('b/')) {
					old_prefix = 'a/'
					new_prefix = 'b/'
				}
			}
			if old.len == 0 {
				cur.has_old = false
			} else {
				cur.old_path = diff_strip_prefix(old, old_prefix)
			}
			if new.len == 0 {
				cur.has_new = false
			} else {
				cur.new_path = diff_strip_prefix(new, new_prefix)
			}
			cur.file_headers = true
			i += 2
			continue
		}
		if line.starts_with('@@ ') {
			if !open {
				return diff_parse_error(number, 'hunk has no file header')
			}
			if !cur.file_headers {
				return diff_parse_error(number, 'hunk requires original and modified file headers')
			}
			i = diff_parse_hunk(mut cur, lines, i)!
			continue
		}
		if !open {
			i++
			continue
		}
		// A binary patch's payload is opaque: keep the marker, not the records.
		if cur.binary && !line.starts_with('Binary files ') {
			i++
			continue
		}
		if cur.file_headers && (line.starts_with('+') || line.starts_with('-')
			|| line.starts_with(' ') || line.starts_with('\\')) {
			return diff_parse_error(number, 'source line outside a hunk')
		}
		diff_extended_header(mut cur, line, number)!
		i++
	}
	if open {
		files << cur.finish()
	}
	if files.len == 0 && patch.trim_space().len > 0 {
		return diff_parse_error(1, 'expected a unified or Git diff')
	}
	return files
}

fn diff_extended_header(mut cur DiffFileBuilder, line string, number int) ! {
	if line.starts_with('Binary files ') || line == 'GIT binary patch' {
		cur.binary = true
	} else if line.starts_with('rename from ') {
		cur.old_path = diff_decode_path(line['rename from '.len..], number)!
		cur.renamed = true
	} else if line.starts_with('rename to ') {
		cur.new_path = diff_decode_path(line['rename to '.len..], number)!
		cur.renamed = true
	} else if line.starts_with('copy from ') {
		cur.old_path = diff_decode_path(line['copy from '.len..], number)!
		cur.copied = true
	} else if line.starts_with('copy to ') {
		cur.new_path = diff_decode_path(line['copy to '.len..], number)!
		cur.copied = true
	} else if line.starts_with('new file mode ') {
		cur.has_old = false
		cur.new_mode = line['new file mode '.len..].trim_space()
	} else if line.starts_with('deleted file mode ') {
		cur.has_new = false
		cur.old_mode = line['deleted file mode '.len..].trim_space()
	} else if line.starts_with('old mode ') {
		cur.old_mode = line['old mode '.len..].trim_space()
	} else if line.starts_with('new mode ') {
		cur.new_mode = line['new mode '.len..].trim_space()
	} else if line.starts_with('similarity index ') {
		value := line['similarity index '.len..].trim_space().trim_right('%')
		cur.similarity = diff_parse_count(value) or { -1 }
	}
	if line.len > 0 {
		cur.headers << line
	}
}

// diff_parse_hunk reads the hunk whose header is lines[start] and returns the
// index of the line after it.
fn diff_parse_hunk(mut cur DiffFileBuilder, lines []string, start int) !int {
	header := lines[start]
	old_start, old_count, new_start, new_count, section := diff_hunk_header(header) or {
		return diff_parse_error(start + 1, 'invalid hunk header')
	}
	if cur.hunks.len > 0 {
		prev := cur.hunks.last()
		prev_old_end := prev.old_start + prev.old_count - if prev.old_count > 0 { 1 } else { 0 }
		prev_new_end := prev.new_start + prev.new_count - if prev.new_count > 0 { 1 } else { 0 }
		if (old_count > 0 && prev.old_count > 0 && prev_old_end >= old_start)
			|| (new_count > 0 && prev.new_count > 0 && prev_new_end >= new_start) {
			return diff_parse_error(start + 1, 'overlapping or unordered hunks')
		}
	}
	if (!cur.has_old && old_count != 0) || (!cur.has_new && new_count != 0) {
		return diff_parse_error(start + 1, 'missing file side has source lines')
	}
	mut out := []DiffLine{cap: old_count + new_count}
	mut old_used := 0
	mut new_used := 0
	mut old_closed := false
	mut new_closed := false
	mut i := start + 1
	for i < lines.len {
		content := lines[i]
		if content.starts_with('\\') {
			// `\ No newline at end of file` (localized by GNU diff): the line
			// before it ends its version(s) without a newline.
			if out.len == 0 || out.last().no_newline {
				return diff_parse_error(i + 1, 'newline marker has no preceding source line')
			}
			last := out.last()
			out[out.len - 1] = DiffLine{
				...last
				no_newline: true
			}
			if last.kind != .added {
				old_closed = true
			}
			if last.kind != .removed {
				new_closed = true
			}
			i++
			continue
		}
		if old_used == old_count && new_used == new_count {
			break
		}
		// Editors and mail may strip the space of an empty context line; git
		// apply accepts that, and so does this.
		mark := if content.len == 0 { u8(` `) } else { content[0] }
		source := if content.len == 0 { '' } else { content[1..] }
		match mark {
			` ` {
				if old_used >= old_count || new_used >= new_count {
					return diff_parse_error(i + 1, 'hunk exceeds declared line counts')
				}
				if old_closed || new_closed {
					return diff_parse_error(i + 1, 'source continues after an unterminated final line')
				}
				out << DiffLine{
					kind:     .context
					old_line: old_start + old_used
					new_line: new_start + new_used
					text:     source
				}
				old_used++
				new_used++
			}
			`-` {
				if old_used >= old_count {
					return diff_parse_error(i + 1, 'hunk exceeds original line count')
				}
				if old_closed {
					return diff_parse_error(i + 1, 'source continues after an unterminated final line')
				}
				out << DiffLine{
					kind:     .removed
					old_line: old_start + old_used
					text:     source
				}
				old_used++
				cur.deletions++
			}
			`+` {
				if new_used >= new_count {
					return diff_parse_error(i + 1, 'hunk exceeds modified line count')
				}
				if new_closed {
					return diff_parse_error(i + 1, 'source continues after an unterminated final line')
				}
				out << DiffLine{
					kind:     .added
					new_line: new_start + new_used
					text:     source
				}
				new_used++
				cur.additions++
			}
			else {
				return diff_parse_error(i + 1, 'hunk ended before its declared line counts')
			}
		}
		i++
	}
	if old_used != old_count || new_used != new_count {
		return diff_parse_error(i + 1, 'hunk ended before its declared line counts')
	}
	cur.hunks << DiffHunk{
		old_start: old_start
		old_count: old_count
		new_start: new_start
		new_count: new_count
		section:   section
		lines:     out
	}
	return i
}

// diff_hunk_header reads `@@ -a[,b] +c[,d] @@[ section]`.
fn diff_hunk_header(line string) ?(int, int, int, int, string) {
	if !line.starts_with('@@ -') {
		return none
	}
	rest := line[3..]
	close := rest.index(' @@') or { return none }
	fields := rest[..close].split(' ')
	if fields.len != 2 || !fields[0].starts_with('-') || !fields[1].starts_with('+') {
		return none
	}
	old_start, old_count := diff_hunk_range(fields[0][1..])?
	new_start, new_count := diff_hunk_range(fields[1][1..])?
	mut section := rest[close + 3..]
	if section.starts_with(' ') {
		section = section[1..]
	}
	return old_start, old_count, new_start, new_count, section
}

fn diff_hunk_range(value string) ?(int, int) {
	comma := value.index(',') or { -1 }
	start := diff_parse_count(if comma >= 0 { value[..comma] } else { value })?
	count := if comma >= 0 { diff_parse_count(value[comma + 1..])? } else { 1 }
	if count > 0 && start == 0 {
		return none
	}
	return start, count
}

// diff_parse_count reads a decimal of digits only, up to a billion.
fn diff_parse_count(digits string) ?int {
	if digits.len == 0 || digits.len > 9 {
		return none
	}
	mut value := 0
	for c in digits.bytes() {
		if c < `0` || c > `9` {
			return none
		}
		value = value * 10 + int(c - `0`)
	}
	return value
}

fn diff_strip_prefix(path string, prefix string) string {
	return if prefix.len > 0 && path.starts_with(prefix) { path[prefix.len..] } else { path }
}

// diff_header_path decodes a `---` or `+++` path, cut at a tab before a
// timestamp; /dev/null, the missing side, is the empty string.
fn diff_header_path(value string, number int) !string {
	tab := value.index('\t') or { value.len }
	path := value[..tab]
	if path == '/dev/null' {
		return ''
	}
	return diff_decode_path(path, number)
}

// diff_git_paths splits the paths of a `diff --git` header and returns them
// without their prefixes, followed by the prefixes it found.
fn diff_git_paths(value string) ?[]string {
	mut old := ''
	mut new := ''
	if value.starts_with('"') {
		end := diff_quoted_end(value)?
		old = diff_decode_path(value[..end], 0) or { return none }
		rest := value[end..].trim_left(' ')
		new = diff_decode_path(rest, 0) or { return none }
	} else if value.ends_with('"') {
		mut found := -1
		mut from := 0
		for {
			at := value.index_after(' "', from) or { break }
			if end := diff_quoted_end(value[at + 1..]) {
				if at + 1 + end == value.len {
					found = at
					break
				}
			}
			from = at + 1
		}
		if found < 0 {
			return none
		}
		old = value[..found]
		new = diff_decode_path(value[found + 1..], 0) or { return none }
	} else {
		// Git does not quote spaces. Without a rename both sides name the same
		// path, which tells which space separates them.
		mut done := false
		for pair in diff_git_prefixes {
			for k, c in value {
				if c != ` ` {
					continue
				}
				a := value[..k]
				b := value[k + 1..]
				if a.starts_with(pair[0]) && b.starts_with(pair[1]) && a.len > pair[0].len
					&& a[pair[0].len..] == b[pair[1].len..] {
					old = a
					new = b
					done = true
					break
				}
			}
			if done {
				break
			}
		}
		if !done {
			// A rename or copy: its `rename from`/`rename to` records give the
			// exact paths later; this is the best guess until then.
			for pair in diff_git_prefixes {
				if pair[0].len == 0 || !value.starts_with(pair[0]) {
					continue
				}
				at := value.last_index(' ' + pair[1]) or { continue }
				old = value[..at]
				new = value[at + 1..]
				done = true
				break
			}
		}
		if !done {
			space := value.index(' ') or { return none }
			old = value[..space]
			new = value[space + 1..]
		}
	}
	for pair in diff_git_prefixes {
		if old.starts_with(pair[0]) && new.starts_with(pair[1]) {
			return [diff_strip_prefix(old, pair[0]), diff_strip_prefix(new, pair[1]), pair[0],
				pair[1]]
		}
	}
	return [old, new, '', '']
}

// diff_quoted_end is the length of the quoted string value starts with.
fn diff_quoted_end(value string) ?int {
	mut escaped := false
	for i := 1; i < value.len; i++ {
		c := value[i]
		if escaped {
			escaped = false
		} else if c == `\\` {
			escaped = true
		} else if c == `"` {
			return i + 1
		}
	}
	return none
}

// diff_decode_path undoes Git's C-style quoting of unusual paths.
fn diff_decode_path(value string, number int) !string {
	if !value.starts_with('"') {
		return value
	}
	end := diff_quoted_end(value) or { -1 }
	if end != value.len {
		return diff_parse_error(number, 'invalid quoted file path')
	}
	body := value[1..value.len - 1]
	mut out := []u8{cap: body.len}
	mut i := 0
	for i < body.len {
		c := body[i]
		if c != `\\` {
			out << c
			i++
			continue
		}
		i++
		if i >= body.len {
			return diff_parse_error(number, 'invalid path escape')
		}
		e := body[i]
		if e >= `0` && e <= `7` {
			mut v := 0
			mut n := 0
			for n < 3 && i < body.len && body[i] >= `0` && body[i] <= `7` {
				v = v * 8 + int(body[i] - `0`)
				i++
				n++
			}
			if v > 255 {
				return diff_parse_error(number, 'invalid octal path escape')
			}
			out << u8(v)
			continue
		}
		out << match e {
			`n` { u8(`\n`) }
			`t` { u8(`\t`) }
			`r` { u8(`\r`) }
			`a` { u8(7) }
			`b` { u8(8) }
			`f` { u8(12) }
			`v` { u8(11) }
			`"`, `\\` { e }
			else { return diff_parse_error(number, 'unsupported path escape') }
		}
		i++
	}
	return out.bytestr()
}

// parse_diff_header reads the commit a `git format-patch` or `git show` patch
// starts with. Fields it does not find stay empty.
pub fn parse_diff_header(patch string) DiffPatchHeader {
	lines := diff_patch_lines(patch)
	mut commit := ''
	mut author := ''
	mut date := ''
	mut subject := ''
	mut body := []string{}
	mut in_body := false
	mut show_style := false
	for i, line in lines {
		if line.starts_with('diff --git ') || line == '---' || line.starts_with('--- ') {
			break
		}
		if !in_body {
			if line.starts_with('From ') && i == 0 {
				commit = line['From '.len..].all_before(' ')
			} else if line.starts_with('commit ') {
				commit = line['commit '.len..].all_before(' ')
				show_style = true
			} else if line.starts_with('From: ') || line.starts_with('Author: ') {
				author = line.all_after(': ').trim_space()
			} else if line.starts_with('Date: ') || line.starts_with('Date:   ') {
				date = line.all_after(':').trim_space()
			} else if line.starts_with('Subject: ') {
				mut s := line['Subject: '.len..].trim_space()
				if s.starts_with('[') {
					s = s.all_after(']').trim_space()
				}
				subject = s
			} else if line.len == 0 {
				in_body = true
			}
			continue
		}
		content := if show_style && line.starts_with('    ') { line[4..] } else { line }
		if subject.len == 0 && show_style {
			if content.trim_space().len > 0 {
				subject = content.trim_space()
			}
			continue
		}
		body << content
	}
	for body.len > 0 && body[0].trim_space().len == 0 {
		body.delete(0)
	}
	for body.len > 0 && body.last().trim_space().len == 0 {
		body.delete_last()
	}
	return DiffPatchHeader{
		commit:  commit
		author:  author
		date:    date
		subject: subject
		message: body.join('\n')
	}
}

// ── Merge conflicts ─────────────────────────────────────────────────

pub enum DiffConflictResolution {
	ours   // Keep the current change (GPUI Kit's Accept Current).
	theirs // Keep the incoming change (Accept Incoming).
	both   // Keep the current change, then the incoming one (Accept Both).
}

// diff_conflict_marker returns the label after a conflict marker of seven
// `ch`, or none when the line is not one.
fn diff_conflict_marker(text string, ch u8) ?string {
	if text.len < 7 {
		return none
	}
	for i in 0 .. 7 {
		if text[i] != ch {
			return none
		}
	}
	rest := text[7..].trim_right('\r')
	if rest.len == 0 {
		return ''
	}
	if rest[0] != ` ` {
		return none
	}
	return rest.trim_space()
}

// diff_find_conflicts finds conflict regions in the modified version of the
// hunks. strict, for a whole working file, makes unbalanced markers an error;
// otherwise a region a hunk cuts off is left alone.
fn diff_find_conflicts(hunks []DiffHunk, strict bool) ![]DiffConflict {
	mut out := []DiffConflict{}
	for hi, hunk in hunks {
		// 0: outside, 1: ours, 2: base, 3: theirs.
		mut part := 0
		mut start := 0
		mut ours_start := 0
		mut ours_end := 0
		mut base_start := -1
		mut base_end := -1
		mut theirs_start := 0
		mut ours_label := ''
		mut base_label := ''
		mut first_line := 0
		for k, line in hunk.lines {
			if line.kind == .removed {
				continue
			}
			if label := diff_conflict_marker(line.text, `<`) {
				if part != 0 {
					if strict {
						return diff_parse_error(line.new_line, 'conflict opens inside another conflict')
					}
				}
				part = 1
				start = k
				ours_start = k + 1
				base_start = -1
				base_end = -1
				ours_label = label
				base_label = ''
				first_line = line.new_line
				continue
			}
			if label := diff_conflict_marker(line.text, `|`) {
				if part == 1 {
					ours_end = k
					base_start = k + 1
					base_label = label
					part = 2
				} else if strict && part != 0 {
					return diff_parse_error(line.new_line, 'misplaced conflict base marker')
				}
				continue
			}
			if _ := diff_conflict_marker(line.text, `=`) {
				if part == 1 {
					ours_end = k
				} else if part == 2 {
					base_end = k
				} else if part == 0 {
					// A line of equals signs outside a conflict is just text.
					continue
				} else if strict {
					return diff_parse_error(line.new_line, 'repeated conflict separator')
				}
				theirs_start = k + 1
				part = 3
				continue
			}
			if label := diff_conflict_marker(line.text, `>`) {
				if part == 3 {
					out << DiffConflict{
						hunk:         hi
						start:        start
						end:          k + 1
						ours_start:   ours_start
						ours_end:     ours_end
						base_start:   base_start
						base_end:     base_end
						theirs_start: theirs_start
						theirs_end:   k
						ours_label:   ours_label
						base_label:   base_label
						theirs_label: label
						first_line:   first_line
						last_line:    line.new_line
					}
					part = 0
				} else if strict && part != 0 {
					return diff_parse_error(line.new_line, 'conflict closes before its separator')
				}
				continue
			}
		}
		if strict && part != 0 {
			return diff_parse_error(first_line, 'conflict is not closed')
		}
	}
	return out
}

// parse_diff_conflicts reads a working file with Git conflict markers,
// including the diff3 base section. It is shown in one column with the working
// file's line numbers; the markers become headings with Accept buttons.
pub fn parse_diff_conflicts(path string, text string) !DiffFile {
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
	hunks := if out.len == 0 {
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
	conflicts := diff_find_conflicts(hunks, true)!
	return DiffFile{
		old_path:  path
		new_path:  path
		status:    .conflicted
		hunks:     hunks
		complete:  true
		conflicts: conflicts
	}
}

// diff_conflict_part_lines returns the text of one part of a conflict: the
// lines in [start, end) of its hunk that are in the working file.
fn diff_conflict_part_lines(file DiffFile, conflict DiffConflict, start int, end int) []string {
	mut out := []string{}
	if start < 0 || conflict.hunk >= file.hunks.len {
		return out
	}
	lines := file.hunks[conflict.hunk].lines
	for k in start .. end {
		if k < lines.len && lines[k].kind != .removed {
			out << lines[k].text
		}
	}
	return out
}

// diff_conflict_kept returns the lines a resolution keeps.
pub fn diff_conflict_kept(file DiffFile, conflict DiffConflict, resolution DiffConflictResolution) []string {
	ours := diff_conflict_part_lines(file, conflict, conflict.ours_start, conflict.ours_end)
	theirs := diff_conflict_part_lines(file, conflict, conflict.theirs_start, conflict.theirs_end)
	return match resolution {
		.ours {
			ours
		}
		.theirs {
			theirs
		}
		.both {
			mut both := ours.clone()
			both << theirs
			both
		}
	}
}

// diff_resolve_text writes a complete file's modified version with every
// conflict replaced by the lines its resolution keeps; resolutions are by
// conflict index. None while a conflict is unresolved, or for a file that does
// not hold the whole working file (a patch).
pub fn diff_resolve_text(file DiffFile, resolutions map[int]DiffConflictResolution) ?string {
	if !file.complete {
		return none
	}
	for ix in 0 .. file.conflicts.len {
		if ix !in resolutions {
			return none
		}
	}
	mut out := []string{}
	mut ends_open := false
	for hi, hunk in file.hunks {
		mut k := 0
		for k < hunk.lines.len {
			mut handled := false
			for ix, conflict in file.conflicts {
				if conflict.hunk == hi && conflict.start == k {
					out << diff_conflict_kept(file, conflict, resolutions[ix])
					ends_open = hunk.lines[conflict.end - 1].no_newline
					k = conflict.end
					handled = true
					break
				}
			}
			if handled {
				continue
			}
			line := hunk.lines[k]
			if line.kind != .removed {
				out << line.text
				ends_open = line.no_newline
			}
			k++
		}
	}
	if out.len == 0 {
		return ''
	}
	return out.join('\n') + if ends_open { '' } else { '\n' }
}
