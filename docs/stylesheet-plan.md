# ui2 Stylesheet Plan (`vss`)

Familiar to QSS + CSS users, better than both, typed for V.

Locked decisions (2026-11-09):
1. **Scope: both** — global per-`Window` + per-subtree `View{ stylesheet }`.
2. **Precedence: inline wins** — theme tokens → global sheet → ancestor scopes (outer→inner) → inline struct props.
3. **Pseudo-states: all** — interaction + structural.
4. **Authoring: both** — `string` / `.vss` files + V DSL building the same `StyleRule` list.

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
win.set_stylesheet(load_stylesheet('cards.vss')!)!

// DSL — compile-time checked, same StyleRule structs
win.set_stylesheet_rule(style_rule('Button.primary:hover', {'background': '@primary'})!)
view(id: 'cards', stylesheet: parse_stylesheet('Item { padding: 8px; }')!, ...)
```

Parser and DSL converge on `[]StyleRule`; cascade/matcher cannot tell
which authored them.

## 5. Phases

- **P0 (done, `75f17da`):** `stylesheet_parse.v` — selectors, declarations,
  variables, `light{}/dark{}` blocks, specificity, `file:line:col` errors + tests.
- **P1 (done, `84cc345`):** `stylesheet_match.v` + `stylesheet_cascade.v`,
  `classes` / `ignore_stylesheet` / `stylesheet` on `Element`,
  `apply_stylesheet()` (global + scoped), `stylesheet_dsl.v`.
- **P2 (done, this commit):** `stylesheet_window.v` (global sheet storage,
  dark follow/force, `stylesheet_frame_env` / `stylesheet_apply_frame`), live
  env hooks in the custom (`ui_immediate.c.v`) and native Windows
  (`windows/ui_windows.v`) build paths, `examples/stylesheet_demo`.
- **P3 (done):** AppKit/UIKit hooks (same pattern),
  `stylesheet_lint.v`, `docs/stylesheet.md` user guide, `background-gradient`
  alias + `border` shorthand polish.
- **P4 (done):** `@media` (orientation, platform, pointer,
  window size, resolution, color-scheme) + `@container` (ancestor sizes,
  optional names), `StyleQueryEnv`, per-backend `dpi` in the
  frame env, `style_rule_guarded` DSL, docs + demo rule.
- **P5 (done):** modern values — viewport units
  (`vw/vh/vmin/vmax` + `sv-/lv-/dv-`), container units (`cqw/cqh/cqmin/cqmax`),
  `env(safe-area-inset-*, fallback)` with per-backend insets, `calc()` family
  + trig, `color-mix(in srgb)`, selector nesting with `&`; `stylesheet_math.v`.
- **P6 (done):** CSS custom properties with inheritance,
  `var(--x, fallback)`, top-level `light-dark()`, full modern color
  (lab/lch/oklab/oklch/hwb/gray/color() + relative `from` syntax),
  docs + gallery var() showcase.
- **P7 (done, this commit):** Vite-style plugin system  (`ui/stylesheet_plugin.v`): custom value functions (number + color),
  custom at-rules (parse-time expansion), custom pseudo-classes, custom
  `@media` features, post-cascade transforms, lint rules, `@import` with
  cycle-safe file loading, mtime-based live-reload helpers,
  `examples/stylesheet_plugins`, docs + README updates.
- **P8 (done, this commit):** predefined per-platform designs
  (`ui/stylesheet_platform.v`): `glass` for macOS/iOS, `material` for
  Android, `auto` gating each behind `@media (platform: ...)` with dark
  variants on `(prefers-color-scheme: dark)`; concrete designs apply
  ungated on every platform. `with_platform_design` merges a base sheet
  with the preset, docs updated.
- **P9 (done, this commit):** stylesheets inside VML (`ui/vml_stylesheet.v`):
  `Style { ... }` raw-`.vss` blocks as scoped sheets on any node, `class:`
  props, inline `style:` declarations, and cascade application at the
  `element_from_vml` / `element_from_vnode` boundary (in-document sheets
  always, global sheet when set). `examples/counter/counter.vml` migrated
  as the showcase, docs updated.
- **P10 (done, this commit):** component stylesheet contract: roots and
  styleable parts of the interactive core carry classes (slider, switch,
  checkbox/radio (+groups), toggle, button, stepper, rating, select,
  combobox, picker rows, progress, dialog/alert/sheet, popover, tooltip,
  toolbar/titlebar/statusbar (+items), tab bar (+tabs), badge, avatar, tag,
  number/otp inputs) with `selected` state classes where the state is not
  a pseudo; leaf kinds keep matching by type. Builder-set fields still win
  over sheets; `ui/component_stylesheet_test.v` pins the contract.- Non-goals v1: layout selectors, animations/transitions,
  `!important`. `refresh_element` (AppKit) intentionally bypasses
  the sheet: it reconciles a caller-supplied subtree, not a fresh build.

## 6. Verification

- `v test ui/ -only stylesheet` + golden snapshots: stylesheet → resolved
  `BoxStyle`/`TextStyle`.
- Negative tests: bad property, bad unit, unknown pseudo → error, never silent.
- Example builds with `-cc tcc -no-retry-compilation` and clang;
  native + `-d ui2_custom_rendering`.
- `v fmt -w` on every touched V file, `v fmt -l` clean, full `git diff`
  review before commit (coreutils `testfmt` gate pattern).
