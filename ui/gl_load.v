// GlLoad scopes the GL libraries a custom-rendered window may load. On Linux,
// glvnd probes the ICD manifest of every installed vendor before the first GL
// call, mapping each vendor's whole userspace stack into the process: the
// NVIDIA probe alone parks tens of megabytes in an application that will
// never talk to the NVIDIA driver, and a machine without the Mesa libraries
// wastes the same for Mesa. This module has to stay platform neutral so the
// native backends compile it too; the renderer block is the only caller.
module ui2

import os

// GlLoad selects which EGL vendor libraries glvnd may load when the window's
// GL context initializes. auto keeps glvnd's probe-every-vendor behavior.
// mesa_only probes the Mesa vendor only, for VMs, CI and Xvfb, where a
// proprietary vendor would only be mapped and never used. gpu_only probes the
// proprietary vendor only, so on a NVIDIA desktop the Mesa/LLVM libraries
// never load; it needs a real hardware GL context. Every pin is probed before
// it is applied, so on machines whose display the pinned vendor cannot serve,
// such as Intel-driven X screens for gpu_only, the pin is dropped and glvnd
// probes as usual instead of killing the window at startup.
pub enum GlLoad {
	auto
	mesa_only
	gpu_only
}

// ui2_gl_vendor_env_var names the environment variable that overrides the
// GlLoad an application compiled in. It lets the measurement harness, CI and
// packagers pick a GL stack without recompiling.
const ui2_gl_vendor_env_var = 'UI2_GL_VENDOR'

// egl_vendor_dirs lists the directories glvnd reads vendor ICD manifests
// from, in glvnd's own search order.
const egl_vendor_dirs = ['/etc/glvnd/egl_vendor.d', '/usr/share/glvnd/egl_vendor.d']

// gl_load_from_env parses ui2_gl_vendor_env_var. It accepts the enum names
// plus the shorter aliases software, mesa, gpu, nvidia and hardware. An unset
// or unrecognized value reports none, so the option's value stays in charge.
pub fn gl_load_from_env() ?GlLoad {
	value := os.getenv(ui2_gl_vendor_env_var).to_lower().trim_space()
	if value.len == 0 {
		return none
	}
	return match value {
		'auto' { GlLoad.auto }
		'mesa_only', 'mesa', 'software' { GlLoad.mesa_only }
		'gpu_only', 'gpu', 'nvidia', 'hardware' { GlLoad.gpu_only }
		else { none }
	}
}

// egl_vendor_jsons collects the ICD manifest files from dirs, sorted so the
// pick is stable whatever order the directory scans in.
fn egl_vendor_jsons(dirs []string) []string {
	mut files := []string{}
	for dir in dirs {
		if !os.is_dir(dir) {
			continue
		}
		entries := os.ls(dir) or { continue }
		for name in entries {
			if name.ends_with('.json') {
				files << os.join_path(dir, name)
			}
		}
	}
	files.sort()
	return files
}

// egl_vendor_is_mesa reports whether a manifest loads the Mesa vendor. The
// name usually settles it; the contents decide when a packager renamed the
// file.
fn egl_vendor_is_mesa(path string) bool {
	name := path.all_after_last('/').to_lower()
	if name.contains('mesa') || name.contains('swrast') || name.contains('llvmpipe') {
		return true
	}
	data := os.read_file(path) or { return false }
	lower := data.to_lower()
	return lower.contains('mesa') || lower.contains('swrast') || lower.contains('llvmpipe')
}

// pick_egl_vendor_json returns the first manifest in dirs whose vendor
// matches want_mesa, or none when no installed manifest matches. Callers
// treat none as "no restriction": a wrong flag must never break rendering.
pub fn pick_egl_vendor_json(dirs []string, want_mesa bool) ?string {
	for path in egl_vendor_jsons(dirs) {
		if egl_vendor_is_mesa(path) == want_mesa {
			return path
		}
	}
	return none
}

// configure_gl_libraries applies load before the window's GL context is
// created, so glvnd never maps the unselected vendor's userspace stack. The
// UI2_GL_VENDOR environment variable overrides `load`, and an explicit
// __EGL_VENDOR_LIBRARY_FILENAMES or __EGL_VENDOR_LIBRARY_DIRS wins over both:
// whoever set those on the process knows their machine better than the flag
// does. When no manifest matches, the setting is left untouched, which
// degenerates to .auto. A matched manifest is probed before it is pinned: on
// a machine whose display the pinned vendor cannot serve, a blind pin leaves
// sokol initializing EGL with no working vendor at all, which kills the
// window at startup, so a failed probe leaves glvnd's probe-every-vendor
// behavior in place instead.
pub fn configure_gl_libraries(load GlLoad) {
	if os.user_os() != 'linux' {
		return
	}
	if os.getenv('__EGL_VENDOR_LIBRARY_FILENAMES').len > 0 {
		return
	}
	if os.getenv('__EGL_VENDOR_LIBRARY_DIRS').len > 0 {
		return
	}
	mut mode := load
	if from_env := gl_load_from_env() {
		mode = from_env
	}
	match mode {
		.auto { return }
		else {}
	}
	json := pick_egl_vendor_json(egl_vendor_dirs, mode == .mesa_only) or {
		return
	}
	$if linux {
		if !egl_vendor_initializes(json) {
			eprintln('ui2: GL vendor pin ${json} cannot initialize the display; keeping glvnd vendor probing')
			return
		}
	}
	os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', json, true)
}

// egl_vendor_initializes reports whether EGL can create and initialize the
// default display with manifest pinned. The probe forks: glvnd reads the
// vendor list once per process, so a failed pin inside this process could not
// be undone by unsetting the environment, and a vendor that crashes while
// initializing would take the window down with it. The child dies with the
// verdict and never reaches the window.
$if linux {
	fn egl_vendor_initializes(manifest string) bool {
		pid := C.fork()
		if pid < 0 {
			return true // cannot fork: keep the pin, the flag is only a hint
		}
		if pid == 0 {
			// Child: probe the pinned vendor and die with the verdict.
			os.setenv('__EGL_VENDOR_LIBRARY_FILENAMES', manifest, true)
			dpy := C.eglGetDisplay(voidptr(0)) // EGL_DEFAULT_DISPLAY
			if dpy == EGLDisplay(0) {
				C._exit(1)
			}
			mut major := EGLint(0)
			mut minor := EGLint(0)
			if C.eglInitialize(dpy, &major, &minor) != 1 {
				C._exit(1)
			}
			C.eglTerminate(dpy)
			C._exit(0)
		}
		mut status := i32(0)
		C.wait(&status)
		return (status & 0x7f) == 0 && ((status >> 8) & 0xff) == 0
	}

	fn C.fork() i32

	fn C.wait(status &i32) i32

	// The EGL types match sokol's declarations in vlib/sokol/sapp/sapp_linux.c.v:
	// when sokol is linked in, the same C functions are declared twice, and a
	// mismatch in the declared signatures or the alias backing them up makes the
	// V compiler report a C-declaration clash before any of this code compiles.
	type EGLDisplay = voidptr
	type EGLint = i32

	fn C.eglGetDisplay(native_display voidptr) EGLDisplay

	fn C.eglInitialize(display EGLDisplay, major &EGLint, minor &EGLint) int

	fn C.eglTerminate(display EGLDisplay) int

	fn C._exit(status i32)
}
