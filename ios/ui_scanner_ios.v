module ui2

import internal.macos

// Barcode scanning is a port of the AVFoundation view controller that used
// to live in native_bridge.h. The controller class is assembled on the
// Objective-C runtime, so every callback below is a method implementation.

fn C.vui_scanner_layout(self voidptr, cmd voidptr)

fn C.vui_scanner_cancel(self voidptr, cmd voidptr)

fn C.vui_scanner_session_error(self voidptr, cmd voidptr, notification voidptr)

fn C.vui_scanner_metadata(self voidptr, cmd voidptr, output voidptr, objects voidptr, connection voidptr)

const av_authorization_restricted = 1
const av_authorization_denied = 2

// AVErrorApplicationIsNotAuthorizedToUseDevice
const av_error_not_authorized = i64(-11852)

const ui_modal_presentation_full_screen = i64(0)

struct MetadataType {
	symbol   string
	fallback string
}

const scanner_metadata_types = [
	MetadataType{
		symbol: 'AVMetadataObjectTypeQRCode'
		fallback: 'org.iso.QRCode'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeEAN13Code'
		fallback: 'org.gs1.EAN-13'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeEAN8Code'
		fallback: 'org.gs1.EAN-8'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeUPCECode'
		fallback: 'org.gs1.UPC-E'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeCode128Code'
		fallback: 'org.iso.Code128'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeCode39Code'
		fallback: 'org.iso.Code39'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeCode93Code'
		fallback: 'org.iso.Code93'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypePDF417Code'
		fallback: 'org.iso.PDF417'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeDataMatrixCode'
		fallback: 'org.iso.DataMatrix'
	},
	MetadataType{
		symbol: 'AVMetadataObjectTypeITF14Code'
		fallback: 'org.gs1.ITF14'
	},
]

__global g_scanner_vc = View(unsafe { nil })
__global g_scanner_session = View(unsafe { nil })
__global g_scanner_preview = View(unsafe { nil })
__global g_scanner_hint = View(unsafe { nil })
__global g_scanner_cancel = View(unsafe { nil })
__global g_scanner_scanned = false

fn av_media_type_video() macos.Id {
	return extern_id('AVMediaTypeVideo', 'vide')
}

fn ensure_scanner_class() {
	if !objc_is_nil(macos.get_class('VuiScannerViewController')) {
		return
	}
	cls := macos.allocate_class_pair(macos.get_class('UIViewController'), 'VuiScannerViewController')
	macos.add_protocol(cls, macos.get_protocol('AVCaptureMetadataOutputObjectsDelegate'))
	// UIViewController's own viewDidLayoutSubviews does nothing, so the
	// override does not have to chain to it.
	macos.add_method(cls, 'viewDidLayoutSubviews', voidptr(C.vui_scanner_layout), 'v@:')
	macos.add_method(cls, 'vuiCancelTap', voidptr(C.vui_scanner_cancel), 'v@:')
	macos.add_method(cls, 'vuiSessionError:', voidptr(C.vui_scanner_session_error), 'v@:@')
	macos.add_method(cls, 'captureOutput:didOutputMetadataObjects:fromConnection:', voidptr(C.vui_scanner_metadata), 'v@:@@@')
	macos.register_class_pair(cls)
}

// native_present_barcode_scanner mirrors the old bridge: presentation always
// happens on the main thread, and a camera the user already refused is
// reported without building a session.
fn native_present_barcode_scanner(root View) {
	if !macos.msg_bool(macos.get_class('NSThread'), 'isMainThread') {
		if !objc_is_nil(g_button_handler) {
			macos.msg_void_sel_id_bool(g_button_handler, 'performSelectorOnMainThread:withObject:waitUntilDone:', macos.sel('vuiPresentScanner:'), root, false)
		}
		return
	}
	if objc_is_nil(root) {
		report_scan_error('scanner unavailable')
		return
	}
	status := i64(macos.msg_u64_id(macos.get_class('AVCaptureDevice'), 'authorizationStatusForMediaType:', av_media_type_video()))
	if status == av_authorization_denied || status == av_authorization_restricted {
		report_scan_error('camera permission denied')
		return
	}
	// An undetermined status needs no explicit request: iOS prompts on the
	// first capture attempt and the session reports a runtime error when the
	// user refuses.
	present_scanner(root)
}

