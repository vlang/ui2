#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <dispatch/dispatch.h>
#include <string.h>

typedef struct {
	unsigned int hex;
	NSColor *color;
} UI2ColorCacheEntry;

static inline NSColor* ui2_nscolor_obj(unsigned int hex) {
	static UI2ColorCacheEntry cache[512];
	unsigned int index = (hex * 2654435761u) % (sizeof(cache) / sizeof(cache[0]));
	if (cache[index].color != nil && cache[index].hex == hex) {
		return cache[index].color;
	}
	double r = ((hex >> 16) & 0xff) / 255.0;
	double g = ((hex >> 8) & 0xff) / 255.0;
	double b = (hex & 0xff) / 255.0;
	NSColor *color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0];
	if (cache[index].color != nil) {
		[cache[index].color release];
	}
	cache[index].hex = hex;
	cache[index].color = [color retain];
	return color;
}

static inline unsigned int ui2_nscolor_hex(NSColor *color, unsigned int fallback) {
	if (color == nil) {
		return fallback;
	}
	NSColor *rgb = [color colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
	if (rgb == nil) {
		return fallback;
	}
	CGFloat red = 0.0;
	CGFloat green = 0.0;
	CGFloat blue = 0.0;
	CGFloat alpha = 0.0;
	[rgb getRed:&red green:&green blue:&blue alpha:&alpha];
	unsigned int r = (unsigned int)llround(MAX(0.0, MIN(1.0, red)) * 255.0);
	unsigned int g = (unsigned int)llround(MAX(0.0, MIN(1.0, green)) * 255.0);
	unsigned int b = (unsigned int)llround(MAX(0.0, MIN(1.0, blue)) * 255.0);
	return (r << 16) | (g << 8) | b;
}

static inline void* ui2_nscolor_rgb(unsigned int hex) {
	return (__bridge void*)ui2_nscolor_obj(hex);
}

static inline void* ui2_image_from_name(const char* raw) {
	if (raw == NULL) {
		return nil;
	}
	NSString *name = [NSString stringWithUTF8String:raw];
	if (name == nil || [name length] == 0) {
		return nil;
	}
	if ([name hasPrefix:@"symbol:"]) {
		NSString *symbol = [name substringFromIndex:[@"symbol:" length]];
		if ([NSImage respondsToSelector:@selector(imageWithSystemSymbolName:accessibilityDescription:)]) {
			NSImage *symbolImage = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
			if (symbolImage != nil) {
				return (__bridge void*)symbolImage;
			}
		}
	}
	NSImage *fileImage = [[[NSImage alloc] initWithContentsOfFile:name] autorelease];
	if (fileImage != nil) {
		return (__bridge void*)fileImage;
	}
	return (__bridge void*)[NSImage imageNamed:name];
}

static inline void* ui2_image_from_name_sized(const char* raw, double width, double height) {
	NSImage *image = (__bridge NSImage*)ui2_image_from_name(raw);
	if (image == nil) {
		return nil;
	}
	NSImage *sized = [[image copy] autorelease];
	[sized setSize:NSMakeSize(width, height)];
	[sized setTemplate:[image isTemplate]];
	return (__bridge void*)sized;
}

typedef struct {
	double size;
	bool bold;
	bool italic;
	NSFont *font;
} UI2FontCacheEntry;

static inline NSFont* ui2_font_obj(double size, bool bold, bool italic) {
	static UI2FontCacheEntry cache[64];
	static unsigned int cache_count = 0;
	for (unsigned int index = 0; index < cache_count; index++) {
		if (cache[index].size == size && cache[index].bold == bold
			&& cache[index].italic == italic) {
			return cache[index].font;
		}
	}
	NSFont *font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
	if (italic) {
		NSFont *italic_font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
		if (italic_font != nil) {
			font = italic_font;
		}
	}
	if (cache_count < sizeof(cache) / sizeof(cache[0])) {
		cache[cache_count].size = size;
		cache[cache_count].bold = bold;
		cache[cache_count].italic = italic;
		cache[cache_count].font = [font retain];
		cache_count++;
	}
	return font;
}

static inline void* ui2_font(double size, bool bold, bool italic) {
	return (__bridge void*)ui2_font_obj(size, bold, italic);
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

static inline NSCursor* ui2_private_cursor(NSString *selector_name, NSCursor *fallback) {
	SEL selector = NSSelectorFromString(selector_name);
	if ([NSCursor respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		NSCursor *cursor = [NSCursor performSelector:selector];
#pragma clang diagnostic pop
		if (cursor != nil) {
			return cursor;
		}
	}
	return fallback;
}

static inline NSCursor* ui2_cursor_for_name(const char* raw) {
	if (raw == NULL || raw[0] == '\0') {
		return [NSCursor arrowCursor];
	}
	if (strcmp(raw, "pointing_hand") == 0) {
		return [NSCursor pointingHandCursor];
	}
	if (strcmp(raw, "resize_nwse") == 0) {
		return ui2_private_cursor(@"_windowResizeNorthWestSouthEastCursor", [NSCursor crosshairCursor]);
	}
	if (strcmp(raw, "resize_nesw") == 0) {
		return ui2_private_cursor(@"_windowResizeNorthEastSouthWestCursor", [NSCursor crosshairCursor]);
	}
	if (strcmp(raw, "resize_ew") == 0) {
		return [NSCursor resizeLeftRightCursor];
	}
	if (strcmp(raw, "resize_ns") == 0) {
		return [NSCursor resizeUpDownCursor];
	}
	if (strcmp(raw, "rotate") == 0) {
		return [NSCursor openHandCursor];
	}
	return [NSCursor arrowCursor];
}

static inline void ui2_add_cursor_rect(void* view_ptr, const char* raw) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil) {
		return;
	}
	[view addCursorRect:[view bounds] cursor:ui2_cursor_for_name(raw)];
}

static inline void ui2_invalidate_cursor_rects(void* view_ptr) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil || [view window] == nil) {
		return;
	}
	[[view window] invalidateCursorRectsForView:view];
}

