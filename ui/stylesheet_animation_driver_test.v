@[has_globals]
module ui2

import math
import os
import time

fn style_reg_reset(source string) {
	reset_widget_animations()
	clear_global_stylesheet()
	set_global_stylesheet(parse_stylesheet(source) or { panic(err) })
}

fn style_reg_cleanup() {
	reset_widget_animations()
	clear_global_stylesheet()
}

fn style_reg_frame(active bool, now i64) Element {
	el := view('target', rect(0, 0, 100, 40), BoxStyle{}, [])
	styled := apply_stylesheet(if active { with_classes(el, 'active') } else { el }, global_stylesheet(), StyleMatchEnv{})
	style_animation_drive_at(styled, now)
	return styled
}

const style_reg_fade = '@keyframes fade { from { opacity: 0; } to { opacity: 1; } }'

fn test_style_running_keyframes_pick_up_variable_changes_without_restarting() {
	style_reg_reset('@keyframes fade { from { opacity: 0; } to { opacity: var(--alpha); } }
		View { --alpha: 0.2; animation: fade 1s linear forwards; }
		View.active { --alpha: 0.8; }')
	defer { style_reg_cleanup() }
	initial := style_reg_frame(false, 0)
	assert apply_widget_animations_at(initial, 500).box.opacity == 0.1
	updated := style_reg_frame(true, 500)
	assert apply_widget_animations_at(updated, 500).box.opacity == 0.4
	assert apply_widget_animations_at(updated, 1000).box.opacity == 0.8
	// Filled animations also keep tracking their computed keyframe values.
	filled := style_reg_frame(false, 1500)
	assert apply_widget_animations_at(filled, 1500).box.opacity == 0.2
	assert !custom_animations_need_frame(filled)
}

fn test_style_scoped_keyframe_changes_update_and_remove_existing_tracks() {
	style_reg_reset('View { animation: fade 1s linear forwards; }')
	defer { style_reg_cleanup() }
	base := view('target', rect(0, 0, 100, 40), BoxStyle{}, [])
	initial := Element{ ...base, stylesheet: parse_stylesheet(style_reg_fade)! }
	style_animation_drive_at(apply_stylesheet(initial, global_stylesheet(), StyleMatchEnv{}), 0)
	updated := Element{ ...base, stylesheet: parse_stylesheet('@keyframes fade { from { opacity: 0; } to { opacity: 0.6; } }')! }
	styled := apply_stylesheet(updated, global_stylesheet(), StyleMatchEnv{})
	style_animation_drive_at(styled, 500)
	assert apply_widget_animations_at(styled, 500).box.opacity == 0.3
	plain := apply_stylesheet(base, global_stylesheet(), StyleMatchEnv{})
	style_animation_drive_at(plain, 600)
	assert apply_widget_animations_at(plain, 600).box.opacity == 1
	assert 'target' !in animation_runtime().style_runs
}

fn test_style_implicit_keyframe_endpoints_follow_underlying_changes() {
	style_reg_reset('@keyframes fade { to { opacity: 0; } }
		View { opacity: 0.8; animation: fade 1s linear; }
		View.active { opacity: 0.4; }')
	defer { style_reg_cleanup() }
	initial := style_reg_frame(false, 0)
	assert apply_widget_animations_at(initial, 500).box.opacity == 0.4
	updated := style_reg_frame(true, 500)
	assert apply_widget_animations_at(updated, 500).box.opacity == 0.2
}

fn test_style_repeated_names_match_existing_timelines_from_the_end() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear forwards; }
		View.active { animation: fade 2s linear forwards, fade 1s linear forwards; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(false, 0)
	updated := style_reg_frame(true, 500)
	assert apply_widget_animations_at(updated, 500).box.opacity == 0.5
	assert apply_widget_animations_at(updated, 750).box.opacity == 0.75
	// Removing a duplicate must retain the last matching clock too.
	single := style_reg_frame(false, 750)
	assert apply_widget_animations_at(single, 750).box.opacity == 0.75
}

fn test_style_transition_all_ignores_case_in_shorthand_and_longhand() {
	for transition in ['transition: ALL 1s linear;',
		'transition-property: ALL; transition-duration: 1s; transition-timing-function: linear;'] {
		style_reg_reset('View { ' + transition + ' } View.active { opacity: 0; }')
		_ = style_reg_frame(false, 0)
		updated := style_reg_frame(true, 0)
		assert apply_widget_animations_at(updated, 500).box.opacity == 0.5
	}
	style_reg_cleanup()
}

fn test_style_keyframes_apply_from_and_repeat_two_stop_animations() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear infinite; }')
	defer { style_reg_cleanup() }
	el := style_reg_frame(false, 0)
	assert apply_widget_animations_at(el, 0).box.opacity == 0
	assert apply_widget_animations_at(el, 500).box.opacity == 0.5
	assert apply_widget_animations_at(el, 1250).box.opacity == 0.25
	assert custom_animations_need_frame(el)
}

