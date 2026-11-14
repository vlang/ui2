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
	app.cached_doc_sheet = parse_ide_stylesheet(app.stylesheet_source) or { ui2.Stylesheet{} }
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
	app.cached_doc_sheet = parse_ide_stylesheet(normalized) or { ui2.Stylesheet{} }
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

fn (mut app IdeApp) lint_all_styles() {
	mut parts := []string{}
	doc_source := if app.style_doc_modified { app.style_doc_text } else { app.stylesheet_source }
	doc_msg := style_lint_message(doc_source)
	if doc_msg.len > 0 {
		parts << 'document: ${doc_msg}'
	}
	if component := app.selected_component() {
		draft := app.scoped_draft_text(component)
		scoped_msg := style_lint_message(draft)
		if scoped_msg.len > 0 {
			parts << 'scoped: ${scoped_msg}'
		}
		if component.inline_style.trim_space().len > 0 {
			inline_msg := style_lint_message('* { ${component.inline_style} }')
			if inline_msg.len > 0 {
				parts << 'inline: ${inline_msg}'
			}
		}
	}
	if parts.len == 0 {
		if doc_source.trim_space().len == 0 {
			app.status = 'No stylesheet to lint.'
		} else {
			app.status = 'Stylesheets are clean.'
			app.log(app.status)
		}
		app.stylesheet_error = ''
	} else {
		app.status = 'Stylesheet lint: ${parts.join('; ')}'
		app.log(app.status)
		app.stylesheet_error = parts.join('; ')
	}
	app.output_open = true
}

fn (mut app IdeApp) lint_style_doc() {
	app.lint_all_styles()
}

fn (mut app IdeApp) apply_all_style_drafts() bool {
	if app.style_doc_modified {
		if !app.apply_style_doc() {
			return false
		}
	}
	// Validate every pending scoped draft before mutating, then commit in
	// one checkpoint so undo stays a single step.
	mut pending := map[int]string{}
	for id in app.style_scoped_drafts.keys() {
		index := app.find_component_index(id)
		if index < 0 {
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
		if app.components[index].scoped_style != draft.trim_space() {
			pending[id] = draft.trim_space()
		}
	}
	if pending.len == 0 {
		app.style_scoped_drafts = map[int]string{}
		return true
	}
	app.checkpoint()
	for id, normalized in pending {
		index := app.find_component_index(id)
		if index < 0 {
			continue
		}
		app.components[index].scoped_style = normalized
	}
	app.style_scoped_drafts = map[int]string{}
	app.changed('Updated scoped stylesheets.')
	return true
}

fn (mut app IdeApp) toggle_selected_enabled() {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return
	}
	app.checkpoint()
	app.components[index].enabled = !app.components[index].enabled
	app.changed(if app.components[index].enabled {
		'Enabled `${app.components[index].name}`.'
	} else {
		'Disabled `${app.components[index].name}` (:disabled rules now match).'
	})
}

fn (mut app IdeApp) reset_inline_to_sheet_defaults() {
	index := app.find_component_index(app.selected_id)
	if index < 0 {
		return
	}
	if app.components[index].background == 0xffffff
		&& app.components[index].color == 0x111111 && app.components[index].font_size == 15 {
		app.status = 'Inline already at sheet defaults.'
		return
	}
	app.checkpoint()
	app.components[index].background = 0xffffff
	app.components[index].color = 0x111111
	app.components[index].font_size = 15
	app.changed('Reset inline colors for `${app.components[index].name}` to sheet defaults; sheets can now win.')
}

fn (mut app IdeApp) set_preview_dark(dark bool) {
	app.preview_dark = dark
	if dark {
		ui2.set_stylesheet_dark(true)
		app.status = 'Dark preview on (forced dark).'
	} else {
		ui2.set_stylesheet_follow_system(true)
		app.status = 'Following system appearance.'
	}
	app.log(app.status)
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
	if event == 'style_enabled' {
		if app.source_modified && !app.apply_source_editor() {
			return true
		}
		app.toggle_selected_enabled()
		return true
	}
	if event == 'style_reset_inline' {
		if app.source_modified && !app.apply_source_editor() {
			return true
		}
		app.reset_inline_to_sheet_defaults()
		return true
	}
	if event == 'style_dark_preview' {
		app.set_preview_dark(!app.preview_dark)
		return true
	}
	mutates := event in ['style_class', 'style_inline', 'style_doc_apply', 'style_scoped_apply',
		'style_all_lint']
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
		'style_doc_lint', 'style_all_lint' {
			app.lint_all_styles()
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
	// Cached on apply/restore so every preview build does not re-parse.
	return app.cached_doc_sheet
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
