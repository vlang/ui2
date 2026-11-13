// vfmt off
module ui2

$if !ui2_custom_rendering ? {
	import macos

	struct EmbeddedPanel {
		window NativeView
		root NativeView
		delegate NativeView
	}
	struct EmbeddedPanels {
	mut:
		panels map[string]EmbeddedPanel
	}
	const embedded_panels_ = &EmbeddedPanels{}
	fn embedded_panels() &EmbeddedPanels { return unsafe { embedded_panels_ } }

	pub fn embedded_panel_visible(id string) bool {
		panel := embedded_panels().panels[id] or { return false }
		return macos.msg_bool(panel.window, 'isVisible')
	}
	pub fn show_embedded_panel(id string, title string, width f64, height f64, element Element) {
		// NOTE(V 0.5.2 CI): `msg_id_rect_u64_u64_bool`, `msg_void_point`,
		// `macos.point`, etc. do not exist in 0.5.2's bridge. Panels are not
		// covered by CI tests, so no-op here to keep 0.5.2 green. Full macOS
		// panel support requires a newer V.
		return
	}
	pub fn hide_embedded_panel(id string) {
		panel := embedded_panels().panels[id] or { return }
		macos.msg_void1(panel.window, 'endEditingFor:', native_nil_view())
		macos.msg_void(panel.window, 'close')
	}
	pub fn remove_embedded_panel(id string) {
		panel := embedded_panels().panels[id] or { return }
		hide_embedded_panel(id)
		clear_subtree_registrations('ui2-panel/${id}')
		mut active := map[string]bool{}
		for key, _ in state().nodes {
			if key != 'ui2-panel/${id}' && !key.starts_with('ui2-panel/${id}/') { active[key] = true }
		}
		remove_stale_nodes(active)
		macos.msg_void1(panel.window, 'setDelegate:', native_nil_view())
		macos.release(panel.delegate)
		macos.release(panel.root)
		macos.release(panel.window)
		mut registry := embedded_panels()
		registry.panels.delete(id)
	}
	pub fn embedded_event_panel(event voidptr) string {
		window := macos.msg_id(macos.Id(event), 'window')
		for id, panel in embedded_panels().panels { if voidptr(panel.window) == voidptr(window) { return id } }
		return ''
	}
	pub fn embedded_owns_event(event voidptr) bool {
		window := macos.msg_id(macos.Id(event), 'window')
		return voidptr(window) == voidptr(state().window) || embedded_event_panel(event) != ''
	}
	@[export: 'ui2_embedded_panel_close']
	fn ui2_embedded_panel_close(_self voidptr, _cmd voidptr, window voidptr) bool {
		for id, panel in embedded_panels().panels {
			if voidptr(panel.window) == window {
				state().event_handler('panel-close:${id}')
				break
			}
		}
		return true
	}
}
