module main

import os
import ui2

// Forms built with ui2.form: a registration form with labels above the
// controls and validation after a submit attempt, a settings form with labels
// beside the controls and sections, a four-column address form with spans, a
// column start and conditional fields, and a single field laid out by
// form_field. Every control is an ordinary ui2 control that the application
// builds in the frame the form gives it; the application owns every value,
// validates with the form helpers and decodes the action rows with
// form_event. Start with UI2_FORM_DARK=1 for the dark theme.

const window_width = 1440
const window_height = 900

const card_y = 92.0
const card_pad = 20.0
const form_top = card_y + 78
const register_x = 24.0
const register_w = 344.0
const settings_x = 388.0
const settings_w = 456.0
const shipping_x = 864.0
const shipping_w = 552.0
// The newsletter card sits over the address card, which grows downwards
// when its messages show.
const newsletter_h = 148.0
const shipping_y = card_y + newsletter_h + 16

const bio_limit = 160

@[heap]
struct FormDemo {
mut:
	dark   bool
	status string = 'Create account was pressed with problems: the registration form shows what to fix.'
	// Registration. A submit has been attempted, so its messages show.
	first         string = 'Ada'
	last          string
	email         string = 'ada@lovelace'
	password      string = 'engine'
	confirm       string = 'engine'
	birthday      ui2.CalendarState
	birthday_open bool
	terms         bool
	tried         bool = true
	// Settings, and what Reset goes back to.
	settings       Settings
	saved          Settings
	settings_tried bool
	// Shipping.
	full_name      string
	phone          string
	street         string
	apt            string
	country        []string = ['us']
	country_state  ui2.SelectState
	region         string = 'California'
	zip            string
	city           string
	speed          string = 'standard'
	gift           bool
	gift_message   string
	shipping_tried bool
	// Newsletter.
	newsletter       string
	newsletter_tried bool
	subscribed       string
	// Work that has to wait for the rebuilt tree.
	focus_id  string
	sync_id   string
	sync_text string
}

struct Settings {
mut:
	display   string = 'Ada Lovelace'
	username  string = 'ada'
	bio       string = 'Mathematician. Wrote the first published algorithm, for the Analytical Engine.'
	updates   bool   = true
	frequency string = 'weekly'
	language  string = 'English'
	text_size string = '14'
}

const demo = &FormDemo{
	dark: os.getenv('UI2_FORM_DARK') == '1'
}

fn app() &FormDemo {
	return unsafe { demo }
}

fn theme_of(a &FormDemo) ui2.ComponentTheme {
	return ui2.component_theme(a.dark)
}

fn window_rect() ui2.Rect {
	b := ui2.bounds()
	if b.width > 0 && b.height > 0 {
		return b
	}
	return ui2.rect(0, 0, window_width, window_height)
}

// ── Controls ────────────────────────────────────────────────────────

fn field_box(theme ui2.ComponentTheme, invalid bool) ui2.BoxStyle {
	return ui2.BoxStyle{
		bg:            theme.background
		radius:        6
		border_color:  if invalid { theme.danger } else { theme.border }
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}
}

fn field_text(theme ui2.ComponentTheme) ui2.TextStyle {
	return ui2.TextStyle{
		color: theme.foreground
		size:  14
	}
}

// Input describes a change-emitting text field; Return in it submits the
// form named by submit.
struct Input {
	id          string
	placeholder string
	value       string
	invalid     bool
	secure      bool
	submit      string
	theme       ui2.ComponentTheme
}

fn (i Input) build(frame ui2.Rect) ui2.Element {
	field := ui2.text_field_with_change_and_submit(i.id, i.submit, i.placeholder, i.value,
		frame, field_box(i.theme, i.invalid), field_text(i.theme), ui2.keyboard_default)
	return ui2.Element{
		...field
		secure: i.secure
	}
}

// control is the field's control: the form calls it with the frame to fill.
fn (i Input) control() ui2.FormSlotFn {
	return fn [i] (frame ui2.Rect) !ui2.Element {
		return i.build(frame)
	}
}

// checkbox_control is a native checkbox titled in the theme's text style.
fn checkbox_control(id string, title string, checked bool, theme ui2.ComponentTheme) ui2.FormSlotFn {
	return fn [id, title, checked, theme] (frame ui2.Rect) !ui2.Element {
		return ui2.checkbox(id, title, checked, frame, field_text(theme))
	}
}

