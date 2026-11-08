// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// The search-selection, footer and search-reset cases follow the scenarios of
// GPUI Kit's crates/component/src/setting/tests.rs, rewritten against the pure
// functions and the decoder; the other tests are new. See third_party/gpui-kit.
module ui2

import math

// ── Fixtures ────────────────────────────────────────────────────────

fn fx_content(options SettingContentOptions) []Element {
	return [
		Element{
			...view('', rect(0, 0, options.width, options.height), BoxStyle{}, []Element{})
			accessibility_label: 'custom:${options.key}:${options.disabled}'
		},
	]
}

// fx_row is a custom row found by one keyword, like upstream's test items.
fn fx_row(keyword string) SettingItem {
	return SettingItem{
		kind:     .custom
		content:  fx_content
		keywords: [keyword]
	}
}

// fx_search_pages mirrors upstream's search fixture: General, Appearance
// (an untitled group, Colors and Fonts) and Editor.
fn fx_search_pages() []SettingPage {
	return [
		SettingPage{
			title:  'General'
			groups: [SettingGroup{
				items: [fx_row('language')]
			}]
		},
		SettingPage{
			title:        'Appearance'
			default_open: true
			groups:       [
				SettingGroup{
					items: [fx_row('unrelated')]
				},
				SettingGroup{
					title: 'Colors'
					items: [fx_row('theme colors')]
				},
				SettingGroup{
					title:  'Fonts'
					footer: 'Changes apply to this device only.'
					items:  [fx_row('unrelated'), fx_row('theme font')]
				},
			]
		},
		SettingPage{
			title:  'Editor'
			groups: [SettingGroup{
				items: [fx_row('theme editor')]
			}]
		},
	]
}

fn fx_pages() []SettingPage {
	return [
		SettingPage{
			id:           'general'
			title:        'General'
			icon:         'gearshape'
			description:  'Everyday *preferences*.'
			default_open: true
			groups:       [
				SettingGroup{
					title: 'Look'
					items: [
						SettingItem{
							key:           'dark'
							title:         'Dark mode'
							description:   'Switch between **light** and dark themes.'
							keywords:      ['theme']
							default_value: false
						},
						SettingItem{
							key:           'clock'
							title:         '24-hour clock'
							kind:          .checkbox
							default_value: true
						},
						SettingItem{
							key:           'lang'
							title:         'Language'
							kind:          .dropdown
							options:       [SettingOption{
								value: 'en'
								label: 'English'
							}, SettingOption{
								value: 'de'
								label: 'Deutsch'
							}, SettingOption{
								value: 'fr'
							}]
							default_value: 'en'
						},
					]
				},
				SettingGroup{
					title:  'Font'
					footer: 'Applies to new windows.'
					items:  [
						SettingItem{
							key:           'size'
							title:         'Font size'
							kind:          .number
							min:           8
							max:           72
							default_value: 14.0
						},
						SettingItem{
							key:           'spacing'
							title:         'Line height'
							kind:          .number
							min:           1
							max:           2.5
							step:          0.1
							precision:     1
							default_value: 1.5
						},
						SettingItem{
							key:           'volume'
							title:         'Volume'
							kind:          .slider
							min:           0
							max:           100
							step:          5
							unit:          '%'
							default_value: 50.0
						},
					]
				},
			]
		},
		SettingPage{
			id:     'advanced'
			title:  'Advanced'
			icon:   'slider.horizontal.3'
			groups: [
				SettingGroup{
					variant: .fill
					items:   [
						SettingItem{
							key:           'proxy'
							title:         'Proxy'
							kind:          .input
							layout:        .vertical
							placeholder:   'http://'
							default_value: ''
						},
						SettingItem{
							key:         'check'
							title:       'Updates'
							kind:        .button
							button_text: 'Check now'
						},
						SettingItem{
							key:           'mfa'
							title:         'Two-factor authentication'
							keywords:      ['MFA', '2FA']
							disabled:      true
							default_value: false
						},
						SettingItem{
							key:           'accent'
							title:         'Accent'
							kind:          .custom
							content:       fx_content
							field_width:   120
							default_value: '#2563eb'
						},
						SettingItem{
							kind:           .custom
							content:        fx_content
							content_height: 40
							keywords:       ['backup']
						},
					]
				},
			]
		},
	]
}

fn fx_config(state SettingsState, values map[string]SettingValue) SettingsConfig {
	return SettingsConfig{
		id:     's'
		frame:  rect(0, 0, 900, 640)
		pages:  fx_pages()
		values: values
		state:  state
	}
}

fn fx_state() SettingsState {
	return settings_initial_state(fx_pages())
}

fn fx_values() map[string]SettingValue {
	return settings_defaults(fx_pages())
}

fn fx_input(typed string, number f64) SettingsInput {
	return SettingsInput{
		text:   fn [typed] (id string) string {
			return typed
		}
		number: fn [number] (id string) f64 {
			return number
		}
	}
}

fn fx_no_input() SettingsInput {
	return SettingsInput{}
}

fn fx_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := fx_find(child, id) {
			return found
		}
	}
	return none
}

fn fx_find_key(el Element, key string) ?Element {
	if el.key == key {
		return el
	}
	for child in el.children {
		if found := fx_find_key(child, key) {
			return found
		}
	}
	return none
}

