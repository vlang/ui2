# Styling with stylesheets (vss)

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
in the sheet), `examples/stylesheet_theme` (accents times modes) and
`examples/stylesheet_plugins` (every plugin hook on a live-reloaded sheet).

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

Nesting flattens child rules onto their parents at parse time, so the
cascade sees ordinary selectors:

```css
View.card {
	background: @surface;
	Label.card-title { font-size: 14px; font-weight: bold; }
	&:hover { border-color: @accent; }
	> Button { border-radius: 0px; }
}
```

`&` splices the parent in (merging when it carries its own type, id,
classes or states — only a leading `&` is supported); otherwise the child
descends, or is a direct child after `>`. Nesting composes with `@media`
and `@container`, which accumulate as usual.

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
`rgb()`/`hsl()` in comma and space forms, Tailwind palette names
(`blue`, `blue-600`, `blue-600/50`, `black`, `white`, `transparent`),
modern spaces (`lab()`, `lch()`, `oklab()`, `oklch()`, `hwb()`,
`gray()`, `color()` with `srgb`, `srgb-linear`, `display-p3`, `a98-rgb`,
`prophoto-rgb`, `rec2020`, `xyz`, `xyz-d50`, `xyz-d65`), and
`linear-gradient(135deg, #4f46e5, #06b6d4)` with `to <side>` directions.
Bare names are Tailwind's 500 shade — `red` is `0xef4444`, not `0xff0000`;
use hex when you mean exact. `color-mix(in srgb, C1 [p%], C2 [q%])` mixes
two colors in gamma-encoded sRGB, defaulting to an even split:

```css
Button.ghost:hover { background: color-mix(in srgb, @accent 12%, @surface); }
```

Relative colors derive from any other color, per channel:

```css
Button:hover { background: rgb(from @accent r g b / 80%); }
Label.muted { color: hsl(from var(--ink) h s 40%); }
```

`rgb()`/`hsl()`/`hwb()` take channels in their own space, `lab()`/`lch()`/
`oklab()`/`oklch()`/`gray()` likewise, and `color()` names its space
explicitly (`color(from red srgb r g b)`). Omitted trailing channels keep
the origin's values, so `rgb(from red r g b / 50%)` only changes alpha.
Channel math (`calc()`, `min()`, …) works on top of origin idents.

Translucent colors composite over the background.

**Lengths** are logical pixels by default: a bare number or a `px` suffix.
Viewport units resolve against the window — `vw`/`vh`/`vmin`/`vmax` and
their `sv-`/`lv-`/`dv-` small/large/dynamic variants, which coincide because
ui2 windows have no collapsing browser chrome. Container units resolve
against the query container (`cqw`/`cqh`/`cqmin`/`cqmax`); outside any
`@container` they use the parent frame, else the window. Percentages,
font-relative and dpi units are rejected: they need a layout or font
context the cascade does not have.

`env()` reads the display safe area, with an optional fallback:

```css
Bar { padding-top: env(safe-area-inset-top, 20px); }
```

`safe-area-inset-top/right/bottom/left` come from the platform (iOS
reports real insets; elsewhere the fallback — or zero — applies).

**Math** works anywhere a length is accepted: `calc()`, `min()`, `max()`,
`clamp()`, `round()` (plus `up`/`down`/`to-zero`), `mod()`, `rem()`,
`abs()`, `sign()`, `sqrt()`, `hypot()`, `pow()`, `exp()`, `log()`,
`sin()`, `cos()`, `tan()`, `asin()`, `acos()`, `atan()`, `atan2()`.
Angles use `deg`/`rad`/`grad`/`turn`:

```css
Label.hero { font-size: clamp(18px, 4vw, 32px); }
View.card { border-radius: max(4px, 1cqw + 2px); }
```

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

Custom properties (`--*`) live on rules and inherit down the tree, like
CSS. `var()` reads them with an optional fallback; unknown names without a
fallback warn and skip the declaration:

```css
View.card { --title-size: 18px; }
Label.card-title { font-size: var(--title-size, 14px); }
```

`var()` works anywhere a value goes — colors, lengths, gradients — and
nests (`var(--a, var(--b, 12px))`). `@name` and `--name` are different
variables; use one spelling consistently.

`light-dark()` picks a branch by the color scheme, as a lighter alternative
to full `light {}`/`dark {}` blocks for one-off values (top-level values
only — it does not nest inside other functions):

```css
Label.hint { color: light-dark(#64748b, #94a3b8); }
```

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
Button { background: red; }              /* (0,0,1) */
Button { background: green; }            /* same score, later: wins over red */
Button.primary { background: blue; }     /* (0,1,0): beats both above */
```

Specificity outranks source order; order only breaks ties. A scoped sheet
with equal specificity beats the global one; an inline `bg:` beats the
whole cascade.

Two implementation notes, both invisible unless you measure. Rules are
indexed by subject (kind, `#id`, `.class` buckets plus a universal one)
when the sheet is built, so each element attempts only the rules it can
match — sheets assembled by hand as `Stylesheet{...}` literals skip the
index and take the full scan instead. And a repeated property applies
once (its last resolved candidate) rather than once per override, except
`background*`, `text-decoration`, and layout-owned/unknown props, which
keep every application for their side effects and per-declaration
warnings. `ui/stylesheet_index_test.v` diffs the indexed cascade against
the full scan to pin this.

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

