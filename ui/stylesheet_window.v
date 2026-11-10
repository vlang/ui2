@[has_globals]
module ui2

// P2 window wiring: one process-wide global sheet plus the per-frame glue.
//
// The application owns the sheet: set it before run_window (or at any time
// and call refresh()), scope tighter rules with with_stylesheet on any View,
// and inline struct props always win. Backends call the build function
// through stylesheet_frame_build, feed live interaction state through
// stylesheet_frame_env, and call stylesheet_apply_frame on the result; both
// custom-rendered and native backends use the same cascade, so a sheet
// behaves identically on either.

__global g_stylesheet_global = Stylesheet{}
__global g_stylesheet_has_global = false
__global g_stylesheet_follow_system = true
__global g_stylesheet_force_dark = false
__global g_stylesheet_last_dpi = 1.0
__global g_stylesheet_frame_building = 0

// set_global_stylesheet installs the process-wide sheet. Call refresh()
// afterwards when the window is already up; before run_window nothing else
// is needed.
pub fn set_global_stylesheet(sheet Stylesheet) {
	g_stylesheet_global = sheet
	g_stylesheet_has_global = true
	g_style_prev_elements = map[string]Element{}
	g_style_prev_valid = false
	g_style_prev_anim_matches = map[string]bool{}
}

// clear_global_stylesheet removes the process-wide sheet. Call refresh()
// afterwards when the window is already up.
pub fn clear_global_stylesheet() {
	g_stylesheet_global = Stylesheet{}
	g_stylesheet_has_global = false
	g_style_prev_elements = map[string]Element{}
	g_style_prev_valid = false
	g_style_prev_anim_matches = map[string]bool{}
}

// set_stylesheet_follow_system resumes (or stops) tracking the operating
// system's appearance for stylesheet dark mode. It is on by default.
pub fn set_stylesheet_follow_system(follow bool) {
	g_stylesheet_follow_system = follow
}

// set_stylesheet_dark forces dark (or light) mode for the stylesheet and
// stops following the system; set_stylesheet_follow_system(true) resumes.
pub fn set_stylesheet_dark(dark bool) {
	g_stylesheet_force_dark = dark
	g_stylesheet_follow_system = false
}

// stylesheet_dark_mode reports the mode the cascade resolves theme variables
// with right now.
pub fn stylesheet_dark_mode() bool {
	if g_stylesheet_follow_system {
		return system_appearance() == .dark
	}
	return g_stylesheet_force_dark
}

// stylesheet_frame_env builds the frame's match environment from the live
// interaction state the backend passes in. Only ids are needed; dark mode
// comes from stylesheet_dark_mode.
pub fn stylesheet_frame_env(hovered string, pressed string, focused string) StyleMatchEnv {
	return StyleMatchEnv{
		hovered: hovered
		pressed: pressed
		focused: focused
		dark:    stylesheet_dark_mode()
	}
}

// stylesheet_frame_build calls a backend's build function and returns its
// tree unstyled. While it runs, trees built from VML skip their own
// cascade, since stylesheet_apply_frame styles the result once with the
// live interaction env.
pub fn stylesheet_frame_build(build BuildFn) Element {
	g_stylesheet_frame_building++
	built := build()
	g_stylesheet_frame_building--
	return built
}

// stylesheet_apply_frame runs the cascade over the built tree: the global
// sheet when one is set, and every Element.stylesheet scope regardless of
// which backend built the tree. Without either it returns the tree
// untouched, so unstyled applications pay one boolean check plus one
// allocation-free walk per build.
pub fn stylesheet_apply_frame(declared Element, env StyleMatchEnv) Element {
	if env.dpi > 0 {
		g_stylesheet_last_dpi = env.dpi
	}
	mut styled := declared
	if !g_stylesheet_has_global {
		if !element_has_scoped_stylesheet(declared) {
			styled = declared
		} else {
			styled = apply_stylesheet(declared, Stylesheet{}, env)
		}
	} else {
		styled = apply_stylesheet(declared, g_stylesheet_global, env)
	}
	// vss animation driver: detect property/state changes since the last
	// styled frame and start transitions / keyframes animations on the
	// animation runtime. The runtime overlays animated values at render time.
	style_animation_drive(styled)
	return styled
}

// stylesheet_live_dpi reports the device pixel ratio from the most recent
// styled frame, or 1.0 before the first one. Applications use it for
// readouts; the cascade itself reads the frame env.
pub fn stylesheet_live_dpi() f64 {
	if g_stylesheet_last_dpi <= 0 {
		return 1.0
	}
	return g_stylesheet_last_dpi
}
