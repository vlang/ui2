# ui2

<img height="280" alt="image" src="https://github.com/user-attachments/assets/0fb17bf1-ba64-4d70-bba9-76e08069e009" />


`ui2` is a compact declarative UI module for V. It uses retained native controls
on macOS, iOS, and Windows and a custom immediate-mode `gg` renderer on Linux
and Android.

The Linux backend draws and handles widgets directly through `gg`/Sokol; it has
no GTK dependency.

macOS and Windows use native widgets by default. Pass the compile-time define
`-d ui2_custom_rendering` to use the same custom `gg` renderer there instead:

```sh
v -d ui2_custom_rendering run examples/users/main.v
```

## Requirements

`ui2` needs V 0.5.2 or newer. The module is split across `ui/`, `appkit/`,
`uikit/`, `windows/`, and `linux/` through the `subdirs` field of `v.mod`, and
older compilers ignore that field. Run `v up` if `import ui2` fails.

To use `ui2` from a project outside this repository, link the clone into
`~/.vmodules`:

```sh
ln -s "$(pwd)" ~/.vmodules/ui2
```

## State and identity

- `Element.id` identifies a mounted control for `text`, `set_text`, `focus`, and
  other lookup APIs.
- `Element.key` identifies a child during reconciliation. Keys must be unique
  among siblings; IDs must be unique in the tree. Renderers validate both before
  changing native state.
- `Element.action_id` identifies the emitted action and falls back to `id`.
  QML `on_tap` and `on_change` populate `action_id` without replacing `id`.

Text inputs use controlled-on-change semantics: changing the declared `text`
applies that value, while a refresh with the same declaration preserves the
current native/local edit, selection, focus, and (on native controls) input
method composition. Use `set_text` for an explicit imperative replacement.

## Typed QML models

`run_qml[T]` parses the document once, owns a model for the window, and exposes
its public fields as `app`:

```v
ui2.run_qml[App](
    source: $embed_file('app.qml').to_string()
    model: App{}
    title: 'My app'
    width: 780
    height: 420
)!
```

Ordinary properties are one-way expressions. `bind.text` and `bind.checked`
write control edits back to a public mutable top-level model field. Public model
methods with no arguments, one `int`, or one `string` argument can be used as
actions:

```qml
TextField { bind.text: app.name }
Button {
    text: "Add"
    enabled: app.users.len < app.max_users
    on_tap: app.add_user()
}
```

On macOS, set `native: true` on a `Button` (or wrap a V-built button with
`with_native_style`) to let AppKit own its bezel, font, hover, and pressed
appearance. Its declared colors remain the fallback for the custom renderer.

Action arguments are evaluated when the event is dispatched, after any two-way
binding on that event has written the control value into the model.

Expressions support property paths, arithmetic, comparisons, boolean operators,
conditionals, parentheses, and string interpolation. They are side-effect-free;
calls are restricted to event handlers. Unknown model paths, non-writable
binding targets, and invalid action signatures fail document loading.
Validation traverses every expression branch and repeater item schema without
executing expressions against the model's initial values.

Use a keyed `Repeater` for model collections. `item` and `index` are scoped to
each instance, and the evaluated key becomes `Element.key` for reconciliation:

```qml
Repeater {
    model: app.users
    key: item.id

    Label { text: "${item.name}" }
}
```

## Backend capabilities

Call `control_support(kind)` to query support. macOS implements every shared
control kind. iOS implements every kind, with text areas reported as `partial`
because rich runs are currently rendered as plain text. Linux, Android, and
opt-in custom desktop builds implement every kind through custom rendering;
dropdowns and text areas are `partial` because the dropdown list is drawn by
the renderer instead of a native menu and rich text-area runs are rendered as
plain text.

A button marked `native` asks the platform for the standard bezel and hands it
the interaction styling. AppKit and Win32 supply theirs; the custom renderer
draws one, including a pressed shade while the pointer is held on it, so the
button does not come out as a bare caption. A button the application gave its
own background keeps it, since the platform styling stops where the
application's own begins.

Images load from `image_path` on every backend. The custom renderer caches
decoded images. Scroll viewports clip both drawing and hit testing.

The Windows backend uses retained Win32 `BUTTON`, `EDIT`, `COMBOBOX`, `STATIC`,
and custom container windows. Its image control currently loads BMP files and
its text area is plain-text, so those two controls report `partial` support.

