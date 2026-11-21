#ifndef UI2_PLATFORM_IOS_H
#define UI2_PLATFORM_IOS_H

#include <stddef.h>
#include <objc/message.h>
#include <objc/runtime.h>

// Return an owned NSString; the caller releases it after the items array
// retains it. NSUTF8StringEncoding is 4. An explicit length preserves NULs.
static inline void *ui2_platform_ios_string(const void *bytes, size_t length) {
	void *allocated = ((void *(*)(void *, void *))objc_msgSend)(
		(void *)objc_getClass("NSString"), sel_registerName("alloc"));
	return ((void *(*)(void *, void *, const void *, size_t, size_t))objc_msgSend)(
		allocated, sel_registerName("initWithBytes:length:encoding:"), bytes, length, 4);
}

#endif