fn fx_has_label(el Element, caption string) bool {
	if el.kind == .label && el.text == caption {
		return true
	}
	for child in el.children {
		if fx_has_label(child, caption) {
			return true
		}
	}
	return false
}

fn fx_count_action(el Element, action string) int {
	mut count := if element_action_id(el) == action { 1 } else { 0 }
	for child in el.children {
		count += fx_count_action(child, action)
	}
	return count
}

fn fx_search(pages []SettingPage, state SettingsState, query string) SettingsState {
	return settings_resolve_state(pages, SettingsState{
		...state
		query: query
	})
}

fn fx_step(config SettingsConfig, action string, input SettingsInput) SettingsStep {
	return settings_update(config, action, input) or { panic('`${action}` was rejected') }
}

fn fx_rejected(config SettingsConfig, action string, input SettingsInput) bool {
	if _ := settings_update(config, action, input) {
		return false
	}
	return true
}

// ── Values ──────────────────────────────────────────────────────────

fn test_settings_values_compare_read_and_default() {
	assert setting_value_equal(SettingValue(true), SettingValue(true))
	assert !setting_value_equal(SettingValue(true), SettingValue(false))
	assert setting_value_equal(SettingValue(0.1 + 0.2), SettingValue(0.3))
	assert !setting_value_equal(SettingValue(1.0), SettingValue(1.01))
	assert setting_value_equal(SettingValue('a'), SettingValue('a'))
	assert !setting_value_equal(SettingValue('1'), SettingValue(1.0))
	assert !setting_value_equal(SettingValue(false), SettingValue(''))

	mut values := fx_values()
	assert values.len == 9 // Every item with a default; the button and custom row have none.
	assert setting_bool(values, 'clock')
	assert setting_number(values, 'size') == 14
	assert setting_string(values, 'lang') == 'en'
	assert !setting_bool(values, 'size') && setting_number(values, 'lang') == 0
	assert setting_string(values, 'missing') == ''

	pages := fx_pages()
	dark := pages[0].groups[0].items[0]
	assert settings_item_value(map[string]SettingValue{}, dark) == SettingValue(false)
	assert !settings_item_dirty(values, dark)
	values['dark'] = SettingValue(true)
	assert settings_item_dirty(values, dark)
	check := pages[1].groups[0].items[1]
	assert settings_item_value(values, check) == SettingValue('')
	assert !settings_item_dirty(values, check)

	step := SettingsStep{
		changes: [SettingChange{
			key:   'size'
			value: SettingValue(20.0)
		}, SettingChange{
			key:   'dark'
			value: SettingValue(false)
		}]
	}
	step.apply(mut values)
	assert setting_number(values, 'size') == 20
	assert !setting_bool(values, 'dark')
}

// ── Markdown and search ─────────────────────────────────────────────

fn test_settings_plain_text_strips_simple_markdown() {
	assert settings_plain_text('Plain text, unchanged.') == 'Plain text, unchanged.'
	assert settings_plain_text('**bold** and *italic*') == 'bold and italic'
	assert settings_plain_text('__bold__ and _italic_') == 'bold and italic'
	assert settings_plain_text('~~old~~ new') == 'old new'
	assert settings_plain_text('Run `v fmt` first') == 'Run v fmt first'
	assert settings_plain_text('See [the docs](https://example.com) for more') == 'See the docs for more'
	assert settings_plain_text('snake_case_name stays') == 'snake_case_name stays'
	assert settings_plain_text('2 * 3 = 6') == '2 * 3 = 6'
	assert settings_plain_text('a \\*literal\\* star') == 'a *literal* star'
	assert settings_plain_text('[not a link] here') == '[not a link] here'
	assert settings_plain_text('Rust doc for the `gpui-component` crate.') == 'Rust doc for the gpui-component crate.'
}

fn test_settings_item_matches_title_description_and_keywords() {
	item := SettingItem{
		key:         'mfa'
		title:       'Enable Two-factor auth'
		description: 'Ask for a **code** when signing in.'
		keywords:    ['MFA', '2FA']
	}
	for query in ['', '   ', 'two', 'TWO-FACTOR', 'code', 'mfa', '2fa', 'auth code', 'code  enable'] {
		assert settings_item_matches(item, query), query
	}
	for query in ['**code**', 'password', 'auth password', 'mfa2'] {
		assert !settings_item_matches(item, query), query
	}
	// A custom row has no title or description: only its keywords find it.
	row := fx_row('backup')
	assert settings_item_matches(row, '')
	assert settings_item_matches(row, 'Back')
	assert !settings_item_matches(row, 'custom')
}

fn test_settings_group_matching_ignores_group_title_and_footer() {
	pages := fx_search_pages()
	fonts := pages[1].groups[2]
	assert settings_group_matches(fonts, 'font')
	assert !settings_group_matches(fonts, 'fonts device')
	assert !settings_group_matches(fonts, 'device')
	assert settings_visible_groups(pages, 'theme') == [[]int{}, [1, 2], [0]]
	assert settings_visible_groups(pages, '') == [[0], [0, 1, 2], [0]]
	assert settings_match_count(pages[1], 'theme') == 2
	assert settings_match_count(pages[1], 'unrelated') == 2
	assert settings_match_count(pages[0], 'theme') == 0
}

