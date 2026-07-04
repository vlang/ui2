#import <Cocoa/Cocoa.h>
#include <dispatch/dispatch.h>

static inline void* ui2_nscolor_rgb(unsigned int hex) {
	double r = ((hex >> 16) & 0xff) / 255.0;
	double g = ((hex >> 8) & 0xff) / 255.0;
	double b = (hex & 0xff) / 255.0;
	return (__bridge void*)[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

typedef void (*ui2_void_cb)(void);

static void ui2_dispatch_main_trampoline(void* ctx) {
	((ui2_void_cb)ctx)();
}

// Runs cb on the main queue; safe to call from any thread.
static inline void ui2_dispatch_main(ui2_void_cb cb) {
	dispatch_async_f(dispatch_get_main_queue(), (void*)cb, ui2_dispatch_main_trampoline);
}

// Subscribes observer's ui2BoundsChanged: to a clip view's bounds changes.
static inline void ui2_observe_bounds(void* observer, void* view) {
	[[NSNotificationCenter defaultCenter] addObserver:(__bridge id)observer
	                                         selector:@selector(ui2BoundsChanged:)
	                                             name:NSViewBoundsDidChangeNotification
	                                           object:(__bridge id)view];
}
