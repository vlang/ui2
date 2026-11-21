// Typed Objective-C bridge for ui/platform_darwin.v.
//
// vlib/macos has no void sender that takes two NSInteger arguments, but
// -[NSHapticFeedbackPerformer performFeedbackPattern:performanceTime:] needs
// exactly that. This is plain C: no Objective-C syntax and no blocks, so it
// also builds with tcc and when ui2's generated C is compiled as Objective-C
// with ARC. Both arguments are NSInteger, i.e. long long on 64-bit macOS.
#ifndef UI2_PLATFORM_DARWIN_H
#define UI2_PLATFORM_DARWIN_H

#include <objc/message.h>
#include <objc/runtime.h>

static inline void ui2_platform_perform_feedback(void* performer, long long pattern,
	long long performance_time) {
	((void (*)(void*, void*, long long, long long))objc_msgSend)(
		performer, sel_registerName("performFeedbackPattern:performanceTime:"),
		pattern, performance_time);
}

#endif