// bordered_text_area is a text area with the border text fields have. AppKit
// window captures leave out a text area's own border, so there it sits inside
// a bordered view; the custom renderer draws the border itself.
fn bordered_text_area(id string, value string, frame ui2.Rect, invalid bool, theme ui2.ComponentTheme) ui2.Element {
	$if !ui2_custom_rendering ?&& macos {
		inner := ui2.rect(3, 3, frame.width - 6, frame.height - 6)
		return ui2.view('', frame, field_box(theme, invalid), [
			ui2.text_area(id, value, inner, ui2.BoxStyle{
				bg: theme.background
			}, field_text(theme)),
		])
	} $else {
		return ui2.text_area(id, value, frame, field_box(theme, invalid), field_text(theme))
	}
}

// radio_strip centers a one-line radio group on a control-high frame.
fn radio_strip(frame ui2.Rect) ui2.Rect {
	height := 26.0
	return ui2.rect(frame.x, frame.y + (frame.height - height) / 2, frame.width, height)
}

fn dropdown_control(id string, value string, options []string, theme ui2.ComponentTheme) ui2.FormSlotFn {
	return fn [id, value, options, theme] (frame ui2.Rect) !ui2.Element {
		return ui2.dropdown(id, value, options, frame, field_box(theme, false), field_text(theme))
	}
}

fn error_of(errors map[string]string, id string) string {
	return errors[id] or { '' }
}

// ── Registration: labels above, validated after a submit attempt ─────

fn register_errors(a &FormDemo) map[string]string {
	mut errors := ui2.form_validate([
		ui2.FormValue{
			field: 'email'
			label: 'Email'
			value: a.email
			rules: [ui2.form_required(), ui2.form_email()]
		},
		ui2.FormValue{
			field: 'password'
			label: 'Password'
			value: a.password
			rules: [ui2.form_required(), ui2.form_min_length(8)]
		},
		ui2.FormValue{
			field: 'confirm'
			label: 'Confirm password'
			value: a.confirm
			rules: [ui2.form_required(),
				ui2.form_equals(a.password).with_message('The passwords do not match.')]
		},
		ui2.FormValue{
			field: 'terms'
			value: if a.terms { 'yes' } else { '' }
			rules: [ui2.form_required().with_message('Accept the terms to create an account.')]
		},
	])
	// Checks of the application's own sit beside the helpers.
	if a.first.trim_space().len == 0 || a.last.trim_space().len == 0 {
		errors['name'] = 'Enter your first and last name.'
	}
	if 'password' !in errors && !a.password.bytes().any(it.is_digit()) {
		errors['password'] = 'Add at least one number.'
	}
	return errors
}

fn register_config(a &FormDemo) ui2.FormConfig {
	theme := theme_of(a)
	errors := if a.tried { register_errors(a) } else { map[string]string{} }
	submit := ui2.form_submit_action('register')
	first := Input{
		id:          'first'
		placeholder: 'First name'
		value:       a.first
		invalid:     'name' in errors && a.first.trim_space().len == 0
		submit:      submit
		theme:       theme_of(a)
	}
	last := Input{
		...first
		id:          'last'
		placeholder: 'Last name'
		value:       a.last
		invalid:     'name' in errors && a.last.trim_space().len == 0
	}
	return ui2.FormConfig{
		id:            'register'
		frame:         ui2.rect(register_x + card_pad, form_top, register_w - 2 * card_pad,
			0)
		theme:         theme
		fields:        [
			ui2.FormField{
				id:       'name'
				label:    'Name'
				required: true
				error:    error_of(errors, 'name')
				// Two controls in one field: form_split shares the frame.
				control:  fn [first, last] (frame ui2.Rect) !ui2.Element {
					parts := ui2.form_split(frame, [0.0, 0], 8)
					return ui2.view('', frame, ui2.BoxStyle{
						transparent: true
					}, [first.build(parts[0]), last.build(parts[1])])
				}
			},
			ui2.FormField{
				id:          'email'
				label:       'Email'
				required:    true
				description: 'We will send a confirmation link.'
				error:       error_of(errors, 'email')
				control:     Input{
					...first
					id:          'email'
					placeholder: 'you@example.com'
					value:       a.email
					invalid:     'email' in errors
				}.control()
			},
			ui2.FormField{
				id:          'password'
				label:       'Password'
				required:    true
				description: 'At least 8 characters, with a number.'
				error:       error_of(errors, 'password')
				control:     Input{
					...first
					id:          'password'
					placeholder: 'Password'
					value:       a.password
					invalid:     'password' in errors
					secure:      true
				}.control()
			},
			ui2.FormField{
				id:       'confirm'
				label:    'Confirm password'
				required: true
				error:    error_of(errors, 'confirm')
				control:  Input{
					...first
					id:          'confirm'
					placeholder: 'Password again'
					value:       a.confirm
					invalid:     'confirm' in errors
					secure:      true
				}.control()
			},
			ui2.FormField{
				id:          'birthday'
				label:       'Birthday'
				description: 'We will send you a birthday gift!'
				control:     fn [a] (frame ui2.Rect) !ui2.Element {
					return ui2.date_picker(ui2.DatePickerConfig{
						...birthday_config(a)
						frame: frame
					})
				}
			},
			ui2.FormField{
				id:           'terms'
				label_indent: false
				height:       24
				error:        error_of(errors, 'terms')
				control:      checkbox_control('terms', 'I agree to the Terms of Service',
					a.terms, theme)
			},
		]
		actions:       [
			ui2.FormAction{
				id:    'create'
				label: 'Create account'
				kind:  .submit
			},
		]
		actions_align: .stretch
	}
}

