module ui2

// OpenUI Lang predefined components: Tier-1 adapters mapping the common
// generative slots onto stock `ui2` builders. The library stays
// user-registered; these are opt-in helpers that hide frames and styles.

fn openui_render_stack(ctx OpenuiCtx) Element {
	return view(ctx.id, ctx.frame, BoxStyle{
		transparent: true
	}, ctx.children)
}

fn openui_render_card(ctx OpenuiCtx) Element {
	return view(ctx.id, ctx.frame, BoxStyle{
		bg:            0xffffff
		radius:        12
		border_color:  0xe2e8f0
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, ctx.children)
}

fn openui_render_text_content(ctx OpenuiCtx) Element {
	style := ctx.string_prop('style')
	size := if style.contains('large') {
		20.0
	} else if style.contains('small') {
		13.0
	} else {
		15.0
	}
	emphasized := style.contains('heavy') || style.contains('bold')
	return label(ctx.id, ctx.string_prop('text'), ctx.frame, TextStyle{
		size: size
		bold: emphasized
	})
}

fn openui_render_button(ctx OpenuiCtx) Element {
	return button(ctx.id, ctx.string_prop('label'), ctx.frame, BoxStyle{
		bg:            0x2563eb
		radius:        8
		border_color:  0x1d4ed8
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, TextStyle{
		color: 0xffffff
		bold:  true
	})
}

pub fn openui_stack_component() OpenuiComponent {
	return OpenuiComponent{
		name:        'Stack'
		description: 'Vertical layout container for child blocks.'
		params:      [
			OpenuiParam{
				name:   'children'
				schema: openui_list_schema(openui_any_schema())
			},
		]
		height:      0
		render:      openui_render_stack
	}
}

pub fn openui_card_component() OpenuiComponent {
	return OpenuiComponent{
		name:        'Card'
		description: 'Vertical container card for grouped content.'
		params:      [
			OpenuiParam{
				name:   'children'
				schema: openui_list_schema(openui_any_schema())
			},
		]
		height:      0
		render:      openui_render_card
	}
}

pub fn openui_text_content_component() OpenuiComponent {
	return OpenuiComponent{
		name:        'TextContent'
		description: 'A line of text. Styles: small, large-heavy.'
		params:      [
			OpenuiParam{
				name:   'text'
				schema: openui_string_schema()
			},
			OpenuiParam{
				name:   'style'
				schema: openui_optional(openui_string_schema(), openui_string(''))
			},
		]
		height:      28
		render:      openui_render_text_content
	}
}

pub fn openui_button_component() OpenuiComponent {
	return OpenuiComponent{
		name:        'Button'
		description: 'A clickable button. Runs its action on tap.'
		params:      [
			OpenuiParam{
				name:   'label'
				schema: openui_string_schema()
			},
			OpenuiParam{
				name:   'action'
				schema: openui_optional(openui_action_schema(), openui_null())
			},
		]
		height:      40
		render:      openui_render_button
	}
}

const openui_table_max_rows = 20

fn openui_table_columns(props map[string]OpenuiValue) []string {
	if raw := props['columns'] {
		if raw.kind == .list {
			mut columns := []string{}
			for item in raw.items {
				text := item.string_value().trim_space()
				if text.len > 0 {
					columns << text
				}
			}
			if columns.len > 0 {
				return columns
			}
		}
	}
	rows := openui_table_rows(props)
	if rows.len == 0 {
		return []
	}
	if rows[0].kind == .object {
		mut keys := rows[0].fields.keys()
		keys.sort()
		return keys
	}
	return ['']
}

fn openui_table_rows(props map[string]OpenuiValue) []OpenuiValue {
	raw := props['rows'] or { return []OpenuiValue{} }
	if raw.kind != .list {
		return []OpenuiValue{}
	}
	return raw.items
}

fn openui_table_height(props map[string]OpenuiValue) f64 {
	rows := openui_table_rows(props)
	shown := if rows.len > openui_table_max_rows { openui_table_max_rows } else { rows.len }
	body := if shown == 0 { 3 * 28.0 } else { f64(shown) * 28.0 }
	footer := if rows.len > shown { 24.0 } else { 0.0 }
	return 16 + 30 + body + footer
}

fn openui_render_table(ctx OpenuiCtx) Element {
	columns := openui_table_columns(ctx.props)
	rows := openui_table_rows(ctx.props)
	shown := if rows.len > openui_table_max_rows { openui_table_max_rows } else { rows.len }
	width := ctx.frame.width
	count := if columns.len > 0 { columns.len } else { 1 }
	cell := width / f64(count)
	mut kids := []Element{}
	for index, column in columns {
		title := if column.len > 0 { column } else { 'Value' }
		kids << label('${ctx.id}_h${index}', title, rect(f64(index) * cell, 8, cell, 30),
			TextStyle{
				bold: true
			})
	}
	for row_index in 0 .. shown {
		row := rows[row_index]
		y := 38 + f64(row_index) * 28
		for col_index in 0 .. count {
			text := if row.kind == .object && col_index < columns.len {
				(row.fields[columns[col_index]] or { openui_null() }).string_value()
			} else if row.kind == .object {
				''
			} else if col_index == 0 {
				row.string_value()
			} else {
				''
			}
			kids << label('${ctx.id}_r${row_index}c${col_index}', text, rect(f64(col_index) * cell,
				y, cell, 28), TextStyle{})
		}
	}
	if rows.len > shown {
		kids << label('${ctx.id}_more', '… and ${rows.len - shown} more', rect(0, 38 +
			f64(shown) * 28, width, 24), TextStyle{
			size: 13
		})
	}
	if columns.len == 0 {
		kids << label(ctx.id, 'No data', rect(0, 38, width, 3 * 28), TextStyle{})
	}
	return view(ctx.id, ctx.frame, BoxStyle{
		bg:            0xffffff
		radius:        12
		border_color:  0xe2e8f0
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, kids)
}

pub fn openui_table_component() OpenuiComponent {
	return OpenuiComponent{
		name:             'Table'
		description:      'A read-only data table. Columns default to the row fields.'
		params:           [
			OpenuiParam{
				name:   'rows'
				schema: openui_list_schema(openui_any_schema())
			},
			OpenuiParam{
				name:   'columns'
				schema: openui_optional(openui_list_schema(openui_string_schema()), openui_null())
			},
		]
		render:           openui_render_table
		height_for_props: openui_table_height
	}
}

fn openui_chart_type(name string) ChartType {
	return match name {
		'line' { .line }
		'pie' { .pie }
		'doughnut' { .doughnut }
		else { .bar }
	}
}

fn openui_render_chart(ctx OpenuiCtx) Element {
	kind := openui_chart_type(ctx.string_prop('type'))
	mut labels := []string{}
	mut values := []f64{}
	raw_labels := ctx.list_prop('labels')
	raw_values := ctx.list_prop('values')
	pairs := if raw_labels.len < raw_values.len { raw_labels.len } else { raw_values.len }
	for index in 0 .. pairs {
		number := raw_values[index].numeric() or { continue }
		labels << raw_labels[index].string_value()
		values << number
	}
	series := ctx.string_prop('series')
	title := ctx.string_prop('title')
	frame := rect(ctx.frame.x, ctx.frame.y, ctx.frame.width, 320)
	return chart(ChartConfig{
		id:      ctx.id
		frame:   frame
		type:    kind
		data:    ChartData{
			labels:   labels
			datasets: [
				ChartDataset{
					label: series
					data:  values
				},
			]
		}
		options: ChartOptions{
			title: title
		}
	}) or { label(ctx.id, 'Chart error: ${err.msg()}', ctx.frame, TextStyle{}) }
}

pub fn openui_chart_component() OpenuiComponent {
	return OpenuiComponent{
		name:        'Chart'
		description: 'A read-only chart. Types: bar, line, pie, doughnut.'
		params:      [
			OpenuiParam{
				name:   'type'
				schema: openui_schema_enum(['bar', 'line', 'pie', 'doughnut'])
			},
			OpenuiParam{
				name:   'labels'
				schema: openui_list_schema(openui_string_schema())
			},
			OpenuiParam{
				name:   'values'
				schema: openui_list_schema(openui_number_schema())
			},
			OpenuiParam{
				name:   'title'
				schema: openui_optional(openui_string_schema(), openui_string(''))
			},
			OpenuiParam{
				name:   'series'
				schema: openui_optional(openui_string_schema(), openui_string(''))
			},
		]
		height:      320
		render:      openui_render_chart
	}
}

// new_openui_default_library assembles the Tier-1 set with `Stack` as root.
// Import only what the model needs: fewer components means better output.

pub fn new_openui_default_library() OpenuiLibrary {
	return new_openui_library('Stack', [
		openui_stack_component(),
		openui_card_component(),
		openui_text_content_component(),
		openui_button_component(),
		openui_table_component(),
		openui_chart_component(),
	])
}
