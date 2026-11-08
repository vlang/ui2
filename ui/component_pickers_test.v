module ui2

import math

const picker_test_window = rect(0, 0, 800, 600)

fn picker_test_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := picker_test_find(child, id) {
			return found
		}
	}
	return none
}

fn picker_test_texts(el Element, mut out []string) {
	if el.kind == .label && el.text.len > 0 {
		out << el.text
	}
	for child in el.children {
		picker_test_texts(child, mut out)
	}
}

fn picker_test_labels(el Element) []string {
	mut out := []string{}
	picker_test_texts(el, mut out)
	return out
}

fn picker_test_count_role(el Element, role string) int {
	mut count := if el.accessibility_role == role { 1 } else { 0 }
	for child in el.children {
		count += picker_test_count_role(child, role)
	}
	return count
}

fn picker_test_ranges(found PickerMatch) [][]int {
	return found.ranges.map([it.start, it.end])
}

// ── Matching ───────────────────────────────────────────────────────

fn test_picker_match_empty_query_matches_everything() {
	for mode in [PickerMatchMode.substring, .fuzzy] {
		found := picker_match('  ', 'Anything', mode) or { panic('blank query rejected') }
		assert found.score == 0
		assert found.ranges.len == 0
	}
}

fn test_picker_substring_match_ignores_case_and_prefers_word_starts() {
	found := picker_match('SAN', 'San Francisco', .substring) or { panic('no match') }
	assert picker_test_ranges(found) == [[0, 3]]
	// "an" occurs inside "Banana" twice and at the start of "and": the word wins.
	word := picker_match('an', 'Banana and', .substring) or { panic('no match') }
	assert picker_test_ranges(word) == [[7, 9]]
	if _ := picker_match('nas', 'Banana', .substring) {
		assert false, 'substring matched out of order'
	}
	if _ := picker_match('sf', 'San Francisco', .substring) {
		assert false, 'substring mode matched a subsequence'
	}
}

fn test_picker_fuzzy_match_finds_subsequences_at_word_starts() {
	found := picker_match('nf', 'New File', .fuzzy) or { panic('no match') }
	assert picker_test_ranges(found) == [[0, 1], [4, 5]]
	words := picker_match('tsb', 'Toggle Side Bar', .fuzzy) or { panic('no match') }
	assert picker_test_ranges(words) == [[0, 1], [7, 8], [12, 13]]
	camel := picker_match('gc', 'getCount', .fuzzy) or { panic('no match') }
	assert picker_test_ranges(camel) == [[0, 1], [3, 4]]
	// Spaces in the query are skipped.
	spaced := picker_match('new fi', 'New File', .fuzzy) or { panic('no match') }
	assert picker_test_ranges(spaced) == [[0, 3], [4, 6]]
	if _ := picker_match('fn', 'New File', .fuzzy) {
		assert false, 'fuzzy matched out of order'
	}
	if _ := picker_match('longer than', 'short', .fuzzy) {
		assert false, 'a query longer than the label matched'
	}
}

fn test_picker_fuzzy_match_takes_the_best_alignment_not_the_first() {
	// A greedy matcher takes a(0) and b(3); the contiguous "ab" at a word
	// start scores higher.
	found := picker_match('ab', 'a-xb ab', .fuzzy) or { panic('no match') }
	assert picker_test_ranges(found) == [[5, 7]]
	assert found.score == picker_score('a-xb ab'.runes(), [5, 6])
	assert found.score > picker_score('a-xb ab'.runes(), [0, 3])
}

fn test_picker_scores_rank_contiguous_prefix_and_exact_matches() {
	exact := picker_match('file', 'File', .fuzzy) or { panic('no match') }
	prefix := picker_match('file', 'File Explorer', .fuzzy) or { panic('no match') }
	inner := picker_match('file', 'Profile', .fuzzy) or { panic('no match') }
	scattered := picker_match('file', 'Find in large edits', .fuzzy) or { panic('no match') }
	assert exact.score > prefix.score
	assert prefix.score > inner.score
	assert inner.score > scattered.score
	// Both modes share the scale: a contiguous fuzzy match scores as the
	// same substring match does.
	sub := picker_match('file', 'Profile', .substring) or { panic('no match') }
	assert sub.score == inner.score
}

fn test_picker_match_folds_case_beyond_ascii_and_counts_runes() {
	ecole := picker_match('ÉCOLE', 'école', .substring) or { panic('no match') }
	assert picker_test_ranges(ecole) == [[0, 5]]
	moscow := picker_match('мос', 'Москва', .substring) or { panic('no match') }
	assert picker_test_ranges(moscow) == [[0, 3]]
	// Ranges are rune offsets, not byte offsets.
	jose := picker_match('sé', 'San José', .substring) or { panic('no match') }
	assert picker_test_ranges(jose) == [[6, 8]]
	if _ := picker_match('e', 'é', .substring) {
		assert false, 'accents are not folded'
	}
}

fn test_picker_option_match_uses_keywords_without_ranges() {
	option := PickerOption{
		value:    'js'
		label:    'JavaScript'
		keywords: ['node', 'ecmascript']
	}
	label_match := picker_option_match(option, 'java', .substring) or { panic('no match') }
	assert label_match.ranges.len == 1
	keyword := picker_option_match(option, 'node', .substring) or { panic('no keyword match') }
	assert keyword.ranges.len == 0
	direct := picker_match('node', 'node', .substring) or { panic('no match') }
	assert keyword.score == direct.score - picker_score_keyword
	if _ := picker_option_match(option, 'python', .substring) {
		assert false, 'unrelated query matched'
	}
	// An option without a label shows and matches its value.
	bare := picker_option('Plain value', '')
	assert bare.title() == 'Plain value'
	assert picker_option_match(bare, 'plain', .substring) != none
}