fn test_style_rule_exit_and_clear_release_only_stylesheet_runs() {
	style_reg_reset(style_reg_fade + ' View.active { animation: fade 1s linear infinite; }')
	defer { style_reg_cleanup() }
	start_widget_animation_at('target', animation(duration: 2, x: 100), 0, false)
	_ = style_reg_frame(true, 0)
	plain := style_reg_frame(false, 500)
	shown := apply_widget_animations_at(plain, 500)
	assert shown.box.opacity == 1
	assert shown.frame.x == 25
	assert 'target' !in animation_runtime().style_runs
	assert animation_info('target').status == .running
	_ = style_reg_frame(true, 600)
	clear_global_stylesheet()
	assert 'target' !in animation_runtime().style_runs
	assert animation_info('target').status == .running
}

fn test_style_comma_animations_keep_separate_timelines() {
	style_reg_reset(style_reg_fade + ' @keyframes move { from { x: 0; } to { x: 100; } } View { animation: fade 1s linear, move 2s linear; }')
	defer { style_reg_cleanup() }
	el := style_reg_frame(false, 0)
	shown := apply_widget_animations_at(el, 500)
	assert shown.box.opacity == 0.5
	assert shown.frame.x == 25
}

fn test_style_pause_resume_preserves_elapsed_time() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear; } View.active { animation-play-state: paused; }')
	defer { style_reg_cleanup() }
	running := style_reg_frame(false, 0)
	assert apply_widget_animations_at(running, 250).box.opacity == 0.25
	paused := style_reg_frame(true, 250)
	assert apply_widget_animations_at(paused, 750).box.opacity == 0.25
	assert !custom_animations_need_frame(paused)
	resumed := style_reg_frame(false, 1000)
	assert apply_widget_animations_at(resumed, 1250).box.opacity == 0.5
}

fn test_style_initially_paused_animation_starts_when_resumed() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear; } View.active { animation-play-state: paused; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(true, 0)
	resumed := style_reg_frame(false, 500)
	assert apply_widget_animations_at(resumed, 1000).box.opacity == 0.5
}

fn test_style_finite_fractional_and_large_counts_stay_finite() {
	for count in ['0.5', '2.5', '257'] {
		style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear ' + count + ' forwards; }')
		el := style_reg_frame(false, 0)
		duration := count.f64() * 1000
		shown := apply_widget_animations_at(el, i64(duration))
		expected := if count == '257' { 1.0 } else { 0.5 }
		assert shown.box.opacity == expected
		assert !custom_animations_need_frame(el)
		assert animation_runtime().style_runs['target'].animations.len == 1
	}
	style_reg_cleanup()
}

fn test_style_zero_iteration_count_starts_no_animation() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear 0; }')
	defer { style_reg_cleanup() }
	el := style_reg_frame(false, 0)
	assert apply_widget_animations_at(el, 500).box.opacity == 1
	assert !custom_animations_need_frame(el)
}

