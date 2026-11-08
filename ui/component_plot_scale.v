module ui2

import math

// Scales map a dimension of data onto positions, the way d3-scale does (which
// GPUI Kit's plot module follows): a linear scale for quantities, band and
// point scales for categories, and an ordinal scale for colors.

// ── Linear ─────────────────────────────────────────────────────────

// PlotLinearScale maps the continuous domain [domain_min, domain_max] onto the
// range [range_start, range_end]. The range may run backwards: a y scale goes
// from the plot's height to 0 so that larger values sit higher.
pub struct PlotLinearScale {
pub:
	domain_min  f64
	domain_max  f64 = 1
	range_start f64
	range_end   f64 = 1
	// clamp keeps positions inside the range, so a value outside the domain
	// stops at the plot's edge instead of leaving it.
	clamp bool
}

pub fn plot_linear_scale(domain_min f64, domain_max f64, range_start f64, range_end f64) PlotLinearScale {
	return PlotLinearScale{
		domain_min:  domain_min
		domain_max:  domain_max
		range_start: range_start
		range_end:   range_end
	}
}

// with_range returns the scale mapped onto a new range.
pub fn (s PlotLinearScale) with_range(range_start f64, range_end f64) PlotLinearScale {
	return PlotLinearScale{
		...s
		range_start: range_start
		range_end:   range_end
	}
}

// with_clamp returns the scale with clamping turned on or off.
pub fn (s PlotLinearScale) with_clamp(clamp bool) PlotLinearScale {
	return PlotLinearScale{
		...s
		clamp: clamp
	}
}

// position is where `value` falls in the range. A domain with no extent puts
// every value in the middle of the range.
pub fn (s PlotLinearScale) position(value f64) f64 {
	span := s.domain_max - s.domain_min
	if span == 0 || !plot_finite(span) {
		return (s.range_start + s.range_end) / 2
	}
	mut t := (value - s.domain_min) / span
	if s.clamp {
		t = math.max(0.0, math.min(1.0, t))
	}
	return s.range_start + t * (s.range_end - s.range_start)
}

// invert is the value at a position in the range: what a pointer over the
// plot points at.
pub fn (s PlotLinearScale) invert(pixel f64) f64 {
	span := s.range_end - s.range_start
	if span == 0 || !plot_finite(span) {
		return s.domain_min
	}
	mut t := (pixel - s.range_start) / span
	if s.clamp {
		t = math.max(0.0, math.min(1.0, t))
	}
	return s.domain_min + t * (s.domain_max - s.domain_min)
}

// plot_tick_step is the round step (1, 2 or 5 times a power of ten) that
// splits [start, stop] into about `count` intervals, as d3's tickIncrement
// picks it.
pub fn plot_tick_step(start f64, stop f64, count int) f64 {
	span := math.abs(stop - start)
	if count <= 0 || span == 0 || !plot_finite(span) {
		return 0
	}
	raw := span / f64(count)
	power := math.floor(math.log10(raw))
	err := raw / math.pow(10, power)
	factor := if err >= math.sqrt(50) {
		10.0
	} else if err >= math.sqrt(10) {
		5.0
	} else if err >= math.sqrt(2) {
		2.0
	} else {
		1.0
	}
	return factor * math.pow(10, power)
}

// tick_step is the step between the scale's ticks for about `count` of them.
pub fn (s PlotLinearScale) tick_step(count int) f64 {
	return plot_tick_step(s.domain_min, s.domain_max, count)
}

// ticks returns about `count` round values inside the domain, in ascending
// order, for an axis to label and grid lines to mark.
pub fn (s PlotLinearScale) ticks(count int) []f64 {
	lo := math.min(s.domain_min, s.domain_max)
	hi := math.max(s.domain_min, s.domain_max)
	if !plot_finite(lo) || !plot_finite(hi) {
		return []f64{}
	}
	if lo == hi {
		return if count > 0 { [lo] } else { []f64{} }
	}
	step := plot_tick_step(lo, hi, count)
	if step <= 0 {
		return []f64{}
	}
	// Whole multiples of the step, computed by multiplying (or, for steps
	// below one, dividing by the inverse) so they come out exact: 0.3, not
	// 0.30000000000000004.
	inverse := if step < 1 { math.round(1 / step) } else { 0.0 }
	first := if inverse > 0 { math.ceil(lo * inverse) } else { math.ceil(lo / step) }
	last := if inverse > 0 { math.floor(hi * inverse) } else { math.floor(hi / step) }
	if last - first > 1000 {
		return []f64{}
	}
	mut ticks := []f64{}
	for k := first; k <= last; k += 1 {
		value := if inverse > 0 { k / inverse } else { k * step }
		ticks << if value == 0 { 0.0 } else { value }
	}
	return ticks
}

