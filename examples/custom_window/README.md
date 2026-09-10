# Custom window

This example keeps the interface in ui2 while replacing the native desktop
frame with a small platform adapter:

```sh
v run examples/custom_window
```

- macOS changes ui2's `NSWindow` to a borderless, non-opaque window and gives
  the root `Screen` a transparent background.
- Windows changes ui2's `HWND` to a borderless layered window and color-keys
  the otherwise unused `#010203` screen background.
- Linux and opt-in custom-rendered desktop builds show the same layout in a
  normal window as a portable fallback.

The header is an ordinary draggable ui2 `Rectangle`. Its pointer-down event is
handed to `performWindowDragWithEvent:` or `WM_NCLBUTTONDOWN`, so the operating
system still performs the move. The close button calls `ui2.quit()`. Everything
else—including the separated rounded surfaces and the clear space between
them—is declared in [`custom_window.qml`](custom_window.qml).

For a resizable custom frame, keep the same pattern and add narrow draggable
ui2 regions at the edges, routing them to the platform's native resize action.
