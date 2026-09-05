#ifndef VUI_NATIVE_BRIDGE_H
#define VUI_NATIVE_BRIDGE_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string.h>

extern void vui_barcode_scanned(char *code);
extern void vui_barcode_error(char *message);
extern void vui_barcode_cancelled(void);
extern void vui_dropdown_selected(void *sender, char *value);

@interface VuiScannerViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate>
@property(nonatomic, retain) AVCaptureSession *session;
@property(nonatomic, retain) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, assign) BOOL didScan;
@end

@implementation VuiScannerViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor blackColor];

	AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	if (device == nil) {
		[self finishWithError:@"camera unavailable"];
		return;
	}

	NSError *inputError = nil;
	AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&inputError];
	if (input == nil || inputError != nil) {
		[self finishWithError:@"camera unavailable"];
		return;
	}

	self.session = [[[AVCaptureSession alloc] init] autorelease];
	if ([self.session canAddInput:input]) {
		[self.session addInput:input];
	}

	AVCaptureMetadataOutput *output = [[[AVCaptureMetadataOutput alloc] init] autorelease];
	if (![self.session canAddOutput:output]) {
		[self finishWithError:@"barcode scanner unavailable"];
		return;
	}
	[self.session addOutput:output];
	[output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];

	NSArray *desiredTypes = @[
		AVMetadataObjectTypeQRCode,
		AVMetadataObjectTypeEAN13Code,
		AVMetadataObjectTypeEAN8Code,
		AVMetadataObjectTypeUPCECode,
		AVMetadataObjectTypeCode128Code,
		AVMetadataObjectTypeCode39Code,
		AVMetadataObjectTypeCode93Code,
		AVMetadataObjectTypePDF417Code,
		AVMetadataObjectTypeDataMatrixCode,
		AVMetadataObjectTypeITF14Code
	];
	NSMutableArray *availableTypes = [NSMutableArray array];
	for (id type in desiredTypes) {
		if ([output.availableMetadataObjectTypes containsObject:type]) {
			[availableTypes addObject:type];
		}
	}
	if (availableTypes.count == 0) {
		[self finishWithError:@"barcode scanner unavailable"];
		return;
	}
	output.metadataObjectTypes = availableTypes;

	self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
	self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	self.previewLayer.frame = self.view.bounds;
	[self.view.layer insertSublayer:self.previewLayer atIndex:0];

	UILabel *hint = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)] autorelease];
	hint.tag = 101;
	hint.text = @"Scan QR or barcode";
	hint.textColor = [UIColor whiteColor];
	hint.font = [UIFont boldSystemFontOfSize:17.0];
	hint.textAlignment = NSTextAlignmentCenter;
	hint.numberOfLines = 1;
	hint.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
	hint.layer.cornerRadius = 8.0;
	hint.layer.masksToBounds = YES;
	[self.view addSubview:hint];

	UIButton *cancel = [UIButton buttonWithType:UIButtonTypeSystem];
	cancel.tag = 102;
	[cancel setTitle:@"Cancel" forState:UIControlStateNormal];
	[cancel setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	cancel.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
	cancel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
	cancel.layer.cornerRadius = 8.0;
	cancel.layer.masksToBounds = YES;
	[cancel addTarget:self action:@selector(cancelTap) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:cancel];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	self.previewLayer.frame = self.view.bounds;
	UIEdgeInsets insets = self.view.safeAreaInsets;
	UIView *hint = [self.view viewWithTag:101];
	UIView *cancel = [self.view viewWithTag:102];
	CGFloat width = self.view.bounds.size.width;
	CGFloat height = self.view.bounds.size.height;
	hint.frame = CGRectMake(16.0, height - insets.bottom - 82.0, width - 32.0, 44.0);
	cancel.frame = CGRectMake(16.0, insets.top + 10.0, 92.0, 40.0);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.session != nil && !self.session.isRunning) {
		[self.session startRunning];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (self.session != nil && self.session.isRunning) {
		[self.session stopRunning];
	}
}

- (void)cancelTap {
	if (self.session != nil && self.session.isRunning) {
		[self.session stopRunning];
	}
	[self dismissViewControllerAnimated:YES completion:^{
		vui_barcode_cancelled();
	}];
}

- (void)finishWithError:(NSString *)message {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.presentingViewController != nil) {
			[self dismissViewControllerAnimated:YES completion:^{
				vui_barcode_error((char *)[message UTF8String]);
			}];
		} else {
			vui_barcode_error((char *)[message UTF8String]);
		}
	});
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
	if (self.didScan) {
		return;
	}
	for (AVMetadataObject *metadata in metadataObjects) {
		if (![metadata isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
			continue;
		}
		NSString *value = [(AVMetadataMachineReadableCodeObject *)metadata stringValue];
		if (value == nil || value.length == 0) {
			continue;
		}
		self.didScan = YES;
		if (self.session != nil && self.session.isRunning) {
			[self.session stopRunning];
		}
		NSString *scanned = [value copy];
		[self dismissViewControllerAnimated:YES completion:^{
			vui_barcode_scanned((char *)[scanned UTF8String]);
			[scanned release];
		}];
		return;
	}
}