// After upstream's search_preserves_the_page_and_clicks_use_original_indices.
fn test_settings_search_keeps_the_page_or_falls_back_to_the_first_match() {
	pages := fx_search_pages()
	mut state := SettingsState{
		page: 'Appearance'
	}
	state = fx_search(pages, state, 'theme')
	assert state.page == 'Appearance' && state.group == -1
	state = fx_search(pages, state, 'font')
	assert state.page == 'Appearance' && state.group == -1
	// Select Editor from the filtered list, then clear the search.
	state = fx_search(pages, state, 'theme')
	state = SettingsState{
		...state
		page: 'Editor'
	}
	state = fx_search(pages, state, '')
	assert state.page == 'Editor'
	// The current page stops matching: the first page that does is selected.
	state = fx_search(pages, state, 'font')
	assert state.page == 'Appearance'
	// Nothing matches: the selection is kept for when results return.
	state = fx_search(pages, state, 'no matching setting')
	assert state.page == 'Appearance'
	state = fx_search(pages, state, '')
	assert state.page == 'Appearance' && state.group == -1
}

// After upstream's search_preserves_group_and_item_identity.
fn test_settings_search_keeps_a_matching_group() {
	pages := fx_search_pages()
	mut state := SettingsState{
		page:  'Appearance'
		group: 2
	}
	state = fx_search(pages, state, 'theme')
	assert state.page == 'Appearance' && state.group == 2
	state = fx_search(pages, state, 'font')
	assert state.group == 2
	state = fx_search(pages, state, '')
	assert state.group == 2
	state = fx_search(pages, state, 'colors')
	assert state.page == 'Appearance' && state.group == -1
	// A group is kept only on the page that stays selected.
	moved := fx_search(pages, SettingsState{
		page:  'General'
		group: 0
	}, 'theme')
	assert moved.page == 'Appearance' && moved.group == -1
}

fn test_settings_resolve_and_initial_state() {
	pages := fx_search_pages()
	assert settings_resolve_state(pages, SettingsState{}).page == 'General'
	assert settings_resolve_state(pages, SettingsState{ page: 'Missing' }).page == 'General'
	assert settings_resolve_state(pages, SettingsState{ page: 'Missing', query: 'zzz' }).page == 'General'
	assert settings_resolve_state([]SettingPage{}, SettingsState{ page: 'x' }).page == 'x'
	initial := settings_initial_state(pages)
	assert initial.page == 'General'
	assert initial.group == -1
	assert initial.expanded == ['Appearance']
	assert settings_initial_state(fx_pages()).expanded == ['general']
}

// ── Decoding ────────────────────────────────────────────────────────

fn test_settings_update_search_reads_the_field_and_scrolls() {
	config := fx_config(fx_state(), fx_values())
	field := settings_search_field_id('s')
	step := fx_step(config, field, fx_input('2fa', 0))
	assert step.state.query == '2fa'
	assert step.state.page == 'advanced' // General has no match.
	assert step.scroll && step.scroll_id == settings_scroll_id('s', 'advanced')
	assert step.scroll_to == 0
	// Without a reader, or with the query unchanged, nothing happens.
	assert fx_rejected(config, field, fx_no_input())
	assert fx_rejected(fx_config(step.state, fx_values()), field, fx_input('2fa', 0))
	// The clear button empties the search, keeps the page and focuses the field.
	cleared := fx_step(fx_config(step.state, fx_values()), input_group_clear_action('s'),
		fx_no_input())
	assert cleared.state.query == ''
	assert cleared.state.page == 'advanced'
	assert cleared.focus == field
	// Clearing an empty search is not offered.
	assert fx_rejected(config, input_group_clear_action('s'), fx_no_input())
}

fn input_group_clear_action(id string) string {
	return component_part_id(settings_search_id(id), 'clear')
}

fn test_settings_update_selects_pages_and_groups() {
	mut state := SettingsState{
		page: 'general'
	}
	config := fx_config(state, fx_values())
	// Selecting a page with several titled groups lists them.
	step := fx_step(config, settings_page_action('s', 'general'), fx_no_input())
	assert step.state.expanded == ['general']
	assert step.scroll && step.scroll_to == 0
	advanced := fx_step(config, settings_page_action('s', 'advanced'), fx_no_input())
	assert advanced.state.page == 'advanced'
	assert advanced.state.expanded.len == 0 // One untitled group: nothing to list.
	assert advanced.scroll_id == settings_scroll_id('s', 'advanced')
	// Group rows exist only under an expanded page.
	assert fx_rejected(config, settings_group_action('s', 'general', 1), fx_no_input())
	state = step.state
	open := fx_config(state, fx_values())
	group := fx_step(open, settings_group_action('s', 'general', 1), fx_no_input())
	assert group.state.page == 'general' && group.state.group == 1
	offset := settings_group_offset(fx_config(group.state, fx_values()), 1) or { -1.0 }
	assert offset > 0 && group.scroll_to == offset
	assert group.scroll_id == settings_scroll_id('s', 'general')
	// Expand toggles.
	collapsed := fx_step(open, settings_expand_action('s', 'general'), fx_no_input())
	assert collapsed.state.expanded.len == 0
	assert fx_rejected(open, settings_expand_action('s', 'advanced'), fx_no_input())
	// Forged and foreign navigation.
	for forged in [settings_page_action('s', 'missing'), settings_group_action('s', 'general', 2),
		component_part_id('s', 'group:' + settings_hex('general') + ':01'),
		component_part_id('s', 'group:' + settings_hex('general')),
		settings_page_action('other', 'general'), component_part_id('s', 'page:zz')] {
		assert fx_rejected(open, forged, fx_no_input()), forged
	}
	// A page the search hides is not in the navigation.
	searching := fx_config(fx_search(fx_pages(), state, 'proxy'), fx_values())
	assert fx_rejected(searching, settings_page_action('s', 'general'), fx_no_input())
}

