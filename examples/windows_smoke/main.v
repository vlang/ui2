module main

import os
import time
import ui2

@[heap]
struct SmokeState {
mut:
	built    bool
	verified bool
	error    string
}

const smoke_state = &SmokeState{}

fn build_smoke_screen() ui2.Element {
	mut state := unsafe { smoke_state }
	state.built = true
	return ui2.screen(0xf3f4f6, [
		ui2.label('title', 'ui2 native Windows smoke test', ui2.rect(16, 12, 360, 28), ui2.TextStyle{
			size: 18
			bold: true
		}),
		ui2.view('panel', ui2.rect(16, 50, 360, 260), ui2.BoxStyle{
			bg: 0xffffff
		}, [
			ui2.button('button', 'Native button', ui2.rect(12, 12, 150, 34), ui2.BoxStyle{}, ui2.TextStyle{}),
			ui2.dropdown('dropdown', 'Two', ['One', 'Two', 'Three'], ui2.rect(178, 12, 160, 34), ui2.BoxStyle{}, ui2.TextStyle{}),
			ui2.text_field_with_change_and_submit('field', 'submit', 'Native text field', 'hello', ui2.rect(12, 60, 326, 32), ui2.BoxStyle{}, ui2.TextStyle{}, ui2.keyboard_default),
			ui2.text_area('area', 'Native multiline EDIT control', ui2.rect(12, 106, 326, 72), ui2.BoxStyle{}, ui2.TextStyle{}),
			ui2.image('image', '', ui2.rect(12, 190, 40, 40)),
			ui2.scroll('scroll', ui2.rect(66, 190, 272, 54), 0xf8fafc, [
				ui2.label('scroll-label', 'Native scrolling container', ui2.rect(8, 8, 220, 24), ui2.TextStyle{}),
				ui2.label('scroll-overflow', 'overflow', ui2.rect(8, 90, 100, 24), ui2.TextStyle{}),
			]),
		]),
	])
}

fn handle_smoke_event(_event string) {}

fn verify_and_close_smoke_window() {
	mut state := unsafe { smoke_state }
	checks := {
		'title':        'ui2 native Windows smoke test'
		'button':       'Native button'
		'dropdown':     'Two'
		'field':        'hello'
		'area':         'Native multiline EDIT control'
		'scroll-label': 'Native scrolling container'
	}
	mut last_error := 'native controls were not built'
	for _ in 0 .. 100 {
		if state.built {
			mut ready := true
			for id, expected in checks {
				actual := ui2.text(id)
				if actual != expected {
					last_error = '${id}: expected `${expected}`, got `${actual}`'
					ready = false
					break
				}
			}
			if ready {
				ui2.text_area_set_selection('area', 7, 9)
				if ui2.text_area_caret('area') != 7
					|| ui2.text_area_selection_length('area') != 9 {
					last_error = 'native text-area selection did not round-trip'
				} else {
					state.verified = true
					ui2.quit()
					return
				}
			}
		}
		time.sleep(100 * time.millisecond)
	}
	state.error = last_error
	ui2.quit()
}

fn main() {
	spawn verify_and_close_smoke_window()
	ui2.run_window('ui2 Wine smoke test', 392, 328, build_smoke_screen, handle_smoke_event)
	state := unsafe { smoke_state }
	if !state.built || !state.verified {
		eprintln('UI2_WINE_SMOKE_FAILED: ${state.error}')
		exit(1)
	}
	result_path := os.getenv('UI2_WINE_SMOKE_RESULT')
	if result_path != '' {
		os.write_file(result_path, 'UI2_WINE_SMOKE_OK\n') or {
			eprintln('UI2_WINE_SMOKE_FAILED: ${err}')
			exit(1)
		}
	}
	println('UI2_WINE_SMOKE_OK')
}
