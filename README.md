# ui2

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
dropdowns and text areas are `partial` because dropdown presentation is a
compact cycling control and rich text-area runs are rendered as plain text.

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

## Layout and text offsets

The QML layer provides fixed frames plus `Row` and `Column` layout. Child frames
are parent-local. It does not implement intrinsic sizing, flex/grid, wrapping,
or min/max constraints; applications can compute frames before constructing an
element tree.

`TextEditor` positions are Unicode rune offsets. Native text-area selection APIs
use UTF-16 code-unit offsets. This is intentional; grapheme-cluster editing is
outside the portable editor's current contract.

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
- `v run examples/message/main.v` — the original Hello World message as a
  portable in-window dialog.
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