fn test_settings_update_toggles_reads_and_snaps_values() {
	config := fx_config(fx_state(), fx_values())
	dark := fx_step(config, settings_field_id('s', 'dark'), fx_no_input())
	assert dark.changes.len == 1
	assert dark.changes[0].key == 'dark' && dark.changes[0].value == SettingValue(true)
	clock := fx_step(config, settings_field_id('s', 'clock'), fx_no_input())
	assert clock.changes[0].value == SettingValue(false)
	// The slider's live value is read, snapped to its step and rounded.
	volume := fx_step(config, settings_field_id('s', 'volume'), fx_input('', 47.2))
	assert volume.changes[0].value == SettingValue(45.0)
	assert fx_rejected(config, settings_field_id('s', 'volume'), fx_input('', 51))
	assert fx_rejected(config, settings_field_id('s', 'volume'), fx_input('', math.nan()))
	assert fx_rejected(config, settings_field_id('s', 'volume'), fx_no_input())
	// A text field's text is read; an unchanged text is no change.
	advanced := fx_config(SettingsState{
		page: 'advanced'
	}, fx_values())
	proxy := fx_step(advanced, settings_field_id('s', 'proxy'), fx_input('http://proxy:8080',
		0))
	assert proxy.changes[0].value == SettingValue('http://proxy:8080')
	assert fx_rejected(advanced, settings_field_id('s', 'proxy'), fx_input('', 0))
	// A button reports its key and changes nothing.
	pressed := fx_step(advanced, settings_field_id('s', 'check'), fx_no_input())
	assert pressed.action == 'check' && pressed.changes.len == 0
}

fn test_settings_update_rejects_disabled_hidden_foreign_and_custom() {
	general := fx_config(fx_state(), fx_values())
	advanced := fx_config(SettingsState{
		page: 'advanced'
	}, fx_values())
	// Disabled items, items on another page, and items the search hides.
	assert fx_rejected(advanced, settings_field_id('s', 'mfa'), fx_no_input())
	assert fx_rejected(general, settings_field_id('s', 'proxy'), fx_input('x', 0))
	searching := fx_config(fx_search(fx_pages(), fx_state(), 'clock'), fx_values())
	assert fx_rejected(searching, settings_field_id('s', 'dark'), fx_no_input())
	assert !fx_rejected(searching, settings_field_id('s', 'clock'), fx_no_input())
	// Custom content belongs to the application.
	assert fx_rejected(advanced, settings_field_id('s', 'accent'), fx_no_input())
	for foreign in ['', 's', 'dark', 'other:component:field:' + settings_hex('dark'),
		settings_field_id('s', 'nope'), component_part_id('s', 'field:'),
		'pointer:enter:' + settings_field_id('s', 'dark') + ':1:2', component_part_id('s', 'bogus')] {
		assert fx_rejected(general, foreign, fx_no_input()), foreign
	}
	// An invalid configuration decodes nothing.
	broken := SettingsConfig{
		...general
		id: ''
	}
	assert fx_rejected(broken, settings_field_id('', 'dark'), fx_no_input())
}

fn test_settings_update_number_drafts_commits_and_steps() {
	number := settings_number_id('s', 'size')
	field := number_input_field_id(number)
	config := fx_config(fx_state(), fx_values())
	typed := fx_step(config, field, fx_input('20', 0))
	assert typed.changes.len == 1 && typed.changes[0].value == SettingValue(20.0)
	assert typed.state.draft_key == 'size' && typed.state.draft == '20'
	assert typed.sync_id == ''
	// Out of range: kept as a draft, shown as invalid, not stored.
	mut values := fx_values()
	low := fx_step(fx_config(typed.state, values), field, fx_input('1', 0))
	assert low.changes.len == 0 && low.state.draft == '1'
	shown := settings_number_input_config(fx_config(low.state, values), low.state, fx_pages()[0].groups[1].items[0],
		rect(0, 0, 100, 32))
	assert shown.text == '1' && shown.invalid
	// Letters are dropped and the field is told to show what is kept.
	cleaned := fx_step(fx_config(low.state, values), field, fx_input('12a', 0))
	assert cleaned.state.draft == '12'
	assert cleaned.sync_id == field && cleaned.sync_text == '12'
	assert cleaned.changes[0].value == SettingValue(12.0)
	// The same text again changes nothing.
	values['size'] = SettingValue(12.0)
	assert fx_rejected(fx_config(SettingsState{
		...cleaned.state
		draft: '12'
	}, values), field, fx_input('12', 0))
	// Return commits the draft, clamped, and puts the text right.
	far := SettingsState{
		...fx_state()
		draft_key: 'size'
		draft:     '200'
	}
	committed := fx_step(fx_config(far, values), component_part_id(number, 'submit'),
		fx_no_input())
	assert committed.changes[0].value == SettingValue(72.0)
	assert committed.sync_text == '72' && committed.state.draft_key == ''
	// Steps move from the stored value.
	up := fx_step(fx_config(fx_state(), fx_values()), component_part_id(number, 'increment'),
		fx_no_input())
	assert up.changes[0].value == SettingValue(15.0)
	spacing := settings_number_id('s', 'spacing')
	finer := fx_step(fx_config(fx_state(), fx_values()), component_part_id(spacing, 'increment'),
		fx_no_input())
	assert finer.changes[0].value == SettingValue(1.6)
	mut top := fx_values()
	top['spacing'] = SettingValue(2.5)
	assert fx_rejected(fx_config(fx_state(), top), component_part_id(spacing, 'increment'),
		fx_no_input())
	// With a draft, steps go from the draft.
	drafted := SettingsState{
		...fx_state()
		draft_key: 'size'
		draft:     '30'
	}
	from_draft := fx_step(fx_config(drafted, fx_values()), component_part_id(number, 'decrement'),
		fx_no_input())
	assert from_draft.changes[0].value == SettingValue(29.0)
	assert from_draft.state.draft_key == '' && from_draft.sync_text == '29'
	// Any other action drops the draft.
	other := fx_step(fx_config(typed.state, fx_values()), settings_field_id('s', 'dark'),
		fx_no_input())
	assert other.state.draft_key == ''
}