fn test_style_fill_modes_apply_during_delay_and_at_completion() {
	for mode in ['none', 'forwards', 'backwards', 'both'] {
		style_reg_reset('@keyframes fade { from { opacity: 0; } to { opacity: 0.5; } } View { animation: fade 1s linear 1s ' + mode + '; }')
		el := style_reg_frame(false, 0)
		before := apply_widget_animations_at(el, 500)
		assert before.box.opacity == if mode in ['backwards', 'both'] { 0.0 } else { 1.0 }
		finished := apply_widget_animations_at(el, 2000)
		assert finished.box.opacity == if mode in ['forwards', 'both'] { 0.5 } else { 1.0 }
		assert !custom_animations_need_frame(el)
	}
	style_reg_cleanup()
}

fn test_style_negative_delay_and_directions() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear -0.25s infinite alternate; }')
	defer { style_reg_cleanup() }
	el := style_reg_frame(false, 0)
	assert apply_widget_animations_at(el, 0).box.opacity == 0.25
	assert apply_widget_animations_at(el, 1000).box.opacity == 0.75
}

fn test_style_transitions_redirect_from_the_displayed_value() {
	style_reg_reset('View { transition: opacity 1s linear; } View.active { opacity: 0; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(false, 0)
	active := style_reg_frame(true, 100)
	assert apply_widget_animations_at(active, 600).box.opacity == 0.5
	plain := style_reg_frame(false, 600)
	assert apply_widget_animations_at(plain, 600).box.opacity == 0.5
	assert apply_widget_animations_at(plain, 1100).box.opacity == 0.75
	assert apply_widget_animations_at(plain, 1600).box.opacity == 1
	assert !custom_animations_need_frame(plain)
}

fn test_style_transition_delay_keeps_scheduler_alive() {
	style_reg_reset('View { transition: opacity 0.2s linear 1s; } View.active { opacity: 0; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(false, 0)
	el := style_reg_frame(true, 0)
	assert animations_need_frames(500)
	assert apply_widget_animations_at(el, 500).box.opacity == 1
	assert math.abs(apply_widget_animations_at(el, 1100).box.opacity - 0.5) < 0.000001
}

fn test_style_transition_none_and_shorthand_time_tokens() {
	assert parse_transition_shorthand('none').len == 0
	for name in ['progress', 'changes'] {
		parsed := parse_animation_shorthand('${name} 1s forwards')
		assert parsed[0].name == name
		assert parsed[0].fill_mode == 'forwards'
		assert parsed[0].duration == 1
	}
	assert parse_time_seconds('forwards') == none
	assert parse_time_seconds('banana1s') == none
	assert parse_time_seconds('1junkms') == none
	if _ := parse_cubic_bezier('cubic-bezier(2, 0, 1, 1)') {
		assert false, 'out-of-range bezier accepted'
	}
}

fn test_style_longhand_lists_cycle_in_either_declaration_order() {
	for body in [
		'transition-property: background, opacity; transition-duration: 1s;',
		'transition-duration: 1s; transition-property: background, opacity;',
	] {
		el := apply_stylesheet(view('target', rect(0, 0, 100, 40), BoxStyle{}, []), parse_stylesheet('View { ${body} }')!, StyleMatchEnv{})
		assert el.style_transitions.len == 2
		assert el.style_transitions.all(it.duration == 1)
	}
	for body in [
		'animation-name: fade, move; animation-duration: 1s;',
		'animation-duration: 1s; animation-name: fade, move;',
	] {
		el := apply_stylesheet(view('target', rect(0, 0, 100, 40), BoxStyle{}, []), parse_stylesheet('View { ${body} }')!, StyleMatchEnv{})
		assert el.style_animations.len == 2
		assert el.style_animations.all(it.duration == 1)
	}
}

fn test_style_numeric_keyframes_resolve_variables_units_and_border_sides() {
	sheet := parse_stylesheet('@alpha: 50%; @edge: 4px; @keyframes fade { from { opacity: 0; } to { opacity: @alpha; border-width: @edge; } }')!
	targets := keyframe_targets([sheet], sheet.keyframes['fade']!.stops[1])
	assert targets.filter(it.name == 'box.opacity')[0].number == 0.5
	assert targets.filter(it.name.starts_with('box.border_')).len == 4
	assert targets.filter(it.name.starts_with('box.border_')).all(it.number == 4)
	for invalid in ['banana%', '50junk%', '%', '-1%', '101%'] {
		assert keyframe_stop_progress(invalid) == none
	}
}

fn test_style_keyframe_only_scope_remains_visible() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	definitions := parse_stylesheet(style_reg_fade)!
	assert !stylesheet_is_empty(definitions)
	child := Element{ ...view('target', rect(0, 0, 100, 40), BoxStyle{}, []), stylesheet: parse_stylesheet('View { animation: fade 1s linear; }')! }
	root := Element{ ...view('root', rect(0, 0, 100, 40), BoxStyle{}, [child]), stylesheet: definitions }
	styled := apply_stylesheet(root, Stylesheet{}, StyleMatchEnv{})
	style_animation_drive_at(styled, 0)
	assert apply_widget_animations_at(styled, 500).children[0].box.opacity == 0.5
}

fn test_style_inline_animation_declarations_keep_precedence() {
	el := Element{ ...view('target', rect(0, 0, 100, 40), BoxStyle{}, []), style_transitions: [StyleTransition{ properties: ['box.opacity'], duration: 2 }] }
	styled := apply_stylesheet(el, parse_stylesheet('View { transition: opacity 1s; }')!, StyleMatchEnv{})
	assert styled.style_transitions[0].duration == 2
	vml := element_from_vml('View { style: "transition: opacity 2s; animation: fade 3s forwards;" }', rect(0, 0, 100, 40))!
	assert vml.style_transitions[0].duration == 2
	assert vml.style_animations[0].duration == 3
	assert vml.style_animations[0].fill_mode == 'forwards'
}

fn test_style_keyframe_import_order_matches_source_order() ! {
	dir := os.join_path(os.temp_dir(), 'ui2-keyframe-import-${time.sys_mono_now()}')
	os.mkdir_all(dir)!
	defer { os.rmdir_all(dir) or {} }
	os.write_file(os.join_path(dir, 'imported.vss'), '@keyframes fade { to { opacity: 0.3; } }')!
	path := os.join_path(dir, 'main.vss')
	os.write_file(path, '@keyframes fade { to { opacity: 0.1; } } @import "imported.vss";')!
	first := load_stylesheet(path)!
	assert first.keyframes['fade']!.stops[0].declarations[0].value == '0.3'
	os.write_file(path, '@import "imported.vss"; @keyframes fade { to { opacity: 0.6; } }')!
	second := load_stylesheet(path)!
	assert second.keyframes['fade']!.stops[0].declarations[0].value == '0.6'
}

fn test_animation_fill_none_saves_live_state_and_reverts_at_completion() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	el := view('target', rect(0, 0, 100, 40), BoxStyle{}, [])
	start_widget_animation_at('target', animation(duration: 1, fill_mode: 'none', x: 100), 0, false)
	assert apply_widget_animations_at(el, 500).frame.x == 50
	assert animation_runtime().runs['target'].initialized
	assert animation_runtime().runs['target'].last.frame.x == 50
	assert apply_widget_animations_at(el, 1000).frame.x == 0
	assert animation_info('target').status == .idle
}