Two predefined looks ship in `ui/stylesheet_platform.v`, so common cases
need no hand-written `@media` blocks: `glass` (frosted cards and buttons
for macOS/iOS) and `material` (solid surfaces with elevation for Android).
`auto` gates each look behind its home platforms and leaves the rest
neutral; a concrete design applies everywhere — including on your dev
machine, which is also how you preview another platform's look:

```v
sheet := ui2.with_platform_design(my_sheet, .auto)!
ui2.set_global_stylesheet(sheet)
```

Presets append after the base rules, so they win equal-specificity ties
while builder-set properties still win over everything. Dark variants ride
on `(prefers-color-scheme: dark)` and follow `set_stylesheet_dark`.
Translucency rides on box opacity — there is no backdrop blur in v1.

## Stylesheets in VML

VML documents style themselves without leaving the file. A `Style { ... }`
block holds raw `.vss` source and becomes the scoped stylesheet of the node
carrying it; `class: "a b"` puts a node in stylesheet classes; `style:`
holds inline declarations for one node:

```vml
Screen {
    Style {
        Button.primary { background: #3478D4; color: white; border-radius: 7px; }
    }
    Button {
        id: increment
        class: primary
        text: "Count"
    }
}
```

Several `Style` blocks on one node merge in order. In-document sheets run
through the same cascade as builder trees when the document builds
(`element_from_vml` / `element_from_vnode`), including dark-mode and media
rules; the global sheet applies too when one is set. Individual VML props
(`background:`, `font_size:`) beat `style:` on the same property, and both
beat sheets, matching the inline-wins rule.

Limits: `Style` blocks take plain sheets — `@import` needs a file, so it
errors with a pointer to inline the sheet instead. Inline `style:` takes
plain values only (no sheet variables; custom properties belong in a
`Style` block) and resolves lengths against the node's own frame. The VML
runtime does not feed pointer interaction into the match env, so `:hover`
/ `:pressed` / `:focused` stay quiet there; state, structural, media, and
container queries all work.

## Styling components

Composite components tag their roots and styleable parts with classes, so
sheets can target them the same way they target builder-built trees. Type
selectors already match leaf components (`Text_field`, `Slider`,
`Switch_control`, …); the classes below cover composite innards that share
the generic `View`/`Label` kinds:

| Component      | Root class        | Part classes |
|----------------|-------------------|--------------|
| Slider         | `slider`          | `slider-track`, `slider-bar`, `slider-fill`, `slider-mark`, `slider-mark-label`, `slider-thumb`, `slider-bubble`, `slider-bubble-text` |
| Switch         | `switch`          | `switch-track`, `switch-thumb` |
| Checkbox       | `styled-checkbox` | `checkbox-indicator` |
| Checkbox group | `checkbox-group`  | `checkbox-option` (keeps `styled-checkbox`) |
| Radio          | `radio`           | `radio-indicator`, `radio-dot`, `radio-label`, `radio-description` |
| Radio group    | `radio-group`     | `radio-option` (plus the radio part classes inside) |
| Toggle         | `toggle`          | — |
| Button         | `styled-button`   | — |
| Stepper        | `stepper`         | `stepper-step`, `stepper-connector`, `stepper-indicator` |
| Rating         | `rating`          | `rating-star` |
| Select         | `select`          | `select-trigger`, `select-value`, `select-placeholder`, `select-chevron`, `select-clear` |
| Combobox       | `combobox`        | `combobox-field`, `combobox-icon`, `combobox-clear`, `combobox-toggle` |
| Picker rows    | —                 | `picker-option`, plus `selected` on the chosen row (select, combobox and command palette popups) |
| Linear progress| `linear-progress` | `linear-progress-track`, `linear-progress-indicator` |
| Dialog         | `dialog`          | `dialog-surface`, `dialog-icon`, `dialog-title`, `dialog-description`, `dialog-body`, `dialog-button`, `dialog-button-<primary\|danger\|ghost>`, `dialog-close` |
| Alert dialog   | `alert-dialog`    | everything `dialog` has |
| Sheet          | `sheet`           | `sheet-panel`, plus the `dialog-*` panel parts |
| Popover        | `popover`         | — |
| Tooltip        | `tooltip`         | `tooltip-surface` |
| Toolbar        | `toolbar`         | `toolbar-item` |
| Title bar      | `titlebar`        | `titlebar-item`, `titlebar-title`, `titlebar-window-button` |
| Status bar     | `statusbar`       | `statusbar-item` |
| Tab bar        | `tab-bar`         | `tab` (plus `selected` on the active tab), `tab-icon`, `tab-label`, `tab-badge`, `tab-close` |
| Badge          | `badge`           | `badge-text` |
| Avatar         | `avatar`          | `avatar-image`, `avatar-initials` |
| Tag            | `tag`             | `tag-text`, `tag-close` |
| Number input   | `number-input`    | `number-input-button`, `number-input-divider` (the text area answers to `Text_field`) |
| OTP input      | `otp-input`       | `otp-input-cell`, `otp-input-separator` (cells are `Text_field`s) |

