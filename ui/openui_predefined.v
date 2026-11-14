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

// new_openui_default_library assembles the Tier-1 set with `Stack` as root.
// Import only what the model needs: fewer components means better output.

pub fn new_openui_default_library() OpenuiLibrary {
	return new_openui_library('Stack', [
		openui_stack_component(),
		openui_card_component(),
		openui_text_content_component(),
		openui_button_component(),
	])
}