fn test_settings_update_dropdown_menu() {
	menu := settings_menu_id('s', 'lang')
	toggle := dropdown_menu_toggle_action(menu)
	closed := fx_config(fx_state(), fx_values())
	opened := fx_step(closed, toggle, fx_no_input())
	assert opened.state.menu == 'lang' && opened.state.menu_state.open
	open := fx_config(opened.state, fx_values())
	// The pointer highlights a row.
	row := dropdown_menu_item_action(menu, [1])
	hovered := fx_step(open, 'pointer:enter:${row}:10:10', fx_no_input())
	assert hovered.state.menu_state.path == [1]
	// Choosing a row stores its value and closes the menu.
	chosen := fx_step(open, row, fx_no_input())
	assert chosen.changes.len == 1 && chosen.changes[0].value == SettingValue('de')
	assert chosen.state.menu == ''
	// Choosing the current value only closes it.
	same := fx_step(open, dropdown_menu_item_action(menu, [0]), fx_no_input())
	assert same.changes.len == 0 && same.state.menu == ''
	// The toggle and the backdrop close it.
	assert fx_step(open, toggle, fx_no_input()).state.menu == ''
	assert fx_step(open, dropdown_menu_dismiss_action(menu), fx_no_input()).state.menu == ''
	// Rows of a closed menu do nothing.
	assert fx_rejected(closed, row, fx_no_input())
	// Any other settings action closes the menu as well.
	other := fx_step(open, settings_field_id('s', 'dark'), fx_no_input())
	assert other.state.menu == '' && other.changes.len == 1
	// The rendered menu lists the options with the current one checked.
	el := settings(open) or { panic(err) }
	rows := fx_find(el, menu) or { panic('the open menu is not drawn') }
	assert !rows.hidden
	content := fx_find(el, settings_scroll_id('s', 'general')) or { panic('no content scroll') }
	assert fx_find(content, menu) != none // Inside the page's scroll, so it scrolls with it.
	trigger := fx_find(el, settings_dropdown_id('s', 'lang')) or { panic('no trigger') }
	assert trigger.accessibility_role == 'combobox'
	assert trigger.accessibility_value == 'English'
	assert element_action_id(trigger) == toggle
}

fn test_settings_update_resets_items_and_pages() {
	mut values := fx_values()
	values['dark'] = SettingValue(true)
	values['size'] = SettingValue(20.0)
	values['volume'] = SettingValue(80.0)
	config := fx_config(fx_state(), values)
	one := fx_step(config, settings_reset_action('s', 'dark'), fx_no_input())
	assert one.changes == [SettingChange{
		key:   'dark'
		value: SettingValue(false)
		reset: true
	}]
	assert fx_rejected(config, settings_reset_action('s', 'clock'), fx_no_input()) // Not dirty.
	all := fx_step(config, settings_reset_page_action('s', 'general'), fx_no_input())
	assert all.changes.map(it.key) == ['dark', 'size', 'volume']
	assert all.changes.all(it.reset)
	// While searching, Reset all leaves the settings it does not show alone.
	searching := fx_config(fx_search(fx_pages(), fx_state(), 'font'), values)
	found := fx_step(searching, settings_reset_page_action('s', 'general'), fx_no_input())
	assert found.changes.map(it.key) == ['size']
	// Another page's Reset all, and a page with nothing to reset.
	assert fx_rejected(config, settings_reset_page_action('s', 'advanced'), fx_no_input())
	assert fx_rejected(fx_config(fx_state(), fx_values()), settings_reset_page_action('s',
		'general'), fx_no_input())
	// Disabled items and pages that are not resettable keep their values.
	mut locked := fx_values()
	locked['mfa'] = SettingValue(true)
	locked['accent'] = SettingValue('#ff0000')
	advanced := fx_config(SettingsState{
		page: 'advanced'
	}, locked)
	assert fx_rejected(advanced, settings_reset_action('s', 'mfa'), fx_no_input())
	custom := fx_step(advanced, settings_reset_page_action('s', 'advanced'), fx_no_input())
	assert custom.changes.map(it.key) == ['accent']
	mut pages := fx_pages()
	pages[0] = SettingPage{
		...pages[0]
		resettable: false
	}
	fixed := SettingsConfig{
		...config
		pages: pages
	}
	assert fx_rejected(fixed, settings_reset_action('s', 'dark'), fx_no_input())
	assert fx_rejected(fixed, settings_reset_page_action('s', 'general'), fx_no_input())
}

