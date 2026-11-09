module main

import ui2

const platform_width = 420
const platform_height = 360

@[heap]
pub struct PlatformDemo {
pub mut:
	badges int
	status string = 'Tap an action below.'
}

const platform_state = &PlatformDemo{}

fn platform_row(id string, title string, y f64, width f64) ui2.Element {
	return ui2.button(id, title, ui2.rect(16, y, width, 44), ui2.BoxStyle{
		bg:     0x2563eb
		radius: 8
	}, ui2.TextStyle{
		color: 0xffffff
		align: .center
	})
}

fn build_platform_screen() ui2.Element {
	state := unsafe { platform_state }
	frame := ui2.bounds()
	width := frame.width - 32
	status := ui2.label('status', state.status, ui2.rect(16, 16, width, 48), ui2.TextStyle{})
	return ui2.screen(0xffffff, [
		status,
		platform_row('buzz', 'Play haptic', 76, width),
		platform_row('badge', 'Stamp badge (${state.badges + 1})', 128, width),
		platform_row('open', 'Open vlang.io', 180, width),
		platform_row('share', 'Share this app', 232, width),
	])
}

fn handle_platform_event(event string) {
	mut state := unsafe { platform_state }
	match event {
		'buzz' {
			state.status = if ui2.haptic(.medium) { 'Haptic fired.' } else { 'No haptics here.' }
		}
		'badge' {
			state.badges++
			state.status = if ui2.set_app_badge(state.badges) {
				'Badge set to ${state.badges}.'
			} else {
				'No icon badge here.'
			}
		}
		'open' {
			state.status = if ui2.open_url('https://vlang.io') {
				'Link opened.'
			} else {
				'Cannot open links here.'
			}
		}
		'share' {
			state.status = if ui2.share_text('ui2 platform integration') {
				'Share sheet opened.'
			} else {
				'No share sheet here.'
			}
		}
		else {}
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('Platform', platform_width, platform_height, build_platform_screen,
		handle_platform_event)
}
