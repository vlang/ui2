module ui2

import os

pub struct VmlImportButtonApp {
pub mut:
	saved bool
}

pub fn (mut app VmlImportButtonApp) save() {
	app.saved = true
}

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

fn test_imported_composite_button_accepts_children_and_dispatches_its_action() {
	dir := vml_import_test_dir('action_surface')
	defer {
		os.rmdir_all(dir) or {}
	}
	os.write_file(os.join_path(dir, 'app.vml'), 'import ActionSurface

Screen {
	ActionSurface {
		id: save_card
		on_tap: app.save()
		x: 20
		y: 20
		width: 180

		Label {
			text: "Save changes"
			x: 16
			y: 16
			width: save_card.width - 32
			height: 24
		}
	}
}') or { panic(err) }
	os.write_file(os.join_path(dir, 'action_surface.vml'), 'module ActionSurface

Rectangle {
	button_behavior: true
	height: 56
	background: #2563EB
	corner_radius: 8
}') or { panic(err) }

	mut app := new_vml_app_file(os.join_path(dir, 'app.vml'), VmlImportButtonApp{}) or {
		panic(err)
	}
	built := app.build(rect(0, 0, 320, 200)) or { panic(err) }
	assert built.children.len == 1
	surface := built.children[0]
	assert surface.kind == .view
	assert surface.button_behavior
	assert surface.accessibility_role == 'button'
	assert surface.accessibility_label == 'Save changes'
	assert surface.children.len == 1
	assert surface.children[0].frame.width == 148
	app.handle(surface.action_id) or { panic(err) }
	assert app.state().saved
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