static inline NSString* ui2_base64_utf8(NSString *s) {
	if (s == nil) {
		s = @"";
	}
	NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
	if (data == nil) {
		data = [NSData data];
	}
	return [data base64EncodedStringWithOptions:0];
}

static inline void ui2_register_drop_types(void *view_ptr) {
	NSView *view = (__bridge NSView *)view_ptr;
	if (view == nil) {
		return;
	}
	[view registerForDraggedTypes:@[NSPasteboardTypeFileURL, NSPasteboardTypeString]];
}

static inline NSPasteboard *ui2_dragging_pasteboard(void *dragging_info_ptr) {
	id<NSDraggingInfo> info = (__bridge id<NSDraggingInfo>)dragging_info_ptr;
	return info == nil ? nil : [info draggingPasteboard];
}

static inline NSArray<NSURL *> *ui2_dragging_file_urls(void *dragging_info_ptr) {
	NSPasteboard *pasteboard = ui2_dragging_pasteboard(dragging_info_ptr);
	if (pasteboard == nil) {
		return @[];
	}
	NSDictionary *options = @{NSPasteboardURLReadingFileURLsOnlyKey: @YES};
	NSArray *urls = [pasteboard readObjectsForClasses:@[[NSURL class]] options:options];
	return urls ?: @[];
}

static inline unsigned long ui2_dragging_file_count(void *dragging_info_ptr) {
	return (unsigned long)[ui2_dragging_file_urls(dragging_info_ptr) count];
}

static inline const char *ui2_dragging_file_path(void *dragging_info_ptr, unsigned long index) {
	NSArray<NSURL *> *urls = ui2_dragging_file_urls(dragging_info_ptr);
	if (index >= [urls count]) {
		return "";
	}
	const char *path = [[[urls objectAtIndex:index] path] UTF8String];
	return path == NULL ? "" : path;
}

static inline const char *ui2_dragging_text(void *dragging_info_ptr) {
	NSPasteboard *pasteboard = ui2_dragging_pasteboard(dragging_info_ptr);
	if (pasteboard == nil) {
		return "";
	}
	NSString *text = [pasteboard stringForType:NSPasteboardTypeString] ?: @"";
	const char *utf8 = [text UTF8String];
	return utf8 == NULL ? "" : utf8;
}