fn picker_test_options() []PickerOption {
	return [
		PickerOption{
			value: 'apple'
			label: 'Apple'
			group: 'Fruit'
		},
		PickerOption{
			value: 'carrot'
			label: 'Carrot'
			group: 'Vegetables'
		},
		PickerOption{
			value:   'banana'
			label:   'Banana'
			group:   'Fruit'
			enabled: false
		},
		PickerOption{
			value: 'beet'
			label: 'Beetroot'
			group: 'Vegetables'
		},
		PickerOption{
			value: 'pear'
			label: 'Pear'
			group: 'Fruit'
		},
	]
}

fn test_picker_filter_groups_options_and_sorts_on_request() {
	options := picker_test_options()
	all := picker_filter(options, '', .substring, true)
	// Groups in order of their first option; options keep their order.
	assert all.map(it.index) == [0, 2, 4, 1, 3]
	filtered := picker_filter(options, 'ar', .substring, false)
	assert filtered.map(options[it.index].value) == ['pear', 'carrot']
	// Sorted: "Carrot" has "ar" nearer the start than "Pear", so the
	// Vegetables group comes first.
	sorted := picker_filter(options, 'ar', .substring, true)
	assert sorted.map(options[it.index].value) == ['carrot', 'pear']
	ranked := picker_filter([picker_option('a', 'Profile'), picker_option('b', 'File')],
		'file', .fuzzy, true)
	assert ranked.map(it.index) == [1, 0]
	assert picker_filter(options, 'zzz', .fuzzy, true).len == 0
}

fn test_picker_navigation_wraps_and_skips_disabled_options() {
	options := picker_test_options()
	hits := picker_filter(options, '', .substring, false)
	// Display order: apple, banana (disabled), pear, carrot, beet.
	assert picker_step_value(options, hits, 'apple', 1) == 'pear'
	assert picker_step_value(options, hits, 'beet', 1) == 'apple'
	assert picker_step_value(options, hits, 'apple', -1) == 'beet'
	assert picker_step_value(options, hits, '', 1) == 'apple'
	assert picker_step_value(options, hits, '', -1) == 'beet'
	assert picker_step_value(options, hits, 'banana', 1) == 'apple'
	assert picker_edge_value(options, hits, true) == 'beet'
	assert picker_typeahead_value(options, hits, 'apple', `b`) == 'beet'
	assert picker_typeahead_value(options, hits, 'carrot', `c`) == 'carrot'
	assert picker_typeahead_value(options, hits, 'carrot', `z`) == ''
	none_enabled := [PickerOption{
		value:   'x'
		enabled: false
	}]
	assert picker_step_value(none_enabled, picker_filter(none_enabled, '', .substring, false),
		'', 1) == ''
}

fn test_picker_value_parts_round_trip_and_reject_forgeries() {
	value := 'a:component:b/ü'
	part := picker_value_part('option:', value)
	assert picker_value_from_part('option:', part) or { '' } == value
	for forged in ['option:', 'option:6', 'option:zz', 'option:6A', 'remove:61'] {
		if _ := picker_value_from_part('option:', forged) {
			assert false, 'accepted ${forged}'
		}
	}
}

fn test_picker_options_validation() {
	validate_picker_options(picker_test_options()) or { panic(err) }
	for bad in [
		[picker_option('', 'Empty')],
		[picker_option('a', 'A'), picker_option('a', 'Again')],
		[PickerOption{
			value: 'a'
			icon:  'not.a.symbol'
		}],
	] {
		if _ := validate_picker_options(bad) {
			assert false, 'invalid options accepted'
		}
	}
}

// ── Select ─────────────────────────────────────────────────────────

fn picker_test_select(state SelectState, selected []string) SelectConfig {
	return SelectConfig{
		id:       'fruit'
		frame:    rect(20, 40, 200, 32)
		window:   picker_test_window
		options:  picker_test_options()
		selected: selected
		state:    state
	}
}

fn test_select_box_shows_placeholder_prefix_and_icon() {
	empty := select_box(picker_test_select(SelectState{}, [])) or { panic(err) }
	assert 'Select…' in picker_test_labels(empty)
	trigger := picker_test_find(empty, select_toggle_action('fruit')) or { panic('no trigger') }
	assert trigger.button_behavior
	assert trigger.accessibility_role == 'combobox'
	assert trigger.accessibility_value == 'Select…'
	chosen := select_box(SelectConfig{
		...picker_test_select(SelectState{}, ['pear'])
		title_prefix: 'Fruit: '
		options:      [
			PickerOption{
				value: 'pear'
				label: 'Pear'
				icon:  'leaf'
			},
		].map(PickerOption{
			...it
			icon: 'star'
		})
	}) or { panic(err) }
	assert 'Fruit: Pear' in picker_test_labels(chosen)
	mut images := 0
	for child in chosen.children {
		for part in child.children {
			if part.kind == .image && part.image_path == 'symbol:star' {
				images++
			}
		}
	}
	assert images == 1
	// The chevron gives way to the clear button.
	clearable := select_box(SelectConfig{
		...picker_test_select(SelectState{}, ['pear'])
		clearable: true
	}) or { panic(err) }
	assert picker_test_find(clearable, select_clear_action('fruit')) != none
	assert picker_test_find(empty, select_clear_action('fruit')) == none
}

