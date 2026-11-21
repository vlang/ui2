module ui2

fn test_adaptive_parent_pins_centers_and_stretch() {
	design := rect(20, 30, 100, 50)
	available := rect(70, 80, 1000, 700)
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{}) == design
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{
		horizontal: .end
		vertical:   .end
	}) == rect(220, 130, 100, 50)
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{
		horizontal: .center
		vertical:   .center
	}) == rect(120, 80, 100, 50)
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{
		horizontal: .stretch
		vertical:   .stretch
	}) == rect(20, 30, 300, 150)
}

fn test_adaptive_limits_preserve_the_selected_anchor() {
	design := rect(20, 30, 100, 50)
	available := rect(0, 0, 1000, 700)
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{
		horizontal: .stretch
		vertical:   .stretch
		max_width:  200
		max_height: 100
	}) == rect(20, 30, 200, 100)
	assert adaptive_layout_frame(design, 800, 600, available, AdaptiveLayout{
		horizontal: .end
		vertical:   .center
		min_width:  120
		min_height: 70
	}) == rect(200, 70, 120, 70)
	assert adaptive_layout_frame(design, 800, 600, rect(0, 0, 100, 100), AdaptiveLayout{
		horizontal: .stretch
		vertical:   .stretch
	}) == rect(20, 30, 0, 0)
}

fn test_adaptive_resize_is_reversible_and_keeps_fractional_coordinates() {
	design := rect(20.25, 30.75, 100.5, 50.25)
	rules := AdaptiveLayout{
		horizontal: .end
		vertical:   .stretch
	}
	for width in [320.0, 600, 800, 1920, 320, 800] {
		resolved := adaptive_layout_frame(design, 800, 600, rect(0, 0, width, 900), rules)
		assert resolved.x + resolved.width == width - (800 - design.x - design.width)
		assert resolved.y == design.y
	}
	assert adaptive_layout_frame(design, 800, 600, rect(0, 0, 800, 600), rules) == design
}

fn test_adaptive_size_classes_and_specificity() {
	assert adaptive_size_class(599.99, 600) == .compact
	assert adaptive_size_class(600, 600) == .regular
	assert adaptive_size_class(600.01, 600) == .regular
	variations := [
		AdaptiveLayoutVariation{
			height_class: .compact
		},
		AdaptiveLayoutVariation{
			width_class: .compact
		},
		AdaptiveLayoutVariation{
			width_class:  .compact
			height_class: .compact
		},
	]
	assert adaptive_variation_index(variations, .compact, .compact) == 2
	assert adaptive_variation_index(variations[..2], .compact, .compact) == 1
	assert adaptive_variation_index([variations[1], variations[0]], .compact, .compact) == 0
	assert adaptive_variation_index(variations, .regular, .compact) == 0
	assert adaptive_variation_index(variations, .compact, .regular) == 1
	assert adaptive_variation_index(variations, .regular, .regular) == -1
}

fn test_adaptive_rejects_inconsistent_size_limits() {
	for rules in [AdaptiveLayout{ min_width: -1 }, AdaptiveLayout{ min_height: 100, max_height: 50 }] {
		mut rejected := false
		validate_adaptive_layout(rules) or { rejected = true }
		assert rejected, 'invalid limits must not be accepted'
	}
	validate_adaptive_layout(AdaptiveLayout{ min_width: 80 }) or { panic(err) }
}
