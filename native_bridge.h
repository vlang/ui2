#ifndef VUI_NATIVE_BRIDGE_H
#define VUI_NATIVE_BRIDGE_H

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern void vui_barcode_scanned(char *code);
extern void vui_barcode_error(char *message);
extern void vui_barcode_cancelled(void);

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

#endif