static inline double ui2_dragging_x_in_view(void *view_ptr, void *dragging_info_ptr) {
	NSView *view = (__bridge NSView *)view_ptr;
	id<NSDraggingInfo> info = (__bridge id<NSDraggingInfo>)dragging_info_ptr;
	if (view == nil || info == nil) {
		return 0.0;
	}
	return [view convertPoint:[info draggingLocation] fromView:nil].x;
}

static inline double ui2_dragging_y_in_view(void *view_ptr, void *dragging_info_ptr) {
	NSView *view = (__bridge NSView *)view_ptr;
	id<NSDraggingInfo> info = (__bridge id<NSDraggingInfo>)dragging_info_ptr;
	if (view == nil || info == nil) {
		return 0.0;
	}
	return [view convertPoint:[info draggingLocation] fromView:nil].y;
}

static inline NSFont* ui2_font_with_family(NSFont *font, const char* family_name, double fallback_size);

static inline int ui2_vertical_align_value(const char* vertical_align) {
	if (vertical_align == NULL) {
		return 0;
	}
	if (strcmp(vertical_align, "superscript") == 0) {
		return 1;
	}
	if (strcmp(vertical_align, "subscript") == 0) {
		return -1;
	}
	return 0;
}

static inline NSString* ui2_vertical_align_name(int value) {
	if (value > 0) {
		return @"superscript";
	}
	if (value < 0) {
		return @"subscript";
	}
	return @"";
}

static inline NSDictionary* ui2_text_attrs(unsigned int color, unsigned int background_color, double size, const char* family_name, bool bold, bool italic, bool underline, bool strikethrough, const char* vertical_align) {
	NSFont *font = ui2_font_obj(size, bold, italic);
	font = ui2_font_with_family(font, family_name, size);
	NSMutableDictionary *attrs = [@{
		NSFontAttributeName: font,
		NSForegroundColorAttributeName: ui2_nscolor_obj(color)
	} mutableCopy];
	if (underline) {
		attrs[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
	}
	if (strikethrough) {
		attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
	}
	if (background_color != 0) {
		attrs[NSBackgroundColorAttributeName] = ui2_nscolor_obj(background_color);
	}
	int align = ui2_vertical_align_value(vertical_align);
	if (align != 0) {
		attrs[NSSuperscriptAttributeName] = @(align);
	}
	return [attrs autorelease];
}

static inline NSShadow* ui2_text_shadow_obj(void) {
	NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.45]];
	[shadow setShadowOffset:NSMakeSize(1.25, -1.25)];
	[shadow setShadowBlurRadius:1.0];
	return shadow;
}

static inline void ui2_apply_text_effect_attrs(NSMutableDictionary *attrs, int effect) {
	[attrs removeObjectForKey:NSShadowAttributeName];
	[attrs removeObjectForKey:NSStrokeWidthAttributeName];
	[attrs removeObjectForKey:NSStrokeColorAttributeName];
	if ((effect & 1) != 0) {
		attrs[NSShadowAttributeName] = ui2_text_shadow_obj();
	}
	if ((effect & 2) != 0) {
		attrs[NSStrokeWidthAttributeName] = @(-2.0);
		NSColor *color = attrs[NSForegroundColorAttributeName];
		attrs[NSStrokeColorAttributeName] = color == nil ? [NSColor blackColor] : color;
	}
}

static inline void ui2_text_view_set_attributed_string(void* tv_ptr, const char* utf8, unsigned int color, unsigned int background_color, double size, const char* family_name, bool bold, bool italic, bool underline, bool strikethrough, const char* vertical_align) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return;
	}
	NSString *s = utf8 == NULL ? @"" : [NSString stringWithUTF8String:utf8];
	if (s == nil) {
		s = @"";
	}
	NSMutableAttributedString *attr = [[[NSMutableAttributedString alloc] initWithString:s attributes:ui2_text_attrs(color, background_color, size, family_name, bold, italic, underline, strikethrough, vertical_align)] autorelease];
	[[tv textStorage] setAttributedString:attr];
}

