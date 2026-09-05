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

Five additional typed-QML ports from `v-ui` are available:

- `v run examples/counter/main.v` — the 7GUIs counter.
- `v run examples/temperature_converter/main.v` — the two-way 7GUIs
  temperature converter.
- `v run examples/flight_booker/main.v` — the validated 7GUIs flight booker.
- `v run examples/dropdown/main.v` — a dropdown with selection feedback.
- `v run examples/switch/main.v` — a boolean switch represented by the
  portable checkbox control.

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

## Verification

Run `make test` for portable and host-native tests. `make check-macos`,
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
