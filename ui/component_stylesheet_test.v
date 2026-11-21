module ui2

// The component stylesheet contract: every composite component tags its
// root and styleable parts with classes, so sheets can target them. Builder
// fields still win over sheets (inline wins); classes unlock scoping,
// state-qualified rules, and every property the builder left default
// (borders, shadows, opacity, radii and text where unset).

fn component_style_find(root Element, class string) []Element {
	mut found := []Element{}
	if class in root.classes {
		found << root
	}
	for child in root.children {
		found << component_style_find(child, class)
	}
	return found
}

fn test_component_switch_classes_and_sheet() {
	el := styled_switch(StyledSwitchConfig{
		id:            'wifi'
		frame:         rect(0, 0, 280, 48)
		label:         'Wi-Fi'
		checked:       true
		reduce_motion: true
	})!
	assert 'switch' in el.classes
	assert component_style_find(el, 'switch-track').len == 1
	assert component_style_find(el, 'switch-thumb').len == 1
	// Borders are unset by the builder, so the sheet owns them.
	styled := apply_stylesheet(el, parse_stylesheet('.switch-track { border-color: #ff0000; border-width: 2px; } .switch-thumb { opacity: 0.5; }')!,
		StyleMatchEnv{})
	track := component_style_find(styled, 'switch-track')[0]
	assert track.box.border_color == 0xff0000
	assert track.box.border_left == 2.0
	thumb := component_style_find(styled, 'switch-thumb')[0]
	assert thumb.box.opacity == 0.5
	// Inline wins: the sheet cannot repaint the themed track fill.
	assert track.box.bg != 0xff0000
}

fn test_component_slider_classes() {
	el := styled_slider(StyledSliderConfig{
		id:    'vol'
		frame: rect(0, 0, 300, 60)
		min:   0
		max:   100
		value: 40
	})!
	assert 'slider' in el.classes
	assert component_style_find(el, 'slider-track').len == 1
	assert component_style_find(el, 'slider-bar').len >= 1
	assert component_style_find(el, 'slider-fill').len == 1
	assert component_style_find(el, 'slider-thumb').len == 1
	styled := apply_stylesheet(el, parse_stylesheet('.slider-fill { opacity: 0.75; }')!,
		StyleMatchEnv{})
	for bar in component_style_find(styled, 'slider-fill') {
		assert bar.box.opacity == 0.75
	}
}

fn test_component_progress_classes() {
	el := linear_progress(LinearProgressConfig{
		id:    'load'
		frame: rect(0, 0, 200, 8)
		value: 50
	})!
	assert 'linear-progress' in el.classes
	assert component_style_find(el, 'linear-progress-track').len == 1
	assert component_style_find(el, 'linear-progress-indicator').len == 1
}

fn test_component_checkbox_radio_classes() {
	box := styled_checkbox(StyledCheckboxConfig{
		id:    'agree'
		frame: rect(0, 0, 280, 32)
		label: 'Agree'
	})!
	assert 'styled-checkbox' in box.classes
	assert component_style_find(box, 'checkbox-indicator').len == 1
	group := checkbox_group(CheckboxGroupConfig{
		id:      'picks'
		frame:   rect(0, 0, 280, 96)
		options: [
			CheckboxOption{
				label: 'A'
				value: 'a'
			},
		]
	})!
	assert 'checkbox-group' in group.classes
	assert component_style_find(group, 'checkbox-option').len == 1
	radio := radio(RadioConfig{
		id:    'choice'
		frame: rect(0, 0, 280, 32)
		label: 'One'
	})!
	assert 'radio' in radio.classes
	assert component_style_find(radio, 'radio-indicator').len == 1
	assert component_style_find(radio, 'radio-label').len == 1
}

fn test_component_toggle_button_classes() {
	toggle_el := toggle(ToggleConfig{
		id:    'bold'
		frame: rect(0, 0, 96, 32)
		label: 'Bold'
	})!
	assert 'toggle' in toggle_el.classes
	btn := styled_button(StyledButtonConfig{
		id:    'go'
		frame: rect(0, 0, 96, 32)
		label: 'Go'
	})!
	assert 'styled-button' in btn.classes
}

fn test_component_stepper_rating_classes() {
	// Stepper needs at least one item; the config surface is wide, so only
	// the class contract is asserted here through a minimal build below.
	stepper_el := stepper(StepperConfig{
		id:    'steps'
		frame: rect(0, 0, 300, 120)
		items: [
			StepperItem{
				title: 'First'
			},
		]
	})!
	assert 'stepper' in stepper_el.classes
	assert component_style_find(stepper_el, 'stepper-step').len == 1
	assert component_style_find(stepper_el, 'stepper-connector').len == 0
	// A single step has no connectors between steps.
	rated := rating(RatingConfig{
		id:    'stars'
		frame: rect(0, 0, 150, 30)
		max:   5
		value: 3
	})!
	assert 'rating' in rated.classes
	assert component_style_find(rated, 'rating-star').len == 5
}

