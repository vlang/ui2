module main

import ui2

fn style_editor(id string, action_id string, text string, frame ui2.Rect) ui2.Element {
	mut editor := ui2.text_area(id, text, frame, ui2.BoxStyle{
		bg:     0x0f172a
		radius: 4
	}, ui2.TextStyle{
		color:       0xe2e8f0
		size:        11
		font_family: source_code_font_family()
	})
	editor = ui2.Element{
		...editor
		action_id:   action_id
		emit_change: true
	}
	return editor
}

fn build_style_inspector(width f64, app &IdeApp) []ui2.Element {
	if component := app.selected_component() {
		mut children := []ui2.Element{}
		children << inspector_field('style_class', 'Classes', component.classes, 4, width)
		children << inspector_field('style_inline', 'Inline', component.inline_style, 4 +
			ide_inspector_row_height, width)
		// Enabled drives `:disabled`; Reset clears inline colors so sheets win.
		children << ui2.checkbox('style_enabled', 'Enabled', component.enabled, ui2.rect(4,
			4 + ide_inspector_row_height * 2, 110, ide_inspector_field_height), text_style(10,
			color_text, false))
		children << tiny_button('style_reset_inline', 'Reset colors', ui2.rect(118, 4 +
			ide_inspector_row_height * 2, width - 122, 24), true)
		scoped_label_y := 4 + ide_inspector_row_height * 3 + 4
		children << ui2.label('', 'Scoped stylesheet', ui2.rect(4, scoped_label_y, width - 8,
			16), text_style(10, color_muted, false))
		draft := app.scoped_draft_text(component)
		children << style_editor('style_scoped_editor', 'style_scoped_edit', draft, ui2.rect(4,
			scoped_label_y + 20, width - 8, 100))
		apply_y := scoped_label_y + 20 + 104
		children << tiny_button('style_scoped_apply', 'Apply scoped', ui2.rect(4, apply_y, 100,
			24), app.has_scoped_draft(component.id))
		children << tiny_button('style_all_lint', 'Lint all', ui2.rect(108, apply_y, 66, 24), true)
		children << ui2.checkbox('style_dark_preview', 'Dark', app.preview_dark, ui2.rect(178,
			apply_y, width - 182, 24), text_style(10, color_text, false))
		msg := if app.has_scoped_draft(component.id) {
			style_lint_message(draft)
		} else {
			style_lint_message(component.scoped_style)
		}
		help := if msg.len > 0 {
			'Scoped: ${msg}'
		} else {
			'Classes match `.name`; inline beats sheets; props beat inline. `@import` needs a file.'
		}
		children << ui2.label('', help, ui2.rect(4, apply_y + 28, width - 8, 60), ui2.TextStyle{
			size:  10
			color: color_muted
			lines: 4
		})
		return children
	}
	mut children := []ui2.Element{}
	children << ui2.label('', 'Document stylesheet (.vss)', ui2.rect(4, 4, width - 8, 16), text_style(10, color_muted, false))
	children << style_editor('style_doc_editor', 'style_doc_edit', app.style_doc_text, ui2.rect(4,
		24, width - 8, 140))
	children << tiny_button('style_doc_apply', 'Apply sheet', ui2.rect(4, 168, 86, 24), app.style_doc_modified)
	children << tiny_button('style_doc_lint', 'Lint', ui2.rect(94, 168, 56, 24), true)
	children << ui2.checkbox('style_dark_preview', 'Dark', app.preview_dark, ui2.rect(154, 168,
		width - 158, 24), text_style(10, color_text, false))
	msg := if app.style_doc_modified {
		style_lint_message(app.style_doc_text)
	} else {
		app.stylesheet_error
	}
	// Container queries in preview evaluate against the scaled display frame;
	// verify breakpoints at 100% zoom or in the running app.
	help := if msg.len > 0 {
		msg
	} else if app.stylesheet_source.trim_space().len == 0 {
		'No sheet yet. Example: Button.primary { background: #2563eb; color: white; } Then set Classes to `primary`. Preview applies it live.'
	} else {
		'Sheet applied. Preview shows it live with hover/focus. Container queries use the scaled preview frame.'
	}
	children << ui2.label('', help, ui2.rect(4, 196, width - 8, 90), ui2.TextStyle{
		size:  10
		color: color_muted
		lines: 7
	})
	return children
}
