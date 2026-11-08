#ifndef UI2_SCHEDULER_LIFECYCLE_DARWIN_H
#define UI2_SCHEDULER_LIFECYCLE_DARWIN_H

#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

// Keep these calls in plain C so the fixture works with both ARC and non-ARC
// generated sources. The opaque pointer has one explicit retain across the
// main-queue timer; no Objective-C ownership conversion is implicit here.
static void ui2_scheduler_restore_window(void *window) {
    ((void (*)(void *, SEL, void *))objc_msgSend)(
        window, sel_registerName("deminiaturize:"), NULL);
    ((void (*)(void *, SEL, void *))objc_msgSend)(
        window, sel_registerName("makeKeyAndOrderFront:"), NULL);
    ((void (*)(void *, SEL))objc_msgSend)(window, sel_registerName("release"));
}

static bool ui2_scheduler_minimize_restore(void *window, int64_t delay_ms) {
    if (window == NULL || delay_ms <= 0 || !pthread_main_np()) {
        return false;
    }
    ((void *(*)(void *, SEL))objc_msgSend)(window, sel_registerName("retain"));
    ((void (*)(void *, SEL, void *))objc_msgSend)(
        window, sel_registerName("miniaturize:"), NULL);
    dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, delay_ms * NSEC_PER_MSEC),
                     dispatch_get_main_queue(), window, ui2_scheduler_restore_window);
    return true;
}

#endif
