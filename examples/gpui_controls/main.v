module main

import ui2

// A gallery of GPUI Kit's slider, switch and checkbox as drawn components
// (styled_slider, styled_switch, styled_checkbox, checkbox_group), next to the
// platform slider, switch_control and checkbox they complement. Every component
// is controlled: the state below is the only state, each build derives the
// configs from it, and on_event decodes actions against those same configs.

const window_width = 1200
const window_height = 900
const col_a = 24.0
const col_b = 420.0
const col_c = 816.0
const col_width = 360.0

@[heap]
struct Gallery {
mut:
	dark bool
	// focus is the control keys go to, and active the thumb of a range slider
	// they move. A press on a slider or a switch focuses it; Tab cycles.
	focus  string
	active ui2.SliderThumb
	// Sliders.
	volume    f64   = 40
	price_lo  f64   = 200
	price_hi  f64   = 650
	rating    f64   = 6
	frequency f64   = 440
	small     f64   = 30
	medium    f64   = 50
	large     f64   = 70
	remaining f64   = 65
	eq        []f64 = [4.0, -3, 6]
	comfort   []f64 = [19.0, 23]
	// Switches.
	notifications bool = true
	wifi          bool = true
	bluetooth     bool
	sizes         []bool = [true, false, true]
	success       bool   = true
	danger        bool   = true
	sync          bool
	sync_loading  bool
	airplane      bool
	// Checkboxes.
	terms     bool
	marketing bool = true
	partial   bool
	mixed     bool     = true
	checks    []bool   = [true, false, true, true]
	notify    []string = ['mail']
	toppings  []string = ['cheese', 'olives']
	// Platform controls.
	native_value  f64    = 35
	native_switch bool   = true
	native_check  bool   = true
	message       string = 'Press a slider or a switch, then use the keyboard.'
}

const gallery = &Gallery{}

fn app() &Gallery {
	return unsafe { gallery }
}

fn theme_of(g &Gallery) ui2.ComponentTheme {
	return ui2.component_theme(g.dark)
}

// ── Sliders ────────────────────────────────────────────────────────

const eq_names = ['Bass', 'Mid', 'Treble']

fn slider_base(g &Gallery, id string, frame ui2.Rect) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		id:      id
		frame:   frame
		focused: g.focus == id
		active:  g.active
		theme:   theme_of(g)
	}
}

fn volume_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'volume', ui2.rect(col_a, 118, 300, 48))
		value:               g.volume
		value_label:         .active
		value_suffix:        '%'
		accessibility_label: 'Volume'
	}
}

fn price_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'price', ui2.rect(col_a, 194, col_width, 66))
		max:                 1000
		step:                10
		range:               true
		start:               g.price_lo
		end:                 g.price_hi
		value_label:         .always
		value_prefix:        '$'
		marks:               [0.0, 250, 500, 750, 1000].map(ui2.SliderMark{
			value: it
			label: '$${int(it)}'
		})
		accessibility_label: 'Price'
	}
}

fn rating_config(g &Gallery) ui2.StyledSliderConfig {
	base := ui2.StyledSliderConfig{
		...slider_base(g, 'rating', ui2.rect(col_a, 286, col_width, 44))
		max:                 10
		value:               g.rating
		snap_to_marks:       true
		accessibility_label: 'Rating'
	}
	return ui2.StyledSliderConfig{
		...base
		marks: ui2.slider_step_marks(base, 1, true) or { []ui2.SliderMark{} }
	}
}

fn frequency_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'frequency', ui2.rect(col_a, 356, col_width, 48))
		min:                 20
		max:                 20000
		value:               g.frequency
		scale:               .logarithmic
		value_label:         .always
		value_suffix:        ' Hz'
		accessibility_label: 'Frequency'
	}
}

fn size_slider_config(g &Gallery, size ui2.ComponentSize) ui2.StyledSliderConfig {
	index := int(size)
	return ui2.StyledSliderConfig{
		...slider_base(g, ['small', 'medium', 'large'][index], ui2.rect(col_a, [430.0, 452, 478][index],
			col_width, [20.0, 24, 28][index]))
		value: [g.small, g.medium, g.large][index]
		size:  size
	}
}

