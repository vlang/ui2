#ifndef UI2_DARWIN_BRIDGE_H
#define UI2_DARWIN_BRIDGE_H
#include <stdbool.h>
#include <stdint.h>
#include <objc/message.h>

typedef struct { double x, y; } ui2_darwin_point;
typedef struct { uint64_t location, length; } ui2_darwin_range;
typedef struct { double x, y, width, height; } ui2_darwin_rect;

/* Typed Objective-C sends for bridge signatures absent in older V releases. */
static inline ui2_darwin_point ui2_darwin_msg_point(void* obj, void* sel) {
	return ((ui2_darwin_point (*)(void*, void*))objc_msgSend)(obj, sel);
}

static inline bool ui2_darwin_msg_bool_id(void* obj, void* sel, void* a0) {
	return ((bool (*)(void*, void*, void*))objc_msgSend)(obj, sel, a0);
}

static inline void ui2_darwin_msg_void_point(void* obj, void* sel, ui2_darwin_point p) {
	((void (*)(void*, void*, ui2_darwin_point))objc_msgSend)(obj, sel, p);
}

static inline void* ui2_darwin_msg_id_four_f64(void* obj, void* sel, double a0, double a1, double a2, double a3) {
	return ((void* (*)(void*, void*, double, double, double, double))objc_msgSend)(obj, sel, a0, a1, a2, a3);
}

static inline void* ui2_darwin_msg_id_id_u64(void* obj, void* sel, void* a0, uint64_t a1) {
	return ((void* (*)(void*, void*, void*, uint64_t))objc_msgSend)(obj, sel, a0, a1);
}

static inline ui2_darwin_range ui2_darwin_msg_range(void* obj, void* sel) {
	return ((ui2_darwin_range (*)(void*, void*))objc_msgSend)(obj, sel);
}

static inline ui2_darwin_point ui2_darwin_msg_point_point_id(void* obj, void* sel, ui2_darwin_point value, void* a1) {
	return ((ui2_darwin_point (*)(void*, void*, ui2_darwin_point, void*))objc_msgSend)(obj, sel, value, a1);
}

static inline bool ui2_darwin_msg_bool_id_bool(void* obj, void* sel, void* a0, bool a1) {
	return ((bool (*)(void*, void*, void*, bool))objc_msgSend)(obj, sel, a0, a1);
}

static inline bool ui2_darwin_msg_bool_sel_id_id(void* obj, void* sel, void* a0, void* a1, void* a2) {
	return ((bool (*)(void*, void*, void*, void*, void*))objc_msgSend)(obj, sel, a0, a1, a2);
}

static inline void* ui2_darwin_msg_id_rect_u64_u64_bool(void* obj, void* sel, ui2_darwin_rect rect, uint64_t a1, uint64_t a2, bool a3) {
	return ((void* (*)(void*, void*, ui2_darwin_rect, uint64_t, uint64_t, bool))objc_msgSend)(obj, sel, rect, a1, a2, a3);
}

static inline void* ui2_darwin_msg_id_id_f64(void* obj, void* sel, void* a0, double a1) {
	return ((void* (*)(void*, void*, void*, double))objc_msgSend)(obj, sel, a0, a1);
}

static inline void* ui2_darwin_msg_id_id_u64_i64_f64(void* obj, void* sel, void* a0, uint64_t a1, int64_t a2, double a3) {
	return ((void* (*)(void*, void*, void*, uint64_t, int64_t, double))objc_msgSend)(obj, sel, a0, a1, a2, a3);
}

static inline void* ui2_darwin_msg_id_u64_id(void* obj, void* sel, uint64_t a0, void* a1) {
	return ((void* (*)(void*, void*, uint64_t, void*))objc_msgSend)(obj, sel, a0, a1);
}

static inline void* ui2_darwin_msg_id_u64_range_ptr(void* obj, void* sel, uint64_t a0, ui2_darwin_range* range_ptr) {
	return ((void* (*)(void*, void*, uint64_t, ui2_darwin_range*))objc_msgSend)(obj, sel, a0, range_ptr);
}

static inline void* ui2_darwin_msg_id_id_u64_range_ptr(void* obj, void* sel, void* a0, uint64_t a1, ui2_darwin_range* range_ptr) {
	return ((void* (*)(void*, void*, void*, uint64_t, ui2_darwin_range*))objc_msgSend)(obj, sel, a0, a1, range_ptr);
}

static inline void* ui2_darwin_msg_id_range(void* obj, void* sel, ui2_darwin_range value) {
	return ((void* (*)(void*, void*, ui2_darwin_range))objc_msgSend)(obj, sel, value);
}

static inline uint64_t ui2_darwin_msg_u64_id(void* obj, void* sel, void* a0) {
	return ((uint64_t (*)(void*, void*, void*))objc_msgSend)(obj, sel, a0);
}

static inline void ui2_darwin_msg_void_id_i64_id(void* obj, void* sel, void* a0, int64_t a1, void* a2) {
	((void (*)(void*, void*, void*, int64_t, void*))objc_msgSend)(obj, sel, a0, a1, a2);
}

static inline void ui2_darwin_msg_void_id_range(void* obj, void* sel, void* a0, ui2_darwin_range value) {
	((void (*)(void*, void*, void*, ui2_darwin_range))objc_msgSend)(obj, sel, a0, value);
}

static inline void ui2_darwin_msg_void_id_id_range(void* obj, void* sel, void* a0, void* a1, ui2_darwin_range value) {
	((void (*)(void*, void*, void*, void*, ui2_darwin_range))objc_msgSend)(obj, sel, a0, a1, value);
}

static inline void ui2_darwin_msg_void_range(void* obj, void* sel, ui2_darwin_range value) {
	((void (*)(void*, void*, ui2_darwin_range))objc_msgSend)(obj, sel, value);
}

static inline void ui2_darwin_msg_void_rect_id(void* obj, void* sel, ui2_darwin_rect rect, void* a1) {
	((void (*)(void*, void*, ui2_darwin_rect, void*))objc_msgSend)(obj, sel, rect, a1);
}

static inline void ui2_darwin_msg_void_id_sel_id_id(void* obj, void* sel, void* a0, void* a1, void* a2, void* a3) {
	((void (*)(void*, void*, void*, void*, void*, void*))objc_msgSend)(obj, sel, a0, a1, a2, a3);
}

static inline void ui2_darwin_msg_void_sel_id_bool(void* obj, void* sel, void* a0, void* a1, bool a2) {
	((void (*)(void*, void*, void*, void*, bool))objc_msgSend)(obj, sel, a0, a1, a2);
}

#endif
