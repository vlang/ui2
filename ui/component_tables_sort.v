module ui2

import math

// Pure helpers behind the tables: sort orders, the window of rows a scrolled body
// shows, keyboard movement and the header checkbox state. None of them touch an
// element, so applications can call them from event handlers and tests can cover
// them without a renderer.

// ── Sorting ─────────────────────────────────────────────────────────

pub enum TableSortDirection {
	none
	ascending
	descending
}

// next is the direction a header click moves to: unsorted, ascending, descending,
// and back to unsorted, the order spreadsheets and most data grids use.
pub fn (direction TableSortDirection) next() TableSortDirection {
	return match direction {
		.none { .ascending }
		.ascending { .descending }
		.descending { .none }
	}
}

// table_compare_text orders strings the way people read them: letters without
// regard to case, and runs of digits by their value, so `Item 9` comes before
// `Item 10`. It returns a negative number, zero or a positive number.
pub fn table_compare_text(a string, b string) int {
	return table_compare_folded(a.to_lower(), b.to_lower())
}

fn table_is_digit(ch u8) bool {
	return ch >= `0` && ch <= `9`
}

// table_compare_folded is table_compare_text on strings already lowered, so a
// sort lowers each key once rather than on every comparison.
fn table_compare_folded(a string, b string) int {
	mut i := 0
	mut j := 0
	for i < a.len && j < b.len {
		if table_is_digit(a[i]) && table_is_digit(b[j]) {
			// Skip leading zeros, then the longer run is the larger number and runs
			// of one length compare digit by digit.
			mut si := i
			for si < a.len && a[si] == `0` {
				si++
			}
			mut sj := j
			for sj < b.len && b[sj] == `0` {
				sj++
			}
			mut ei := si
			for ei < a.len && table_is_digit(a[ei]) {
				ei++
			}
			mut ej := sj
			for ej < b.len && table_is_digit(b[ej]) {
				ej++
			}
			if ei - si != ej - sj {
				return if ei - si < ej - sj { -1 } else { 1 }
			}
			for k in 0 .. ei - si {
				if a[si + k] != b[sj + k] {
					return if a[si + k] < b[sj + k] { -1 } else { 1 }
				}
			}
			i = ei
			j = ej
			continue
		}
		if a[i] != b[j] {
			return if a[i] < b[j] { -1 } else { 1 }
		}
		i++
		j++
	}
	if a.len - i == b.len - j {
		return 0
	}
	return if a.len - i < b.len - j { -1 } else { 1 }
}

// table_merge_order sorts the indices 0..count by `before`, which says whether the
// first index must come ahead of the second. Equal items keep their order: a merge
// sort takes from the left run unless the right item is strictly ahead.
fn table_merge_order(count int, before fn (int, int) bool) []int {
	mut order := []int{len: count, init: index}
	if count < 2 {
		return order
	}
	mut scratch := []int{len: count}
	mut width := 1
	for width < count {
		mut low := 0
		for low < count {
			middle := math.min(low + width, count)
			high := math.min(low + 2 * width, count)
			mut left := low
			mut right := middle
			mut out := low
			for left < middle && right < high {
				if before(order[right], order[left]) {
					scratch[out] = order[right]
					right++
				} else {
					scratch[out] = order[left]
					left++
				}
				out++
			}
			for left < middle {
				scratch[out] = order[left]
				left++
				out++
			}
			for right < high {
				scratch[out] = order[right]
				right++
				out++
			}
			low += 2 * width
		}
		for k in 0 .. count {
			order[k] = scratch[k]
		}
		width *= 2
	}
	return order
}

// table_sort_order_text returns the indices of values in sorted order, comparing
// with table_compare_text. The sort is stable in both directions: values that
// compare equal keep the order they had, so sorting by one column and then another
// groups rows by the second while keeping the first within each group. `none`
// returns the original order. Show row `i` as the data at index `order[i]`.
pub fn table_sort_order_text(values []string, direction TableSortDirection) []int {
	if direction == .none {
		return []int{len: values.len, init: index}
	}
	folded := values.map(it.to_lower())
	sign := if direction == .ascending { 1 } else { -1 }
	return table_merge_order(values.len, fn [folded, sign] (a int, b int) bool {
		return table_compare_folded(folded[a], folded[b]) * sign < 0
	})
}

