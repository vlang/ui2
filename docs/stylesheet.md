# Styling with stylesheets (u2ss)

One stylesheet language for every ui2 backend, familiar to QSS and CSS
users and stricter than both: type, `#id` and `.class` selectors,
`:hover`/`:disabled`-style states, `@media` and `@container` queries,
variables, and light/dark blocks. The sheet fills in what the V builders
leave at defaults; anything set inline in V always wins. Parse errors carry
`line:col` positions; nothing fails silently at runtime.

```v
import ui2

const sheet = '
@accent: #2563eb;
light { @bg: #f1f5f9; @ink: #172033; }
dark  { @bg: #172033; @ink: #f8fafc; }

Button { background: @accent; color: white; border-radius: 6px; }
Button:hover { background: #1d4ed8; }
Button:disabled { opacity: 0.4; }
Label.title { font-size: 22px; font-weight: bold; }
'

fn main() {
	ui2.set_global_stylesheet(ui2.parse_stylesheet(sheet) or { panic(err) })
	ui2.run_window('Styled', 480, 320, build, handle)
}
```

Start with `examples/stylesheet_demo`, then `examples/stylesheet_gallery`
(the deep showcase), `examples/stylesheet_responsive` (layout in V, style
in the sheet) and `examples/stylesheet_theme` (accents times modes).

## The three layers

Styling resolves in a fixed order, weakest first:

1. **Theme tokens** (`ComponentTheme`, `ComponentThemeRegistry`) — the
   defaults every component already takes. See
   [theme.md](gpui-kit/theme.md).
2. **Stylesheets** — the global sheet, then ancestor `with_stylesheet`
   scopes from the outside in. Inner scopes win ties.
3. **Inline props** — `BoxStyle`/`TextStyle` literals in V. These always win;
   there is no `!important`.

A sheet declaration applies to a property only when the element leaves it at
its struct default (`bg: 0xffffff`, `color: 0x111111`, `size: 15.0`,
`radius: 0`, ...). The one caveat: explicitly writing a default value
(`bg: 0xffffff`) is indistinguishable from leaving it unset, and the sheet
will override it. Prefer leaving sheet-owned props unset.

## Selectors

| Form                     | Example                          |
| ------------------------ | -------------------------------- |
| Type                     | `Button`, `Label`, `View`        |
| Id                       | `Button#login`                   |
| Class                    | `Button.primary`, `.card`        |
| Universal                | `*`                              |
| Descendant               | `View.card Label.title`          |
| Child                    | `View > Button`                  |
| Group                    | `Button, Input { ... }`          |

Type names are the element kinds (`Screen`, `View`, `Label`, `Image`,
`Button`, `Checkbox`, `Dropdown`, `Text_field`, `Text_area`, `Scroll`,
`Slider`, `Switch_control`, `Toggle_button`, `Opengl`), case-insensitive.
An unknown type never matches — useful to know when a rule silently does
nothing: check the spelling against this list first.

Attach classes with `with_classes(el, 'primary')`, ids with the builder's
`id` argument. Specificity is `id > class/pseudo-class > type`, counted as
`ids × 1_000_000 + classes × 1_000 + types`; on ties the later rule wins,
an inner scope beats an outer scope, and several declarations of one
property in a single rule apply in source order.

```css
Button { background: red; }          /* (0,0,1) */
Button { background: green; }        /* same score, later: wins over red */
Button.primary { background: blue; } /* (0,1,1): beats both above */
```

Specificity outranks source order; order only breaks ties. A scoped sheet
with equal specificity beats the global one; an inline `bg:` beats the
whole cascade.

## Pseudo-classes

Interaction: `:hover :pressed :focused :disabled :enabled :checked
:selected`. `:selected` matches a checked element or one whose
`accessibility_value` is `selected`. State ids match the element `id` or
`action_id`, since backends track hover/press/focus chains by action id.

Structural: `:first-child :last-child :nth-child(2|odd|even) :only-child
:empty`. Positions count among siblings starting at 1.

Backend coverage differs, because native backends track different state:

| State                 | custom | Windows | macOS | iOS |
| --------------------- | ------ | ------- | ----- | --- |
| `:hover`              | yes    | yes     | yes   | —   |
| `:pressed`            | yes    | —       | —     | —   |
| `:focused`            | yes    | yes     | yes   | yes |
| `:disabled` etc.      | yes    | yes     | yes   | yes |

`:hover` needs `hoverable: true` on the element, otherwise no hover region
exists to match. Untracked states simply never match; they are not errors.

## Properties