// nice extends the domain outward to round values, so that its ends fall on
// ticks: [0, 186] becomes [0, 200] for five ticks.
pub fn (s PlotLinearScale) nice(count int) PlotLinearScale {
	mut lo := math.min(s.domain_min, s.domain_max)
	mut hi := math.max(s.domain_min, s.domain_max)
	if !plot_finite(lo) || !plot_finite(hi) || lo == hi || count <= 0 {
		return s
	}
	mut previous := 0.0
	for _ in 0 .. 10 {
		step := plot_tick_step(lo, hi, count)
		if step <= 0 || step == previous {
			break
		}
		lo = math.floor(lo / step) * step
		hi = math.ceil(hi / step) * step
		previous = step
	}
	reversed := s.domain_min > s.domain_max
	return PlotLinearScale{
		...s
		domain_min: if reversed { hi } else { lo }
		domain_max: if reversed { lo } else { hi }
	}
}

// plot_extent is the smallest and largest finite value among `values` and
// `include` (pass [0.0] to keep zero in view). With no finite value it is
// (0, 0).
pub fn plot_extent(values []f64, include []f64) (f64, f64) {
	mut lo := math.max_f64
	mut hi := -math.max_f64
	for list in [values, include] {
		for value in list {
			if plot_finite(value) {
				lo = math.min(lo, value)
				hi = math.max(hi, value)
			}
		}
	}
	if lo > hi {
		return 0, 0
	}
	return lo, hi
}

// ── Band ───────────────────────────────────────────────────────────

// PlotBandScale lays categories out as equal bands across a range, with
// space between them (padding_inner, a share of a step) and before the first
// and after the last (padding_outer, in steps), as a bar chart needs.
pub struct PlotBandScale {
pub:
	domain        []string // distinct values, laid out in order from range_start
	range_start   f64
	range_end     f64
	padding_inner f64 // 0 to 1
	padding_outer f64
	align         f64 = 0.5 // where leftover space goes: 0 after the bands, 1 before
	// count lays the range out for this many bands when the domain has fewer;
	// the domain takes the leading ones and the rest stay empty.
	count int
	// max_bandwidth caps the band width (0 is no cap); a capped band stays
	// centered in its slot.
	max_bandwidth f64
}

// plot_band_scale lays the distinct values of `domain` out across the range.
pub fn plot_band_scale(domain []string, range_start f64, range_end f64) PlotBandScale {
	return PlotBandScale{
		domain:      plot_distinct(domain)
		range_start: range_start
		range_end:   range_end
	}
}

// with_padding returns the scale with new inner and outer padding.
pub fn (s PlotBandScale) with_padding(inner f64, outer f64) PlotBandScale {
	return PlotBandScale{
		...s
		padding_inner: inner
		padding_outer: outer
	}
}

fn plot_distinct(values []string) []string {
	mut seen := map[string]bool{}
	mut out := []string{cap: values.len}
	for value in values {
		if value !in seen {
			seen[value] = true
			out << value
		}
	}
	return out
}

// band_count is the number of bands the range is divided into.
pub fn (s PlotBandScale) band_count() int {
	return if s.count > s.domain.len { s.count } else { s.domain.len }
}

fn (s PlotBandScale) inner() f64 {
	return math.max(0.0, math.min(1.0, s.padding_inner))
}

// step is the distance between the starts of neighboring bands.
pub fn (s PlotBandScale) step() f64 {
	n := f64(s.band_count())
	if n == 0 {
		return 0
	}
	span := math.abs(s.range_end - s.range_start)
	return span / math.max(1.0, n - s.inner() + 2 * math.max(0.0, s.padding_outer))
}

fn (s PlotBandScale) slot_width() f64 {
	return s.step() * (1 - s.inner())
}

// bandwidth is the width of each band.
pub fn (s PlotBandScale) bandwidth() f64 {
	width := s.slot_width()
	return if s.max_bandwidth > 0 { math.min(width, s.max_bandwidth) } else { width }
}

// position_at is where band `index` starts, counted from range_start; for a
// backwards range the bands run backwards too.
pub fn (s PlotBandScale) position_at(index int) f64 {
	n := s.band_count()
	step := s.step()
	lo := math.min(s.range_start, s.range_end)
	span := math.abs(s.range_end - s.range_start)
	// The space the bands leave over, as a share of the range, so it comes
	// out exactly zero without padding.
	used := f64(n) - s.inner()
	slots := math.max(1.0, used + 2 * math.max(0.0, s.padding_outer))
	start := lo + span * (slots - used) / slots * math.max(0.0, math.min(1.0, s.align))
	slot := if s.range_end < s.range_start { n - 1 - index } else { index }
	return start + step * f64(slot) + (s.slot_width() - s.bandwidth()) / 2
}

