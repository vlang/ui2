module ui2

@[heap]
struct MeasureCalls {
mut:
	count int
}

fn test_measure_text_width_estimates_without_a_backend() {
	configure_text_measurer(MeasureTextFn(unsafe { nil }))
	assert !text_measurement_exact()
	assert measure_text_width('', TextStyle{}) == 0
	short := measure_text_width('Save', TextStyle{})
	long := measure_text_width('Save changes', TextStyle{})
	assert short > 0 && long > short
	assert measure_text_width('Save', TextStyle{ bold: true }) > short
	assert measure_text_width('Save', TextStyle{ size: 30 }) > short
}

fn test_measure_text_width_asks_the_backend_once_per_text_and_style() {
	mut calls := &MeasureCalls{}
	configure_text_measurer(fn [mut calls] (text string, style TextStyle) f64 {
		calls.count++
		return f64(text.len) * style.size / 2
	})
	defer {
		configure_text_measurer(MeasureTextFn(unsafe { nil }))
	}
	assert text_measurement_exact()
	assert measure_text_width('abcd', TextStyle{ size: 10 }) == 20
	assert measure_text_width('abcd', TextStyle{ size: 10 }) == 20
	assert calls.count == 1
	// Another size, weight or family is another measurement.
	assert measure_text_width('abcd', TextStyle{ size: 20 }) == 40
	assert measure_text_width('abcd', TextStyle{ size: 10, bold: true }) == 20
	assert measure_text_width('abcd', TextStyle{ size: 10, font_family: 'mono' }) == 20
	assert calls.count == 4
	// A new backend starts with no remembered widths.
	configure_text_measurer(fn [mut calls] (text string, style TextStyle) f64 {
		calls.count++
		return 1
	})
	assert measure_text_width('abcd', TextStyle{ size: 10 }) == 1
	assert calls.count == 5
}

fn test_wrap_text_to_width_breaks_at_spaces_and_newlines() {
	configure_text_measurer(fn (text string, style TextStyle) f64 {
		return f64(text.runes().len) * 10
	})
	defer {
		configure_text_measurer(MeasureTextFn(unsafe { nil }))
	}
	assert wrap_text_to_width('one two three', TextStyle{}, 70) == ['one two', 'three']
	assert wrap_text_to_width('one two three', TextStyle{}, 200) == ['one two three']
	assert wrap_text_to_width('one\ntwo three', TextStyle{}, 200) == ['one', 'two three']
	// A word wider than the line keeps a line of its own.
	assert wrap_text_to_width('a extraordinary b', TextStyle{}, 50) == ['a', 'extraordinary', 'b']
}
