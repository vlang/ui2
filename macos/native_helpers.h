#import <Cocoa/Cocoa.h>
#include <dispatch/dispatch.h>

static inline NSColor* ui2_nscolor_obj(unsigned int hex) {
	double r = ((hex >> 16) & 0xff) / 255.0;
	double g = ((hex >> 8) & 0xff) / 255.0;
	double b = (hex & 0xff) / 255.0;
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
}

static inline void* ui2_nscolor_rgb(unsigned int hex) {
	return (__bridge void*)ui2_nscolor_obj(hex);
}

static inline NSFont* ui2_font_obj(double size, bool bold, bool italic) {
	NSFont *font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
	if (italic) {
		NSFont *italic_font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
		if (italic_font != nil) {
			font = italic_font;
		}
	}
	return font;
}

static inline unsigned long ui2_utf16_length(const char* utf8) {
	if (utf8 == NULL) {
		return 0;
	}
	NSString *s = [NSString stringWithUTF8String:utf8];
	if (s == nil) {
		return 0;
	}
	return (unsigned long)[s length];
}

static inline NSDictionary* ui2_text_attrs(unsigned int color, double size, bool bold, bool italic, bool underline) {
	NSMutableDictionary *attrs = [@{
		NSFontAttributeName: ui2_font_obj(size, bold, italic),
		NSForegroundColorAttributeName: ui2_nscolor_obj(color)
	} mutableCopy];
	if (underline) {
		attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
	}
	return [attrs autorelease];
}

static inline void ui2_text_view_set_attributed_string(void* tv_ptr, const char* utf8, unsigned int color, double size, bool bold, bool italic, bool underline) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return;
	}
	NSString *s = utf8 == NULL ? @"" : [NSString stringWithUTF8String:utf8];
	if (s == nil) {
		s = @"";
	}
	NSMutableAttributedString *attr = [[[NSMutableAttributedString alloc] initWithString:s attributes:ui2_text_attrs(color, size, bold, italic, underline)] autorelease];
	[[tv textStorage] setAttributedString:attr];
}

static inline void ui2_text_view_add_style(void* tv_ptr, unsigned long location, unsigned long length, unsigned int color, double size, bool bold, bool italic, bool underline) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil || length == 0) {
		return;
	}
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || location >= [storage length]) {
		return;
	}
	NSUInteger safe_len = MIN((NSUInteger)length, [storage length] - (NSUInteger)location);
	[storage addAttributes:ui2_text_attrs(color, size, bold, italic, underline) range:NSMakeRange((NSUInteger)location, safe_len)];
}

static inline void ui2_control_set_attributed_title(void* control_ptr, const char* utf8, unsigned int color, double size, bool bold, bool italic, bool underline) {
	NSControl *control = (__bridge NSControl*)control_ptr;
	if (control == nil) {
		return;
	}
	NSString *s = utf8 == NULL ? @"" : [NSString stringWithUTF8String:utf8];
	if (s == nil) {
		s = @"";
	}
	NSAttributedString *attr = [[[NSAttributedString alloc] initWithString:s attributes:ui2_text_attrs(color, size, bold, italic, underline)] autorelease];
	if ([control respondsToSelector:@selector(setAttributedTitle:)]) {
		[(id)control setAttributedTitle:attr];
	} else if ([control respondsToSelector:@selector(setAttributedStringValue:)]) {
		[(id)control setAttributedStringValue:attr];
	}
}

static inline NSTextView* ui2_text_view_obj(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return nil;
	}
	[tv setRichText:YES];
	[[tv window] makeFirstResponder:tv];
	return tv;
}

static inline void ui2_text_view_set_selected_range(void* tv_ptr, unsigned long location, unsigned long length) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return;
	}
	NSString *text = [tv string];
	NSUInteger text_len = text == nil ? 0 : [text length];
	NSUInteger safe_location = MIN((NSUInteger)location, text_len);
	NSUInteger safe_length = MIN((NSUInteger)length, text_len - safe_location);
	[[tv window] makeFirstResponder:tv];
	NSRange range = NSMakeRange(safe_location, safe_length);
	[tv setSelectedRange:range];
	[tv scrollRangeToVisible:range];
}

static inline NSDictionary* ui2_text_view_current_attrs(NSTextView *tv) {
	if (tv == nil) {
		return nil;
	}
	NSRange selected = [tv selectedRange];
	NSTextStorage *storage = [tv textStorage];
	if (selected.length == 0) {
		NSDictionary *typing = [tv typingAttributes];
		if (typing != nil && [typing count] > 0) {
			return typing;
		}
	}
	if (storage != nil && [storage length] > 0) {
		NSUInteger index = selected.location;
		if (index >= [storage length]) {
			index = [storage length] - 1;
		}
		return [storage attributesAtIndex:index effectiveRange:NULL];
	}
	return [tv typingAttributes];
}

static inline bool ui2_text_view_format_active(void* tv_ptr, int format) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	NSDictionary *attrs = ui2_text_view_current_attrs(tv);
	if (attrs == nil) {
		return false;
	}
	if (format == 2) {
		NSNumber *underline = attrs[NSUnderlineStyleAttributeName];
		return underline != nil && [underline integerValue] != 0;
	}
	NSFont *font = attrs[NSFontAttributeName];
	if (font == nil) {
		return false;
	}
	NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont:font];
	if (format == 0) {
		return (traits & NSBoldFontMask) != 0;
	}
	if (format == 1) {
		return (traits & NSItalicFontMask) != 0;
	}
	return false;
}