Shared state includes `hidden`, `enabled`, `accessibility_role`,
`accessibility_label`, and `accessibility_value`. Native backends expose these
through AppKit/UIKit. Standard Windows controls expose their native name and
value; explicit Windows accessibility overrides are not yet implemented.
`autocorrect` and `padding_left` configure applicable mobile text inputs.

## Message boxes

`message_box(...)` shows the operating system's own modal alert and blocks until
the user answers it:

```v
choice := ui2.message_box(
	title:   'Save changes?'
	text:    'The document has unsaved edits.'
	style:   .question
	buttons: .yes_no_cancel
)
```

`title` is the short heading and `text` the body. macOS renders them as an
`NSAlert` message and informative text, Windows as a `MessageBoxW` caption and
body, and Linux as the desktop's own `zenity` or `kdialog` dialog — `kdialog`
first under KDE and Plasma. iOS presents a `UIAlertController` and pumps the run
loop so the call stays synchronous like the desktop backends. `alert(title,
text)` and `confirm(title, text)` wrap the two common cases.

Android has no alert this layer can drive without a JVM callback, so
`message_box_supported()` returns `false` there and `message_box` answers as if
the dialog had been dismissed. Dismissal always reports the non-destructive
result: `cancel` where the button set has one, otherwise `no`, or `ok` for a
single-button alert.

`custom_message_box(...)` is the separate, hand-drawn alternative: a dimmed
overlay with a rounded card that stays inside the window and never blocks. Flip
its `hidden` field from the button events instead of reading a return value. It
is also available from QML as `MessageBox`, whose `Button` children become the
card's actions:

```qml
MessageBox {
    id: overlay
    hidden: !app.visible
    title: "Hello World"
    text: "This message came from the ui example."

    Button { id: close_message text: "OK" on_tap: app.close_message() }
}
```

## Layout and text offsets

The QML layer provides fixed frames plus `Row` and `Column` layout. Child frames
are parent-local. It does not implement intrinsic sizing, flex/grid, wrapping,
or min/max constraints; applications can compute frames before constructing an
element tree.

A label, button, checkbox, or dropdown whose text is wider than its frame ends
in an ellipsis rather than running over whatever is beside it: the native
backends hand their cells `NSLineBreakByTruncatingTail`, and the custom
renderer shortens the line itself. Text fields and text areas are the
exception, since they place the caret by measuring the whole string.

`TextEditor` positions are Unicode rune offsets. Native text-area selection APIs
use UTF-16 code-unit offsets. This is intentional; grapheme-cluster editing is
outside the portable editor's current contract.

## Fonts and text sizes

`TextStyle.size` is in points. Win32 and the Linux desktops resolve a point at
96 dpi, AppKit and UIKit at 72, so the custom renderer follows whichever
platform it draws on and a declared size matches the native controls beside it.
The default size of 15 is therefore a 20 px em square on Linux and Windows, and
15 px on macOS and iOS.

The custom renderer draws through fontstash, which sizes a glyph by its
ascender-to-descender height rather than by the em square. `ui2` reads
`unitsPerEm` and the `hhea` metrics out of the font file and converts, so the
declared size means the same thing no matter which face is loaded.

The renderer picks the font itself instead of taking the first face `fc-match`
reports, which varies by distribution. `ui2` ships Roboto and Roboto Mono in
`assets/fonts/`, so every custom-rendered window draws the same faces on every
platform. Nothing has to be installed for that to work while the module is on
the build machine; to ship a binary elsewhere, copy `assets/fonts/` next to it
or put the files in a `fonts/` directory beside it.

Failing all of those, the renderer looks for Inter, Roboto, Noto Sans, Open
Sans, DejaVu Sans, Liberation Sans, Ubuntu, Cantarell, FreeSans, and Arial among
the installed fonts, in that order, and settles for any upright sans face.

`UI2_FONT` and `UI2_FONT_BOLD` override everything and take file paths, which is
the quickest way to compare faces:

```sh
UI2_FONT=/usr/share/fonts/truetype/roboto/Roboto-Regular.ttf ./users
```

Use static font files, not variable ones. `stb_truetype`, the rasterizer
fontstash builds with, ignores the `fvar` and `gvar` tables, so a variable font
draws every weight at its default instance and bold text stops being bold. The
renderer skips variable files (`Roboto[wdth,wght].ttf`, `*-VariableFont*.ttf`)
when choosing a default for that reason.

