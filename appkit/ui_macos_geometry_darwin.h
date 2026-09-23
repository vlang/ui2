#include <objc/message.h>

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
