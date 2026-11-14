module main

import ui2

// VSS (vss) support for the visual IDE: document and per-component
// stylesheets plus `class:` and `style:` props. File format matches
// `ui/vml_stylesheet.v`: `Style { ... }` blocks hold raw `.vss` source,
// `class: "a b"` joins stylesheet classes, `style: "..."` holds inline
// declarations. Inline VML props still beat `style:`, which beats sheets.

fn is_style_class_start(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `_` || c == `-`
}

fn is_style_class_char(c u8) bool {
	return is_style_class_start(c) || (c >= `0` && c <= `9`)
}

fn validate_style_classes(raw string) !string {
	trimmed := raw.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	parts := trimmed.fields()
	for part in parts {
		if part.len == 0 {
			continue
		}
		if !is_style_class_start(part[0]) {
			return error('invalid class `${part}`: use letters, digits, `_` and `-`, starting with a letter, `_` or `-`')
		}
		for c in part.bytes() {
			if !is_style_class_char(c) {
				return error('invalid class `${part}`: use letters, digits, `_` and `-`')
			}
		}
	}
	return parts.join(' ')
}

fn validate_inline_style(raw string) !string {
	trimmed := raw.trim_space()
	if trimmed.len == 0 {
		return ''
	}
	sheet := ui2.parse_stylesheet('* { ${trimmed} }') or {
		return error('invalid `style`: ${err.msg()}')
	}
	if sheet.rules.len == 0 {
		return error('invalid `style`: empty declaration')
	}
	for decl in sheet.rules[0].declarations {
		if decl.prop.starts_with('--') {
			return error('invalid `style`: custom properties need a `Style` block')
		}
	}
	return trimmed
}

fn parse_ide_stylesheet(source string) !ui2.Stylesheet {
	if source.trim_space().len == 0 {
		return ui2.Stylesheet{}
	}
	sheet := ui2.parse_stylesheet(source) or { return err }
	if sheet.imports.len > 0 {
		return error('invalid `Style` block: `@import` needs a file; inline the sheet or style from V')
	}
	return sheet
}

fn merge_ide_sheets(sheets []ui2.Stylesheet) ui2.Stylesheet {
	mut rules := []ui2.StyleRule{}
	mut variables := map[string]string{}
	mut light_vars := map[string]string{}
	mut dark_vars := map[string]string{}
	for sheet in sheets {
		rules << sheet.rules
		for key, value in sheet.variables {
			variables[key] = value
		}
		for key, value in sheet.light_vars {
			light_vars[key] = value
		}
		for key, value in sheet.dark_vars {
			dark_vars[key] = value
		}
	}
	return ui2.Stylesheet{
		rules:      rules
		variables:  variables
		light_vars: light_vars
		dark_vars:  dark_vars
		rule_index: ui2.stylesheet_index_rules(rules)
	}
}

fn style_block_vml_lines(source string, indent string) []string {
	trimmed := source.trim_space()
	if trimmed.len == 0 {
		return []string{}
	}
	mut out := [indent + 'Style {']
	for line in trimmed.split_into_lines() {
		out << indent + '    ' + line.trim_right(' \t')
	}
	out << indent + '}'
	return out
}

fn style_lint_message(source string) string {
	if source.trim_space().len == 0 {
		return ''
	}
	notes := ui2.stylesheet_lint_source(source) or { return err.msg() }
	if notes.has_errors() || notes.warnings.len > 0 {
		mut parts := []string{}
		for e in notes.errors {
			parts << 'error: ${e}'
		}
		for w in notes.warnings {
			parts << 'warning: ${w}'
		}
		return parts.join('; ')
	}
	return ''
}

fn (mut app IdeApp) sync_style_drafts() {
	app.style_doc_text = app.stylesheet_source
	app.style_doc_modified = false
	app.style_scoped_drafts = map[int]string{}
	app.stylesheet_error = style_lint_message(app.stylesheet_source)
	if component := app.selected_component() {
		scoped_msg := style_lint_message(component.scoped_style)
		if scoped_msg.len > 0 {
			app.stylesheet_error = if app.stylesheet_error.len > 0 {
				'${app.stylesheet_error}; scoped: ${scoped_msg}'
			} else {
				'scoped: ${scoped_msg}'
			}
		}
		inline_msg := if component.inline_style.trim_space().len > 0 {
			style_lint_message('* { ${component.inline_style} }')
		} else {
			''
		}
		if inline_msg.len > 0 {
			app.stylesheet_error = if app.stylesheet_error.len > 0 {
				'${app.stylesheet_error}; inline: ${inline_msg}'
			} else {
				'inline: ${inline_msg}'
			}
		}
	}
}