static inline NSFont* ui2_font_with_format(NSFont *font, int format, bool enabled, double fallback_size) {
	if (font == nil) {
		if (fallback_size <= 0) {
			fallback_size = [NSFont systemFontSize];
		}
		font = [NSFont systemFontOfSize:fallback_size];
	}
	NSFontTraitMask trait = format == 0 ? NSBoldFontMask : NSItalicFontMask;
	NSFontManager *manager = [NSFontManager sharedFontManager];
	NSFont *converted = enabled
		? [manager convertFont:font toHaveTrait:trait]
		: [manager convertFont:font toNotHaveTrait:trait];
	return converted == nil ? font : converted;
}

static inline void ui2_apply_typing_format(NSTextView *tv, int format, bool enabled) {
	NSMutableDictionary *attrs = [[tv typingAttributes] mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	if (format == 2) {
		if (enabled) {
			attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
		} else {
			[attrs removeObjectForKey:NSUnderlineStyleAttributeName];
		}
	} else {
		NSFont *font = attrs[NSFontAttributeName];
		if (font == nil) {
			font = [tv font];
		}
		attrs[NSFontAttributeName] = ui2_font_with_format(font, format, enabled, [tv font] == nil ? [NSFont systemFontSize] : [[tv font] pointSize]);
	}
	[tv setTypingAttributes:attrs];
	[attrs release];
}

static inline void ui2_apply_range_format(NSTextView *tv, NSRange range, int format, bool enabled) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	[storage beginEditing];
	if (format == 2) {
		if (enabled) {
			[storage addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
		} else {
			[storage removeAttribute:NSUnderlineStyleAttributeName range:range];
		}
	} else {
		NSUInteger end = NSMaxRange(range);
		NSUInteger cursor = range.location;
		while (cursor < end) {
			NSRange effective = NSMakeRange(cursor, end - cursor);
			NSFont *font = [storage attribute:NSFontAttributeName atIndex:cursor longestEffectiveRange:&effective inRange:range];
			NSRange apply = NSIntersectionRange(effective, range);
			if (apply.length == 0) {
				apply = NSMakeRange(cursor, 1);
			}
			NSFont *converted = ui2_font_with_format(font == nil ? [tv font] : font, format, enabled, [tv font] == nil ? [NSFont systemFontSize] : [[tv font] pointSize]);
			[storage addAttribute:NSFontAttributeName value:converted range:apply];
			cursor = NSMaxRange(apply);
		}
	}
	[storage endEditing];
	[tv setSelectedRange:range];
}

static inline void ui2_text_view_toggle_format(void* tv_ptr, int format) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	bool enabled = !ui2_text_view_format_active(tv_ptr, format);
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_format(tv, format, enabled);
		return;
	}
	ui2_apply_range_format(tv, selected, format, enabled);
}

static inline bool ui2_view_save_png(void* view_ptr, const char* path) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil || path == NULL) {
		return false;
	}
	NSString *out_path = [NSString stringWithUTF8String:path];
	if (out_path == nil || [out_path length] == 0) {
		return false;
	}
	NSRect bounds = [view bounds];
	if (NSWidth(bounds) <= 0 || NSHeight(bounds) <= 0) {
		return false;
	}
	[view layoutSubtreeIfNeeded];
	[view displayIfNeeded];
	NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:bounds];
	if (rep == nil) {
		return false;
	}
	[view cacheDisplayInRect:bounds toBitmapImageRep:rep];
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	if (png == nil || [png length] == 0) {
		return false;
	}
	return [png writeToFile:out_path atomically:YES];
}

static inline NSImage* ui2_pasteboard_image(void) {
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSArray *objects = [pasteboard readObjectsForClasses:@[[NSImage class]] options:@{}];
	if (objects == nil || [objects count] == 0) {
		return nil;
	}
	NSImage *image = [objects objectAtIndex:0];
	return image;
}

static inline bool ui2_pasteboard_has_image(void) {
	return ui2_pasteboard_image() != nil;
}

static inline bool ui2_pasteboard_write_image_png(const char* path) {
	if (path == NULL) {
		return false;
	}
	NSImage *image = ui2_pasteboard_image();
	if (image == nil) {
		return false;
	}
	NSData *tiff = [image TIFFRepresentation];
	if (tiff == nil || [tiff length] == 0) {
		return false;
	}
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
	if (rep == nil) {
		return false;
	}
	NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
	if (png == nil || [png length] == 0) {
		return false;
	}
	NSString *out_path = [NSString stringWithUTF8String:path];
	if (out_path == nil || [out_path length] == 0) {
		return false;
	}
	return [png writeToFile:out_path atomically:YES];
}

static inline bool ui2_app_send_edit_command(int command) {
	SEL action = NULL;
	switch (command) {
		case 0:
			action = @selector(selectAll:);
			break;
		case 1:
			action = @selector(cut:);
			break;
		case 2:
			action = @selector(copy:);
			break;
		case 3:
			action = @selector(paste:);
			break;
		case 4:
			action = @selector(undo:);
			break;
		case 5:
			action = @selector(redo:);
			break;
		default:
			return false;
	}
	return [[NSApplication sharedApplication] sendAction:action to:nil from:nil];
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
