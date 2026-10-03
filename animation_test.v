@[has_globals]
module ui2

import math

__global g_animation_test_events = []AnimationEvent{}

fn animation_test_event_handler(event AnimationEvent) {
	g_animation_test_events << event
}

fn animation_test_element() Element {
	return view('tile', rect(10, 20, 100, 40), BoxStyle{
		bg: 0x000000
		radius: 4
	}, [])
}

fn animation_test_root(element Element) Element {
	return screen(0xffffff, [element])
}

fn animation_test_find(element Element, id string) Element {
	if element.id == id {
		return element
	}
	for child in element.children {
		found := animation_test_find(child, id)
		if found.id == id {
			return found
		}
	}
	return Element{}
}

fn test_animation_interpolates_multiple_widget_properties() {
	reset_widget_animations()
	definition := animation(AnimationConfig{
		duration: 1
		transition: .linear
		x: 110
		y: 120
		width: 200
		rotation: 90
		background: u32(0xffffff)
		corner_radius: 12
	})
	start_widget_animation_at('tile', definition, 1_000, false)

	half := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500), 'tile')
	assert half.frame.x == 60
	assert half.frame.y == 70
	assert half.frame.width == 150
	assert half.rotation == 45
	assert half.box.bg == 0x808080
	assert half.box.radius == 8

	end := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 2_000), 'tile')
	assert end.frame.x == 110
	assert end.frame.y == 120
	assert end.frame.width == 200
	assert end.box.bg == 0xffffff
	assert animation_info('tile').status == .completed
}

fn test_animation_sequence_and_parallel_composition() {
	reset_widget_animations()
	move_x := animation(AnimationConfig{
		duration: 1
		x: 110
	})
	move_y := animation(AnimationConfig{
		duration: 2
		y: 100
	})
	sequence_definition := move_x + move_y
	assert sequence_definition.duration == 3
	assert sequence_definition.animated_properties() == ['x', 'y']
	start_widget_animation_at('tile', sequence_definition, 1_000, false)
	sequenced := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 2_500), 'tile')
	assert sequenced.frame.x == 110
	assert sequenced.frame.y == 40

	reset_widget_animations()
	parallel_definition := parallel(move_x, move_y)
	assert parallel_definition.duration == 2
	start_widget_animation_at('tile', parallel_definition, 1_000, false)
	concurrent := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 2_000), 'tile')
	assert concurrent.frame.x == 110
	assert concurrent.frame.y == 60
}

fn test_animation_easing_step_and_custom_transition() {
	reset_widget_animations()
	stepped := animation(AnimationConfig{
		duration: 1
		step: 0.25
		x: 110
	})
	start_widget_animation_at('tile', stepped, 1_000, false)
	result := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_370), 'tile')
	assert result.frame.x == 35

	reset_widget_animations()
	custom := animation(AnimationConfig{
		duration: 1
		transition_fn: fn (progress f64) f64 {
			return progress * progress
		}
		x: 110
	})
	start_widget_animation_at('tile', custom, 1_000, false)
	eased := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500), 'tile')
	assert eased.frame.x == 35
}

fn test_animation_generic_properties_cover_widget_and_style_values() {
	reset_widget_animations()
	definition := animation(AnimationConfig{
		duration: 1
		properties: [
			animation_number_property('value', 80),
			animation_number_property('box.border_left', 10),
			animation_number_property('slider_style.thumb_size', 32),
			animation_color_property('slider_style.thumb_color', 0xff0000),
			animation_color_property('switch_style.active_track_color', 0x0000ff),
		]
	})
	assert definition.animated_properties() == ['value', 'box.border_left', 'slider_style.thumb_size',
		'slider_style.thumb_color', 'switch_style.active_track_color']
	start_widget_animation_at('tile', definition, 1_000, false)
	half := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500), 'tile')
	assert half.value == 40
	assert half.box.border_left == 5
	assert half.slider_style.thumb_size == 26
	assert half.slider_style.thumb_color == 0x923276
	assert half.switch_style.active_track_color == 0x1163af
}

fn test_animation_generic_properties_normalize_names_and_ignore_invalid_targets() {
	reset_widget_animations()
	assert is_animatable_property('frame.x', .number)
	assert is_animatable_property('box.bg', .color)
	assert !is_animatable_property('text', .number)
	assert !is_animatable_property('value', .color)
	definition := animation(AnimationConfig{
		duration: 1
		x: 110
		properties: [
			animation_number_property('frame.x', 210),
			animation_color_property('value', 0xffffff),
			animation_number_property('text', 5),
		]
	})
	assert definition.animated_properties() == ['x']
	start_widget_animation_at('tile', definition, 1_000, false)
	half := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500), 'tile')
	assert half.frame.x == 110
	cancel_animation_property('tile', 'frame.x')
	assert animation_info('tile').status == .cancelled
}

fn test_repeating_sequence_restarts_from_previous_end() {
	reset_widget_animations()
	forward := animation(AnimationConfig{
		duration: 0.1
		x: 110
	})
	back := animation(AnimationConfig{
		duration: 0.1
		x: 10
	})
	definition := (forward + back).repeating()
	start_widget_animation_at('tile', definition, 1_000, false)
	second_cycle := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 1_250), 'tile')
	assert math.close(second_cycle.frame.x, 60)
	assert animation_info('tile').status == .running
}

fn test_redirect_cancel_property_and_clear_preserve_declarative_values() {
	reset_widget_animations()
	first := animation(AnimationConfig{
		duration: 1
		x: 110
		y: 120
	})
	start_widget_animation_at('tile', first, 1_000, false)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500)

	redirect := animation(AnimationConfig{
		duration: 1
		x: 210
	})
	start_widget_animation_at('tile', redirect, 1_500, false)
	redirected := animation_test_find(apply_widget_animations_at(animation_test_root(animation_test_element()), 2_000), 'tile')
	assert redirected.frame.x == 135
	// The y reached by the previous animation remains on the retained widget.
	assert redirected.frame.y == 70

	cancel_animation_property('tile', 'x')
	declared := Element{
		...animation_test_element()
		frame: rect(10, 20, 250, 40)
	}
	frozen := animation_test_find(apply_widget_animations_at(animation_test_root(declared), 2_500), 'tile')
	assert frozen.frame.x == 135
	assert frozen.frame.width == 250

	clear_animation('tile')
	cleared := animation_test_find(apply_widget_animations_at(animation_test_root(declared), 2_500), 'tile')
	assert cleared.frame.x == 10
	assert cleared.frame.y == 20
}

fn test_animation_events_and_stop_cancel_semantics() {
	reset_widget_animations()
	g_animation_test_events = []AnimationEvent{}
	definition := animation(AnimationConfig{
		duration: 1
		x: 110
		on_event: animation_test_event_handler
	})
	start_widget_animation_at('tile', definition, 1_000, false)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 1_000)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 2_000)
	assert g_animation_test_events.map(it.kind) == [.start, .progress, .progress, .complete]
	assert g_animation_test_events.last().progress == 1

	reset_widget_animations()
	g_animation_test_events = []AnimationEvent{}
	start_widget_animation_at('tile', definition, 1_000, false)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500)
	cancel_animation('tile')
	assert animation_info('tile').status == .cancelled
	assert g_animation_test_events.map(it.kind) == [.start, .progress]

	reset_widget_animations()
	g_animation_test_events = []AnimationEvent{}
	start_widget_animation_at('tile', definition, 1_000, false)
	apply_widget_animations_at(animation_test_root(animation_test_element()), 1_500)
	stop_animation('tile')
	assert animation_info('tile').status == .stopped
	assert g_animation_test_events.last().kind == .complete
}
