module main

import ui2

// A gallery of the choice components: radio, rating, toggle, button group and
// stepper. Every component is controlled: the state below is the only state,
// each build derives the configs from it, and on_event decodes actions against
// those same configs before rebuilding.

const window_width = 1200
const window_height = 900
const col_a = 24.0
const col_b = 420.0
const col_c = 816.0
const col_width = 360.0

@[heap]
struct Gallery {
mut:
	dark    bool
	payment string = 'card'
	appear  string = 'light'
	score   string = '8'
	terms   bool
	stars   int  = 3
	score10 int  = 7
	bold    bool = true
	italic  bool
	visible bool     = true
	filters []string = ['starred', 'tagged']
	period  []string = ['week']
	marks   []string = ['bold', 'code']
	sizes   []string = ['m']
	layout  string   = 'grid'
	range   string   = 'week'
	align   string   = 'top'
	step    int      = 1
	setup   int      = 2
	message string   = 'Every control here is controlled by on_event.'
}

const gallery = &Gallery{}

fn app() &Gallery {
	return unsafe { gallery }
}

fn theme_of(g &Gallery) ui2.ComponentTheme {
	return ui2.component_theme(g.dark)
}

// ── Configs, shared by the build and by on_event ───────────────────

fn payment_config(g &Gallery) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:                  'payment'
		frame:               ui2.rect(col_a, 124, col_width, 138)
		selected:            g.payment
		accessibility_label: 'Payment method'
		theme:               theme_of(g)
		options:             [
			ui2.RadioOption{
				value:       'card'
				label:       'Credit card'
				description: 'Visa, Mastercard, American Express'
			},
			ui2.RadioOption{
				value:       'paypal'
				label:       'PayPal'
				description: 'Pay with your PayPal account'
			},
			ui2.RadioOption{
				value:       'bank'
				label:       'Bank transfer'
				description: 'Unavailable for this order'
				enabled:     false
			},
		]
	}
}

fn appear_config(g &Gallery) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:          'appear'
		frame:       ui2.rect(col_a, 296, col_width, 28)
		selected:    g.appear
		orientation: .horizontal
		theme:       theme_of(g)
		options:     [ui2.RadioOption{
			value: 'light'
			label: 'Light'
		}, ui2.RadioOption{
			value: 'dark'
			label: 'Dark'
		}, ui2.RadioOption{
			value: 'auto'
			label: 'Automatic'
		}]
	}
}

fn score_config(g &Gallery) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:          'score'
		frame:       ui2.rect(col_a, 358, col_width, 48)
		selected:    g.score
		orientation: .horizontal
		size:        .small
		theme:       theme_of(g)
		options:     []ui2.RadioOption{len: 11, init: ui2.RadioOption{
			label: index.str()
		}}
	}
}

fn disabled_radio_config(g &Gallery) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:          'disabled-radio'
		frame:       ui2.rect(col_a, 440, col_width, 28)
		selected:    'b'
		orientation: .horizontal
		enabled:     false
		theme:       theme_of(g)
		options:     [ui2.RadioOption{
			value: 'a'
			label: 'Option A'
		}, ui2.RadioOption{
			value: 'b'
			label: 'Option B'
		}, ui2.RadioOption{
			value: 'c'
			label: 'Option C'
		}]
	}
}

fn terms_config(g &Gallery) ui2.RadioConfig {
	return ui2.RadioConfig{
		id:      'terms'
		frame:   ui2.rect(col_a, 502, col_width, 28)
		label:   'I accept the terms'
		checked: g.terms
		theme:   theme_of(g)
	}
}

fn stars_config(g &Gallery) ui2.RatingConfig {
	return ui2.RatingConfig{
		id:    'stars'
		frame: ui2.rect(col_a, 594, ui2.rating_width(5, .medium), 26)
		value: g.stars
		theme: theme_of(g)
	}
}

fn score10_config(g &Gallery) ui2.RatingConfig {
	return ui2.RatingConfig{
		id:    'score10'
		frame: ui2.rect(col_a, 714, ui2.rating_width(10, .large), 32)
		value: g.score10
		max:   10
		tone:  .primary
		size:  .large
		theme: theme_of(g)
	}
}

fn bold_config(g &Gallery) ui2.ToggleConfig {
	return ui2.ToggleConfig{
		id:      'bold'
		frame:   ui2.rect(col_b, 124, ui2.styled_button_width('Bold', 'textformat', .medium), 32)
		label:   'Bold'
		icon:    'textformat'
		pressed: g.bold
		theme:   theme_of(g)
	}
}

