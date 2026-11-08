module ui2

import os
import sokol.sapp

// The bundled fonts live inside the APK, and the font lookup reads files, so on
// Android they are copied out of the package into the app's internal data
// directory the first time they are asked for. The copy reads until the whole
// asset is in hand: os.read_apk_asset makes one read, and an asset stored
// compressed can come back short.
const android_bundled_fonts = [
	'MaterialIcons-Regular.ttf',
	'NotoEmoji-Regular.ttf',
	'NotoSansSymbols2-Regular.ttf',
	'Roboto-Bold.ttf',
	'Roboto-BoldItalic.ttf',
	'Roboto-Italic.ttf',
	'Roboto-Regular.ttf',
	'RobotoMono-Bold.ttf',
	'RobotoMono-Regular.ttf',
]

// android_font_dir returns the directory the bundled fonts are unpacked into,
// unpacking whichever of them are missing first.
fn android_font_dir() ?string {
	act := unsafe { &os.NativeActivity(sapp.android_get_native_activity()) }
	if isnil(act) {
		return none
	}
	dir := os.join_path(unsafe { cstring_to_vstring(act.internalDataPath) }, 'fonts')
	os.mkdir_all(dir) or { return none }
	for name in android_bundled_fonts {
		target := os.join_path(dir, name)
		if os.is_file(target) {
			continue
		}
		data := read_apk_asset_fully('fonts/${name}') or { continue }
		os.write_file_array(target, data) or {}
	}
	return dir
}

// read_apk_asset_fully reads the whole asset at path, relative to the APK's
// assets directory, or none when the package does not have it.
fn read_apk_asset_fully(path string) ?[]u8 {
	act := unsafe { &os.NativeActivity(sapp.android_get_native_activity()) }
	if isnil(act) {
		return none
	}
	asset := act.assetManager.open(path, .streaming) or { return none }
	defer {
		asset.close()
	}
	mut buf := []u8{len: int(asset.get_length_64())}
	mut done := 0
	for done < buf.len {
		n := asset.read(unsafe { voidptr(u64(buf.data) + u64(done)) }, uint(buf.len - done))
		if n <= 0 {
			break
		}
		done += n
	}
	if done != buf.len {
		return none
	}
	return buf
}
