# UI2 Studio

<img width="1200" alt="UI2 Studio running with native macOS controls" src="../docs/images/ide-macos.png" />


`ide/` is a Delphi/Lazarus-style visual form designer implemented entirely in
V and UI2. It edits flat `Screen` documents that UI2 renders on macOS, Windows,
Linux, the BSDs, iOS, and Android, with fixed coordinates or opt-in adaptive
layouts.

Run it from the repository root:

```sh
v run ide
```

Pass a flat VML file (or a directory containing one) to open it immediately:

```sh
v run ide ide/sample.vml
```

The designer provides:

- a single-window Delphi-style workspace with the component palette across the
  top, the object tree above the inspector on the left, and document tabs below
  the central design/code surface;
- a component palette for labels, buttons, fields, text areas, checkboxes,
  dropdowns, rectangles, and images, with click-to-place and drag-to-form
  placement;
- a scaled WYSIWYG form with selection, drag, resize, arrow-key movement,
  grid display, and grid snapping;
- project and object trees plus a live property/event inspector whose editable
  rows support Tab and Shift+Tab traversal;
- an adaptive Layout inspector with parent pins, centering, stretching, size
  limits, visibility, and compact/regular width and height variations;
- phone, tablet, desktop, rotated, and custom-size previews that do not rewrite
  the saved design;
- undo/redo, duplicate, delete, and z-order commands;
- generated VML source with a source-to-designer apply workflow;
- an interactive preview and a messages/build pane;
- VML save/open, file drop, safe unsaved-change prompts, `main.v` scaffolding,
  and project checking through the installed V compiler.

The visual loader deliberately accepts only a flat `Screen` with plain numeric
coordinates and optional adaptive rules/`LayoutVariation` metadata. Dynamic
expressions, repeaters, and nested `Row`/`Column` layouts
remain editable in Source view, but are rejected by the designer instead of
being flattened or silently lost.

Saving a new form will not overwrite an existing VML file that was not opened
first. `Generate main.v` also leaves an existing companion file untouched.

See [Adaptive forms](ADAPTIVE_LAYOUT.md) for the workflow, VML format, and scope.
Try the sample with `v run ide ide/adaptive_sample.vml`.
