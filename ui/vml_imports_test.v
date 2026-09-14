module ui2

import os

fn vml_import_test_dir(name string) string {
	dir := os.join_path(os.temp_dir(), 'ui2_vml_import_test', name)
	os.rmdir_all(dir) or {}
	os.mkdir_all(dir) or { panic(err) }
	return dir
}

fn test_parse_vml_file_expands_a_snake_case_imported_module() {
	dir := vml_import_test_dir('primary_screen')
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'main.vml'), 'import PrimaryScreen

Screen {
	ScreenManager {
		PrimaryScreen {}
	}
}') or { panic(err) }
	os.write_file(os.join_path(dir, 'primary_screen.vml'), 'module PrimaryScreen

Screen {
	id: home
	Label { text: "Home" }
}') or { panic(err) }
	node := parse_vml_file(os.join_path(dir, 'main.vml')) or { panic(err) }
	assert node.tag == 'Screen'
	assert node.children[0].tag == 'ScreenManager'
	assert node.children[0].children[0].tag == 'Screen'
	assert node.children[0].children[0].id == 'home'
	assert node.children[0].children[0].children[0].prop('text') == 'Home'
}

fn test_parse_vml_file_rejects_missing_or_mismatched_import_modules() {
	dir := vml_import_test_dir('invalid_module')
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'main.vml'), 'import PrimaryScreen
Screen { PrimaryScreen {} }') or { panic(err) }
	if _ := parse_vml_file(os.join_path(dir, 'main.vml')) {
		assert false, 'a missing import must be rejected'
	}
	os.write_file(os.join_path(dir, 'primary_screen.vml'), 'module WrongName
Screen {}') or { panic(err) }
	if _ := parse_vml_file(os.join_path(dir, 'main.vml')) {
		assert false, 'an imported file must declare the imported module name'
	}
}

fn test_parse_vml_file_rejects_import_cycles() {
	dir := vml_import_test_dir('cycle')
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'main.vml'), 'import First
Screen { First {} }') or { panic(err) }
	os.write_file(os.join_path(dir, 'first.vml'), 'module First
import Second
Screen { Second {} }') or { panic(err) }
	os.write_file(os.join_path(dir, 'second.vml'), 'module Second
import First
Screen { First {} }') or { panic(err) }
	if _ := parse_vml_file(os.join_path(dir, 'main.vml')) {
		assert false, 'cyclic imports must be rejected'
	}
}