fn (app &IdeApp) scoped_draft_text(component DesignerComponent) string {
	if draft := app.style_scoped_drafts[component.id] {
		return draft
	}
	return component.scoped_style
}

fn (app &IdeApp) has_scoped_draft(id int) bool {
	return id in app.style_scoped_drafts
}

fn (mut app IdeApp) set_style_classes(raw string) bool {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return false
	}
	normalized := validate_style_classes(raw) or {
		app.status = err.msg()
		return false
	}
	if app.components[index].classes == normalized {
		return false
	}
	app.checkpoint()
	app.components[index].classes = normalized
	app.changed('Updated classes for `${app.components[index].name}`.')
	return true
}

fn (mut app IdeApp) set_inline_style(raw string) bool {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return false
	}
	normalized := validate_inline_style(raw) or {
		app.status = err.msg()
		return false
	}
	if app.components[index].inline_style == normalized {
		return false
	}
	app.checkpoint()
	app.components[index].inline_style = normalized
	app.changed('Updated inline style for `${app.components[index].name}`.')
	return true
}

fn (mut app IdeApp) apply_style_doc() bool {
	source := app.style_doc_text
	if source.trim_space().len > 0 {
		parse_ide_stylesheet(source) or {
			app.status = 'Stylesheet error: ${err.msg()}'
			app.log(app.status)
			app.stylesheet_error = app.status
			return false
		}
	}
	normalized := source.trim_space()
	if app.stylesheet_source == normalized && !app.style_doc_modified {
		return false
	}
	app.checkpoint()
	app.stylesheet_source = normalized
	app.style_doc_text = normalized
	app.style_doc_modified = false
	app.changed('Updated document stylesheet.')
	app.stylesheet_error = style_lint_message(app.stylesheet_source)
	if app.stylesheet_error.len > 0 {
		app.log('Stylesheet lint: ${app.stylesheet_error}')
	}
	return true
}

fn (mut app IdeApp) edit_scoped_draft(raw string) {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return
	}
	id := app.components[index].id
	committed := app.components[index].scoped_style
	if raw.trim_space() == committed.trim_space() && raw == committed {
		if id in app.style_scoped_drafts {
			app.style_scoped_drafts.delete(id)
		}
		app.status = 'Scoped stylesheet matches saved version.'
		return
	}
	if raw.trim_space() == committed.trim_space() {
		// Whitespace-only difference counts as clean to avoid sticky dirty.
		if id in app.style_scoped_drafts {
			app.style_scoped_drafts.delete(id)
		}
		app.dirty = true
		app.status = 'Scoped stylesheet edited; apply it to update the designer.'
		return
	}
	app.style_scoped_drafts[id] = raw
	app.dirty = true
	app.status = 'Scoped stylesheet edited; apply it to update the designer.'
}

fn (mut app IdeApp) apply_scoped_style() bool {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return false
	}
	id := app.components[index].id
	draft := if d := app.style_scoped_drafts[id] { d } else { return false }
	if draft.trim_space().len > 0 {
		parse_ide_stylesheet(draft) or {
			app.status = 'Scoped stylesheet error: ${err.msg()}'
			app.log(app.status)
			return false
		}
	}
	normalized := draft.trim_space()
	if app.components[index].scoped_style == normalized {
		app.style_scoped_drafts.delete(id)
		return false
	}
	app.checkpoint()
	app.components[index].scoped_style = normalized
	app.style_scoped_drafts.delete(id)
	app.changed('Updated scoped stylesheet for `${app.components[index].name}`.')
	return true
}

fn (mut app IdeApp) lint_style_doc() {
	if app.stylesheet_source.trim_space().len == 0 && app.style_doc_text.trim_space().len == 0 {
		app.status = 'No document stylesheet to lint.'
		return
	}
	source := if app.style_doc_modified { app.style_doc_text } else { app.stylesheet_source }
	msg := style_lint_message(source)
	app.stylesheet_error = msg
	if msg.len == 0 {
		app.status = 'Stylesheet is clean.'
		app.log(app.status)
	} else {
		app.status = 'Stylesheet lint: ${msg}'
		app.log(app.status)
	}
	app.output_open = true
}

