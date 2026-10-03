module ui2

pub struct MeasureCacheItem {
pub:
	id   int
	text string
}

pub struct MeasureCacheApp {
pub:
	items []MeasureCacheItem
}

// Alternating orientations change the width each level offers its subtree.
fn measure_cache_nested(depth int) string {
	mut source := 'Label { text: "content that wraps at a narrow width" lines: 3 }'
	for level in 0 .. depth {
		orientation := if level % 2 == 0 { 'horizontal' } else { 'vertical' }
		source = 'FlexLayout { orientation: ${orientation} gap: 4\n Label { text: "level ${level}" }\n ${source} }'
	}
	return source
}

fn measure_cache_model_computations(depth int) int {
	root := parse_vml('Screen {\n ${measure_cache_nested(depth)} }') or { panic(err) }
	mut evaluation := VmlEvaluation{}
	v_eval_node(root, {
		'app': v_value_from(MeasureCacheApp{})
	}, rect(0, 0, 800, 600), mut evaluation) or { panic(err) }
	return evaluation.measure.computed
}

fn measure_cache_static_computations(depth int) int {
	root := parse_vml(measure_cache_nested(depth)) or { panic(err) }
	mut cache := VLayoutMeasureCache{}
	v_layout_preferred(root, rect(0, 0, 800, 600), mut cache) or { panic(err) }
	return cache.computed
}

fn test_nested_flex_measurement_grows_polynomially_with_depth() {
	for count in [measure_cache_static_computations, measure_cache_model_computations] {
		shallow := count(6)
		deep := count(12)
		// Measuring every subtree twice per level made six more levels cost about
		// 2^6 times as much. With reuse the growth stays near quadratic (~4x).
		assert deep < shallow * 8, '${shallow} -> ${deep}'
	}
}

// Repeated items share a source node and path but resolve to different text.
// Each must be measured as its own content inside an outer measurement.
fn test_nested_measurement_keeps_repeated_items_distinct() {
	source := 'FlexLayout {
		orientation: vertical align_items: start
		FlexLayout {
			id: row gap: 4 align_items: start width: 300
			Repeater {
				model: app.items
				key: item.id
				FlexLayout {
					orientation: vertical flex_basis: 0 flex_grow: 1
					Label { text: item.text lines: 8 }
				}
			}
		}
	}'
	long_text := 'A description long enough to wrap onto several lines in a narrow column'
	model := MeasureCacheApp{
		items: [MeasureCacheItem{1, 'Short'}, MeasureCacheItem{2, long_text},
			MeasureCacheItem{3, 'Short'}]
	}
	root := element_from_vml_model(source, model, rect(0, 0, 600, 400)) or { panic(err) }
	row := root.children[0]
	items := row.children
	assert items.len == 3
	label := items[1].children[0]
	expected := measure_layout_text(long_text, label.text_style, items[1].frame.width) or {
		panic(err)
	}
	assert items[0].frame.height < items[1].frame.height
	assert items[0].frame.height == items[2].frame.height
	assert items[1].frame.height == expected.height
	assert row.frame.height == expected.height
}