// birthday_config anchors the picker's popover at the control the form placed.
fn birthday_config(a &FormDemo) ui2.DatePickerConfig {
	anchor := ui2.form_control_frame(register_config(a), 'birthday') or { ui2.Rect{} }
	win := window_rect()
	today := ui2.calendar_today()
	return ui2.DatePickerConfig{
		id:                  'birthday'
		frame:               anchor
		anchor:              anchor
		calendar:            ui2.CalendarConfig{
			state: a.birthday
			today: today
			max:   today
		}
		open:                a.birthday_open
		window_width:        win.width
		window_height:       win.height
		format:              '%B %-d, %Y'
		placeholder:         'Pick a date'
		clearable:           true
		accessibility_label: 'Birthday'
		theme:               theme_of(a)
	}
}

// ── Settings: labels beside, sections, Reset and Save ────────────────

fn settings_errors(s Settings) map[string]string {
	return ui2.form_validate([
		ui2.FormValue{
			field: 'display'
			label: 'Display name'
			value: s.display
			rules: [ui2.form_required(), ui2.form_max_length(40)]
		},
		ui2.FormValue{
			field: 'username'
			label: 'Username'
			value: s.username
			rules: [ui2.form_required(), ui2.form_min_length(3), ui2.form_alphanumeric()]
		},
		ui2.FormValue{
			field: 'bio'
			label: 'Bio'
			value: s.bio
			rules: [ui2.form_max_length(bio_limit)]
		},
		ui2.FormValue{
			field: 'text_size'
			label: 'Text size'
			value: s.text_size
			rules: [ui2.form_required(), ui2.form_number(10, 24)]
		},
	])
}

