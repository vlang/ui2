#ifndef UI2_SOKOL_FRAME_COMPAT_H
#define UI2_SOKOL_FRAME_COMPAT_H
#include <stdbool.h>

/* Older Sokol releases have no on-demand hooks. Weak imports let those builds
   retain continuous presentation while newer builds keep sleeping and waking. */
#if defined(__unix__) || defined(__APPLE__)
#ifdef __APPLE__
#define UI2_SAPP_OPTIONAL __attribute__((weak_import))
#else
#define UI2_SAPP_OPTIONAL __attribute__((weak))
#endif
extern bool sapp_set_present_on_demand(bool) UI2_SAPP_OPTIONAL;
extern void sapp_request_present(void) UI2_SAPP_OPTIONAL;
extern void sapp_set_frame_deadline_cb(double (*)(void)) UI2_SAPP_OPTIONAL;
extern void sapp_wake(void) UI2_SAPP_OPTIONAL;
#endif

static inline bool ui2_sapp_set_present_on_demand(bool enabled) {
#if defined(__unix__) || defined(__APPLE__)
    if (sapp_set_present_on_demand && sapp_request_present &&
        sapp_set_frame_deadline_cb && sapp_wake) {
        return sapp_set_present_on_demand(enabled);
    }
#endif
    return false;
}

static inline void ui2_sapp_request_present(void) {
#if defined(__unix__) || defined(__APPLE__)
    if (sapp_request_present) sapp_request_present();
#endif
}

static inline void ui2_sapp_set_frame_deadline_cb(double (*cb)(void)) {
#if defined(__unix__) || defined(__APPLE__)
    /* Install a sleeping loop only when it can also be woken by workers. */
    if (sapp_set_frame_deadline_cb && sapp_wake &&
        sapp_set_present_on_demand && sapp_request_present) {
        sapp_set_frame_deadline_cb(cb);
    }
#endif
}

static inline void ui2_sapp_wake(void) {
#if defined(__unix__) || defined(__APPLE__)
    if (sapp_wake) sapp_wake();
#endif
}
#endif
