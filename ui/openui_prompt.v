module ui2

// OpenUI Lang system prompt: serialized instructions generated from the
// registered library, so the model writes components the renderer accepts.

pub struct OpenuiPromptOptions {
pub:
	preamble          string
	additional_rules  []string
	examples          []string
	tools             []string
	tool_calls        bool = true
	bindings          bool = true
	builtin_functions bool
	edit_mode         bool
	inline_mode       bool
}

fn openui_schema_text(schema OpenuiSchema) string {
	base := match schema.kind {
		.string_ {
			if schema.enum_values.len > 0 {
				'"' + schema.enum_values.join('" | "') + '"'
			} else {
				'string'
			}
		}
		.number { 'number' }
		.bool_ { 'boolean' }
		.list {
			if !isnil(schema.element) {
				openui_schema_text(*schema.element) + '[]'
			} else {
				'any[]'
			}
		}
		.action { 'ActionExpression' }
		.bind { '$var' }
		.object {
			if schema.ref_component.len > 0 {
				schema.ref_component
			} else {
				'any'
			}
		}
		.null_ { 'null' }
		.invalid { 'any' }
	}
	if schema.optional {
		return base + '?'
	}
	return base
}

fn openui_component_signature(component OpenuiComponent) string {
	mut parts := []string{}
	for param in component.params {
		optional := if param.schema.optional { '?' } else { '' }
		parts << '${param.name}${optional}: ${openui_schema_text(param.schema)}'
	}
	return '${component.name}(${parts.join(', ')}) — ${component.description}'
}

fn openui_builtin_reference() string {
	return '@Count(array) → number; @Sum(numbers) → number; @Avg(numbers) → number; ' +
		'@Min(array) → number; @Max(array) → number; @First(array); @Last(array); ' +
		'@Filter(array, field, op, value) ops ==, !=, >, <, >=, <=, contains; ' +
		'@Sort(array, field, direction?); @Round(number, decimals?); @Abs(number); ' +
		'@Floor(number); @Ceil(number); @Each(array, varName, template)'
}

fn openui_action_reference(library OpenuiLibrary) string {
	mut lines := ['@ToAssistant(message, context?) — send follow-up to the model',
		'@OpenUrl(url) — open a link', '@Set(\$var, value)', '@Reset(\$a, \$b)',
		'@Run(ref) — run a Mutation or re-fetch a Query']
	for action in library.actions {
		mut parts := []string{}
		for param in action.params {
			parts << '${param.name}: ${openui_schema_text(param.schema)}'
		}
		lines << '@${action.name}(${parts.join(', ')}) — ${action.description}'
	}
	return lines.join('\n')
}

pub fn openui_library_spec(library OpenuiLibrary) string {
	mut lines := []string{}
	lines << 'root component: ${library.root}'
	for component in library.components {
		lines << openui_component_signature(component)
	}
	return lines.join('\n')
}

// generate_system_prompt renders the model instructions for a library. It
// has no LLM or network dependency: the host sends the result as the system
// prompt and streams the model's OpenUI Lang response into the renderer.

pub fn generate_system_prompt(library OpenuiLibrary, options OpenuiPromptOptions) string {
	mut lines := []string{}
	if options.preamble.len > 0 {
		lines << options.preamble
	} else {
		lines << 'You output only OpenUI Lang.'
	}
	lines << ''
	lines << '## Syntax'
	lines << 'One statement per line: `identifier = Expression`.'
	lines << 'Positional args map to props in declaration order; `null` skips an optional.'
	lines << 'Forward references are allowed. Last definition wins for duplicates.'
	lines << 'Every program defines `root = ${library.root}(...)`.'
	lines << 'Only `Action([...])` runs without `@`; everything else needs it.'
	lines << ''
	if library.groups.len > 0 {
		for group in library.groups {
			lines << '### ${group.name}'
			for name in group.components {
				component := library.find(name) or { continue }
				lines << openui_component_signature(component)
			}
			for note in group.notes {
				lines << note
			}
			lines << ''
		}
	} else {
		lines << '### Components'
		for component in library.components {
			lines << openui_component_signature(component)
		}
		lines << ''
	}
	needs_builtins := options.tool_calls || options.bindings || options.builtin_functions
	if needs_builtins {
		lines << '### Built-in functions'
		lines << openui_builtin_reference()
		lines << ''
	}
	if library.functions.len > 0 {
		lines << '### Custom functions'
		for function in library.functions {
			mut parts := []string{}
			for param in function.params {
				parts << '${param.name}: ${openui_schema_text(param.schema)}'
			}
			lines << '@${function.name}(${parts.join(', ')}) — ${function.description}'
		}
		lines << ''
	}
	lines << '### Actions'
	lines << openui_action_reference(library)
	lines << ''
	if options.tool_calls {
		lines << '### Data'
		lines << '`name = Query("tool", {args}, {defaults}, refresh?)` reads; it runs on load and re-fetches when `$vars` in args change.'
		lines << '`name = Mutation("tool", {args})` writes; run it with `@Run(name)` inside `Action([...])`. Steps run in order; a failed mutation stops the rest.'
		if options.tools.len > 0 {
			lines << 'Tools:'
			for tool in options.tools {
				lines << '- ${tool}'
			}
		}
		lines << ''
	}
	if options.bindings {
		lines << '### State'
		lines << 'Declare with `\$name = default`. Passing `\$name` to an input binds it; edits re-evaluate dependents.'
		lines << ''
	}
	lines << '### Streaming'
	lines << 'Emit layout first, then components, then data. `root` comes first so the shell renders while children stream.'
	lines << ''
	if options.edit_mode {
		lines << 'Edit mode: output only changed statements.'
		lines << ''
	}
	if options.inline_mode {
		lines << 'Inline mode: plain text answers are allowed without UI code.'
		lines << ''
	}
	for rule in options.additional_rules {
		lines << rule
	}
	if options.additional_rules.len > 0 {
		lines << ''
	}
	if options.examples.len > 0 {
		lines << '### Examples'
		for example in options.examples {
			lines << example
		}
		lines << ''
	}
	return lines.join('\n')
}
