// macOS has no X11, so the RandR reader in monitor_nix.v does not apply to it.
// No macOS reader exists yet, so it reports 0 ("cannot tell"), as before.
module ui2

fn native_monitor_refresh_rate() f64 {
	return 0
}
