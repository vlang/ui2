module ui2

// Theme registry: named theme sets, each with light and dark variants, as GPUI
// Kit's ThemeRegistry keeps them. Every variant carries the ComponentTheme the
// components take plus every color token its theme file gave, gradients
// included, so an application can paint surfaces the components do not cover.
//
// Nothing here is global. The application owns a ComponentThemeRegistry, the
// name of the set it shows and a ComponentThemeMode, and resolves the theme on
// every build: `registry.resolve(name, mode).theme`. Switching themes is
// storing another name or mode and rebuilding.
//
// Theme files are parsed in component_theme_registry_parse.v, the bundled sets
// live in component_theme_registry_builtin.v and the system appearance is read
// by the component_theme_registry_system_*.v files.

// ── Modes and the system appearance ─────────────────────────────────

// ComponentThemeMode picks a set's light or dark variant, or follows the
// operating system's appearance.
pub enum ComponentThemeMode {
	light
	dark
	system // The OS appearance where system_appearance can tell, light where it cannot.
}

// component_theme_mode_from_name reads a mode back from its name (`light`,
// `dark` or `system`), as an application stores it in its settings.
pub fn component_theme_mode_from_name(name string) ?ComponentThemeMode {
	return match name.trim_space().to_lower() {
		'light' { .light }
		'dark' { .dark }
		'system', 'auto' { .system }
		else { none }
	}
}

// SystemAppearance is the light or dark appearance the user chose for the
// operating system.
pub enum SystemAppearance {
	unknown // This platform does not say, or it could not be read.
	light
	dark
}

// system_appearance reports the operating system's appearance right now:
// macOS's Appearance setting, iOS's trait collection, Windows' app mode and,
// on Linux, a `:dark` GTK_THEME. Elsewhere it is unknown. It is cheap enough to
// call on every build; there is no change notification, so an application
// that follows the system rebuilds on a timer (see examples/gpui_theme).
pub fn system_appearance() SystemAppearance {
	return native_system_appearance()
}

// component_theme_mode_is_dark resolves a mode against the system appearance.
// The system mode is light while the appearance is unknown.
pub fn component_theme_mode_is_dark(mode ComponentThemeMode, system SystemAppearance) bool {
	return match mode {
		.light { false }
		.dark { true }
		.system { system == .dark }
	}
}

// ── Tokens ──────────────────────────────────────────────────────────

// ComponentThemeToken is one color value of a theme file: a solid color, or a
// linear gradient whose first stop stands in for it where only a solid color
// fits, as upstream's ThemeToken does.
pub struct ComponentThemeToken {
pub:
	color    u32 // 0xRRGGBB: the color, or a gradient's first stop.
	opacity  f64 = 1.0 // The color's alpha, from 0 to 1.
	gradient Gradient // Two or more stops when the value was a linear-gradient().
}

// has_gradient reports whether the token fills with a gradient.
pub fn (token ComponentThemeToken) has_gradient() bool {
	return token.gradient.stops.len >= 2
}

// over is the opaque color the token shows over background: its color (a
// gradient's first stop) composited at its opacity.
pub fn (token ComponentThemeToken) over(background u32) u32 {
	return color_over(token.color & 0xffffff, token.opacity, background)
}

// box is a BoxStyle filled with the token: its gradient when it has one,
// otherwise its color at its opacity. Add a border or shadow with `...`.
pub fn (token ComponentThemeToken) box(radius f64) BoxStyle {
	if token.has_gradient() {
		return BoxStyle{
			bg:       token.color & 0xffffff
			radius:   radius
			gradient: token.gradient
		}
	}
	opacity := color_alpha(token.opacity)
	return BoxStyle{
		bg:          token.color & 0xffffff
		radius:      radius
		transparent: opacity <= 0
		opacity:     opacity
	}
}

// ── Variants ────────────────────────────────────────────────────────

