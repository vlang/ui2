module ui2

// ProgressBarConfig describes a horizontal, display-only progress indicator.
// Its value follows Kivy's ProgressBar semantics: it is clamped between zero
// and max, and max defaults to 100.
pub struct ProgressBarConfig {
pub:
	id         string
	frame      Rect
	value      f64
	max        f64 = 100.0
	background u32 = 0xe2e8f0
	color      u32 = 0x3b82f6
	radius     f64 = 4.0
}

// progress_bar_value_normalized returns value as a safe fraction in 0...1.
// A non-positive maximum produces an empty progress bar.
pub fn progress_bar_value_normalized(value f64, max f64) f64 {
	if max <= 0 || value <= 0 {
		return 0
	}
	if value >= max {
		return 1
	}
	return value / max
}

fn progress_bar_number(value f64) string {
	integer := i64(value)
	if value == f64(integer) {
		return integer.str()
	}
	return value.str()
}

// progress_bar builds a horizontal progress indicator from ordinary views, so
// it has identical geometry and styling on native and custom-rendered backends.
pub fn progress_bar(config ProgressBarConfig) Element {
	normalized := progress_bar_value_normalized(config.value, config.max)
	maximum := if config.max > 0 { config.max } else { 0.0 }
	clamped_value := normalized * maximum
	fill := view('', rect(0, 0, config.frame.width * normalized, config.frame.height), BoxStyle{
		bg: config.color
		radius: config.radius
	}, [])
	return Element{
		...view(config.id, config.frame, BoxStyle{
			bg: config.background
			radius: config.radius
		}, [fill])
		accessibility_role: 'progressbar'
		accessibility_label: 'Progress'
		accessibility_value: '${progress_bar_number(clamped_value)} of ${progress_bar_number(maximum)}'
	}
}