| Property                                             | Maps to                                   |
| ---------------------------------------------------- | ----------------------------------------- |
| `background`, `background-color`, `background-gradient` | fill color or `linear-gradient(...)`    |
| `color`                                              | text color                                |
| `font-size` (`12px` / `12`)                          | text size                                 |
| `font-family`                                        | font family                               |
| `font-weight` (`bold` / `600` / `normal`)            | bold                                      |
| `font-style` (`italic` / `normal`)                   | italic                                    |
| `text-align` (`left` / `center` / `right`)           | alignment                                 |
| `text-decoration` (`underline` / `line-through` / `none`) | underline / strikethrough           |
| `border` (`1px solid red`), `border-width`, `border-color` | box border                          |
| `border-radius`                                      | corner radius                             |
| `opacity` (`0.5` / `50%`)                            | fill opacity                              |
| `box-shadow` (`<color> [blur] [x y] [spread]` / `none`) | drop shadow                             |
| `padding`, `margin`, `gap`                           | parsed, **not applied yet** (warns)       |

Unknown properties warn instead of failing the build. `opacity` outside
`0..1` clamps; garbage warns and keeps `1.0`.

## Values

**Colors** reuse the theme grammar: `#rgb`, `#rrggbb`, `#rrggbbaa`,
`rgb()`/`hsl()` in both comma and space forms, Tailwind palette names
(`blue`, `blue-600`, `blue-600/50`, `black`, `white`, `transparent`) and
`linear-gradient(135deg, #4f46e5, #06b6d4)` with `to <side>` directions.
Bare names are Tailwind's 500 shade — `red` is `0xef4444`, not `0xff0000`;
use hex when you mean exact. Translucent colors composite over the
background.

**Lengths** are logical pixels: a bare number or a `px` suffix. `em`, `%`
and other units are rejected with a position.

**Variables** start with `@` or `--` and substitute anywhere in a value,
including inside `linear-gradient(...)`:

```css
@accent: #2563eb;
--card-pad: 12px;
Button { background: @accent; }
Card { background: linear-gradient(135deg, @accent, #06b6d4); }
```

Unknown variables warn per element and skip the declaration. Variable
lookup runs innermost scope first, then outward, then global — a card can
override `@accent` for its subtree with its own `light {}`/`dark {}` vars.

**Theme blocks** scope variables by mode:

```css
light { @bg: #ffffff; @ink: #172033; }
dark  { @bg: #172033; @ink: #f8fafc; }
```

Only variables may appear inside; rules there are a parse error.

## Cascade and precedence

For one element, matching declarations order by (specificity, scope depth,
source order) and apply weakest-first, so the strongest writes last.
Inline props are read off the pre-cascade element and never overwritten.
A worked example:

```css
Button { background: red; }              /* specificity 1 */
View Button { background: blue; }        /* specificity 2: wins */
Button { background: green; }            /* same as first, but later: wins over red */
```

...resolves to green for a `Button` directly inside a `View` — wait, no:
`View Button` (specificity 2) beats both. Specificity outranks order; order
only breaks ties. A scoped sheet with the same specificity beats the global
one; an inline `bg:` beats everything.

## Scoping

```v
ui2.set_global_stylesheet(sheet) // whole window
ui2.with_stylesheet(ui2.view('card', frame, box, children), card_sheet)
ui2.with_classes(el, 'primary', 'large') // .primary.large matches
ui2.Element{ ...el ignore_stylesheet: true } // opt out (children still cascade)
```

`with_stylesheet` scopes a parsed sheet to that element's subtree. A scope
containing only `light {}`/`dark {}` variables still activates, so
theme-only scoped overrides work. `ignore_stylesheet` skips one element;
its children still cascade.

## Media queries

```css
@media (orientation: landscape) and (min-width: 700px) { ... }
@media (platform: windows), (platform: macos) { ... }
@media not (pointer: coarse) { ... }
@media (prefers-color-scheme: dark) { ... }
@media (min-resolution: 1.5dppx) { ... }
```

| Feature                | Values                                              |
| ---------------------- | --------------------------------------------------- |
| `orientation`          | `landscape`, `portrait` (from window aspect)        |
| `platform`             | `windows`, `macos`, `linux`, `ios`, `android`, …    |
| `pointer`              | `coarse` (mobile), `fine` (desktop)                 |
| `prefers-color-scheme` | `dark`, `light` (same source as `dark {}`)          |
| `min-/max-width/height`| window size in px                                   |
| `min-/max-resolution`  | device pixels, `Ndppx` or `Nx` (`1.5dppx`, `2x`)    |

Comma means OR, `and` means AND, `not` negates one query. Platform names
are matched openly — a typo never matches but is not an error; every other
feature validates values at parse time. Unknown resolution (no frame yet)
fails closed. Nesting accumulates: a rule in `@media A` containing
`@container B` needs both. Resizing rebuilds, so media rules re-evaluate
live with no extra wiring.

## Container queries

