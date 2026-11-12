@[has_globals]
module ui2

$if ui2_headless ? {
	// The embedding renderer supplies its logical framebuffer bounds.
	pub fn bounds() Rect { return Rect{width: 1024, height: 768} }
	pub fn request_refresh() {}
	__global g_key_modifiers = KeyModifiers{}

	fn test_headless_queries_do_not_require_a_native_window() {
		assert monitor_refresh_rate() == 0
		env := stylesheet_query_env(false, 96)
		assert env.width == 1024
		assert env.height == 768
		assert env.insets == none
	}
}
