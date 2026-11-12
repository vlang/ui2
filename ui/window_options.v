module ui2

// RefreshMode selects how often the custom renderer rebuilds and presents:
// continuous redraws every vsync, on_demand only between explicit asks, and
// manual suppresses the frame callback between explicit asks, like on_demand
// did before the frame scheduler took over: refresh and request_refresh wake
// the loop for exactly one coalesced frame, deadlines and running animations
// wake their own continuation, and nothing else draws — no per-vsync present,
// no keep-alive redraw.
pub enum RefreshMode {
	continuous
	on_demand
	manual
}

// WindowOptions carries the window creation knobs run_window_with_options
// accepts on top of what run_window takes positionally. gl_load scopes which
// EGL vendor libraries glvnd may load before the window's GL context
// initializes (Linux only; see GlLoad), and UI2_GL_VENDOR overrides it
// without a recompile.
pub struct WindowOptions {
pub:
	title      string
	width      int
	height     int
	min_width  int
	min_height int
	// sample_count is Sokol's antialiasing level for the window's framebuffer.
	// Flat immediate-mode geometry gains nothing visible from 4x, and weak GPUs
	// pay the fill rate for it; 1 turns antialiasing off.
	sample_count int         = 4
	refresh      RefreshMode = .on_demand
	gl_load      GlLoad      = .auto
	// background keeps the window's frames running while the window is
	// hidden — iconified, minimized, or parked on another workspace — instead
	// of suspending the frame coordinator. Nothing is presented while hidden;
	// the frames exist so the application keeps its own machinery fed: a
	// custom renderer whose surface is drained inside the frame (a video
	// player's mpv render call, say) must keep consuming frames, or the
	// source stalls and playback stops the moment the window is hidden.
	// Windows that only show UI pay nothing for this — leave it off and a
	// hidden window suspends, as before.
	background bool
}
