module ui2

fn test_color_channel_extracts_srgb_channels() {
	assert color_channel(0x102030, 16) == 0x10
	assert color_channel(0x102030, 8) == 0x20
	assert color_channel(0x102030, 0) == 0x30
}

fn test_color_mix_endpoints_and_midpoint() {
	assert color_mix(0x000000, 0xffffff, 0) == 0x000000
	assert color_mix(0x000000, 0xffffff, 1) == 0xffffff
	assert color_mix(0x000000, 0xffffff, 0.5) == 0x808080
	assert color_mix(0x102030, 0x102030, 0.3) == 0x102030
}

fn test_color_mix_clamps_overshooting_ranges() {
	assert color_mix(0x000000, 0xffffff, 7) == 0xffffff
	assert color_mix(0xffffff, 0x000000, 7) == 0x000000
}

fn test_color_tint_moves_toward_white() {
	assert color_tint(0x000000, 1.0) == 0xffffff
	assert color_tint(0x102030, 0) == 0x102030
	assert color_tint(0x000000, 0.5) == 0x808080
}
