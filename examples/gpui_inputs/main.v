module main

import ui2

// A gallery of the text-entry components: number input, OTP input and input
// group. The application owns every value. Each component emits actions that
// its decoder turns into a typed request against the current state, and
// on_key_event adds the arrow, Backspace and Delete behavior a field cannot
// provide on its own.

const window_width = 760
const window_height = 700
const verification_code = '123456'

@[heap]
struct InputsDemo {
mut:
	quantity  string = '3'
	price     string = '4.50'
	small     string = '12'
	code      string = '123455'
	code_bad  bool   = true
	pin       string = '25'
	show_pin  bool
	recovery  string = 'K7Q2'
	search    string = 'gpui'
	website   string = 'example'
	password  string = 'correct horse'
	reveal    bool
	amount    string = '12.50'
	token     string = 'tok_8f2a91c4'
	token_gen int
	message   string = 'Type, paste, step with the buttons or the arrow keys.'
	// Work to do once the tree has been rebuilt with the new state.
	sync_id   string
	sync_text string
	focus_id  string
}

const demo = &InputsDemo{}

const theme = ui2.component_theme(false)

// ── Configurations, shared by the build and the event handlers ──────

fn quantity_config(app &InputsDemo) ui2.NumberInputConfig {
	config := ui2.NumberInputConfig{
		id:                  'quantity'
		frame:               ui2.rect(24, 144, 176, 32)
		text:                app.quantity
		min:                 1
		max:                 99
		accessibility_label: 'Quantity'
		theme:               theme
	}
	// A value typed out of range is kept while typing and shown as invalid;
	// Return clamps it.
	return ui2.NumberInputConfig{
		...config
		invalid: app.quantity.len > 0 && !ui2.number_input_in_range(config, app.quantity)
	}
}

fn price_config(app &InputsDemo) ui2.NumberInputConfig {
	return ui2.NumberInputConfig{
		id:                  'price'
		frame:               ui2.rect(224, 144, 176, 32)
		text:                app.price
		placeholder:         '0.00'
		min:                 0
		step:                0.25
		precision:           2
		controls:            .trailing
		accessibility_label: 'Price'
		theme:               theme
	}
}

fn small_config(app &InputsDemo) ui2.NumberInputConfig {
	return ui2.NumberInputConfig{
		id:                  'small'
		frame:               ui2.rect(424, 148, 136, 24)
		text:                app.small
		precision:           0
		size:                .small
		accessibility_label: 'Small number'
		theme:               theme
	}
}

fn disabled_number_config() ui2.NumberInputConfig {
	return ui2.NumberInputConfig{
		id:                  'disabled_number'
		frame:               ui2.rect(584, 144, 152, 32)
		text:                '7'
		enabled:             false
		accessibility_label: 'Disabled number'
		theme:               theme
	}
}

fn code_config(app &InputsDemo) ui2.OtpInputConfig {
	return ui2.OtpInputConfig{
		id:                  'code'
		frame:               ui2.rect(24, 276, 320, 40)
		code:                app.code
		separator:           '-'
		invalid:             app.code_bad
		accessibility_label: 'Verification code'
		theme:               theme
	}
}

fn pin_config(app &InputsDemo) ui2.OtpInputConfig {
	return ui2.OtpInputConfig{
		id:                  'pin'
		frame:               ui2.rect(400, 276, 160, 40)
		code:                app.pin
		length:              4
		groups:              1
		masked:              !app.show_pin
		accessibility_label: 'PIN'
		theme:               theme
	}
}

fn recovery_config(app &InputsDemo) ui2.OtpInputConfig {
	return ui2.OtpInputConfig{
		id:                  'recovery'
		frame:               ui2.rect(24, 376, 320, 32)
		code:                app.recovery
		length:              8
		charset:             .alphanumeric
		size:                .small
		accessibility_label: 'Recovery code'
		theme:               theme
	}
}

fn disabled_otp_config() ui2.OtpInputConfig {
	return ui2.OtpInputConfig{
		id:      'disabled_otp'
		frame:   ui2.rect(400, 376, 160, 32)
		code:    '42'
		length:  4
		groups:  1
		size:    .small
		enabled: false
		theme:   theme
	}
}