fn italic_config(g &Gallery) ui2.ToggleConfig {
	return ui2.ToggleConfig{
		id:      'italic'
		frame:   ui2.rect(col_b + 104, 124, ui2.styled_button_width('Italic', '', .medium), 32)
		label:   'Italic'
		pressed: g.italic
		variant: .outline
		theme:   theme_of(g)
	}
}

fn visible_config(g &Gallery) ui2.ToggleConfig {
	return ui2.ToggleConfig{
		id:                  'visible'
		frame:               ui2.rect(col_b + 188, 124, 32, 32)
		icon:                if g.visible { 'eye' } else { 'eye.slash' }
		pressed:             g.visible
		accessibility_label: 'Visibility'
		variant:             .outline
		theme:               theme_of(g)
	}
}

fn locked_config(g &Gallery) ui2.ToggleConfig {
	return ui2.ToggleConfig{
		id:      'locked'
		frame:   ui2.rect(col_b + 228, 124, ui2.styled_button_width('Locked', 'lock', .medium), 32)
		label:   'Locked'
		icon:    'lock'
		pressed: true
		enabled: false
		variant: .outline
		theme:   theme_of(g)
	}
}

fn filters_config(g &Gallery) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:       'filters'
		frame:    ui2.rect(col_b, 196, col_width, 32)
		selected: g.filters
		theme:    theme_of(g)
		items:    [ui2.ToggleItem{
			value: 'starred'
			label: 'Starred'
			icon:  'star'
		}, ui2.ToggleItem{
			value: 'private'
			label: 'Private'
			icon:  'lock'
		}, ui2.ToggleItem{
			value: 'tagged'
			label: 'Tagged'
			icon:  'tag'
		}, ui2.ToggleItem{
			value:               'trash'
			icon:                'trash'
			accessibility_label: 'Trash'
		}]
	}
}

fn period_config(g &Gallery) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:          'period'
		frame:       ui2.rect(col_b, 268, col_width, 32)
		selected:    g.period
		multiple:    false
		allow_empty: false
		segmented:   true
		fill:        true
		variant:     .outline
		theme:       theme_of(g)
		items:       [ui2.ToggleItem{
			value: 'day'
			label: 'Day'
		}, ui2.ToggleItem{
			value: 'week'
			label: 'Week'
		}, ui2.ToggleItem{
			value: 'month'
			label: 'Month'
		}, ui2.ToggleItem{
			value: 'year'
			label: 'Year'
		}]
	}
}

fn marks_config(g &Gallery) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:        'marks'
		frame:     ui2.rect(col_b, 340, col_width, 32)
		selected:  g.marks
		segmented: true
		variant:   .outline
		theme:     theme_of(g)
		items:     [ui2.ToggleItem{
			value: 'bold'
			label: 'Bold'
		}, ui2.ToggleItem{
			value: 'italic'
			label: 'Italic'
		}, ui2.ToggleItem{
			value: 'code'
			label: 'Code'
		}, ui2.ToggleItem{
			value:   'strike'
			label:   'Strike'
			enabled: false
		}]
	}
}

fn small_toggles_config(g &Gallery) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:        'sizes'
		frame:     ui2.rect(col_b, 414, col_width, 24)
		selected:  g.sizes
		multiple:  false
		segmented: true
		size:      .small
		theme:     theme_of(g)
		items:     [ui2.ToggleItem{
			value: 's'
			label: 'Small'
		}, ui2.ToggleItem{
			value: 'm'
			label: 'Medium'
		}, ui2.ToggleItem{
			value: 'l'
			label: 'Large'
		}]
	}
}

fn large_toggles_config(g &Gallery) ui2.ToggleGroupConfig {
	return ui2.ToggleGroupConfig{
		id:       'large-toggles'
		frame:    ui2.rect(col_b, 450, col_width, 40)
		selected: g.marks
		size:     .large
		variant:  .outline
		theme:    theme_of(g)
		items:    [ui2.ToggleItem{
			value: 'bold'
			label: 'Bold'
		}, ui2.ToggleItem{
			value: 'italic'
			label: 'Italic'
		}, ui2.ToggleItem{
			value: 'code'
			label: 'Code'
		}]
	}
}

const group_x = col_c + 84
const group_width = col_width - 84