static inline void ui2_text_view_set_paragraph_style(void* tv_ptr, int alignment, double head_indent, double first_line_indent, double hyphenation_factor) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return;
	}
	NSMutableParagraphStyle *style = [[[tv defaultParagraphStyle] mutableCopy] autorelease];
	if (style == nil) {
		style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	}
	NSTextAlignment native_alignment = NSTextAlignmentLeft;
	if (alignment == 1) {
		native_alignment = NSTextAlignmentCenter;
	} else if (alignment == 2) {
		native_alignment = NSTextAlignmentRight;
	}
	[style setAlignment:native_alignment];
	[style setHeadIndent:MAX(head_indent, 0.0)];
	[style setFirstLineHeadIndent:MAX(first_line_indent, 0.0)];
	[style setTailIndent:0.0];
	[style setHyphenationFactor:MIN(MAX(hyphenation_factor, 0.0), 1.0)];
	[tv setDefaultParagraphStyle:style];
	NSTextStorage *storage = [tv textStorage];
	if (storage != nil && [storage length] > 0) {
		[storage addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [storage length])];
	}
	NSMutableDictionary *typing = [[tv typingAttributes] mutableCopy];
	if (typing == nil) {
		typing = [[NSMutableDictionary alloc] init];
	}
	typing[NSParagraphStyleAttributeName] = style;
	[tv setTypingAttributes:typing];
	[typing release];
}

static inline void ui2_text_view_add_style(void* tv_ptr, unsigned long location, unsigned long length, unsigned int color, unsigned int background_color, double size, const char* family_name, bool bold, bool italic, bool underline, bool strikethrough, const char* vertical_align) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil || length == 0) {
		return;
	}
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || location >= [storage length]) {
		return;
	}
	NSUInteger safe_len = MIN((NSUInteger)length, [storage length] - (NSUInteger)location);
	[storage addAttributes:ui2_text_attrs(color, background_color, size, family_name, bold, italic, underline, strikethrough, vertical_align) range:NSMakeRange((NSUInteger)location, safe_len)];
}

static inline void ui2_text_view_add_link(void* tv_ptr, unsigned long location, unsigned long length, const char* utf8) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil || length == 0 || utf8 == NULL) {
		return;
	}
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || location >= [storage length]) {
		return;
	}
	NSString *target = [NSString stringWithUTF8String:utf8];
	if (target == nil || [target length] == 0) {
		return;
	}
	NSUInteger safe_len = MIN((NSUInteger)length, [storage length] - (NSUInteger)location);
	NSRange range = NSMakeRange((NSUInteger)location, safe_len);
	[storage addAttribute:NSLinkAttributeName value:target range:range];
	NSDictionary *attrs = @{
		NSForegroundColorAttributeName: ui2_nscolor_obj(0x0563c1),
		NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
	};
	[tv setLinkTextAttributes:attrs];
}

