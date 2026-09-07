# UI2 Studio

<img width="400" alt="image" src="https://github.com/user-attachments/assets/db98f044-b0a3-4f93-8ba8-d9ae39cb1ee4" />


`ide/` is a Delphi/Lazarus-style visual form designer implemented entirely in
V and UI2. It edits the fixed-coordinate `Screen` documents that UI2 renders on
macOS, Windows, Linux, iOS, and Android.

Run it from the repository root:

```sh
v run ide
```

Pass a flat, fixed-coordinate QML file (or a directory containing one) to open
it immediately:

```sh
v run ide ide/sample.qml
```

The designer provides:

- a single-window Delphi-style workspace with the component palette across the
  top, the object tree above the inspector on the left, and document tabs below
  the central design/code surface;
- a component palette for labels, buttons, fields, text areas, checkboxes,
  dropdowns, rectangles, and images;
- a scaled WYSIWYG form with selection, drag, resize, arrow-key movement,
  grid display, and grid snapping;
- project and object trees plus a live property/event inspector;
- undo/redo, duplicate, delete, and z-order commands;
- generated QML source with a source-to-designer apply workflow;
- an interactive preview and a messages/build pane;
- QML save/open, file drop, safe unsaved-change prompts, `main.v` scaffolding,
  and project checking through the installed V compiler.

The visual loader deliberately accepts only a flat `Screen` with plain numeric
coordinates. Dynamic expressions, repeaters, and nested `Row`/`Column` layouts
remain editable in Source view, but are rejected by the designer instead of
being flattened or silently lost.

Saving a new form will not overwrite an existing QML file that was not opened
first. `Generate main.v` also leaves an existing companion file untouched.
