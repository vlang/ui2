#include <objc/message.h>
#include <objc/runtime.h>
#include <dlfcn.h>

// A message that takes a rectangle and answers one, which vlib's macos bridge has no
// entry for: -[NSCell titleRectForBounds:] is how a control says where its title is
// drawn once its image, bezel and arrows have had their share of the frame.
typedef struct ui2_macos_rect {
	double x;
	double y;
	double width;
	double height;
} ui2_macos_rect;

static inline ui2_macos_rect ui2_macos_msg_rect_rect(void* obj, void* sel, ui2_macos_rect rect) {
#if defined(__x86_64__)
	// Intel returns a structure this large through memory, which plain objc_msgSend
	// does not do.
	ui2_macos_rect result;
	((void (*)(ui2_macos_rect*, void*, void*, ui2_macos_rect))objc_msgSend_stret)(&result, obj, sel, rect);
	return result;
#else
	return ((ui2_macos_rect (*)(void*, void*, ui2_macos_rect))objc_msgSend)(obj, sel, rect);
#endif
}

// A class built at runtime has no `super` to send to, so reaching the method it
// overrides means naming the class the lookup should start from. objc_super is a
// receiver followed by that class; plain pointers keep this free of ownership casts.
static inline void ui2_macos_msg_super_void_id(void* obj, void* superclass, void* sel, void* arg) {
	struct {
		void* receiver;
		void* super_class;
	} target = { obj, superclass };
	((void (*)(void*, void*, void*))objc_msgSendSuper)(&target, sel, arg);
}

// -[NSView hitTest:] takes a point and answers an object, which the bridge has no
// entry for either. A point is two doubles on both architectures.
static inline void* ui2_macos_msg_id_point(void* obj, void* sel, double x, double y) {
	struct { double x; double y; } point = { x, y };
	return ((void* (*)(void*, void*, __typeof__(point)))objc_msgSend)(obj, sel, point);
}

// Gives `view` a tracking area that follows its visible rectangle and reports the
// pointer entering, moving over and leaving it while the app is active. The
// initializer takes a rectangle, an option set and two objects: a shape the bridge
// has no entry for.
static inline void ui2_macos_add_tracking_area(void* view) {
	const unsigned long entered_and_exited = 0x01, moved = 0x02, active_in_app = 0x40,
		in_visible_rect = 0x200;
	void* area = ((void* (*)(void*, void*))objc_msgSend)((void*)objc_getClass("NSTrackingArea"),
		sel_registerName("alloc"));
	ui2_macos_rect zero = { 0, 0, 0, 0 };
	area = ((void* (*)(void*, void*, ui2_macos_rect, unsigned long, void*, void*))objc_msgSend)(area,
		sel_registerName("initWithRect:options:owner:userInfo:"), zero,
		entered_and_exited | moved | active_in_app | in_visible_rect, view, (void*)0);
	if (area == (void*)0) return;
	((void (*)(void*, void*, void*))objc_msgSend)(view, sel_registerName("addTrackingArea:"), area);
	((void (*)(void*, void*))objc_msgSend)(area, sel_registerName("release"));
}

// CALayer's shadowOpacity is a float, which the bridge's double setters would
// pass in the wrong register width.
static inline void ui2_macos_msg_void_float(void* obj, void* sel, float value) {
	((void (*)(void*, void*, float))objc_msgSend)(obj, sel, value);
}

// CoreGraphics' path functions are looked up at run time: tcc cannot read the
// CoreGraphics headers, and declaring the functions here would clash with those
// headers wherever an application includes them. CGRect is four CGFloats, laid
// out like ui2_macos_rect.
typedef void* (*ui2_macos_rounded_path_fn)(ui2_macos_rect rect, double corner_width,
	double corner_height, const void* transform);
typedef void (*ui2_macos_release_path_fn)(void* path);

// Gives a layer the rounded-rectangle shadow path of a box, so CoreAnimation draws
// the shadow from that shape instead of from the layer's rendered content, which a
// transparent box does not have. CGPathCreateWithRoundedRect rejects corners
// larger than half a side, so the radius is clamped.
static inline void ui2_macos_set_shadow_path(void* layer, double x, double y, double width,
		double height, double radius) {
	void* set = sel_registerName("setShadowPath:");
	if (width <= 0 || height <= 0) {
		((void (*)(void*, void*, void*))objc_msgSend)(layer, set, (void*)0);
		return;
	}
	double limit = (width < height ? width : height) / 2;
	double r = radius < 0 ? 0 : (radius > limit ? limit : radius);
	static ui2_macos_rounded_path_fn create = (void*)0;
	static ui2_macos_release_path_fn release = (void*)0;
	if (create == (void*)0) {
		create = (ui2_macos_rounded_path_fn)dlsym(RTLD_DEFAULT, "CGPathCreateWithRoundedRect");
		release = (ui2_macos_release_path_fn)dlsym(RTLD_DEFAULT, "CGPathRelease");
	}
	if (create == (void*)0 || release == (void*)0) return;
	ui2_macos_rect rect = { x, y, width, height };
	void* path = create(rect, r, r, (void*)0);
	((void (*)(void*, void*, void*))objc_msgSend)(layer, set, path);
	release(path);
}

