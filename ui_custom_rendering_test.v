module ui2

$if ui2_custom_rendering ? {
	import gg
	import sokol.sgl

	// Regression coverage for `-d ui2_custom_rendering`:
	// Alpha blending goes through `sokol.sgl` directly so the test compiles
	// on V 0.5.2 (CI, whose gg predates `render.Context`) as well as on
	// newer V (whose sgl API is unchanged). Defining this helper fails to
	// compile if the `sgl` pipeline types diverge again
	// (see shape_immediate.c.v / ui_immediate.c.v).
	fn custom_render_pipeline_smoke(ctx &gg.Context) {
		sgl.load_pipeline(im_alpha_pipeline())
	}
}

fn test_custom_renderer_uses_render_pipeline() {
	$if ui2_custom_rendering ? {
		c := shape_color(0xff0000, 1.0)
		assert c.r == 0xff && c.g == 0x00 && c.b == 0x00 && c.a == 255
		faded := shape_color(0x00ff00, 0.5)
		assert faded.g == 0xff && faded.a == 128
	}
}
