# Stylesheets (u2ss)

One stylesheet language for every ui2 backend, familiar to QSS and CSS users:
type, `#id` and `.class` selectors, `:hover`/`:disabled`-style states,
variables, and light/dark blocks. The sheet fills in what the V builders
leave at defaults; anything set inline in V always wins.

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

Run `examples/stylesheet_demo` for a live tour: global + scoped + DSL
rules, a light/dark toggle, and hover/disabled/checked states.

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

Type names are the element kinds (`Button`, `Label`, `View`, `Checkbox`,
`Dropdown`, `Text_field`, `Text_area`, `Scroll`, `Slider`,
`Switch_control`, `Toggle_button`, `Image`, `Opengl`, `Screen`),
case-insensitive. An unknown type simply never matches.

Specificity is `id > class/pseudo-class > type`; on ties the later rule
wins, and an inner scope beats an outer scope. There is no `!important`:
inline V props beat every rule, full stop.

## Pseudo-classes

Interaction: `:hover :pressed :focused :disabled :enabled :checked :selected`.
`:selected` matches a checked element or one whose `accessibility_value` is
`selected`. State ids match the element `id` or `action_id`.

Structural: `:first-child :last-child :nth-child(2|odd|even) :only-child :empty`.

Backend notes: the custom renderer tracks hover, press and focus. The
native backends track hover and focus on Windows and macOS, focus only on
iOS; `:pressed` works on the custom renderer only.

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

Colors reuse the theme grammar: `#rgb`, `#rrggbb`, `rgb()`/`hsl()`,
Tailwind names (`blue-600/50`, `white`, `transparent`) and
`linear-gradient(135deg, ...)`. Units are logical px: a bare number or a
`px` suffix; `em`/`%` lengths are rejected. Anything else warns as an
unknown property instead of failing the build.

## Variables and dark mode

```css
@accent: #2563eb;
--card-pad: 12px;
light { @bg: #ffffff; @ink: #172033; }
dark  { @bg: #172033; @ink: #f8fafc; }
Button { background: @bg; color: @ink; }
```

`light {}` values apply in light mode, `dark {}` in dark. Mode follows the
OS by default; `set_stylesheet_dark(true/false)` forces one
(`set_stylesheet_follow_system(true)` resumes), and `stylesheet_dark_mode()`
reports the active one.

## Scoping

```v
ui2.with_stylesheet(ui2.view('card', frame, box, children), card_sheet)
```

A scoped sheet applies to its subtree only and wins over the global sheet
on equal specificity. `ignore_stylesheet: true` opts one element out
(children still cascade). `with_classes(el, 'primary')` attaches classes.

## Authoring from V

```v
rule := ui2.style_rule('Button.primary:hover', {'background': '@primary'})!
sheet := ui2.stylesheet_from_rules([rule], {'@primary': '#2563eb'})
ui2.set_global_stylesheet(sheet)
```

String/`.u2ss` files (via `parse_stylesheet` / `load_stylesheet`) and the
DSL build the same rule list; the cascade cannot tell them apart.

## Lint

```v
notes := ui2.stylesheet_lint_source(src)!
assert !notes.has_errors()
```

Reports unknown properties, unknown variables and layout-owned properties
before the sheet ever reaches a build. Parse errors already carry
`line:col` positions.