fn test_settings_key_drives_menus_search_and_numbers() {
	menu_state := SettingsState{
		...fx_state()
		menu:       'lang'
		menu_state: DropdownMenuState{}.opened()
	}
	open := fx_config(menu_state, fx_values())
	down := settings_key(open, '', KeyEvent{ code: .down }) or { panic('down was ignored') }
	assert down.state.menu_state.path == [0]
	down2 := settings_key(fx_config(down.state, fx_values()), '', KeyEvent{ code: .down }) or {
		panic('down was ignored')
	}
	enter := settings_key(fx_config(down2.state, fx_values()), '', KeyEvent{ code: .enter }) or {
		panic('enter was ignored')
	}
	assert enter.changes[0].value == SettingValue('de') && enter.state.menu == ''
	escape := settings_key(open, '', KeyEvent{ code: .escape }) or { panic('escape was ignored') }
	assert escape.state.menu == '' && escape.changes.len == 0
	// Escape in the search field clears it.
	search := settings_search_field_id('s')
	searching := fx_config(fx_search(fx_pages(), fx_state(), 'font'), fx_values())
	cleared := settings_key(searching, search, KeyEvent{ code: .escape }) or {
		panic('escape was ignored')
	}
	assert cleared.state.query == ''
	if _ := settings_key(fx_config(fx_state(), fx_values()), search, KeyEvent{ code: .escape }) {
		assert false, 'escape in an empty search'
	}
	// Up and Down step a focused number field.
	field := number_input_field_id(settings_number_id('s', 'size'))
	up := settings_key(fx_config(fx_state(), fx_values()), field, KeyEvent{ code: .up }) or {
		panic('up was ignored')
	}
	assert up.changes[0].value == SettingValue(15.0)
	assert up.sync_id == field && up.sync_text == '15'
	if _ := settings_key(fx_config(fx_state(), fx_values()), field, KeyEvent{
		code:  .up
		shift: true
	})
	{
		assert false, 'shift+up stepped'
	}
	if _ := settings_key(fx_config(fx_state(), fx_values()), 'elsewhere', KeyEvent{ code: .up }) {
		assert false, 'a key away from the settings was taken'
	}
}

// ── Layout ──────────────────────────────────────────────────────────

fn test_settings_layout_rows_groups_and_stacking() {
	config := fx_config(fx_state(), fx_values())
	wide := settings_page_layout(config, config.state, 0, 660)
	assert !wide.stacked
	assert wide.groups.len == 2
	look := wide.groups[0]
	assert look.title.height > 0
	assert look.surface.y >= look.title.y + look.title.height
	assert look.items.len == 3 && look.separators.len == 0 // The default variant is normal.
	for box in look.items {
		assert box.layout == .horizontal
		assert box.field.x + box.field.width <= look.surface.x + look.surface.width + 0.001
		assert box.title.x + box.title.width <= box.field.x
		assert box.field.y >= box.row.y && box.field.y + box.field.height <= box.row.y + box.row.height
	}
	// Resettable items keep room for their reset button left of the control.
	dark := look.items[0]
	assert dark.reset.width > 0 && dark.reset.x + dark.reset.width <= dark.field.x
	assert dark.description.height > 0
	// Groups follow each other; the footer sits below the surface.
	font := wide.groups[1]
	assert font.frame.y > look.frame.y + look.frame.height
	assert font.footer.y >= font.surface.y + font.surface.height
	assert wide.height > font.frame.y + font.frame.height
	// Narrow pages stack every item.
	narrow := settings_page_layout(config, config.state, 0, 420)
	assert narrow.stacked
	for box in narrow.groups[0].items {
		assert box.layout == .vertical
		assert box.field.y >= box.title.y + box.title.height
	}
	lang := narrow.groups[0].items[2]
	assert lang.field.width == lang.row.width // Wide controls fill a stacked row.
	// The vertical item and the full-width custom row, in a fill group.
	advanced := settings_page_layout(config, config.state, 1, 660).groups[0]
	assert advanced.variant == .fill && advanced.separators.len == 4
	assert advanced.title.height == 0
	proxy := advanced.items[0]
	assert proxy.layout == .vertical && proxy.field.y > proxy.title.y
	row := advanced.items[4]
	assert row.full && row.field.width == row.row.width && row.field.height == 40
	accent := advanced.items[3]
	assert accent.field.width == 120
	// A search lays out only what matches.
	found := settings_page_layout(config, fx_search(fx_pages(), config.state, 'volume'), 0,
		660)
	assert found.groups.len == 1 && found.groups[0].items.len == 1
	assert found.groups[0].items[0].item == 2
}

