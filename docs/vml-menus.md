# Menus in VML

`menu_bar_from_vml` loads a **standalone menu document** and returns `[]Menu`.
Install that declaration with the existing `set_menu_bar` API:

```v
menus := ui2.menu_bar_from_vml($embed_file('menus.vml').to_string())!
ui2.set_menu_bar(menus)
```

The document may contain one `Menu`, or a `MenuBar` containing several menus:

```qml
MenuBar {
    Menu {
        title: "File"
        MenuItem { id: file_new text: "New" shortcut: "cmd+n" }
        MenuItem { text: "Open" on_tap: file_open shortcut: "cmd+o" }
        MenuSeparator {}
        MenuItem { id: file_revert text: "Revert" enabled: false }
        Menu {
            title: "Export"
            MenuItem { id: export_pdf text: "PDF" }
        }
    }
    Menu {
        title: "View"
        MenuItem { id: word_wrap text: "Word Wrap" checked: true }
    }
}
```

A menu and its rows accept `title` or `text`; `title` takes precedence when both
are present. A leaf `MenuItem` emits its `on_tap` action id, falling back to `id`
when `on_tap` is absent. The id reaches the event handler passed to `run_window`,
just like an ordinary menu declared in V. Quote ids containing dots, for example
`on_tap: "file.open"`.

A nested `Menu` is a submenu. A `MenuItem` with children is also a submenu and
must not emit an action itself. `MenuSeparator {}` and
`MenuItem { separator: true }` declare a separator. Separators cannot carry
an action, title, shortcut, checked/disabled state, or child rows.

`checked` defaults to `false`; `enabled` defaults to `true`. Check marks are
**declarations, not automatic toggles**. Handle the action in V and install a new
menu declaration to change its state. Shortcuts use the same syntax and platform
behavior as `menu_item_with_shortcut`: `cmd` means Command on macOS and Control
on Windows/Linux.

For repeated updates, parse the source once with `parse_vml`, change the relevant
node's `props` in V, and call `menu_bar_from_vnode` followed by `set_menu_bar`.
Both conversion functions validate the menu and are side-effect-free. Neither
changes the input tree nor installs native UI. An empty `MenuBar {}` returns an
empty list, which can be passed to `set_menu_bar` to clear the declared menus.

## Scope

This loader uses **literal values and action ids**. It rejects app expressions,
method calls, assignments, interpolation, two-way bindings, and property
declarations rather than silently treating them as strings. Unknown properties,
unexpected child tags, invalid booleans, missing titles/actions, duplicate action
ids, and submenus that also emit an action are errors.

Keep this file separate from the visual `Screen` document. This API does **not**
add application-menu nodes to `run_vml`, `VmlApp`, `element_from_vml`, or the
compiler's `$vml` lowering. Existing flat `MenuItem` context menus on visual
widgets are unchanged. The existing native/custom menu backends and mobile
capability checks are also unchanged.

Run the complete example from the repository root:

```sh
v run examples/vml_menu
```

Run the focused tests:

```sh
  v test vml_menu_test.v
```
