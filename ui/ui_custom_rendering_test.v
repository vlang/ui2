module ui2

$if ui2_custom_rendering ? {
	import gg

	// Regression coverage for `-d ui2_custom_rendering`:
	// `ctx.pipeline` holds `render.Pipeline`, so alpha blending must go
	// through `ctx.r` (the pure-V `gg/render` context), not `sokol.sgl`.
	// Defining this helper fails to compile if the `sgl`/`render` pipeline
	// types diverge again (see shape_immediate.c.v / ui_immediate.c.v).
	fn custom_render_pipeline_smoke(ctx &gg.Context) {
		ctx.r.load_pipeline(ctx.pipeline.alpha)
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
