module ui2

import math

fn vector_test_area(points []VectorPoint) f64 {
	mut area := 0.0
	for index, point in points {
		next := points[(index + 1) % points.len]
		area += point.x * next.y - next.x * point.y
	}
	return math.abs(area / 2)
}

fn test_vector_decoration_preserves_concave_area_in_both_directions() {
	points := [VectorPoint{0, 0}, VectorPoint{10, 0}, VectorPoint{10, 4}, VectorPoint{4, 4},
		VectorPoint{4, 10}, VectorPoint{0, 10}]
	for contour in [points, points.reverse()] {
		triangles := VectorPath{ points: contour }.triangles()
		assert triangles.len == 12
		mut area := 0.0
		for index := 0; index < triangles.len; index += 3 {
			area += vector_test_area([contour[triangles[index]], contour[triangles[index + 1]],
				contour[triangles[index + 2]]])
		}
		assert math.abs(area - 64) < 1e-9
	}
}

fn test_open_or_unfilled_vectors_do_not_publish_fill_triangles() {
	points := [VectorPoint{0, 0}, VectorPoint{10, 0}, VectorPoint{0, 10}]
	assert VectorPath{ points: points, closed: false }.triangles().len == 0
	assert VectorPath{ points: points, fill_enabled: false }.triangles().len == 0
	assert VectorPath{}.triangles().len == 0
}

fn test_button_image_child_uses_explicit_logical_size_and_retains_control_identity() {
	button := Element{
		kind:     .button
		id:       'open'
		frame:    rect(0, 0, 24, 24)
		children: [Element{ kind: .image, frame: rect(0, 0, 16, 16), image_path: 'icon.png' }]
	}
	normalized := embedded_button_image_element(button)
	assert normalized.id == 'open'
	assert normalized.image_path == 'icon.png'
	assert normalized.button_image_size == 16
	assert embedded_button_image_frame(normalized) == rect(4, 4, 16, 16)
	assert button.image_path == ''
	assert embedded_button_image_frame(Element{ ...normalized, button_image_size: 80 }) == rect(2, 2, 20, 20)
}
