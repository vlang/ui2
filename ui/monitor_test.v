// The rate depends on the machine's display setup, so the test can only pin
// the documented contract: a rate the platform could not determine is 0, and
// anything else is a plausible refresh rate.
module ui2

fn test_monitor_refresh_rate_is_zero_or_a_plausible_rate() {
	rate := monitor_refresh_rate()
	assert rate == 0 || (rate > 20 && rate < 500)
}