// center_at is the middle of band `index`.
pub fn (s PlotBandScale) center_at(index int) f64 {
	return s.position_at(index) + s.bandwidth() / 2
}

// index_of is the band of a domain value.
pub fn (s PlotBandScale) index_of(value string) ?int {
	for i, item in s.domain {
		if item == value {
			return i
		}
	}
	return none
}

// position is where the band of `value` starts, or none for a value outside
// the domain.
pub fn (s PlotBandScale) position(value string) ?f64 {
	index := s.index_of(value)?
	return s.position_at(index)
}

// nearest_index is the band whose slot (the band and half the padding on each
// side) holds `pixel`, or the nearest one; -1 with no bands.
pub fn (s PlotBandScale) nearest_index(pixel f64) int {
	n := s.band_count()
	if n == 0 {
		return -1
	}
	mut best := 0
	mut best_distance := math.max_f64
	for i in 0 .. n {
		distance := math.abs(pixel - s.center_at(i))
		if distance < best_distance {
			best = i
			best_distance = distance
		}
	}
	return best
}

// ── Point ──────────────────────────────────────────────────────────

// PlotPointScale places categories at evenly spaced points, the first and
// last on the ends of the range unless `padding` (in steps) keeps them in.
// Line and area charts lay their x axis out with it.
pub struct PlotPointScale {
pub:
	domain      []string
	range_start f64
	range_end   f64
	padding     f64
	align       f64 = 0.5
	// count lays the range out for this many points when the domain has
	// fewer, so a series still in progress fills only the leading ones.
	count int
}

pub fn plot_point_scale(domain []string, range_start f64, range_end f64) PlotPointScale {
	return PlotPointScale{
		domain:      domain
		range_start: range_start
		range_end:   range_end
	}
}

// point_count is the number of points the range is laid out for.
pub fn (s PlotPointScale) point_count() int {
	return if s.count > s.domain.len { s.count } else { s.domain.len }
}

// step is the distance between neighboring points.
pub fn (s PlotPointScale) step() f64 {
	n := s.point_count()
	if n == 0 {
		return 0
	}
	span := s.range_end - s.range_start
	return span / math.max(1.0, f64(n - 1) + 2 * math.max(0.0, s.padding))
}

// position_at is the position of point `index`. A single point sits in the
// middle of the range.
pub fn (s PlotPointScale) position_at(index int) f64 {
	n := s.point_count()
	span := s.range_end - s.range_start
	used := f64(n - 1)
	slots := math.max(1.0, used + 2 * math.max(0.0, s.padding))
	start := s.range_start + span * (slots - used) / slots * math.max(0.0, math.min(1.0, s.align))
	return start + span * f64(index) / slots
}

// position is the position of a domain value, or none outside the domain.
pub fn (s PlotPointScale) position(value string) ?f64 {
	for i, item in s.domain {
		if item == value {
			return s.position_at(i)
		}
	}
	return none
}

// nearest_index is the point nearest `pixel`, or -1 with no points.
pub fn (s PlotPointScale) nearest_index(pixel f64) int {
	n := s.point_count()
	if n == 0 {
		return -1
	}
	step := s.step()
	if step == 0 {
		return 0
	}
	index := int(math.round((pixel - s.position_at(0)) / step))
	return if index < 0 {
		0
	} else if index > n - 1 {
		n - 1
	} else {
		index
	}
}

// ── Ordinal ────────────────────────────────────────────────────────

// PlotOrdinalScale maps each domain value to a color of its range, in order,
// repeating the range when the domain is longer.
pub struct PlotOrdinalScale {
pub:
	domain  []string
	range   []u32
	unknown ?u32 // the color of values outside the domain
}

// plot_color_scale gives each key its slot of the theme's chart palette.
pub fn plot_color_scale(keys []string, theme ComponentTheme) PlotOrdinalScale {
	return PlotOrdinalScale{
		domain: keys
		range:  plot_chart_palette(theme)
	}
}

// get is the color of `value`: its range slot, the unknown color for a value
// outside the domain, or none when there is neither.
pub fn (s PlotOrdinalScale) get(value string) ?u32 {
	for i, item in s.domain {
		if item == value {
			if s.range.len == 0 {
				return none
			}
			return s.range[i % s.range.len]
		}
	}
	return s.unknown
}