@end

static UIViewController *vui_top_view_controller(UIViewController *root) {
	UIViewController *top = root;
	while (top.presentedViewController != nil) {
		top = top.presentedViewController;
	}
	return top;
}

static void vui_present_authorized_scanner(UIViewController *root) {
	if (root == nil) {
		dispatch_async(dispatch_get_main_queue(), ^{
			vui_barcode_error("scanner unavailable");
		});
		return;
	}
	UIViewController *top = vui_top_view_controller(root);
	VuiScannerViewController *scanner = [[[VuiScannerViewController alloc] init] autorelease];
	scanner.modalPresentationStyle = UIModalPresentationFullScreen;
	[top presentViewController:scanner animated:YES completion:nil];
}

static inline UIAccessibilityTraits vui_accessibility_traits(const char *raw) {
	if (raw == NULL || raw[0] == '\0') return UIAccessibilityTraitNone;
	if (strcmp(raw, "button") == 0) return UIAccessibilityTraitButton;
	if (strcmp(raw, "image") == 0) return UIAccessibilityTraitImage;
	if (strcmp(raw, "link") == 0) return UIAccessibilityTraitLink;
	if (strcmp(raw, "header") == 0) return UIAccessibilityTraitHeader;
	if (strcmp(raw, "adjustable") == 0) return UIAccessibilityTraitAdjustable;
	return UIAccessibilityTraitNone;
}

static char vui_original_accessibility_role_key;
static char vui_original_accessibility_label_key;
static char vui_original_accessibility_value_key;
static char vui_original_is_accessibility_element_key;

static inline id vui_saved_accessibility_value(id value) {
	return value == nil ? [NSNull null] : value;
}

static inline id vui_restored_accessibility_value(id value) {
	return value == [NSNull null] ? nil : value;
}