fn remaining_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'remaining', ui2.rect(col_a, 534, 300, 24))
		value:               g.remaining
		reverse:             true
		color:               theme_of(g).success
		accessibility_label: 'Time remaining'
	}
}

fn disabled_slider_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'disabled-slider', ui2.rect(col_a, 584, col_width, 24))
		range:   true
		start:   30
		end:     70
		enabled: false
		marks:   [25.0, 50, 75].map(ui2.SliderMark{
			value: it
		})
	}
}

fn eq_config(g &Gallery, index int) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'eq-${index}', ui2.rect(col_b + f64(index) * 64, 532, 56, 180))
		min:                 -12
		max:                 12
		value:               g.eq[index]
		orientation:         .vertical
		marks:               [ui2.SliderMark{
			value: 0
		}]
		value_suffix:        ' dB'
		accessibility_label: eq_names[index]
	}
}

fn comfort_config(g &Gallery) ui2.StyledSliderConfig {
	return ui2.StyledSliderConfig{
		...slider_base(g, 'comfort', ui2.rect(col_b + 200, 532, 160, 180))
		min:                 10
		max:                 30
		step:                0.5
		range:               true
		start:               g.comfort[0]
		end:                 g.comfort[1]
		orientation:         .vertical
		value_label:         .always
		value_suffix:        '°'
		decimals:            1
		marks:               [10.0, 20, 30].map(ui2.SliderMark{
			value: it
			label: '${int(it)}°'
		})
		size:                .small
		accessibility_label: 'Comfort range'
	}
}

fn slider_configs(g &Gallery) []ui2.StyledSliderConfig {
	mut configs := [volume_config(g), price_config(g), rating_config(g), frequency_config(g),
		size_slider_config(g, .small), size_slider_config(g, .medium), size_slider_config(g, .large),
		remaining_config(g), disabled_slider_config(g)]
	for i in 0 .. eq_names.len {
		configs << eq_config(g, i)
	}
	configs << comfort_config(g)
	return configs
}

fn apply_slider(mut g Gallery, id string, change ui2.SliderChange) {
	match id {
		'volume' { g.volume = change.value }
		'price' { g.price_lo, g.price_hi = change.start, change.end }
		'rating' { g.rating = change.value }
		'frequency' { g.frequency = change.value }
		'small' { g.small = change.value }
		'medium' { g.medium = change.value }
		'large' { g.large = change.value }
		'remaining' { g.remaining = change.value }
		'comfort' { g.comfort = [change.start, change.end] }
		else {
			if id.starts_with('eq-') {
				g.eq[id['eq-'.len..].int()] = change.value
			}
		}
	}
}

// ── Switches ───────────────────────────────────────────────────────

fn switch_base(g &Gallery, id string, frame ui2.Rect) ui2.StyledSwitchConfig {
	return ui2.StyledSwitchConfig{
		id:      id
		frame:   frame
		focused: g.focus == id
		theme:   theme_of(g)
	}
}

fn notifications_config(g &Gallery) ui2.StyledSwitchConfig {
	return ui2.StyledSwitchConfig{
		...switch_base(g, 'notifications', ui2.rect(col_b, 118, col_width, 44))
		checked:     g.notifications
		label:       'Notifications'
		description: 'Show alerts, play sounds and badge the app icon.'
	}
}

fn settings_switch_config(g &Gallery, index int) ui2.StyledSwitchConfig {
	labels := ['Wi-Fi', 'Bluetooth', 'Airplane mode']
	ids := ['wifi', 'bluetooth', 'airplane-locked']
	checked := [g.wifi, g.bluetooth, false]
	return ui2.StyledSwitchConfig{
		...switch_base(g, ids[index], ui2.rect(col_b + 12, 196 + f64(index) * 28, 276, 24))
		checked:    checked[index]
		label:      labels[index]
		label_side: .left
		enabled:    index < 2
		size:       .small
	}
}