fn test_animation_delay_is_included_in_native_frame_deadline() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	start_widget_animation_at('target', animation(duration: 0.2, delay: 1, x: 100), 0, false)
	assert animations_need_frames(500)
}

fn test_style_removing_one_comma_animation_preserves_the_other_clock() {
	style_reg_reset(style_reg_fade + ' @keyframes move { from { x: 0; } to { x: 100; } } View { animation: fade 1s linear, move 2s linear; } View.active { animation: move 2s linear; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(false, 0)
	el := style_reg_frame(true, 500)
	assert apply_widget_animations_at(el, 500).frame.x == 25
	assert apply_widget_animations_at(el, 1000).frame.x == 50
	assert apply_widget_animations_at(el, 1000).box.opacity == 1
}

fn test_style_removing_all_scopes_clears_their_animation_contribution() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	el := Element{ ...view('target', rect(0, 0, 100, 40), BoxStyle{}, []), stylesheet: parse_stylesheet(style_reg_fade + ' View { animation: fade 1s infinite; }')! }
	_ = stylesheet_apply_frame(el, StyleMatchEnv{})
	assert 'target' in animation_runtime().style_runs
	plain := stylesheet_apply_frame(view('target', rect(0, 0, 100, 40), BoxStyle{}, []), StyleMatchEnv{})
	assert 'target' !in animation_runtime().style_runs
	assert apply_widget_animations_at(plain, animation_now_ms()).box.opacity == 1
}

