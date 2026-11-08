# Disclosure components: accordion and carousel

An audit of ui2's existing `accordion` and `carousel` against GPUI Kit's
[accordion](https://github.com/longbridge/gpui-kit/blob/main/website/component/accordion.md)
and [carousel](https://github.com/longbridge/gpui-kit/blob/main/website/component/carousel.md)
pages, and the features it added. Both widgets keep their existing API and
behavior; the GPUI Kit features are new fields with defaults and new functions.

The code is in `ui/accordion.v` and `ui/carousel.v` (configs, the original
layouts, geometry and navigation), `ui/component_disclosure.v` (the stacked
accordion and the shared animation helpers) and
`ui/component_disclosure_carousel.v` (the carousel's viewport, controls,
indicators, decoders, drag and animation). `examples/gpui_disclosure/main.v`
shows every feature with a light/dark toggle. All of it is a new UI2
implementation of the documented behavior; no upstream code was adapted.

## Conventions

- State is controlled. A component never changes itself: it emits an action,
  the application decodes it with the component's decoder, stores the result
  and rebuilds. Decoders take **the config the component was built with**, so
  build one config from the model and use it in both places:

  ```v
  fn faq_config(m &Model) ui2.AccordionConfig {
      return ui2.AccordionConfig{
          id:     'faq'
          frame:  ui2.rect(20, 20, 420, 0)
          layout: .stack
          open:   m.faq_open
          items:  [ui2.AccordionItem{ title: 'Shipping', icon: 'cart', content: shipping }]
      }
  }

  // build:    ui2.accordion(faq_config(m)) or { panic(err) }
  // on_event: if open := ui2.accordion_open_from_action(faq_config(m), action) {
  //               m.faq_open = open
  //           }
  ```

  Decoders return `none` for actions that belong to something else, forged or
  malformed actions, disabled components or items, and actions that would not
  change anything (the current indicator, the next button on the last slide).
- Components cannot capture keys. Each has key helpers to call from
  `on_key_event` while the application considers the component focused; the
  `focused` fields draw the focus ring.
- Animations are opt-in: call `accordion_animate(before, after)` or
  `carousel_animate(before, after)` with the config the component was built
  with and the one it is about to be rebuilt with, before the rebuild. Not
  calling them is how an application honours a reduced-motion preference.
- A ui2 view does not clip its children, so content that slides or unrolls sits
  in a `scroll` whose content fits it: a scroll always clips to its frame, and
  one with nothing to scroll hands the wheel to the pane around it.

## Accordion

`accordion` has two layouts, chosen by `AccordionConfig.layout`:

- `.fill` (the default, unchanged): Kivy's accordion. `current` is open and
  takes every point the other headers (`min_space` each) leave, horizontally or
  vertically. Headers are styled buttons that emit the item's `action_id`.
  This is what VML's `Accordion` builds.
- `.stack`: GPUI Kit's accordion. Title rows stack from the top; any item may be
  open (or several, with `multiple`), and an open panel is as tall as its
  content.

```v
config := ui2.AccordionConfig{
    id:       'faq'
    frame:    ui2.rect(24, 120, 552, 0) // height 0: as tall as the items need
    layout:   .stack
    open:     m.faq_open                // []int
    multiple: false
    bordered: true
    hovered:  m.faq_hover
    focused:  m.faq_focus
    size:     .medium
    theme:    ui2.component_theme(m.dark)
    items:    [
        ui2.AccordionItem{
            title:   'Is it accessible?'
            icon:    'questionmark.circle'
            content: ui2.label('', answer, ui2.rect(0, 0, ui2.accordion_body_width(552, .medium, true), 40), style)
        },
        ui2.AccordionItem{ title: 'Billing', icon: 'creditcard', enabled: false },
    ]
}
children << ui2.accordion(config) or { panic(err) }

// on_event
if open := ui2.accordion_open_from_action(config, action) {
    before := config
    m.faq_open = open
    ui2.accordion_animate(before, faq_config(m)) or {}
} else if hovered := ui2.accordion_hover_from_event(config, action) {
    m.faq_hover = hovered
}

// on_key_event, while the accordion has the keyboard
if focused := ui2.accordion_focus_after_key(config, event.code) {
    m.faq_focus = focused
} else if open := ui2.accordion_open_after_key(config, event.code) {
    m.faq_open = open
}
```

An item's `content` frame is relative to the panel body, which starts under the
title row and is inset by the size's padding; the panel is as tall as the
content's bottom edge plus the bottom padding. `accordion_body_width(width,
size, bordered)` is the width the content has. A frame height of 0 sizes the
accordion to its items; `accordion_stack_layout(config).height` is that height,
for placing what follows.

API: `AccordionLayout` (`.fill`, `.stack`); new `AccordionConfig` fields
`layout, open, multiple, bordered = true, enabled = true, hovered = -1,
focused = -1, accessibility_label, size, theme`; new `AccordionItem.icon`;
`accordion_stack_layout` → `AccordionStackLayout{height, items, titles,
panels, body_width}`, `accordion_body_width`, `accordion_open_items`,
`accordion_toggled`, `accordion_open_from_action`, `accordion_hover_from_event`,
`accordion_focus_after_key`, `accordion_open_after_key`, `accordion_animate`,
`accordion_item_action_id`, `accordion_panel_id`.

| GPUI Kit accordion | ui2 | Status |
| --- | --- | --- |
| Items with a title and content | `items`, `AccordionItem{title, content}` | Already present (both layouts) |
| One item open at a time (default) | `.stack` without `multiple`; `.fill` always | Implemented / already present |
| `multiple(true)` | `multiple: true` | Implemented |
| Collapsible: clicking the open item closes it, all may be closed | `.stack` | Implemented (`.fill` keeps one open, as before) |
| `bordered` (default true): one rounded card, items joined by separators | `bordered` | Implemented |
| Sizes `small`, `medium`, `large` | `size` | Implemented |
| Size `xsmall` | — | Omitted: `ComponentSize` has no extra-small size |
| `on_toggle_click(open_indices)` | `accordion_open_from_action` returns the open indices | Implemented |
| `disabled` accordion and disabled items | `enabled` on the config and on items | Implemented (items already in `.fill`) |
| Item `icon` | `AccordionItem.icon` (SF Symbol name) | Implemented |
| Title as an arbitrary element (icon plus text) | `icon` + `title` | Partly: the documented icon-and-text title is covered; arbitrary title elements are not |
| Nested accordions | `content` is any element, including an accordion | Implemented (see the gallery) |
| Chevron that turns half a turn when open | `chevron.down` / `chevron.up` | Implemented as a swap: symbol images do not rotate on the custom renderer |
| Animated reveal (spring), unmounted once closed | `accordion_animate`: rows glide, the opening panel unrolls, the card follows | Implemented with an ease-out tween; a closing panel's content goes at once, since closed content is not mounted |
| Hover style for the title row (none by default) | `hovered` + `accordion_hover_from_event`, muted fill | Implemented; no hover unless the application tracks it, as upstream |
| Keyboard: triggers are buttons (Enter/Space) | `accordion_focus_after_key` (Up/Down wrap, Home/End, skipping disabled rows), `accordion_open_after_key` (Enter/Space), `focused` ring | Implemented through helpers |
| Accessibility: expanded state | Title rows are buttons valued `expanded`/`collapsed`; open panels are groups labelled with the title | Implemented |
| `title_style`, `content_style`, `Styled` refinements | Theme, size, and the content element's own styling | Omitted: ui2 components take a theme, not style refinements (`.fill` keeps its `header_box`/`*_text_style`) |

## Carousel

Any of `controls`, `indicators`, `per_view` above one, `gap`, `clip`,
`draggable` or `focused` switches a carousel from its original layout (every
slide filling the frame, inactive slides hidden, exactly as before) to GPUI
Kit's: the slides sit in a clipping viewport and stay mounted, so they can
slide; the frame also holds the controls and indicators.

```v
fn hero_config(m &Model) ui2.CarouselConfig {
    return ui2.CarouselConfig{
        id:          'hero'
        frame:       ui2.rect(24, 120, 560, 240)
        index:       m.hero
        loop:        true
        controls:    .outside   // or .inside, over the slides' edges
        indicators:  .dots      // or .numbers
        per_view:    1
        gap:         0
        draggable:   true
        drag_offset: m.hero_offset
        focused:     m.focus == 'hero'
        box:         ui2.BoxStyle{ transparent: true, radius: 12 }
        theme:       ui2.component_theme(m.dark)
        slides:      slides
    }
}

fn set_hero(mut m Model, index int) {
    before := hero_config(m)
    m.hero = index
    m.hero_offset = 0
    ui2.carousel_animate(before, hero_config(m)) or {}
}

// on_event
if index := ui2.carousel_index_from_action(hero_config(m), action) {
    set_hero(mut m, index)
} else if drag := ui2.carousel_drag_event(hero_config(m), m.hero_drag, action) {
    m.hero_drag = drag.drag
    if drag.phase == .end { set_hero(mut m, drag.index) } else { m.hero_offset = drag.offset }
}

// on_key_event, while the carousel has the keyboard
if index := ui2.carousel_index_after_key(hero_config(m), event.code) {
    set_hero(mut m, index)
}
```

`box` styles the viewport's background (`BoxStyle`'s default is white; pass
`transparent: true` to let the slides' own backgrounds show) and its radius
rounds the focus ring. `direction` keeps its meaning: `.right` (the default)
and `.left` are horizontal, `.bottom` and `.top` vertical, and the controls,
indicators, arrow keys and drags follow it. Previous and next are outline
circles on the side their slides come from, dimmed and inert at the ends of a
carousel that does not loop.

**Autoplay** is the application's timer, since components do not create
timers. Pausing on hover needs only `with_hover` on the carousel, which reports
`pointer:enter:<id>` and `pointer:leave:<id>`:

```v
fn schedule_autoplay() {
    mut m := app()
    ui2.cancel_timer(m.timer)
    if !m.playing { return }
    m.timer = ui2.after(3.0, fn () {
        mut m := app()
        if !m.hero_hovered && !m.hero_drag.active {
            set_hero(mut m, ui2.carousel_autoplay_index(hero_config(m)))
        }
        schedule_autoplay()
    })
}

children << ui2.with_hover(ui2.carousel(hero_config(m)) or { panic(err) })
```

`carousel_autoplay_index` is the next position, or the first one after the last
of a carousel that does not loop.

API: `CarouselControls` (`.none`, `.outside`, `.inside`), `CarouselIndicators`
(`.none`, `.dots`, `.numbers`); new `CarouselConfig` fields `per_view = 1, gap,
controls, indicators, clip, draggable, drag_offset, focused, enabled = true,
previous_label, next_label, accessibility_label = 'Carousel', size, theme`;
`carousel_layout` → `CarouselLayout{viewport, previous, next, indicators,
pages, extent, step}`, `carousel_current`, `carousel_max_index`,
`carousel_page_count`, `carousel_has_previous`, `carousel_has_next`,
`carousel_next_index`, `carousel_previous_index`, `carousel_autoplay_index`,
`carousel_index_from_action`, `carousel_index_after_key`, `CarouselDrag`,
`CarouselDragPhase`, `CarouselDragEvent`, `carousel_drag_event`,
`carousel_animate`, `carousel_previous_action_id`, `carousel_next_action_id`,
`carousel_page_action_id`, `carousel_track_id`. The existing
`carousel_index`, `carousel_next`, `carousel_previous`, `carousel_frames`
(now relative to the viewport, which is the frame in the original layout) and
`carousel_index_after_swipe` keep working.

| GPUI Kit carousel | ui2 | Status |
| --- | --- | --- |
| Slides in a snapping viewport | `slides`, `index` | Already present |
| Controlled selection, change events | `index` + `carousel_index_from_action` / key / drag decoders | Already present / implemented |
| Horizontal and vertical (`Axis`) | `direction` (`.right`, `.left`, `.bottom`, `.top`) | Already present (also right-to-left and bottom-to-top) |
| Looping | `loop`; animations take the shorter way round the wrap | Already present / implemented |
| Previous and next controls: outline round icon buttons outside the viewport, disabled at the ends | `controls: .outside` | Implemented; `.inside` (over the slides) is an addition |
| Control sizes | `size` | Implemented |
| Control accessibility label and tooltip | `previous_label`, `next_label` | Implemented |
| Custom control content | `carousel_has_previous`/`has_next`/`next_index`/`previous_index` to build one's own | Omitted as a slot: compose custom controls instead, as upstream's own guide suggests |
| Pagination items | `indicators: .dots` (current one a pill) or `.numbers` | Implemented; arbitrary indicator content is not |
| Several items per view, with spacing | `per_view`, `gap`; positions that would leave the view part empty collapse, as upstream's duplicate snap points | Implemented for whole numbers of slides |
| Keyboard: arrows along the axis, Home, End | `carousel_index_after_key` | Implemented through the helper |
| Focus ring when focused from the keyboard | `focused` | Implemented (the application decides when) |
| Pointer drag that settles on the nearest position | `draggable`, `drag_offset`, `carousel_drag_event` (follows the pointer, resists past the ends, moves as many positions as the drag covered) | Implemented; `carousel_index_after_swipe` remains |
| Wheel and trackpad scrolling (a notch moves one item; an edge gesture scrolls the parent) | — | Omitted: views do not receive wheel events in ui2 |
| Animated movement between positions | `carousel_animate` | Implemented (ease-out slide of the track) |
| Reduced motion | the application does not call `carousel_animate` | Application's choice |
| Accessibility: labelled region, item position | Root `group` labelled `accessibility_label`, valued "Slide n of N"; each slide labelled "Slide n of N" unless the application labelled it | Implemented (`group`, as AppKit has no `region` mapping) |
| Autoplay | `after` + `carousel_autoplay_index`, pause on hover with `with_hover` | Not upstream; documented pattern |
| `Styled`/`track_style` refinements | `box`, `gap`, `per_view` | Omitted: ui2 components take a theme, not style refinements |

## Limitations

- An accordion's closing panel disappears at once while the rows below glide up;
  opening unrolls. A closed item's content is not mounted, so it cannot animate
  out.
- Animations start from the layout the decoder saw and end at the layout of the
  config passed as `after`; if the application rebuilds with a different
  layout mid-animation, elements settle on the declaration when it ends.
- Neither widget adds VML properties: VML's `Accordion` and `Carousel` build the
  original layouts as before.