fn test_select_box_multiple_displays() {
	base := SelectConfig{
		...picker_test_select(SelectState{}, ['apple', 'carrot', 'beet', 'pear'])
		multiple: true
		frame:    rect(0, 0, 220, 32)
	}
	tags := select_box(base) or { panic(err) }
	shown := picker_test_labels(tags)
	assert 'Apple' in shown
	// Not every tag fits: the rest are counted on a "+N" tag.
	assert shown.any(it.starts_with('+'))
	assert picker_test_find(tags, select_remove_action('fruit', 'apple')) != none
	wide := select_box(SelectConfig{
		...base
		frame: rect(0, 0, 600, 32)
	}) or { panic(err) }
	assert !picker_test_labels(wide).any(it.starts_with('+'))
	count := select_box(SelectConfig{
		...base
		display: .count
	}) or { panic(err) }
	assert '4 selected' in picker_test_labels(count)
	list := select_box(SelectConfig{
		...base
		display: .list
	}) or { panic(err) }
	assert 'Apple, Carrot, Beetroot, Pear' in picker_test_labels(list)
	assert select_display_text(SelectConfig{
		...base
		display:      .count
		count_format: '{count} fruits'
	}) == '4 fruits'
	// Unknown values are skipped.
	assert select_titles(SelectConfig{
		...base
		selected: ['ghost', 'pear']
	}) == ['Pear']
}

fn test_select_tags_fit_the_trigger() {
	config := SelectConfig{
		...picker_test_select(SelectState{}, ['apple', 'carrot', 'beet', 'pear'])
		multiple: true
	}
	for right in [60.0, 120, 200, 400] {
		tags := select_tags(config, 8, right, 32)
		assert tags.len > 0
		last := tags[tags.len - 1]
		assert last.frame.x + last.frame.width <= right + 0.5 || tags.len == 1
		mut shown := 0
		for item in tags {
			if item.value.len > 0 {
				shown++
			} else {
				assert item.text == '+${4 - shown}'
			}
		}
	}
}

fn test_select_validation() {
	for bad in [
		SelectConfig{
			...picker_test_select(SelectState{}, [])
			id: ' '
		},
		SelectConfig{
			...picker_test_select(SelectState{}, ['apple', 'pear'])
		},
		SelectConfig{
			...picker_test_select(SelectState{}, [])
			frame: rect(0, 0, -1, 10)
		},
		SelectConfig{
			...picker_test_select(SelectState{}, [])
			icon: 'no.such.symbol'
		},
		SelectConfig{
			...picker_test_select(SelectState{}, [])
			max_height: math.nan()
		},
	] {
		if _ := select_box(bad) {
			assert false, 'invalid select accepted'
		}
		if _ := select_popup(bad) {
			assert false, 'invalid select popup accepted'
		}
	}
}

fn test_select_update_opens_chooses_and_closes() {
	closed := picker_test_select(SelectState{}, ['pear'])
	opened := select_update(closed, select_toggle_action('fruit')) or { panic('did not open') }
	assert opened.state.open
	assert opened.state.highlight == 'pear'
	assert opened.focus == ''
	assert !opened.changed
	open := picker_test_select(opened.state, ['pear'])
	chose := select_update(open, select_option_action('fruit', 'apple')) or { panic('no choice') }
	assert !chose.state.open
	assert chose.selected == ['apple']
	assert chose.changed
	same := select_update(open, select_option_action('fruit', 'pear')) or { panic('no choice') }
	assert !same.state.open
	assert !same.changed
	again := select_update(open, select_toggle_action('fruit')) or { panic('did not close') }
	assert !again.state.open
	dismissed := select_update(open, select_dismiss_action('fruit')) or { panic('no dismiss') }
	assert !dismissed.state.open
	assert dismissed.selected == ['pear']
	if _ := select_update(closed, select_dismiss_action('fruit')) {
		assert false, 'dismissed a closed select'
	}
	if _ := select_update(closed, select_option_action('fruit', 'apple')) {
		assert false, 'chose from a closed popup'
	}
	// Without a selection the first enabled option is highlighted.
	fresh := select_update(picker_test_select(SelectState{}, []), select_toggle_action('fruit')) or {
		panic('did not open')
	}
	assert fresh.state.highlight == 'apple'
}

fn test_select_update_rejects_foreign_forged_disabled_and_hidden_options() {
	open := picker_test_select(SelectState{
		open:      true
		highlight: 'apple'
	}, [])
	for event in [
		'apple',
		'other:component:toggle',
		select_option_action('fruit', 'banana'),
		select_option_action('fruit', 'ghost'),
		component_part_id('fruit', 'option:zz'),
		component_part_id('fruit', 'option:'),
		component_part_id('fruit', 'option:617'),
		component_part_id('fruit', 'nonsense'),
		select_remove_action('fruit', 'apple'),
		select_clear_action('fruit'),
	] {
		if _ := select_update(open, event) {
			assert false, 'accepted ${event}'
		}
	}
	// An option the query hides cannot be chosen.
	searching := SelectConfig{
		...open
		searchable: true
		state:      SelectState{
			open:  true
			query: 'car'
		}
	}
	if _ := select_update(searching, select_option_action('fruit', 'apple')) {
		assert false, 'chose a hidden option'
	}
	assert (select_update(searching, select_option_action('fruit', 'carrot')) or {
		panic('could not choose a shown option')
	}).selected == ['carrot']
	// A disabled select only lets go of its popup.
	disabled := SelectConfig{
		...open
		enabled: false
	}
	if _ := select_update(disabled, select_option_action('fruit', 'apple')) {
		assert false, 'disabled select chose'
	}
	if _ := select_update(SelectConfig{
		...disabled
		state: SelectState{}
	}, select_toggle_action('fruit'))
	{
		assert false, 'disabled select opened'
	}
	assert select_update(disabled, select_dismiss_action('fruit')) != none
}