`TextStyle.font_family` names a family. The native backends hand the name to the
platform's font manager; the custom renderer resolves it against the same font
directories and ignores it when the machine has no such face.

A family that names a fixed-pitch face is the exception: dropping to the
proportional default would lose the column alignment it was asked for. So
`monospace`, `Consolas`, `Courier New`, `Menlo`, and anything ending in `Mono`
fall back through Roboto Mono, JetBrains Mono, DejaVu Sans Mono, Liberation
Mono, Noto Sans Mono, Ubuntu Mono, Cascadia Mono, Consolas, Menlo, and Courier
New. The bundled Roboto Mono means that list always resolves.

### Symbols

A text face carries the letters of the scripts it was cut for and little else.
Roboto has 927 code points, so the triangles, arrows and check marks an
interface labels its rows with are not in it, and fontstash draws a code point
it cannot find as glyph 0 — the empty box, or tofu.

`ui2` therefore ships Noto Sans Symbols 2 in `assets/fonts/` as well, and hands
it to fontstash as a fallback for every face it loads. Fontstash searches the
chain whenever a glyph lookup lands on that empty box, so a label mixing letters
and symbols is still drawn in one pass and measured exactly the way it is drawn;
`TextStyle.font_family` faces get the same chain.

Noto Sans Symbols 2 covers the geometric shapes, dingbats, box elements and
braille. Behind it the renderer adds one symbol face off the machine — Noto Sans
Symbols, Segoe UI Symbol, Apple Symbols, Symbola, or the widest text face it
finds — which is what covers the blocks Noto Sans Symbols 2 leaves out, the
arrows at U+2190 and the box drawing at U+2500 among them. Only one is loaded,
since every face in the chain stays in memory for as long as the window does.

Emoji are not covered. They need a color font, and `stb_truetype` rasterizes
outlines only.

`UI2_FONT_SYMBOLS` takes a file path and is searched ahead of the bundled face:

```sh
UI2_FONT_SYMBOLS=/usr/share/fonts/truetype/ancient-scripts/Symbola.ttf ./treeview
```

## Examples

Typed-QML ports from `v-ui` include:

- `v run examples/counter/main.v` — the 7GUIs counter.
- `v run examples/temperature_converter/main.v` — the two-way 7GUIs
  temperature converter.
- `v run examples/flight_booker/main.v` — the validated 7GUIs flight booker.
- `v run examples/dropdown/main.v` — a dropdown with selection feedback.
- `v run examples/switch/main.v` — a boolean switch represented by the
  portable checkbox control.
- `v run examples/crud/main.v` — create, filter, update, and delete people.
- `v run examples/rgb_color/main.v` — validate RGB components and preview the
  resulting color.
- `v run examples/group/main.v` — grouped text fields, checkboxes, and form
  validation.
- `v run examples/rectangles/main.v` — the original four-color rectangle row.
- `v run examples/textbox/main.v` — editable and read-only multiline text
  areas with live character counts.
- `v run examples/box_layout/main.v` — fixed, relative, nested, and
  window-anchored rectangles.
- `v run examples/dynamic_layout/main.v` — add, remove, reorder, hide, and
  rename controls through a keyed repeater.
- `v run examples/grid/main.v` — the original compact three-column data grid.
- `v run examples/label_justify/main.v` — left, center, and right label
  alignment plus single-line clipping.
- `v run examples/message/main.v` — compare the system alert from
  `message_box` with the hand-drawn in-window dialog.
- `v run examples/demo_label/main.v` — the original minimal centered-label
  demonstration.
- `v run examples/group2/main.v` — two responsive groups with text fields,
  a checkbox, native buttons, and validation feedback.
- `v run examples/logview/main.v` — append scan batches to a read-only log.
- `v run examples/nested_scrollview/main.v` — scroll a list of independently
  scrollable multiline text areas.
- `v run examples/scrollview/main.v` — two independently scrollable read-only
  text panes with generated content.
- `v run examples/box_layout_with_textbox/main.v` — fixed and proportional box
  layout with an editable multiline text area.
- `v run examples/files_dropped/main.v` — collect dropped files and plain text
  in a keyed, scrollable list.
- `v run examples/nested_scrollview_box_layout/main.v` — a scrollable 5×5 box
  layout of independently editable multiline areas.
