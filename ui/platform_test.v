module ui2

import os

fn test_platform_valid_url_accepts_web_and_mailto_links() {
	assert platform_valid_url('https://vlang.io')
	assert platform_valid_url('http://localhost:8080/path?q=1')
	assert platform_valid_url('https://example.com/a%20b')
	assert platform_valid_url('mailto:hello@example.com')
}

fn test_platform_valid_url_rejects_junk() {
	assert !platform_valid_url('')
	assert !platform_valid_url('   ')
	assert !platform_valid_url('not a url')
	assert !platform_valid_url('https://')
	assert !platform_valid_url('https://exa mple.com')
	assert !platform_valid_url('ftp://example.com/file')
	assert !platform_valid_url('file:///etc/hosts')
	assert !platform_valid_url('mailto:nobody')
	assert !platform_valid_url('mailto:   ')
}

fn test_open_url_rejects_bad_input_on_every_backend() {
	assert !open_url('')
	assert !open_url('just words')
	assert !open_url('ftp://example.com/x')
}

fn test_share_text_rejects_blank_on_every_backend() {
	assert !share_text('')
	assert !share_text('   ')
}

fn test_set_app_badge_rejects_negative_on_every_backend() {
	assert !set_app_badge(-1)
}

fn test_platform_supported_flags_match_the_backend() {
	$if windows {
		assert !haptic_supported()
		assert !app_badge_supported()
		assert open_url_supported()
		assert !share_supported()
	} $else $if macos {
		assert haptic_supported()
		assert app_badge_supported()
		assert open_url_supported()
		assert !share_supported()
	} $else $if ios {
		assert haptic_supported()
		assert app_badge_supported()
		assert open_url_supported()
		assert share_supported()
	} $else {
		// Linux, the BSDs, Android and the custom renderer answer unsupported
		// everywhere except URLs, which the nix desktops hand to xdg-open.
		assert !haptic_supported()
		assert !app_badge_supported()
		assert !share_supported()
	}
}

@[test]
fn test_platform_real_haptic_and_badge_opt_in() ! {
	if os.getenv('ui2_platform_real_test').len == 0 {
		eprintln('skipped: set ui2_platform_real_test=1 to fire a real haptic and badge')
		return
	}
	assert haptic_supported()
	assert haptic(.medium)
	assert app_badge_supported()
	assert set_app_badge(1)
	assert set_app_badge(0)
}