fn test_select_multiple_toggles_and_stays_open() {
	config := SelectConfig{
		...picker_test_select(SelectState{
			open:      true
			highlight: 'apple'
		}, ['pear'])
		multiple: true
	}
	added := select_update(config, select_option_action('fruit', 'apple')) or { panic('no add') }
	assert added.state.open
	assert added.state.highlight == 'apple'
	assert added.selected == ['pear', 'apple']
	assert added.changed
	removed := select_update(SelectConfig{
		...config
		selected: added.selected
	}, select_option_action('fruit', 'pear')) or { panic('no remove') }
	assert removed.selected == ['apple']
	tag := select_update(SelectConfig{
		...config
		state: SelectState{}
	}, select_remove_action('fruit', 'pear')) or { panic('tag not removed') }
	assert tag.selected == []
	assert !tag.state.open
	if _ := select_update(config, select_remove_action('fruit', 'carrot')) {
		assert false, 'removed an unselected tag'
	}
	cleared := select_update(SelectConfig{
		...config
		clearable: true
	}, select_clear_action('fruit')) or { panic('not cleared') }
	assert cleared.selected.len == 0
	assert cleared.changed
}

fn test_select_hover_moves_the_highlight() {
	open := picker_test_select(SelectState{
		open:      true
		highlight: 'apple'
	}, [])
	enter := 'pointer:enter:${select_option_action('fruit', 'pear')}:10:20'
	moved := select_update(open, enter) or { panic('hover ignored') }
	assert moved.state.highlight == 'pear'
	assert moved.state.open
	for event in [
		'pointer:enter:${select_option_action('fruit', 'banana')}:10:20',
		'pointer:leave:${select_option_action('fruit', 'pear')}:10:20',
		'pointer:enter:${select_option_action('fruit', 'apple')}:10:20',
	] {
		if _ := select_update(open, event) {
			assert false, 'accepted ${event}'
		}
	}
	if _ := select_update(picker_test_select(SelectState{}, []), enter) {
		assert false, 'hover on a closed popup'
	}
}

fn test_select_keys() {
	open := picker_test_select(SelectState{
		open:      true
		highlight: 'apple'
	}, [])
	down := select_key(open, KeyEvent{ code: .down }) or { panic('down ignored') }
	assert down.state.highlight == 'pear'
	up := select_key(open, KeyEvent{ code: .up }) or { panic('up ignored') }
	assert up.state.highlight == 'beet'
	end := select_key(open, KeyEvent{ code: .end }) or { panic('end ignored') }
	assert end.state.highlight == 'beet'
	typed := select_key(open, KeyEvent{ code: .c }) or { panic('typeahead ignored') }
	assert typed.state.highlight == 'carrot'
	enter := select_key(open, KeyEvent{ code: .enter }) or { panic('enter ignored') }
	assert enter.selected == ['apple']
	assert !enter.state.open
	space := select_key(open, KeyEvent{ code: .space }) or { panic('space ignored') }
	assert space.selected == ['apple']
	escape := select_key(open, KeyEvent{ code: .escape }) or { panic('escape ignored') }
	assert !escape.state.open
	tab := select_key(open, KeyEvent{ code: .tab }) or { panic('tab ignored') }
	assert !tab.state.open
	assert tab.propagate
	if _ := select_key(open, KeyEvent{ code: .down, cmd: true }) {
		assert false, 'took a shortcut'
	}
	if _ := select_key(picker_test_select(SelectState{}, []), KeyEvent{ code: .down }) {
		assert false, 'closed select took a key'
	}
	// A search field owns Space, Home, End and letters.
	searching := SelectConfig{
		...open
		searchable: true
	}
	for code in [KeyCode.space, .home, .end, .c] {
		if _ := select_key(searching, KeyEvent{ code: code }) {
			assert false, 'searchable select took ${code}'
		}
	}
	assert select_open_key(KeyEvent{ code: .down })
	assert select_open_key(KeyEvent{ code: .space })
	assert !select_open_key(KeyEvent{ code: .down, alt: true })
	assert !select_open_key(KeyEvent{ code: .a })
}

fn test_select_search_filters_and_returns_with_enter() {
	config := SelectConfig{
		...picker_test_select(SelectState{}, [])
		searchable: true
	}
	opened := select_update(config, select_toggle_action('fruit')) or { panic('not opened') }
	assert opened.focus == select_search_id('fruit')
	searched := select_search(SelectConfig{
		...config
		state: opened.state
	}, 'ar')
	assert searched.state.query == 'ar'
	assert searched.state.highlight == 'pear'
	submitted := select_update(SelectConfig{
		...config
		state: searched.state
	}, component_part_id(component_part_id('fruit', 'search'), 'submit')) or {
		panic('enter in the search field ignored')
	}
	assert submitted.selected == ['pear']
	// Closing forgets the query.
	assert submitted.state.query == ''
	nothing := select_search(config, 'zzz')
	assert nothing.state.highlight == ''
}

fn test_select_popup_elements() {
	closed := select_popup(picker_test_select(SelectState{}, [])) or { panic(err) }
	assert closed.hidden
	assert closed.children.len == 0
	config := SelectConfig{
		...picker_test_select(SelectState{
			open:      true
			highlight: 'pear'
		}, ['apple'])
		searchable: true
		separators: true
	}
	popup := select_popup(config) or { panic(err) }
	assert !popup.hidden
	assert popup.frame == picker_test_window
	backdrop := popup.children[0]
	assert backdrop.action_id == select_dismiss_action('fruit')
	assert picker_test_find(popup, select_search_id('fruit')) != none
	row := picker_test_find(popup, select_option_action('fruit', 'pear')) or { panic('no row') }
	assert row.hoverable
	assert row.box.bg == config.theme.muted
	assert row.accessibility_role == 'option'
	chosen := picker_test_find(popup, select_option_action('fruit', 'apple')) or { panic('no row') }
	assert chosen.accessibility_value == 'selected'
	disabled := picker_test_find(popup, select_option_action('fruit', 'banana')) or {
		panic('no row')
	}
	assert !disabled.enabled
	labels := picker_test_labels(popup)
	assert 'Fruit' in labels
	assert 'Vegetables' in labels
	assert picker_test_count_role(popup, 'separator') == 1
	// The surface opens below the trigger.
	surface := picker_test_find(popup, component_part_id('fruit', 'surface')) or { panic('no surface') }
	assert surface.frame.y >= 40 + 32
	assert surface.frame.width == 200
	empty := select_popup(SelectConfig{
		...config
		state: SelectState{
			open:  true
			query: 'zzz'
		}
	}) or { panic(err) }
	assert 'No results' in picker_test_labels(empty)
	rect_ := select_highlight_rect(config) or { panic('no highlight rect') }
	assert rect_.height > 0
	assert select_highlight_rect(picker_test_select(SelectState{}, [])) == none
}