fn settings_config(a &FormDemo) ui2.FormConfig {
	theme := theme_of(a)
	s := a.settings
	errors := if a.settings_tried { settings_errors(s) } else { map[string]string{} }
	submit := ui2.form_submit_action('settings')
	fields_theme := theme_of(a)
	bio_count := s.bio.runes().len
	return ui2.FormConfig{
		id:           'settings'
		frame:        ui2.rect(settings_x + card_pad, form_top, settings_w - 2 * card_pad,
			0)
		label_layout: .horizontal
		label_width:  112
		label_align:  .right
		theme:        theme
		fields:       [
			ui2.FormField{
				id:          'profile'
				kind:        .section
				label:       'Profile'
				description: 'How other people see you.'
			},
			ui2.FormField{
				id:       'display'
				label:    'Display name'
				required: true
				error:    error_of(errors, 'display')
				control:  Input{
					id:      'display'
					value:   s.display
					invalid: 'display' in errors
					submit:  submit
					theme:   fields_theme
				}.control()
			},
			ui2.FormField{
				id:          'username'
				label:       'Username'
				required:    true
				description: 'Letters and digits only.'
				error:       error_of(errors, 'username')
				control:     fn [a] (frame ui2.Rect) !ui2.Element {
					return ui2.input_group(ui2.InputGroupConfig{
						...username_config(a)
						frame: frame
					})
				}
			},
			ui2.FormField{
				id:             'bio'
				label:          'Bio'
				height:         64
				align:          .start
				error:          error_of(errors, 'bio')
				control:        fn [s, fields_theme] (frame ui2.Rect) !ui2.Element {
					return bordered_text_area('bio', s.bio, frame, s.bio.runes().len > bio_limit,
						fields_theme)
				}
				// A dynamic description: a note and a live character count.
				description_fn: fn [bio_count, theme] (frame ui2.Rect) !ui2.Element {
					count_width := 64.0
					return ui2.view('', frame, ui2.BoxStyle{
						transparent: true
					}, [
						ui2.label('', 'Shown on your profile.', ui2.rect(0, 0, frame.width - count_width,
							frame.height), ui2.TextStyle{
							color:  theme.muted_foreground
							size:   12
							valign: .top
						}),
						ui2.label('', '${bio_count} / ${bio_limit}', ui2.rect(frame.width - count_width,
							0, count_width, frame.height), ui2.TextStyle{
							color:  if bio_count > bio_limit {
								theme.danger
							} else {
								theme.muted_foreground
							}
							size:   12
							align:  .right
							valign: .top
						}),
					])
				}
			},
			ui2.FormField{
				id:    'member'
				label: 'Member since'
				text:  'March 2024'
			},
			ui2.FormField{
				id:    'notifications'
				kind:  .section
				label: 'Notifications'
			},
			ui2.FormField{
				id:      'updates'
				label:   'Email updates'
				control: fn [s] (frame ui2.Rect) !ui2.Element {
					return ui2.switch_control(ui2.SwitchConfig{
						id:     'updates'
						frame:  ui2.rect(frame.x, frame.y + (frame.height - 24) / 2, 40, 24)
						active: s.updates
					})
				}
			},
			// Shown only while updates are on.
			ui2.FormField{
				id:      'frequency'
				label:   'Frequency'
				visible: s.updates
				control: fn [a] (frame ui2.Rect) !ui2.Element {
					return ui2.radio_group(ui2.RadioGroupConfig{
						...frequency_config(a)
						frame: radio_strip(frame)
					})
				}
			},
			ui2.FormField{
				id:    'appearance'
				kind:  .section
				label: 'Appearance'
			},
			ui2.FormField{
				id:      'language'
				label:   'Language'
				control: dropdown_control('language', s.language, [
					'English',
					'Deutsch',
					'Español',
					'Français',
					'日本語',
				], theme)
			},
			ui2.FormField{
				id:          'text_size'
				label:       'Text size'
				description: 'From 10 to 24 points.'
				error:       error_of(errors, 'text_size')
				control:     fn [a, errors] (frame ui2.Rect) !ui2.Element {
					return ui2.number_input(ui2.NumberInputConfig{
						...text_size_config(a)
						frame:   ui2.rect(frame.x, frame.y, 140, frame.height)
						invalid: 'text_size' in errors
					})
				}
			},
		]
		actions:      [
			ui2.FormAction{
				id:      'reset'
				label:   'Reset'
				kind:    .reset
				enabled: a.settings != a.saved
			},
			ui2.FormAction{
				id:    'save'
				label: 'Save changes'
				kind:  .submit
			},
		]
	}
}

fn username_config(a &FormDemo) ui2.InputGroupConfig {
	errors := if a.settings_tried { settings_errors(a.settings) } else { map[string]string{} }
	return ui2.InputGroupConfig{
		id:                  'username'
		text:                a.settings.username
		placeholder:         'username'
		invalid:             'username' in errors
		accessibility_label: 'Username'
		addons:              [
			ui2.InputGroupAddon{
				id:   'at'
				kind: .text
				text: '@'
			},
		]
		theme:               theme_of(a)
	}
}

fn frequency_config(a &FormDemo) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:                  'frequency'
		selected:            a.settings.frequency
		orientation:         .horizontal
		accessibility_label: 'Frequency'
		options:             [
			ui2.RadioOption{
				value: 'daily'
				label: 'Daily'
			},
			ui2.RadioOption{
				value: 'weekly'
				label: 'Weekly'
			},
			ui2.RadioOption{
				value: 'monthly'
				label: 'Monthly'
			},
		]
		theme:               theme_of(a)
	}
}

fn text_size_config(a &FormDemo) ui2.NumberInputConfig {
	return ui2.NumberInputConfig{
		id:                  'text_size'
		text:                a.settings.text_size
		min:                 10
		max:                 24
		precision:           0
		accessibility_label: 'Text size'
		theme:               theme_of(a)
	}
}

// ── Shipping: four columns, spans, a column start, conditional fields ─