```css
@container (min-width: 400px) { .card-title { font-size: 20px; } }
@container sidebar (max-width: 300px) { Button { font-size: 12px; } }
@container sidebar { Button { border-radius: 0px; } }  /* ancestry only */
```

The unnamed query tests the parent element's frame; a named one tests the
nearest ancestor whose id or class matches. Only `min-/max-` `width`/`height`
conditions are allowed — sheets cannot change frames, so there is no layout
feedback loop. Combine with `@media` by nesting, and with the DSL via
`style_rule_guarded(sel, props, '(platform: windows)', 'card (min-width: 400px)')`.

## Dark mode and color schemes

Mode follows the OS by default. `set_stylesheet_dark(true/false)` forces
one (`set_stylesheet_follow_system(true)` resumes), `stylesheet_dark_mode()`
reports the active one, and `(prefers-color-scheme: dark)` in `@media`
reads the same source. `stylesheet_live_dpi()` reports the last frame's
pixel ratio for readouts. One builder-owned exception: `screen()` takes a
plain background color, so branch it on `stylesheet_dark_mode()` in V —
everything inside the screen comes from the sheet.

## Platform adaptation

`platform` queries restyle per OS without `#flag` forks in V: flatter
buttons on Windows, larger radii on iOS, denser type on Linux. For behavior
(not style) keep using `$if`. The `:pressed`/`:hover` gaps in the matrix
above mean press-feedback styling is custom-renderer-only; prefer `:hover`
plus `:focused` for cross-backend feedback.

## Authoring from V

```v
rule := ui2.style_rule('Button.primary:hover', {'background': '@primary'})!
guarded := ui2.style_rule_guarded('Label', {'color': 'white'},
	'(platform: tvos)', 'card (min-width: 400px)')!
sheet := ui2.stylesheet_from_rules([rule, guarded], {'@primary': '#2563eb'})
```

String/`.u2ss` files (via `parse_stylesheet` / `load_stylesheet`) and the
DSL build the same rule list; the cascade cannot tell them apart. Store the
parsed sheet in app state and re-apply on changes (`set_global_stylesheet`
+ `refresh()` when the window is already up; nothing needed before
`run_window`).

## Lint

```v
notes := ui2.stylesheet_lint_source(src)!
assert !notes.has_errors()
```

Reports unknown properties, unknown variables and layout-owned properties
before the sheet ever reaches a build.

## Dynamic sheets

The theme-studio pattern: parse once, keep the base sheet in state, swap
variables per interaction:

```v
mut vars := state.base_sheet.variables.clone()
vars['@accent'] = pairs[state.accent][0]
ui2.set_global_stylesheet(ui2.Stylesheet{ ...state.base_sheet, variables: vars })
ui2.refresh()
```

Mode switches only flip the dark flag (`set_stylesheet_dark` /
`set_stylesheet_follow_system`); the sheet itself is unchanged.

## Layout vs style

Sheets own box fills, text, borders, shadows, opacity. Frames, positions
and stacking stay in V: derive them from `ui2.bounds()` in the build
function (as `examples/stylesheet_responsive` does), and let media and
container queries style each layout. `padding`/`margin`/`gap` parse and
warn until layout reads them.

## Migration: inline styles to sheets

1. Move repeated `BoxStyle`/`TextStyle` literals into type rules first;
   keep one-offs inline — inline always wins, so nothing breaks mid-way.
2. Replace per-instance colors with `@variables`, then add `dark {}`.
3. Turn state branches (`if hovered ... else ...` in V) into pseudo-classes.
4. Turn bounds branches into `@media` rules where only style changes;
   keep frame math in V.
5. Run `stylesheet_lint_source` on every sheet in CI; fix unknowns.

## Troubleshooting

- **Sheet does nothing:** check the type name against the kind list
  (`Text_field`, not `Input`; `Switch_control`, not `Switch`), then check
  for an inline prop on the same property — inline always wins.
- **Wrong red:** bare names are Tailwind 500s. Use hex for exact colors.
- **`:hover` dead:** the element needs `hoverable: true`, and `:pressed`
  is custom-renderer-only.
- **Dark mode stuck:** programmatic `set_stylesheet_dark` needs no refresh
  when driven by an event (events rebuild); a bare call outside events
  needs an explicit `refresh()`.
- **Media stale:** media reads window state per build; anything that
  changes size outside events should `refresh()`.
- **`lights { }` parses as a rule:** type names starting with `light`/`dark`
  are not theme blocks (word boundary); unknown types never match.
- **`@mediax`:** the `@` prefix always starts a variable or query — check
  the keyword spelling; the error points at it.

## Non-goals (v1)

Layout selectors, animations/transitions, `!important`, and container units
(`cqw`). `refresh_element` (AppKit) bypasses the sheet: it reconciles a
caller-supplied subtree.
