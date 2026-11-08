# Sidebar

A port of GPUI Kit's [sidebar](https://github.com/longbridge/gpui-kit/blob/main/website/component/sidebar.md):
a navigation panel with a header, labelled groups of menu items (icons, badges,
suffixes, nested sub-items), a footer, either side of the window, and an icon
rail when collapsed. The implementation is in `ui/component_sidebar.v` (model,
state, actions, keyboard, anchors) and `ui/component_sidebar_view.v` (drawing,
colors and the collapse toggle). `examples/gpui_sidebar/main.v` is a small
project-tracker shell: an expanded sidebar with groups, nested items, badges, a
switch and a footer next to the page, a right-side inspector that collapses off
the canvas, a collapsed rail in a preview window, menus opened from the header,
the footer, the items' ⋯ buttons and a rail flyout, and a light/dark toggle.

## Conventions

- **Controlled state.** The application owns `SidebarState` (the current item,
  which items are expanded, which groups are folded, the keyboard cursor and
  the hover) and whether the sidebar is collapsed. The sidebar emits actions;
  `sidebar_update` and `sidebar_key` turn an event or a key into the next state
  and say what happened. They reject actions that belong to something else, are
  malformed or forged, name items the sidebar does not show (inside a folded
  group or a collapsed item) or that are disabled, and presses that would change
  nothing. Store the step's state and rebuild.
- **Items are named by id.** Item ids and group ids share one namespace and are
  unique across the sidebar. They are hex-encoded into actions, so they may
  contain any character.
- **Frames.** The application frames the sidebar, usually the full height of
  the window at its left or right edge; `sidebar_width` gives the width for its
  state. Child frames are sidebar-local, but every anchor helper answers in the
  coordinates `frame` is given in (window coordinates for a sidebar placed in
  the screen), which is what `dropdown_menu` and `popover` take.
- **Overlays are the application's.** Header and footer menus, item context
  menus and rail flyouts are `dropdown_menu`s the application builds last, over
  everything else, anchored with the helpers below.
- **Keys.** Components cannot capture keys: call `sidebar_key` from
  `on_key_event` and `consume_key()` whenever it returns a step.
- **Size and theme.** `size` is a `ComponentSize`; colors come from
  `ComponentTheme` through `sidebar_colors`, in light and dark themes alike.

## Sidebar

```v
fn nav_config(m &Model) ui2.SidebarConfig {
	win := ui2.bounds()
	collapsed := ui2.sidebar_auto_collapsed(win.width, ui2.sidebar_breakpoint, m.collapsed)
	return ui2.SidebarConfig{
		id:        'nav'
		frame:     ui2.rect(0, 0, ui2.sidebar_width(260, collapsed, .icon, .medium), win.height)
		collapsed: collapsed
		header:    ui2.SidebarHeader{
			title:    'Acme Inc'
			subtitle: 'Enterprise'
			icon:     'bolt'  // a symbol on a primary-colored tile
			menu:     true    // a button: emits sidebar_header_action('nav')
		}
		groups:    [
			ui2.SidebarGroup{
				label: 'Platform'
				items: [
					ui2.SidebarItem{ id: 'dashboard', label: 'Dashboard', icon: 'house' },
					ui2.SidebarItem{ id: 'inbox', label: 'Inbox', icon: 'tray', badge: '12' },
					ui2.SidebarItem{
						id:       'projects'
						label:    'Projects'
						icon:     'folder'
						more:     true // a ⋯ button for the item's actions
						children: [
							ui2.SidebarItem{ id: 'web', label: 'Web App' },
							ui2.SidebarItem{ id: 'mobile', label: 'Mobile App' },
						]
					},
					ui2.SidebarItem{ id: 'analytics', label: 'Analytics', icon: 'chart.bar', dot: true, badge_tone: .danger },
					ui2.SidebarItem{ id: 'team', label: 'Team', icon: 'person.2', suffix: '1,234' },
					ui2.SidebarItem{ id: 'archive', label: 'Archive', icon: 'tray', enabled: false },
				]
			},
			ui2.SidebarGroup{
				id:          'settings' // collapsible groups need an id
				label:       'Settings'
				collapsible: true
				items:       [...]
			},
		]
		footer:    ui2.SidebarFooter{
			title:    'Ada Lovelace'
			subtitle: 'ada@acme.dev'
			avatar:   'Ada Lovelace'
			menu:     true
		}
		state:     m.nav
		offset:    m.nav_offset
		theme:     ui2.component_theme(m.dark)
	}
}

// build:
ui2.sidebar(nav_config(m))!

// on_event:
if step := ui2.sidebar_update(nav_config(m), event) {
	m.nav = step.state
	match step.event {
		.activate { navigate(step.item.id) }
		.collapse { m.collapsed = step.collapsed }
		.header { m.org_menu = m.org_menu.toggled() }
		.footer { m.account_menu = m.account_menu.toggled() }
		.more {
			m.item_menu_of = step.item.id
			m.item_menu = m.item_menu.opened()
		}
		.flyout {
			m.flyout_of = step.item.id
			m.flyout = m.flyout.opened()
		}
		else {} // .expand, .group, .hover, .focus: the state says it all
	}
}

// on_scroll: anchors and sidebar_reveal_offset need the groups' scroll position.
if id == ui2.sidebar_scroll_id('nav') {
	m.nav_offset = ui2.scroll_offset(id)
}
```