fn search_config(app &InputsDemo) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:          'search'
		frame:       ui2.rect(24, 484, 352, 32)
		text:        app.search
		placeholder: 'Search components'
		clearable:   true
		addons:      [
			ui2.InputGroupAddon{
				id:                  'icon'
				kind:                .icon
				icon:                'magnifyingglass'
				accessibility_label: 'Search'
			},
			ui2.InputGroupAddon{
				id:      'go'
				kind:    .button
				side:    .trailing
				text:    'Search'
				primary: true
			},
		]
		theme:       theme
	}
}

fn website_config(app &InputsDemo) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:                  'website'
		frame:               ui2.rect(400, 484, 336, 32)
		text:                app.website
		placeholder:         'domain'
		accessibility_label: 'Website'
		addons:              [
			ui2.InputGroupAddon{
				id:   'scheme'
				kind: .text
				text: 'https://'
			},
			ui2.InputGroupAddon{
				id:   'tld'
				kind: .text
				side: .trailing
				text: '.com'
			},
		]
		theme:               theme
	}
}

fn password_config(app &InputsDemo) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:                  'password'
		frame:               ui2.rect(24, 552, 352, 32)
		text:                app.password
		placeholder:         'Password'
		secure:              !app.reveal
		accessibility_label: 'Password'
		addons:              [
			ui2.InputGroupAddon{
				id:   'lock'
				kind: .icon
				icon: 'lock'
			},
			ui2.InputGroupAddon{
				id:                  'reveal'
				kind:                .button
				side:                .trailing
				icon:                if app.reveal { 'eye.slash' } else { 'eye' }
				tooltip:             if app.reveal { 'Hide password' } else { 'Show password' }
				accessibility_label: if app.reveal { 'Hide password' } else { 'Show password' }
			},
		]
		theme:               theme
	}
}

fn amount_config(app &InputsDemo) ui2.InputGroupConfig {
	valid := app.amount.len == 0 || ui2.number_input_parse(app.amount) != none
	return ui2.InputGroupConfig{
		id:                  'amount'
		frame:               ui2.rect(400, 552, 336, 32)
		text:                app.amount
		placeholder:         '0.00'
		invalid:             !valid
		keyboard:            ui2.keyboard_decimal
		accessibility_label: 'Amount'
		addons:              [
			ui2.InputGroupAddon{
				id:   'currency'
				kind: .text
				text: '$'
			},
			ui2.InputGroupAddon{
				id:   'code'
				kind: .text
				side: .trailing
				text: 'USD'
			},
		]
		theme:               theme
	}
}

fn token_config(app &InputsDemo) ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:                  'token'
		frame:               ui2.rect(24, 624, 352, 24)
		text:                app.token
		readonly:            true
		size:                .small
		accessibility_label: 'API token'
		addons:              [
			ui2.InputGroupAddon{
				id:   'key'
				kind: .text
				text: 'Token'
			},
			ui2.InputGroupAddon{
				id:   'renew'
				kind: .button
				side: .trailing
				icon: 'arrow.clockwise'
				text: 'Renew'
			},
		]
		theme:               theme
	}
}

fn disabled_group_config() ui2.InputGroupConfig {
	return ui2.InputGroupConfig{
		id:                  'disabled_group'
		frame:               ui2.rect(400, 616, 336, 40)
		text:                'Locked by an administrator'
		enabled:             false
		clearable:           true
		size:                .large
		accessibility_label: 'Disabled'
		addons:              [
			ui2.InputGroupAddon{
				id:   'person'
				kind: .icon
				icon: 'person.crop.circle'
			},
			ui2.InputGroupAddon{
				id:   'edit'
				kind: .button
				side: .trailing
				text: 'Edit'
			},
		]
		theme:               theme
	}
}

// ── Build ───────────────────────────────────────────────────────────