fn size_switch_config(g &Gallery, index int) ui2.StyledSwitchConfig {
	sizes := [ui2.ComponentSize.small, .medium, .large]
	names := ['Small', 'Medium', 'Large']
	return ui2.StyledSwitchConfig{
		...switch_base(g, 'switch-${names[index].to_lower()}', ui2.rect(col_b + [0.0, 100, 216][index],
			312, 112, 28))
		checked: g.sizes[index]
		label:   names[index]
		size:    sizes[index]
	}
}

fn color_switch_config(g &Gallery, index int) ui2.StyledSwitchConfig {
	theme := theme_of(g)
	names := ['Success', 'Danger', 'Disabled']
	return ui2.StyledSwitchConfig{
		...switch_base(g, names[index].to_lower(), ui2.rect(col_b + f64(index) * 120, 372,
			112, 28))
		checked: [g.success, g.danger, true][index]
		label:   names[index]
		color:   [theme.success, theme.danger, theme.success][index]
		enabled: index < 2
	}
}

fn sync_config(g &Gallery) ui2.StyledSwitchConfig {
	return ui2.StyledSwitchConfig{
		...switch_base(g, 'sync', ui2.rect(col_b, 432, 170, 28))
		checked: g.sync
		loading: g.sync_loading
		label:   if g.sync_loading { 'Syncing…' } else { 'Cloud sync' }
	}
}

fn airplane_config(g &Gallery) ui2.StyledSwitchConfig {
	return ui2.StyledSwitchConfig{
		...switch_base(g, 'airplane', ui2.rect(col_b + 180, 432, 180, 28))
		checked: g.airplane
		label:   'Airplane mode'
		tooltip: 'Turns off every wireless connection'
	}
}

fn switch_configs(g &Gallery) []ui2.StyledSwitchConfig {
	mut configs := [notifications_config(g)]
	for i in 0 .. 3 {
		configs << settings_switch_config(g, i)
		configs << size_switch_config(g, i)
		configs << color_switch_config(g, i)
	}
	configs << sync_config(g)
	configs << airplane_config(g)
	return configs
}

fn apply_switch(mut g Gallery, id string, checked bool) {
	match id {
		'notifications' {
			g.notifications = checked
		}
		'wifi' {
			g.wifi = checked
		}
		'bluetooth' {
			g.bluetooth = checked
		}
		'switch-small' {
			g.sizes[0] = checked
		}
		'switch-medium' {
			g.sizes[1] = checked
		}
		'switch-large' {
			g.sizes[2] = checked
		}
		'success' {
			g.success = checked
		}
		'danger' {
			g.danger = checked
		}
		'airplane' {
			g.airplane = checked
		}
		'sync' {
			// The change takes a moment to apply: the switch shows a spinner
			// and ignores clicks until the timer settles it.
			g.sync_loading = true
			ui2.after(1.2, fn [checked] () {
				mut s := app()
				s.sync = checked
				s.sync_loading = false
				s.message = 'Cloud sync is ${if checked { 'on' } else { 'off' }}.'
			})
		}
		else {}
	}
}

// ── Checkboxes ─────────────────────────────────────────────────────

fn checkbox_base(g &Gallery, id string, frame ui2.Rect) ui2.StyledCheckboxConfig {
	return ui2.StyledCheckboxConfig{
		id:      id
		frame:   frame
		focused: g.focus == id
		theme:   theme_of(g)
	}
}

fn terms_config(g &Gallery) ui2.StyledCheckboxConfig {
	return ui2.StyledCheckboxConfig{
		...checkbox_base(g, 'terms', ui2.rect(col_c, 118, col_width, 24))
		checked: g.terms
		label:   'I agree to the terms and conditions'
	}
}

fn marketing_config(g &Gallery) ui2.StyledCheckboxConfig {
	return ui2.StyledCheckboxConfig{
		...checkbox_base(g, 'marketing', ui2.rect(col_c, 146, col_width, 44))
		checked:     g.marketing
		label:       'Marketing emails'
		description: 'Receive emails about new products, features and offers.'
	}
}

fn partial_config(g &Gallery) ui2.StyledCheckboxConfig {
	return ui2.StyledCheckboxConfig{
		...checkbox_base(g, 'partial', ui2.rect(col_c, 194, col_width, 24))
		checked:       g.partial
		indeterminate: g.mixed
		label:         if g.mixed { 'Indeterminate: click to check' } else { 'Was indeterminate' }
		tooltip:       'An indeterminate checkbox becomes checked when clicked'
	}
}