- `v run examples/demo_radio/main.v` — exclusive country choices that switch
  between compact horizontal and vertical layouts.
- `v run examples/demo_style_4colors/main.v` — select four-color palettes and
  preview them across portable and native controls.
- `v run examples/box_layout_inside_row/main.v` — proportional box layout
  inside an inset row, with switchable text-area bounds.
- `v run examples/rectangles_resizable/main.v` — four rounded color boxes that
  share the available width as the window resizes.
- `v run examples/accordion/main.v` — collapsible component pages with one
  active section at a time.
- `v run examples/tabs/main.v` — three keyed pages selected through a native
  tab-style button bar.
- `v run examples/double_listbox/main.v` — transfer keyed values between two
  scrollable lists and inspect the result.
- `v run examples/treeview/main.v` — expand nested folders and select files in
  a keyed, scrollable tree.
- `v run examples/dirbrowser/main.v` — browse and choose folders from the local
  filesystem.
- `v run examples/fontchooser/main.v` — apply font family, size, color, and
  emphasis choices to an editable preview.
- `v run examples/rasterview/main.v` — show a bundled bitmap in a responsive
  image frame.
- `v run examples/resizable_menu_window/main.v` — resize a native context-menu
  control between compact and stretched layouts.
- `v run examples/filebrowser/main.v` — browse folders, select files, and
  confirm or cancel the current selection.
- `v run examples/splitpanel/main.v` — adjust nested responsive panes around
  editable text and a scrollable data grid.
- `v run examples/row_layout/main.v` — experiment with row proportions,
  margins, spacing, and control height.
- `v run examples/demo_event/main.v` — inspect normalized pointer and keyboard
  events in a live event log.
- `v run examples/demo_chunkview/main.v` — compose nested styled text chunks
  and toggle their visibility and alignment.
- `v run examples/cells/main.v` — edit a compact spreadsheet and recalculate
  dependent `sum` formulas.
- `v run examples/circle_drawer/main.v` — add and resize circles with
  selection-aware undo and redo.
- `v run examples/gg2048/main.v` — play a deterministic, responsive version
  of the 2048 tile game.
- `v run examples/editor/main.v` — browse, create, edit, and save text files
  from a responsive editor.
- `v run examples/calculate/main.v` — evaluate arithmetic expressions with
  precedence, unary operators, and parentheses.
- `v run examples/timer/main.v` — run, pause, resume, and restart a timer with
  a draggable duration control.
- `v run examples/slider_textbox/main.v` — keep horizontal and vertical slider
  values synchronized with validated text fields.
- `v run examples/transitions/main.v` — animate a movable tile between canvas
  targets with cubic easing.
- `v run examples/gradient_texture/main.v` — generate an interactive HSV
  gradient from keyed color tiles.
- `v run examples/change_title/main.v` — validate a title and update the native
  desktop window caption.
- `v run examples/nested_clipping/main.v` — toggle a scroll viewport per box, or
  per quadrant, and watch the unclipped bars spill over their neighbours.
- `v run examples/canvas_layout/main.v` — drag a themed tile across a sheet that
  is taller than its viewport, and read live canvas coordinates.
- `v run examples/grid2/main.v` — sort a scrollable data grid of text, factor,
  and boolean columns, then edit the selected record.
- `v run examples/colorbox/main.v` — pick a color from a hue strip and an HSV
  square, store it in a slot, and drive a rectangle's text with it.
- `v run examples/child_window/main.v` — open a movable child panel with its own
  field, checkbox, and native greeting dialog.
- `v run examples/accent_color/main.v` — drag three channels into an accent and
  derive a shade, a tint, and a readable font color from it.
- `v run examples/text_style/main.v` — apply a family found in this machine's
  font trees, at a chosen size and emphasis, to an editable sample.
- `v run examples/canvas_layout_inside_row/main.v` — drag a rotatable logo
  across two panes and read its position in each pane's own coordinates.
- `v run examples/calculator_resizable/main.v` — a calculator whose keys, type,
  and spacing are all fractions of the window.
- `v run examples/users_box_layout/main.v` — a fixed registration column, with a
  progress bar and country choices, beside a table pane anchored to the window.

Run the calculator demo with:

```sh
v run examples/calculator/main.v
```