The sidebar draws, from top to bottom: the header, the groups, and the footer,
pinned to the bottom edge, with a one-point border along the edge that faces the
content (`border: false` drops it). The groups scroll in
`sidebar_scroll_id(id)` once they are taller than the room between the header
and the footer; when they fit they are a plain view, since a Scroll element
would add room below them to scroll into. The sidebar is not virtualized: every
shown row is built.

### Configuration

`SidebarConfig`:

| Field | Meaning |
| --- | --- |
| `id`, `frame` | Required id; the sidebar's frame. |
| `groups` | `[]SidebarGroup`. |
| `header`, `footer` | Drawn when they have a title, an icon, an avatar or children. |
| `state` | `SidebarState`, below. |
| `collapsed` | Show the icon rail (or nothing, off-canvas). |
| `collapsible` | `.icon` (default): collapses to a rail `sidebar_rail_width(size)` wide; `.offcanvas`: collapses to nothing, building a hidden view, so it can stay in the tree; `.none`: never collapses and ignores the toggle. |
| `side` | `.left` (default) or `.right`: where the border goes and which way the rail hugs. |
| `offset` | The groups' scroll position, stored from `on_scroll`. |
| `follow_focus` | Arrow keys also activate the item they move to, as a native source list does. |
| `open_menu`, `header_open`, `footer_open` | The item whose ⋯ menu (in the rail: whose flyout) is open, and whether the header's and footer's menus are: they are drawn pressed. |
| `more_always` | Show every ⋯ button, for touch screens, which do not hover. |
| `border` | The edge line (default `true`). |
| `accessibility_label` | Default `'Sidebar'`. |
| `size`, `theme` | `ComponentSize`, `ComponentTheme`. |

`SidebarGroup` has an `id` (required when `collapsible`), a `label` (empty
draws no label row) and `items`. A collapsible group's label is a button with a
chevron that folds the group shut; folded groups keep their label.

`SidebarItem`:

| Field | Meaning |
| --- | --- |
| `id`, `label` | Required. |
| `icon` | A symbol name (`symbol_known`). In the rail, an item without one shows its label's initial. |
| `badge`, `badge_tone` | Short text in a pill at the end (default tone `.primary`; `.neutral` is a quiet gray). |
| `dot` | A dot in the badge tone instead of a pill. |
| `suffix` | Muted text at the end: a total, a shortcut. |
| `accessory`, `accessory_width` | Custom trailing elements (a small switch, say), framed in a box that wide and as tall as the row. |
| `children` | Sub-items, shown while the item is in `state.expanded`; they nest to any depth, each level indented beside a guide line. |
| `click` | What a press on an item with sub-items does besides activating it: `.activate` (default; only the chevron shows them), `.open` (also shows them) or `.toggle` (also shows or hides them). |
| `more` | A ⋯ button emitting `sidebar_more_action`; it shows while the row is hovered, focused, current or its menu is open. |
| `menu` | The row's native right-click menu (`[]MenuEntry`, whose entries emit their own ids). |
| `enabled` | Disabled items are dimmed, inert and skipped by the keyboard. |
| `tooltip` | What the rail shows on hover (the label by default; `Inbox (12)` with a badge). |
| `accessibility_label` | Defaults to the label and the badge. |