static inline void* ui2_text_view_runs(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return (__bridge void*)@"";
	}
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0) {
		return (__bridge void*)@"";
	}
	NSString *full = [storage string];
	if (full == nil) {
		return (__bridge void*)@"";
	}
	NSMutableString *out = [NSMutableString string];
	NSFontManager *manager = [NSFontManager sharedFontManager];
	NSUInteger cursor = 0;
	NSUInteger length = [storage length];
	while (cursor < length) {
		NSRange effective = NSMakeRange(cursor, length - cursor);
		NSDictionary *attrs = [storage attributesAtIndex:cursor longestEffectiveRange:&effective inRange:NSMakeRange(cursor, length - cursor)];
		if (effective.length == 0) {
			effective = NSMakeRange(cursor, 1);
		}
		NSString *text = [full substringWithRange:effective];
		NSFont *font = attrs[NSFontAttributeName];
		if (font == nil) {
			font = [tv font];
		}
		NSString *family = font == nil ? @"" : [font familyName];
		double size = font == nil ? 0.0 : [font pointSize];
		NSFontTraitMask traits = font == nil ? 0 : [manager traitsOfFont:font];
		bool bold = (traits & NSBoldFontMask) != 0;
		bool italic = (traits & NSItalicFontMask) != 0;
		NSNumber *underline = attrs[NSUnderlineStyleAttributeName];
		bool underlined = underline != nil && [underline integerValue] != 0;
		NSNumber *strike = attrs[NSStrikethroughStyleAttributeName];
		bool struck = strike != nil && [strike integerValue] != 0;
		unsigned int color = ui2_nscolor_hex(attrs[NSForegroundColorAttributeName], 0x111111);
		unsigned int background_color = ui2_nscolor_hex(attrs[NSBackgroundColorAttributeName], 0);
		int effect = attrs[NSShadowAttributeName] != nil ? 1 : 0;
		if (attrs[NSStrokeWidthAttributeName] != nil && [attrs[NSStrokeWidthAttributeName] doubleValue] != 0.0) {
			effect |= 2;
		}
		NSNumber *superscript = attrs[NSSuperscriptAttributeName];
		NSString *vertical_align = ui2_vertical_align_name(superscript == nil ? 0 : [superscript integerValue]);
		[out appendFormat:@"%@\t%@\t%.3f\t%d\t%d\t%d\t%@\t%d\t%u\t%u\t%d\n",
			ui2_base64_utf8(text),
			ui2_base64_utf8(family),
			size,
			bold ? 1 : 0,
			italic ? 1 : 0,
			underlined ? 1 : 0,
			vertical_align,
			struck ? 1 : 0,
			color,
			background_color,
			effect];
		cursor = NSMaxRange(effective);
	}
	return (__bridge void*)out;
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
	NSAttributedString *attr = [[[NSAttributedString alloc] initWithString:s attributes:ui2_text_attrs(color, 0, size, NULL, bold, italic, underline, false, NULL)] autorelease];
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

static inline unsigned long ui2_text_view_selected_location(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return 0;
	}
	NSRange selected = [tv selectedRange];
	return selected.location == NSNotFound ? 0 : selected.location;
}

static inline unsigned long ui2_text_view_selected_length(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return 0;
	}
	NSRange selected = [tv selectedRange];
	return selected.location == NSNotFound ? 0 : selected.length;
}

static inline void ui2_text_view_insert_text(void* tv_ptr, const char* utf8) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil || utf8 == NULL) {
		return;
	}
	NSString *text = [NSString stringWithUTF8String:utf8];
	if (text == nil) {
		return;
	}
	[tv insertText:text replacementRange:[tv selectedRange]];
}

static inline unsigned long ui2_text_view_text_length(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil) {
		return 0;
	}
	NSString *text = [tv string];
	return text == nil ? 0 : [text length];
}