fn top_view_controller(root View) View {
	mut top := root
	for {
		presented := macos.msg_id(top, 'presentedViewController')
		if objc_is_nil(presented) {
			break
		}
		top = presented
	}
	return top
}

fn present_scanner(root View) {
	ensure_scanner_class()
	scanner := macos.msg_id(macos.alloc('VuiScannerViewController'), 'init')
	if objc_is_nil(scanner) {
		report_scan_error('scanner unavailable')
		return
	}
	macos.msg_void_i64(scanner, 'setModalPresentationStyle:', ui_modal_presentation_full_screen)
	g_scanner_vc = scanner
	g_scanner_scanned = false
	// Reading `view` loads the controller's view, which is the work the old
	// bridge did in viewDidLoad.
	view := macos.msg_id(scanner, 'view')
	macos.msg_void1(view, 'setBackgroundColor:', macos.msg_id(macos.get_class('UIColor'), 'blackColor'))
	if !start_scanner_session(scanner, view) {
		release_scanner()
		return
	}
	build_scanner_chrome(scanner, view)
	layout_scanner(view)
	macos.msg_void_id_i64_id(top_view_controller(root), 'presentViewController:animated:completion:', scanner, 1, objc_nil())
	macos.msg_void(g_scanner_session, 'startRunning')
}

fn scanner_metadata_object_types(output View) macos.Id {
	available := macos.msg_id(output, 'availableMetadataObjectTypes')
	types := macos.msg_id(macos.alloc('NSMutableArray'), 'init')
	for metadata_type in scanner_metadata_types {
		value := extern_id(metadata_type.symbol, metadata_type.fallback)
		if macos.msg_bool_id(available, 'containsObject:', value) {
			macos.msg_void1(types, 'addObject:', value)
		}
	}
	return types
}

fn start_scanner_session(scanner View, view View) bool {
	// dispatch_get_main_queue() is a macro over this symbol; reading it keeps
	// the queue a plain pointer that ARC never looks at.
	queue := macos.Id(extern_symbol('_dispatch_main_q'))
	device := macos.msg_id1(macos.get_class('AVCaptureDevice'), 'defaultDeviceWithMediaType:', av_media_type_video())
	if objc_is_nil(device) || objc_is_nil(queue) {
		report_scan_error('camera unavailable')
		return false
	}
	mut failure := objc_nil()
	input := macos.msg_id2(macos.get_class('AVCaptureDeviceInput'), 'deviceInputWithDevice:error:', device, macos.Id(voidptr(&failure)))
	if objc_is_nil(input) {
		report_scan_error('camera unavailable')
		return false
	}
	session := macos.msg_id(macos.alloc('AVCaptureSession'), 'init')
	if macos.msg_bool_id(session, 'canAddInput:', input) {
		macos.msg_void1(session, 'addInput:', input)
	}
	output := macos.msg_id(macos.alloc('AVCaptureMetadataOutput'), 'init')
	if !macos.msg_bool_id(session, 'canAddOutput:', output) {
		macos.release(output)
		macos.release(session)
		report_scan_error('barcode scanner unavailable')
		return false
	}
	macos.msg_void1(session, 'addOutput:', output)
	macos.msg_void2(output, 'setMetadataObjectsDelegate:queue:', scanner, queue)
	// The supported types are only known once the output is connected.
	types := scanner_metadata_object_types(output)
	if macos.msg_u64(types, 'count') == 0 {
		macos.release(types)
		macos.release(output)
		macos.release(session)
		report_scan_error('barcode scanner unavailable')
		return false
	}
	macos.msg_void1(output, 'setMetadataObjectTypes:', types)
	macos.release(types)
	macos.release(output)
	g_scanner_session = session
	preview := macos.msg_id1(macos.get_class('AVCaptureVideoPreviewLayer'), 'layerWithSession:', session)
	macos.msg_void1(preview, 'setVideoGravity:', extern_id('AVLayerVideoGravityResizeAspectFill', 'AVLayerVideoGravityResizeAspectFill'))
	// The preview goes in before any subview, so every control added later
	// layers on top of it.
	macos.msg_void1(macos.msg_id(view, 'layer'), 'addSublayer:', preview)
	g_scanner_preview = macos.retain(preview)
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void_id_sel_id_id(center, 'addObserver:selector:name:object:', scanner, macos.sel('vuiSessionError:'), extern_id('AVCaptureSessionRuntimeErrorNotification', 'AVCaptureSessionRuntimeErrorNotification'), session)
	return true
}