`SidebarHeader` and `SidebarFooter` share their fields: `title`, `subtitle`,
`icon` (a symbol on a primary tile, a logo) or `avatar`/`avatar_image` (a round
avatar, a user), `menu` (a button emitting `sidebar_header_action` /
`sidebar_footer_action`, with `menu_icon` at its end: `chevron.down` for the
header and `ellipsis` for the footer by default), `children` (custom content
replacing the logo and text, framed in the block's own coordinates) and `height`
(zero picks one for the size). In the rail they shrink to the logo or avatar,
with the title as a tooltip.

### State

```v
pub struct SidebarState {
	active        string   // the current item
	expanded      []string // items whose sub-items show
	closed_groups []string // collapsible groups folded shut
	focused       string   // the keyboard cursor: an item or a collapsible group
	hovered       string   // the element under the pointer, by its action; pass it back
}
```

The current item is drawn highlighted in a primary tint with a bold label and a
primary icon. When it is hidden (its parent is collapsed, or the sidebar is a
rail) the nearest shown item above it is highlighted instead, so the rail always
shows where the user is. The keyboard cursor is a primary focus ring; pointer
presses clear it, so a mouse user never sees it. Rows highlight under the
pointer through the hover events they report, which `sidebar_update` keeps in
`hovered`.

### Events

`sidebar_update(config, event) ?SidebarStep` returns `step.event`, the
`step.state` to store, and `step.item`, `step.group` or `step.collapsed` as the
event needs:

| Input | `step.event` | Effect |
| --- | --- | --- |
| Press on an item | `.activate` | It becomes `active`; its `click` may show or hide its sub-items (`.expand` when only that changed). |
| Press on a rail item with sub-items | `.flyout` | Nothing changes: open `sidebar_flyout_items` beside it. |
| Press on an item's chevron | `.expand` | Its id is toggled in `expanded`. |
| Press on a collapsible group's label | `.group` | Its id is toggled in `closed_groups`. |
| Press on an item's ⋯ button | `.more` | Open its menu at `sidebar_more_anchor`. |
| Press on the header or footer (with `menu`) | `.header`, `.footer` | Open its menu at `sidebar_header_anchor` / `sidebar_footer_anchor`. |
| `sidebar_collapse_action(id)` | `.collapse` | `step.collapsed` is the new value; store it where `collapsed` comes from. |
| Pointer enters or leaves a row, label, header, footer or the toggle | `.hover` | `hovered` follows the pointer. |

The single-purpose decoders are built on it: `sidebar_item_from_action(config,
action) ?SidebarItem` (an item became current), `sidebar_expanded_from_action`
(the next `expanded`), `sidebar_closed_groups_from_action` (the next
`closed_groups`) and `sidebar_collapsed_from_action(id, collapsed, action) ?bool`
(which needs no config, for a toggle that lives elsewhere). The action builders
are public too: `sidebar_item_action`, `sidebar_expand_action`,
`sidebar_more_action`, `sidebar_group_action`, `sidebar_header_action`,
`sidebar_footer_action`, `sidebar_collapse_action` and `sidebar_scroll_id`.

`sidebar_select(config, item_id) ?SidebarState` makes an item current from
outside (a flyout menu, a route, a search result): it unfolds its group and
expands every item above it. It rejects unknown and disabled items.

### Keyboard

```v
fn on_key(event ui2.KeyEvent) {
	if step := ui2.sidebar_key(nav_config(m), event) {
		ui2.consume_key()
		apply(step) // as for sidebar_update
		ui2.refresh()
		if step.reveal {
			// After the refresh, so the scroll has its new range.
			if offset := ui2.sidebar_reveal_offset(nav_config(m), m.nav.focused) {
				m.nav_offset = offset
				ui2.scroll_to_offset(ui2.sidebar_scroll_id('nav'), offset)
			}
		}
	}
}
```

`sidebar_key` moves through the sidebar as through a tree:

| Key | Effect |
| --- | --- |
| Down / Up | The next / previous enabled item or collapsible group label, without wrapping. The first key starts on the current item. |
| Home, Page Up / End, Page Down | The first / last one. |
| Right | Show an item's sub-items, or unfold a group; when they show already, go to the first of them. |
| Left | Hide an item's sub-items, or fold a group; otherwise go up to the item it is under, or to its group's label. |
| Enter, Space | Activate the item (a rail item with sub-items asks for its flyout), or fold or unfold the group. |
| Escape | Hide the cursor. |

Keys with Cmd, Ctrl, Alt or Shift are left alone. With `follow_focus`, moving
onto an item also activates it.

### Menus, context menus and flyouts

Upstream items take a right-click `context_menu`, and the header and footer a
`dropdown_menu`. In ui2 a press on a composite element cannot tell the mouse
buttons apart, and the custom renderer has no right-click menus at all, so the
portable form is a button that opens a `dropdown_menu`:

```v
// The ⋯ button of an item with `more: true`:
ui2.dropdown_menu(
	id:     'item-menu'
	state:  m.item_menu
	items:  item_menu_items()
	anchor: ui2.sidebar_more_anchor(nav_config(m), m.item_menu_of) or { ui2.rect(0, 0, 0, 0) }
	window: ui2.bounds()
	side:   .right
)!
// The header: a menu under it, or beside it in the rail.
ui2.dropdown_menu(
	id:     'org-menu'
	state:  m.org_menu
	items:  org_items(m)
	anchor: ui2.sidebar_header_anchor(nav_config(m)) or { ui2.rect(0, 0, 0, 0) }
	window: ui2.bounds()
	side:   if collapsed { .right } else { .bottom }
)!
```

Pass `open_menu: m.item_menu_of` (while that menu is open), `header_open` and
`footer_open` so the trigger stays visible and pressed. Where a native
right-click menu exists (AppKit, Windows), `SidebarItem.menu` adds one as well;
`dropdown_menu_items_from_entries(item.menu)` turns the same entries into rows
for the ⋯ menu.

In the rail, sub-items have no room. A press on a rail item with sub-items
reports `.flyout`; show them in a menu beside it and pass the choice to
`sidebar_select`:

```v
ui2.dropdown_menu(
	id:     'flyout'
	state:  m.flyout
	items:  ui2.sidebar_flyout_items(nav_config(m), m.flyout_of) // the current one checked
	anchor: ui2.sidebar_item_anchor(nav_config(m), m.flyout_of) or { ui2.rect(0, 0, 0, 0) }
	window: ui2.bounds()
	side:   .right
)!
// on a choice: m.nav = ui2.sidebar_select(nav_config(m), step.item.id) or { m.nav }
```

`sidebar_item_anchor`, `sidebar_more_anchor`, `sidebar_header_anchor` and
`sidebar_footer_anchor` return none for things the sidebar does not show; they
account for the frame's origin and the groups' scroll `offset`.

### Collapsing, widths and responsiveness

```v
// In the title bar or a toolbar:
ui2.sidebar_toggle_button(
	id:         'nav-toggle'
	sidebar_id: 'nav'
	frame:      ui2.rect(12, 10, 32, 32)
	collapsed:  collapsed
	side:       .left
	hovered:    ui2.sidebar_toggle_hovered(m.nav, 'nav')
)!
```

The toggle is upstream's `SidebarToggleButton`: an icon of a panel with its pane
on the sidebar's side, filled while the sidebar is expanded, drawn from strips so
it looks the same on every renderer. It emits `sidebar_collapse_action(sidebar_id)`
and reports its hover under that action, which `sidebar_update` keeps in the
sidebar's `hovered`; any other button can emit the action too. `on_sidebar`
draws its fills in the sidebar's colors, for a toggle placed inside one.

`sidebar_width(expanded, collapsed, collapsible, size)` is the width to frame
the sidebar with (`sidebar_default_width` is upstream's 255), and
`sidebar_rail_width(size)` the rail's (48 at `.medium`). GPUI Kit's responsive
sidebar collapses on narrow windows; `sidebar_auto_collapsed(available,
breakpoint, collapsed)` is that rule (`sidebar_breakpoint` is upstream's 768):
keep the user's choice and pass the result as `collapsed`.

### Theming

`sidebar_colors(theme) SidebarColors` derives upstream's sidebar tokens from a
`ComponentTheme`: `background` (between the theme's background and muted
colors), `foreground`, `muted` (group labels, suffixes, icons), `disabled`,
`border`, `hover`, `pressed`, `active` (a primary tint) and
`active_foreground`, `ring`, and `logo`/`logo_foreground`. Use them for chrome
next to the sidebar, such as a title bar of the same color.

## Accessibility

The sidebar is a `navigation` element (its value is `collapsed` in the rail),
the groups a `tree`, and each row a `treeitem` labelled with its label and
badge, whose value says `current` and `expanded`/`collapsed`. Chevrons are
buttons named "Toggle <label> submenu" (upstream's wording), ⋯ buttons "More
actions for <label>", collapsible group labels buttons with an
expanded/collapsed value, and the header and footer buttons (with `menu`) or
groups named by their title and subtitle. The toggle button says "Collapse
sidebar" or "Expand sidebar" and carries the state as its value.

## Implemented and omitted

| Upstream feature | Status |
| --- | --- |
| `Sidebar::new(id)`, `header`, `footer`, `child`/`children` | `sidebar(SidebarConfig)` with `header`, `footer`, `groups` |
| `side(Side::Left / Right)` | `side: .left / .right` |
| `collapsed`, `collapsible(bool)` and `SidebarCollapsible::{Icon, Offcanvas, None}` | `collapsed` and `collapsible: .icon / .offcanvas / .none` |
| `width(...)`, default 255 and collapsed 48 | The frame; `sidebar_width`, `sidebar_default_width`, `sidebar_rail_width` |
| Width transition when collapsing (200 ms) | Omitted: frames are the application's and the rows are laid out for the width they get, so the layout switches at once. |
| `SidebarGroup::new(label)` | `SidebarGroup{ label, items }`; folding groups (`collapsible`) is new, after shadcn's collapsible groups |
| `SidebarMenu` | Not a separate type: a group's `items` |
| `SidebarMenuItem::new(label)`, `icon`, `disable` | `SidebarItem{ label, icon, enabled }` |
| `active(bool)` | `state.active`, one current item; a hidden one highlights its nearest shown ancestor |
| `on_click` | `.activate` from `sidebar_update` |
| `children`, the caret button, `default_open` | `children`, the chevron (`sidebar_expand_action`), the initial `state.expanded` |
| `click_to_open`, `click_to_toggle` | `click: .open / .toggle` |
| `suffix(...)`: Badge, text, Switch, icon | `badge`/`badge_tone`, `dot`, `suffix`, and `accessory` elements for anything else |
| `context_menu(...)` (right click) | `more` (a ⋯ button and a `dropdown_menu` at `sidebar_more_anchor`) on every renderer, and `menu` (native right-click entries) on AppKit and Windows |
| Header / footer `dropdown_menu`, `Selectable` | `menu: true`, the anchors and a `dropdown_menu`; `header_open`/`footer_open` draw them pressed |
| Header and footer content | `title`, `subtitle`, `icon` or `avatar`, or custom `children` |
| Collapsed item tooltips (`collapsed_tooltip`) | Rail tooltips with `with_tooltip`, from the label or `tooltip` |
| Collapsed items with sub-items | New: a `.flyout` event and `sidebar_flyout_items` |
| `SidebarToggleButton` with panel icons, `accessibility_label` | `sidebar_toggle_button`, `label` |
| `accessibility_label` on items | Implemented |
| Theme tokens `sidebar`, `sidebar_foreground`, `sidebar_border`, `sidebar_accent(_foreground)`, `sidebar_primary(_foreground)` | `sidebar_colors(ComponentTheme)` |
| Responsive sidebar (`is_mobile || collapsed`) | `sidebar_auto_collapsed`, `sidebar_breakpoint` |
| Scrolling list with a vertical scrollbar and bounce | A Scroll element with the backend's scroller and bounce, used only when the groups overflow; not virtualized |
| `border_width`, `label_style` and other `Styled` refinements | Omitted: one-point border (`border`), and the size and theme set the rest |
| Keyboard navigation | Not in upstream; added as `sidebar_key` (tree-style) |

## Verification

```sh
v test ui/component_sidebar_test.v
v -d ui2_custom_rendering test ui/component_sidebar_test.v
v run examples/gpui_sidebar/main.v
v -d ui2_custom_rendering run examples/gpui_sidebar/main.v
```

The tests cover validation (ids, labels, symbols, groups, header and footer,
geometry), layout (header, footer and body frames, rows, sub-items and their
guide, folded groups, the rail on both sides and its dividers, the current
item's nearest shown ancestor, when the groups scroll), rendering (actions,
keys, roles and values, the focus ring, ⋯ buttons on hover, badges, rail
tooltips and badge dots, off-canvas hiding, the toggle button), every event
including forged, foreign, hidden, disabled and no-op actions, the click modes,
flyouts, `sidebar_select`, hover tracking, the keyboard (moving without
wrapping, folding and climbing, Enter, Escape, `follow_focus`, the rail), the
anchors with a frame origin and a scroll offset, and reveal offsets.
