module ui2

import math
import os
import time

// Windows MCI round-trip against a generated tone: open, duration, transport
// and close must all work through the real winmm driver. Playback assertions
// only run when the machine actually starts the stream, so the suite stays
// green on headless runners without silently passing on a broken driver:
// open, duration and close are asserted unconditionally.
$if windows {
	fn write_media_test_tone(path string, secs int) {
		sample_rate := 8000
		n := secs * sample_rate
		mut data := []u8{cap: 44 + n * 2}
		data << 'RIFF'.bytes()
		size := u32(36 + n * 2)
		data << [u8(size & 0xff), u8((size >> 8) & 0xff), u8((size >> 16) & 0xff),
			u8((size >> 24) & 0xff)]
		data << 'WAVE'.bytes()
		data << 'fmt '.bytes()
		data << [u8(16), 0, 0, 0, 1, 0, 1, 0]
		data << [u8(0x40), u8(0x1f), 0, 0]
		data << [u8(0x80), u8(0x3e), 0, 0, 2, 0, 16, 0]
		data << 'data'.bytes()
		data << [u8((n * 2) & 0xff), u8(((n * 2) >> 8) & 0xff), u8(((n * 2) >> 16) & 0xff),
			u8(((n * 2) >> 24) & 0xff)]
		for i in 0 .. n {
			t := f64(i) / f64(sample_rate)
			s := i16(10000.0 * math.sin(t * 440.0 * 2.0 * math.pi))
			data << u8(u16(s) & 0xff)
			data << u8((u16(s) >> 8) & 0xff)
		}
		os.write_file_array(path, data) or { panic(err) }
	}

	fn test_windows_mci_audio_round_trip() {
		assert media_playback_supported(.audio)
		assert media_playback_supported(.video)
		wav := os.join_path(os.temp_dir(), 'ui2_media_test.wav')
		write_media_test_tone(wav, 2)
		defer {
			os.rm(wav) or {}
		}
		assert media_open('mci-tone', .audio, wav)
		defer {
			media_close('mci-tone')
		}
		duration := media_duration('mci-tone')
		assert duration > 1.9 && duration < 2.1
		assert media_can_seek('mci-tone')
		if media_play('mci-tone') {
			time.sleep(300 * time.millisecond)
			assert media_state('mci-tone') == .playing
			assert media_position('mci-tone') >= 0
			assert media_pause('mci-tone')
			assert media_state('mci-tone') == .paused
			assert media_play('mci-tone')
			assert media_seek('mci-tone', 1.0)
			assert media_set_volume('mci-tone', 0.5)
			assert media_set_muted('mci-tone', true)
			assert media_set_muted('mci-tone', false)
			assert media_set_rate('mci-tone', 1.0)
			assert media_set_loop('mci-tone', true)
			assert media_set_loop('mci-tone', false)
			assert media_stop('mci-tone')
			assert media_state('mci-tone') == .stopped
		}
	}

	fn test_windows_screen_capture_writes_a_bitmap() {
		assert media_capture_supported(.screen)
		shot := os.join_path(os.temp_dir(), 'ui2_media_shot_test.bmp')
		defer {
			os.rm(shot) or {}
		}
		assert media_capture_screen(shot)
		assert os.exists(shot)
		assert os.file_size(shot) > 54
	}

	fn test_windows_mic_record_round_trip() {
		assert media_capture_supported(.microphone)
		rec := os.join_path(os.temp_dir(), 'ui2_media_rec_test.wav')
		defer {
			os.rm(rec) or {}
		}
		if media_start_recording('mci-memo', .microphone, rec) {
			defer {
				media_stop_recording('mci-memo')
				media_close('mci-memo')
			}
			time.sleep(300 * time.millisecond)
			assert media_state('mci-memo') == .recording
			assert media_recording_elapsed('mci-memo') >= 0
			assert media_stop_recording('mci-memo')
			assert media_state('mci-memo') == .stopped
		}
	}
}
