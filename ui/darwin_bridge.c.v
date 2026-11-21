module ui2

// Runtime bridges are shared by native controls and renderer-independent
// integrations such as the clipboard and tray images.
$if (macos || ios) && !ui2_headless ? {
	import macos

	#include "@VMODROOT/ui/darwin_bridge.h"

	@[typedef]
	struct C.ui2_darwin_point {
	pub mut:
		x f64
		y f64
	}
	@[typedef]
	struct C.ui2_darwin_range {
	pub mut:
		location u64
		length   u64
	}
	@[typedef]
	struct C.ui2_darwin_rect {
		x      f64
		y      f64
		width  f64
		height f64
	}
	pub type DarwinPoint = C.ui2_darwin_point
	pub type DarwinRange = C.ui2_darwin_range

	pub fn darwin_point(x f64, y f64) DarwinPoint {
		return DarwinPoint{ x: x, y: y }
	}
	pub fn darwin_range(location u64, length u64) DarwinRange {
		return DarwinRange{ location: location, length: length }
	}
	pub fn darwin_responds_to(obj macos.Id, sel string) bool {
		return darwin_msg_bool_id(obj, 'respondsToSelector:', macos.Id(macos.sel(sel)))
	}

	fn C.ui2_darwin_msg_point(obj voidptr, sel voidptr) C.ui2_darwin_point
	pub fn darwin_msg_point(obj macos.Id, sel string) DarwinPoint {
		return C.ui2_darwin_msg_point(obj, macos.sel(sel))
	}

	fn C.ui2_darwin_msg_bool_id(obj voidptr, sel voidptr, a0 voidptr) bool
	pub fn darwin_msg_bool_id(obj macos.Id, sel string, a0 macos.Id) bool {
		return C.ui2_darwin_msg_bool_id(obj, macos.sel(sel), a0)
	}

	fn C.ui2_darwin_msg_void_point(obj voidptr, sel voidptr, p C.ui2_darwin_point)
	pub fn darwin_msg_void_point(obj macos.Id, sel string, p DarwinPoint) {
		C.ui2_darwin_msg_void_point(obj, macos.sel(sel), p)
	}

	fn C.ui2_darwin_msg_id_four_f64(obj voidptr, sel voidptr, a0 f64, a1 f64, a2 f64, a3 f64) voidptr
	pub fn darwin_msg_id_four_f64(obj macos.Id, sel string, a0 f64, a1 f64, a2 f64, a3 f64) macos.Id {
		return C.ui2_darwin_msg_id_four_f64(obj, macos.sel(sel), a0, a1, a2, a3)
	}

	fn C.ui2_darwin_msg_id_id_u64(obj voidptr, sel voidptr, a0 voidptr, a1 u64) voidptr
	pub fn darwin_msg_id_id_u64(obj macos.Id, sel string, a0 macos.Id, a1 u64) macos.Id {
		return C.ui2_darwin_msg_id_id_u64(obj, macos.sel(sel), a0, a1)
	}

	fn C.ui2_darwin_msg_range(obj voidptr, sel voidptr) C.ui2_darwin_range
	pub fn darwin_msg_range(obj macos.Id, sel string) DarwinRange {
		return C.ui2_darwin_msg_range(obj, macos.sel(sel))
	}

	fn C.ui2_darwin_msg_point_point_id(obj voidptr, sel voidptr, value C.ui2_darwin_point, a1 voidptr) C.ui2_darwin_point
	pub fn darwin_msg_point_point_id(obj macos.Id, sel string, value DarwinPoint, a1 macos.Id) DarwinPoint {
		return C.ui2_darwin_msg_point_point_id(obj, macos.sel(sel), value, a1)
	}

	fn C.ui2_darwin_msg_bool_id_bool(obj voidptr, sel voidptr, a0 voidptr, a1 bool) bool
	pub fn darwin_msg_bool_id_bool(obj macos.Id, sel string, a0 macos.Id, a1 bool) bool {
		return C.ui2_darwin_msg_bool_id_bool(obj, macos.sel(sel), a0, a1)
	}

	fn C.ui2_darwin_msg_bool_sel_id_id(obj voidptr, sel voidptr, a0 voidptr, a1 voidptr, a2 voidptr) bool
	pub fn darwin_msg_bool_sel_id_id(obj macos.Id, sel string, a0 macos.Sel, a1 macos.Id, a2 macos.Id) bool {
		return C.ui2_darwin_msg_bool_sel_id_id(obj, macos.sel(sel), a0, a1, a2)
	}

	fn C.ui2_darwin_msg_id_rect_u64_u64_bool(obj voidptr, sel voidptr, rect C.ui2_darwin_rect, a1 u64, a2 u64, a3 bool) voidptr
	pub fn darwin_msg_id_rect_u64_u64_bool(obj macos.Id, sel string, rect macos.Rect, a1 u64, a2 u64, a3 bool) macos.Id {
		return C.ui2_darwin_msg_id_rect_u64_u64_bool(obj, macos.sel(sel), C.ui2_darwin_rect{ x: rect.x, y: rect.y, width: rect.width, height: rect.height }, a1, a2, a3)
	}

	fn C.ui2_darwin_msg_id_id_f64(obj voidptr, sel voidptr, a0 voidptr, a1 f64) voidptr
	pub fn darwin_msg_id_id_f64(obj macos.Id, sel string, a0 macos.Id, a1 f64) macos.Id {
		return C.ui2_darwin_msg_id_id_f64(obj, macos.sel(sel), a0, a1)
	}

	fn C.ui2_darwin_msg_id_id_u64_i64_f64(obj voidptr, sel voidptr, a0 voidptr, a1 u64, a2 i64, a3 f64) voidptr
	pub fn darwin_msg_id_id_u64_i64_f64(obj macos.Id, sel string, a0 macos.Id, a1 u64, a2 i64, a3 f64) macos.Id {
		return C.ui2_darwin_msg_id_id_u64_i64_f64(obj, macos.sel(sel), a0, a1, a2, a3)
	}

	fn C.ui2_darwin_msg_id_u64_id(obj voidptr, sel voidptr, a0 u64, a1 voidptr) voidptr
	pub fn darwin_msg_id_u64_id(obj macos.Id, sel string, a0 u64, a1 macos.Id) macos.Id {
		return C.ui2_darwin_msg_id_u64_id(obj, macos.sel(sel), a0, a1)
	}

	fn C.ui2_darwin_msg_id_u64_range_ptr(obj voidptr, sel voidptr, a0 u64, range_ptr &C.ui2_darwin_range) voidptr
	pub fn darwin_msg_id_u64_range_ptr(obj macos.Id, sel string, a0 u64, range_ptr &DarwinRange) macos.Id {
		return C.ui2_darwin_msg_id_u64_range_ptr(obj, macos.sel(sel), a0, range_ptr)
	}

	fn C.ui2_darwin_msg_id_id_u64_range_ptr(obj voidptr, sel voidptr, a0 voidptr, a1 u64, range_ptr &C.ui2_darwin_range) voidptr
	pub fn darwin_msg_id_id_u64_range_ptr(obj macos.Id, sel string, a0 macos.Id, a1 u64, range_ptr &DarwinRange) macos.Id {
		return C.ui2_darwin_msg_id_id_u64_range_ptr(obj, macos.sel(sel), a0, a1, range_ptr)
	}

	fn C.ui2_darwin_msg_id_range(obj voidptr, sel voidptr, value C.ui2_darwin_range) voidptr
	pub fn darwin_msg_id_range(obj macos.Id, sel string, value DarwinRange) macos.Id {
		return C.ui2_darwin_msg_id_range(obj, macos.sel(sel), value)
	}

	fn C.ui2_darwin_msg_u64_id(obj voidptr, sel voidptr, a0 voidptr) u64
	pub fn darwin_msg_u64_id(obj macos.Id, sel string, a0 macos.Id) u64 {
		return C.ui2_darwin_msg_u64_id(obj, macos.sel(sel), a0)
	}

	fn C.ui2_darwin_msg_void_id_i64_id(obj voidptr, sel voidptr, a0 voidptr, a1 i64, a2 voidptr)
	pub fn darwin_msg_void_id_i64_id(obj macos.Id, sel string, a0 macos.Id, a1 i64, a2 macos.Id) {
		C.ui2_darwin_msg_void_id_i64_id(obj, macos.sel(sel), a0, a1, a2)
	}

	fn C.ui2_darwin_msg_void_id_range(obj voidptr, sel voidptr, a0 voidptr, value C.ui2_darwin_range)
	pub fn darwin_msg_void_id_range(obj macos.Id, sel string, a0 macos.Id, value DarwinRange) {
		C.ui2_darwin_msg_void_id_range(obj, macos.sel(sel), a0, value)
	}

	fn C.ui2_darwin_msg_void_id_id_range(obj voidptr, sel voidptr, a0 voidptr, a1 voidptr, value C.ui2_darwin_range)
	pub fn darwin_msg_void_id_id_range(obj macos.Id, sel string, a0 macos.Id, a1 macos.Id, value DarwinRange) {
		C.ui2_darwin_msg_void_id_id_range(obj, macos.sel(sel), a0, a1, value)
	}

	fn C.ui2_darwin_msg_void_range(obj voidptr, sel voidptr, value C.ui2_darwin_range)
	pub fn darwin_msg_void_range(obj macos.Id, sel string, value DarwinRange) {
		C.ui2_darwin_msg_void_range(obj, macos.sel(sel), value)
	}

	fn C.ui2_darwin_msg_void_rect_id(obj voidptr, sel voidptr, rect C.ui2_darwin_rect, a1 voidptr)
	pub fn darwin_msg_void_rect_id(obj macos.Id, sel string, rect macos.Rect, a1 macos.Id) {
		C.ui2_darwin_msg_void_rect_id(obj, macos.sel(sel), C.ui2_darwin_rect{ x: rect.x, y: rect.y, width: rect.width, height: rect.height }, a1)
	}

	fn C.ui2_darwin_msg_void_id_sel_id_id(obj voidptr, sel voidptr, a0 voidptr, a1 voidptr, a2 voidptr, a3 voidptr)
	pub fn darwin_msg_void_id_sel_id_id(obj macos.Id, sel string, a0 macos.Id, a1 macos.Sel, a2 macos.Id, a3 macos.Id) {
		C.ui2_darwin_msg_void_id_sel_id_id(obj, macos.sel(sel), a0, a1, a2, a3)
	}

	fn C.ui2_darwin_msg_void_sel_id_bool(obj voidptr, sel voidptr, a0 voidptr, a1 voidptr, a2 bool)
	pub fn darwin_msg_void_sel_id_bool(obj macos.Id, sel string, a0 macos.Sel, a1 macos.Id, a2 bool) {
		C.ui2_darwin_msg_void_sel_id_bool(obj, macos.sel(sel), a0, a1, a2)
	}
}