fn (mut app IdeApp) apply_all_style_drafts() bool {
	if app.style_doc_modified {
		if !app.apply_style_doc() {
			return false
		}
	}
	// Apply every pending scoped draft, not just the selection, so Save
	// never drops unapplied per-component edits.
	for id in app.style_scoped_drafts.keys() {
		index := app.find_component_index(id)
		if index < 0 {
			app.style_scoped_drafts.delete(id)
			continue
		}
		draft := app.style_scoped_drafts[id]
		if draft.trim_space().len > 0 {
			parse_ide_stylesheet(draft) or {
				app.status = 'Scoped stylesheet error: ${err.msg()}'
				app.log(app.status)
				return false
			}
		}
		normalized := draft.trim_space()
		if app.components[index].scoped_style == normalized {
			app.style_scoped_drafts.delete(id)
			continue
		}
		// Checkpoint once for the batch; subsequent commits reuse it.
		// Use a single checkpoint for the whole batch to keep undo clean.
		app.checkpoint()
		for inner_id in app.style_scoped_drafts.keys() {
			inner_index := app.find_component_index(inner_id)
			if inner_index < 0 {
				continue
			}
			inner_draft := app.style_scoped_drafts[inner_id]
			if inner_draft.trim_space().len > 0 {
				parse_ide_stylesheet(inner_draft) or {
					app.undo_stack.delete_last()
					app.status = 'Scoped stylesheet error: ${err.msg()}'
					app.log(app.status)
					return false
				}
			}
			app.components[inner_index].scoped_style = inner_draft.trim_space()
		}
		app.style_scoped_drafts = map[int]string{}
		app.changed('Updated scoped stylesheets.')
		break
	}
	return true
}

fn (mut app IdeApp) handle_style_event(event string) bool {
	if event == 'inspector_style' {
		app.inspector_tab = 'style'
		return true
	}
	if event == 'style_doc_edit' {
		app.style_doc_text = ui2.text('style_doc_editor')
		app.style_doc_modified = true
		app.dirty = true
		app.status = 'Stylesheet edited; apply it to update the designer.'
		return true
	}
	if event == 'style_scoped_edit' {
		app.edit_scoped_draft(ui2.text('style_scoped_editor'))
		return true
	}
	mutates := event in ['style_class', 'style_inline', 'style_doc_apply', 'style_scoped_apply']
	if mutates && app.source_modified && !app.apply_source_editor() {
		return true
	}
	match event {
		'style_class' {
			app.set_style_classes(ui2.text('style_class'))
		}
		'style_inline' {
			app.set_inline_style(ui2.text('style_inline'))
		}
		'style_doc_apply' {
			app.apply_style_doc()
		}
		'style_doc_lint' {
			app.lint_style_doc()
		}
		'style_scoped_apply' {
			app.apply_scoped_style()
		}
		else {
			return false
		}
	}
	return true
}

fn (app &IdeApp) preview_document_sheet() ui2.Stylesheet {
	if app.stylesheet_source.trim_space().len == 0 {
		return ui2.Stylesheet{}
	}
	return parse_ide_stylesheet(app.stylesheet_source) or { return ui2.Stylesheet{} }
}

fn preview_element_sheet(component DesignerComponent, preview_id string) ui2.Stylesheet {
	mut sheets := []ui2.Stylesheet{}
	if component.scoped_style.trim_space().len > 0 {
		scoped := parse_ide_stylesheet(component.scoped_style) or { ui2.Stylesheet{} }
		if scoped.rules.len > 0 || scoped.variables.len > 0 || scoped.light_vars.len > 0
			|| scoped.dark_vars.len > 0 {
			sheets << scoped
		}
	}
	if component.inline_style.trim_space().len > 0 {
		// Inline declarations beat sheets but lose to VML/builder props.
		// Represent them as an `#id` rule in the element's own scope so
		// they outrank document type/class rules while builder props
		// (non-defaults) still win in the cascade.
		inline_sheet := ui2.parse_stylesheet('#${preview_id} { ${component.inline_style} }') or {
			ui2.Stylesheet{}
		}
		if inline_sheet.rules.len > 0 {
			sheets << inline_sheet
		}
	}
	if sheets.len == 0 {
		return ui2.Stylesheet{}
	}
	return merge_ide_sheets(sheets)
}