// table_sort_order_numbers is table_sort_order_text for numeric columns. NaN has
// no place among numbers, so it goes last in either direction.
pub fn table_sort_order_numbers(values []f64, direction TableSortDirection) []int {
	if direction == .none {
		return []int{len: values.len, init: index}
	}
	ascending := direction == .ascending
	return table_merge_order(values.len, fn [values, ascending] (a int, b int) bool {
		x := values[a]
		y := values[b]
		if math.is_nan(x) || math.is_nan(y) {
			return !math.is_nan(x) && math.is_nan(y)
		}
		return if ascending { x < y } else { x > y }
	})
}

// ── Virtualization ──────────────────────────────────────────────────

// TableRowRange is the half-open range [start, end) of row indices to build.
pub struct TableRowRange {
pub:
	start int
	end   int
}

pub fn (range TableRowRange) len() int {
	return range.end - range.start
}

pub fn (range TableRowRange) contains(row int) bool {
	return row >= range.start && row < range.end
}

// table_visible_rows is the window of rows a body `viewport` tall shows when it is
// scrolled down by `offset`, widened by `overscan` rows on each side so rows are
// already built when a scroll brings them in. Only these rows need elements; a
// spacer as tall as every row keeps the scroll range.
pub fn table_visible_rows(row_count int, row_height f64, viewport f64, offset f64, overscan int) TableRowRange {
	if row_count <= 0 || !component_finite(row_height) || row_height <= 0
		|| !component_finite(viewport) || viewport <= 0 {
		return TableRowRange{}
	}
	top := if component_finite(offset) { math.max(0.0, offset) } else { 0.0 }
	extra := math.max(0, overscan)
	first := int(math.floor(top / row_height))
	last := int(math.ceil((top + viewport) / row_height))
	start := math.min(row_count, math.max(0, first - extra))
	end := math.min(row_count, math.max(start, last + extra))
	return TableRowRange{start, end}
}

// ── Keyboard ────────────────────────────────────────────────────────

// table_row_after_key moves a row cursor the way GPUI Kit's table does: Up and
// Down by one, Page Up and Page Down by `page` rows, Home and End to the ends,
// stopping at the first and last row. Without a current row (-1) any of them
// starts at the first row, and End at the last. It returns none for other keys,
// an empty table, and a move that would stay put.
pub fn table_row_after_key(current int, row_count int, page int, code KeyCode) ?int {
	if row_count <= 0 {
		return none
	}
	last := row_count - 1
	step := math.max(1, page)
	if current < 0 || current > last {
		return match code {
			.up, .down, .home, .page_up, .page_down { 0 }
			.end { last }
			else { none }
		}
	}
	target := match code {
		.up { current - 1 }
		.down { current + 1 }
		.page_up { current - step }
		.page_down { current + step }
		.home { 0 }
		.end { last }
		else { return none }
	}
	clamped := math.min(last, math.max(0, target))
	return if clamped == current { none } else { clamped }
}

// ── Selection ───────────────────────────────────────────────────────

pub enum TableCheckState {
	unchecked
	checked
	mixed // Some rows but not all: the indeterminate header checkbox.
}

// table_check_state is what a select-all checkbox shows for `selected` of `total`
// rows.
pub fn table_check_state(selected int, total int) TableCheckState {
	if selected <= 0 || total <= 0 {
		return .unchecked
	}
	return if selected >= total { .checked } else { .mixed }
}

// ── Resizing ────────────────────────────────────────────────────────

// table_resize_width is the width a column drag ends at: the width when the
// press started plus how far the pointer has moved, held between the column's
// min_width and max_width.
pub fn table_resize_width(column TableColumn, start_width f64, delta f64) f64 {
	low, high := table_column_bounds(column)
	base := if component_finite(start_width) { start_width } else { low }
	moved := if component_finite(delta) { delta } else { 0.0 }
	return math.min(high, math.max(low, base + moved))
}

// table_resized_widths returns widths with column `index` dragged by `delta` from
// `start_width`, and every other column as it was.
pub fn table_resized_widths(columns []TableColumn, widths []f64, index int, start_width f64, delta f64) []f64 {
	mut next := widths.clone()
	if index >= 0 && index < columns.len && index < next.len {
		next[index] = table_resize_width(columns[index], start_width, delta)
	}
	return next
}