fn test_select_popup_scrolls_and_stays_in_the_window() {
	mut options := []PickerOption{}
	for i in 0 .. 40 {
		options << picker_option('v${i}', 'Option ${i}')
	}
	config := SelectConfig{
		...picker_test_select(SelectState{
			open: true
		}, [])
		frame:   rect(20, 500, 200, 32)
		options: options
	}
	popup := select_popup(config) or { panic(err) }
	surface := picker_test_find(popup, component_part_id('fruit', 'surface')) or { panic('no surface') }
	// No room below: it opens above the trigger, within the window margin.
	assert surface.frame.y + surface.frame.height <= 500
	assert surface.frame.y >= 8
	assert surface.frame.height <= 320
	assert picker_test_find(popup, select_list_id('fruit')) != none
}

// ── Combobox ───────────────────────────────────────────────────────

fn picker_test_cities() []PickerOption {
	return [
		picker_option('paris', 'Paris'),
		picker_option('san-diego', 'San Diego'),
		PickerOption{
			value:   'san-jose'
			label:   'San José'
			enabled: false
		},
		picker_option('santiago', 'Santiago'),
		picker_option('seattle', 'Seattle'),
	]
}

fn picker_test_combobox(text string, value string, state ComboboxState) ComboboxConfig {
	return ComboboxConfig{
		id:      'city'
		frame:   rect(20, 40, 240, 32)
		window:  picker_test_window
		text:    text
		value:   value
		options: picker_test_cities()
		state:   state
	}
}

fn test_combobox_input_filters_opens_and_highlights() {
	typed := combobox_input(picker_test_combobox('', '', ComboboxState{}), 'san')
	assert typed.state.open
	assert typed.state.highlight == 'san-diego'
	assert typed.change == .typed
	assert typed.text == 'san'
	hits := combobox_matches(picker_test_combobox('san', '', typed.state), 'san')
	assert hits.len == 3
	no_auto := combobox_input(ComboboxConfig{
		...picker_test_combobox('', '', ComboboxState{})
		auto_highlight: false
	}, 'san')
	assert no_auto.state.open
	assert no_auto.state.highlight == ''
	waiting := combobox_input(ComboboxConfig{
		...picker_test_combobox('', '', ComboboxState{})
		min_chars: 2
	}, 's')
	assert !waiting.state.open
	capped := combobox_matches(ComboboxConfig{
		...picker_test_combobox('', '', ComboboxState{})
		max_rows: 2
	}, 's')
	assert capped.len == 2
}

fn test_combobox_typing_away_from_the_committed_title_clears_the_value() {
	config := picker_test_combobox('Paris', 'paris', ComboboxState{})
	kept := combobox_input(config, 'Paris')
	assert kept.value == 'paris'
	changed := combobox_input(config, 'Pari')
	assert changed.value == ''
	// While the text is the committed title the list shows every option.
	assert combobox_matches(config, 'Paris').len == 5
	assert combobox_matches(picker_test_combobox('Paris', '', ComboboxState{}), 'Paris').len == 1
}

fn test_combobox_keys_open_move_pick_and_close() {
	closed := picker_test_combobox('Paris', 'paris', ComboboxState{})
	opened := combobox_key(closed, KeyEvent{ code: .down }) or { panic('down ignored') }
	assert opened.state.open
	assert opened.state.highlight == 'paris'
	from_end := combobox_key(picker_test_combobox('', '', ComboboxState{}), KeyEvent{
		code: .up
	}) or { panic('up ignored') }
	assert from_end.state.highlight == 'seattle'
	open := picker_test_combobox('san', '', ComboboxState{
		open:      true
		highlight: 'san-diego'
	})
	down := combobox_key(open, KeyEvent{ code: .down }) or { panic('down ignored') }
	// San José is disabled.
	assert down.state.highlight == 'santiago'
	wrapped := combobox_key(open, KeyEvent{ code: .up }) or { panic('up ignored') }
	assert wrapped.state.highlight == 'santiago'
	picked := combobox_key(open, KeyEvent{ code: .enter }) or { panic('enter ignored') }
	assert picked.change == .picked
	assert picked.text == 'San Diego'
	assert picked.value == 'san-diego'
	assert !picked.state.open
	assert picked.focus == combobox_field_id('city')
	escape := combobox_key(open, KeyEvent{ code: .escape }) or { panic('escape ignored') }
	assert !escape.state.open
	assert escape.text == 'san'
	tab := combobox_key(open, KeyEvent{ code: .tab }) or { panic('tab ignored') }
	assert tab.propagate
	assert !tab.state.open
	for code in [KeyCode.home, .end, .left, .right, .a, .space, .backspace] {
		if _ := combobox_key(open, KeyEvent{ code: code }) {
			assert false, 'combobox took ${code} from its field'
		}
	}
	for event in [KeyEvent{
		code: .escape
	}, KeyEvent{
		code: .enter
	}, KeyEvent{
		code: .tab
	}] {
		if _ := combobox_key(closed, event) {
			assert false, 'closed combobox took ${event.code}'
		}
	}
	if _ := combobox_key(ComboboxConfig{
		...closed
		enabled: false
	}, KeyEvent{ code: .down })
	{
		assert false, 'disabled combobox opened'
	}
}