fn heading(title string, y f64) ui2.Element {
	return ui2.label('', title, ui2.rect(24, y, 712, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(content string, x f64, y f64, width f64) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn note(content string, x f64, y f64, width f64, color u32) ui2.Element {
	return ui2.label('', content, ui2.rect(x, y, width, 20), ui2.TextStyle{
		color: color
		size:  13
	})
}

fn otp_status(app &InputsDemo) (string, u32) {
	entered := app.code.runes().len
	if app.code_bad {
		return 'That code is not right. Try ${verification_code}.', theme.danger
	}
	if entered == 6 {
		return 'Verified.', theme.success
	}
	return '${entered} of 6 digits. Paste a whole code into any cell.', theme.muted_foreground
}

fn build() ui2.Element {
	app := unsafe { demo }
	mut c := []ui2.Element{}
	c << ui2.label('', 'Inputs', ui2.rect(24, 16, 712, 32), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	c << note('Number input, OTP input and input group. The application owns every value.',
		24, 50, 712, theme.muted_foreground)

	c << heading('Number input', 92)
	c << caption('Quantity, 1 to 99', 24, 122, 176)
	c << caption('Price, steps of 0.25', 224, 122, 176)
	c << caption('Small, whole numbers', 424, 122, 136)
	c << caption('Disabled', 584, 122, 152)
	c << ui2.number_input(quantity_config(app)) or { panic(err) }
	c << ui2.number_input(price_config(app)) or { panic(err) }
	c << ui2.number_input(small_config(app)) or { panic(err) }
	c << ui2.number_input(disabled_number_config()) or { panic(err) }
	c << note('Quantity ${app.quantity} at ${app.price} each. With a field focused, ↑ and ↓ step it.',
		24, 186, 712, theme.muted_foreground)

	c << heading('OTP input', 226)
	c << caption('Verification code', 24, 256, 320)
	c << caption('PIN, masked', 400, 256, 160)
	c << ui2.otp_input(code_config(app)) or { panic(err) }
	c << ui2.otp_input(pin_config(app)) or { panic(err) }
	c << ui2.button('toggle_pin', if app.show_pin { 'Hide' } else { 'Show' }, ui2.rect(572,
		280, 72, 32), ui2.BoxStyle{
		bg:     theme.muted
		radius: 6
	}, ui2.TextStyle{
		color: theme.foreground
		size:  14
	})
	status, color := otp_status(app)
	c << note(status, 24, 324, 520, color)
	c << caption('Recovery code, letters and digits', 24, 356, 320)
	c << caption('Disabled', 400, 356, 160)
	c << ui2.otp_input(recovery_config(app)) or { panic(err) }
	c << ui2.otp_input(disabled_otp_config()) or { panic(err) }

	c << heading('Input group', 434)
	c << caption('Icon, clear button and action', 24, 464, 352)
	c << caption('Text addons', 400, 464, 336)
	c << ui2.input_group(search_config(app)) or { panic(err) }
	c << ui2.input_group(website_config(app)) or { panic(err) }
	c << caption('Password with a reveal button', 24, 532, 352)
	c << caption('Validated amount', 400, 532, 336)
	c << ui2.input_group(password_config(app)) or { panic(err) }
	c << ui2.input_group(amount_config(app)) or { panic(err) }
	c << caption('Small and read-only', 24, 600, 352)
	c << caption('Large and disabled', 400, 596, 336)
	c << ui2.input_group(token_config(app)) or { panic(err) }
	c << ui2.input_group(disabled_group_config()) or { panic(err) }
	c << note(app.message, 24, 668, 712, theme.foreground)
	return ui2.screen(theme.background, c)
}

// ── Events ──────────────────────────────────────────────────────────

// number_update applies a number input's action and returns the text to store.
fn number_update(mut app InputsDemo, config ui2.NumberInputConfig, action string) ?string {
	kind := ui2.number_input_event(config, action) or { return none }
	field := ui2.number_input_field_id(config.id)
	match kind {
		.change {
			typed := ui2.text(field)
			clean := ui2.number_input_sanitize(config, typed)
			if clean != typed {
				// A rebuild keeps what the field shows unless its declared text
				// changes, so take out what was rejected explicitly.
				app.sync_id = field
				app.sync_text = clean
			}
			return clean
		}
		.submit {
			committed := ui2.number_input_commit(config, ui2.text(field)) or { config.text }
			app.sync_id = field
			app.sync_text = committed
			app.message = '${config.accessibility_label} set to ${committed}.'
			return committed
		}
		.decrement, .increment {
			return ui2.number_input_value_from_action(config, action)
		}
	}
}

// apply_otp stores an edit, then asks for the edited cell to be put in step
// with the code and for focus to move on once the tree has been rebuilt.
fn apply_otp(mut app InputsDemo, config ui2.OtpInputConfig, index int, edit ui2.OtpInputEdit) {
	match config.id {
		'code' {
			app.code = edit.code
			app.code_bad = edit.complete && edit.code != verification_code
		}
		'pin' {
			app.pin = edit.code
			if edit.complete {
				app.message = 'PIN entered.'
			}
		}
		else {
			app.recovery = edit.code
		}
	}
	app.sync_id = ui2.otp_input_cell_id(config.id, index)
	app.sync_text = ui2.otp_input_cell_text(edit.code, index)
	app.focus_id = ui2.otp_input_cell_id(config.id, edit.focus)
}

fn handle_otp(mut app InputsDemo, config ui2.OtpInputConfig, action string) bool {
	index := ui2.otp_input_cell_from_action(config, action) or { return false }
	typed := ui2.text(ui2.otp_input_cell_id(config.id, index))
	apply_otp(mut app, config, index, ui2.otp_input_edit(config, index, typed))
	return true
}

struct GroupUpdate {
	event ui2.InputGroupEvent
	text  string
}

// group_update applies an input group's action and returns the event with the
// text to store.
fn group_update(mut app InputsDemo, config ui2.InputGroupConfig, action string) ?GroupUpdate {
	event := ui2.input_group_event(config, action) or { return none }
	field := ui2.input_group_field_id(config.id)
	return match event.kind {
		.change {
			GroupUpdate{event, ui2.text(field)}
		}
		.clear {
			app.focus_id = field
			GroupUpdate{event, ''}
		}
		else {
			GroupUpdate{event, config.text}
		}
	}
}

fn handle_event(action string) {
	mut app := unsafe { demo }
	if action == 'toggle_pin' {
		app.show_pin = !app.show_pin
	} else if next := number_update(mut app, quantity_config(app), action) {
		app.quantity = next
	} else if next := number_update(mut app, price_config(app), action) {
		app.price = next
	} else if next := number_update(mut app, small_config(app), action) {
		app.small = next
	} else if handle_otp(mut app, code_config(app), action) {
	} else if handle_otp(mut app, pin_config(app), action) {
	} else if handle_otp(mut app, recovery_config(app), action) {
	} else if update := group_update(mut app, search_config(app), action) {
		app.search = update.text
		if update.event.kind in [.submit, .addon] {
			app.message = 'Searching for “${app.search}”.'
		}
	} else if update := group_update(mut app, website_config(app), action) {
		app.website = update.text
		app.message = 'Website: https://${app.website}.com'
	} else if update := group_update(mut app, password_config(app), action) {
		app.password = update.text
		if update.event.kind == .addon {
			app.reveal = !app.reveal
		}
	} else if update := group_update(mut app, amount_config(app), action) {
		app.amount = update.text
	} else if update := group_update(mut app, token_config(app), action) {
		if update.event.kind == .addon {
			app.token_gen++
			app.token = 'tok_${u32(app.token_gen) * u32(2654435761):08x}'
			app.message = 'Issued a new token.'
		}
	} else {
		return
	}
	refresh_and_settle(mut app)
}

// refresh_and_settle rebuilds, then does what has to wait for the new tree:
// putting a field's text back and moving focus.
fn refresh_and_settle(mut app InputsDemo) {
	ui2.refresh()
	if app.sync_id.len > 0 {
		if ui2.text(app.sync_id) != app.sync_text {
			ui2.set_text(app.sync_id, app.sync_text)
		}
		app.sync_id = ''
	}
	if app.focus_id.len > 0 {
		ui2.focus(app.focus_id)
		app.focus_id = ''
	}
}

// handle_key adds what the fields cannot do alone: ↑ and ↓ step a focused
// number input, and Backspace, Delete and the arrows move between OTP cells.
fn handle_key(event ui2.KeyEvent) {
	mut app := unsafe { demo }
	focused := ui2.focused_id()
	if focused.len == 0 {
		return
	}
	numbers := [quantity_config(app), price_config(app), small_config(app)]
	for config in numbers {
		if focused != ui2.number_input_field_id(config.id) {
			continue
		}
		next := ui2.number_input_value_from_key(config, event) or { return }
		ui2.consume_key()
		match config.id {
			'quantity' { app.quantity = next }
			'price' { app.price = next }
			else { app.small = next }
		}
		refresh_and_settle(mut app)
		return
	}
	codes := [code_config(app), pin_config(app), recovery_config(app)]
	for config in codes {
		index := ui2.otp_input_cell_from_action(config, focused) or { continue }
		edit := ui2.otp_input_key(config, index, event) or { return }
		ui2.consume_key()
		apply_otp(mut app, config, edit.focus, edit)
		refresh_and_settle(mut app)
		return
	}
}

fn main() {
	ui2.on_key_event(handle_key)
	ui2.run_window('GPUI Kit inputs', window_width, window_height, build, handle_event)
}