fn shipping_errors(a &FormDemo) map[string]string {
	us := a.country == ['us']
	return ui2.form_validate([
		ui2.FormValue{
			field: 'full_name'
			label: 'Full name'
			value: a.full_name
			rules: [ui2.form_required()]
		},
		ui2.FormValue{
			field: 'phone'
			label: 'Phone'
			value: a.phone
			rules: [
				ui2.form_pattern('###-###-####|(###) ###-####|##########').with_message('Use a number like 555-123-4567.'),
			]
		},
		ui2.FormValue{
			field: 'street'
			label: 'Street address'
			value: a.street
			rules: [ui2.form_required()]
		},
		ui2.FormValue{
			field: 'country'
			label: 'Country'
			value: a.country.join('')
			rules: [ui2.form_required()]
		},
		ui2.FormValue{
			field: 'zip'
			label: if us { 'ZIP code' } else { 'Postal code' }
			value: a.zip
			rules: if us {
				[ui2.form_required(),
					ui2.form_pattern('#####|#####-####').with_message('Use 5 digits, or 5+4.')]
			} else {
				[ui2.form_required()]
			}
		},
		ui2.FormValue{
			field: 'city'
			label: 'City'
			value: a.city
			rules: [ui2.form_required()]
		},
		ui2.FormValue{
			field: 'gift_message'
			label: 'Gift message'
			value: if a.gift { a.gift_message } else { '' }
			rules: [ui2.form_max_length(120)]
		},
	])
}

fn shipping_config(a &FormDemo) ui2.FormConfig {
	theme := theme_of(a)
	errors := if a.shipping_tried { shipping_errors(a) } else { map[string]string{} }
	us := a.country == ['us']
	base := Input{
		submit: ui2.form_submit_action('shipping')
		theme:  theme_of(a)
	}
	return ui2.FormConfig{
		id:      'shipping'
		frame:   ui2.rect(shipping_x + card_pad, shipping_y + form_top - card_y, shipping_w - 2 * card_pad,
			0)
		columns: 4
		theme:   theme
		fields:  [
			ui2.FormField{
				id:       'full_name'
				label:    'Full name'
				required: true
				col_span: 2
				error:    error_of(errors, 'full_name')
				control:  Input{
					...base
					id:          'full_name'
					placeholder: 'Ada Lovelace'
					value:       a.full_name
					invalid:     'full_name' in errors
				}.control()
			},
			ui2.FormField{
				id:       'phone'
				label:    'Phone'
				col_span: 2
				error:    error_of(errors, 'phone')
				control:  Input{
					...base
					id:          'phone'
					placeholder: '555-123-4567'
					value:       a.phone
					invalid:     'phone' in errors
				}.control()
			},
			ui2.FormField{
				id:       'street'
				label:    'Street address'
				required: true
				col_span: 3
				error:    error_of(errors, 'street')
				control:  Input{
					...base
					id:          'street'
					placeholder: '12 St James’s Square'
					value:       a.street
					invalid:     'street' in errors
				}.control()
			},
			ui2.FormField{
				id:      'apt'
				label:   'Apt, suite'
				control: Input{
					...base
					id:    'apt'
					value: a.apt
				}.control()
			},
			ui2.FormField{
				id:       'country'
				label:    'Country'
				required: true
				col_span: 2
				error:    error_of(errors, 'country')
				control:  fn [a] (frame ui2.Rect) !ui2.Element {
					return ui2.select_box(ui2.SelectConfig{
						...country_config(a)
						frame: frame
					})
				}
			},
			// Only for the United States. The ZIP code keeps column 4 either way.
			ui2.FormField{
				id:      'region'
				label:   'State'
				visible: us
				control: dropdown_control('region', a.region, ['California', 'New York', 'Texas',
					'Washington'], theme)
			},
			ui2.FormField{
				id:        'zip'
				label:     if us { 'ZIP code' } else { 'Postal code' }
				required:  true
				col_start: 4
				error:     error_of(errors, 'zip')
				control:   Input{
					...base
					id:      'zip'
					value:   a.zip
					invalid: 'zip' in errors
				}.control()
			},
			ui2.FormField{
				id:       'city'
				label:    'City'
				required: true
				col_span: 2
				error:    error_of(errors, 'city')
				control:  Input{
					...base
					id:      'city'
					value:   a.city
					invalid: 'city' in errors
				}.control()
			},
			ui2.FormField{
				id:       'speed'
				label:    'Delivery'
				col_span: 2
				control:  fn [a] (frame ui2.Rect) !ui2.Element {
					return ui2.radio_group(ui2.RadioGroupConfig{
						...speed_config(a)
						frame: radio_strip(frame)
					})
				}
			},
			// Without a label of its own, the checkbox takes the label's room only
			// while the gift message beside it has a label to line up with.
			ui2.FormField{
				id:           'gift'
				col_span:     2
				label_indent: a.gift
				control:      checkbox_control('gift', 'This order is a gift', a.gift,
					theme)
			},
			// Placed explicitly in columns 3 and 4, beside the checkbox.
			ui2.FormField{
				id:        'gift_message'
				label:     'Gift message'
				visible:   a.gift
				col_start: 3
				col_span:  2
				error:     error_of(errors, 'gift_message')
				control:   Input{
					...base
					id:          'gift_message'
					placeholder: 'Happy birthday!'
					value:       a.gift_message
					invalid:     'gift_message' in errors
				}.control()
			},
		]
		actions: [
			ui2.FormAction{
				id:    'back'
				label: 'Back to cart'
				icon:  'arrow.left'
			},
			ui2.FormAction{
				id:    'continue'
				label: 'Continue to payment'
				kind:  .submit
			},
		]
	}
}

