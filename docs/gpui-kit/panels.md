# Panels: resizable panels and dock area

Ports of GPUI Kit's [Resizable](https://github.com/longbridge/gpui-kit/blob/main/website/component/resizable.md)
and [Dock](https://github.com/longbridge/gpui-kit/blob/main/website/component/dock.md)
(with the model of [Dock — gpui-base](https://github.com/longbridge/gpui-kit/blob/main/website/base/dock.md)).

| GPUI Kit | ui2 | Source |
| --- | --- | --- |
| `h_resizable`, `v_resizable`, `resizable_panel`, `ResizableState`, `ResizablePanelEvent` | `resizable_panels(ResizablePanelsConfig)`, `ResizablePanel`, `ResizableState`, `resizable_panels_event`, `resizable_panels_key`, `resizable_panels_toggle`, `resizable_panels_layout` | `ui/component_panels.v` |
| `resize_handle`, `HandleEdge`, `ResizeHandleState`, `resize_handle_appearance` | `resize_handle(ResizeHandleConfig)`, `ResizeHandleEdge`, `ResizeHandlePhase`, `resize_handle_frame`, `resize_handle_indicator` | `ui/component_panels.v` |
| `DockLayout`, `PaneTree` edits, `DockAreaState` (persistence), `DockPlacement` | `DockLayout`, `DockRegion`, `DockGroup`, `dock_layout_*` operations, `dock_layout_encode`/`dock_layout_decode` | `ui/component_panels_dock.v` |
| `DockArea`, `DockSkin`, `Panel`, `TabPanel`, `DockEvent` | `dock_area(DockAreaConfig)`, `DockPanel`, `DockAreaState`, `dock_area_event`, `dock_area_key`, `dock_area_layout`, `DockAreaEvent` | `ui/component_panels_dock_view.v` |

Tests are in `ui/component_panels_test.v`. `examples/gpui_panels/main.v` has two
pages: **Workspace**, an IDE built with `dock_area` (explorer and search on the
left, editor tabs in the center, an outline on the right, a terminal, problems
and output at the bottom), and **Resizable**, a row of panels with a column
nested in its middle panel that shows every panel's size as it is laid out.
Both have a light/dark toggle.

```sh
v run examples/gpui_panels/main.v
v -d ui2_custom_rendering run examples/gpui_panels/main.v
UI2_PANELS_PAGE=resizable v run examples/gpui_panels/main.v   # open on the second page
```

## Conventions

- **Controlled state.** Nothing here keeps state of its own. A group of
  resizable panels takes a `ResizableState`; a dock area takes a `DockLayout`
  (what the user arranged, which the application saves) and a `DockAreaState`
  (the drag, hover, focus and open menu, which it does not). Pointer reports,
  clicks and menu choices come back through `on_event`; the decoders return the
  next state, or none for events that belong to something else, are malformed or
  forged, are not allowed, or would change nothing. Store what they return and
  rebuild.
- **Keys.** Components cannot capture keys. `resizable_panels_key` and
  `dock_area_key` are pure helpers for `on_key_event`: call them and consume the
  key when they return something.
- **Frames.** Child frames are parent-local, as everywhere in ui2. Panel content
  is built for its panel-local frame, `rect(0, 0, width, height)`, through a
  build function, so content follows the panel's size; views do not clip their
  children, so keep content inside that frame (a `scroll` clips).
- **Handles.** Panels are separated by a one-point line. Its grab band reaches
  four points past the line on each side, on top of the panels, with the
  resize cursor. At rest only the line shows; GPUI Kit's indicator grows on it
  as the pointer engages it — 20 points at 35% when hovered, 28 at 60% when
  pressed, 44 at 90% while dragging — and a handle with keyboard focus shows it
  in the primary color. Drags decode window coordinates relative to the press,
  so a handle works wherever its group sits.

## Resizable panels

```v
mut app_state := ui2.ResizableState{} // kept by the application

fn sidebar_and_main(frame ui2.Rect, state ui2.ResizableState) ui2.ResizablePanelsConfig {
	return ui2.ResizablePanelsConfig{
		id:     'layout'
		frame:  frame
		axis:   .horizontal // .vertical stacks the panels
		state:  state
		panels: [
			ui2.ResizablePanel{
				key:         'sidebar'
				label:       'Sidebar'
				size:        240 // initial size; 0 shares what sized panels leave
				min_size:    160 // default 100, as upstream
				max_size:    400 // 0 means none
				collapsible: true
				build:       fn (frame ui2.Rect) ui2.Element {
					return ui2.label('', 'Sidebar', frame, ui2.TextStyle{})
				}
			},
			ui2.ResizablePanel{
				key:   'main'
				build: fn (frame ui2.Rect) ui2.Element {
					return main_content(frame) // may be another resizable_panels
				}
			},
		]
	}
}

// build:   ui2.resizable_panels(sidebar_and_main(frame, app.split))!
// events:  if step := ui2.resizable_panels_event(config, event) { app.split = step.state }
// keys:    if step := ui2.resizable_panels_key(config, key) { ui2.consume_key(); app.split = step.state }
```

`ResizablePanel` fields: `key` (required, unique), `size`, `min_size`,
`max_size`, `fixed`, `resizable`, `visible`, `collapsible`, `collapsed_size`,
`label`, `box` (the panel's background, transparent by default), and either
`children` (in panel-local coordinates) or `build` (wins when set).

- **Sizes.** `ResizableState.sizes` and `.collapsed` run parallel to the panels.
  While `sizes` does not have one entry per panel, each panel starts at its own
  `size` and the panels without one share what is left evenly.
  `resizable_panels_layout(config)` returns the sizes and frames as laid out,
  plus the handles; every press stores the laid-out sizes in the state.
- **Container resizes.** The stored sizes are fitted to the container on every
  build, without changing them: held to each panel's range first, then a
  difference is shared by the flexible panels in proportion to their sizes,
  then by `fixed` panels, then by locked ones, and as a last resort past the
  limits so the panels always cover the container. A window shrunk below what
  the panels need and grown again gets the same proportions back.
- **Dragging** a handle moves space between its two sides, nearest panels
  first: the side the handle moves into gives way (each panel down to its
  minimum), the other side takes it (each up to its maximum). A `fixed` panel
  only gives or takes for its own handles; a panel with `resizable: false` is
  locked at its size and moves along whole, so the panels past it resize.
- **Collapsing.** A `collapsible` panel collapses to `collapsed_size` (0 hides
  its content) when its handle is dragged more than half its minimum past that
  minimum, and expands to at least its minimum when a handle beside it pulls it
  open by half its minimum; one drag can do both, as react-resizable-panels and
  VS Code sashes do. `resizable_panels_toggle(config, panel)` collapses or
  restores one from a button. A collapsed panel's entry in `sizes` is the size
  it restores to.
- **Hidden panels** (`visible: false`) take no space and have no handle; their
  stored size is kept for when they come back.
- **Nesting.** A panel's `build` can return another `resizable_panels` with the
  frame it is given; each group has its own id and state.
- **Events.** `ResizablePanelsStep{kind, state, handle, panel}` with `kind` one of
  `hover`, `resize_start` (the handle is now focused for keys), `resize`,
  `resize_end` (a good moment to save the sizes), `collapse`, `expand`, `focus`.
  `resizable_handle_action(id, handle)` is a handle's action; handles are named
  by the index of the panel before them.
- **Keyboard** (on the handle pressed last): the arrows along the group's axis
  move it by `step` (10 points; Shift moves 50), Home and End as far as the panels
  allow, Enter collapses or restores a collapsible panel beside it, Escape clears
  the focus. The focus indicator shows only after a key, like `:focus-visible`.

### Standalone handle

`resize_handle(ResizeHandleConfig{id, frame, axis, edge, phase, focus_visible,
line, enabled, accessibility_label, accessibility_value, theme})` draws a handle
for an edge no group owns (an application's own sidebar). `resize_handle_frame(axis,
position, start, length, edge)` gives its band for a line at `position`: `.straddle`
centers the band on the line, `.leading` and `.trailing` keep it inside a
container whose first or last point is the line. It reports `pointer:down|drag|up`
and `enter`/`leave` under its id; decode them with `parse_pointer_event`.

### Resizable: implemented and omitted

Implemented: horizontal and vertical groups, initial sizes and flexible panels,
size ranges, fixed panels with upstream's container-resize rule, conditional
visibility, nested groups, the standalone handle with leading/trailing edges,
the hairline and three-level indicator, sizes readable at any time (upstream's
`sizes()`), programmatic resizing (`resize_panel` → apply a new
`ResizableState.sizes`), resize events for persistence.

Added beyond upstream: collapsible panels, locked (`resizable: false`) panels
and keyboard resizing; upstream documents none of them.

Omitted: the indicator's eased transition (the state switches instantly; a
handle could animate with ui2's widget animations if wanted), `insert_panel`/
`remove_panel` on the state (edit the panel list and `sizes` together instead),
style refinements on panels beyond `box`, and double-click on a handle (ui2 has
no double-click event; use `resizable_panels_toggle` from a button or Enter).

## Dock area

```v
fn dock_config(app &App) ui2.DockAreaConfig {
	return ui2.DockAreaConfig{
		id:      'workspace'
		frame:   ui2.rect(0, 40, win.width, win.height - 40)
		layout:  app.layout // a ui2.DockLayout
		state:   app.dock   // a ui2.DockAreaState
		panels:  [
			ui2.DockPanel{ id: 'files', title: 'Files', icon: 'folder' },
			ui2.DockPanel{ id: 'main.v', title: 'main.v', icon: 'curlybraces' },
			ui2.DockPanel{ id: 'terminal', title: 'Terminal', zoom_button: true },
		]
		content: build_panel // fn (panel string, frame ui2.Rect) ui2.Element
		theme:   ui2.component_theme(app.dark)
	}
}

layout := ui2.DockLayout{
	version: 1
	center:  ui2.DockRegion{ groups: [ui2.DockGroup{ panels: ['main.v'] }] }
	left:    ui2.DockRegion{ size: 240, groups: [ui2.DockGroup{ panels: ['files'] }] }
	bottom:  ui2.DockRegion{ size: 200, groups: [ui2.DockGroup{ panels: ['terminal'] }] }
}

// build:   ui2.dock_area(dock_config(app))!
// events:  if e := ui2.dock_area_event(dock_config(app), event) { app.layout = e.layout; app.dock = e.state }
// keys:    if e := ui2.dock_area_key(dock_config(app), key) { ui2.consume_key(); app.layout = e.layout; app.dock = e.state }
```

### The model

`DockLayout{version, center, left, right, bottom, zoomed}` is a value: four
`DockRegion{groups, open, size}`, each a row (center, bottom dock) or a column
(side docks) of `DockGroup{panels, active, size}` tab groups. Panels are named
by ids; the area takes titles, icons and capabilities from `DockPanel` entries
(a panel without one is titled with its id). A region's groups size like
resizable panels: a group's `size` is its extent along the region (0 shares the
rest) with `min_group` as minimum. A dock's `size` is its width (side docks) or
height (bottom); 0 uses `side_size` (240) or `bottom_size` (200). A closed
dock keeps its groups and size. `zoomed` names a panel whose group fills the
whole area.

Operations return a new layout and leave the one passed in alone:
`dock_layout_normalized` (drops empty and repeated ids and empty groups, clamps
active indexes, cleans sizes and the zoom), `dock_layout_find`,
`dock_layout_panels`, `dock_layout_is_open`, `dock_layout_activate` (opens a
closed dock), `dock_layout_close` (the tab after a closed displayed tab is
shown; a zoom on the group moves to it), `dock_layout_add` (into a region's first
group, opening it), `dock_layout_move`, `dock_layout_split` (a new group after
its own, taking half its size), `dock_layout_toggle`, `dock_layout_resize`,
`dock_layout_zoom` and `dock_layout_retain` (keeps the panels the application
still has). The ones that can refuse return an option.

### Saving and restoring

```v
text := ui2.dock_layout_encode(app.layout)         // save anywhere
restored := ui2.dock_layout_decode(text) or { default_layout() }
if restored.version == layout_version {
	app.layout = ui2.dock_layout_retain(restored, known_panel_ids)
}
```

The text format is a few lines (`ui2-dock 1`, `version`, `zoomed`, then each
region as `center open 0` followed by its `group <active> <size> <ids>...`, ids
percent-escaped). `dock_layout_decode` rejects anything malformed with an error
rather than guessing. `DockLayout` holds only strings, numbers and booleans, so
`json2.encode(layout)` and `json2.decode[ui2.DockLayout](text)` work as well
(missing fields take their defaults); run the result through
`dock_layout_normalized`. `version` is the application's schema version, as
upstream's: compare it before using a saved layout.

### What the area draws

- Side docks take the full height; the bottom dock sits under the center,
  between them. The center keeps at least `min_center` points across and down;
  the docks give way first down to `min_dock` from what each has above it.
- Each group has a tab bar (34 points at `.medium`) over its displayed panel. A
  group of one panel shows a title bar instead (`panel_style: .auto`, upstream's
  `PanelStyle::Auto`, uppercase in the docks); `.tabs` always shows tabs, and
  `DockPanel.title_bar: false` opts a panel out. Tabs fit their titles, shrink
  toward a minimum when they do not fit, and leave out the ones that still do
  not, keeping the displayed tab in view. The displayed tab takes the content
  background; the current panel's (`DockAreaState.current`, set on activation)
  carries a primary accent line.
- Close buttons appear on closable tabs (`close_buttons`), except on a dock's
  last panel, which upstream does not let close.
- The trailing tools are a zoom button (always while zoomed; otherwise when the
  panel sets `zoom_button`) and the panel menu ("..."). Upstream's dock toggle
  buttons sit where its skin puts them: the left dock's at the start of the
  center's first group, the right dock's at the end of the center's last group,
  the bottom dock's at the start of its first group (`toggle_buttons`). They are
  drawn from boxes, a window with its dock pane filled while open, so they look
  the same on every renderer, as is the zoom glyph.
- A closed bottom dock stays as a strip of its tabs; clicking one opens it.
  Closed side docks are reopened from their toggles (or the application's own
  controls). An empty center shows `empty_text` under a bar with the toggles.
- Panel content is keyed by panel id, so a panel's native views survive moving
  it between docks.

### Panel menu, moving and zooming

The "..." button opens a `dropdown_menu` for the displayed panel:
`DockPanel.menu_items` first (choosing one reports `menu_item` with `item` set),
then Zoom In/Out (`zoomable`), Move to each other region and Split Right/Down
(unless `locked`), then Close (`dock_area_can_close`). `dock_area_menu_items`
returns the rows; built-in ids start with `dock:`. The menu is drawn inside the
area, on top, and is controlled through `DockAreaState.menu_panel` and `.menu`;
`dock_area_event` and `dock_area_key` drive it like any dropdown menu.

### Resizing

Dock edges (`left`, `right`, `bottom`) and the dividers between groups
(`split:<placement>:<index>`) are handles. Dragging an edge resizes its dock
between `min_dock` and what leaves the center its minimum; dragging it more than
half the minimum below the minimum closes the dock and keeps its size, and
dragging back reopens it within the same drag. Dividers move space between
groups like resizable panels. A pressed handle takes the keys: arrows move it by
`step`, Home and End to its limits, Enter opens or closes an edge's dock, Escape
clears the focus. Escape also zooms out when nothing else takes it.

### Events

`DockAreaEvent{kind, panel, placement, item, layout, state}` with `kind` one of
`activate`, `close`, `move`, `split`, `toggle_dock`, `zoom`, `resize_start`,
`resize`, `resize_end`, `hover`, `focus`, `menu` and `menu_item`. Store `layout`
and `state` from every one; save the layout on the kinds that change it
(`resize_end` rather than every `resize`).

### Dock: implemented and omitted

Implemented: center plus left, right and bottom docks; tab groups with titles,
icons, close buttons and title bars for single panels; splits (one level per
region); activating, closing, adding, moving and splitting panels; toggling,
resizing and collapsing docks; zoom; a locked mode; per-panel closable,
zoomable, zoom control and title bar options and custom menu rows; the
serializable layout with a version; restoring with unknown panels dropped.

Omitted, with reasons:

- **Drag-and-drop of tabs** between groups and docks (optional in this port):
  ui2 has no drag-and-drop between elements, only pointer reports on one element,
  so the panel menu's Move and Split commands do this.
- **Nested splits** inside a region (a split of splits): each region is one row
  or column of groups, which covers the side-by-side editors and stacked dock
  panels the documentation shows, and keeps the saved format and the menu simple.
- **Renderer traits** (`DockAreaRenderer`, `TabGroupRenderer`) and `DockSkin`:
  ui2 components are styled through `ComponentTheme`, `ComponentSize` and the
  config; `dock_area_layout` exposes every rectangle for an application that
  wants to draw its own chrome.
- **Panel lifecycle hooks** (`on_added_to`, `set_active`, `on_removed`): with a
  controlled layout the application sees every change in the events and can
  compare layouts.
- **Panel registry and factories**: panels are just ids here; the application
  builds their content, so restoring needs only `dock_layout_retain`.
- **Scrolling tab bars**: tabs shrink and then hide past the end while keeping
  the displayed one visible.
- **Keyboard actions** such as upstream's `ToggleZoom` and `ClosePanel` key
  bindings: applications bind keys and apply `dock_layout_zoom` or
  `dock_layout_close` themselves.

## Accessibility

Resizable groups and their panels are `group`s labelled by
`accessibility_label` and each panel's `label` (value `collapsed` when
collapsed). Handles are `separator`s labelled `Resize <panel>` with the size
before them as value; dock edges are labelled `Resize Left Dock` and so on.
Dock tab bars have role `tablist` (labelled with their region), tabs `tab` with
`selected`/`not selected`, and close, menu, zoom and toggle buttons are buttons
with labels and tooltips (`Close <title>`, `More`, `Zoom In`, `Open Left Dock`);
the menu button's value is `expanded` while its menu is open. Panel content is
a `group` labelled with the panel's title.

## Attribution

`ui/component_panels.v` takes two rules from GPUI Kit: the handle indicator's
levels (length and opacity for hovered, pressed and dragging, its 3-point
thickness, the 4-point grab padding) of `crates/component/src/resizable.rs` and
`crates/base/src/resizable/resize_handle.rs`, and the container-resize rule for
fixed panels of `crates/base/src/resizable/mod.rs`, whose fixed-panel test
cases `ui/component_panels_test.v` reuses. `ui/component_panels_dock_view.v` takes the chrome rules
of `crates/component/src/dock/tab_panel.rs`: where the dock toggle buttons go,
the collapsed bottom strip, title bars for single panels, zoom in the menu with
a toolbar button to zoom out, and no close for a dock's last panel. The three
files carry the Apache-2.0 header. The sizing, drag, collapse and keyboard rules, the layout
model and its text format, the geometry and the drawing are new UI2 code.

## Verification

```sh
v test ui/component_panels_test.v
v -d ui2_custom_rendering test ui/component_panels_test.v
v run examples/gpui_panels/main.v
v -d ui2_custom_rendering run examples/gpui_panels/main.v
```
