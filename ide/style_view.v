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
		children << ui2.label('', 'Scoped stylesheet', ui2.rect(4, 4 + ide_inspector_row_height * 2 + 4, width - 8, 16), text_style(10, color_muted, false))
		draft := app.scoped_draft_text(component)
		children << style_editor('style_scoped_editor', 'style_scoped_edit', draft, ui2.rect(4,
			4 + ide_inspector_row_height * 2 + 24, width - 8, 110))
		apply_y := 4 + ide_inspector_row_height * 2 + 24 + 114
		children << tiny_button('style_scoped_apply', 'Apply scoped', ui2.rect(4, apply_y, 110,
			24), app.has_scoped_draft(component.id))
		children << tiny_button('style_doc_lint', 'Lint all', ui2.rect(118, apply_y, 70, 24), true)
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
		24, width - 8, 150))
	children << tiny_button('style_doc_apply', 'Apply sheet', ui2.rect(4, 178, 90, 24), app.style_doc_modified)
	children << tiny_button('style_doc_lint', 'Lint', ui2.rect(98, 178, 60, 24), true)
	msg := if app.style_doc_modified {
		style_lint_message(app.style_doc_text)
	} else {
		app.stylesheet_error
	}
	help := if msg.len > 0 {
		msg
	} else if app.stylesheet_source.trim_space().len == 0 {
		'No sheet yet. Example: Button.primary { background: #2563eb; color: white; } Then set Classes to `primary`. Preview applies it live.'
	} else {
		'Sheet applied. Preview shows it live with hover/focus.'
	}
	children << ui2.label('', help, ui2.rect(4, 206, width - 8, 80), ui2.TextStyle{
		size:  10
		color: color_muted
		lines: 6
	})
	return children
}