fn test_combobox_update_picks_submits_and_clears() {
	open := picker_test_combobox('san', '', ComboboxState{
		open:      true
		highlight: 'santiago'
	})
	picked := combobox_update(open, combobox_option_action('city', 'san-diego')) or {
		panic('pick ignored')
	}
	assert picked.value == 'san-diego'
	assert picked.text == 'San Diego'
	submit := component_part_id('city', 'submit')
	entered := combobox_update(open, submit) or { panic('submit ignored') }
	assert entered.value == 'santiago'
	free := combobox_update(picker_test_combobox('Lyon', '', ComboboxState{}), submit) or {
		panic('submit ignored')
	}
	assert free.change == .submitted
	assert free.text == 'Lyon'
	toggled := combobox_update(picker_test_combobox('', '', ComboboxState{}), combobox_toggle_action('city')) or {
		panic('toggle ignored')
	}
	assert toggled.state.open
	assert toggled.focus == combobox_field_id('city')
	cleared := combobox_update(ComboboxConfig{
		...open
		clearable: true
	}, combobox_clear_action('city')) or { panic('clear ignored') }
	assert cleared.change == .cleared
	assert cleared.text == ''
	assert !cleared.state.open
	hover := combobox_update(open, 'pointer:enter:${combobox_option_action('city', 'san-diego')}:1:2') or {
		panic('hover ignored')
	}
	assert hover.state.highlight == 'san-diego'
	for event in [
		combobox_option_action('city', 'san-jose'),
		combobox_option_action('city', 'paris'),
		combobox_option_action('city', 'ghost'),
		combobox_clear_action('city'),
		'pointer:enter:${combobox_option_action('city', 'paris')}:1:2',
		'city:component:optional',
		'other:component:toggle',
	] {
		if _ := combobox_update(open, event) {
			assert false, 'accepted ${event}'
		}
	}
	dismissed := combobox_update(open, combobox_dismiss_action('city')) or { panic('no dismiss') }
	assert !dismissed.state.open
	if _ := combobox_update(picker_test_combobox('', '', ComboboxState{}), combobox_dismiss_action('city')) {
		assert false, 'dismissed a closed list'
	}
}

fn test_combobox_elements() {
	config := ComboboxConfig{
		...picker_test_combobox('san', '', ComboboxState{
			open:      true
			highlight: 'san-diego'
		})
		icon:      'magnifyingglass'
		clearable: true
	}
	el := combobox(config) or { panic(err) }
	field := picker_test_find(el, combobox_field_id('city')) or { panic('no field') }
	assert field.kind == .text_field
	assert field.text == 'san'
	assert field.submit_id == component_part_id('city', 'submit')
	assert field.emit_change
	assert field.accessibility_role == 'combobox'
	assert field.accessibility_value == 'expanded'
	assert picker_test_find(el, combobox_toggle_action('city')) != none
	assert picker_test_find(el, combobox_clear_action('city')) != none
	popup := combobox_popup(config) or { panic(err) }
	// The backdrop leaves a hole over the combobox, so a press on the field
	// reaches it instead of closing the list.
	mut backdrops := []Rect{}
	for child in popup.children {
		if child.action_id == combobox_dismiss_action('city') {
			backdrops << child.frame
		}
	}
	assert backdrops.len == 4
	anchor := config.frame
	for frame in backdrops {
		overlap := intersect_rect(frame, anchor)
		assert overlap.width == 0 || overlap.height == 0
	}
	assert picker_test_find(popup, combobox_option_action('city', 'san-diego')) != none
	loading := combobox_popup(ComboboxConfig{
		...config
		loading: true
	}) or { panic(err) }
	assert 'Loading…' in picker_test_labels(loading)
	assert picker_test_find(loading, combobox_option_action('city', 'san-diego')) == none
	empty := combobox_popup(ComboboxConfig{
		...config
		text: 'zzz'
	}) or { panic(err) }
	assert 'No matches' in picker_test_labels(empty)
	closed := combobox_popup(ComboboxConfig{
		...config
		state: ComboboxState{}
	}) or { panic(err) }
	assert closed.hidden
	assert combobox_highlight_rect(config) != none
	if _ := combobox(ComboboxConfig{
		...config
		min_chars: -1
	}) {
		assert false, 'negative min_chars accepted'
	}
}

// ── Command palette ────────────────────────────────────────────────

fn picker_test_commands() []CommandPaletteItem {
	return [
		CommandPaletteItem{
			id:       'calendar'
			label:    'Calendar'
			icon:     'calendar'
			group:    'Suggestions'
			keywords: ['schedule']
		},
		CommandPaletteItem{
			id:      'calculator'
			label:   'Calculator'
			group:   'Suggestions'
			enabled: false
		},
		CommandPaletteItem{
			id:       'new'
			label:    'New File'
			shortcut: 'cmd+n'
			group:    'Files'
		},
		CommandPaletteItem{
			id:       'save'
			label:    'Save'
			shortcut: 'cmd+s'
			group:    'Files'
		},
		CommandPaletteItem{
			id:      'settings'
			label:   'Settings'
			group:   'Settings'
			checked: true
		},
	]
}

fn picker_test_palette(state CommandPaletteState) CommandPaletteConfig {
	return CommandPaletteConfig{
		id:     'palette'
		window: picker_test_window
		state:  state
		items:  picker_test_commands()
	}
}