static inline void vui_apply_common_view_state(void *view_ptr, bool hidden, bool enabled,
		const char *role_raw, const char *label_raw, const char *value_raw) {
	UIView *view = (UIView *)view_ptr;
	if (view == nil) {
		return;
	}
	view.hidden = hidden;
	BOOL has_role = role_raw != NULL && role_raw[0] != '\0';
	BOOL has_label = label_raw != NULL && label_raw[0] != '\0';
	BOOL has_value = value_raw != NULL && value_raw[0] != '\0';
	id saved_label = objc_getAssociatedObject(view, &vui_original_accessibility_label_key);
	if (has_label) {
		if (saved_label == nil) {
			objc_setAssociatedObject(view, &vui_original_accessibility_label_key,
				vui_saved_accessibility_value(view.accessibilityLabel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		view.accessibilityLabel = [NSString stringWithUTF8String:label_raw];
	} else if (saved_label != nil) {
		view.accessibilityLabel = vui_restored_accessibility_value(saved_label);
		objc_setAssociatedObject(view, &vui_original_accessibility_label_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	id saved_value = objc_getAssociatedObject(view, &vui_original_accessibility_value_key);
	if (has_value) {
		if (saved_value == nil) {
			objc_setAssociatedObject(view, &vui_original_accessibility_value_key,
				vui_saved_accessibility_value(view.accessibilityValue), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		view.accessibilityValue = [NSString stringWithUTF8String:value_raw];
	} else if (saved_value != nil) {
		view.accessibilityValue = vui_restored_accessibility_value(saved_value);
		objc_setAssociatedObject(view, &vui_original_accessibility_value_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	UIAccessibilityTraits traits = vui_accessibility_traits(role_raw);
	id saved_traits = objc_getAssociatedObject(view, &vui_original_accessibility_role_key);
	if (has_role) {
		if (saved_traits == nil) {
			objc_setAssociatedObject(view, &vui_original_accessibility_role_key,
				@(view.accessibilityTraits), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		view.accessibilityTraits = traits;
	} else if (saved_traits != nil) {
		view.accessibilityTraits = [saved_traits unsignedLongLongValue];
		objc_setAssociatedObject(view, &vui_original_accessibility_role_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	BOOL has_metadata = has_role || has_label || has_value;
	id saved_accessible = objc_getAssociatedObject(view, &vui_original_is_accessibility_element_key);
	if (has_metadata) {
		if (saved_accessible == nil) {
			objc_setAssociatedObject(view, &vui_original_is_accessibility_element_key,
				@(view.isAccessibilityElement), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		view.isAccessibilityElement = YES;
	} else if (saved_accessible != nil) {
		view.isAccessibilityElement = [saved_accessible boolValue];
		objc_setAssociatedObject(view, &vui_original_is_accessibility_element_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	if ([view isKindOfClass:[UIControl class]]) {
		[(UIControl *)view setEnabled:enabled];
	} else {
		view.userInteractionEnabled = enabled;
	}
}

static inline void vui_configure_dropdown(void *button_ptr, const char *encoded_raw) {
	UIButton *button = (UIButton *)button_ptr;
	if (button == nil || encoded_raw == NULL) {
		return;
	}
	if (@available(iOS 14.0, *)) {
		NSString *encoded = [NSString stringWithUTF8String:encoded_raw] ?: @"";
		NSArray<NSString *> *lines = [encoded componentsSeparatedByString:@"\n"];
		NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
		__unsafe_unretained UIButton *target = button;
		for (NSString *line in lines) {
			if (line.length == 0) {
				continue;
			}
			NSData *data = [[[NSData alloc] initWithBase64EncodedString:line options:0] autorelease];
			NSString *title = data == nil ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
			if (title == nil) {
				continue;
			}
			UIAction *action = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(__kindof UIAction *chosen) {
				[target setTitle:chosen.title forState:UIControlStateNormal];
				vui_dropdown_selected(target, (char *)[chosen.title UTF8String]);
			}];
			[actions addObject:action];
		}
		button.menu = [UIMenu menuWithTitle:@"" children:actions];
		button.showsMenuAsPrimaryAction = YES;
	}
}

static inline void vui_set_view_rotation(void *view_ptr, double degrees) {
	UIView *view = (UIView *)view_ptr;
	if (view != nil) {
		view.transform = CGAffineTransformMakeRotation((CGFloat)(degrees * 0.017453292519943295));
	}
}

void vui_present_barcode_scanner(void *root_ptr) {
	UIViewController *root = (UIViewController *)root_ptr;
	dispatch_async(dispatch_get_main_queue(), ^{
		AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
		if (status == AVAuthorizationStatusAuthorized) {
			vui_present_authorized_scanner(root);
			return;
		}
		if (status == AVAuthorizationStatusNotDetermined) {
			[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
				dispatch_async(dispatch_get_main_queue(), ^{
					if (granted) {
						vui_present_authorized_scanner(root);
					} else {
						vui_barcode_error("camera permission denied");
					}
				});
			}];
			return;
		}
		vui_barcode_error("camera permission denied");
	});
}

static inline void vui_text_view_set_selected_range(void *view_ptr, unsigned long location, unsigned long length) {
	UITextView *view = (UITextView *)view_ptr;
	if (view == nil || ![view isKindOfClass:[UITextView class]]) {
		return;
	}
	NSUInteger text_length = view.text == nil ? 0 : view.text.length;
	NSUInteger safe_location = MIN((NSUInteger)location, text_length);
	NSUInteger safe_length = MIN((NSUInteger)length, text_length - safe_location);
	NSRange range = NSMakeRange(safe_location, safe_length);
	[view becomeFirstResponder];
	view.selectedRange = range;
	[view scrollRangeToVisible:range];
}

static inline unsigned long vui_text_view_selected_location(void *view_ptr) {
	UITextView *view = (UITextView *)view_ptr;
	if (view == nil || ![view isKindOfClass:[UITextView class]]) {
		return 0;
	}
	NSRange range = view.selectedRange;
	return range.location == NSNotFound ? 0 : range.location;
}

static inline unsigned long vui_text_view_selected_length(void *view_ptr) {
	UITextView *view = (UITextView *)view_ptr;
	if (view == nil || ![view isKindOfClass:[UITextView class]]) {
		return 0;
	}
	NSRange range = view.selectedRange;
	return range.location == NSNotFound ? 0 : range.length;
}

// vui_message_box presents the system alert and blocks the caller until a
// button is chosen. UIKit only reports the choice through a handler block, so
// the main run loop is pumped in place rather than returned to; that keeps
// ui2's message_box synchronous on iOS like it is on the desktop backends.
static inline int vui_message_box(void *root_ptr, const char *title_raw,
		const char *text_raw, const char *buttons_raw, int fallback) {
	UIViewController *root = (UIViewController *)root_ptr;
	if (root == nil || buttons_raw == NULL) {
		return fallback;
	}
	NSString *joined = [NSString stringWithUTF8String:buttons_raw] ?: @"";
	NSArray<NSString *> *titles = [joined componentsSeparatedByString:@"\n"];
	if (titles.count == 0) {
		return fallback;
	}
	NSString *title = title_raw == NULL ? @"" : ([NSString stringWithUTF8String:title_raw] ?: @"");
	NSString *text = text_raw == NULL ? @"" : ([NSString stringWithUTF8String:text_raw] ?: @"");
	__block int chosen = -1;
	UIAlertController *alert = [UIAlertController
		alertControllerWithTitle:title.length == 0 ? nil : title
		message:text.length == 0 ? nil : text
		preferredStyle:UIAlertControllerStyleAlert];
	for (NSUInteger index = 0; index < titles.count; index++) {
		NSString *label = titles[index];
		NSUInteger position = index;
		BOOL dismissal = (index + 1 == titles.count) && titles.count > 1;
		UIAlertAction *action = [UIAlertAction
			actionWithTitle:label
			style:dismissal ? UIAlertActionStyleCancel : UIAlertActionStyleDefault
			handler:^(UIAlertAction *sender) {
				chosen = (int)position;
			}];
		[alert addAction:action];
	}
	[root presentViewController:alert animated:YES completion:nil];
	NSRunLoop *loop = [NSRunLoop currentRunLoop];
	while (chosen < 0) {
		[loop runMode:NSDefaultRunLoopMode
			beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
	return chosen;
}

#endif
