// vfmt off
module ui2

import macos

#flag darwin -framework AppKit

const ns_modal_response_ok = i64(1)

fn native_file_dialog_supported() bool {
	return true
}

fn native_file_dialog(cfg FileDialogConfig) []string {
	pool := macos.autorelease_pool_new()
	defer {
		macos.release(pool)
	}
	macos.msg_id(macos.get_class('NSApplication'), 'sharedApplication')
	panel := if cfg.kind == .save {
		macos.msg_id(macos.get_class('NSSavePanel'), 'savePanel')
	} else {
		macos.msg_id(macos.get_class('NSOpenPanel'), 'openPanel')
	}
	if panel == unsafe { nil } {
		return []string{}
	}
	if cfg.title.len > 0 {
		macos.msg_void1(panel, 'setTitle:', macos.nsstring(cfg.title))
	}
	if cfg.directory.len > 0 {
		url := macos.msg_id1(macos.get_class('NSURL'), 'fileURLWithPath:',
			macos.nsstring(cfg.directory))
		macos.msg_void1(panel, 'setDirectoryURL:', url)
	}
	if cfg.kind == .save {
		macos.msg_void_bool(panel, 'setCanCreateDirectories:', true)
		if cfg.filename.len > 0 {
			macos.msg_void1(panel, 'setNameFieldStringValue:', macos.nsstring(cfg.filename))
		}
	} else {
		macos.msg_void_bool(panel, 'setCanChooseFiles:', cfg.kind == .open)
		macos.msg_void_bool(panel, 'setCanChooseDirectories:', cfg.kind == .folder)
		macos.msg_void_bool(panel, 'setAllowsMultipleSelection:', cfg.kind == .open && cfg.multiple)
	}
	extensions := file_dialog_extensions(cfg.filters)
	if cfg.kind != .folder && extensions.len > 0 {
		allowed := macos.msg_id(macos.alloc('NSMutableArray'), 'init')
		for extension in extensions {
			macos.msg_void1(allowed, 'addObject:', macos.nsstring(extension))
		}
		macos.msg_void1(panel, 'setAllowedFileTypes:', allowed)
		macos.release(allowed)
	}
	if macos.msg_i64(panel, 'runModal') != ns_modal_response_ok {
		return []string{}
	}
	if cfg.kind == .save {
		path := native_file_dialog_macos_url_path(macos.msg_id(panel, 'URL'))
		return if path.len > 0 { [path] } else { []string{} }
	}
	urls := macos.msg_id(panel, 'URLs')
	mut paths := []string{}
	for index in 0 .. int(macos.msg_u64(urls, 'count')) {
		paths << native_file_dialog_macos_url_path(macos.msg_id_u64(urls, 'objectAtIndex:',
			u64(index)))
	}
	return paths.filter(it.len > 0)
}

fn native_file_dialog_macos_url_path(url macos.Id) string {
	if url == unsafe { nil } {
		return ''
	}
	return macos.utf8_string(macos.msg_id(url, 'path'))
}