fn disabled_checkbox_config(g &Gallery, checked bool) ui2.StyledCheckboxConfig {
	return ui2.StyledCheckboxConfig{
		...checkbox_base(g, if checked { 'disabled-on' } else { 'disabled-off' }, ui2.rect(col_c +
			if checked { 180.0 } else { 0.0 }, 246, 170, 24))
		checked: checked
		label:   if checked { 'Disabled, checked' } else { 'Disabled' }
		enabled: false
	}
}

fn size_checkbox_config(g &Gallery, index int) ui2.StyledCheckboxConfig {
	sizes := [ui2.ComponentSize.small, .medium, .large, .medium]
	names := ['Small', 'Medium', 'Large', '']
	return ui2.StyledCheckboxConfig{
		...checkbox_base(g, 'check-${index}', ui2.rect(col_c + [0.0, 90, 196, 300][index],
			300, [80.0, 96, 96, 24][index], 28))
		checked:             g.checks[index]
		label:               names[index]
		size:                sizes[index]
		accessibility_label: if index == 3 { 'Without a label' } else { '' }
	}
}

fn checkbox_configs(g &Gallery) []ui2.StyledCheckboxConfig {
	mut configs := [terms_config(g), marketing_config(g), partial_config(g)]
	for i in 0 .. 4 {
		configs << size_checkbox_config(g, i)
	}
	return configs
}

fn apply_checkbox(mut g Gallery, id string, checked bool) {
	match id {
		'terms' {
			g.terms = checked
		}
		'marketing' {
			g.marketing = checked
		}
		'partial' {
			g.partial = checked
			g.mixed = false
		}
		else {
			if id.starts_with('check-') {
				g.checks[id['check-'.len..].int()] = checked
			}
		}
	}
}

fn notify_config(g &Gallery) ui2.CheckboxGroupConfig {
	base := ui2.CheckboxGroupConfig{
		id:                  'notify'
		frame:               ui2.rect(col_c, 356, col_width, 0)
		selected:            g.notify
		select_all:          'All notifications'
		accessibility_label: 'Notifications'
		theme:               theme_of(g)
		options:             [
			ui2.CheckboxOption{
				value:       'mail'
				label:       'Email'
				description: 'A daily digest of activity'
			},
			ui2.CheckboxOption{
				value: 'push'
				label: 'Push notifications'
			},
			ui2.CheckboxOption{
				value:       'sms'
				label:       'Text messages'
				description: 'Needs a verified phone number'
				enabled:     false
			},
		]
	}
	return ui2.CheckboxGroupConfig{
		...base
		frame: ui2.rect(col_c, 356, col_width, ui2.checkbox_group_height(base))
	}
}

fn toppings_config(g &Gallery) ui2.CheckboxGroupConfig {
	base := ui2.CheckboxGroupConfig{
		id:          'toppings'
		frame:       ui2.rect(col_c, 572, col_width, 0)
		selected:    g.toppings
		orientation: .horizontal
		size:        .small
		theme:       theme_of(g)
		options:     ['Cheese', 'Olives', 'Mushrooms', 'Peppers', 'Onions', 'Basil'].map(ui2.CheckboxOption{
			value: it.to_lower()
			label: it
		})
	}
	return ui2.CheckboxGroupConfig{
		...base
		frame: ui2.rect(col_c, 572, col_width, ui2.checkbox_group_height(base))
	}
}

// ── Keyboard focus ─────────────────────────────────────────────────

struct FocusStop {
	id    string
	thumb ui2.SliderThumb
}

// focus_stops is the Tab order: every enabled control, with a stop per thumb of
// a range slider.
fn focus_stops(g &Gallery) []FocusStop {
	mut stops := []FocusStop{}
	for config in slider_configs(g) {
		if !config.enabled {
			continue
		}
		if config.range {
			stops << FocusStop{
				id:    config.id
				thumb: .start
			}
			stops << FocusStop{
				id:    config.id
				thumb: .end
			}
		} else {
			stops << FocusStop{
				id: config.id
			}
		}
	}
	for config in switch_configs(g) {
		if config.enabled {
			stops << FocusStop{
				id: config.id
			}
		}
	}
	for config in checkbox_configs(g) {
		stops << FocusStop{
			id: config.id
		}
	}
	return stops
}