fn scanner_overlay_color() macos.Id {
	return macos.msg_id_f64(macos.msg_id(macos.get_class('UIColor'), 'blackColor'), 'colorWithAlphaComponent:', 0.55)
}

fn build_scanner_chrome(scanner View, view View) {
	white := macos.msg_id(macos.get_class('UIColor'), 'whiteColor')
	hint := macos.msg_id_rect(macos.alloc('UILabel'), 'initWithFrame:', macos.rect(0, 0, 0, 0))
	macos.msg_void1(hint, 'setText:', macos.nsstring('Scan QR or barcode'))
	macos.msg_void1(hint, 'setTextColor:', white)
	macos.msg_void1(hint, 'setFont:', font(17, true))
	macos.msg_void_i64(hint, 'setTextAlignment:', 1)
	macos.msg_void_i64(hint, 'setNumberOfLines:', 1)
	macos.msg_void1(hint, 'setBackgroundColor:', scanner_overlay_color())
	set_corner_radius(hint, 8)
	macos.msg_void1(view, 'addSubview:', hint)
	g_scanner_hint = hint

	cancel := macos.msg_id_u64(macos.get_class('UIButton'), 'buttonWithType:', u64(0))
	macos.msg_void2(cancel, 'setTitle:forState:', macos.nsstring('Cancel'), macos.Id(usize(0)))
	macos.msg_void2(cancel, 'setTitleColor:forState:', white, macos.Id(usize(0)))
	macos.msg_void1(macos.msg_id(cancel, 'titleLabel'), 'setFont:', font(16, true))
	macos.msg_void1(cancel, 'setBackgroundColor:', scanner_overlay_color())
	set_corner_radius(cancel, 8)
	macos.msg_void3(cancel, 'addTarget:action:forControlEvents:', scanner, macos.Id(macos.sel('vuiCancelTap')), macos.Id(usize(64)))
	macos.msg_void1(view, 'addSubview:', cancel)
	// buttonWithType: hands back an autoreleased button, so it needs the same
	// ownership as the label allocated above.
	g_scanner_cancel = macos.retain(cancel)
}

fn layout_scanner(view View) {
	if objc_is_nil(view) {
		return
	}
	bounds := macos.msg_rect(view, 'bounds')
	if !objc_is_nil(g_scanner_preview) {
		macos.msg_void_rect(g_scanner_preview, 'setFrame:', bounds)
	}
	// UIEdgeInsets lands in a rect as top, left, bottom, right.
	insets := macos.msg_rect(view, 'safeAreaInsets')
	if !objc_is_nil(g_scanner_hint) {
		macos.msg_void_rect(g_scanner_hint, 'setFrame:', macos.rect(16, bounds.height - insets.width - 82, bounds.width - 32, 44))
	}
	if !objc_is_nil(g_scanner_cancel) {
		macos.msg_void_rect(g_scanner_cancel, 'setFrame:', macos.rect(16, insets.x + 10, 92, 40))
	}
}