It ports the `v-ui` calculator to typed QML: the display reads from the model,
a keyed `Repeater` builds the keypad, and button actions call the calculator's
business logic directly. It includes decimal input, sign and percentage
controls, exponentiation, repeated equals, and division-by-zero recovery.

Run the responsive users demo with:

```sh
v run examples/users/main.v
```

It ports the native-widget users example from `v-ui`. The complete screen is
declared in `examples/users/users.qml` and embedded once with `$embed_file`; V only
contains the typed model and business actions. The example includes validated
text entry, password masking, country selection, toggles, a progress indicator,
and a keyed, scrollable user table.

### Android

Build Android examples on a Linux, macOS, or Windows development computer with
[V Android Bootstrapper (`vab`)](https://github.com/vlang/vab). It requires V,
a Java JDK, the Android SDK, and the Android NDK; Android Studio itself is not
required. Install `vab` on macOS or Linux with:

```sh
v install vab
v ~/.vmodules/vab
export PATH="$HOME/.vmodules/vab:$PATH"
vab doctor
```

See the `vab` installation guide linked above for Windows setup and environment
variables if the SDK or NDK is not detected. Then, from the `ui2` repository
root, build an APK for an example:

```sh
mkdir -p build/android
vab --name "ui2 counter" --package-id io.vlang.ui2.counter \
  -o build/android/counter.apk examples/counter
```

Replace `counter` in the source path, output name, application name, and package
ID to build another example. Use a different package ID for each example if you
want several of them installed at the same time. The default build includes all
supported Android CPU architectures.

Install the resulting APK on a connected device or emulator with:

```sh
adb install -r build/android/counter.apk
```

After installation, open **ui2 counter** from the device's app launcher.

Alternatively, let `vab` build, install, and launch the example in one step:

```sh
vab run --device auto --name "ui2 counter" \
  --package-id io.vlang.ui2.counter examples/counter
```

## Verification

Run `make test` for portable and host-native tests. `make examples` compiles
every example under `examples/` for the host platform and reports all failures
at once; `make examples-custom` repeats that with the custom `gg` renderer.
GitHub Actions runs `make examples` on Linux, macOS, and Windows, plus
`make examples-custom` on macOS and Windows, for every push and pull request.
`make check-macos`,
`make check-ios`, `make check-android`, `make check-linux`, and
`make check-windows` type-check each renderer; cross-target checks require their
normal platform SDK/toolchain. `make check-custom` additionally type-checks the
opt-in custom macOS and Windows builds.

`make screenshot EXAMPLE=<name>` renders one example and writes a single frame
to a PNG, so a layout can be checked without a person watching the window:

```sh
make screenshot EXAMPLE=message
v run examples/screenshot_example.vsh message --frame 30 --out shots
```

It drives gg's own recorder rather than a desktop screenshot utility, so it
needs no screen recording permission and captures the window alone. The
recorder reads the presented framebuffer back, which only the GL backend
implements, so the script builds macOS examples against GL instead of Metal.
Text is a third wider at 96 dpi than it is on macOS, so a layout that only just
fits in a macOS screenshot still has to be checked on Linux or Windows.

The Windows backend also has an executable Wine smoke test. It creates every
native widget kind, reads text back from the Win32 controls, verifies text-area
selection, and closes itself with a non-zero exit status on failure:

```sh
smoke_dir="$(mktemp -d)"
v -enable-globals -os windows \
  -o "$smoke_dir/ui2-windows-smoke.exe" examples/windows_smoke/main.v
mingw_sysroot="$(x86_64-w64-mingw32-gcc -print-sysroot)"
mingw_runtime="$(find "$mingw_sysroot" -name libwinpthread-1.dll -type f -print -quit)"
test -n "$mingw_runtime" && cp "$mingw_runtime" "$smoke_dir/"
WINEARCH=win64 WINEPREFIX="$smoke_dir/prefix" \
  wine "$smoke_dir/ui2-windows-smoke.exe"
```

A successful run prints `UI2_WINE_SMOKE_OK`. The runtime DLL copy is required
by the default MinGW-w64 thread runtime; it should likewise be shipped beside
applications unless the final executable is linked without that dependency.

Native objects returned by `alloc` follow a +1 creation contract. Renderers
release that ownership after a retaining parent/property accepts the object and
remove observers, delegates, actions, menus, and pointer registries on unmount.

## License

MIT. See [LICENSE](LICENSE).