fn plain_group(id string, frame ui2.Rect, variant ui2.ButtonVariant, outline bool, size ui2.ComponentSize, labels []string, g &Gallery) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:      id
		frame:   frame
		variant: variant
		outline: outline
		size:    size
		theme:   theme_of(g)
		items:   labels.map(ui2.ButtonGroupItem{
			label: it
		})
	}
}

// action_groups are button groups whose buttons are plain actions.
fn action_groups(g &Gallery) []ui2.ButtonGroupConfig {
	return [
		plain_group('secondary', ui2.rect(group_x, 100, group_width, 32), .secondary, false,
			.medium, ['Archive', 'Report', 'Snooze'], g),
		plain_group('primary', ui2.rect(group_x, 140, group_width, 32), .primary, false, .medium,
			['Save', 'Save as', 'Export'], g),
		plain_group('outline', ui2.rect(group_x, 180, group_width, 32), .secondary, true, .medium,
			['Cut', 'Copy', 'Paste'], g),
		plain_group('small-group', ui2.rect(group_x, 300, group_width, 24), .success, false,
			.small, ['Small', 'Success'], g),
		plain_group('large-group', ui2.rect(group_x, 332, group_width, 40), .warning, false,
			.large, ['Large', 'Warning'], g),
		plain_group('danger', ui2.rect(group_x + 112, 384, group_width - 112, 32), .danger,
			false, .medium, ['Delete', 'Discard'], g),
	]
}

fn layout_config(g &Gallery) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:      'layout'
		frame:   ui2.rect(group_x, 260, group_width, 32)
		variant: .ghost
		theme:   theme_of(g)
		items:   [
			ui2.ButtonGroupItem{
				value:    'list'
				label:    'List'
				icon:     'line.3.horizontal'
				selected: g.layout == 'list'
			},
			ui2.ButtonGroupItem{
				value:    'grid'
				label:    'Grid'
				icon:     'rectangle.grid.2x2'
				selected: g.layout == 'grid'
			},
			ui2.ButtonGroupItem{
				value:    'table'
				label:    'Table'
				icon:     'tablecells'
				selected: g.layout == 'table'
			},
		]
	}
}

fn range_config(g &Gallery) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:      'range'
		frame:   ui2.rect(group_x, 220, group_width, 32)
		variant: .primary
		outline: true
		fill:    true
		theme:   theme_of(g)
		items:   ['day', 'week', 'month'].map(ui2.ButtonGroupItem{
			value:    it
			label:    it.capitalize()
			selected: g.range == it
		})
	}
}

fn align_config(g &Gallery) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:          'align'
		frame:       ui2.rect(group_x, 380, 96, 72)
		orientation: .vertical
		fill:        true
		size:        .small
		theme:       theme_of(g)
		items:       ['top', 'middle', 'bottom'].map(ui2.ButtonGroupItem{
			value:    it
			label:    it.capitalize()
			selected: g.align == it
		})
	}
}

fn disabled_group_config(g &Gallery) ui2.ButtonGroupConfig {
	return ui2.ButtonGroupConfig{
		id:      'disabled-group'
		frame:   ui2.rect(group_x + 112, 424, group_width - 112, 32)
		enabled: false
		outline: true
		theme:   theme_of(g)
		items:   [ui2.ButtonGroupItem{
			label: 'Undo'
		}, ui2.ButtonGroupItem{
			label: 'Redo'
		}]
	}
}

fn wizard_items() []ui2.StepperItem {
	return [
		ui2.StepperItem{
			title:       'Account'
			description: 'Name and email'
		},
		ui2.StepperItem{
			title:       'Shipping'
			description: 'Delivery address'
		},
		ui2.StepperItem{
			title:       'Payment'
			description: 'Card or transfer'
		},
		ui2.StepperItem{
			title:       'Review'
			description: 'Confirm the order'
		},
	]
}

fn wizard_config(g &Gallery) ui2.StepperConfig {
	return ui2.StepperConfig{
		id:      'wizard'
		frame:   ui2.rect(col_b, 624, 756, 72)
		items:   wizard_items()
		current: g.step
		theme:   theme_of(g)
	}
}

fn centered_config(g &Gallery) ui2.StepperConfig {
	return ui2.StepperConfig{
		id:          'centered'
		frame:       ui2.rect(col_b, 742, col_width, 56)
		items:       [ui2.StepperItem{
			title: 'Cart'
			icon:  'tag'
		}, ui2.StepperItem{
			title: 'Details'
			icon:  'pencil'
		}, ui2.StepperItem{
			title: 'Print'
			icon:  'printer'
		}]
		current:     g.step - 1
		text_center: true
		clickable:   false
		size:        .small
		theme:       theme_of(g)
	}
}

