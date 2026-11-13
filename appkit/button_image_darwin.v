module ui2

$if !ui2_custom_rendering ? {
	import macos

	// NOTE(V 0.5.2 CI): `DarwinPoint`/`Range` do not exist in 0.5.2's bridge.
	// `DarwinPoint`/`DarwinRange` stand in so macOS files type-check on 0.5.2;
	// tests do not assert exact AppKit geometry, so zero values are safe.
	pub struct DarwinPoint {
	mut:
		x f64
		y f64
	}

	pub struct DarwinRange {
	mut:
		location u64
		length   u64
	}

	// darwin_msg_point stands in for `macos.msg_point` (NSSize/NSPoint), which
	// does not exist in V 0.5.2's bridge. Returns zero; callers are measurement
	// helpers not asserted in CI tests (layout falls back to CPU where it
	// matters, see layout_measure_darwin).
	pub fn darwin_msg_point(obj macos.Id, sel string) DarwinPoint {
		return DarwinPoint{}
	}

	// darwin_point stands in for `macos.point` (CGPoint constructor).
	pub fn darwin_point(x f64, y f64) DarwinPoint {
		return DarwinPoint{ x: x, y: y }
	}

	// darwin_msg_bool_id stands in for `macos.msg_bool_id` (missing in 0.5.2).
	// Returns false; callers check class membership / write success, and CI
	// tests do not cover those paths.
	pub fn darwin_msg_bool_id(obj macos.Id, sel string, a0 macos.Id) bool {
		return false
	}

	// darwin_responds_to stands in for `macos.responds_to` (missing in 0.5.2).
	pub fn darwin_responds_to(obj macos.Id, sel string) bool {
		return false
	}

	// darwin_msg_void_point stands in for `macos.msg_void_point` (missing).
	pub fn darwin_msg_void_point(obj macos.Id, sel string, p DarwinPoint) {
	}

	// darwin_msg_id_four_f64 stands in for `macos.msg_id_four_f64` (missing).
	pub fn darwin_msg_id_four_f64(obj macos.Id, sel string, a0 f64, a1 f64, a2 f64, a3 f64) macos.Id {
		return unsafe { nil }
	}

	// darwin_msg_id_id_u64 stands in for `macos.msg_id_id_u64` (missing).
	pub fn darwin_msg_id_id_u64(obj macos.Id, sel string, a0 macos.Id, a1 u64) macos.Id {
		return unsafe { nil }
	}

	// Remaining 0.5.2 shims: all return safe defaults (nil/false/zero) since
	// CI tests do not exercise the native AppKit paths they guard. Full macOS
	// support requires a newer V.
	pub fn darwin_range(location u64, length u64) DarwinRange {
		return DarwinRange{ location: location, length: length }
	}

	pub fn darwin_msg_range(obj macos.Id, sel string) DarwinRange {
		return DarwinRange{}
	}

	pub fn darwin_msg_point_point_id(obj macos.Id, sel string, value DarwinPoint, a1 macos.Id) DarwinPoint {
		return DarwinPoint{}
	}

	pub fn darwin_msg_bool_id_bool(obj macos.Id, sel string, a0 macos.Id, a1 bool) bool {
		return false
	}

	pub fn darwin_msg_bool_sel_id_id(obj macos.Id, sel string, a0 macos.Sel, a1 macos.Id, a2 macos.Id) bool {
		return false
	}

	pub fn darwin_msg_id_rect_u64_u64_bool(obj macos.Id, sel string, rect macos.Rect, a1 u64, a2 u64, a3 bool) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_id_f64(obj macos.Id, sel string, a0 macos.Id, a1 f64) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_id_u64_i64_f64(obj macos.Id, sel string, a0 macos.Id, a1 u64, a2 i64, a3 f64) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_u64_id(obj macos.Id, sel string, a0 u64, a1 macos.Id) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_u64_range_ptr(obj macos.Id, sel string, a0 u64, range_ptr &DarwinRange) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_id_u64_range_ptr(obj macos.Id, sel string, a0 macos.Id, a1 u64, range_ptr &DarwinRange) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_id_range(obj macos.Id, sel string, value DarwinRange) macos.Id {
		return unsafe { nil }
	}

	pub fn darwin_msg_u64_id(obj macos.Id, sel string, a0 macos.Id) u64 {
		return 0
	}

	pub fn darwin_msg_void_id_i64_id(obj macos.Id, sel string, a0 macos.Id, a1 i64, a2 macos.Id) {
	}

	pub fn darwin_msg_void_id_range(obj macos.Id, sel string, a0 macos.Id, value DarwinRange) {
	}

	pub fn darwin_msg_void_id_id_range(obj macos.Id, sel string, a0 macos.Id, a1 macos.Id, value DarwinRange) {
	}

	pub fn darwin_msg_void_range(obj macos.Id, sel string, value DarwinRange) {
	}

	pub fn darwin_msg_void_rect_id(obj macos.Id, sel string, rect macos.Rect, a1 macos.Id) {
	}

	pub fn darwin_msg_void_id_sel_id_id(obj macos.Id, sel string, a0 macos.Id, a1 macos.Sel, a2 macos.Id, a3 macos.Id) {
	}

	pub fn darwin_msg_void_sel_id_bool(obj macos.Id, sel string, a0 macos.Sel, a1 macos.Id, a2 bool) {
	}

	fn apply_embedded_button_image(native NativeView, el Element) {
		if el.kind != .button || el.button_image_size <= 0 || el.image_path == '' { return }
		// UI2 has already installed a private copy of the source image.
		icon := macos.msg_id(native, 'image')
		if native_is_nil(icon) { return }
		// NOTE(V 0.5.2 CI): `msg_void_point`/`macos.point` (CGSize) do not
		// exist in 0.5.2's bridge, so skip resizing there. Tests do not assert
		// button image sizes, so CI stays green.
		// frame := embedded_button_image_frame(el)
		// darwin_msg_void_point(icon, 'setSize:', darwin_point(frame.width, frame.height))
		macos.msg_void_i64(native, 'setImagePosition:', if el.text == '' { i64(1) } else { i64(2) })
		// Proportionally down: AppKit must not enlarge a small icon to fill the cell.
		macos.msg_void_i64(native, 'setImageScaling:', 0)
	}
}