fn countries() []ui2.PickerOption {
	return [
		ui2.picker_option('us', 'United States'),
		ui2.picker_option('ca', 'Canada'),
		ui2.picker_option('gb', 'United Kingdom'),
		ui2.picker_option('de', 'Germany'),
		ui2.picker_option('jp', 'Japan'),
	]
}

fn country_config(a &FormDemo) ui2.SelectConfig {
	anchor := ui2.form_control_frame(shipping_config(a), 'country') or { ui2.Rect{} }
	errors := if a.shipping_tried { shipping_errors(a) } else { map[string]string{} }
	return ui2.SelectConfig{
		id:                  'country'
		frame:               anchor
		anchor:              anchor
		window:              window_rect()
		options:             countries()
		selected:            a.country
		state:               a.country_state
		placeholder:         'Choose a country'
		invalid:             'country' in errors
		accessibility_label: 'Country'
		theme:               theme_of(a)
	}
}

fn speed_config(a &FormDemo) ui2.RadioGroupConfig {
	return ui2.RadioGroupConfig{
		id:                  'speed'
		selected:            a.speed
		orientation:         .horizontal
		accessibility_label: 'Delivery'
		options:             [
			ui2.RadioOption{
				value: 'standard'
				label: 'Standard'
			},
			ui2.RadioOption{
				value: 'express'
				label: 'Express'
			},
		]
		theme:               theme_of(a)
	}
}

// ── Newsletter: one field on its own ────────────────────────────────

fn newsletter_error(a &FormDemo) string {
	if !a.newsletter_tried {
		return ''
	}
	return ui2.form_check(a.newsletter, 'Email', [ui2.form_required(), ui2.form_email()])
}

fn newsletter_config(a &FormDemo) ui2.FormFieldConfig {
	failure := newsletter_error(a)
	return ui2.FormFieldConfig{
		id:           'newsletter'
		frame:        ui2.rect(shipping_x + card_pad, form_top, shipping_w - 2 * card_pad - 124,
			0)
		label_layout: .horizontal
		label_width:  48
		theme:        theme_of(a)
		field:        ui2.FormField{
			id:          'newsletter_email'
			label:       'Email'
			description: if a.subscribed.len > 0 {
				a.subscribed
			} else {
				'One email a month. Unsubscribe at any time.'
			}
			error:       failure
			control:     Input{
				id:          'newsletter_email'
				placeholder: 'you@example.com'
				value:       a.newsletter
				invalid:     failure.len > 0
				submit:      'subscribe'
				theme:       theme_of(a)
			}.control()
		}
	}
}

// ── Build ───────────────────────────────────────────────────────────

fn page_color(a &FormDemo) u32 {
	return if a.dark { 0x0f172a } else { 0xf1f5f9 }
}

fn card(x f64, y f64, w f64, h f64, title string, note string, theme ui2.ComponentTheme) []ui2.Element {
	return [
		ui2.Element{
			...ui2.view('', ui2.rect(x, y, w, h), ui2.BoxStyle{
				bg:            theme.background
				radius:        12
				border_color:  theme.border
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
				shadow:        ui2.component_card_shadow()
			}, []ui2.Element{})
		},
		ui2.label('', title, ui2.rect(x + card_pad, y + 18, w - 2 * card_pad, 24), ui2.TextStyle{
			color: theme.foreground
			size:  17
			bold:  true
		}),
		ui2.label('', note, ui2.rect(x + card_pad, y + 44, w - 2 * card_pad, 18), ui2.TextStyle{
			color: theme.muted_foreground
			size:  13
		}),
	]
}

// card_height fits a card to its form, which starts 78 below the card's top.
fn card_height(config ui2.FormConfig) f64 {
	layout := ui2.form_layout(config) or { return 0 }
	return form_top - card_y + layout.height + card_pad + 4
}

