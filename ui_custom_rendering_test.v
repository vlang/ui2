module ui2

$if ui2_custom_rendering ? {
	import gg

	// The adapter must accept gg's active renderer and its pipeline types.
	fn custom_render_pipeline_smoke(ctx &gg.Context) {
		im_load_alpha(ctx)
	}
}

fn test_custom_renderer_uses_render_pipeline() {
	$if ui2_custom_rendering ? {
		c := shape_color(0xff0000, 1.0)
		assert c.r == 0xff && c.g == 0x00 && c.b == 0x00 && c.a == 255
		faded := shape_color(0x00ff00, 0.5)
		assert faded.g == 0xff && faded.a == 128
		// Packed RGB ignores the high byte; shape opacity supplies alpha.
		packed := shape_color(0x80123456, 0.5)
		assert packed.r == 0x12 && packed.g == 0x34 && packed.b == 0x56 && packed.a == 128
	}
}