```vss
.switch-track { border-color: #2563eb; border-width: 2px; }
.slider-fill { opacity: 0.75; }
.picker-option.selected { font-weight: bold; }
.tab.selected { border-color: #2563eb; }
```

Two rules of the road. First, builder-set fields still win: sheets can
only fill properties the builder left at their defaults, so theme-driven
fills (track backgrounds, thumb colors) stay put while borders,
box-shadows, opacity, radii and text where unset are all styleable, as are
descendant and state-qualified rules (`.dialog .slider-track`,
`Button:disabled`). Second, component state that lives in ids and
accessibility values (`:checked`, `:selected`) is not a pseudo-class —
match it with the `selected` classes above instead.

## Authoring from V

```v
rule := ui2.style_rule('Button.primary:hover', {'background': '@primary'})!
guarded := ui2.style_rule_guarded('Label', {'color': 'white'},
	'(platform: tvos)', 'card (min-width: 400px)')!
sheet := ui2.stylesheet_from_rules([rule, guarded], {'@primary': '#2563eb'})
```

String/`.vss` files (via `parse_stylesheet` / `load_stylesheet`) and the
DSL build the same rule list; the cascade cannot tell them apart. Store the
parsed sheet in app state and re-apply on changes (`set_global_stylesheet`
+ `refresh()` when the window is already up; nothing needed before
`run_window`).

Large sheets split across files with `@import "other.vss";` (or
`@import url(other.vss);`), resolved relative to the importing file.
Imports splice in place, depth-first, each file once — cycles terminate on
the second visit.

## Plugins

Plugins extend the engine the way Vite plugins extend a build: same
`register once, hook everywhere` shape, but compiled in — V has no runtime
module loading, so there are no remote or lazily-loaded plugins. Register
before parsing (unknown names fail fast without a plugin that claims them):

```v
ui2.register_style_plugin(ui2.StylePlugin{
	name:           'demo-kit'
	functions:      ['theme']
	eval_function:  theme_lookup
	at_rules:       ['supports']
	expand_at_rule: expand_supports
	pseudos:        ['--has-tooltip']
	match_pseudo:   has_tooltip
	transform:      debug_outlines
	lint:           no_red_literals
})
```

- **Custom value functions** (`functions` + `eval_function`): `theme(primary)`
  or `double(4px)`. The hook gets the raw inner text and the length context
  and returns a number (`StyleValue`) or color (`ComponentThemeToken`).
  Unknown functions without a plugin are parse errors.
- **Custom at-rules** (`at_rules` + `expand_at_rule`): `@supports (x) { ... }`
  receives the prelude and body as text and returns replacement source,
  which is parsed with the same enclosing `@media`/`@container` context.
  This is a parse-time macro: use it for scoping, static gating, or sugar.
- **Custom pseudo-classes** (`pseudos` + `match_pseudo`): `:--has-tooltip`
  and friends receive the element, its ancestors and the frame env.
  Unknown pseudo-classes without a plugin are parse errors, as before.
- **Custom media features** (`media_features` + `match_media`): gate rules
  on anything a boolean can express (`@media (brand: acme)`).
- **Transform** (`transform`): a per-element post pass after the cascade,
  run top-down so children see the transformed parent. It can only touch
  existing `Element` fields; `id` and `kind` are pinned to keep
  reconciliation and dispatch intact.
- **Lint** (`lint`): appends to `StylesheetLintNotes`. See
  `examples/stylesheet_plugins` for all six working together, including a
  file-backed sheet with `@import` and a Reload button that only rebuilds
  when `stylesheet_file_stamp` (the sheet's content plus its `@import`
  chain) changed.

A missing hook means that extension point stays stock: unclaimed names
error, unmatched pseudos/queries never match.

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
beyond lengths (`cqw` etc. work as values; container *queries* are the
`@container` rules above). `refresh_element` (AppKit) bypasses the sheet:
it reconciles a caller-supplied subtree, not a fresh build.

Deliberately unsupported CSS (the cascade parses values, it does not lay
out or paint): gradients other than `linear-gradient()` (no
`radial-`/`conic-gradient()` backends), `color-contrast()` and
`contrast-color()` (spec still churning; use `color-mix()` with white or
black instead), `palette-mix()` (no palette infra), `anchor()` /
`position-try` (no anchor positioning), filter functions (`blur()`,
`brightness()`, … — no filter stage), transform functions (`rotate()`,
`scale()`, `translate()` — transforms are animation targets, not style),
`image-set()` / `cross-fade()` (no image URLs in stylesheets), `attr()`
(no element-attribute bridge), counters, `sibling-index()` and `if()`
(use `@media`), and non-sRGB output gamuts (everything renders through
sRGB with clamping).
