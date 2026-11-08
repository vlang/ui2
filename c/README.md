# C API

`ui2.h` is a standalone C99 header with C++ support. The shared library owns
the V runtime, renders through ui2's existing backend, and exports ordinary
C functions. Application code needs no V types, headers, compiler, or runtime
setup. V is needed to build the library once.

From the repository root:

```sh
make c-api       # build/c/libui2.dylib, libui2.so, or ui2.dll
make c-example   # build/c/counter (counter.exe on Windows)
make c-test      # compile and run the C ABI tests without opening a window
make c-smoke     # open a window, verify mounted controls, then quit
./build/c/counter
```

The build uses a C compiler and V with Boehm GC. `CC` selects the compiler
executable. Windows uses Clang and LLVM's `llvm-dlltool` to create an x64
import library for the example/tests. You can also invoke the portable build
script directly: `v run c/build.vsh example`. On macOS and Windows, choose the
custom renderer with `make c-example C_API_FLAGS='-d ui2_custom_rendering'`.
The initial C library supports desktop macOS, Linux, the BSDs, and Windows.

To compile your own application on macOS, Linux, or the BSDs:

```sh
cc -std=c99 app.c -Ic -Lbuild/c -lui2 \
  -Wl,-rpath,"$PWD/build/c" -o app
```

Ship the library beside your application and set the executable's runtime
search path for that location (`@loader_path` on macOS, `$ORIGIN` on Linux and
the BSDs).
Windows finds `ui2.dll` beside the executable; link against `build/c/ui2.lib`.
The library still needs the normal platform dependencies of the selected
backend, as described in the main README. No GTK is involved on Linux or the
BSDs.

## A small app

```c
#include "ui2.h"
#include <stdio.h>
#include <string.h>

static ui2_node *build(void *data) {
    char text[32];
    snprintf(text, sizeof text, "Count: %d", *(int *)data);
    ui2_node *root = ui2_screen(0xf4f6f8);
    ui2_add(root, ui2_label("count", text, 20, 16, 240, 30));
    ui2_add(root, ui2_button("increment", "Increment", 20, 56, 240, 40));
    return root;
}

static void event(void *data, const char *id) {
    if (strcmp(id, "increment") == 0) ++*(int *)data;
}

int main(void) {
    int count = 0;
    ui2_config config = {0};
    config.title = "Counter";
    config.width = 280;
    config.height = 120;
    config.build = build;
    config.event = event;
    config.user_data = &count;
    return ui2_run(&config) == 0 ? 0 : 1;
}
```

## Building and updating widgets

`build` returns a fresh screen tree whenever ui2 refreshes. It also runs once
before window creation to validate the initial tree. Keep it free of application
state changes: the custom renderer builds every frame. Handle user actions in
`event`; ui2 automatically requests a rebuild after event and keyboard callbacks.
`ui2_refresh` requests a rebuild after other state changes.

Use `ui2_create` for views, images, checkboxes, dropdowns, text fields, text areas,
sliders, switches, and toggle buttons. Frames use logical pixels relative to
the parent. `ui2_bounds` provides the content width/height, including during the
initial validation. IDs must be unique in the tree. Assign stable sibling keys
with `ui2_set_key` when inserting or reordering items.

Use the style defaults as a starting point, then change the fields you need:

```c
ui2_node *field = ui2_create(UI2_TEXT_FIELD, "name", 20, 20, 220, 36);
ui2_set_text(field, app->name);
ui2_set_placeholder(field, "Your name");
ui2_set_flags(field, UI2_EMIT_CHANGE);
ui2_text_style text = ui2_default_text_style();
text.size = 18;
ui2_set_text_style(field, &text);
ui2_add(root, field);

ui2_node *scroll = ui2_scroll("canvas", UI2_SCROLL_BOTH, 20, 70, 400, 250);
ui2_add(scroll, ui2_label("wide", "Wide content", 800, 500, 180, 24));
ui2_add(root, scroll);
```

Set dropdown items with `ui2_add_option`, checkbox/switch/toggle state with
`ui2_set_checked`, and slider range/value with `ui2_set_slider`. `ui2_set_flags`
replaces all flags; combine flags with `|`. `ui2_button` starts with `UI2_NATIVE`;
use `ui2_create(UI2_BUTTON, ...)` to start with application styling.

During an event, read live control state with `ui2_get_text`, `ui2_get_value`,
and `ui2_get_checked`, then store it in your model. `ui2_get_text` writes to a
caller-owned buffer and returns the required byte count **including the NUL**:

```c
size_t size = ui2_get_text("name", NULL, 0);
char *name = malloc(size);
ui2_get_text("name", name, size);
/* use name, then free(name) */
```

`ui2_update_text`, `ui2_update_value`, and `ui2_update_checked` change mounted
controls directly without emitting an event. Declare the new value in your model
too. With an unchanged declaration, ui2 preserves local edits, selection, and
focus across refreshes. `ui2_scroll_to(id, x, y)` and `ui2_get_scroll` work on both
axes; an axis excluded by the scroll mode stays at zero.

## Lifetime, errors, and language bindings

All input strings are NUL-terminated UTF-8 and copied immediately; NULL means
empty. Local character arrays and temporary FFI buffers are safe. Widget handles
belong to the current `build` call: do not save, free, or use them after it
returns. The library roots handles while a foreign runtime builds the tree,
then lets its collector reclaim them. Each child has exactly one parent.

Event, key, scroll, and error strings are borrowed. Copy callback strings if
you need them later. `ui2_last_error` is valid until the next API call/build.
`ui2_run` and `ui2_validate` return 0 on success or -1 on failure. Invalid initial
trees are rejected before a window opens. An invalid later build records an
error and retains the last valid tree; subsequent valid builds can recover.
Cycles, duplicate IDs/keys, invalid enums, and recursive run/validate calls are
reported as errors. Use `ui2_abi_version()` to check ABI compatibility (currently 1).

Call all UI APIs on the main thread and keep your callbacks and `user_data`
alive until `ui2_run` finishes. One window can run at a time. The native macOS
backend may terminate the process when its last window closes or `ui2_quit`
runs, following the existing V application's behavior.

For another language, declare the function and struct signatures from `ui2.h`
using its C FFI. Convenience constructors are header inlines; bindings use
`ui2_create` plus setters. There is a runnable example using only Python's
standard-library `ctypes`:

```sh
make c-api
python3 examples/counter_python/main.py
python3 examples/counter_python/main.py --validate
```

The C ABI uses opaque pointers, `int`, `uint32_t`, `double`, `size_t`, UTF-8
strings, and function pointers; it does not expose V strings or arrays.