fn build() ui2.Element {
	a := app()
	theme := theme_of(a)
	register := register_config(a)
	settings := settings_config(a)
	shipping := shipping_config(a)
	mut c := []ui2.Element{}
	c << ui2.label('', 'Form', ui2.rect(24, 18, 600, 32), ui2.TextStyle{
		color: theme.foreground
		size:  24
		bold:  true
	})
	c << ui2.label('', a.status, ui2.rect(24, 52, 1200, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  14
	})
	c << ui2.styled_button(
		id:      'theme'
		frame:   ui2.rect(window_width - 24 - 112, 20, 112, 32)
		label:   if a.dark { 'Light' } else { 'Dark' }
		icon:    if a.dark { 'sun.max' } else { 'moon' }
		outline: true
		theme:   theme
	) or { panic(err) }
	c << card(register_x, card_y, register_w, card_height(register), 'Create an account',
		'Labels above the controls.', theme)
	c << card(settings_x, card_y, settings_w, card_height(settings), 'Settings', 'Labels beside the controls, in sections.',
		theme)
	c << card(shipping_x, card_y, shipping_w, newsletter_h, 'Newsletter', 'A field on its own, laid out by form_field.',
		theme)
	c << card(shipping_x, shipping_y, shipping_w, card_height(shipping),
		'Shipping address', 'Four columns: spans, a column start and conditional fields.', theme)
	c << ui2.form(register) or { panic(err) }
	c << ui2.form(settings) or { panic(err) }
	c << ui2.form(shipping) or { panic(err) }
	c << ui2.form_field(newsletter_config(a)) or { panic(err) }
	c << ui2.styled_button(
		id:    'subscribe'
		frame: ui2.rect(shipping_x + shipping_w - card_pad - 112, form_top, 112, 32)
		label: 'Subscribe'
		icon:  'envelope'
		theme: theme
	) or { panic(err) }
	// Popups last, so they are drawn over the forms.
	c << ui2.date_picker_overlay(birthday_config(a)) or { panic(err) }
	c << ui2.select_popup(country_config(a)) or { panic(err) }
	return ui2.screen(page_color(a), c)
}

// ── Events ──────────────────────────────────────────────────────────

// focus_target is the control to focus for a field with a message.
fn focus_target(field string) string {
	return match field {
		'name' { 'first' }
		'username' { ui2.input_group_field_id('username') }
		'text_size' { ui2.number_input_field_id('text_size') }
		else { field }
	}
}

fn submit_register(mut a FormDemo) {
	a.tried = true
	if field := ui2.form_first_error(register_config(a)) {
		count := register_errors(a).len
		a.status = 'Create account was pressed with ${count} problem${if count == 1 {
			''
		} else {
			's'
		}}: fix the fields marked in red.'
		a.focus_id = focus_target(field)
		return
	}
	a.status = 'Created an account for ${a.first} ${a.last} <${a.email.trim_space()}>.'
}

fn submit_settings(mut a FormDemo) {
	a.settings_tried = true
	if field := ui2.form_first_error(settings_config(a)) {
		a.status = 'The settings were not saved: check ${field}.'
		a.focus_id = focus_target(field)
		return
	}
	a.saved = a.settings
	a.settings_tried = false
	a.status = 'Settings saved for @${a.settings.username}.'
}

fn submit_shipping(mut a FormDemo) {
	a.shipping_tried = true
	if field := ui2.form_first_error(shipping_config(a)) {
		a.status = 'The address is incomplete.'
		if field != 'country' {
			a.focus_id = focus_target(field)
		}
		return
	}
	a.status = 'Shipping ${a.speed} to ${a.street}, ${a.city} ${a.zip}.'
}

fn subscribe(mut a FormDemo) {
	a.newsletter_tried = true
	if newsletter_error(a).len > 0 {
		a.subscribed = ''
		a.focus_id = 'newsletter_email'
		return
	}
	a.subscribed = 'You are subscribed. See you next month.'
	a.status = 'Subscribed ${a.newsletter.trim_space()} to the newsletter.'
}

// text_changed stores what a text field of the forms now holds.
fn text_changed(mut a FormDemo, id string) bool {
	value := ui2.text(id)
	match id {
		'first' { a.first = value }
		'last' { a.last = value }
		'email' { a.email = value }
		'password' { a.password = value }
		'confirm' { a.confirm = value }
		'display' { a.settings.display = value }
		'bio' { a.settings.bio = value }
		'full_name' { a.full_name = value }
		'phone' { a.phone = value }
		'street' { a.street = value }
		'apt' { a.apt = value }
		'zip' { a.zip = value }
		'city' { a.city = value }
		'gift_message' { a.gift_message = value }
		'newsletter_email' { a.newsletter = value }
		else { return false }
	}
	return true
}

