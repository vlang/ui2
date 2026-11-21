# Embedding UI2 controls

UI2 can mount its ordinary elements in an application's existing window. The
application owns its element tree, actions and document renderer; UI2 owns native
controls, reconciliation, editing and normalized input delivery.

On macOS, pass the host NSView to `mount_embedded_browser(parent, elements,
handler)`, update the tree with `update_embedded_browser(elements)`, and release
it with `unmount_embedded_browser()`. Uncovered regions continue receiving the
host's native input. Auxiliary settings roots and panels have independent
reconciliation lifetimes. `embedded_controls_version` identifies this API.

`select_embedded_textbox(id)` focuses and selects a named editor.
`select_embedded_text_range(id, start, end)` uses rune offsets with an exclusive
end; AppKit's UTF-16 offsets are converted internally. Readonly fields support
selection and copying while rejecting text mutations. `embedded_text_composing`
reports an active input-method composition so a host can defer text replacement.

For the custom renderer, `draw_embedded_elements` draws into an existing GG
context and borrows the host's image IDs. Call it inside the host's render pass;
prepare image textures before that pass. `embedded_elements_event` returns
whether UI2 consumed an event so uncovered content retains its input routing.

Elements also support a `VectorPath` decoration and an explicit
`button_image_size`. Vector coordinates are local to the element; closed filled
contours are triangulated by the custom renderer and drawn by a shape layer on
AppKit. Button icons keep their logical size regardless of the source bitmap's
resolution.