fn test_settings_group_variant_overrides_the_default() {
	mut config := fx_config(fx_state(), fx_values())
	config = SettingsConfig{
		...config
		group_variant: .outline
	}
	general := settings_page_layout(config, config.state, 0, 660)
	assert general.groups[0].variant == .outline
	assert general.groups[0].separators.len == 2
	// Items sit inside an outlined surface, inset from its edges.
	box := general.groups[0].items[0]
	assert box.row.x > general.groups[0].surface.x
	// A group's own variant wins.
	assert settings_page_layout(config, config.state, 1, 660).groups[0].variant == .fill
	normal := settings_page_layout(fx_config(fx_state(), fx_values()), config.state, 0,
		660)
	assert normal.groups[0].items[0].row.x == normal.groups[0].surface.x
}

fn test_settings_text_lines_estimate() {
	assert settings_text_lines('', 13, 200) == 0
	assert settings_text_lines('One line', 13, 400) == 1
	long := 'word '.repeat(60)
	lines := settings_text_lines(long, 13, 200)
	assert lines > 3
	assert settings_text_lines(long, 13, 100) > lines
	assert settings_text_lines('first\nsecond', 13, 400) == 2
	assert settings_text_lines('x'.repeat(200), 13, 100) > 1
	assert settings_text_width('MMM', 13) > settings_text_width('iii', 13)
	assert settings_text_width('日本', 13) > settings_text_width('ab', 13)
}

fn test_settings_nav_layout_lists_pages_groups_and_counts() {
	config := fx_config(fx_state(), fx_values())
	nav := settings_nav_layout(config, config.state)
	// General is expanded with its two titled groups; Advanced has none.
	assert nav.rows.map(it.group) == [-1, 0, 1, -1]
	assert nav.rows[0].active && nav.rows[0].caret.width > 0 && nav.rows[0].open
	assert nav.rows[3].caret.width == 0
	assert nav.rows.all(it.count == -1)
	for i in 1 .. nav.rows.len {
		assert nav.rows[i].frame.y >= nav.rows[i - 1].frame.y + nav.rows[i - 1].frame.height
	}
	assert nav.search.y + nav.search.height <= nav.list.y
	// A selected group takes the highlight from its page.
	grouped := settings_nav_layout(config, SettingsState{
		...config.state
		group: 1
	})
	assert !grouped.rows[0].active && grouped.rows[2].active
	// Searching filters the pages and counts the matches.
	searching := settings_nav_layout(config, fx_search(fx_pages(), config.state, 'mfa'))
	assert searching.rows.len == 1
	assert searching.rows[0].page == 1 && searching.rows[0].count == 1
}

// ── Rendering ───────────────────────────────────────────────────────

fn test_settings_render_tree_ids_and_accessibility() {
	mut values := fx_values()
	values['dark'] = SettingValue(true)
	el := settings(fx_config(fx_state(), values)) or { panic(err) }
	assert el.id == 's' && el.accessibility_role == 'group'
	assert el.accessibility_label == 'Settings'
	nav := fx_find_key(el, 'nav') or { panic('no navigation') }
	assert nav.accessibility_role == 'navigation'
	assert fx_find(el, settings_search_field_id('s')) != none
	page := fx_find(el, settings_page_action('s', 'general')) or { panic('no page row') }
	assert page.button_behavior && page.accessibility_value == 'current'
	other := fx_find(el, settings_page_action('s', 'advanced')) or { panic('no page row') }
	assert other.accessibility_value == ''
	assert fx_find(el, settings_group_action('s', 'general', 1)) != none
	assert fx_find(el, settings_expand_action('s', 'general')) != none
	// Controls.
	dark := fx_find(el, settings_field_id('s', 'dark')) or { panic('no switch') }
	assert dark.accessibility_role == 'switch' && dark.accessibility_value == 'on'
	assert dark.accessibility_label == 'Dark mode' && dark.button_behavior
	clock := fx_find(el, settings_field_id('s', 'clock')) or { panic('no checkbox') }
	assert clock.accessibility_role == 'checkbox' && clock.accessibility_value == 'checked'
	size := fx_find(el, number_input_field_id(settings_number_id('s', 'size'))) or {
		panic('no number field')
	}
	assert size.kind == .text_field && size.text == '14'
	volume := fx_find(el, settings_field_id('s', 'volume')) or { panic('no slider') }
	assert volume.kind == .slider && volume.value == 50 && volume.accessibility_value == '50%'
	assert fx_has_label(el, '50%')
	// Markdown is shown as plain text.
	assert fx_has_label(el, 'Switch between light and dark themes.')
	assert fx_has_label(el, 'Everyday preferences.')
	assert fx_has_label(el, 'Applies to new windows.')
	// Reset shows only for the dirty item, and Reset all with it.
	assert fx_find(el, settings_reset_action('s', 'dark')) != none
	assert fx_find(el, settings_reset_action('s', 'clock')) == none
	reset_all := fx_find(el, settings_reset_page_action('s', 'general')) or {
		panic('no Reset all')
	}
	assert reset_all.tooltip.len > 0
	clean := settings(fx_config(fx_state(), fx_values())) or { panic(err) }
	assert fx_find(clean, settings_reset_page_action('s', 'general')) == none
	assert fx_find(clean, settings_reset_action('s', 'dark')) == none
}

