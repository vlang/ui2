module ui2

import os
import time

fn test_platform_valid_url_accepts_web_and_mailto_links() {
	assert platform_valid_url('https://vlang.io')
	assert platform_valid_url('http://localhost:8080/path?q=1')
	assert platform_valid_url('https://example.com/a%20b')
	assert platform_valid_url('mailto:hello@example.com')
	assert platform_valid_url('HTTPS://example.com/path')
	assert platform_valid_url('https://[::1]:8080/path')
	assert platform_valid_url('https://example.com/🙂')
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
	for url in ['https:///path', 'http://?q=1', 'https://#fragment', 'https://:80', 'https://user@/path',
		'https://[::1', 'https://example.com/%zz', 'mailto:@example.com', 'mailto:hello@',
		'mailto:?subject=a@b'] {
		assert !platform_valid_url(url), url
	}
}

fn test_platform_valid_url_judges_the_exact_string_it_is_given() {
	// open_url trims once and forwards the very value it validated, so the
	// validator must not trim a copy of its own: padding could then pass
	// validation while the backend still received it.
	assert platform_valid_url('https://vlang.io')
	assert !platform_valid_url(' https://vlang.io')
	assert !platform_valid_url('https://vlang.io ')
	assert !platform_valid_url('https://vlang.io\n')
	assert !platform_valid_url('\thttps://vlang.io')
	assert !open_url('  just words  ')
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
	} $else $if android {
		// A running activity can launch intents without a vibrator or the
		// VIBRATE permission. Haptics are a separate hardware capability.
		assert !app_badge_supported()
		if haptic_supported() {
			assert open_url_supported()
		}
		assert open_url_supported() == share_supported()
	} $else {
		// Linux, the BSDs and the custom renderer answer unsupported everywhere
		// except URLs, which the nix desktops hand to xdg-open.
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

fn test_open_url_passes_one_normalized_literal_argument_to_the_launcher() ! {
	$if linux || freebsd || openbsd || netbsd || dragonfly || solaris {
		dir := os.join_path(os.temp_dir(), "ui2-opener 'test-${os.getpid()}")
		os.mkdir_all(dir)!
		defer { os.rmdir_all(dir) or {} }
		script := os.join_path(dir, 'xdg-open')
		output := os.join_path(dir, 'url.txt')
		os.write_file(script, '#!/bin/sh\n[ "$#" -eq 1 ] || exit 3\nprintf "%s" "$1" > "$UI2_TEST_URL_OUTPUT"\n/bin/sleep 3\n')!
		os.chmod(script, 0o755)!
		old_path := os.getenv('PATH')
		old_output := os.getenv_opt('UI2_TEST_URL_OUTPUT')
		os.setenv('PATH', dir, true)
		os.setenv('UI2_TEST_URL_OUTPUT', output, true)
		defer {
			os.setenv('PATH', old_path, true)
			if value := old_output {
				os.setenv('UI2_TEST_URL_OUTPUT', value, true)
			} else {
				os.unsetenv('UI2_TEST_URL_OUTPUT')
			}
		}
		assert open_url_supported()
		url := "https://example.com/a'b?value=$(echo)&other=✓"
		start := time.sys_mono_now()
		assert open_url(' \t${url}\n')
		assert time.sys_mono_now() - start < 2 * time.second
		// Starting the request succeeds before the launcher has necessarily
		// written its argument. No real browser is launched by this fixture.
		for _ in 0 .. 100 {
			if (os.read_file(output) or { '' }) == url {
				break
			}
			time.sleep(10 * time.millisecond)
		}
		assert os.read_file(output)! == url
		os.rm(script)!
		assert !open_url_supported()
		assert !open_url(url)
	}
}