static inline void* ui2_selector_name(void* selector_ptr) {
	if (selector_ptr == NULL) {
		return (__bridge void*)@"";
	}
	const char *name = sel_getName((SEL)selector_ptr);
	if (name == NULL) {
		return (__bridge void*)@"";
	}
	return (__bridge void*)[NSString stringWithUTF8String:name];
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
	if (format == 3) {
		NSNumber *strike = attrs[NSStrikethroughStyleAttributeName];
		return strike != nil && [strike integerValue] != 0;
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

static inline int ui2_text_view_vertical_align_active(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	NSDictionary *attrs = ui2_text_view_current_attrs(tv);
	if (attrs == nil) {
		return 0;
	}
	NSNumber *superscript = attrs[NSSuperscriptAttributeName];
	if (superscript == nil) {
		return 0;
	}
	NSInteger value = [superscript integerValue];
	if (value > 0) {
		return 1;
	}
	if (value < 0) {
		return -1;
	}
	return 0;
}

static inline int ui2_text_view_effect_active(void* tv_ptr) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	NSDictionary *attrs = ui2_text_view_current_attrs(tv);
	if (attrs == nil) {
		return 0;
	}
	int effect = attrs[NSShadowAttributeName] != nil ? 1 : 0;
	NSNumber *stroke_width = attrs[NSStrokeWidthAttributeName];
	if (stroke_width != nil && [stroke_width doubleValue] != 0.0) {
		effect |= 2;
	}
	return effect;
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

static inline NSFont* ui2_font_with_family(NSFont *font, const char* family_name, double fallback_size) {
	if (fallback_size <= 0) {
		fallback_size = [NSFont systemFontSize];
	}
	CGFloat size = font == nil ? fallback_size : [font pointSize];
	NSString *family = family_name == NULL ? nil : [NSString stringWithUTF8String:family_name];
	if (family == nil || [family length] == 0) {
		return font == nil ? [NSFont systemFontOfSize:size] : font;
	}
	NSFont *base = [NSFont fontWithName:family size:size];
	if (base == nil) {
		base = [[NSFontManager sharedFontManager] fontWithFamily:family traits:0 weight:5 size:size];
	}
	if (base == nil) {
		return font == nil ? [NSFont systemFontOfSize:size] : font;
	}
	if (font == nil) {
		return base;
	}
	NSFontManager *manager = [NSFontManager sharedFontManager];
	NSFontTraitMask traits = [manager traitsOfFont:font];
	NSFont *converted = base;
	if ((traits & NSBoldFontMask) != 0) {
		converted = [manager convertFont:converted toHaveTrait:NSBoldFontMask] ?: converted;
	}
	if ((traits & NSItalicFontMask) != 0) {
		converted = [manager convertFont:converted toHaveTrait:NSItalicFontMask] ?: converted;
	}
	return converted;
}

static inline NSFont* ui2_font_with_size(NSFont *font, double size) {
	if (size <= 0) {
		size = [NSFont systemFontSize];
	}
	if (font == nil) {
		return [NSFont systemFontOfSize:size];
	}
	NSFont *converted = [[NSFontManager sharedFontManager] convertFont:font toSize:size];
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
	} else if (format == 3) {
		if (enabled) {
			attrs[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
		} else {
			[attrs removeObjectForKey:NSStrikethroughStyleAttributeName];
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

static inline void ui2_apply_typing_color(NSTextView *tv, unsigned int color, bool background) {
	NSMutableDictionary *attrs = [[tv typingAttributes] mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	NSString *key = background ? NSBackgroundColorAttributeName : NSForegroundColorAttributeName;
	if (background && color == 0) {
		[attrs removeObjectForKey:key];
	} else {
		attrs[key] = ui2_nscolor_obj(color);
	}
	[tv setTypingAttributes:attrs];
	[attrs release];
}

static inline void ui2_apply_typing_effect(NSTextView *tv, int effect) {
	NSMutableDictionary *attrs = [[tv typingAttributes] mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	ui2_apply_text_effect_attrs(attrs, effect);
	[tv setTypingAttributes:attrs];
	[attrs release];
}

static inline void ui2_apply_typing_font_family(NSTextView *tv, const char* family_name) {
	NSMutableDictionary *attrs = [[tv typingAttributes] mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	NSFont *font = attrs[NSFontAttributeName];
	if (font == nil) {
		font = [tv font];
	}
	attrs[NSFontAttributeName] = ui2_font_with_family(font, family_name, [tv font] == nil ? [NSFont systemFontSize] : [[tv font] pointSize]);
	[tv setTypingAttributes:attrs];
	[attrs release];
}

static inline void ui2_apply_typing_font_size(NSTextView *tv, double size) {
	NSMutableDictionary *attrs = [[tv typingAttributes] mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	NSFont *font = attrs[NSFontAttributeName];
	if (font == nil) {
		font = [tv font];
	}
	attrs[NSFontAttributeName] = ui2_font_with_size(font, size);
	[tv setTypingAttributes:attrs];
	[attrs release];
}

static inline void ui2_apply_typing_vertical_align(NSTextView *tv, int align) {
	NSDictionary *current = ui2_text_view_current_attrs(tv);
	NSMutableDictionary *attrs = current == nil ? [[tv typingAttributes] mutableCopy] : [current mutableCopy];
	if (attrs == nil) {
		attrs = [[NSMutableDictionary alloc] init];
	}
	if (attrs[NSFontAttributeName] == nil && [tv font] != nil) {
		attrs[NSFontAttributeName] = [tv font];
	}
	if (align == 0) {
		[attrs removeObjectForKey:NSSuperscriptAttributeName];
	} else {
		attrs[NSSuperscriptAttributeName] = @(align);
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
	} else if (format == 3) {
		if (enabled) {
			[storage addAttribute:NSStrikethroughStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
		} else {
			[storage removeAttribute:NSStrikethroughStyleAttributeName range:range];
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

static inline void ui2_apply_range_color(NSTextView *tv, NSRange range, unsigned int color, bool background) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	NSString *key = background ? NSBackgroundColorAttributeName : NSForegroundColorAttributeName;
	if (background && color == 0) {
		[storage removeAttribute:key range:range];
	} else {
		[storage addAttribute:key value:ui2_nscolor_obj(color) range:range];
	}
	[tv setSelectedRange:range];
}

static inline void ui2_apply_range_effect(NSTextView *tv, NSRange range, int effect) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	[storage removeAttribute:NSShadowAttributeName range:range];
	[storage removeAttribute:NSStrokeWidthAttributeName range:range];
	[storage removeAttribute:NSStrokeColorAttributeName range:range];
	if ((effect & 1) != 0) {
		[storage addAttribute:NSShadowAttributeName value:ui2_text_shadow_obj() range:range];
	}
	if ((effect & 2) != 0) {
		[storage addAttribute:NSStrokeWidthAttributeName value:@(-2.0) range:range];
		[storage addAttribute:NSStrokeColorAttributeName value:[NSColor blackColor] range:range];
	}
	[tv setSelectedRange:range];
}

static inline void ui2_apply_range_vertical_align(NSTextView *tv, NSRange range, int align) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	[storage beginEditing];
	if (align == 0) {
		[storage removeAttribute:NSSuperscriptAttributeName range:range];
	} else {
		[storage addAttribute:NSSuperscriptAttributeName value:@(align) range:range];
	}
	[storage endEditing];
	[tv setSelectedRange:range];
}

static inline void ui2_apply_range_font_family(NSTextView *tv, NSRange range, const char* family_name) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	[storage beginEditing];
	NSUInteger end = NSMaxRange(range);
	NSUInteger cursor = range.location;
	while (cursor < end) {
		NSRange effective = NSMakeRange(cursor, end - cursor);
		NSFont *font = [storage attribute:NSFontAttributeName atIndex:cursor longestEffectiveRange:&effective inRange:range];
		NSRange apply = NSIntersectionRange(effective, range);
		if (apply.length == 0) {
			apply = NSMakeRange(cursor, 1);
		}
		NSFont *converted = ui2_font_with_family(font == nil ? [tv font] : font, family_name, [tv font] == nil ? [NSFont systemFontSize] : [[tv font] pointSize]);
		[storage addAttribute:NSFontAttributeName value:converted range:apply];
		cursor = NSMaxRange(apply);
	}
	[storage endEditing];
	[tv setSelectedRange:range];
}

static inline void ui2_apply_range_font_size(NSTextView *tv, NSRange range, double size) {
	NSTextStorage *storage = [tv textStorage];
	if (storage == nil || [storage length] == 0 || range.length == 0 || range.location >= [storage length]) {
		return;
	}
	NSUInteger max_len = [storage length] - range.location;
	if (range.length > max_len) {
		range.length = max_len;
	}
	[storage beginEditing];
	NSUInteger end = NSMaxRange(range);
	NSUInteger cursor = range.location;
	while (cursor < end) {
		NSRange effective = NSMakeRange(cursor, end - cursor);
		NSFont *font = [storage attribute:NSFontAttributeName atIndex:cursor longestEffectiveRange:&effective inRange:range];
		NSRange apply = NSIntersectionRange(effective, range);
		if (apply.length == 0) {
			apply = NSMakeRange(cursor, 1);
		}
		[storage addAttribute:NSFontAttributeName value:ui2_font_with_size(font == nil ? [tv font] : font, size) range:apply];
		cursor = NSMaxRange(apply);
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

static inline void ui2_text_view_set_font_family(void* tv_ptr, const char* family_name) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_font_family(tv, family_name);
		return;
	}
	ui2_apply_range_font_family(tv, selected, family_name);
}

static inline void ui2_text_view_set_font_size(void* tv_ptr, double size) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_font_size(tv, size);
		return;
	}
	ui2_apply_range_font_size(tv, selected, size);
}

static inline void ui2_text_view_set_color(void* tv_ptr, unsigned int color) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_color(tv, color, false);
		return;
	}
	ui2_apply_range_color(tv, selected, color, false);
}

static inline void ui2_text_view_set_background_color(void* tv_ptr, unsigned int color) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_color(tv, color, true);
		return;
	}
	ui2_apply_range_color(tv, selected, color, true);
}

static inline void ui2_text_view_add_effect(void* tv_ptr, unsigned long location, unsigned long length, int effect) {
	NSTextView *tv = (__bridge NSTextView*)tv_ptr;
	if (tv == nil || length == 0) {
		return;
	}
	ui2_apply_range_effect(tv, NSMakeRange((NSUInteger)location, (NSUInteger)length), effect);
}

static inline void ui2_text_view_set_effect(void* tv_ptr, int effect) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil) {
		return;
	}
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_effect(tv, effect);
		return;
	}
	ui2_apply_range_effect(tv, selected, effect);
}