fn test_settings_render_advanced_page_controls() {
	mut values := fx_values()
	values['accent'] = SettingValue('#ff0000')
	el := settings(fx_config(SettingsState{
		page: 'advanced'
	}, values)) or { panic(err) }
	proxy := fx_find(el, settings_field_id('s', 'proxy')) or { panic('no field') }
	assert proxy.kind == .text_field && proxy.placeholder == 'http://'
	mfa := fx_find(el, settings_field_id('s', 'mfa')) or { panic('no switch') }
	assert !mfa.enabled
	button := fx_find(el, settings_field_id('s', 'check')) or { panic('no button') }
	assert button.button_behavior && button.enabled
	// Custom content is built for its frame and told whether it is disabled.
	assert fx_count_label(el, 'custom:accent:false') == 1
	assert fx_count_label(el, 'custom::false') == 1
	assert fx_find(el, settings_reset_action('s', 'accent')) != none
	assert fx_count_action(el, settings_reset_action('s', 'accent')) == 1
}

fn fx_count_label(el Element, caption string) int {
	mut count := if el.accessibility_label == caption { 1 } else { 0 }
	for child in el.children {
		count += fx_count_label(child, caption)
	}
	return count
}

fn test_settings_render_search_results_and_empty_state() {
	searching := fx_config(fx_search(fx_pages(), fx_state(), 'font'), fx_values())
	el := settings(searching) or { panic(err) }
	assert fx_find(el, number_input_field_id(settings_number_id('s', 'size'))) != none
	assert fx_find(el, settings_field_id('s', 'dark')) == none
	assert fx_find(el, settings_page_action('s', 'advanced')) == none
	badge := fx_find_key(el, 'count') or { panic('no match count') }
	assert badge.children[0].text == '1' // Only Font size matches on General.
	// The footer follows its group.
	assert fx_has_label(el, 'Applies to new windows.')
	hidden := settings(fx_config(fx_search(fx_pages(), fx_state(), 'dark'), fx_values())) or {
		panic(err)
	}
	assert !fx_has_label(hidden, 'Applies to new windows.')
	// Nothing matches: no page, a status instead.
	empty := settings(fx_config(fx_search(fx_pages(), fx_state(), 'zebra'), fx_values())) or {
		panic(err)
	}
	status := fx_find_key(empty, 'empty') or { panic('no empty state') }
	assert status.accessibility_role == 'status'
	assert fx_has_label(empty, 'No matching settings')
	assert fx_find(empty, settings_scroll_id('s', 'general')) == none
}

fn test_settings_render_title_suffix_and_stacked_layout() {
	mut pages := fx_pages()
	pages[0] = SettingPage{
		...pages[0]
		title_suffix:       fn (options SettingContentOptions) []Element {
			return [
				Element{
					...view('help', rect(0, 0, options.width, options.height), BoxStyle{}, []Element{})
					accessibility_label: 'suffix ${int(options.width)}x${int(options.height)}'
				},
			]
		}
		title_suffix_width: 24
	}
	config := SettingsConfig{
		...fx_config(fx_state(), fx_values())
		pages: pages
		frame: rect(0, 0, 640, 500)
	}
	el := settings(config) or { panic(err) }
	suffix := fx_find(el, 'help') or { panic('no title suffix') }
	assert suffix.accessibility_label == 'suffix 24x32'
	// 640 - 240 leaves 400 for the page: the items stack.
	lang := fx_find(el, settings_dropdown_id('s', 'lang')) or { panic('no dropdown') }
	assert lang.frame.width > 300
}

fn test_settings_validation() {
	base := fx_config(fx_state(), fx_values())
	settings(base) or { panic(err) }
	bad_pages := [
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:   'x'
					title: 'X'
				}, SettingItem{
					key:   'x'
					title: 'Y'
				}]
			}]
		}],
		[SettingPage{
			title: 'A'
		}, SettingPage{
			title: 'A'
		}],
		[SettingPage{
			title: 'A'
			icon:  'no.such.symbol'
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:   's'
					title: 'Slider'
					kind:  .slider
					max:   10
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:           'd'
					title:         'Dropdown'
					kind:          .dropdown
					options:       [SettingOption{
						value: 'a'
					}]
					default_value: 'b'
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:           'n'
					title:         'Number'
					kind:          .number
					default_value: true
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:   'c'
					title: 'Custom'
					kind:  .custom
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					title: 'No key'
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:   'b'
					title: 'Button'
					kind:  .button
				}]
			}]
		}],
		[SettingPage{
			title:  'A'
			groups: [SettingGroup{
				items: [SettingItem{
					key:   'n'
					title: 'Number'
					kind:  .number
					min:   5
					max:   1
				}]
			}]
		}],
	]
	for index, pages in bad_pages {
		if _ := settings(SettingsConfig{
			...base
			pages: pages
		})
		{
			assert false, 'configuration ${index} was accepted'
		}
	}
	if _ := settings(SettingsConfig{
		...base
		id: ' '
	})
	{
		assert false, 'an empty id was accepted'
	}
	if _ := settings(SettingsConfig{
		...base
		nav_width: -1
	})
	{
		assert false, 'a negative navigation width was accepted'
	}
	// Edge sizes still build.
	settings(SettingsConfig{
		...base
		frame: rect(0, 0, 0, 0)
	}) or { panic(err) }
	settings(SettingsConfig{
		...base
		frame:     rect(0, 0, 200, 100)
		nav_width: 400
	}) or { panic(err) }
	settings(SettingsConfig{
		...base
		size:  .small
		theme: component_theme(true)
	}) or { panic(err) }
	settings(SettingsConfig{
		...base
		size:  .large
		pages: []SettingPage{}
	}) or { panic(err) }
}
