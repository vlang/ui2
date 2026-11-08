# Popovers, hover cards and menus

Ports of GPUI Kit's [popover](https://github.com/longbridge/gpui-kit/blob/main/website/component/popover.md),
[hover card](https://github.com/longbridge/gpui-kit/blob/main/website/component/hover-card.md),
the dropdown, popup and context-menu parts of [menu](https://github.com/longbridge/gpui-kit/blob/main/website/component/menu.md),
and [dropdown button](https://github.com/longbridge/gpui-kit/blob/main/website/component/dropdown_button.md).
The implementation is in `ui/component_popovers_position.v` (placement),
`ui/component_popovers.v` (popover, hover card) and
`ui/component_popovers_menu.v` (dropdown menu, dropdown button);
`examples/gpui_popovers/main.v` shows all of them, with a popover, a hover card
and a menu with an open submenu showing from the start.

## Conventions

- **Overlays are built last.** A popover, hover card or menu is an element drawn
  on top of the rest of the window, so append it after everything it may cover,
  as one of the last children of the screen.
- **Window coordinates.** Each overlay takes `anchor`, the rectangle it opens
  next to (usually its trigger's frame), and `window`, the rectangle it has to stay
  inside: pass `ui2.bounds()`. Both are in window coordinates, which for a
  trigger that is a direct child of the screen is simply its frame. The overlay
  places itself; there is no layout pass to wait for.
- **Controlled state.** The application owns whether an overlay is open (and a
  menu's highlight). Components emit actions; each ships a decoder or a pure
  state machine that turns an event into the next state, rejecting actions that
  belong to something else, are malformed or forged, name disabled rows, or
  would change nothing. Store the result and rebuild.
- **Keys.** Components cannot capture keys. `popover_dismiss_key` and
  `dropdown_menu_key` are pure helpers to call from `on_key_event`; consume the
  key when they handle it.
- **Size and theme.** `size` is a `ComponentSize`, colors come from
  `ComponentTheme`. Surfaces are rounded panels with a one-point border, drawn
  as a border-colored shape with the fill inset over it so they look the same in
  the custom renderer, whose `BoxStyle` borders are square-cornered.
- **Closed means unmounted.** A closed overlay builds to an empty hidden view
  with its id, so the call can stay in the tree. Content inside a closed
  popover is not mounted and keeps no native state.

## Placement

```v
placed := ui2.popover_place(
    anchor: trigger_frame
    window: ui2.bounds()
    width:  240
    height: 120
    side:   .bottom // .top, .bottom, .left, .right
    align:  .start  // .start, .center, .end along that side
    offset: 4       // gap between anchor and surface (or arrow tip)
    margin: 8       // kept clear along every window edge
    arrow:  6       // arrow depth, added to the gap; 0 = none
    radius: 6       // the arrow stays clear of the surface's rounded corners
    flip:   true    // open on the opposite side when only that one has room
    shift:  true    // slide back inside the window
)!
// placed.frame, placed.side (after flipping), placed.flipped, placed.arrow
```

`popover_place` is the pure function every overlay here uses. The surface goes
on the preferred side if it fits there (surface plus gap), on the opposite side
if only that one has room, and otherwise on whichever of the two has more room.
It is then aligned along the side and clamped inside the window, keeping
`margin` from each edge; a surface larger than the window keeps its top-left
corner visible. Coordinates are rounded to whole points. `placed.arrow` is the
position of the arrow tip along the edge facing the anchor: the anchor's center,
clamped so the arrow clears the corners.

GPUI Kit names a popover's position with an `Anchor` (the popover's own corner)
and does not flip. The same positions in ui2 terms:

| GPUI Kit `Anchor` | `side` | `align` |
| --- | --- | --- |
| `TopLeft` / `TopCenter` / `TopRight` (below the trigger) | `.bottom` | `.start` / `.center` / `.end` |
| `BottomLeft` / `BottomCenter` / `BottomRight` (above) | `.top` | `.start` / `.center` / `.end` |
| `LeftCenter` (opens to the right) | `.right` | `.center` |
| `RightCenter` (opens to the left) | `.left` | `.center` |

Pass `flip: false` for GPUI Kit's clamp-without-flipping behavior.

## Popover

```v
// The trigger toggles the popover; any button can be one.
ui2.with_action(ui2.button('details-button', 'Details', trigger_frame, box, style),
    ui2.popover_toggle_action('details'))

// Last in the screen's children:
ui2.popover(
    id:       'details'
    open:     app.details_open
    anchor:   trigger_frame
    window:   ui2.bounds()
    width:    260
    height:   150
    side:     .bottom
    arrow:    true
    label:    'Dimensions' // accessibility label of the surface
    children: [...]        // relative to the padded body
    theme:    theme
)!

// on_event: the toggle action, and the dismiss action a press outside emits.
if open := ui2.popover_open_from_action('details', app.details_open, event) {
    app.details_open = open
}
// on_key_event: Escape closes it.
if ui2.popover_dismiss_key(app.details_open, key) {
    ui2.consume_key()
    app.details_open = false
}
```

`PopoverConfig` also has `align`, `offset`, `margin`, `flip`, `shift`,
`padding` (`-1` picks one for the size: 12 points at `.medium`, upstream's
`p_3`), `close_on_outside_click` (default `true`) and `dismiss_action` (the action
the outside press emits; `popover_dismiss_action(id)` by default). A button
inside the popover can emit `popover_dismiss_action(id)` to close it, which is
GPUI Kit's "emit `DismissEvent` from the content".

With `close_on_outside_click` the popover's root is a view over the whole
window whose first child is a transparent backdrop button; the surface sits
above it. The surface reports presses as a clickable view does, so a press on
its blank space stays with it rather than reaching the backdrop. While the
backdrop is up, nothing below it is hovered or clickable, which is GPUI's
occlusion. Without it the root is just the surface and its arrow, and
everything around them stays interactive.

The arrow is built from half-point strips: a border-colored triangle, the
surface, then a background-colored triangle one point smaller whose base
overlaps the surface border, so the outline runs from the surface into the
arrow's slopes.

## Hover card

The card opens once the pointer has rested on its trigger for `open_delay`
(0.6 s), and closes `close_delay` (0.3 s) after the pointer has left both the
trigger and the card, so the pointer can travel from one to the other. A pointer
sweeping across the trigger never opens it.

`HoverCardState` is a pure state machine. The application keeps one per card,
feeds it the pointer events of the trigger and the card, and runs the timers
each step asks for with `after` and `cancel_timer`:

```v
@[heap]
struct App {
mut:
    card       ui2.HoverCardState // HoverCardState{ open_delay: 0.2, close_delay: 0.1 } for a fast one
    card_timer ui2.TimerId
}

const app_state = &App{}

fn app() &App {
    return unsafe { app_state }
}

// apply_card stores the next state and runs the timer work it asks for. The
// timer feeds the card its generation back when it fires.
fn apply_card(step ui2.HoverCardStep) {
    mut model := app()
    model.card = step.state
    if step.cancel {
        ui2.cancel_timer(model.card_timer)
    }
    if step.schedule {
        generation := step.state.generation
        model.card_timer = ui2.after(step.delay, fn [generation] () {
            apply_card(app().card.timer_fired(generation))
        })
    }
}

// build: the trigger keeps its own action (a link here), wrapped in the hover area.
ui2.hover_card_trigger('profile', ui2.link(id: 'ada', text: '@ada', action_id: 'open-profile',
    frame: trigger_frame)!)!
// ...and last in the screen's children:
ui2.hover_card(
    id:       'profile'
    state:    app().card
    anchor:   trigger_frame
    window:   ui2.bounds()
    width:    300
    height:   104
    arrow:    true
    children: [...]
)!

// on_event:
if step := ui2.hover_card_step('profile', app().card, event) {
    apply_card(step)
}
```

| Event | Method | Result |
| --- | --- | --- |
| Pointer enters the trigger | `trigger_entered()` | Closed: start the open delay. Open: call off a pending close. |
| Pointer leaves the trigger | `trigger_left()` | Onto the card: nothing. Open: start the close delay. Opening: call it off. |
| Pointer enters the card | `card_entered()` | Call off a pending close. |
| Pointer leaves the card | `card_left()` | Unless back on the trigger, start the close delay. |
| A timer fires | `timer_fired(generation)` | Open or close, unless that timer has been replaced. |
| Escape, a click inside | `dismissed()` | Close now. |
| A tap (touch screens) | `tapped()` | Toggle without delays. |

Every step returns the next state with `cancel` (cancel the timer started
earlier), `schedule` and `delay` (start `after(delay)`). Each scheduled timer
gets a new `generation`; `timer_fired` ignores any other, so a timer that could
not be cancelled in time is harmless. The fields of `HoverCardState` are
readable (`open`, `trigger_hovered`, `card_hovered`, `pending`); set
`open: true` in its literal to start with the card showing.

`hover_card_trigger(id, element)` wraps any element in a hoverable view taking
its frame; the element keeps its own action and stays clickable. Hover follows
CSS `:hover`, so the pointer on the element counts as the pointer on the
wrapper. The card has no backdrop and does not close on outside clicks, as
upstream. Touch screens have no hover: call `tapped()` when the trigger's own
action arrives there.

## Dropdown menu

```v
fn edit_items(app &App) []ui2.DropdownMenuItem {
    return [
        ui2.dropdown_menu_heading('Clipboard'),
        ui2.DropdownMenuItem{
            ...ui2.dropdown_menu_item('cut', 'Cut')
            icon:     'scissors' // a symbol name
            shortcut: 'cmd+x'    // shown as ⌘X on macOS, Ctrl+X elsewhere
        },
        ui2.DropdownMenuItem{
            ...ui2.dropdown_menu_item('paste', 'Paste')
            enabled: false
        },
        ui2.dropdown_menu_separator(),
        ui2.dropdown_menu_checkbox('wrap', 'Word wrap', app.word_wrap),
        ui2.dropdown_menu_submenu('Sort by', [
            ui2.dropdown_menu_radio('name', 'Name', app.sort == 'name'),
            ui2.dropdown_menu_radio('size', 'Size', app.sort == 'size'),
        ]),
    ]
}

// build, last in the screen's children:
ui2.dropdown_menu(
    id:     'edit-menu'
    state:  app.edit_menu // ui2.DropdownMenuState
    items:  edit_items(app)
    anchor: button_frame
    window: ui2.bounds()
    label:  'Edit'
)!

// on_event: toggle, outside press, choosing a row, hovering a row.
if step := ui2.dropdown_menu_update('edit-menu', edit_items(app), app.edit_menu, event) {
    app.edit_menu = step.state
    if step.chosen {
        match step.item.id {
            'wrap' { app.word_wrap = !app.word_wrap }
            'name', 'size' { app.sort = step.item.id }
            else { run(step.item.id) }
        }
    }
}
// on_key_event:
if step := ui2.dropdown_menu_key(edit_items(app), app.edit_menu, key) {
    ui2.consume_key()
    // ...the same handling as above
}
```

Rows (`DropdownMenuItem`) have a `kind`: `.item`, `.checkbox`, `.radio`,
`.separator`, `.label` (a group heading) or `.submenu` (with `items`). They
carry `id` (the value a choice returns, unique among choosable rows), `label`,
`icon` (a symbol name drawn as `symbol:<icon>`; use names `symbol_known`
accepts), `shortcut`, `checked`, `enabled`, and, for custom content,
`children` (drawn in place of the label) and `height`. Builders:
`dropdown_menu_item`, `dropdown_menu_checkbox`, `dropdown_menu_radio`,
`dropdown_menu_separator`, `dropdown_menu_heading`, `dropdown_menu_submenu`.
`validate_dropdown_menu_items` rejects missing or duplicated ids, untitled rows,
empty submenus and decorated separators; `dropdown_menu` calls it.

A checked row shows a check mark (a dot for radio rows) in the leading column,
in place of its icon. The leading column is reserved when any row of that level
has an icon or is a check or radio row, so toggling a check does not shift the
labels. Radio rows are grouped by the application, which checks one per group.

`DropdownMenuState` holds `open` and `path`, the highlighted row of every open
level: `[5]` highlights the sixth row and, when it is a submenu, shows that
submenu beside it; `[5, 0]` also highlights the submenu's first row. A step
from `dropdown_menu_update` or `dropdown_menu_key` carries the next state, and
`chosen`, `item` and `path` when a row was chosen (the menu closes then).

| Input | Effect |
| --- | --- |
| `dropdown_menu_toggle_action(id)` | Open or close (emit it from the trigger; `dropdown_button` does). |
| Press outside | Close (`dropdown_menu_dismiss_action(id)` from the backdrop). |
| Press on a row | Choose it; a submenu row opens its submenu. |
| Pointer enters a row | Highlight it, closing sibling submenus; a disabled row, heading or separator clears the highlight at its level. |
| Pointer leaves a row | Clear its highlight, unless a key moved the highlight elsewhere or the row is a submenu (the pointer is on its way into it). |
| Up / Down | Previous / next navigable row, skipping separators, headings and disabled rows, wrapping around. |
| Home, Page Up / End, Page Down | First / last navigable row. |
| Right, or Enter on a submenu row | Open the submenu and highlight its first row. |
| Left | Back out of a submenu. |
| Enter, Space | Choose the highlighted row. |
| Escape, Tab | Close the menu. |

The menu sizes itself from an estimate of its rows (`dropdown_menu_size`), at
least `min_width` (128) and at most `max_width` (480), unless `width` is set. A
level taller than `max_height` (or the window) scrolls. Submenus open beside
their row, their first row level with it, and flip to the other side near the
window edge. `dropdown_menu_item_from_action(id, items, action)` decodes a
choice on its own, and `dropdown_menu_item_action(id, path)` builds a row's
action, for tests or for driving a menu programmatically.

### Relationship to ui2's other menus

ui2 already has three kinds of menu, and the dropdown menu complements them:

- `Element.menu` (`[]MenuEntry`) attaches a native right-click menu to an
  element: drawn by the system, a flat list of titles that emit their ids.
- `set_menu_bar` and `set_tray` take `MenuItem` rows with shortcuts, check
  marks, disabled rows, separators and submenus, again drawn by the system
  (README "Menus and the tray").
- `dropdown` is the native select control.

`dropdown_menu` is drawn by ui2 itself, inside the window, so it looks the same
on every backend and can carry icons, radio rows, headings, custom content and
hover highlights, and it can open from any rectangle. To show the same choices
in both places, `dropdown_menu_items_from_menu([]MenuItem)` and
`dropdown_menu_items_from_entries([]MenuEntry)` convert existing declarations;
shortcuts use the same `cmd+shift+s` syntax and are rendered with
`menu_shortcut_label`. For GPUI Kit's context menu, keep using `Element.menu`
for a native right-click menu, or open a `dropdown_menu` anchored at
`rect(x, y, 0, 0)` from a pointer event's coordinates for a drawn one.

## Dropdown button

```v
ui2.dropdown_button(
    id:      'edit-button'
    menu_id: 'edit-menu' // the dropdown_menu it opens
    label:   'Edit'
    icon:    'pencil'
    open:    app.edit_menu.open // drawn pressed, announced as expanded
    frame:   button_frame
)!

// A split button: the main half has its own action, the chevron opens the menu.
ui2.dropdown_button(
    id:         'save-button'
    menu_id:    'save-menu'
    label:      'Save'
    split:      true
    action_id:  'save' // default: dropdown_button_action(id)
    menu_label: 'More save options' // the chevron's accessibility label
    tone:       .primary
    open:       app.save_menu.open
    frame:      save_frame
)!
```

Both forms emit `dropdown_menu_toggle_action(menu_id)` from their menu trigger,
so `dropdown_menu_update` handles it with no extra code. Anchor the menu to the
button's frame; GPUI Kit's split button anchors its menu at the trailing edge,
which is `align: .end`. `tone` and `outline` choose the colors (neutral filled by
default), `enabled: false` disables both halves, and `dropdown_button_width`
estimates a width that fits the label, icon and chevron. The chevron is a caret
built from strips like the popover arrow, because a `▾` glyph comes out at very
different sizes in different fallback fonts.

## Accessibility

Popover surfaces have the role `dialog` and the configured `label`; hover cards
`group`; the outside-press backdrop `presentation`. Menus are `menu` surfaces
labelled with the menu's (or the submenu row's) label, with `menuitem`,
`menuitemcheckbox` and `menuitemradio` rows (value `checked`/`unchecked`;
submenu rows `expanded`/`collapsed`), `separator` rows and `text` headings. A
dropdown button is a button whose value is `expanded` or `collapsed`; a split
button is a `group` of two buttons. AppKit does not map the `menu*` roles yet,
so those rows keep the view's own role there.

## Implemented and omitted

### Popover

| Upstream feature | Status |
| --- | --- |
| Content anchored to a trigger, `anchor` positions | Implemented as `side` + `align` (see the table above), plus flipping and shifting from upstream's side positioner |
| `offset`, `arrow` (follows the side, clears rounded corners, outlined) | Implemented |
| Controlled `open` + `on_open_change` | Implemented: the app owns `open`; toggle/dismiss actions and `popover_open_from_action` replace the callback |
| Dismiss on outside click, `overlay_closable(false)` | Implemented (`close_on_outside_click`, custom `dismiss_action`) |
| Escape to dismiss | Implemented as `popover_dismiss_key` for `on_key_event` |
| Dismiss from inside the content (`DismissEvent`) | Implemented: emit `popover_dismiss_action(id)` |
| `default_open` | Not needed: initialise the app's `open` |
| `trigger(...)`, `Selectable::open` styling | Omitted: the app builds its own trigger and styles it from `open` (the gallery's side buttons do) |
| `mouse_button(Right)` | Omitted: ui2 reports no mouse button; use `Element.menu` or a clickable view's pointer events |
| `appearance(false)`, `Styled` refinements | Omitted: pass `padding: 0` and draw your own content; surface colors come from the theme |
| `content` builder closure | Not applicable: content is an element list rebuilt with the tree |
| Focus capture and restoration, Enter/Space on the trigger | Omitted: components cannot take focus; native buttons keep their own keyboard activation |
| Open animation, shadow | Omitted: `BoxStyle` has no shadow; the app can animate the surface by id |

### Hover card

| Upstream feature | Status |
| --- | --- |
| Open on hover with `open_delay` (600 ms), close with `close_delay` (300 ms) | Implemented |
| Stays open moving between trigger and card; quick sweeps never open | Implemented |
| Epoch-based debouncing of timers | Implemented as `generation` |
| `anchor` positions | Implemented as `side`/`align` (default `.bottom`/`.center`, upstream's `TopCenter`), with flipping |
| `on_open_change` | The app sees every change as the returned state |
| Tap to toggle on touch platforms | `tapped()`; the app calls it where there is no hover |
| `appearance(false)`, styling | Omitted, as for popovers |
| Arrow | Added (`arrow: true`); upstream hover cards have none |

### Dropdown menu

| Upstream feature | Status |
| --- | --- |
| Items with label, icon, disabled state | Implemented |
| Keyboard shortcuts shown beside items | Implemented from a `shortcut` string; upstream reads them from action key bindings |
| Check state (`menu_with_check`) | Implemented, plus explicit checkbox and radio rows |
| Separators (trailing separator dropped), labels | Implemented |
| Submenus, with icons, flipping at the window edge, Left/Right navigation | Implemented |
| Keyboard: Up/Down (wrapping, skipping), Enter, Escape, Tab | Implemented, plus Home/End and Space |
| Hover highlight that a key press does not fight | Implemented |
| Custom element items (`menu_element`) | Implemented as `children` + `height` |
| Scrollable menus, `min_w`/`max_w`/`max_h` | Implemented; a submenu of a scrolled level is placed as if the level were scrolled to the top, and the keyboard highlight is not scrolled into view (the component cannot read the scroll position) |
| Anchor positions (`dropdown_menu_with_anchor`) | Implemented as `side`/`align` |
| Link items (`link`, external-link icon) | Omitted: ui2 components never open URLs; use an item and open it in the app |
| `check_side(Right)` | Omitted |
| Actions, `action_context`, key-binding lookup | Not applicable: rows emit ids through the app's event handler |
| Context menu on right click | Native via `Element.menu`; a drawn one can be anchored at a pointer position |
| App menu bar | Existing `set_menu_bar` |

### Dropdown button

| Upstream feature | Status |
| --- | --- |
| Split button: main action + caret trigger, joined | Implemented (`split: true`) |
| Plain button with a chevron opening a menu (`Button::dropdown_menu`) | Implemented (default) |
| Shared variant and size, outline | `tone`, `outline`, `size` |
| `menu_accessibility_label` ("More options") | Implemented as `menu_label` |
| Disabled | Implemented |
| Open state shown on the trigger | Implemented (`open`) |
| `dropdown_menu_with_anchor` | The app picks `side`/`align` on its `dropdown_menu` |
| Ghost variant hover reveal, loading, tooltip on the inner button | Omitted; `with_tooltip` can wrap the result |

## Verification

```sh
v test ui/component_popovers_test.v
v -d ui2_custom_rendering test ui/component_popovers_test.v
v run examples/gpui_popovers/main.v
v -d ui2_custom_rendering run examples/gpui_popovers/main.v
```

The tests cover placement (preferred and flipped sides, the roomier side when
neither fits, alignment, offsets and arrows, clamping, windows smaller than the
surface, invalid geometry), arrow geometry on all four sides, popover structure
and actions, every hover-card transition including stale timers and quick
sweeps, menu validation, navigation, hover and keyboard handling, forged and
disabled actions, submenu placement and flipping, scrolling, the `MenuItem` and
`MenuEntry` conversions, and both dropdown button forms. Some positioning cases
are adapted from upstream's positioner tests.