fn test_command_palette_shortcut_and_toggle() {
	$if macos {
		assert command_palette_shortcut(KeyEvent{ code: .k, cmd: true })
		assert !command_palette_shortcut(KeyEvent{ code: .k, ctrl: true })
		assert command_palette_shortcut_label() == '⌘K'
	} $else {
		assert command_palette_shortcut(KeyEvent{ code: .k, ctrl: true })
		assert !command_palette_shortcut(KeyEvent{ code: .k, cmd: true })
		assert command_palette_shortcut_label() == 'Ctrl+K'
	}
	assert !command_palette_shortcut(KeyEvent{ code: .k })
	assert !command_palette_shortcut(KeyEvent{ code: .k, cmd: true, ctrl: true, shift: true })
	primary := $if macos {
		KeyEvent{
			code: .k
			cmd:  true
		}
	} $else {
		KeyEvent{
			code: .k
			ctrl: true
		}
	}
	opened := command_palette_toggle_key(picker_test_palette(CommandPaletteState{}), primary) or {
		panic('did not open')
	}
	assert opened.state.open
	assert opened.state.highlight == 'calendar'
	assert opened.focus == command_palette_search_id('palette')
	closed := command_palette_toggle_key(picker_test_palette(opened.state), primary) or {
		panic('did not close')
	}
	assert !closed.state.open
	if _ := command_palette_toggle_key(CommandPaletteConfig{
		...picker_test_palette(CommandPaletteState{})
		modal: false
		frame: rect(0, 0, 300, 300)
	}, primary)
	{
		assert false, 'a panel toggled'
	}
}

fn test_command_palette_remember() {
	assert command_palette_remember([], 'a', 3) == ['a']
	assert command_palette_remember(['b', 'a', 'c'], 'a', 3) == ['a', 'b', 'c']
	assert command_palette_remember(['b', 'c', 'd'], 'a', 3) == ['a', 'b', 'c']
	assert command_palette_remember(['b', 'c', 'd'], 'a', 0) == ['a', 'b', 'c', 'd']
}

fn test_command_palette_lists_recent_commands_first_until_searching() {
	config := CommandPaletteConfig{
		...picker_test_palette(CommandPaletteState{
			open: true
		})
		recent: ['save', 'ghost', 'settings']
	}
	listed := command_palette_matches(config)
	assert listed.map(it.item.id) == ['save', 'settings', 'calendar', 'calculator', 'new']
	assert listed[0].group == 'Recent'
	assert listed[2].group == 'Suggestions'
	assert command_palette_open(config).state.highlight == 'save'
	searching := command_palette_matches(CommandPaletteConfig{
		...config
		state: CommandPaletteState{
			open:  true
			query: 'save'
		}
	})
	assert searching.map(it.item.id) == ['save']
	assert searching[0].group == 'Files'
}

fn test_command_palette_search_scores_hides_empty_groups_and_highlights() {
	config := picker_test_palette(CommandPaletteState{
		open: true
	})
	searched := command_palette_search(config, 'se')
	assert searched.state.query == 'se'
	assert searched.state.open
	results := command_palette_matches(CommandPaletteConfig{
		...config
		state: searched.state
	})
	ids := results.map(it.item.id)
	// "Settings" and "Save" have "S…e" at a word start; "Calendar" matches its
	// keyword "schedule" only and ranks last, with nothing highlighted.
	assert ids[0] == 'settings'
	assert 'save' in ids
	assert ids[ids.len - 1] == 'calendar'
	assert results[0].ranges == [PickerRange{0, 2}]
	assert results[ids.len - 1].ranges.len == 0
	assert searched.state.highlight == 'settings'
	assert !results.any(it.group == 'Suggestions' && it.item.id == 'calculator')
	// Highlight skips disabled commands.
	disabled := command_palette_search(config, 'calc')
	assert disabled.state.highlight == ''
	el := command_palette(CommandPaletteConfig{
		...config
		state: CommandPaletteState{
			open:  true
			query: 'save'
		}
	}) or { panic(err) }
	shown := picker_test_labels(el)
	assert 'Files' in shown
	assert 'Suggestions' !in shown
	assert 'Settings' !in shown
}

fn test_command_palette_keys() {
	open := picker_test_palette(CommandPaletteState{
		open:      true
		highlight: 'calendar'
	})
	down := command_palette_key(open, KeyEvent{ code: .down }) or { panic('down ignored') }
	// Calculator is disabled.
	assert down.state.highlight == 'new'
	up := command_palette_key(open, KeyEvent{ code: .up }) or { panic('up ignored') }
	assert up.state.highlight == 'settings'
	last := command_palette_key(open, KeyEvent{ code: .page_down }) or { panic('page down ignored') }
	assert last.state.highlight == 'settings'
	run := command_palette_key(open, KeyEvent{ code: .enter }) or { panic('enter ignored') }
	assert run.chosen
	assert run.item.id == 'calendar'
	assert !run.state.open
	query := CommandPaletteConfig{
		...open
		state: CommandPaletteState{
			open:      true
			query:     'sa'
			highlight: 'save'
		}
	}
	cleared := command_palette_key(query, KeyEvent{ code: .escape }) or { panic('escape ignored') }
	assert cleared.state.open
	assert cleared.state.query == ''
	assert cleared.state.highlight == 'calendar'
	closed := command_palette_key(open, KeyEvent{ code: .escape }) or { panic('escape ignored') }
	assert !closed.state.open
	for event in [KeyEvent{
		code: .tab
	}, KeyEvent{
		code: .a
	}, KeyEvent{
		code: .home
	}, KeyEvent{
		code: .down
		cmd:  true
	}] {
		if _ := command_palette_key(open, event) {
			assert false, 'palette took ${event.code}'
		}
	}
	if _ := command_palette_key(picker_test_palette(CommandPaletteState{}), KeyEvent{
		code: .down
	})
	{
		assert false, 'closed palette took a key'
	}
}