fn stop_scanner_session() {
	if !objc_is_nil(g_scanner_session) && macos.msg_bool(g_scanner_session, 'isRunning') {
		macos.msg_void(g_scanner_session, 'stopRunning')
	}
}

fn dismiss_scanner() {
	scanner := g_scanner_vc
	if objc_is_nil(scanner) {
		return
	}
	center := macos.msg_id(macos.get_class('NSNotificationCenter'), 'defaultCenter')
	macos.msg_void1(center, 'removeObserver:', scanner)
	// The completion argument is a block, which is always nil here.
	dismiss := unsafe { ObjcVoidBoolIdMsg(C.objc_msgSend) }
	dismiss(voidptr(scanner), voidptr(macos.sel('dismissViewControllerAnimated:completion:')), true, unsafe { nil })
	release_scanner()
}

fn release_scanner() {
	macos.release(g_scanner_hint)
	macos.release(g_scanner_cancel)
	macos.release(g_scanner_preview)
	macos.release(g_scanner_session)
	macos.release(g_scanner_vc)
	g_scanner_hint = View(unsafe { nil })
	g_scanner_cancel = View(unsafe { nil })
	g_scanner_preview = View(unsafe { nil })
	g_scanner_session = View(unsafe { nil })
	g_scanner_vc = View(unsafe { nil })
}

fn report_scan_code(code string) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_code:' + code)
}

fn report_scan_error(message string) {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_error:' + message)
}

fn report_scan_cancelled() {
	if voidptr(g_event_handler) == unsafe { nil } {
		return
	}
	g_event_handler('scan_cancelled')
}

// ── Scanner callbacks ──────────────────────────────────────────────

@[export: 'vui_scanner_present']
fn vui_scanner_present(_self voidptr, _cmd voidptr, root voidptr) {
	native_present_barcode_scanner(View(root))
}

@[export: 'vui_scanner_layout']
fn vui_scanner_layout(self voidptr, _cmd voidptr) {
	// The chrome is tracked in globals, so a controller on its way out must
	// not lay out the one that replaced it.
	if View(self) != g_scanner_vc {
		return
	}
	layout_scanner(macos.msg_id(View(self), 'view'))
}

@[export: 'vui_scanner_cancel']
fn vui_scanner_cancel(self voidptr, _cmd voidptr) {
	if View(self) != g_scanner_vc {
		return
	}
	stop_scanner_session()
	dismiss_scanner()
	report_scan_cancelled()
}

@[export: 'vui_scanner_session_error']
fn vui_scanner_session_error(self voidptr, _cmd voidptr, notification voidptr) {
	if View(self) != g_scanner_vc {
		return
	}
	info := macos.msg_id(View(notification), 'userInfo')
	failure := macos.msg_id1(info, 'objectForKey:', extern_id('AVCaptureSessionErrorKey', 'AVCaptureSessionErrorKey'))
	code := macos.msg_i64(failure, 'code')
	stop_scanner_session()
	dismiss_scanner()
	if code == av_error_not_authorized {
		report_scan_error('camera permission denied')
	} else {
		report_scan_error('camera unavailable')
	}
}

@[export: 'vui_scanner_metadata']
fn vui_scanner_metadata(_self voidptr, _cmd voidptr, _output voidptr, objects voidptr, _connection voidptr) {
	if g_scanner_scanned {
		return
	}
	list := View(objects)
	count := int(macos.msg_u64(list, 'count'))
	for index in 0 .. count {
		metadata := macos.msg_id_u64(list, 'objectAtIndex:', u64(index))
		if !objc_is_kind_of(metadata, 'AVMetadataMachineReadableCodeObject') {
			continue
		}
		code := objc_string(macos.msg_id(metadata, 'stringValue'))
		if code.len == 0 {
			continue
		}
		g_scanner_scanned = true
		stop_scanner_session()
		dismiss_scanner()
		report_scan_code(code)
		return
	}
}