// ComponentThemeVariant is one theme of a set, such as "Solarized Light".
pub struct ComponentThemeVariant {
pub:
	name       string
	dark       bool
	theme      ComponentTheme // What every component takes.
	radius     f64  = 6    // The file's `radius`; components keep their component_metrics radii.
	radius_lg  f64  = 8    // The file's `radius.lg`, for dialogs and other large surfaces.
	shadow     bool = true // The file's `shadow`: false asks for flat controls and cards.
	is_default bool // The file marked it the set's default for its mode.
	// tokens holds every color the file gave, by its key ("tab_bar.background",
	// "chart.1", ...), plus the keys behind the ComponentTheme fields, which are
	// always present (see docs/gpui-kit/theme.md for the mapping).
	tokens map[string]ComponentThemeToken
	// ignored lists the color keys whose values did not parse; they fell back.
	ignored []string
}

// token returns the token the theme gives key.
pub fn (variant ComponentThemeVariant) token(key string) ?ComponentThemeToken {
	return variant.tokens[key] or { return none }
}

// token_or returns the token for key, or a solid fallback color when the theme
// has none.
pub fn (variant ComponentThemeVariant) token_or(key string, fallback u32) ComponentThemeToken {
	return variant.tokens[key] or {
		ComponentThemeToken{
			color: fallback & 0xffffff
		}
	}
}

// color is the opaque color of key over the theme background (a gradient's
// first stop), or fallback when the theme does not set key.
pub fn (variant ComponentThemeVariant) color(key string, fallback u32) u32 {
	token := variant.tokens[key] or { return fallback }
	return token.over(variant.theme.background)
}

// gradient returns key's gradient when the theme gives it one.
pub fn (variant ComponentThemeVariant) gradient(key string) ?Gradient {
	token := variant.tokens[key] or { return none }
	return if token.has_gradient() { token.gradient } else { none }
}

// background_box is the BoxStyle of the window background: the `background`
// token, a gradient when the theme gives one.
pub fn (variant ComponentThemeVariant) background_box() BoxStyle {
	return variant.token_or('background', variant.theme.background).box(0)
}

// card_box is the BoxStyle of a card or panel raised above the background:
// the `group_box.background` token, else `popover.background`, else the
// background, with the theme border and, unless the theme turns shadows off,
// the card shadow. A gradient token fills the card with its gradient.
pub fn (variant ComponentThemeVariant) card_box(radius f64) BoxStyle {
	mut token := variant.token_or('background', variant.theme.background)
	for key in ['group_box.background', 'popover.background'] {
		if found := variant.tokens[key] {
			token = found
			break
		}
	}
	return BoxStyle{
		...token.box(radius)
		border_color:  variant.theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
		shadow:        if variant.shadow { component_card_shadow() } else { BoxShadow{} }
	}
}

// component_theme_variant_of wraps a ComponentTheme built in code, such as the
// default theme with another primary color, as a variant: its tokens are the
// keys behind the ComponentTheme fields, and it is dark when its background is.
pub fn component_theme_variant_of(name string, theme ComponentTheme) ComponentThemeVariant {
	mut tokens := map[string]ComponentThemeToken{}
	theme_fill_tokens(mut tokens, theme)
	return ComponentThemeVariant{
		name:   name
		dark:   feedback_is_dark(theme)
		theme:  theme
		tokens: tokens
	}
}

// component_theme_accent_gradient runs left to right from the primary color to
// a neighbouring hue, for a highlighted card or banner in a theme that has no
// gradient token for it. Text on it reads in the primary foreground.
pub fn component_theme_accent_gradient(theme ComponentTheme) Gradient {
	start := color_from_rgba(theme.primary, 1)
	shifted := color_hsva(start.h + 40, start.s, start.v, 1).rgb()
	end := choice_mix(shifted, theme.background, 0.25)
	return linear_gradient(0, gradient_stop(theme.primary, 0), gradient_stop(end, 1))
}

// ── Sets ────────────────────────────────────────────────────────────

