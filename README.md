## Safe areas

A `SafeArea` insets its children by the operating-system intrusions — the
status bar, display notch, camera housing, and home indicator on phones —
after Flutter's `SafeArea`. Each side can be switched off individually, and
`minimum` keeps at least that much room where the platform reports nothing.
Children are positioned relative to the safe content box:

```v
content := ui2.safe_area(
    id:    'safe'
    frame: ui2.bounds()
    minimum: ui2.LayoutPadding{ top: 8, bottom: 8 }
    children: [ui2.label('title', 'Hello', ui2.rect(0, 0, 200, 24), style)]
)!
```

```vml
SafeArea {
    id: safe
    minimum_top: 8
    minimum_bottom: 8
}
```

`SafeViewport` is the scrolling equivalent, after Flutter's `SliverSafeArea`:
the scroll pane spans the whole frame while its content clears the intrusions,
so the first and last rows are never hidden behind a notch or home indicator.
`scroll_mode` chooses the axes, as in `scroll_with_mode`:

```vml
SafeViewport {
    id: list
    scroll_mode: vertical_only
}
```

`safe_area_insets()` reports the current intrusions per side (zero where the
platform keeps them outside the content rect, as on desktop); `safe_area_top()`
is the top edge of the same value. iOS reads the view's `safeAreaInsets`, so
rotating the phone or revealing the keyboard-adjacent edges is picked up on
the next build.

## Scaffold

`scaffold` lays a screen out the way Compose's `Scaffold` does: a top bar, a
bottom bar, content filling the box between them, and optional floating
action and snackbar overlays docked inside the content box. Slot elements
keep their declared sizes; bar children are positioned relative to their
strip, content children relative to the content box, and the overlays are
placed by the scaffold itself:

```v
ui2.scaffold(
    id:                'app'
    frame:             ui2.bounds()
    top_bar_height:    56
    bottom_bar_height: 64
    top_bar:           [ui2.label('title', 'Scaffold', ui2.rect(16, 0, 200, 56), style)]
    content:           [ui2.label('body', 'Hello', ui2.rect(16, 16, 200, 24), style)]
    bottom_bar:        [ui2.label('nav', 'Nav', ui2.rect(16, 0, 200, 64), style)]
    floating_action:   ui2.button('add', '+', ui2.rect(0, 0, 56, 56), fab_box, fab_text)
    snackbar:          ui2.label('snack', 'Saved', ui2.rect(0, 0, 100, 40), snack_text)
)!
```

```vml
Scaffold {
    id: app
    top_bar_height: 56
    bottom_bar_height: 64

    Label { slot: top text: "Scaffold" }
    Label { text: "Hello" }
    Label { slot: bottom text: "Nav" }
    Button { slot: fab text: "+" x: 0 y: 0 width: 56 height: 56 }
}
```

Children without a `slot` land in the content box. At most one `fab` and one
`snackbar` child are allowed; anything else in `slot` is rejected while the
document loads. `scaffold_content_rect` exposes the content box for code that
places its own overlays.

## Fonts and text sizes