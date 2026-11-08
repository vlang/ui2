// monitor_refresh_rate reports how often the display refreshes, in Hz: 60 on
// a 60 Hz panel, 90 or 120 on a higher-rate one. It returns 0 when the
// platform cannot tell — a native Wayland session, or no RandR to ask.
//
// RandR reports whole Hz, so a 60.01 Hz panel reads as 60. Callers that need
// the exact rate refine it from their own presentation timing.
module ui2

pub fn monitor_refresh_rate() f64 {
	return native_monitor_refresh_rate()
}
