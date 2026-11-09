# ui2 Stylesheet Plan (`u2ss`)

Familiar to QSS + CSS users, better than both, typed for V.

Locked decisions (2026-11-09):
1. **Scope: both** — global per-`Window` + per-subtree `View{ stylesheet }`.
2. **Precedence: inline wins** — theme tokens → global sheet → ancestor scopes (outer→inner) → inline struct props.
3. **Pseudo-states: all** — interaction + structural.
4. **Authoring: both** — `string` / `.u2ss` files + V DSL building the same `StyleRule` list.

## 1. Syntax (v1)

```css
/* variables + theme-aware tokens */
@primary: #2563eb;
--card-pad: 12px;
light { @bg: #ffffff; @ink: #172033; }
dark  { @bg: #172033; @ink: #f8fafc; }

/* QSS-familiar selectors */
* { font-family: "Inter"; }
Button { background: @primary; border-radius: 6px; color: white; }
Button#login { padding: 12px; }
Button.primary:hover { background: @primary-hover; }
View.card > Label.title { font-size: 16px; font-weight: bold; }
Input:disabled, Button:disabled { opacity: 0.5; }
List > Item:first-child { border-top: 0; }
Item:nth-child(2) { background: @bg; }
Item:selected { background: @primary; }
```

Selectors v1: `Type`, `#id`, `.class`, `*`, descendant (`A B`), child (`A > B`),
groups (`A, B`), pseudo-states below. Specificity: `id > class/pseudo > type`,
later rule wins on tie. No `!important` in v1.

Pseudo-states v1:
- interaction: `:hover :pressed :focused :disabled :enabled :checked :selected`
- structural: `:first-child :last-child :nth-child(n) :only-child :empty`

Properties v1 (only what `BoxStyle` + `TextStyle` already draw):
- box: `background, background-gradient, border, border-color, border-width,`
  `border-radius, opacity, box-shadow`
- text: `color, font-size, font-family, font-weight, font-style,`
  `text-align, text-decoration`
- box-model: `padding, margin, gap` — applied only where layout supports it,
  otherwise lint warning (never silent, never hard error at resolve time).
- unknown property / bad unit / unknown pseudo = parse error with `file:line:col`.

Colors reuse `component_theme_token()` grammar: hex, `rgb()/hsl()`,
Tailwind names (`blue-600/50`), `linear-gradient(...)`. Units v1: `px`/bare
numbers only (logical units); `em/%` rejected with helpful error.

## 2. Architecture

New files (no rewrites, no renderer changes):

| File | Contents |
|---|---|
| `ui/stylesheet_parse.v` | tokenizer + parser → `Stylesheet{ rules, variables, light_vars, dark_vars }`. Pure, no backend deps. `parse_stylesheet(src) !Stylesheet`, `load_stylesheet(path) !Stylesheet`. |
| `ui/stylesheet_match.v` | selector matching vs `Element` + ancestor chain + child index. Needs `classes []string` (+ `ignore_stylesheet bool`) on `Element`. |
| `ui/stylesheet_cascade.v` | `resolve_stylesheet(...) → (BoxStyle, TextStyle)`; called once per build before layout. Native + custom renderers consume result unchanged. |
| `ui/stylesheet_dsl.v` | V builder DSL producing the same `StyleRule` structs (no parser). |
| `ui/stylesheet_*_test.v` | parser / matcher / cascade golden tests. |
| `examples/stylesheet_demo/` | buttons/inputs/cards + light/dark toggle + hot-reload. |
| `docs/stylesheet.md` | user docs (this plan is the build order, not the user doc). |

Token flow: `ComponentThemeRegistry` stays the token source; `@tokens`
resolve through it (light/dark aware). Stylesheet never forks theming.

`:selected` v1 maps to `checked || accessibility_value == 'selected'`
(`Element` has no `selected` field today); add a real field in P2 if the
mapping proves lossy.

## 3. Cascade (locked)

```
theme defaults → global Window sheet → ancestor View sheets (outer→inner) → inline props
```

- Inner scope beats outer scope on equal specificity.
- Inline struct props always win (no `!important` to override them).
- `Element{ ignore_stylesheet: true }` opts out (e.g. `native_style` buttons).

## 4. DSL sketch (same engine as strings)

```v
// strings / files — hot-reloadable
win.set_stylesheet(parse_stylesheet('@primary: #2563eb; Button { background: @primary; }')!)!
win.set_stylesheet(load_stylesheet('cards.u2ss')!)!

// DSL — compile-time checked, same StyleRule structs
win.set_stylesheet_rule(style_rule('Button.primary:hover', {'background': '@primary'})!)
view(id: 'cards', stylesheet: parse_stylesheet('Item { padding: 8px; }')!, ...)
```

Parser and DSL converge on `[]StyleRule`; cascade/matcher cannot tell
which authored them.

## 5. Phases

- **P0 (started):** `stylesheet_parse.v` — selectors, declarations, variables,
  `light{}/dark{}` blocks, specificity, `file:line:col` errors + tests.
- **P1:** `stylesheet_match.v` + `stylesheet_cascade.v`, `classes` /
  `ignore_stylesheet` on `Element`, `set_stylesheet()` (global + scoped).
- **P2:** state wiring (`hover/press/focus/disable/check/selected`) +
  structural pseudos (`first/last/nth/only/empty`) + `stylesheet_demo`.
- **P3:** `load_stylesheet()`, lint helper, `docs/stylesheet.md`, gradient /
  shadow shorthands polish.
- Non-goals v1: layout selectors, animations/transitions, `@media`,
  nesting, `!important`.

## 6. Verification

- `v test ui/ -only stylesheet` + golden snapshots: stylesheet → resolved
  `BoxStyle`/`TextStyle`.
- Negative tests: bad property, bad unit, unknown pseudo → error, never silent.
- Example builds with `-cc tcc -no-retry-compilation` and clang;
  native + `-d ui2_custom_rendering`.
- `v fmt -w` on every touched V file, `v fmt -l` clean, full `git diff`
  review before commit (coreutils `testfmt` gate pattern).