static inline void ui2_text_view_toggle_vertical_align(void* tv_ptr, int align) {
	NSTextView *tv = ui2_text_view_obj(tv_ptr);
	if (tv == nil || align == 0) {
		return;
	}
	int current = ui2_text_view_vertical_align_active(tv_ptr);
	int next = current == align ? 0 : align;
	NSRange selected = [tv selectedRange];
	if (selected.length == 0) {
		ui2_apply_typing_vertical_align(tv, next);
		return;
	}
	ui2_apply_range_vertical_align(tv, selected, next);
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

static inline unsigned long ui2_current_event_modifier_flags(void) {
	NSEvent *event = [NSApp currentEvent];
	return event == nil ? 0 : [event modifierFlags];
}

static inline double ui2_event_x_in_view(void* view_ptr, void* event_ptr) {
	NSView *view = (__bridge NSView*)view_ptr;
	NSEvent *event = (__bridge NSEvent*)event_ptr;
	if (view == nil || event == nil) {
		return 0;
	}
	NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
	return p.x;
}

static inline double ui2_event_y_in_view(void* view_ptr, void* event_ptr) {
	NSView *view = (__bridge NSView*)view_ptr;
	NSEvent *event = (__bridge NSEvent*)event_ptr;
	if (view == nil || event == nil) {
		return 0;
	}
	NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
	return p.y;
}

static inline void ui2_layer_set_frame_geometry(CALayer *layer, NSRect frame) {
	[layer setAnchorPoint:CGPointMake(0.5, 0.5)];
	[layer setBounds:CGRectMake(0, 0, NSWidth(frame), NSHeight(frame))];
	[layer setPosition:CGPointMake(NSMidX(frame), NSMidY(frame))];
}

static inline void ui2_view_set_rotation(void* view_ptr, double degrees) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil) {
		return;
	}
	NSRect frame = [view frame];
	[view setWantsLayer:YES];
	CALayer *layer = [view layer];
	if (layer == nil) {
		return;
	}
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[layer setAffineTransform:CGAffineTransformIdentity];
	ui2_layer_set_frame_geometry(layer, frame);
	CGFloat radians = (CGFloat)(degrees * M_PI / 180.0);
	[layer setAffineTransform:CGAffineTransformMakeRotation(radians)];
	[CATransaction commit];
}

static inline void ui2_view_reset_transform(void* view_ptr) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil) {
		return;
	}
	NSRect frame = [view frame];
	[view setWantsLayer:YES];
	CALayer *layer = [view layer];
	if (layer == nil) {
		return;
	}
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[layer setAffineTransform:CGAffineTransformIdentity];
	ui2_layer_set_frame_geometry(layer, frame);
	[CATransaction commit];
	[view setFrame:frame];
}

static inline void ui2_view_clear_rotation(void* view_ptr) {
	NSView *view = (__bridge NSView*)view_ptr;
	if (view == nil || ![view wantsLayer]) {
		return;
	}
	CALayer *layer = [view layer];
	if (layer == nil) {
		return;
	}
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	[layer setAffineTransform:CGAffineTransformIdentity];
	ui2_layer_set_frame_geometry(layer, [view frame]);
	[CATransaction commit];
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
