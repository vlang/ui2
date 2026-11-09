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
	import_test_write(dir, 'base.vss', 'Button { background: #ff0000; color: white; }')
	main := import_test_write(dir, 'main.vss', '@import "base.vss";
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
	import_test_write(dir, 'a.vss', '@import "b.vss";
Button { background: #ff0000; }')
	import_test_write(dir, 'b.vss', '@import "a.vss";
Button { color: white; }')
	sheet := load_stylesheet(os.join_path(dir, 'a.vss')) or { panic(err) }
	assert sheet.rules.len == 2
}

fn test_import_missing_file_errors() {
	dir := import_test_dir()
	main := import_test_write(dir, 'main.vss', '@import "nope.vss";
Button { background: #ff0000; }')
	if _ := load_stylesheet(main) {
		assert false, 'missing import must fail'
	} else {
		assert err.msg().contains('nope.vss')
	}
}

fn test_import_requires_semicolon() {
	if _ := parse_stylesheet('@import "x.vss"') {
		assert false, 'missing semicolon must fail'
	} else {
		assert err.msg().contains(';')
	}
}

fn test_import_url_form() {
	dir := import_test_dir()
	import_test_write(dir, 'other.vss', 'Button { background: #ff0000; }')
	main := import_test_write(dir, 'main.vss', '@import url(other.vss);
Button { color: white; }')
	sheet := load_stylesheet(main) or { panic(err) }
	assert sheet.rules.len == 2
}

fn test_stylesheet_file_mtime_missing() {
	assert stylesheet_file_mtime('/no/such/file/anywhere.vss') == 0
}

fn test_stylesheet_file_changed_tracks_edits() {
	dir := import_test_dir()
	path := import_test_write(dir, 'live.vss', 'Button { background: red; }')
	known := stylesheet_file_mtime(path)
	assert known != 0
	changed, now := stylesheet_file_changed(path, known)
	assert !changed
	assert now == known
	changed_again, _ := stylesheet_file_changed(path, known + 1)
	assert changed_again
}

fn test_import_splices_variables_in_source_order() {
	dir := import_test_dir()
	import_test_write(dir, 'vars.vss', '--x: #0000ff;')
	before := import_test_write(dir, 'before.vss', '--x: #ff0000;
@import "vars.vss";')
	after := import_test_write(dir, 'after.vss', '@import "vars.vss";
--x: #ff0000;')
	assert (load_stylesheet(before) or { panic(err) }).variables['--x'] == '#0000ff'
	assert (load_stylesheet(after) or { panic(err) }).variables['--x'] == '#ff0000'
}

fn test_import_splices_rules_in_place() {
	dir := import_test_dir()
	import_test_write(dir, 'late.vss', 'Button { background: #0000ff; }')
	main := import_test_write(dir, 'late_main.vss', 'Button { background: #ff0000; }
@import "late.vss";')
	sheet := load_stylesheet(main) or { panic(err) }
	assert sheet.rules.len == 2
	assert sheet.rules[0].declarations[0].value == '#ff0000'
	assert sheet.rules[1].declarations[0].value == '#0000ff'
}

fn test_import_error_names_the_file() {
	dir := import_test_dir()
	import_test_write(dir, 'broken.vss', 'Button { color red; }')
	main := import_test_write(dir, 'broken_main.vss', '@import "broken.vss";')
	if _ := load_stylesheet(main) {
		assert false, 'broken import must fail'
	} else {
		assert err.msg().contains('broken.vss:1:')
	}
}

fn test_import_cannot_leave_the_stylesheet_directory() {
	dir := import_test_dir()
	inner := os.join_path(dir, 'confined')
	os.mkdir_all(inner) or { panic(err) }
	import_test_write(dir, 'outside.vss', 'Button { color: red; }')
	main := import_test_write(inner, 'main.vss', '@import "../outside.vss";')
	if _ := load_stylesheet(main) {
		assert false, 'escaping import must fail'
	} else {
		assert err.msg().contains('outside the stylesheet directory')
	}
	absolute := import_test_write(inner, 'abs.vss', '@import "${os.join_path(dir, 'outside.vss')}";')
	if _ := load_stylesheet(absolute) {
		assert false, 'absolute import outside the root must fail'
	} else {
		assert err.msg().contains('outside the stylesheet directory')
	}
	// An explicit wider root allows it.
	sheet := load_stylesheet_within(main, dir) or { panic(err) }
	assert sheet.rules.len == 1
}
