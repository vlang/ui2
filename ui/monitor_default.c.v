// Fallback for platforms this layer has no refresh-rate reader for yet.
module ui2

fn native_monitor_refresh_rate() f64 {
	return 0
}