fn test_command_palette_update_runs_and_rejects() {
	open := picker_test_palette(CommandPaletteState{
		open:      true
		highlight: 'save'
	})
	run := command_palette_update(open, command_palette_item_action('palette', 'new')) or {
		panic('press ignored')
	}
	assert run.chosen
	assert run.item.label == 'New File'
	submitted := command_palette_update(open, component_part_id(component_part_id('palette',
		'search'), 'submit')) or { panic('enter in the field ignored') }
	assert submitted.item.id == 'save'
	hover := command_palette_update(open, 'pointer:enter:${command_palette_item_action('palette', 'settings')}:4:4') or { panic('hover ignored') }
	assert hover.state.highlight == 'settings'
	assert !hover.chosen
	dismissed := command_palette_update(open, command_palette_dismiss_action('palette')) or {
		panic('dismiss ignored')
	}
	assert !dismissed.state.open
	searching := CommandPaletteConfig{
		...open
		state: CommandPaletteState{
			open:  true
			query: 'save'
		}
	}
	for event in [
		command_palette_item_action('palette', 'calculator'),
		command_palette_item_action('palette', 'ghost'),
		'pointer:enter:${command_palette_item_action('palette', 'calculator')}:4:4',
		'palette:component:option:zz',
		'other:component:dismiss',
	] {
		if _ := command_palette_update(open, event) {
			assert false, 'accepted ${event}'
		}
	}
	if _ := command_palette_update(searching, command_palette_item_action('palette', 'new')) {
		assert false, 'ran a command the query hides'
	}
	if _ := command_palette_update(picker_test_palette(CommandPaletteState{}), command_palette_item_action('palette',
		'new'))
	{
		assert false, 'closed palette ran a command'
	}
}

fn test_command_palette_panel_keeps_its_state() {
	panel := CommandPaletteConfig{
		...picker_test_palette(CommandPaletteState{
			query:     'save'
			highlight: 'save'
		})
		modal: false
		frame: rect(10, 20, 360, 300)
	}
	run := command_palette_update(panel, command_palette_item_action('palette', 'save')) or {
		panic('press ignored')
	}
	assert run.chosen
	assert run.state.query == 'save'
	if _ := command_palette_update(panel, command_palette_dismiss_action('palette')) {
		assert false, 'a panel was dismissed'
	}
	empty := CommandPaletteConfig{
		...panel
		state: CommandPaletteState{}
	}
	if _ := command_palette_key(empty, KeyEvent{ code: .escape }) {
		assert false, 'escape closed a panel'
	}
	el := command_palette(panel) or { panic(err) }
	assert el.frame == rect(10, 20, 360, 300)
	assert !el.hidden
	assert picker_test_find(el, command_palette_dismiss_action('palette')) == none
	assert !command_palette_focus_trap(panel).enabled
}

fn test_command_palette_elements() {
	closed := command_palette(picker_test_palette(CommandPaletteState{})) or { panic(err) }
	assert closed.hidden
	config := picker_test_palette(CommandPaletteState{
		open:      true
		highlight: 'new'
	})
	el := command_palette(config) or { panic(err) }
	assert el.frame == picker_test_window
	assert el.children[0].action_id == command_palette_dismiss_action('palette')
	surface := el.children[1]
	assert surface.accessibility_role == 'dialog'
	assert surface.frame.width == 560
	assert surface.frame.x == 120
	assert surface.frame.y == 72
	assert picker_test_find(el, command_palette_search_id('palette')) != none
	row := picker_test_find(el, command_palette_item_action('palette', 'new')) or { panic('no row') }
	assert row.box.bg == config.theme.muted
	shown := picker_test_labels(el)
	assert menu_shortcut_label('cmd+n') in shown
	assert '5 results' in shown
	// A checked command shows a check mark.
	settings := picker_test_find(el, command_palette_item_action('palette', 'settings')) or {
		panic('no row')
	}
	assert settings.children.any(it.image_path == 'symbol:checkmark')
	no_backdrop := command_palette(CommandPaletteConfig{
		...config
		backdrop: .none
	}) or { panic(err) }
	assert no_backdrop.frame.width == 560
	assert no_backdrop.clickable
	empty := command_palette(CommandPaletteConfig{
		...config
		state: CommandPaletteState{
			open:  true
			query: 'zzzz'
		}
	}) or { panic(err) }
	assert 'No results found.' in picker_test_labels(empty)
	loading := command_palette(CommandPaletteConfig{
		...config
		loading: true
		state:   CommandPaletteState{
			open:  true
			query: 'zzzz'
		}
	}) or { panic(err) }
	assert 'Searching…' in picker_test_labels(loading)
	trap := command_palette_focus_trap(config)
	assert trap.enabled
	assert trap.first() or { '' } == command_palette_search_id('palette')
	assert command_palette_highlight_rect(config) != none
	// A small window keeps the palette inside it.
	small := command_palette(CommandPaletteConfig{
		...config
		window: rect(0, 0, 300, 200)
	}) or { panic(err) }
	assert small.children[1].frame.width == 268
	assert small.children[1].frame.y + small.children[1].frame.height <= 200
}

fn test_command_palette_validation() {
	for bad in [
		CommandPaletteConfig{
			...picker_test_palette(CommandPaletteState{})
			id: ''
		},
		CommandPaletteConfig{
			...picker_test_palette(CommandPaletteState{})
			items: [CommandPaletteItem{
				id: 'a'
			}, CommandPaletteItem{
				id: 'a'
			}]
		},
		CommandPaletteConfig{
			...picker_test_palette(CommandPaletteState{})
			items: [CommandPaletteItem{
				label: 'No id'
			}]
		},
		CommandPaletteConfig{
			...picker_test_palette(CommandPaletteState{})
			top: -5
		},
		CommandPaletteConfig{
			...picker_test_palette(CommandPaletteState{})
			width: math.inf(1)
		},
	] {
		if _ := command_palette(bad) {
			assert false, 'invalid palette accepted'
		}
	}
}
