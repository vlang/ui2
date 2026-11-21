# ui2 DOM renderer

A small, framework-free DOM renderer for ui2's `Element` tree. It is shipped as
`renderer.js` and embedded into the V server at compile time, so a browser gets
the whole app from one binary and no Node/npm/TypeScript toolchain is needed at
run time.

The file is authored as type-checked JavaScript (`// @ts-check`, JSDoc types).
To type-check it during development:

```sh
cd web/renderer && npx --yes typescript tsc -p tsconfig.json
```

## Wire contract

| Direction | Message |
|---|---|
| server → client | `{ type: 'snapshot', seq, title, width, height, dpr, root }` |
| server → client | `{ type: 'patch', seq, ops }` |
| server → client | `{ type: 'error', message }` |
| client → server | `{ type, id, action, value, x, y, dx, dy, key, code, shift?, ctrl?, alt?, cmd?, token }` |

`id` addresses the element's state on the server; `action` is `action_id` (or
`id` when unset) and is what the server turns into the desktop `EventFn`
string. Scalar-only patches update a node in place (typing and scroll survive);
structural patches (`replace_children`) re-render the tree. See
`docs/web-backend.md` for the full Element → DOM mapping and event strings.
