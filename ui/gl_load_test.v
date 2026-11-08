// Tests for the GlLoad flag: env parsing, vendor manifest picking and the
// env wiring configure_gl_libraries performs before sokol opens a display.
module ui2

import os
import time

// remove_test_dir deletes a scratch directory without failing the suite.
fn remove_test_dir(path string) {
	os.rmdir_all(path) or { return }
}

// write_test_file writes a scratch file, panicking loudly on failure so a
// broken fixture never masquerades as a pick_egl_vendor_json bug.
fn write_test_file(path string, content string) {
	os.write_file(path, content) or { panic('write ${path}: ${err}') }
}

fn test_gl_load_from_env_parses_names_aliases_and_unknowns() {
	defer {
		os.unsetenv(ui2_gl_vendor_env_var)
	}
	os.setenv(ui2_gl_vendor_env_var, 'mesa_only', true)
	assert (gl_load_from_env() or { panic('mesa_only not parsed') }) == .mesa_only
	os.setenv(ui2_gl_vendor_env_var, 'Software', true)
	assert (gl_load_from_env() or { panic('mesa alias not parsed') }) == .mesa_only
	os.setenv(ui2_gl_vendor_env_var, 'gpu', true)
	assert (gl_load_from_env() or { panic('gpu alias not parsed') }) == .gpu_only
	os.setenv(ui2_gl_vendor_env_var, 'NVIDIA', true)
	assert (gl_load_from_env() or { panic('nvidia alias not parsed') }) == .gpu_only
	os.setenv(ui2_gl_vendor_env_var, 'auto', true)
	assert (gl_load_from_env() or { panic('auto not parsed') }) == .auto
	os.setenv(ui2_gl_vendor_env_var, 'bogus', true)
	assert gl_load_from_env() == none
	os.setenv(ui2_gl_vendor_env_var, '', true)
	assert gl_load_from_env() == none
	os.setenv(ui2_gl_vendor_env_var, '   ', true)
	assert gl_load_from_env() == none
}

fn test_pick_egl_vendor_json_matches_by_name_and_content() {
	dir := os.join_path(os.temp_dir(), 'ui2_gl_load_${time.ticks()}')
	defer {
		remove_test_dir(dir)
	}
	os.mkdir(dir) or { panic('mkdir ${dir}: ${err}') }
	nvidia := os.join_path(dir, '10_nvidia.json')
	mesa := os.join_path(dir, '50_mesa.json')
	renamed := os.join_path(dir, '99_renamed.json')
	write_test_file(nvidia, '{"ICD":{"library_path":"libEGL_nvidia.so.0"}}')
	write_test_file(mesa, '{"ICD":{"library_path":"libEGL_mesa.so.0"}}')
	write_test_file(renamed, '{"ICD":{"library_path":"libEGL_mesa.so.0"}}')
	found_mesa := pick_egl_vendor_json([dir], true) or { panic('mesa manifest not picked') }
	assert found_mesa == mesa
	found_nvidia := pick_egl_vendor_json([dir], false) or { panic('nvidia manifest not picked') }
	assert found_nvidia == nvidia
	// Name detection only: the renamed file is still found through its
	// contents.
	os.rm(mesa) or { panic('rm ${mesa}: ${err}') }
	found_renamed := pick_egl_vendor_json([dir], true) or { panic('renamed manifest not picked') }
	assert found_renamed == renamed
	os.rm(nvidia) or { panic('rm ${nvidia}: ${err}') }
	os.rm(renamed) or { panic('rm ${renamed}: ${err}') }
	assert pick_egl_vendor_json([dir], true) == none
	assert pick_egl_vendor_json(['/no/such/dir'], true) == none
}

fn test_configure_gl_libraries_sets_env_and_respects_explicit_lists() {
	prev_filenames := os.getenv('__EGL_VENDOR_LIBRARY_FILENAMES')
	prev_dirs := os.getenv('__EGL_VENDOR_LIBRARY_DIRS')
	defer {
		os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', prev_filenames, true)
		os.setenv('__EGL_VENDOR_LIBRARY_DIRS', prev_dirs, true)
		os.unsetenv(ui2_gl_vendor_env_var)
	}
	// The explicit dirs override would short-circuit every block on a machine
	// that sets one, so the test runs with it cleared.
	os.unsetenv('__EGL_VENDOR_LIBRARY_DIRS')
	// An explicit glvnd vendor list wins over the flag, however it arrives.
	os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', '/pinned/by/user.json', true)
	os.setenv(ui2_gl_vendor_env_var, 'mesa_only', true)
	configure_gl_libraries(.auto)
	assert os.getenv('__EGL_VENDOR_LIBRARY_FILENAMES') == '/pinned/by/user.json'
	// Without a pinned list, the env override points glvnd at the Mesa
	// manifest wherever one is installed; machines without any Mesa manifest
	// are left untouched, which degenerates to .auto. A matched manifest is
	// probed before it is pinned, so a display the pinned vendor cannot serve
	// leaves the environment untouched as well.
	os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', '', true)
	configure_gl_libraries(.gpu_only)
	mesa := pick_egl_vendor_json(egl_vendor_dirs, true)
	assert os.getenv('__EGL_VENDOR_LIBRARY_FILENAMES') in [mesa or { '' }, '']
	// Without the env override the option field drives the setting. The pin
	// the last block left behind is cleared and UI2_GL_VENDOR unset, so the
	// option field is the only thing left to consult.
	os.unsetenv(ui2_gl_vendor_env_var)
	os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', '', true)
	configure_gl_libraries(.gpu_only)
	not_mesa := pick_egl_vendor_json(egl_vendor_dirs, false)
	assert os.getenv('__EGL_VENDOR_LIBRARY_FILENAMES') in [not_mesa or { '' }, '']
}
