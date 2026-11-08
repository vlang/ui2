# Tabs and tree: tab bar, tabbed panel, tree view

An audit of ui2's existing `tabbed_panel` and `tree_view` against GPUI Kit's
[Tabs](https://github.com/longbridge/gpui-kit/blob/main/website/component/tabs.md)
and [Tree](https://github.com/longbridge/gpui-kit/blob/main/website/component/tree.md),
and the features added to close the gaps.

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `TabBar`, `Tab`, `TabVariant` | `tab_bar(TabBarConfig)`, `TabBarItem`, `TabVariant` | `ui/component_navigation2_tabs.v`, `ui/component_navigation2_tabs_draw.v` |
| (a tab bar over its content) | `tabbed_panel` with `variant` or `theme` | `ui/tabbed_panel.v`, `ui/component_navigation2_panel.v` |
| `Tree`, `TreeState`, `TreeItem`, `TreeEntry` | `tree_view` with `theme`, `TreeViewNode`, `TreeViewState` | `ui/tree_view.v`, `ui/component_navigation2_tree.v`, `ui/component_navigation2_tree_draw.v` |

`tabbed_panel` and `tree_view` keep their API and their look: everything they
did before is unchanged when the new fields are left alone, and the VML
`TabbedPanel` and `TreeView` tags build them as before. Setting `variant` (tabs)
or `theme` (tabs and tree) switches them to the GPUI Kit look and behavior
described here.

Tests are in `ui/component_navigation2_test.v`. `examples/gpui_navigation2/main.v`
is the gallery; its Tabs page shows every variant and size, icons, badges,
prefix and suffix elements, closable and reorderable tabs, a bar that overflows
into a scroll and a tab menu, and two themed tabbed panels. Its Tree page shows
a file tree (multiple selection, a lazily loaded folder, dragging, filtering, a
context menu), a tree of check boxes, a virtualized tree of 10,100 nodes with
its own row content, and an application-styled `tree_view` for comparison.
`GPUI_NAVIGATION2_PAGE=tree` opens the Tree page and `GPUI_NAVIGATION2_DARK=1`
the dark theme.

```sh
v run examples/gpui_navigation2/main.v
v -d ui2_custom_rendering run examples/gpui_navigation2/main.v
```

## Conventions

- **Controlled state.** The components own nothing. The application keeps the
  selection, hover, menu, drag and scroll offset, passes them in and rebuilds.
  `tab_bar_update`, `tabbed_panel_update` and `tree_view_update` decode what
  `on_event` receives; `tab_bar_key`, `tabbed_panel_key` and `tree_view_key`
  decode keys from `on_key_event` (consume the key when a step comes back).
  They return none for events that belong to something else, are malformed or
  forged, name a disabled or absent tab or node, or would change nothing.
- **Names.** Tabs and nodes are named by `id`, hex-encoded into actions, so ids
  may contain any character and the selection survives tabs being added,
  closed or moved.
- **Scroll positions** come from `on_scroll`: store
  `scroll_horizontal_offset(tab_bar_scroll_id(id))` (`scroll_offset` for a
  vertical bar) or `scroll_offset(tree_view_scroll_id(id))` and pass it as
  `offset`. When a step says `reveal`, scroll to `tab_bar_reveal_offset` or
  `tree_view_reveal_offset` after `refresh()`.
- **Size and theme.** `size` is a `ComponentSize` and colors come from
  `ComponentTheme`, as everywhere in the catalog.
- **Icons** are symbol names (`symbol_known`); an unknown one is an error.

## Tab bar

```v
bar := ui2.TabBarConfig{
	id:      'mail'
	frame:   ui2.rect(20, 20, 600, ui2.tab_bar_height(.underline, .medium))
	items:   [
		ui2.TabBarItem{ id: 'inbox', label: 'Inbox', icon: 'tray', badge: '12' },
		ui2.tab_bar_item('sent', 'Sent'),
		ui2.TabBarItem{ id: 'drafts', label: 'Drafts', closable: true },
		ui2.TabBarItem{ id: 'spam', label: 'Spam', enabled: false },
	]
	state:   app.mail_tabs // ui2.TabBarState{ selected: 'inbox' }
	variant: .underline
	theme:   ui2.component_theme(app.dark)
}
ui2.tab_bar(bar)!

// on_event:
if step := ui2.tab_bar_update(bar, event) {
	app.mail_tabs = step.state
	if step.closed.len > 0 {
		next := ui2.tab_bar_after_close(bar.items, step.state.selected, step.closed)
		// remove the tab, select `next`
	}
	if step.moved {
		app.tabs = ui2.tab_bar_reorder(app.tabs, step.from, step.to)
	}
}
```

`TabBarItem{id, label, icon, badge, badge_tone, closable, enabled = true,
action_id, tooltip, accessibility_label}` is one tab. An item with an icon and
no label is an icon-only tab, whose label (or `accessibility_label`) becomes its
tooltip. `action_id` replaces the tab's own action, for applications that route
tabs to actions of their own; `tab_bar_update` then does not see that tab.

`TabBarConfig`:

| Field | Meaning |
| --- | --- |
| `variant` | `.tab` (default), `.outline`, `.pill`, `.segmented`, `.underline`, `.folder` |
| `position` | `.top` (default), `.bottom`, `.left`, `.right`: the side of its content the bar is on. Left and right bars stack their tabs; the tab and folder variants join the selected tab to the content on that side, and the underline runs along it. |
| `align` | `.start`, `.center`, `.end` for tabs that do not fill the bar |
| `fill` | Share the bar's length among the tabs, as a segmented control spanning its container does |
| `max_tab_width`, `min_tab_width` | Bounds on each tab; a longer label ends in an ellipsis and its tab gets the whole label as a tooltip. Icon-only tabs keep their size. |
| `prefix`, `prefix_size`, `suffix`, `suffix_size` | Application elements at either end (navigation buttons, an add button, a ⋯ menu), laid out in a slot `*_size` long across the bar's thickness |
| `menu` | A button after the tabs that lists all of them in a dropdown menu |
| `offset` | The strip's scroll position when the tabs overflow |
| `reorderable` | Tabs can be dragged to a new place |
| `animate` | Slide the segmented, pill and underline indicator between tabs (default on) |
| `state` | `TabBarState{selected, hovered, menu, drag}` |

Size a horizontal bar with `tab_bar_height(variant, size)`: 24/32/40 points
for small, medium and large, 4 more for underline, and the folder variant's
top space (4 or 8) more for folder. A vertical bar takes any width; its tabs
are 24/32/40 tall.

`tab_bar_layout(config)` returns the geometry (prefix, strip, tabs, menu
button, suffix, whether it scrolls); `tab_bar_drop_index(layout, from, delta)`
is where a dragged tab lands.

**Selection and hover.** A press on an enabled tab that is not selected
selects it; the pointer entering and leaving a tab sets `hovered`, which the
outline, pill and folder variants show as a fill and the others as darker text.

**Keys.** `tab_bar_key` moves the selection with the arrows along the bar (Left
and Right, or Up and Down for a vertical bar), Home and End, and Ctrl+Tab and
Ctrl+Shift+Tab; disabled tabs are skipped and the ends wrap around. While the
tab menu is open the keys move through the menu.

**Closing.** A closable tab draws a close button; `tab_bar_update` reports its
press as `closed` and leaves removing the tab to the application.
`tab_bar_after_close(items, selected, closed)` is the tab to select next: the
same one, or for the closed selected tab the next enabled tab, else the
previous one, as a browser does.

**Overflow.** Tabs longer than the bar scroll in `tab_bar_scroll_id(id)`: a
trackpad, a tilt wheel or Shift with a wheel scrolls a horizontal strip. When a step says `reveal`,
`tab_bar_reveal_offset(config, tab)` is the offset that shows the tab and
24–40 points of the tabs on either side, moving as little as it can (the tab
itself wins on a short bar), as GPUI Kit's `track_scroll` reveal does. Pass it
to `scroll_to_horizontal_offset`. With `menu: true` the bar ends in a button
that toggles `tab_bar_menu_id(id)`; draw the menu last with
`tab_bar_menu(config, tab_bar_menu_anchor(config), ui2.bounds())`
(offset the anchor by where the bar's parent is in the window). The menu lists
every tab with its full label, checks the selected one and disables disabled
ones; `tab_bar_update` and `tab_bar_key` drive it.

**Dragging.** With `reorderable`, tabs report pointer presses. Past 10 points of
movement a press becomes a drag: the tab follows the pointer along the bar,
floating above the others, which move aside to show where it will land.
Released, `tab_bar_update` reports `moved` with `from` and `to` indices;
`tab_bar_reorder(items, from, to)` moves an item of any array that way. A
press released where it started is a click.

**The indicator** of the segmented (a raised surface), pill (a primary
capsule) and underline (a primary line) variants is one element that slides
from the tab it left to the one selected, using a widget animation keyed by
the tab it shows. It snaps when only the layout changed (a resize), and
`animate: false` turns the slide off.

### Implemented, already present, omitted

ui2 had `tabbed_panel` (application-styled headers on any side of the
content, alignment, disabled tabs, controlled selection) but no tab bar on its
own. Compared with GPUI Kit's TabBar and Tab:

| GPUI Kit | ui2 |
| --- | --- |
| `TabBar::new`, `child`, `children`, `selected_index`, `on_click` | `tab_bar` with `items` and `state.selected`; `tab_bar_update` reports the press (tabs are named by id rather than index) |
| Variants `Tab`, `Outline`, `Pill`, `Segmented`, `Underline`, `Folder` | Implemented, with each variant's normal, hovered, selected and disabled colors |
| Sizes small, medium, large | Implemented (`size`) |
| Size xsmall | Omitted: `ComponentSize` has no extra-small step anywhere in the catalog |
| Tabs with icons; icon-only tabs | Implemented (`icon`) |
| `TabBar::prefix`, `suffix` | Implemented (`prefix`, `suffix` with their sizes) |
| `Tab::prefix`, `suffix` (any element) | Implemented for the documented uses: a leading icon, a trailing badge (the "custom tab content" example) and a close button. Arbitrary per-tab elements are omitted: a tab is one button, and a second interactive element inside it needs the bar to place it. |
| Disabled tabs | Implemented; they are skipped by the keyboard and the menu |
| Dynamic tabs, tabs with close buttons | Implemented: `closable`, `closed`, `tab_bar_after_close` |
| `menu(true)`: dropdown of all tabs | Implemented (`menu`, `tab_bar_menu`) |
| `max_width` with ellipsis | Implemented (`max_tab_width`), plus `min_tab_width` |
| Scrollable tabs, `track_scroll`, reveal with a peek of the neighbors | Implemented (`offset`, `tab_bar_reveal_offset`); the reveal jumps where GPUI Kit springs, since a component cannot drive a scroll |
| Sliding indicator (spring) | Implemented as an eased 0.22 s slide |
| Pill text fading in with the indicator | Omitted: the label switches color at once |
| `last_empty_space` | Omitted: the suffix takes elements after the tabs |
| `Tab::on_click` per tab | `action_id` per tab |
| `Tab::selected`, `with_variant`, `Sizable` per tab | Omitted: the bar decides selection, variant and size for all its tabs, as GPUI Kit's bar does |
| Reordering (mentioned in the introduction) | Implemented by dragging (`reorderable`) |
| Keyboard navigation (a TODO upstream) | Implemented (`tab_bar_key`) |
| Vertical tabs (not upstream) | Implemented (`position: .left`, `.right`) |

## Tabbed panel

```v
ui2.tabbed_panel(
	id:           'settings'
	frame:        ui2.rect(20, 80, 520, 320)
	current:      app.tab
	tab_position: .left_top
	variant:      .pill
	theme:        ui2.component_theme(app.dark)
	bar_size:     150
	hovered:      app.tab_hovered
	tabs:         [
		ui2.TabbedPanelTab{ title: 'General', icon: 'gearshape', content: general },
		ui2.TabbedPanelTab{ title: 'Privacy', icon: 'lock', content: privacy },
	]
)!

// on_event and on_key_event:
if step := ui2.tabbed_panel_update(config, event) { app.tab = step.current; app.tab_hovered = step.hovered }
if step := ui2.tabbed_panel_key(config, key) { app.tab = step.current }
```

New `TabbedPanelConfig` fields: `variant ?TabVariant`, `theme ?ComponentTheme`
(either one turns the themed look on), `size`, `fill`, `bar_size` (the width of
a bar beside the content; zero is 180), `hovered` (an index, -1 for none),
`offset` and `accessibility_label`. New `TabbedPanelTab` fields: `icon`, `badge`
and `closable`. The themed panel draws a `tab_bar` (`tabbed_panel_bar(config)`
returns its configuration, with tabs named `'0'`, `'1'`, …) along the side
`tab_position` names and aligned as it says, puts the current tab's content
beside it on the theme's background, and needs an `id`. `box`, `header_box`,
the header text styles, `tab_width` and `tab_height` only apply to the
application-styled look.

A tab's own `action_id` is still what it emits in either look, so VML
`on_select` handlers keep working; `tabbed_panel_update` decodes those actions
too (and their hover reports in the themed look), and reports closed tabs by
index. `tabbed_panel_key` moves the selection in either look, and
`tabbed_panel_geometry` returns the themed tab frames when the panel is themed.

## Tree view

```v
config := ui2.TreeViewConfig{
	id:          'files'
	frame:       ui2.rect(20, 80, 320, 480)
	nodes:       app.nodes
	theme:       ui2.component_theme(app.dark)
	selection:   .multiple
	state:       app.tree_state
	offset:      app.tree_offset
	reorderable: true
}
ui2.tree_view(config)!

// on_event:
if step := ui2.tree_view_update(config, event, ui2.list_held_modifiers()) {
	app.tree_state = step.state
	app.nodes = ui2.tree_view_apply(app.nodes, step)
	if step.load.len > 0 {
		// fetch, then: app.nodes = ui2.tree_view_with_children(app.nodes, step.load, children)
	}
	if step.moved {
		app.nodes = ui2.tree_view_move_nodes(app.nodes, step.move) or { app.nodes }
	}
}
// on_key_event: the same with ui2.tree_view_key(config, key)
```

The selection, expansion and check marks stay on the nodes, as they were in
`tree_view` (and as GPUI Kit's `TreeItem` keeps `expanded` and `disabled`);
`tree_view_apply(nodes, step)` applies a step to them. The interaction state
that has no node to live on is `TreeViewState{active, anchor, hovered, drag}`.

New `TreeViewNode` fields: `icon`, `expanded_icon` (a folder's icon while open),
`trailing` (muted text at the end of the row), `has_children` (a folder whose
children are not loaded yet), `loading`, `checked`, `menu` (the row's native
right-click menu) and `accessibility_label`.

New `TreeViewConfig` fields:

| Field | Meaning |
| --- | --- |
| `theme` | Turns the themed look on. Rows are then sized by `size` (24/28/34 points), and `row_height`, `spacing`, `indent`, `disclosure_width`, the boxes and text styles go unused. |
| `selection` | `ListSelectionMode`: `.none`, `.single` (default), `.multiple` |
| `checkable` | Draw check boxes |
| `state` | `TreeViewState` |
| `offset`, `virtualize`, `overscan` | Scroll position, and building only the rows near it |
| `reorderable` | Rows can be dragged before, after and into other rows |
| `expand_on_click` | A plain click on a folder also opens or closes it (default on, as GPUI Kit's tree does) |
| `guides`, `bordered` | Indent guides and the outline (default on) |
| `empty_title`, `accessibility_label` | |
| `row_content` | `fn (node, frame, selected) []Element` that draws a row's content in place of its icon, text and trailing text, as GPUI Kit's `render_item` closure does |

`tree_view_rows` and `tree_view_content_height` return the themed geometry for
a themed tree.

**Selection.** A press on a row selects it with the modifiers the application
passes (`list_held_modifiers()` for the keys held now): Cmd/Ctrl toggles a row
in a multiple selection, Shift selects the range from the anchor through the
visible, enabled rows. A plain press also `confirms` the node. A row's own
`action_id` (and a folder's `toggle_action_id`) still count as presses on it.

**Folders.** The chevron opens and closes a folder (`expand`, `collapse`).
Closing the folder the keyboard cursor is in moves the cursor onto it. Opening
a folder with `has_children` and no children reports `load`; `tree_view_apply`
marks it `loading`, which shows a spinner row under it, and
`tree_view_with_children(nodes, id, children)` fills it in (a folder that turns
out empty loses its chevron). `tree_view_reveal(nodes, id)` opens the folders
above a node, as GPUI Kit's `reveal_item` and `set_selected_item` do, and
`tree_view_filter(nodes, query)` keeps the matching nodes and the folders above
them, opened, as its search example does.

**Check boxes.** A leaf (or an unloaded folder) shows its own `checked`; a
folder with children shows whether all, some or none of its descendants are
checked (`tree_view_check_state(node)`, a `TableCheckState`). Pressing a check
box checks the node and every enabled node in it, or unchecks them when every
enabled leaf in it is already checked.

**Keys.** `tree_view_key` follows GPUI Kit's tree: Up and Down move through the
visible enabled rows and wrap around, Left closes an open folder or goes to the
folder above, Right opens a closed folder or goes to its first child, Enter
opens or closes a folder and confirms a leaf. Also: Home, End, Page Up and Page
Down; Shift with the arrows extends a multiple selection; Cmd/Ctrl+A selects
every visible row; Space checks or unchecks in a checkable tree and otherwise
toggles the row in the selection; Escape clears the cursor (`cancelled`). The
selection follows the cursor.

**Dragging.** With `reorderable`, rows report pointer presses; past 10 points a
press becomes a drag. A ghost of the row follows the pointer, and the drop
place shows as a line before or after a row, or as a highlighted folder to drop
into: the top quarter of a folder row is before it, the bottom quarter after it
(unless it is open), the rest into it; a leaf row splits in half. Released,
`tree_view_update` reports `moved` with a `TreeViewMove{node, target,
position}`, which `tree_view_move_nodes` applies. A node cannot be dropped into
itself or its own subtree, and a drop that would leave everything where it was
is not reported as a move.

**Virtualization.** With `virtualize`, only the rows in view and `overscan`
more on each side are built; `tree_view_visible_range(config)` says which, so
`on_scroll` can rebuild only when they change (the gallery's 10,100-node tree
builds about 30 rows). `tree_view_reveal_offset(config, id)` is the offset that
brings a row into view.

### Implemented, already present, omitted

| GPUI Kit | ui2 |
| --- | --- |
| Nested items, `children`, `expanded`, `disabled` | Already present (`TreeViewNode.children`, `expanded`, `enabled`) |
| Expand and collapse with a disclosure | Already present (per-node `toggle_action_id`); themed: decoded by `tree_view_update` |
| Selection (`selected_index`, `set_selected_index`) | Already present as `selected` flags; themed: single and multiple selection with modifiers |
| File tree with icons, depth indent | Implemented (`icon`, `expanded_icon`, indent guides) |
| `TreeEvent::Expanded`, `Collapsed` | `step.expand`, `step.collapse` |
| `set_items`, `items` | The application owns the nodes |
| `set_selected_item`, `reveal_item`, `scroll_to_item` | `tree_view_reveal`, `tree_view_reveal_offset` |
| Keyboard Up, Down, Left, Right, Enter | Implemented, plus Home, End, paging, Shift ranges, select all, Space, Escape |
| Virtualized `uniform_list` | Implemented (`virtualize`) on `VirtualListLayout` |
| `render_item` closure | `row_content`, or the built-in icon, text and trailing text |
| `context_menu` | `TreeViewNode.menu`, the native right-click menu |
| Right-clicked row highlight | Omitted: ui2 reports no right-click events, only menu choices |
| Lazy loading (example) | Implemented: `has_children`, `load`, `loading`, `tree_view_with_children` |
| Search and filter (example) | Implemented: `tree_view_filter` |
| Multi-select (example, application-side) | Implemented in the component (`selection: .multiple`) |
| Check boxes with tri-state folders (not upstream) | Implemented (`checkable`) |
| Drag to reorder (not upstream) | Implemented (`reorderable`) |
| `scroll_bounce` | Left to the backend: AppKit's scroll views bounce, the custom renderer's do not |
| `Styled` refinements on the tree | Omitted: colors come from the theme, geometry from `size` |

## Accessibility

Tab bars are `tablist`s of `tab`s whose value is `selected` or `not
selected`; close buttons are labelled "Close …" and the menu button "All tabs"
(`expanded`/`collapsed`). Themed trees are `tree`s of `treeitem`s whose value
lists `selected`, `expanded`/`collapsed`, `checked`/`mixed`/`unchecked` and
`loading`; check boxes are `checkbox`es with the same check value; loading rows
are `status`. Disclosures are buttons labelled "Expand …" or "Collapse …".

## Platform notes

- AppKit maps `tablist`, `tab` and `checkbox`; `treeitem` rows keep their
  native button role so they stay pressable.

## Attribution

The tab variants' sizes, paddings, gaps and colors, the sliding indicator, the
folder tab's outline and the reveal-with-peek idea follow GPUI Kit's
`crates/component/src/tab/tab.rs` and `tab_bar.rs`; the tree's keyboard model
and reveal follow `crates/base/src/tree.rs`. Those files carry the Apache-2.0
header; see `third_party/gpui-kit`. The rest is new ui2 code.

## Verification

```sh
v test ui/component_navigation2_test.v
v -d ui2_custom_rendering test ui/component_navigation2_test.v
v test ui/tabbed_panel_test.v ui/tree_view_test.v ui/vml_test.v ui/vml_model_test.v
v run examples/gpui_navigation2/main.v
```
