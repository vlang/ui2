module ui2

// OpenUI Lang stored-message protocol: marker lines the host writes around
// the program. The model never sees them; the renderer strips them before
// parsing. With several content sections the last one wins.

pub struct OpenuiStoredMessage {
pub:
	content    string
	context    string
	finished   bool
	has_stream bool
}

// parse_openui_stored splits `]]>openui:content`, `]]>openui:context`, and
// `]]>openui:end` markers. Text without markers is plain content.

pub fn parse_openui_stored(raw string) OpenuiStoredMessage {
	if !raw.contains(']]>openui:') {
		return OpenuiStoredMessage{
			content: raw
		}
	}
	mut contents := []string{}
	mut context := ''
	mut finished := false
	mut mode := 'content'
	mut current := []string{}
	lines := raw.split_into_lines()
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with(']]>openui:') {
			rest := trimmed.all_after(']]>openui:')
			if rest.starts_with('content') || rest.starts_with('context')
				|| rest.starts_with('end') {
				text := current.join('\n')
				if mode == 'context' {
					context = text
				} else {
					contents << text
				}
				current = []string{}
				if rest.starts_with('content') {
					mode = 'content'
				} else if rest.starts_with('context') {
					mode = 'context'
				} else {
					finished = true
					mode = 'content'
				}
				continue
			}
		}
		current << line
	}
	text := current.join('\n')
	if mode == 'context' {
		context = text
	} else {
		contents << text
	}
	mut content := ''
	for part in contents {
		if part.trim_space().len > 0 {
			content = part
		}
	}
	return OpenuiStoredMessage{
		content:    content
		context:    context
		finished:   finished
		has_stream: true
	}
}

// strip_openui_markers returns the program text: the last content section,
// or the raw text when no markers exist.

pub fn strip_openui_markers(raw string) string {
	return parse_openui_stored(raw).content
}
