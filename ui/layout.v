module ui2

import math

pub enum LayoutOrientation {
	horizontal
	vertical
}

pub enum LayoutAlignment {
	auto
	start
	center
	end
	stretch
}

pub struct LayoutPadding {
pub:
	left   f64
	top    f64
	right  f64
	bottom f64
}

pub fn layout_orientation(value string) !LayoutOrientation {
	return match value {
		'', 'horizontal' { .horizontal }
		'vertical' { .vertical }
		else { return error('unknown layout orientation `${value}`') }
	}
}

pub fn layout_alignment(value string) !LayoutAlignment {
	return match value {
		'', 'auto' { .auto }
		'start' { .start }
		'center' { .center }
		'end' { .end }
		'stretch' { .stretch }
		else { return error('unknown layout alignment `${value}`') }
	}
}

fn layout_finite(value f64) bool {
	return !math.is_nan(value) && !math.is_inf(value, 0)
}

fn layout_bound(value f64, minimum f64, maximum f64) f64 {
	mut bounded := if value < 0 { 0.0 } else { value }
	if minimum >= 0 && bounded < minimum { bounded = minimum }
	if maximum >= 0 && bounded > maximum { bounded = maximum }
	return bounded
}

fn layout_max(left f64, right f64) f64 {
	return if left > right { left } else { right }
}
