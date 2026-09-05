# ui2

`ui2` is a compact declarative UI module for V. It uses retained native controls
on macOS, iOS, and Windows and an immediate-mode `gg` renderer on Android.

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

## Backend capabilities

Call `control_support(kind)` to query support. macOS implements every shared
control kind. iOS implements every kind, with text areas reported as `partial`
because rich runs are currently rendered as plain text. Android implements every
kind; dropdowns and text areas are also `partial` because dropdown presentation
is a compact cycling control and rich text-area runs are rendered as plain text.

Images load from `image_path` on every backend. Android caches decoded images.
Scroll viewports clip both drawing and hit testing.

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

Run the calculator demo with:

```sh
v run examples/calculator/main.v
```

It ports the `v-ui` calculator to `ui2`, including decimal input, sign and
percentage controls, exponentiation, repeated equals, and division-by-zero
recovery.

Run the responsive users demo with:

```sh
v -enable-globals run examples/users.v
```

It ports the native-widget users example from `v-ui`. The complete screen is
declared in `examples/users.qml`, embedded into the executable with
`$embed_file` (with V supplying dynamic state and table rows), and includes
validated text entry, password masking, country selection, toggles, a progress
indicator, and a scrollable user table.

## Verification

Run `make test` for portable and host-native tests. `make check-macos`,
`make check-ios`, `make check-android`, and `make check-windows` type-check each
renderer; cross-target checks require their normal platform SDK/toolchain.

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
