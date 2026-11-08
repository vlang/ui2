# Theme registry and gradient backgrounds

A port of GPUI Kit's
[Theme](https://github.com/longbridge/gpui-kit/blob/main/website/component/theme.md)
page: the `ThemeRegistry` of named theme sets with light and dark variants,
theme files in upstream's JSON format, switching themes and following the
system appearance, and gradient backgrounds in theme colors. The
implementation is in `ui/component_theme_registry.v` (modes, tokens,
variants, sets, the registry and the surface boxes),
`ui/component_theme_registry_parse.v` (color values, gradients, theme files,
the mapping onto `ComponentTheme`, writing files back),
`ui/component_theme_registry_builtin.v` (the bundled sets) and
`ui/component_theme_registry_system_*.v` (the system appearance per
platform). `examples/gpui_theme/main.v` is a theme studio: a picker of every
set with light, dark and system modes, a theme loaded from a JSON string, and
buttons, inputs, badges, tags, tabs, a table, progress, alerts, gradient cards
and the palette re-themed live. `ui/component_theme_registry_test.v` covers the
logic.

## Conventions

- **Themes are values.** Every component already takes a `ComponentTheme`;
  nothing here adds global state. A `ComponentThemeRegistry` is a value the
  application keeps in its state, next to the name of the set it shows and a
  `ComponentThemeMode` (`.light`, `.dark` or `.system`). Every build resolves
  the theme with `registry.resolve(name, mode)` and passes `variant.theme` to
  the components; switching is storing another name or mode and rebuilding.
- **Build the registry once.** `component_theme_registry()` parses the bundled
  theme files; call it at startup, not in the build function.
- **Sets, variants, tokens.** A `ComponentThemeSet` is one theme file: a name,
  author, url and its variants. A `ComponentThemeVariant` is one theme
  ("Solarized Light"): its mode, the `ComponentTheme` components take, the
  file's `radius`, `radius.lg` and `shadow`, and `tokens`, every color the file
  gave keyed as the file keys it (`tab_bar.background`, `chart.1`, ...).
  Tokens are how an application paints what the components do not cover.
- **The Default set is always there.** `ComponentThemeRegistry{}` holds only
  it; its variants are exactly `component_theme(false)` and
  `component_theme(true)`. A set registered as "Default" replaces it until
  removed. Unknown names resolve to it, so a stale saved name still shows a
  theme.
- **Errors.** A theme file that is not JSON, has no themes, or has a theme
  without a name or with a mode other than light or dark is an error. A color
  that does not parse only falls back; its key is listed in the variant's
  `ignored`.

## Usage

```v
import os
import ui2

struct App {
mut:
	registry ui2.ComponentThemeRegistry
	theme    string                 = 'Catppuccin'
	mode     ui2.ComponentThemeMode = .system
}

const app = &App{}

fn build() ui2.Element {
	variant := app.registry.resolve(app.theme, app.mode)
	theme := variant.theme
	return ui2.screen(theme.background, [
		ui2.view('page', ui2.rect(0, 0, 800, 600), variant.background_box(), [
			ui2.view('card', ui2.rect(24, 24, 360, 160), variant.card_box(10), [
				ui2.styled_button(id: 'save', frame: ui2.rect(16, 16, 96, 32),
					label: 'Save', variant: .primary, theme: theme) or { panic(err) },
			]),
		]),
	])
}

fn main() {
	mut state := unsafe { app }
	state.registry = ui2.component_theme_registry()
	// A theme file in GPUI Kit's format, read from disk or embedded.
	state.registry.load_json(os.read_file('themes/harbor.json') or { '' }) or {
		eprintln(err)
	}
	ui2.run_window('Themed', 800, 600, build, fn (event string) {})
}
```

Switching is the application's: `app.theme = 'Solarized'`, `app.mode = .dark`,
or `app.theme = app.registry.cycle(app.theme, 1)` for a next-theme command,
then `ui2.refresh()`. Persist `app.theme` and `app.mode.str()`;
`component_theme_mode_from_name` reads the mode back.

## Theme files

`component_theme_set_from_json(source)` and `registry.load_json(source)` read
upstream's format (the files in its `themes/` directory load unchanged):

```json
{
  "name": "Harbor",
  "author": "Docks",
  "url": "https://example.com/harbor",
  "themes": [
    {
      "name": "Harbor Light",
      "mode": "light",
      "radius": 4,
      "colors": {
        "background": "#f7fafc",
        "foreground": "slate-900",
        "primary.background": "linear-gradient(135deg, teal-600, cyan-600)",
        "muted.background": "rgb(241 245 249)",
        "border": "hsl(214, 32%, 91%)"
      }
    },
    { "name": "Harbor Dark", "mode": "dark", "colors": { "background": "#0b1416" } }
  ]
}
```

- `mode` is `light` (the default) or `dark`; `is_default` marks the variant a
  set shows for its mode, else the first one of that mode is shown.
  `set.with_variants(light_name, dark_name)` picks others (Catppuccin Frappe
  instead of Mocha). A set with one mode shows it in both: Tokyo Night stays
  dark in light mode, and `set.has_mode(false)` tells a picker so.
- A file holding a single theme object (`name`, `mode`, `colors`, no `themes`)
  loads as a set of one. A theme repeating an earlier one's name is skipped,
  as upstream skips it.
- `highlight` (syntax colors), `font.*` and `mono_font.*` are not read.
- `component_theme_set_json(set)` writes a set back in the same format, every
  token included, so a theme built or adjusted in code can be saved and
  loaded again. The example's "Copy as JSON" button uses it.

### Color values

`component_theme_token(value)` parses one value:

| Form | Examples |
| --- | --- |
| Hex | `#fff`, `#fff8`, `#2563eb`, `#2563eb80` |
| Tailwind palette (upstream's names) | `blue` (500), `blue-600`, `blue-600/50` (50% opacity), `neutral/20`, `black`, `white`, `transparent` |
| CSS rgb() | `rgb(37, 99, 235)`, `rgba(37, 99, 235, 0.5)`, `rgb(37 99 235 / 50%)`, `rgb(100%, 0%, 50%)` |
| CSS hsl() | `hsl(221, 83%, 53%)`, `hsla(221, 83%, 53%, 0.5)`, `hsl(221deg 83% 53% / 0.5)` |
| Gradient | `linear-gradient(135deg, #4f46e5, #06b6d4)`, `linear-gradient(to right, red-500 25%, blue-600 75%)`, `linear-gradient(#fff, #f8fafc)` |

GPUI Kit reads hex, palette names and two-stop gradients with a `deg` angle or
a `to` direction. The rgb()/hsl() functions, `turn`/`rad`/`grad` angles and
gradients of three or more stops are ui2 additions. Gradient angles follow
CSS (0 points up, the default runs to the bottom) and are converted to
`Gradient.angle` (0 runs left to right, 90 down); stops without a position
are spread evenly, as in CSS. `component_theme_palette_color(name, scale)`
returns a palette color.

### Mapping onto ComponentTheme

`ComponentTheme` has thirteen colors; the rest of a file stays in `tokens`.
Each field takes the first key the file sets:

| Field | Keys | When the file sets none of them |
| --- | --- | --- |
| `background` | `background` | The default theme's, for the mode |
| `foreground` | `foreground` | The default theme's |
| `muted` | `muted.background`, `secondary.background`, `accent.background` | 8% of the foreground over the background; the default's when the file keeps the default background and foreground |
| `muted_foreground` | `muted.foreground` | `muted` blended 70% toward the foreground, upstream's rule; the default's when `muted` and the foreground are the default's |
| `border` | `border`, `input.border` | 18% of the foreground over the background; the default's as for `muted` |
| `primary` | `primary.background`, `button.primary.background`, `base.blue` | The default's |
| `primary_foreground` | `primary.foreground`, `button.primary.foreground` | The default's with the default primary, else the theme background or foreground, whichever reads better on `primary` (upstream uses the foreground) |
| `success`, `warning`, `danger` | `<tone>.background`, then `base.green`, `base.yellow`, `base.red` | The default's |
| `success_foreground`, ... | `<tone>.foreground` | The default's with the default fill, else `primary_foreground`, upstream's rule |

- Translucent colors are flattened: the background over the default
  background, text over the fill it sits on, the rest over the background.
  Tokens keep their alpha.
- A gradient counts as its first stop, as upstream's `ThemeToken.color` does.
- A foreground below 2:1 contrast on its fill is replaced by the theme
  background or foreground, whichever reads better (black or white if
  neither reads). Components draw it as text on a solid fill, where pairs
  meant for tinted surfaces cannot be read: upstream's Default Dark gives
  red-600 text for a red-400 danger fill (1.7:1). Pairs from 2:1 up are kept,
  so Ayu Light keeps its white on light blue (2.3:1).
- After mapping, the thirteen keys behind the fields are added to `tokens`
  when the file left them out, so `variant.token('primary.background')`
  always answers.

## Gradient backgrounds

Theme colors may be gradients, as upstream's Gradient Backgrounds section
describes. Components keep solid colors: `ComponentTheme` fields are `u32`,
and the gradient's first stop stands in, exactly as upstream keeps
`cx.theme().button_primary` solid while `cx.theme().tokens.button_primary`
carries the gradient. Surfaces that opt in read the token:

```v
variant := registry.resolve(name, mode)
page := ui2.view('page', frame, variant.background_box(), children) // `background`
card := ui2.view('card', frame, variant.card_box(10), body) // group_box, popover, background
bar := ui2.view('bar', frame, variant.token_or('title_bar.background', variant.theme.muted).box(0), [])
hero := ui2.view('hero', frame, ui2.BoxStyle{
	gradient: variant.gradient('primary.background') or {
		ui2.component_theme_accent_gradient(variant.theme)
	}
	radius: 12
}, [])
```

- `ComponentThemeToken` is `color` (the color or the first stop), `opacity`
  and `gradient`. `token.box(radius)` is a `BoxStyle` filled with it (the
  gradient, or the color at its opacity); `token.over(bg)` is the opaque color
  it shows over bg; `token.css()` writes it back as a theme-file value.
- `variant.background_box()` fills a window background with the `background`
  token. `variant.card_box(radius)` is a raised card: `group_box.background`,
  else `popover.background`, else the background, with the theme border and
  the card shadow unless the file sets `"shadow": false`.
- `variant.color(key, fallback)` is a token as an opaque color,
  `variant.gradient(key)` its gradient, `variant.token_or(key, fallback)` the
  token or a solid fallback.
- `component_theme_accent_gradient(theme)` derives a left-to-right gradient
  from the primary color to a neighbouring hue, for a banner in a theme
  without a gradient token. Text on it reads in `primary_foreground`.
- A gradient button is a `button_view` filled with
  `variant.token_or('button.primary.background', theme.primary).box(6)`; the
  example has one. Native buttons keep solid fills (see `Gradient` in
  `ui/box_effects.v`).
- Aurora, among the bundled sets, has gradient buttons, bars, switches and
  progress; the example's embedded Sunset theme has a gradient window
  background, cards and primary color.

## System appearance

`system_appearance()` reports the OS setting as `.light`, `.dark` or
`.unknown`, and `registry.resolve(name, .system)` uses it (light while
unknown); `component_theme_mode_is_dark(mode, appearance)` is the pure rule.

| Platform | Source |
| --- | --- |
| macOS (AppKit and custom renderer) | `AppleInterfaceStyle` in the global defaults: "Dark" while dark, also when switching automatically |
| iOS | `UITraitCollection.currentTraitCollection.userInterfaceStyle` (iOS 13+) |
| Windows | `AppsUseLightTheme` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` |
| Linux and the BSDs | Only a `GTK_THEME` ending in `:dark` or `-dark`; otherwise unknown. The desktop color scheme lives in the XDG settings portal (`org.freedesktop.appearance`, D-Bus), which ui2 does not speak. |
| Android | Unknown |

No backend reports appearance changes, so an application following the
system re-reads it on rebuilds; the example rebuilds every two seconds with
`after` while its mode is System.

## Bundled sets

`component_theme_builtin_sets()` (and so `component_theme_registry()`), in
picker order after Default. The data is adapted from GPUI Kit's theme files at
revision `d4c56812` without their syntax highlighting; the palettes are their
authors'.

| Set | Variants | Source |
| --- | --- | --- |
| Default | Default Light, Default Dark | ui2's `component_theme(false/true)` |
| Neutral | Neutral Light, Neutral Dark | Upstream's own Default (`default-theme.json`, shadcn's neutral palette), renamed |
| Aurora | Aurora Light | `themes/aurora.json` (Longbridge), with gradients |
| Ayu | Ayu Light, Ayu Dark | `themes/ayu.json` (Zed Industries' Ayu) |
| Catppuccin | Catppuccin Latte, Catppuccin Mocha | `themes/catppuccin.json` (Frappe and Macchiato left out) |
| Gruvbox | Gruvbox Light, Gruvbox Dark | `themes/gruvbox.json` (Pavel Pertsev) |
| Solarized | Solarized Light, Solarized Dark | `themes/solarized.json` (Ethan Schoonover) |
| Tokyo Night | Tokyo Night | `themes/tokyonight.json` (Folke Lemaitre; Storm and Moon left out) |

Upstream ships twenty-one theme files; all of them (38 themes, with their
`highlight` sections) load with `load_json` without an ignored color.

## API

### Registry

| Function | Purpose |
| --- | --- |
| `component_theme_registry() ComponentThemeRegistry` | Default plus the bundled sets |
| `ComponentThemeRegistry{}` | Default only |
| `registry.register(set) !` | Add, or replace a set of the same name (ignoring case) |
| `registry.load_json(source) !ComponentThemeSet` | Parse a theme file and register it |
| `registry.remove(name) bool` | Drop a set |
| `registry.sets()`, `registry.names()` | Every set, Default first |
| `registry.find(name) ?ComponentThemeSet` | By set name or variant name ("Ayu Light"), ignoring case |
| `registry.variant(name, dark)`, `registry.theme(name, dark)` | The variant / `ComponentTheme` for a set and mode |
| `registry.resolve(name, mode) ComponentThemeVariant` | The same for a `ComponentThemeMode`, reading the system appearance for `.system` |
| `registry.cycle(name, delta) string` | The set name `delta` places on, wrapping |

### Sets and variants

| Function | Purpose |
| --- | --- |
| `component_theme_default_set()` | The Default set |
| `component_theme_builtin_sets()` | The bundled sets |
| `component_theme_set_from_json(source) !ComponentThemeSet` | Read a theme file |
| `component_theme_set_json(set) string` | Write one |
| `component_theme_variant(name, dark, colors map[string]string)` | A variant from a `colors` object |
| `component_theme_variant_of(name, theme)` | Wrap a `ComponentTheme` built in code |
| `set.variant(dark)`, `set.theme(dark)`, `set.has_mode(dark)`, `set.variant_named(name)`, `set.with_variants(light, dark) !` | Variant choice |
| `variant.token(key)`, `token_or(key, fallback)`, `color(key, fallback)`, `gradient(key)` | Tokens |
| `variant.background_box()`, `variant.card_box(radius)` | Surface boxes |

### Values, modes and appearance

| Function | Purpose |
| --- | --- |
| `component_theme_token(value) !ComponentThemeToken` | Parse a color or gradient |
| `token.has_gradient()`, `token.box(radius)`, `token.over(bg)`, `token.css()` | Use or write a token |
| `component_theme_palette_color(name, scale) ?u32` | Tailwind palette |
| `component_theme_accent_gradient(theme) Gradient` | A gradient derived from the primary color |
| `system_appearance() SystemAppearance` | The OS appearance |
| `component_theme_mode_is_dark(mode, appearance) bool` | Resolve a mode |
| `component_theme_mode_from_name(name) ?ComponentThemeMode` | `light`, `dark`, `system` (or `auto`) |

## GPUI Kit features

| GPUI Kit | ui2 |
| --- | --- |
| `ThemeRegistry` global with `themes()`, `sorted_themes()` | A `ComponentThemeRegistry` value; `sets()`/`names()` keep Default first and registration order |
| Themes looked up by a variant's name ("Ayu Light") | `find`, `variant` |
| `default_themes`, `is_default` | The Default set; `is_default` picks a set's variant for its mode |
| `load_themes_from_str` | `load_json` (a set replaces one of the same name; upstream keeps the first) |
| `watch_dir` (load and hot-reload a themes directory) | Omitted: `ui/` has no file watcher. Read the files and call `load_json`; re-read on a timer to reload. |
| `Theme::change(mode)`, `light_theme`/`dark_theme` | The application's name and mode; `with_variants` picks the light and dark variants |
| `sync_system_appearance` / `WindowAppearance` | `system_appearance()` and `.system`; no change notification, so poll |
| `ThemeConfig`: `name`, `mode`, `is_default`, `colors` | Read |
| `radius`, `radius.lg`, `shadow` | Read onto the variant; `card_box` honours `shadow`. Components keep their `component_metrics` radii, since `ComponentTheme` has no radius. |
| `font.size`, `font.family`, `mono_font.*` | Omitted: ui2 components size text from `ComponentSize`, and fonts are per `TextStyle` |
| `highlight` (syntax theme) | Omitted: no ui2 component takes a syntax theme yet |
| ~130 `ThemeColor` fields with fallbacks | Thirteen drive `ComponentTheme` (table above); every other key is kept as written in `tokens`, without upstream's fallback chain |
| Alpha caps on `list.active`, `table.active`, `selection` | Not applied: those tokens do not feed components, and are kept as written |
| Hex and Tailwind palette colors | Implemented, plus CSS rgb()/hsl() |
| Gradient tokens (`ThemeToken.color` + `.background`) | `ComponentThemeToken.color` + `.gradient`; more than two stops and more angle units accepted |
| Components rendering gradient tokens | Omitted for components: `ComponentTheme` is solid. Surfaces use `token.box`, `background_box`, `card_box`; gradient buttons are `button_view`s. |
| `SemanticThemeConfig` (radius, spacing, typography, shadow scales) | Omitted: ui2 has `component_metrics` per size instead |
| Bundled theme files | Seven sets bundled (above); the others load from JSON |

## Platform notes

- Native buttons, checkboxes and switches keep the platform look; AppKit's
  switch is gray while the window is inactive, as in screenshots.

## Verification

```sh
v test ui/component_theme_registry_test.v
v -d ui2_custom_rendering test ui/component_theme_registry_test.v
v run examples/gpui_theme/main.v
v -d ui2_custom_rendering run examples/gpui_theme/main.v
GPUI_THEME=Sunset GPUI_THEME_MODE=dark v run examples/gpui_theme/main.v
```