fn test_component_select_classes() {
	el := select_box(SelectConfig{
		id:       'fruit'
		frame:    rect(20, 40, 200, 32)
		window:   rect(0, 0, 800, 600)
		options:  [
			PickerOption{
				value: 'pear'
				label: 'Pear'
			},
		]
		selected: []string{}
	})!
	assert 'select' in el.classes
	assert component_style_find(el, 'select-trigger').len == 1
	assert component_style_find(el, 'select-placeholder').len == 1
	combo := combobox(ComboboxConfig{
		id:          'search'
		frame:       rect(20, 40, 200, 32)
		window:      rect(0, 0, 800, 600)
		placeholder: 'Search…'
	})!
	assert 'combobox' in combo.classes
	assert component_style_find(combo, 'combobox-toggle').len == 1
}

fn test_component_picker_rows_share_contract() {
	popup := select_popup(SelectConfig{
		id:       'fruit'
		frame:    rect(20, 40, 200, 32)
		window:   rect(0, 0, 800, 600)
		options:  [
			PickerOption{
				value: 'pear'
				label: 'Pear'
			},
			PickerOption{
				value: 'plum'
				label: 'Plum'
			},
		]
		selected: ['pear']
		state:    SelectState{
			open: true
		}
	})!
	rows := component_style_find(popup, 'picker-option')
	assert rows.len == 2
	assert rows.count(it.classes.contains('selected')) == 1
}

fn test_component_dialog_classes() {
	dialog := modal_dialog(DialogConfig{
		id:          'profile'
		frame:       rect(0, 0, 1000, 800)
		open:        true
		title:       'Edit profile'
		description: 'Make changes.'
		buttons:     [
			DialogButton{
				id:   'ok'
				text: 'OK'
			},
		]
	})!
	assert 'dialog' in dialog.classes
	assert component_style_find(dialog, 'dialog-surface').len == 1
	assert component_style_find(dialog, 'dialog-title').len == 1
	assert component_style_find(dialog, 'dialog-description').len == 1
	assert component_style_find(dialog, 'dialog-button').len == 1
	sheet_el := sheet(SheetConfig{
		id:    'panel'
		frame: rect(0, 0, 1000, 800)
		open:  true
		title: 'Panel'
	})!
	assert 'sheet' in sheet_el.classes
	assert component_style_find(sheet_el, 'sheet-panel').len == 1
	alert := alert_dialog(AlertDialogConfig{
		id:    'warn'
		frame: rect(0, 0, 1000, 800)
		open:  true
		title: 'Sure?'
	})!
	assert 'alert-dialog' in alert.classes
	assert 'dialog' in alert.classes
}

fn test_component_toolbar_tab_classes() {
	bar := toolbar(ToolbarConfig{
		id:    'main'
		frame: rect(0, 0, 600, 40)
		items: [
			BarItem{
				id:    'save'
				label: 'Save'
			},
		]
	})!
	assert 'toolbar' in bar.classes
	assert component_style_find(bar, 'toolbar-item').len == 1
	tabs := tab_bar(TabBarConfig{
		id:    'bar'
		frame: rect(0, 0, 600, 48)
		items: [
			TabBarItem{
				id:    'home'
				label: 'Home'
			},
		]
		state: TabBarState{
			selected: 'home'
		}
	})!
	assert 'tab-bar' in tabs.classes
	tab := component_style_find(tabs, 'tab')
	assert tab.len == 1
	assert 'selected' in tab[0].classes
	assert component_style_find(tabs, 'tab-label').len == 1
}

fn test_component_display_input_classes() {
	b := badge(BadgeConfig{
		frame: rect(0, 0, 48, 24)
		text:  '3'
	})!
	assert 'badge' in b.classes
	assert component_style_find(b, 'badge-text').len == 1
	av := avatar(AvatarConfig{
		frame: rect(0, 0, 40, 40)
		name:  'Ada Lovelace'
	})!
	assert 'avatar' in av.classes
	assert component_style_find(av, 'avatar-initials').len == 1
	t := tag(TagConfig{
		frame: rect(0, 0, 120, 28)
		text:  'v1.0'
	})!
	assert 'tag' in t.classes
	assert component_style_find(t, 'tag-text').len == 1
	num := number_input(NumberInputConfig{
		id:    'qty'
		frame: rect(0, 0, 160, 32)
	})!
	assert 'number-input' in num.classes
	assert component_style_find(num, 'number-input-button').len == 2
	otp := otp_input(OtpInputConfig{
		id:     'code'
		frame:  rect(0, 0, 240, 48)
		length: 4
	})!
	assert 'otp-input' in otp.classes
	assert component_style_find(otp, 'otp-input-cell').len == 4
}