fn move_focus(mut g Gallery, back bool) {
	stops := focus_stops(g)
	if stops.len == 0 {
		return
	}
	mut index := -1
	for i, stop in stops {
		if stop.id == g.focus && (stop.thumb == g.active || stop.thumb == .value) {
			index = i
			break
		}
	}
	next := if index < 0 {
		if back { stops.len - 1 } else { 0 }
	} else if back {
		(index + stops.len - 1) % stops.len
	} else {
		(index + 1) % stops.len
	}
	g.focus = stops[next].id
	g.active = stops[next].thumb
	g.message = 'Focus: ${g.focus}${if g.active == .value { '' } else { ' (${g.active})' }}.'
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
	return ui2.label('', text, ui2.rect(x, y, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn value_text(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.foreground
		size:  13
		align: .right
	})
}

fn build() ui2.Element {
	g := app()
	theme := theme_of(g)
	mut children := []ui2.Element{}
	children << ui2.label('', 'Slider, switch and checkbox', ui2.rect(col_a, 18, 600, 34),
		ui2.TextStyle{
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

	// Slider
	children << section('Slider', col_a, 72, theme)
	children << caption('Single value; press it, then use the arrow keys', col_a, 100, col_width,
		theme)
	children << ui2.styled_slider(volume_config(g)) or { panic(err) }
	children << value_text('${int(g.volume)}%', ui2.rect(col_a + 300, 141, 60, 24), theme)
	children << caption('Range, step 10, value bubbles and labelled marks', col_a, 176,
		col_width, theme)
	children << ui2.styled_slider(price_config(g)) or { panic(err) }
	children << caption('Steps of one snapping to tick marks: ${int(g.rating)} of 10',
		col_a, 268, col_width, theme)
	children << ui2.styled_slider(rating_config(g)) or { panic(err) }
	children << caption('Logarithmic scale, 20 Hz to 20 kHz', col_a, 338, col_width, theme)
	children << ui2.styled_slider(frequency_config(g)) or { panic(err) }
	children << caption('Small, medium and large', col_a, 412, col_width, theme)
	for size in [ui2.ComponentSize.small, .medium, .large] {
		children << ui2.styled_slider(size_slider_config(g, size)) or { panic(err) }
	}
	children << caption('Custom color; the fill shows the time remaining', col_a, 516,
		col_width, theme)
	children << ui2.styled_slider(remaining_config(g)) or { panic(err) }
	children << value_text('${int(g.remaining)} min', ui2.rect(col_a + 300, 534, 60, 24),
		theme)
	children << caption('Disabled range with marks', col_a, 566, col_width, theme)
	children << ui2.styled_slider(disabled_slider_config(g)) or { panic(err) }

	// Platform controls
	children << section('Platform controls', col_a, 628, theme)
	children << caption('slider, switch_control and checkbox; disabled copies below', col_a,
		656, col_width, theme)
	for row in 0 .. 2 {
		enabled := row == 0
		y := 676 + f64(row) * 36
		suffix := if enabled { '' } else { '-off' }
		children << ui2.slider(
			id:                  'native-slider${suffix}'
			frame:               ui2.rect(col_a, y, 200, 28)
			value:               g.native_value
			step:                1
			value_track:         true
			enabled:             enabled
			accessibility_label: 'Native slider'
			style:               ui2.SliderStyle{
				track_color:       theme.border
				value_track_color: theme.primary
				thumb_color:       theme.primary
				thumb_size:        16
			}
		)
		children << ui2.switch_control(
			id:                  'native-switch${suffix}'
			frame:               ui2.rect(col_a + 212, y, 48, 28)
			active:              g.native_switch
			enabled:             enabled
			accessibility_label: 'Native switch'
			style:               ui2.SwitchStyle{
				inactive_track_color: theme.border
				active_track_color:   theme.primary
				thumb_color:          if g.dark { theme.foreground } else { theme.background }
				disabled_track_color: if g.dark { theme.muted } else { u32(0xe2e8f0) }
				disabled_thumb_color: if g.dark { theme.border } else { u32(0xf8fafc) }
			}
		)
		children << ui2.Element{
			...ui2.checkbox('native-check${suffix}', 'Native', g.native_check, ui2.rect(col_a +
				272, y, 88, 28), ui2.TextStyle{
				color: theme.foreground
				size:  13
			})
			enabled: enabled
		}
	}

	// Switch
	children << section('Switch', col_b, 72, theme)
	children << caption('Label and description; a click focuses it', col_b, 100, col_width,
		theme)
	children << ui2.styled_switch(notifications_config(g)) or { panic(err) }
	children << caption('Label on the left, small: a settings list', col_b, 172, col_width,
		theme)
	children << ui2.view('', ui2.rect(col_b, 188, 300, 92), ui2.BoxStyle{
		bg:     theme.muted
		radius: 8
	}, []ui2.Element{})
	for i in 0 .. 3 {
		children << ui2.styled_switch(settings_switch_config(g, i)) or { panic(err) }
	}
	children << caption('Small, medium and large', col_b, 292, col_width, theme)
	for i in 0 .. 3 {
		children << ui2.styled_switch(size_switch_config(g, i)) or { panic(err) }
	}
	children << caption('Custom colors; disabled keeps its color at half strength', col_b,
		352, col_width, theme)
	for i in 0 .. 3 {
		children << ui2.styled_switch(color_switch_config(g, i)) or { panic(err) }
	}
	children << caption('Loading while a change applies; hover for a tooltip', col_b, 412,
		col_width, theme)
	children << ui2.styled_switch(sync_config(g)) or { panic(err) }
	children << ui2.styled_switch(airplane_config(g)) or { panic(err) }

	// Vertical sliders
	children << section('Vertical slider', col_b, 484, theme)
	children << caption('An equalizer, and a range with value bubbles', col_b, 510, col_width,
		theme)
	for i in 0 .. eq_names.len {
		children << ui2.styled_slider(eq_config(g, i)) or { panic(err) }
		db := int(g.eq[i])
		children << ui2.label('', '${if db > 0 { '+' } else { '' }}${db} dB', ui2.rect(col_b +
			f64(i) * 64, 716, 56, 18), ui2.TextStyle{
			color: theme.foreground
			size:  12
			align: .center
		})
		children << ui2.label('', eq_names[i], ui2.rect(col_b + f64(i) * 64, 734, 56, 18),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  12
				align: .center
			})
	}
	children << ui2.styled_slider(comfort_config(g)) or { panic(err) }
	children << ui2.label('', 'Comfort', ui2.rect(col_b + 200, 734, 160, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
		align: .center
	})

	// Checkbox
	children << section('Checkbox', col_c, 72, theme)
	children << caption('Label, description and indeterminate', col_c, 100, col_width, theme)
	for config in checkbox_configs(g)[..3] {
		children << ui2.styled_checkbox(config) or { panic(err) }
	}
	children << caption('Disabled', col_c, 228, col_width, theme)
	children << ui2.styled_checkbox(disabled_checkbox_config(g, false)) or { panic(err) }
	children << ui2.styled_checkbox(disabled_checkbox_config(g, true)) or { panic(err) }
	children << caption('Small, medium, large and without a label', col_c, 282, col_width,
		theme)
	for i in 0 .. 4 {
		children << ui2.styled_checkbox(size_checkbox_config(g, i)) or { panic(err) }
	}
	children << caption('Group with select all; one option is disabled', col_c, 338, col_width,
		theme)
	children << ui2.checkbox_group(notify_config(g)) or { panic(err) }
	children << caption('Horizontal group, wrapping onto a second row', col_c, 554, col_width,
		theme)
	children << ui2.checkbox_group(toppings_config(g)) or { panic(err) }

	children << ui2.label('', 'Keys: Tab and Shift+Tab move the focus ring; arrows, Page Up/Down, Home and End move a focused slider; Space toggles a focused switch or checkbox.',
		ui2.rect(col_a, 770, col_width, 54), ui2.TextStyle{
			color:  theme.muted_foreground
			size:   12
			lines:  3
			valign: .top
		})
	children << ui2.label('', g.message, ui2.rect(col_a, 830, col_width, 40), ui2.TextStyle{
		color:  theme.foreground
		size:   13
		lines:  2
		valign: .top
	})
	return ui2.screen(theme.background, children)
}

// ── Events ─────────────────────────────────────────────────────────

fn on_event(action string) {
	mut g := app()
	for config in slider_configs(g) {
		if change := ui2.styled_slider_change(config, action) {
			apply_slider(mut g, config.id, change)
			g.focus = config.id
			g.active = change.thumb
			if change.done {
				g.message = '${config.accessibility_label}: ${if config.range {
					'${ui2.styled_slider_value_text(config, change.start)} – ${ui2.styled_slider_value_text(config, change.end)}'
				} else {
					ui2.styled_slider_value_text(config, change.value)
				}}.'
			}
			ui2.refresh()
			return
		}
	}
	for config in switch_configs(g) {
		if checked := ui2.styled_switch_checked_from_action(config, action) {
			apply_switch(mut g, config.id, checked)
			g.focus = config.id
			g.message = '${config.label}: ${if checked { 'on' } else { 'off' }}.'
			ui2.refresh()
			return
		}
	}
	for config in checkbox_configs(g) {
		if checked := ui2.styled_checkbox_checked_from_action(config, action) {
			apply_checkbox(mut g, config.id, checked)
			g.message = '${if config.label.len > 0 {
				config.label
			} else {
				config.accessibility_label
			}}: ${if checked {
				'checked'
			} else {
				'unchecked'
			}}.'
			ui2.refresh()
			return
		}
	}
	if selection := ui2.checkbox_group_selection_from_action(notify_config(g), action) {
		g.notify = selection
		g.message = 'Notifications: ${selection}.'
	} else if selection := ui2.checkbox_group_selection_from_action(toppings_config(g),
		action)
	{
		g.toppings = selection
		g.message = 'Toppings: ${selection}.'
	} else {
		match action {
			'theme' {
				g.dark = !g.dark
			}
			'native-slider' {
				g.native_value = ui2.slider_value('native-slider')
				g.message = 'Native slider: ${int(g.native_value)}.'
			}
			'native-switch' {
				g.native_switch = ui2.switch_active('native-switch')
				g.message = 'Native switch: ${if g.native_switch { 'on' } else { 'off' }}.'
			}
			'native-check' {
				g.native_check = !g.native_check
				g.message = 'Native checkbox: ${if g.native_check { 'checked' } else { 'unchecked' }}.'
			}
			else {
				// Component events the decoders turned down (a drag that moves
				// nothing, a hover) change nothing.
				return
			}
		}
	}
	ui2.refresh()
}