// Builds a CGPath from ui2 path commands and gives it to a CAShapeLayer. The
// commands are packed seven doubles each: verb (move, line, quad, cubic,
// close), x, y and the control points. CGFloat is a double here.
typedef void* (*ui2_macos_path_create_fn)(void);
typedef void (*ui2_macos_path_point_fn)(void* path, const void* transform, double x, double y);
typedef void (*ui2_macos_path_quad_fn)(void* path, const void* transform, double cx, double cy,
	double x, double y);
typedef void (*ui2_macos_path_cubic_fn)(void* path, const void* transform, double c1x,
	double c1y, double c2x, double c2y, double x, double y);
typedef void (*ui2_macos_path_close_fn)(void* path);

static inline void ui2_macos_set_shape_path(void* layer, const double* commands, int count) {
	static ui2_macos_path_create_fn create = (void*)0;
	static ui2_macos_path_point_fn move = (void*)0;
	static ui2_macos_path_point_fn line = (void*)0;
	static ui2_macos_path_quad_fn quad = (void*)0;
	static ui2_macos_path_cubic_fn cubic = (void*)0;
	static ui2_macos_path_close_fn close_subpath = (void*)0;
	static ui2_macos_release_path_fn release = (void*)0;
	if (create == (void*)0) {
		create = (ui2_macos_path_create_fn)dlsym(RTLD_DEFAULT, "CGPathCreateMutable");
		move = (ui2_macos_path_point_fn)dlsym(RTLD_DEFAULT, "CGPathMoveToPoint");
		line = (ui2_macos_path_point_fn)dlsym(RTLD_DEFAULT, "CGPathAddLineToPoint");
		quad = (ui2_macos_path_quad_fn)dlsym(RTLD_DEFAULT, "CGPathAddQuadCurveToPoint");
		cubic = (ui2_macos_path_cubic_fn)dlsym(RTLD_DEFAULT, "CGPathAddCurveToPoint");
		close_subpath = (ui2_macos_path_close_fn)dlsym(RTLD_DEFAULT, "CGPathCloseSubpath");
		release = (ui2_macos_release_path_fn)dlsym(RTLD_DEFAULT, "CGPathRelease");
	}
	if (create == (void*)0 || move == (void*)0 || line == (void*)0 || quad == (void*)0
			|| cubic == (void*)0 || close_subpath == (void*)0 || release == (void*)0) {
		return;
	}
	void* path = create();
	int started = 0;
	for (int i = 0; i < count; i++) {
		const double* c = commands + i * 7;
		int verb = (int)c[0];
		if (verb != 0 && verb != 4 && !started) {
			// CoreGraphics needs a current point before a line or curve.
			move(path, (void*)0, c[1], c[2]);
			started = 1;
			if (verb == 1) continue;
		}
		switch (verb) {
			case 0: move(path, (void*)0, c[1], c[2]); started = 1; break;
			case 1: line(path, (void*)0, c[1], c[2]); break;
			case 2: quad(path, (void*)0, c[3], c[4], c[1], c[2]); break;
			case 3: cubic(path, (void*)0, c[3], c[4], c[5], c[6], c[1], c[2]); break;
			case 4: if (started) close_subpath(path); break;
		}
	}
	((void (*)(void*, void*, void*))objc_msgSend)(layer, sel_registerName("setPath:"), path);
	release(path);
}

// -[NSCell drawingRectForBounds:] sent to the superclass, for the text field cell
// ui2 subclasses: it takes and answers a rectangle (see ui2_macos_msg_rect_rect).
static inline ui2_macos_rect ui2_macos_msg_super_rect_rect(void* obj, void* superclass,
		void* sel, ui2_macos_rect rect) {
	struct {
		void* receiver;
		void* super_class;
	} target = { obj, superclass };
#if defined(__x86_64__)
	ui2_macos_rect result;
	((void (*)(ui2_macos_rect*, void*, void*, ui2_macos_rect))objc_msgSendSuper_stret)(&result,
		&target, sel, rect);
	return result;
#else
	return ((ui2_macos_rect (*)(void*, void*, ui2_macos_rect))objc_msgSendSuper)(&target, sel, rect);
#endif
}

// -[NSTextFieldCell editWithFrame:inView:editor:delegate:event:] to the superclass.
static inline void ui2_macos_msg_super_cell_edit(void* obj, void* superclass, void* sel,
		ui2_macos_rect rect, void* view, void* editor, void* delegate, void* event) {
	struct {
		void* receiver;
		void* super_class;
	} target = { obj, superclass };
	((void (*)(void*, void*, ui2_macos_rect, void*, void*, void*, void*))objc_msgSendSuper)(
		&target, sel, rect, view, editor, delegate, event);
}

// -[NSTextFieldCell selectWithFrame:inView:editor:delegate:start:length:] to the
// superclass.
static inline void ui2_macos_msg_super_cell_select(void* obj, void* superclass, void* sel,
		ui2_macos_rect rect, void* view, void* editor, void* delegate, long start, long length) {
	struct {
		void* receiver;
		void* super_class;
	} target = { obj, superclass };
	((void (*)(void*, void*, ui2_macos_rect, void*, void*, void*, long, long))objc_msgSendSuper)(
		&target, sel, rect, view, editor, delegate, start, length);
}
