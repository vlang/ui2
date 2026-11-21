@[has_globals]
module main

import ui2

// The same build/on_event pair runs on desktop (ui2.run_window) and in a
// browser (ui2.run_web_window, with -d ui2_headless). No app code is changed
// between the two: the web backend owns state through the ui2.text(),
// ui2.slider_value() and ui2.scroll_offset() accessors.
struct Model {
mut:
	count     int
	last_name string = 'Ada'
	volume    f64    = 25.0
	accepted  bool
}

__global g_counter_model = Model{}

fn build() ui2.Element {
	caption := if g_counter_model.accepted { 'Ready' } else { 'Not accepted' }
	return ui2.screen(0xf4f6f8, [
		ui2.view('panel', ui2.rect(24, 24, 452, 272), ui2.BoxStyle{
			bg:            0xffffff
			radius:        12
			border_color:  0xe5e7eb
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, [
			ui2.label('title', 'ui2 web counter', ui2.rect(20, 16, 260, 28), ui2.TextStyle{
				size:  18.0
				bold:  true
				color: 0x111827
			}),
			ui2.label('value', 'count: ${g_counter_model.count}', ui2.rect(20, 52, 260, 30), ui2.TextStyle{
				size:  16.0
				color: 0x2563eb
			}),
			ui2.label('status', caption, ui2.rect(20, 86, 260, 24), ui2.TextStyle{
				size:  12.0
				color: 0x6b7280
			}),
			ui2.button('dec', '-', ui2.rect(20, 120, 56, 36), ui2.BoxStyle{
				bg:     0xe5e7eb
				radius: 8
			}, ui2.TextStyle{ size: 18.0 }),
			ui2.button('inc', '+', ui2.rect(84, 120, 56, 36), ui2.BoxStyle{
				bg:     0x2563eb
				radius: 8
			}, ui2.TextStyle{ color: 0xffffff, size: 18.0 }),
			ui2.button('reset', 'Reset', ui2.rect(148, 120, 88, 36), ui2.BoxStyle{
				bg:     0xf3f4f6
				radius: 8
			}, ui2.TextStyle{}),
			ui2.text_field('name', 'Name', g_counter_model.last_name, ui2.rect(20, 168, 240, 32), ui2.BoxStyle{
				bg: 0xffffff
			}, ui2.TextStyle{}, ui2.keyboard_default),
			ui2.checkbox('terms', 'Accept terms', g_counter_model.accepted, ui2.rect(20, 212, 240, 24),
				ui2.TextStyle{}),
			ui2.label('name_echo', 'hello, ${g_counter_model.last_name}', ui2.rect(272, 168, 160, 24),
				ui2.TextStyle{
					size:  12.0
					color: 0x374151
				}),
			ui2.slider(ui2.SliderConfig{
				id:    'volume'
				frame: ui2.rect(272, 212, 160, 24)
				min:   0
				max:   100
				value: g_counter_model.volume
			}),
		]),
		ui2.scroll('log', ui2.rect(24, 312, 452, 96), 0xffffff, [
			ui2.label('log0', 'events appear here as the g_counter_model changes', ui2.rect(8, 8, 420, 20),
				ui2.TextStyle{}),
			ui2.label('log1', 'count: ${g_counter_model.count} · name: ${g_counter_model.last_name} · volume: ${int(g_counter_model.volume)}',
				ui2.rect(8, 32, 420, 20), ui2.TextStyle{}),
		]),
	])
}

fn on_event(event string) {
	match event {
		'inc' {
			g_counter_model.count++
		}
		'dec' {
			g_counter_model.count--
		}
		'reset' {
			g_counter_model.count = 0
		}
		'name' {
			g_counter_model.last_name = ui2.text('name')
		}
		'terms' {
			g_counter_model.accepted = !g_counter_model.accepted
		}
		'volume' {
			g_counter_model.volume = ui2.slider_value('volume')
		}
		else {
			eprintln('unhandled event: ${event}')
		}
	}
}

fn main() {
	$if ui2_headless ? {
		ui2.run_web_window(ui2.WebOptions{
			title:  'ui2 web counter'
			width:  500
			height: 430
		}, build, on_event)
	} $else {
		ui2.run_window('ui2 web counter', 500, 430, build, on_event)
	}
}