fn test_style_inline_only_transition_reaches_the_frame_driver() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	before := element_from_vml('View { id: target style: "transition: opacity 1s linear;" }', rect(0, 0, 100, 40))!
	_ = stylesheet_apply_frame(before, StyleMatchEnv{})
	after := Element{ ...before, box: BoxStyle{ opacity: 0 } }
	_ = stylesheet_apply_frame(after, StyleMatchEnv{})
	assert 'box.opacity' in animation_runtime().style_runs['target'].transitions
}

fn test_style_keyframes_resolve_inherited_custom_properties() {
	style_reg_reset('@keyframes fade { from { opacity: 0; } to { opacity: var(--alpha); } } #parent { --alpha: 50%; } #target { animation: fade 1s linear; }')
	defer { style_reg_cleanup() }
	root := view('parent', rect(0, 0, 100, 40), BoxStyle{}, [view('target', rect(0, 0, 100, 40), BoxStyle{}, [])])
	styled := apply_stylesheet(root, global_stylesheet(), StyleMatchEnv{})
	style_animation_drive_at(styled, 0)
	assert apply_widget_animations_at(styled, 500).children[0].box.opacity == 0.25
}

fn test_animation_compounds_include_child_delays() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	el := view('target', rect(0, 0, 100, 40), BoxStyle{}, [])
	first := animation(duration: 1, delay: 0.5, x: 100)
	second := animation(duration: 1, delay: 0.5, y: 100)
	serial := sequence(first, second)
	assert serial.duration == 3
	start_widget_animation_at('target', serial, 0, false)
	assert apply_widget_animations_at(el, 1000).frame.x == 50
	assert apply_widget_animations_at(el, 1750).frame.y == 0
	assert apply_widget_animations_at(el, 2500).frame.y == 50
	reset_widget_animations()
	concurrent := parallel(first, second)
	assert concurrent.duration == 1.5
	start_widget_animation_at('target', concurrent, 0, false)
	shown := apply_widget_animations_at(el, 1000)
	assert shown.frame.x == 50 && shown.frame.y == 50
}

fn test_style_changing_active_duration_to_zero_releases_the_run() {
	style_reg_reset(style_reg_fade + ' View { animation: fade 1s linear infinite; } View.active { animation-duration: 0s; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(false, 0)
	el := style_reg_frame(true, 250)
	assert apply_widget_animations_at(el, 500).box.opacity == 1
	assert !custom_animations_need_frame(el)
}

__global style_reg_events = []AnimationEventKind{}

fn style_reg_event(event AnimationEvent) {
	style_reg_events << event.kind
}

fn test_animation_nonretaining_callbacks_fire_once_per_lifecycle() {
	style_reg_cleanup()
	defer { style_reg_cleanup() }
	style_reg_events = []AnimationEventKind{}
	el := view('target', rect(0, 0, 100, 40), BoxStyle{}, [])
	start_widget_animation_at('target', animation(
		duration:  1
		fill_mode: 'none'
		x:         100
		on_event:  style_reg_event
	), 0, false)
	for now in [i64(0), 250, 500, 1000, 1250] {
		_ = apply_widget_animations_at(el, now)
	}
	assert style_reg_events.filter(it == .start).len == 1
	assert style_reg_events.filter(it == .complete).len == 1
}

fn test_animation_reset_releases_style_history() {
	style_reg_reset('View { transition: opacity 1s; } View.active { opacity: 0; }')
	defer { style_reg_cleanup() }
	_ = style_reg_frame(true, 0)
	reset_widget_animations()
	plain := style_reg_frame(false, 500)
	assert apply_widget_animations_at(plain, 500).box.opacity == 1
	assert !custom_animations_need_frame(plain)
}
