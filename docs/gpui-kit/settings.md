# Settings

A port of GPUI Kit's
[Settings](https://github.com/longbridge/gpui-kit/blob/main/website/component/settings.md)
(`Settings`, `SettingPage`, `SettingGroup`, `SettingItem`, `SettingField`): a
navigation column with a search field and the pages, and the selected page's
header and groups of settings. The implementation is in
`ui/component_settings.v` (the model, search, selection rules and decoders),
`ui/component_settings_layout.v` (pure geometry) and
`ui/component_settings_view.v` (rendering). `examples/gpui_settings/main.v` is a
preferences window with General, Appearance, Editor, Notifications and Advanced
pages, every kind of control, search, resettable values and a light/dark switch
that is itself a setting. `ui/component_settings_test.v` covers the logic.

## Conventions

- **Controlled model.** The application owns the values, a
  `map[string]SettingValue` keyed by each item's `key`, and a `SettingsState`
  (selected page and group, search text, expanded pages, the open dropdown
  menu, a number being typed). It builds a `SettingsConfig` from both, passes
  every action to `settings_update` and every key to `settings_key`, and
  stores what they return. Build the config in one function and use it for the
  build and the decoders.
- **Values are a sum type.** `SettingValue = bool | f64 | string`: switches and
  checkboxes hold a bool, number inputs and sliders an f64, text inputs a
  string, and dropdowns the string value of the chosen option. Custom items may
  use any of them. `setting_bool`, `setting_number` and `setting_string` read a
  value with a fallback; `settings_defaults(pages)` collects every item's
  `default_value` as the values to start from.
- **Changes are typed.** A decoded `SettingsStep` carries the next `state`, the
  `changes` to store (`SettingChange{key, value, reset}`; `step.apply(mut
  values)` stores them), the `action` key of a button item that was pressed,
  and what to do after the rebuild: `scroll_to_offset(scroll_id, scroll_to)`
  when `scroll` is set, `focus(focus)`, and `set_text(sync_id, sync_text)` when
  a field's text was cleaned up.
- **Live values through readers.** ui/ cannot read a field, so the decoder
  takes the backend's readers and calls them only for the field or slider the
  action came from: `ui2.SettingsInput{ text: ui2.text, number:
  ui2.slider_value }`. (Calling `ui2.text` on an arbitrary action id is not
  safe on AppKit: most ids name views without text.)
- **Rejection.** The decoders reject actions that belong to something else,
  are malformed or forged, name a page the search hides, a group row that is
  not shown, an item the selected page does not show, a disabled item, or
  change nothing.
- **Keys.** Components cannot capture keys: call `settings_key(config,
  ui2.focused_id(), event)` from `on_key_event` and `consume_key()` when it
  returns a step. It drives the open dropdown menu (arrows, Home/End, Return,
  Escape), steps a focused number field with Up and Down, and clears the search
  with Escape. Focusing the search (Cmd+F, say) is the application's:
  `ui2.focus(ui2.settings_search_field_id(id))`.
- `size` is a `ComponentSize`, colors come from `ComponentTheme`.

## Usage

```v
fn pages() []ui2.SettingPage {
	return [
		ui2.SettingPage{
			id:           'general'
			title:        'General'
			icon:         'gearshape'
			default_open: true
			groups:       [
				ui2.SettingGroup{
					title: 'Appearance'
					items: [
						ui2.SettingItem{
							key:           'dark'
							title:         'Dark mode'
							description:   'Switch between light and dark themes.'
							default_value: false
						},
					]
				},
				ui2.SettingGroup{
					title:  'Font'
					footer: 'Applies to new windows.'
					items:  [
						ui2.SettingItem{
							key:           'font'
							title:         'Font family'
							kind:          .dropdown
							options:       [ui2.SettingOption{ value: 'Arial' },
								ui2.SettingOption{ value: 'Helvetica' }]
							default_value: 'Arial'
						},
						ui2.SettingItem{
							key:           'size'
							title:         'Font size'
							kind:          .number
							min:           8
							max:           72
							default_value: 14.0
						},
					]
				},
			]
		},
	]
}

fn config(m &Model) ui2.SettingsConfig {
	return ui2.SettingsConfig{
		id:            'prefs'
		frame:         ui2.rect(0, 0, ui2.bounds().width, ui2.bounds().height)
		pages:         pages()
		values:        m.values
		state:         m.state
		group_variant: .outline
		theme:         ui2.component_theme(ui2.setting_bool(m.values, 'dark'))
	}
}

// main: m.values = ui2.settings_defaults(pages())
//       m.state = ui2.settings_initial_state(pages())
// build: ui2.settings(config(m))!

fn on_event(event string) {
	live := ui2.SettingsInput{
		text:   ui2.text
		number: ui2.slider_value
	}
	step := ui2.settings_update(config(m), event, live) or { return }
	m.state = step.state
	step.apply(mut m.values)
	ui2.refresh()
	if step.scroll {
		ui2.scroll_to_offset(step.scroll_id, step.scroll_to)
	}
	if step.focus.len > 0 {
		ui2.focus(step.focus)
	}
	if step.sync_id.len > 0 && ui2.text(step.sync_id) != step.sync_text {
		ui2.set_text(step.sync_id, step.sync_text)
	}
}
```

## API

### Builders and decoders

| Function | Purpose |
| --- | --- |
| `settings(config) !Element` | The whole component, filling `config.frame`. |
| `settings_update(config, action, input) ?SettingsStep` | Decodes an action (see Conventions). |
| `settings_key(config, focused, event) ?SettingsStep` | Decodes a key. |
| `settings_initial_state(pages) SettingsState` | The first page selected, `default_open` pages expanded. |
| `settings_defaults(pages) map[string]SettingValue` | Every item's default value. |
| `step.apply(mut values)` | Stores a step's changes. |
| `settings_group_offset(config, group) ?f64` | Where to scroll the selected page to show a group. |

### Pure helpers

| Function | Purpose |
| --- | --- |
| `settings_item_matches(item, query) bool` | The search: every word of the query, ignoring case, occurs in the title, the description (as plain text) or a keyword. An empty query matches everything; an item without title or description is found by its keywords alone. |
| `settings_group_matches(group, query)`, `settings_visible_groups(pages, query)`, `settings_match_count(page, query)` | A group shows when one of its items does (its title and footer do not count, as upstream); the indices of the groups each page shows; the matches on a page. |
| `settings_resolve_state(pages, state) SettingsState` | Upstream's selection rules while searching (below). The builder and the decoders apply it; the decoders store its result. |
| `settings_plain_text(markdown) string` | The plain text of a description written in simple Markdown. |
| `settings_item_value(values, item)`, `settings_item_dirty(values, item)` | The value an item shows (stored, else default, else zero); whether it differs from its default. |
| `setting_value_equal(a, b)`, `setting_bool`, `setting_number`, `setting_string` | Comparing (numbers to within rounding) and reading values. |

### Ids and actions

`settings_search_field_id(id)` (focus, text), `settings_nav_scroll_id(id)`,
`settings_scroll_id(id, page)` (each page has its own scroll, so a page opens
at its top), `settings_field_id(id, key)` (an item's switch, checkbox, text
field, slider or button; also its action), `settings_number_id(id, key)` (a
number item's `number_input`), `settings_menu_id(id, key)` (a dropdown's menu),
and the actions `settings_page_action`, `settings_expand_action`,
`settings_group_action`, `settings_reset_action` and
`settings_reset_page_action`.

### Types

`SettingsConfig`: `id`, `frame`, `pages`, `values`, `state`, `group_variant`
(`.normal` by default, as upstream), `nav_width` (240), `search_placeholder`,
`empty_title`, `empty_description`, `reset_all_text`, `stacked_width` (480),
`accessibility_label`, `size`, `theme`.

`SettingPage`: `id` (defaults to the title), `title`, `icon` (a symbol name),
`description`, `groups`, `default_open`, `resettable` (true by default, as
upstream), `title_suffix` (a `SettingContentFn`) and `title_suffix_width`.

`SettingGroup`: `title`, `description`, `items`, `variant ?SettingsGroupVariant`
(overrides the settings' variant), `footer`.

`SettingItem`: `key`, `title`, `description`, `keywords`, `kind`
(`SettingFieldKind`), `layout` (`.horizontal` or `.vertical`), `disabled`,
`default_value ?SettingValue`, and per kind: `options` (dropdown;
`SettingOption{value, label}`), `min`, `max`, `step`, `precision` (number and
slider), `unit` (slider), `placeholder` and `secure` (input), `button_text`
and `button_variant` (button), `content` and `content_height` (custom), and
`field_width` (the control's width in a horizontal row).

`SettingContentFn = fn (SettingContentOptions) []Element` builds custom content
in a frame `options.width` by `options.height`, with `options.disabled`,
`layout`, `size` and `theme`.

### Field kinds

| Kind | Control | Value |
| --- | --- | --- |
| `.switch` | A switch drawn by ui2 in the theme's colors | bool |
| `.checkbox` | A checkbox drawn by ui2 | bool |
| `.dropdown` | `dropdown_button` (outline) opening a `dropdown_menu` with the current option checked | string |
| `.input` | A native text field | string |
| `.number` | `number_input` from the input components | f64 |
| `.slider` | The native slider and its value (`unit` appended) | f64 |
| `.button` | `styled_button` in `button_variant`; `SettingsStep.action` names the item | none |
| `.custom` | The application's `content`: beside the title, or the whole row when the item has neither title nor description | any, or none |

A number field keeps what is typed as a draft in the state: a value is stored
while the text parses and lies in range, out-of-range text stays (drawn
invalid) until Return clamps it, and letters are dropped. The dropdown menu is
drawn inside the page's scroll, over the items below it, so it scrolls with
its trigger and needs no window coordinates.

## Behaviour

**Search.** The navigation lists only the pages with matching settings, each
with the number of matches, and a page shows only its matching items, in the
groups that have some. Search keeps the current page selected while it
matches; otherwise the first matching page is selected. A selected group stays
selected while it matches on that page; otherwise the selection falls back to
the page. Clearing the search keeps the current page. When nothing matches, no
page is shown (an empty state says so) and the selection is kept for when
results return. A group's footer follows the group's visibility.

**Navigation.** A page with more than one shown group lists its titled groups
below it once expanded: `default_open` pages start expanded, selecting a page
expands it, and its chevron expands or collapses it. Selecting a group scrolls
the page to it.

**Reset.** An enabled item with a `default_value`, on a resettable page, shows
a reset button beside its control while its value differs from the default.
The page header shows Reset all while a shown item differs; it restores the
items the search shows and leaves hidden and disabled ones alone, as upstream.
Custom items take part through `key` and `default_value` like any other.

**Layout.** Items place their control beside the title, or below it with
`layout: .vertical`. While the page is at most `stacked_width` wide every item
stacks, and wide controls (dropdown, input, number, slider, custom) fill the
row, as upstream's container query does below 480 pixels. Group variants:
`.normal` puts items directly on the page, `.outline` in a bordered card and
`.fill` in a filled card, with hairlines between items in cards.

**Accessibility.** The root is a `group` labelled `accessibility_label`, the
navigation a `navigation`, page and group rows buttons whose value is
`current` when selected; switches (`switch`, on/off), checkboxes (`checkbox`,
checked/unchecked), dropdown triggers (`combobox`, the chosen label), sliders
(the value with its unit) and number fields carry their item's title. The
empty search result is a `status`.

## GPUI Kit features

| GPUI Kit | ui2 |
| --- | --- |
| `Settings`, `SettingPage`, `SettingGroup`, `SettingItem` | `SettingsConfig`, `SettingPage`, `SettingGroup`, `SettingItem` |
| Search by title, description and keywords | Implemented; every word of the query must match somewhere (upstream matches the whole query as one substring, which is the one-word case) |
| Selection while searching | Implemented (`settings_resolve_state`), with upstream's scenarios as tests |
| Pages: title, icon, description, default open, resettable, title suffix | Implemented |
| Page groups listed under the page in the sidebar | Implemented, with expand and collapse |
| `default_selected_index` | The application's initial `state.page` / `state.group` |
| Groups: title, description, single item, untitled, footer outside the surface | Implemented; the footer is text (upstream takes an element, documenting that text is enough) |
| `with_group_variant`, `SettingGroup::variant` (Normal, Outline, Fill) | `group_variant`, `variant` |
| Items: description, keywords, disabled, horizontal and vertical layout | Implemented |
| Markdown description | Shown as plain text with emphasis, code spans and links reduced to their text (`settings_plain_text`); ui2 has no Markdown renderer yet. Bold, italic and links are not styled. |
| `SettingField::switch`, `checkbox`, `input`, `dropdown`, `number_input` | `.switch`, `.checkbox`, `.input`, `.dropdown`, `.number` |
| `scrollable_dropdown` | Every dropdown menu scrolls once it is taller than the page |
| `NumberFieldOptions { min, max, step }` | `min`, `max`, `step`, plus `precision` |
| `default_value` and reset | `default_value`; per-item reset buttons as well as the page's Reset all (upstream only has Reset all) |
| `SettingField::render`, `SettingField::element`, `SettingItem::render` | `.custom` with `content`, beside the title or spanning the row |
| `on_reset` for custom items | Custom items reset through `key` and `default_value`; state outside the values map is the application's |
| `RenderOptions` (size, layout, disabled, indices) | `SettingContentOptions` (key, width, height, disabled, layout, size, theme) |
| Narrow layout (container query below 480 px) | `stacked_width` |
| Sizes | `size`: small, medium, large (no extra small) |
| Slider and button fields | Added as `.slider` and `.button`; upstream builds them with `render` |
| Resizable sidebar (`sidebar_width`, `sidebar_size_range`) | `nav_width` only. Omitted: dragging the divider would need the resizable component, which is ported separately. |
| `sidebar_style`, `header_style`, `Styled` refinements | Omitted: ui2 has no style refinement; colors come from the theme. |
| Scroll bounce and virtualised page list | Omitted: the backend's own scroll is used, and settings pages are short. |
| Highlighting the matched text | Omitted: labels cannot style part of their text. The navigation shows how many settings match on each page instead. |
| Localised strings (`t!`) | Plain config fields: `search_placeholder`, `empty_title`, `empty_description`, `reset_all_text`. |

## Platform notes

- The slider is the platform's own control (AppKit's NSSlider, the custom
  renderer's themed slider), so it keeps the system look on AppKit.
- The custom renderer's fonts have no CJK glyphs, so option labels in Chinese,
  Japanese or Korean draw as boxes there.

## Verification

```sh
v test ui/component_settings_test.v
v -d ui2_custom_rendering test ui/component_settings_test.v
v run examples/gpui_settings/main.v
v -d ui2_custom_rendering run examples/gpui_settings/main.v
```