// ComponentThemeSet is a named family of themes, one theme file: usually a
// light and a dark variant, sometimes more (Catppuccin's four flavors) or a
// single mode (Tokyo Night is dark only).
pub struct ComponentThemeSet {
pub:
	name     string
	author   string
	url      string
	variants []ComponentThemeVariant
	// light_name and dark_name pick the variant variant() returns for each mode;
	// empty means the file's default for the mode, else its first one.
	light_name string
	dark_name  string
}

// has_mode reports whether the set has a variant of that mode.
pub fn (set ComponentThemeSet) has_mode(dark bool) bool {
	return set.variants.any(it.dark == dark)
}

// variant returns the set's variant for a mode. A set with only the other
// mode returns that, so a dark-only set stays dark in light mode; an empty set
// returns the default theme.
pub fn (set ComponentThemeSet) variant(dark bool) ComponentThemeVariant {
	preferred := if dark { set.dark_name } else { set.light_name }
	mut first := -1
	mut marked := -1
	for index, candidate in set.variants {
		if candidate.dark != dark {
			continue
		}
		if preferred.len > 0 && candidate.name.to_lower() == preferred.to_lower() {
			return candidate
		}
		if first < 0 {
			first = index
		}
		if marked < 0 && candidate.is_default {
			marked = index
		}
	}
	if marked >= 0 {
		return set.variants[marked]
	}
	if first >= 0 {
		return set.variants[first]
	}
	if set.variants.len > 0 {
		return set.variants[0]
	}
	return component_theme_default_set().variant(dark)
}

// theme is the ComponentTheme of the set's variant for a mode.
pub fn (set ComponentThemeSet) theme(dark bool) ComponentTheme {
	return set.variant(dark).theme
}

// variant_named finds a variant by its name, ignoring case.
pub fn (set ComponentThemeSet) variant_named(name string) ?ComponentThemeVariant {
	wanted := name.trim_space().to_lower()
	for candidate in set.variants {
		if candidate.name.to_lower() == wanted {
			return candidate
		}
	}
	return none
}

// with_variants returns the set showing other variants for each mode, such as
// Catppuccin Frappe instead of Mocha. An empty name keeps the mode's current
// choice; a name the set lacks for that mode is an error.
pub fn (set ComponentThemeSet) with_variants(light_name string, dark_name string) !ComponentThemeSet {
	set.check_variant(light_name, false)!
	set.check_variant(dark_name, true)!
	return ComponentThemeSet{
		...set
		light_name: if light_name.len > 0 { light_name } else { set.light_name }
		dark_name:  if dark_name.len > 0 { dark_name } else { set.dark_name }
	}
}

fn (set ComponentThemeSet) check_variant(name string, dark bool) ! {
	if name.len == 0 {
		return
	}
	found := set.variant_named(name) or {
		return error('theme set "${set.name}" has no variant "${name}"')
	}
	if found.dark != dark {
		mode := if dark { 'dark' } else { 'light' }
		return error('"${found.name}" is not a ${mode} theme')
	}
}

// component_theme_default_set is the "Default" set: component_theme(false) and
// component_theme(true), the themes every component uses when given none.
pub fn component_theme_default_set() ComponentThemeSet {
	return ComponentThemeSet{
		name:     'Default'
		author:   'ui2'
		variants: [
			ComponentThemeVariant{
				...component_theme_variant_of('Default Light', component_theme(false))
				is_default: true
			},
			ComponentThemeVariant{
				...component_theme_variant_of('Default Dark', component_theme(true))
				is_default: true
			},
		]
	}
}

// ── Registry ────────────────────────────────────────────────────────

// ComponentThemeRegistry holds theme sets by name. The Default set is always
// there, first, unless a set registered under its name replaces it. A
// ComponentThemeRegistry{} holds only the Default set; component_theme_registry()
// adds the bundled sets. It is a value the application keeps in its state.
pub struct ComponentThemeRegistry {
mut:
	sets []ComponentThemeSet
}

// component_theme_registry returns a registry with the Default set and the
// sets bundled with ui2 (see component_theme_builtin_sets). Build it once, not
// on every rebuild: the bundled sets are parsed from their theme files.
pub fn component_theme_registry() ComponentThemeRegistry {
	return ComponentThemeRegistry{
		sets: component_theme_builtin_sets()
	}
}