fn setup_config(g &Gallery) ui2.StepperConfig {
	return ui2.StepperConfig{
		id:          'setup'
		frame:       ui2.rect(col_c, 742, col_width, 140)
		items:       [
			ui2.StepperItem{
				title:       'Create project'
				description: 'Pick a name and a template.'
			},
			ui2.StepperItem{
				title:       'Invite team'
				description: 'Locked until billing is set up.'
				enabled:     false
			},
			ui2.StepperItem{
				title:       'Deploy'
				description: 'Ship the first build.'
			},
		]
		current:     g.setup
		orientation: .vertical
		size:        .small
		theme:       theme_of(g)
	}
}

// ── Build ──────────────────────────────────────────────────────────

fn section(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, col_width, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(text string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn build() ui2.Element {
	g := app()
	theme := theme_of(g)
	mut children := []ui2.Element{}
	children << ui2.label('', 'Choice components', ui2.rect(col_a, 18, 600, 34), ui2.TextStyle{
		color: theme.foreground
		size:  24
		bold:  true
	})
	children << ui2.styled_button(
		id:      'theme'
		frame:   ui2.rect(window_width - 24 - 136, 20, 136, 32)
		label:   if g.dark { 'Light theme' } else { 'Dark theme' }
		icon:    'paintpalette'
		outline: true
		theme:   theme
	) or { panic(err) }

	// Radio
	children << section('Radio', col_a, 72, theme)
	children << caption('Vertical, with descriptions and a disabled option', col_a, 100,
		col_width, theme)
	children << ui2.radio_group(payment_config(g)) or { panic(err) }
	children << caption('Horizontal', col_a, 272, col_width, theme)
	children << ui2.radio_group(appear_config(g)) or { panic(err) }
	children << caption('Small, wrapping onto a second row', col_a, 334, col_width, theme)
	children << ui2.radio_group(score_config(g)) or { panic(err) }
	children << caption('Disabled group', col_a, 416, col_width, theme)
	children << ui2.radio_group(disabled_radio_config(g)) or { panic(err) }
	children << caption('Single radio (cannot uncheck itself)', col_a, 478, col_width, theme)
	children << ui2.radio(terms_config(g)) or { panic(err) }

	// Rating
	children << section('Rating', col_a, 544, theme)
	children << caption('Click a star; clicking the last filled star lowers the value', col_a,
		572, col_width, theme)
	children << ui2.rating(stars_config(g)) or { panic(err) }
	children << ui2.label('', '${g.stars} / 5', ui2.rect(col_a + 140, 594, 80, 26), ui2.TextStyle{
		color: theme.foreground
		size:  14
	})
	children << ui2.rating(
		frame:    ui2.rect(col_a, 630, ui2.rating_width(5, .small), 26)
		value:    4
		readonly: true
		tone:     .success
		size:     .small
		theme:    theme
	) or { panic(err) }
	children << caption('Readonly, small, success tone', col_a + 110, 633, 200, theme)
	children << ui2.rating(
		frame:   ui2.rect(col_a, 662, ui2.rating_width(5, .medium), 26)
		value:   2
		enabled: false
		theme:   theme
	) or { panic(err) }
	children << caption('Disabled', col_a + 140, 665, 200, theme)
	children << caption('Large, 10 stars, primary tone', col_a, 692, col_width, theme)
	children << ui2.rating(score10_config(g)) or { panic(err) }

	// Toggle
	children << section('Toggle', col_b, 72, theme)
	children << caption('Ghost with icon, outline, icon only, disabled', col_b, 100, col_width,
		theme)
	children << ui2.toggle(bold_config(g)) or { panic(err) }
	children << ui2.toggle(italic_config(g)) or { panic(err) }
	children << ui2.toggle(visible_config(g)) or { panic(err) }
	children << ui2.toggle(locked_config(g)) or { panic(err) }
	children << caption('Toggle group: multiple selection, ghost, icons', col_b, 172, col_width,
		theme)
	children << ui2.toggle_group(filters_config(g)) or { panic(err) }
	children << caption('Segmented, single selection, filling its frame', col_b, 244, col_width,
		theme)
	children << ui2.toggle_group(period_config(g)) or { panic(err) }
	children << caption('Segmented, multiple selection, one item disabled', col_b, 316,
		col_width, theme)
	children << ui2.toggle_group(marks_config(g)) or { panic(err) }
	children << caption('Small ghost segmented; large outline', col_b, 390, col_width, theme)
	children << ui2.toggle_group(small_toggles_config(g)) or { panic(err) }
	children << ui2.toggle_group(large_toggles_config(g)) or { panic(err) }

	// Button group
	children << section('Button group', col_c, 72, theme)
	for i, name in ['Secondary', 'Primary', 'Outline', 'Selected', 'Ghost', 'Sizes', 'Vertical'] {
		children << caption(name, col_c, [106.0, 146, 186, 226, 266, 304, 386][i], 80, theme)
	}
	for config in action_groups(g) {
		children << ui2.button_group(config) or { panic(err) }
	}
	children << ui2.button_group(range_config(g)) or { panic(err) }
	children << ui2.button_group(layout_config(g)) or { panic(err) }
	children << ui2.button_group(align_config(g)) or { panic(err) }
	children << ui2.button_group(disabled_group_config(g)) or { panic(err) }
	children << caption('Styled buttons', col_c, 466, 120, theme)
	variants := [ui2.ButtonVariant.primary, .secondary, .ghost, .danger]
	labels := ['Primary', 'Secondary', 'Ghost', 'Danger']
	mut x := col_c
	for i, variant in variants {
		width := ui2.styled_button_width(labels[i], '', .medium)
		children << ui2.styled_button(
			id:      'styled-${labels[i].to_lower()}'
			frame:   ui2.rect(x, 488, width, 32)
			label:   labels[i]
			variant: variant
			theme:   theme
		) or { panic(err) }
		x += width + 8
	}
	outline_width := ui2.styled_button_width('Outline', 'plus', .medium)
	children << ui2.styled_button(
		id:      'styled-outline'
		frame:   ui2.rect(col_c, 528, outline_width, 32)
		label:   'Outline'
		icon:    'plus'
		variant: .primary
		outline: true
		theme:   theme
	) or { panic(err) }
	children << ui2.styled_button(
		id:      'styled-disabled'
		frame:   ui2.rect(col_c + outline_width + 8, 528, ui2.styled_button_width('Disabled',
			'', .medium), 32)
		label:   'Disabled'
		variant: .primary
		enabled: false
		theme:   theme
	) or { panic(err) }

	// Stepper
	children << section('Stepper', col_b, 572, theme)
	children << caption('Horizontal, clickable steps, with descriptions', col_b, 600, 400, theme)
	children << ui2.stepper(wizard_config(g)) or { panic(err) }
	children << ui2.styled_button(
		id:      'back'
		frame:   ui2.rect(col_b + 280, 572, 72, 28)
		label:   'Back'
		enabled: g.step > 0
		size:    .small
		theme:   theme
	) or { panic(err) }
	children << ui2.styled_button(
		id:      'next'
		frame:   ui2.rect(col_b + 360, 572, 76, 28)
		label:   if g.step >= 3 { 'Finish' } else { 'Next' }
		variant: .primary
		enabled: g.step < 4
		size:    .small
		theme:   theme
	) or { panic(err) }
	children << caption('Text centered, icons, small, display only', col_b, 718, col_width,
		theme)
	children << ui2.stepper(centered_config(g)) or { panic(err) }
	children << caption('Vertical, small, with a disabled step', col_c, 718, col_width, theme)
	children << ui2.stepper(setup_config(g)) or { panic(err) }

	children << ui2.label('', 'Keys: Left/Right step the wizard, Up/Down move the payment choice and digits 0-5 rate.',
		ui2.rect(col_a, 776, col_width, 36), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			lines:  2
			valign: .top
		})
	children << ui2.label('', g.message, ui2.rect(col_a, 820, col_width, 40), ui2.TextStyle{
		color:  theme.foreground
		size:   13
		lines:  2
		valign: .top
	})
	return ui2.screen(theme.background, children)
}

// ── Events ─────────────────────────────────────────────────────────

fn action_group_value(g &Gallery, action string) ?string {
	for config in action_groups(g) {
		if value := ui2.button_group_value_from_action(config, action) {
			return value
		}
	}
	return none
}

fn on_event(action string) {
	mut g := app()
	if value := ui2.radio_group_value_from_action(payment_config(g), action) {
		g.payment = value
		g.message = 'Payment method: ${value}.'
	} else if value := ui2.radio_group_value_from_action(appear_config(g), action) {
		g.appear = value
		g.message = 'Appearance: ${value}.'
	} else if value := ui2.radio_group_value_from_action(score_config(g), action) {
		g.score = value
		g.message = 'Recommendation score: ${value}.'
	} else if _ := ui2.radio_checked_from_action(terms_config(g), action) {
		g.terms = true
		g.message = 'Terms accepted. A radio cannot uncheck itself.'
	} else if value := ui2.rating_value_from_action(stars_config(g), action) {
		g.stars = value
		g.message = 'Rated ${value} of 5.'
	} else if value := ui2.rating_value_from_action(score10_config(g), action) {
		g.score10 = value
		g.message = 'Rated ${value} of 10.'
	} else if pressed := ui2.toggle_pressed_from_action(bold_config(g), action) {
		g.bold = pressed
	} else if pressed := ui2.toggle_pressed_from_action(italic_config(g), action) {
		g.italic = pressed
	} else if pressed := ui2.toggle_pressed_from_action(visible_config(g), action) {
		g.visible = pressed
	} else if selection := ui2.toggle_group_selection_from_action(filters_config(g), action) {
		g.filters = selection
		g.message = 'Filters: ${selection}.'
	} else if selection := ui2.toggle_group_selection_from_action(period_config(g), action) {
		g.period = selection
		g.message = 'Period: ${selection}.'
	} else if selection := ui2.toggle_group_selection_from_action(marks_config(g), action) {
		g.marks = selection
		g.message = 'Formatting: ${selection}.'
	} else if selection := ui2.toggle_group_selection_from_action(large_toggles_config(g),
		action)
	{
		g.marks = selection
		g.message = 'Formatting: ${selection}.'
	} else if selection := ui2.toggle_group_selection_from_action(small_toggles_config(g),
		action)
	{
		g.sizes = selection
		g.message = 'Size: ${selection}.'
	} else if value := ui2.button_group_value_from_action(range_config(g), action) {
		g.range = value
		g.message = 'Range: ${value}.'
	} else if value := ui2.button_group_value_from_action(layout_config(g), action) {
		g.layout = value
		g.message = 'Layout: ${value}.'
	} else if value := ui2.button_group_value_from_action(align_config(g), action) {
		g.align = value
		g.message = 'Alignment: ${value}.'
	} else if value := action_group_value(g, action) {
		g.message = 'Clicked ${value}.'
	} else if step := ui2.stepper_step_from_action(wizard_config(g), action) {
		g.step = step
		g.message = 'Jumped to step ${step + 1}.'
	} else if step := ui2.stepper_step_from_action(setup_config(g), action) {
		g.setup = step
		g.message = 'Setup step ${step + 1}.'
	} else {
		match action {
			'theme' {
				g.dark = !g.dark
			}
			'back' {
				if step := ui2.stepper_previous_step(wizard_config(g)) {
					g.step = step
				}
			}
			'next' {
				g.step = ui2.stepper_next_step(wizard_config(g)) or { 4 }
				g.message = if g.step >= 4 { 'All steps completed.' } else { 'Step ${g.step + 1}.' }
			}
			else {
				// Component actions the decoders turned down (an option that is
				// already selected, say) change nothing.
				if action.contains(':component:') {
					return
				}
				g.message = 'Clicked ${action}.'
			}
		}
	}
	ui2.refresh()
}

// Components cannot capture keys, so the application routes them: here the
// arrow keys and digits drive three components through their key helpers.
fn on_key(event ui2.KeyEvent) {
	if event.cmd || event.ctrl || event.alt {
		return
	}
	mut g := app()
	if step := ui2.stepper_step_after_key(wizard_config(g), event.code) {
		g.step = step
		g.message = 'Keyboard: step ${step + 1}.'
	} else if value := ui2.radio_group_value_after_key(payment_config(g), event.code) {
		g.payment = value
		g.message = 'Keyboard: payment method ${value}.'
	} else if event.code !in [.left, .right, .up, .down, .home, .end] {
		// Digits only: the arrows already belong to the stepper and the radio group.
		value := ui2.rating_value_after_key(stars_config(g), event.code) or { return }
		g.stars = value
		g.message = 'Keyboard: rated ${value} of 5.'
	} else {
		return
	}
	ui2.consume_key()
	ui2.refresh()
}

fn main() {
	ui2.on_key_event(on_key)
	ui2.run_window('ui2 choice components', window_width, window_height, build, on_event)
}
