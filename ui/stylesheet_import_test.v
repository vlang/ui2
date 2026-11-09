module ui2

import os

fn import_test_dir() string {
	dir := os.join_path(os.temp_dir(), 'ui2_import_test')
	os.mkdir_all(dir) or { panic(err) }
	return dir
}

fn import_test_write(dir string, name string, content string) string {
	path := os.join_path(dir, name)
	os.write_file(path, content) or { panic(err) }
	return path
}

fn test_import_basic_and_override() {
	dir := import_test_dir()
	import_test_write(dir, 'base.u2ss', 'Button { background: #ff0000; color: white; }')
	main := import_test_write(dir, 'main.u2ss', '@import "base.u2ss";
Button { background: #0000ff; }')
	sheet := load_stylesheet(main) or { panic(err) }
	assert sheet.rules.len == 2
	// The importing file comes after its imports.
	assert sheet.rules[0].declarations[0].value == '#ff0000'
	assert sheet.rules[1].declarations[0].value == '#0000ff'
	mut root := view('root', rect(0, 0, 100, 100), BoxStyle{}, [
		Element{ kind: .button, id: 'a', enabled: true },
	])
	root = apply_stylesheet(root, sheet, StyleMatchEnv{})
	assert root.children[0].box.bg == 0x0000ff
	assert root.children[0].text_style.color == 0xffffff
}

fn test_import_cycle_terminates() {
	dir := import_test_dir()
	import_test_write(dir, 'a.u2ss', '@import "b.u2ss";
Button { background: #ff0000; }')
	import_test_write(dir, 'b.u2ss', '@import "a.u2ss";
Button { color: white; }')
	sheet := load_stylesheet(os.join_path(dir, 'a.u2ss')) or { panic(err) }
	assert sheet.rules.len == 2
}

fn test_import_missing_file_errors() {
	dir := import_test_dir()
	main := import_test_write(dir, 'main.u2ss', '@import "nope.u2ss";
Button { background: #ff0000; }')
	if _ := load_stylesheet(main) {
		assert false, 'missing import must fail'
	} else {
		assert err.msg().contains('nope.u2ss')
	}
}

fn test_import_requires_semicolon() {
	if _ := parse_stylesheet('@import "x.u2ss"') {
		assert false, 'missing semicolon must fail'
	} else {
		assert err.msg().contains(';')
	}
}

fn test_import_url_form() {
	dir := import_test_dir()
	import_test_write(dir, 'other.u2ss', 'Button { background: #ff0000; }')
	main := import_test_write(dir, 'main.u2ss', '@import url(other.u2ss);
Button { color: white; }')
	sheet := load_stylesheet(main) or { panic(err) }
	assert sheet.rules.len == 2
}

fn test_stylesheet_file_mtime_missing() {
	assert stylesheet_file_mtime('/no/such/file/anywhere.u2ss') == 0
}

fn test_stylesheet_file_changed_tracks_edits() {
	dir := import_test_dir()
	path := import_test_write(dir, 'live.u2ss', 'Button { background: red; }')
	known := stylesheet_file_mtime(path)
	assert known != 0
	changed, now := stylesheet_file_changed(path, known)
	assert !changed
	assert now == known
	changed_again, _ := stylesheet_file_changed(path, known + 1)
	assert changed_again
}