fn (registry ComponentThemeRegistry) index_of(name string) int {
	wanted := name.trim_space().to_lower()
	for index, set in registry.sets {
		if set.name.to_lower() == wanted {
			return index
		}
	}
	return -1
}

// sets lists every set, the Default set first and then in registration order.
pub fn (registry ComponentThemeRegistry) sets() []ComponentThemeSet {
	mut sets := []ComponentThemeSet{cap: registry.sets.len + 1}
	if registry.index_of('Default') < 0 {
		sets << component_theme_default_set()
	}
	sets << registry.sets
	return sets
}

// names lists the set names in the order sets() returns them.
pub fn (registry ComponentThemeRegistry) names() []string {
	return registry.sets().map(it.name)
}

// find returns a set by its name or by the name of one of its variants
// ("Ayu Light", as upstream looks themes up), ignoring case.
pub fn (registry ComponentThemeRegistry) find(name string) ?ComponentThemeSet {
	sets := registry.sets()
	wanted := name.trim_space().to_lower()
	for set in sets {
		if set.name.to_lower() == wanted {
			return set
		}
	}
	for set in sets {
		if _ := set.variant_named(wanted) {
			return set
		}
	}
	return none
}

// register adds a set, replacing any set of the same name (ignoring case),
// the Default set included. The set needs a name and at least one variant.
pub fn (mut registry ComponentThemeRegistry) register(set ComponentThemeSet) ! {
	if set.name.trim_space().len == 0 {
		return error('a theme set needs a name')
	}
	if set.variants.len == 0 {
		return error('theme set "${set.name}" has no themes')
	}
	index := registry.index_of(set.name)
	if index >= 0 {
		registry.sets[index] = set
	} else {
		registry.sets << set
	}
}

// load_json parses a theme file (see component_theme_set_from_json), registers
// the set and returns it.
pub fn (mut registry ComponentThemeRegistry) load_json(source string) !ComponentThemeSet {
	set := component_theme_set_from_json(source)!
	registry.register(set)!
	return set
}

// remove drops the set with that name and reports whether there was one.
// Removing the Default set's replacement brings the built-in Default back.
pub fn (mut registry ComponentThemeRegistry) remove(name string) bool {
	index := registry.index_of(name)
	if index < 0 {
		return false
	}
	registry.sets.delete(index)
	return true
}

// variant returns the theme for a set name and mode. A variant name of that
// mode ("Catppuccin Frappe" while dark) picks that variant; an unknown name
// falls back to the Default set, so a stale saved name still shows a theme.
pub fn (registry ComponentThemeRegistry) variant(name string, dark bool) ComponentThemeVariant {
	set := registry.find(name) or {
		fallback := registry.find('Default') or { component_theme_default_set() }
		return fallback.variant(dark)
	}
	if named := set.variant_named(name) {
		if named.dark == dark {
			return named
		}
	}
	return set.variant(dark)
}

// theme is the ComponentTheme for a set name and mode.
pub fn (registry ComponentThemeRegistry) theme(name string, dark bool) ComponentTheme {
	return registry.variant(name, dark).theme
}

// resolve is the theme to show for the application's choice of set and mode,
// reading the system appearance for the system mode.
pub fn (registry ComponentThemeRegistry) resolve(name string, mode ComponentThemeMode) ComponentThemeVariant {
	system := if mode == .system { system_appearance() } else { SystemAppearance.unknown }
	return registry.variant(name, component_theme_mode_is_dark(mode, system))
}

// cycle returns the set name `delta` places after name in names(), wrapping,
// for next/previous theme commands. An unknown name counts as the first.
pub fn (registry ComponentThemeRegistry) cycle(name string, delta int) string {
	names := registry.names()
	mut current := 0
	if set := registry.find(name) {
		current = names.index(set.name)
	}
	count := names.len
	return names[((current + delta) % count + count) % count]
}
