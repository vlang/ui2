# Adaptive forms in UI2 Studio

UI2 Studio can edit a flat `Screen` as either a fixed-coordinate form (the
existing default) or an adaptive form. Adaptive forms use parent pins, centering,
size limits and compact/regular width and height variations. The designer and
`element_from_vml` use the same geometry resolver, so generated `main.v` files
adapt to `ui2.bounds()` when the window is rebuilt after a resize.

Try the included form:

```sh
v run ide ide/adaptive_sample.vml
```

## Design a form

1. Select the form or a control, open **Layout** in the Object Inspector, and
   enable **Adaptive layout**. Existing coordinates become the base design;
   this does not reposition the controls.
2. In **Base**, select a control and choose its horizontal and vertical pins.
   **Left/Top** preserve the near edge; **Right/Bottom** preserve the far edge;
   **Center** preserves its offset from the parent's center; **Both** preserves
   both edge insets by stretching the control. Insets and center offsets come
   from the current frame; edit X/Y/Width/Height or drag to change them.
3. Set minimum and maximum sizes in the Layout inspector. Press Return to apply
   numeric layout fields. A maximum of **0** means unlimited. Size limits take
   precedence over stretching's far pin, retaining the near pin; overflow is
   left visible rather than silently moving or shrinking another control.
4. Use **Phone**, **Tablet**, **Desktop**, **Rotate**, or a custom size in the
   preview bar. Press Return or **Apply size** after changing width/height.
   These controls change only the preview: they do not change saved dimensions,
   component coordinates, dirty state or undo history. Arbitrary preview sizes
   are read-only for geometry; text and event properties remain shared.
5. Cycle **Edit width** and **Edit height** through `any`, `compact`, and
   `regular` to edit a size-class layout. The first frame, pin, size-limit or
   visibility change creates a local override for the selected control. Its
   base layout and other variants stay unchanged. **Reset this size-class
   override** restores inheritance and is undoable. **Base** returns to Any/Any.

Add and duplicate controls in Base. A duplicate receives independent copies of
all variations. Deleting a control removes it and its variations in every size
class. Text, style, names and event handlers are shared across all layouts.
Changing the saved form Width/Height in Properties is a document edit, distinct
from previewing: it rebases the base frames while preserving their pins.

**Hidden in this layout** removes a control from the live Preview. The Design
canvas keeps a labeled proxy so it can still be selected and edited. **Guides**
shows the selected control's relationship to parent edges or its center line.
**Check layout** reports off-canvas and empty visible controls at the current
size in Messages. It does not check text truncation, overlap, accessibility or
arbitrary conflicting constraints.

The preview toolbar scrolls horizontally when the IDE window is narrow. The
property inspector also scrolls, including the size-limit and variation controls.

## Size classes and inheritance

The form's Layout inspector sets independent width and height breakpoints in
logical pixels. The defaults are 600 in each direction: values **below** the
breakpoint are compact, and values **at or above** it are regular. These are
application-defined thresholds, not Apple's device-specific UIKit traits.
Device buttons are generic logical-size presets, not hardware simulators or
safe-area emulators.

There are nine editing scopes: Any/Any is the base, and the other eight are
variations. Resolution is deterministic:

- An exact width+height match wins over a single-axis match.
- A width-specific match wins over a height-specific match when both apply.
- Otherwise the base layout is used.

A local variation replaces the **frame, reference canvas, pins, size limits and
visibility together**. It is not a per-property cascade. Until an override is
created, the control inherits a matching less-specific variation or its base.
Editing an abstract scope such as Compact/Any deliberately ignores more-specific
Compact/Compact and Compact/Regular variants; live Preview always uses the
actual viewport classes. Duplicate selectors are rejected rather than made
order-dependent.

The reference canvas stored with each variation prevents cumulative drift:
every resize resolves from saved geometry, never from the previous preview.
Undo/redo and source save/load preserve these reference frames and variations.
Disabling adaptive layout retains the metadata, so it can be enabled again.

## VML format

Adaptive behavior is opt-in. Screen `width` and `height` describe the base design
canvas; actual runtime bounds determine the displayed size.

```vml
Screen {
    id: Form1
    width: 760
    height: 520
    adaptive: true
    layout_breakpoint_width: 600
    layout_breakpoint_height: 600

    Button {
        id: save
        x: 624 y: 460 width: 112 height: 36
        text: "Save"
        on_tap: save_clicked
        layout_x: end
        layout_y: end

        LayoutVariation {
            width_class: compact
            height_class: any
            reference_width: 390
            reference_height: 844
            x: 24 y: 784 width: 342 height: 36
            layout_x: stretch
            layout_y: end
            layout_min_width: 0
            layout_max_width: 0
            layout_min_height: 0
            layout_max_height: 0
            hidden: false
        }
    }
}
```

`layout_x` and `layout_y` accept `start`, `end`, `center`, or `stretch`.
`layout_min_width`, `layout_max_width`, `layout_min_height` and
`layout_max_height` default to 0. Base `hidden` defaults to false. In hand-written
variations, omitted pin/limit/visibility fields inherit the base values when
loaded; the designer writes a complete local layout snapshot. A variation must
provide its reference width/height and x/y/width/height. Reference dimensions
must be positive, control dimensions non-negative, and numeric values finite.
Unknown variation properties, invalid classes, invalid limits and duplicate
selectors produce errors. `LayoutVariation` is metadata, not a rendered view.
Dropdown `Option` children remain independent of this metadata.

Stylesheets are orthogonal: `Style` blocks, `class:`, `style:`, and
`enabled:` round-trip alongside `LayoutVariation` and are preserved by
duplicate/undo/redo. Geometry varies by size class; text, events, classes,
and styles are shared. Container queries in Preview evaluate against the
scaled display frame, so verify breakpoints at 100% zoom or in the running
app.

## Scope

This is an Xcode-inspired adaptive workflow, **not** a general Auto Layout
solver. It supports physical parent edges and centers, not sibling equations,
constraint priorities, content hugging/compression resistance, baseline
alignment, automatic RTL leading/trailing mirroring, safe areas, or intrinsic
content measurement. Existing nested Row/Column/container layouts and dynamic
expressions remain Source-only; they are not flattened into the visual model.

The supported adaptive VML path is the runtime `element_from_vml` /
`element_from_vnode` path used by the IDE's generated companion. Compile-time
`$vml` code generation is not extended by this feature. Applications can also
call the pure `adaptive_layout_frame` and `adaptive_variation_index` helpers
from V. Validate rule limits with `validate_adaptive_layout` before resolving
programmatically constructed rules.
