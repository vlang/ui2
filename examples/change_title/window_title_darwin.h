#ifndef UI2_EXAMPLE_WINDOW_TITLE_DARWIN_H
#define UI2_EXAMPLE_WINDOW_TITLE_DARWIN_H

#import <Cocoa/Cocoa.h>

static inline void ui2_example_set_window_title(const char *title) {
	NSWindow *window = [NSApp keyWindow];
	if (window != nil && title != NULL) {
		[window setTitle:[NSString stringWithUTF8String:title]];
	}
}

#endif