// Components cannot capture keys, so the gallery routes them to the control it
// treats as focused.
fn on_key(event ui2.KeyEvent) {
	mut g := app()
	if event.code == .tab && !event.cmd && !event.ctrl && !event.alt {
		move_focus(mut g, event.shift)
		ui2.consume_key()
		ui2.refresh()
		return
	}
	if g.focus.len == 0 {
		return
	}
	for config in slider_configs(g) {
		if config.id == g.focus {
			change := ui2.styled_slider_change_after_key(config, event) or { return }
			apply_slider(mut g, config.id, change)
			g.active = change.thumb
			ui2.consume_key()
			ui2.refresh()
			return
		}
	}
	for config in switch_configs(g) {
		if config.id == g.focus {
			checked := ui2.styled_switch_checked_after_key(config, event) or { return }
			apply_switch(mut g, config.id, checked)
			ui2.consume_key()
			ui2.refresh()
			return
		}
	}
	for config in checkbox_configs(g) {
		if config.id == g.focus {
			checked := ui2.styled_checkbox_checked_after_key(config, event) or { return }
			apply_checkbox(mut g, config.id, checked)
			ui2.consume_key()
			ui2.refresh()
			return
		}
	}
}

fn main() {
	ui2.on_key_event(on_key)
	ui2.run_window('ui2 slider, switch and checkbox', window_width, window_height, build,
		on_event)
}