fn handle_event(action string) {
	mut a := app()
	if apply_action(mut a, action) {
		refresh_and_settle(mut a)
	}
}

// apply_action decodes an action against the current state and stores what
// it asks for; false means it belongs to nothing here.
fn apply_action(mut a FormDemo, action string) bool {
	if event := ui2.form_event(register_config(a), action) {
		if event.kind == .submit {
			submit_register(mut a)
		}
	} else if event := ui2.form_event(settings_config(a), action) {
		match event.kind {
			.submit {
				submit_settings(mut a)
			}
			.reset {
				a.settings = a.saved
				a.settings_tried = false
				a.status = 'Settings reset.'
			}
			.button {}
		}
	} else if event := ui2.form_event(shipping_config(a), action) {
		match event.kind {
			.submit { submit_shipping(mut a) }
			else { a.status = 'Back to the cart.' }
		}
	} else if text_changed(mut a, action) {
	} else if ev := ui2.date_picker_event(birthday_config(a), action) {
		a.birthday = ev.state
		a.birthday_open = ev.open
		if ev.kind == .select {
			a.status = 'Birthday: ${ui2.date_picker_text(birthday_config(a))}.'
		}
	} else if step := ui2.select_update(country_config(a), action) {
		a.country_state = step.state
		if step.changed {
			a.country = step.selected
		}
	} else if group := ui2.input_group_event(username_config(a), action) {
		if group.kind == .change {
			a.settings.username = ui2.text(ui2.input_group_field_id('username'))
		} else if group.kind == .submit {
			submit_settings(mut a)
		}
	} else if value := ui2.radio_group_value_from_action(frequency_config(a), action) {
		a.settings.frequency = value
	} else if value := ui2.radio_group_value_from_action(speed_config(a), action) {
		a.speed = value
	} else if kind := ui2.number_input_event(text_size_config(a), action) {
		config := text_size_config(a)
		field := ui2.number_input_field_id('text_size')
		a.settings.text_size = match kind {
			.change { ui2.number_input_sanitize(config, ui2.text(field)) }
			.submit { ui2.number_input_commit(config, ui2.text(field)) or { config.text } }
			.increment, .decrement {
				ui2.number_input_value_from_action(config, action) or {
					config.text
				}
			}
		}
		if ui2.text(field) != a.settings.text_size {
			a.sync_id = field
			a.sync_text = a.settings.text_size
		}
	} else {
		match action {
			'theme' { a.dark = !a.dark }
			'terms' { a.terms = !a.terms }
			'gift' { a.gift = !a.gift }
			'updates' { a.settings.updates = !a.settings.updates }
			'language' { a.settings.language = ui2.text('language') }
			'region' { a.region = ui2.text('region') }
			'subscribe' { subscribe(mut a) }
			else { return false }
		}
	}
	return true
}

// refresh_and_settle rebuilds, then does what needs the new tree: putting a
// field's text back and moving focus.
fn refresh_and_settle(mut a FormDemo) {
	ui2.refresh()
	if a.sync_id.len > 0 {
		if ui2.text(a.sync_id) != a.sync_text {
			ui2.set_text(a.sync_id, a.sync_text)
		}
		a.sync_id = ''
	}
	if a.focus_id.len > 0 {
		ui2.focus(a.focus_id)
		a.focus_id = ''
	}
}

// handle_key routes keys to the popups while they are open, and the arrows
// to the text size field while it has focus.
fn handle_key(event ui2.KeyEvent) {
	mut a := app()
	if a.country_state.open {
		step := ui2.select_key(country_config(a), event) or { return }
		a.country_state = step.state
		if step.changed {
			a.country = step.selected
		}
		if !step.propagate {
			ui2.consume_key()
		}
	} else if a.birthday_open {
		ev := ui2.date_picker_key_event(birthday_config(a), event) or { return }
		ui2.consume_key()
		a.birthday = ev.state
		a.birthday_open = ev.open
	} else if ui2.focused_id() == ui2.number_input_field_id('text_size') {
		next := ui2.number_input_value_from_key(text_size_config(a), event) or { return }
		ui2.consume_key()
		a.settings.text_size = next
	} else {
		return
	}
	refresh_and_settle(mut a)
}

fn main() {
	ui2.on_key_event(handle_key)
	ui2.run_window('GPUI Kit form', window_width, window_height, build, handle_event)
}
