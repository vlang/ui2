@[has_globals]
module ui2

import math
import math.easing
import sync
import time

// AnimationTransition names the easing curves supported by Kivy's
// AnimationTransition API. A custom curve can be supplied with transition_fn.
pub enum AnimationTransition {
	linear
	in_sine
	out_sine
	in_out_sine
	in_quad
	out_quad
	in_out_quad
	in_cubic
	out_cubic
	in_out_cubic
	in_quart
	out_quart
	in_out_quart
	in_quint
	out_quint
	in_out_quint
	in_expo
	out_expo
	in_out_expo
	in_circ
	out_circ
	in_out_circ
	in_back
	out_back
	in_out_back
	in_elastic
	out_elastic
	in_out_elastic
	in_bounce
	out_bounce
	in_out_bounce
}

pub type AnimationTransitionFn = fn (f64) f64

// AnimationPropertyKind identifies the value representation used by a generic
// animation property. Numeric values interpolate linearly; colors interpolate
// each RGB channel.
pub enum AnimationPropertyKind {
	number
	color
}

// AnimationProperty targets an interpolatable Element property by name. Use
// animation_number_property or animation_color_property to construct one.
//
// This is the extensible counterpart to AnimationConfig's legacy named fields:
// it covers every numeric and color property exposed by Element and its styles.
pub struct AnimationProperty {
pub:
	name   string
	kind   AnimationPropertyKind
	number f64
	color  u32
}

// animation_number_property creates a target for a numeric Element property.
// Both concise names (for example, "value") and dotted Element paths (for
// example, "slider_style.thumb_size") are accepted.
pub fn animation_number_property(name string, target f64) AnimationProperty {
	return AnimationProperty{
		name: name
		kind: .number
		number: target
	}
}

// animation_color_property creates a target for a color Element property.
pub fn animation_color_property(name string, target u32) AnimationProperty {
	return AnimationProperty{
		name: name
		kind: .color
		color: target
	}
}

pub enum AnimationEventKind {
	start
	progress
	complete
}

pub struct AnimationEvent {
pub:
	kind     AnimationEventKind
	id       string
	progress f64
}

pub type AnimationEventFn = fn (AnimationEvent)

type AnimationRefreshFn = fn ()

// AnimationConfig describes the final values of interpolatable Element
// properties. Duration and step are seconds, matching Kivy. A zero step updates
// on every frame.
pub struct AnimationConfig {
pub:
	duration        f64 = 1.0
	transition      AnimationTransition = .linear
	transition_fn   AnimationTransitionFn = unsafe { nil }
	step            f64
	repeat          bool
	on_event        AnimationEventFn = unsafe { nil }
	x               ?f64
	y               ?f64
	width           ?f64
	height          ?f64
	rotation        ?f64
	background      ?u32
	corner_radius   ?f64
	text_color      ?u32
	text_background ?u32
	font_size       ?f64
	padding_left    ?f64
	// properties accepts arbitrary supported numeric and color Element paths.
	// Generic targets take precedence over a duplicate legacy named field.
	properties []AnimationProperty
}

struct AnimationTargets {
	x               ?f64
	y               ?f64
	width           ?f64
	height          ?f64
	rotation        ?f64
	background      ?u32
	corner_radius   ?f64
	text_color      ?u32
	text_background ?u32
	font_size       ?f64
	padding_left    ?f64
	properties      []AnimationProperty
}

enum AnimationKind {
	tween
	sequence
	parallel
}

// Animation is an immutable animation definition. Set repeat directly on a
// mutable value, or use repeating() when composing expressions.
pub struct Animation {
pub:
	duration   f64
	transition AnimationTransition
	step       f64
pub mut:
	repeat bool
mut:
	kind          AnimationKind
	targets       AnimationTargets
	children      []Animation
	properties    []string
	transition_fn AnimationTransitionFn = unsafe { nil }
	on_event      AnimationEventFn = unsafe { nil }
}

pub enum AnimationStatus {
	idle
	running
	completed
	stopped
	cancelled
}

pub struct AnimationInfo {
pub:
	status              AnimationStatus
	progress            f64
	duration            f64
	repeat              bool
	animated_properties []string
}

struct AnimationRun {
	definition Animation
	started_at i64
	retained   []string
mut:
	initialized bool
	start       Element
	last        Element
	status      AnimationStatus = .running
	progress    f64
	suppressed  map[string]bool
}

struct PendingAnimationEvent {
	callback AnimationEventFn = unsafe { nil }
	event    AnimationEvent
}

@[heap]
struct AnimationRuntime {
	mutex &sync.Mutex = sync.new_mutex()
mut:
	runs             map[string]AnimationRun
	refresh_callback AnimationRefreshFn = unsafe { nil }
	drive_frames     bool
	driver_running   bool
}

__global g_animation_runtime = &AnimationRuntime{
	runs: map[string]AnimationRun{}
}

// animation creates a reusable definition for one or more Element properties.
pub fn animation(config AnimationConfig) Animation {
	properties := animation_config_properties(config)
	duration := math.max(0.0, config.duration)
	step := math.max(0.0, config.step)
	return Animation{
		kind: .tween
		duration: duration
		transition: config.transition
		transition_fn: config.transition_fn
		step: step
		repeat: config.repeat
		on_event: config.on_event
		properties: properties
		targets: AnimationTargets{
			x: config.x
			y: config.y
			width: config.width
			height: config.height
			rotation: config.rotation
			background: config.background
			corner_radius: config.corner_radius
			text_color: config.text_color
			text_background: config.text_background
			font_size: config.font_size
			padding_left: config.padding_left
			properties: normalized_animation_properties(config.properties)
		}
	}
}

// + composes two animations sequentially.
pub fn (left Animation) +(right Animation) Animation {
	return sequence(left, right)
}

// sequence runs each definition after the preceding definition completes.
pub fn sequence(animations ...Animation) Animation {
	mut duration := 0.0
	mut properties := []string{}
	for child in animations {
		duration += child.duration
		properties = merge_property_names(properties, child.properties)
	}
	return Animation{
		kind: .sequence
		duration: duration
		transition: .linear
		children: animations
		properties: properties
	}
}

// parallel runs all definitions at once and completes with the longest one.
pub fn parallel(animations ...Animation) Animation {
	mut duration := 0.0
	mut properties := []string{}
	for child in animations {
		if child.duration > duration {
			duration = child.duration
		}
		properties = merge_property_names(properties, child.properties)
	}
	return Animation{
		kind: .parallel
		duration: duration
		transition: .linear
		children: animations
		properties: properties
	}
}

// parallel_with is the method form of parallel().
pub fn (left Animation) parallel_with(right Animation) Animation {
	return parallel(left, right)
}

// repeating returns a copy that restarts until it is stopped or cancelled.
pub fn (definition Animation) repeating() Animation {
	return Animation{
		...definition
		repeat: true
	}
}

// with_event_handler returns a copy that reports start, progress and complete
// events. Apply it after sequence/parallel composition to observe the compound.
pub fn (definition Animation) with_event_handler(handler AnimationEventFn) Animation {
	return Animation{
		...definition
		on_event: handler
	}
}

// animated_properties returns the unique Element property names changed by the
// definition.
pub fn (definition Animation) animated_properties() []string {
	return definition.properties.clone()
}

// start begins this animation on the mounted Element with id. If that element
// is already animated, the new definition starts at its currently displayed
// values.
pub fn (definition Animation) start(id string) {
	start_widget_animation_at(id, definition, time.ticks(), true)
}

pub fn (definition Animation) cancel(id string) {
	cancel_animation(id)
}

pub fn (definition Animation) stop(id string) {
	stop_animation(id)
}

pub fn (definition Animation) cancel_property(id string, property string) {
	cancel_animation_property(id, property)
}

pub fn (definition Animation) stop_property(id string, property string) {
	stop_animation_property(id, property)
}

pub fn (definition Animation) have_properties_to_animate(id string) bool {
	return has_animated_properties(id)
}

// animation_info returns the state of the current or most recently retained
// animation for id.
pub fn animation_info(id string) AnimationInfo {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	animation_run := runtime.runs[id] or {
		runtime.mutex.unlock()
		return AnimationInfo{}
	}
	info := AnimationInfo{
		status: animation_run.status
		progress: animation_run.progress
		duration: animation_run.definition.duration
		repeat: animation_run.definition.repeat
		animated_properties: active_animation_properties(animation_run)
	}
	runtime.mutex.unlock()
	return info
}

pub fn has_animated_properties(id string) bool {
	info := animation_info(id)
	return info.status == .running && info.animated_properties.len > 0
}

// cancel_animation freezes the widget at its current values without emitting a
// complete event.
pub fn cancel_animation(id string) {
	finish_animation(id, '', false)
}

// stop_animation freezes the widget at its current values and emits complete.
pub fn stop_animation(id string) {
	finish_animation(id, '', true)
}

// cancel_animation_property freezes one property without emitting complete.
// If it was the last active property, the whole animation is cancelled.
pub fn cancel_animation_property(id string, property string) {
	finish_animation(id, property, false)
}

// stop_animation_property freezes one property. If it was the last active
// property, the whole animation is stopped and emits complete.
pub fn stop_animation_property(id string, property string) {
	finish_animation(id, property, true)
}

// cancel_all_animations accepts an empty id to target every animated widget.
// Optional property names limit what is cancelled.
pub fn cancel_all_animations(id string, properties ...string) {
	finish_all_animations(id, properties, false)
}

// stop_all_animations is the completing counterpart to cancel_all_animations.
pub fn stop_all_animations(id string, properties ...string) {
	finish_all_animations(id, properties, true)
}

// clear_animation releases retained animated values so the next build uses the
// widget's declaration unchanged.
pub fn clear_animation(id string) {
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	runtime.runs.delete(id)
	runtime.mutex.unlock()
	request_animation_refresh()
}

fn animation_config_properties(config AnimationConfig) []string {
	mut properties := []string{}
	if _ := config.x { properties << 'x' }
	if _ := config.y { properties << 'y' }
	if _ := config.width { properties << 'width' }
	if _ := config.height { properties << 'height' }
	if _ := config.rotation { properties << 'rotation' }
	if _ := config.background { properties << 'background' }
	if _ := config.corner_radius { properties << 'corner_radius' }
	if _ := config.text_color { properties << 'text_color' }
	if _ := config.text_background { properties << 'text_background' }
	if _ := config.font_size { properties << 'font_size' }
	if _ := config.padding_left { properties << 'padding_left' }
	for property in normalized_animation_properties(config.properties) {
		if property.name !in properties {
			properties << property.name
		}
	}
	return properties
}

fn normalized_animation_properties(properties []AnimationProperty) []AnimationProperty {
	mut normalized := []AnimationProperty{}
	for property in properties {
		name := canonical_animation_property_name(property.name)
		if name.len == 0 || !animation_property_kind_matches(name, property.kind) {
			continue
		}
		normalized_property := AnimationProperty{
			...property
			name: name
		}
		mut replaced := false
		for index, current in normalized {
			if current.name == name {
				normalized[index] = normalized_property
				replaced = true
				break
			}
		}
		if !replaced {
			normalized << normalized_property
		}
	}
	return normalized
}

// is_animatable_property reports whether name denotes a numeric or color
// property currently supported by the generic animation API.
pub fn is_animatable_property(name string, kind AnimationPropertyKind) bool {
	canonical := canonical_animation_property_name(name)
	return canonical.len > 0 && animation_property_kind_matches(canonical, kind)
}

fn canonical_animation_property_name(name string) string {
	return match name {
		'x', 'frame.x' { 'x' }
		'y', 'frame.y' { 'y' }
		'width', 'frame.width' { 'width' }
		'height', 'frame.height' { 'height' }
		'rotation' { 'rotation' }
		'background', 'box.bg' { 'background' }
		'corner_radius', 'box.radius' { 'corner_radius' }
		'box.border_color' { 'box.border_color' }
		'box.border_left' { 'box.border_left' }
		'box.border_top' { 'box.border_top' }
		'box.border_right' { 'box.border_right' }
		'box.border_bottom' { 'box.border_bottom' }
		'text_color', 'text_style.color' { 'text_color' }
		'text_background', 'text_style.background_color' { 'text_background' }
		'font_size', 'text_style.size' { 'font_size' }
		'text_style.head_indent' { 'text_style.head_indent' }
		'text_style.first_line_indent' { 'text_style.first_line_indent' }
		'text_style.hyphenation_factor' { 'text_style.hyphenation_factor' }
		'text_style.lines' { 'text_style.lines' }
		'padding_left' { 'padding_left' }
		'keyboard' { 'keyboard' }
		'value' { 'value' }
		'min_value' { 'min_value' }
		'max_value' { 'max_value' }
		'step' { 'step' }
		'padding' { 'padding' }
		'slider_style.track_color' { 'slider_style.track_color' }
		'slider_style.value_track_color' { 'slider_style.value_track_color' }
		'slider_style.thumb_color' { 'slider_style.thumb_color' }
		'slider_style.track_width' { 'slider_style.track_width' }
		'slider_style.thumb_size' { 'slider_style.thumb_size' }
		'switch_style.inactive_track_color' { 'switch_style.inactive_track_color' }
		'switch_style.active_track_color' { 'switch_style.active_track_color' }
		'switch_style.thumb_color' { 'switch_style.thumb_color' }
		'switch_style.disabled_track_color' { 'switch_style.disabled_track_color' }
		'switch_style.disabled_thumb_color' { 'switch_style.disabled_thumb_color' }
		'toggle_down_box.bg' { 'toggle_down_box.bg' }
		'toggle_down_box.radius' { 'toggle_down_box.radius' }
		'toggle_down_box.border_color' { 'toggle_down_box.border_color' }
		'toggle_down_box.border_left' { 'toggle_down_box.border_left' }
		'toggle_down_box.border_top' { 'toggle_down_box.border_top' }
		'toggle_down_box.border_right' { 'toggle_down_box.border_right' }
		'toggle_down_box.border_bottom' { 'toggle_down_box.border_bottom' }
		'toggle_down_text_style.color' { 'toggle_down_text_style.color' }
		'toggle_down_text_style.background_color' { 'toggle_down_text_style.background_color' }
		'toggle_down_text_style.size' { 'toggle_down_text_style.size' }
		'toggle_down_text_style.head_indent' { 'toggle_down_text_style.head_indent' }
		'toggle_down_text_style.first_line_indent' { 'toggle_down_text_style.first_line_indent' }
		'toggle_down_text_style.hyphenation_factor' { 'toggle_down_text_style.hyphenation_factor' }
		'toggle_down_text_style.lines' { 'toggle_down_text_style.lines' }
		else { '' }
	}
}

fn animation_property_kind_matches(name string, kind AnimationPropertyKind) bool {
	return match name {
		'background', 'box.border_color', 'text_color', 'text_background', 'slider_style.track_color', 'slider_style.value_track_color', 'slider_style.thumb_color', 'switch_style.inactive_track_color', 'switch_style.active_track_color', 'switch_style.thumb_color', 'switch_style.disabled_track_color', 'switch_style.disabled_thumb_color', 'toggle_down_box.bg', 'toggle_down_box.border_color', 'toggle_down_text_style.color', 'toggle_down_text_style.background_color' {
			kind == .color
		}
		else { kind == .number }
	}
}

fn merge_property_names(left []string, right []string) []string {
	mut merged := left.clone()
	for property in right {
		if property !in merged {
			merged << property
		}
	}
	return merged
}

fn active_animation_properties(animation_run AnimationRun) []string {
	mut active := []string{}
	for property in animation_run.definition.properties {
		if !(animation_run.suppressed[property] or { false }) {
			active << property
		}
	}
	return active
}

fn start_widget_animation_at(id string, definition Animation, now i64, schedule bool) {
	if id.len == 0 {
		return
	}
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	previous := runtime.runs[id] or { AnimationRun{} }
	mut retained := definition.properties.clone()
	mut initialized := false
	mut start := Element{}
	if previous.initialized {
		initialized = true
		start = previous.last
		retained = merge_property_names(previous.retained, retained)
	}
	runtime.runs[id] = AnimationRun{
		definition: definition
		started_at: now
		retained: retained
		initialized: initialized
		start: start
		last: start
		status: .running
		suppressed: map[string]bool{}
	}
	runtime.mutex.unlock()
	if schedule {
		schedule_animation_frames()
	}
}

fn finish_animation(id string, property string, completing bool) {
	mut runtime := g_animation_runtime
	mut pending := []PendingAnimationEvent{}
	target_property := if property.len > 0 {
		canonical := canonical_animation_property_name(property)
		if canonical.len > 0 { canonical } else { property }
	} else {
		''
	}
	runtime.mutex.lock()
	mut animation_run := runtime.runs[id] or {
		runtime.mutex.unlock()
		return
	}
	if target_property.len > 0 {
		if target_property !in animation_run.definition.properties {
			runtime.mutex.unlock()
			return
		}
		animation_run.suppressed[target_property] = true
		if active_animation_properties(animation_run).len > 0 {
			runtime.runs[id] = animation_run
			runtime.mutex.unlock()
			return
		}
	}
	if animation_run.status == .running {
		animation_run.status = if completing { .stopped } else { .cancelled }
		if completing && voidptr(animation_run.definition.on_event) != unsafe { nil } {
			pending << PendingAnimationEvent{
				callback: animation_run.definition.on_event
				event: AnimationEvent{
					kind: .complete
					id: id
					progress: animation_run.progress
				}
			}
		}
		runtime.runs[id] = animation_run
	}
	runtime.mutex.unlock()
	dispatch_animation_events(pending)
	request_animation_refresh()
}

fn finish_all_animations(id string, properties []string, completing bool) {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	ids := if id.len > 0 { [id] } else { runtime.runs.keys() }
	runtime.mutex.unlock()
	for target in ids {
		if properties.len == 0 {
			finish_animation(target, '', completing)
		} else {
			for property in properties {
				finish_animation(target, property, completing)
			}
		}
	}
}

fn schedule_animation_frames() {
	request_animation_refresh()
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	start_driver := runtime.drive_frames && !runtime.driver_running
	if start_driver {
		runtime.driver_running = true
	}
	runtime.mutex.unlock()
	if start_driver {
		spawn animation_frame_driver()
	}
}

fn animation_frame_driver() {
	for {
		time.sleep(16 * time.millisecond)
		if !animations_need_frames(time.ticks()) {
			// The first trailing refresh completes an animation whose deadline was
			// crossed; the second reflects any application state its callback changed.
			request_animation_refresh()
			time.sleep(16 * time.millisecond)
			request_animation_refresh()
			return
		}
		request_animation_refresh()
	}
}

fn configure_animation_driver(callback AnimationRefreshFn, drive_frames bool) {
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	runtime.refresh_callback = callback
	runtime.drive_frames = drive_frames
	runtime.mutex.unlock()
}

fn request_animation_refresh() {
	runtime := g_animation_runtime
	runtime.mutex.lock()
	callback := runtime.refresh_callback
	runtime.mutex.unlock()
	if voidptr(callback) != unsafe { nil } {
		callback()
	}
}

fn animations_need_frames(now i64) bool {
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	mut active := false
	for _, animation_run in runtime.runs {
		deadline := animation_run.started_at + i64(math.ceil(animation_run.definition.duration * 1000.0)) + 34
		if animation_run.status == .running
			&& (animation_run.definition.repeat || now <= deadline) {
			active = true
			break
		}
	}
	if !active {
		runtime.driver_running = false
	}
	runtime.mutex.unlock()
	return active
}

fn apply_widget_animations(root Element) Element {
	return apply_widget_animations_at(root, time.ticks())
}

fn apply_widget_animations_at(root Element, now i64) Element {
	mut runtime := g_animation_runtime
	mut pending := []PendingAnimationEvent{}
	runtime.mutex.lock()
	result := apply_widget_animation_node(root, now, mut pending)
	runtime.mutex.unlock()
	dispatch_animation_events(pending)
	return result
}

fn apply_widget_animation_node(declared Element, now i64, mut pending []PendingAnimationEvent) Element {
	mut runtime := g_animation_runtime
	mut children := []Element{cap: declared.children.len}
	for child in declared.children {
		children << apply_widget_animation_node(child, now, mut pending)
	}
	mut result := Element{
		...declared
		children: children
	}
	if declared.id.len == 0 {
		return result
	}
	mut animation_run := runtime.runs[declared.id] or { return result }
	previous_progress := animation_run.progress
	if !animation_run.initialized {
		animation_run.initialized = true
		animation_run.start = result
		animation_run.last = result
		if voidptr(animation_run.definition.on_event) != unsafe { nil } {
			pending << PendingAnimationEvent{
				callback: animation_run.definition.on_event
				event: AnimationEvent{
					kind: .start
					id: declared.id
				}
			}
		}
	}
	if animation_run.status == .running {
		elapsed := math.max(0.0, f64(now - animation_run.started_at) / 1000.0)
		duration := animation_run.definition.duration
		mut evaluation_elapsed := elapsed
		mut completed := duration == 0.0
		if animation_run.definition.repeat && duration > 0.0 {
			cycle := i64(math.floor(elapsed / duration))
			evaluation_elapsed = math.fmod(elapsed, duration)
			cycle_start := if cycle == 0 {
				animation_run.start
			} else {
				evaluate_animation(animation_run.definition, animation_run.start, duration)
			}
			evaluated := evaluate_animation(animation_run.definition, cycle_start, evaluation_elapsed)
			result = merge_animation_properties(result, evaluated, animation_run.retained)
			animation_run.progress = evaluation_elapsed / duration
		} else {
			if elapsed >= duration {
				evaluation_elapsed = duration
				completed = true
			}
			evaluated := evaluate_animation(animation_run.definition, animation_run.start, evaluation_elapsed)
			result = merge_animation_properties(result, evaluated, animation_run.retained)
			animation_run.progress = if duration == 0.0 {
				1.0
			} else {
				math.min(1.0, elapsed / duration)
			}
		}
		if animation_run.suppressed.len > 0 {
			result = merge_suppressed_animation_properties(result, animation_run.last, animation_run.suppressed)
		}
		if voidptr(animation_run.definition.on_event) != unsafe { nil }
			&& animation_run.progress != previous_progress {
			pending << PendingAnimationEvent{
				callback: animation_run.definition.on_event
				event: AnimationEvent{
					kind: .progress
					id: declared.id
					progress: animation_run.progress
				}
			}
		}
		if completed {
			animation_run.status = .completed
			if voidptr(animation_run.definition.on_event) != unsafe { nil } {
				pending << PendingAnimationEvent{
					callback: animation_run.definition.on_event
					event: AnimationEvent{
						kind: .complete
						id: declared.id
						progress: 1.0
					}
				}
			}
		}
		animation_run.last = result
		runtime.runs[declared.id] = animation_run
		return result
	}
	if animation_run.initialized {
		result = merge_animation_properties(result, animation_run.last, animation_run.retained)
	}
	runtime.runs[declared.id] = animation_run
	return result
}

fn dispatch_animation_events(pending []PendingAnimationEvent) {
	for item in pending {
		item.callback(item.event)
	}
}

fn evaluate_animation(definition Animation, start Element, elapsed f64) Element {
	return match definition.kind {
		.tween {
			mut sample := elapsed
			if definition.step > 0.0 && elapsed < definition.duration {
				sample = math.floor(elapsed / definition.step) * definition.step
			}
			raw := if definition.duration == 0.0 {
				1.0
			} else {
				math.max(0.0, math.min(1.0, sample / definition.duration))
			}
			eased := apply_animation_transition(definition, raw)
			apply_animation_targets(start, definition.targets, eased)
		}
		.sequence {
			evaluate_animation_sequence(definition.children, start, elapsed)
		}
		.parallel {
			evaluate_animation_parallel(definition.children, start, elapsed)
		}
	}
}

fn evaluate_animation_sequence(children []Animation, start Element, elapsed f64) Element {
	mut current := start
	mut remaining := math.max(0.0, elapsed)
	for child in children {
		if remaining >= child.duration {
			current = evaluate_animation(child, current, child.duration)
			remaining -= child.duration
			continue
		}
		return evaluate_animation(child, current, remaining)
	}
	return current
}

fn evaluate_animation_parallel(children []Animation, start Element, elapsed f64) Element {
	mut current := start
	for child in children {
		evaluated := evaluate_animation(child, start, math.min(elapsed, child.duration))
		current = merge_animation_properties(current, evaluated, child.properties)
	}
	return current
}

fn apply_animation_transition(definition Animation, progress f64) f64 {
	if voidptr(definition.transition_fn) != unsafe { nil } {
		return definition.transition_fn(progress)
	}
	return match definition.transition {
		.linear { easing.linear(progress) }
		.in_sine { easing.in_sine(progress) }
		.out_sine { easing.out_sine(progress) }
		.in_out_sine { easing.in_out_sine(progress) }
		.in_quad { easing.in_quad(progress) }
		.out_quad { easing.out_quad(progress) }
		.in_out_quad { easing.in_out_quad(progress) }
		.in_cubic { easing.in_cubic(progress) }
		.out_cubic { easing.out_cubic(progress) }
		.in_out_cubic { easing.in_out_cubic(progress) }
		.in_quart { easing.in_quart(progress) }
		.out_quart { easing.out_quart(progress) }
		.in_out_quart { easing.in_out_quart(progress) }
		.in_quint { easing.in_quint(progress) }
		.out_quint { easing.out_quint(progress) }
		.in_out_quint { easing.in_out_quint(progress) }
		.in_expo { easing.in_expo(progress) }
		.out_expo { easing.out_expo(progress) }
		.in_out_expo { easing.in_out_expo(progress) }
		.in_circ { easing.in_circ(progress) }
		.out_circ { easing.out_circ(progress) }
		.in_out_circ { easing.in_out_circ(progress) }
		.in_back { easing.in_back(progress) }
		.out_back { easing.out_back(progress) }
		.in_out_back { easing.in_out_back(progress) }
		.in_elastic { easing.in_elastic(progress) }
		.out_elastic { easing.out_elastic(progress) }
		.in_out_elastic { easing.in_out_elastic(progress) }
		.in_bounce { easing.in_bounce(progress) }
		.out_bounce { easing.out_bounce(progress) }
		.in_out_bounce { easing.in_out_bounce(progress) }
	}
}

fn interpolate(start f64, target f64, progress f64) f64 {
	return start + (target - start) * progress
}

fn interpolate_color(start u32, target u32, progress f64) u32 {
	if progress == 1.0 {
		return target
	}
	start_r := f64((start >> 16) & 0xff)
	start_g := f64((start >> 8) & 0xff)
	start_b := f64(start & 0xff)
	target_r := f64((target >> 16) & 0xff)
	target_g := f64((target >> 8) & 0xff)
	target_b := f64(target & 0xff)
	r := u32(math.round(math.max(0.0, math.min(255.0, interpolate(start_r, target_r, progress)))))
	g := u32(math.round(math.max(0.0, math.min(255.0, interpolate(start_g, target_g, progress)))))
	b := u32(math.round(math.max(0.0, math.min(255.0, interpolate(start_b, target_b, progress)))))
	return (r << 16) | (g << 8) | b
}

fn apply_animation_targets(start Element, targets AnimationTargets, progress f64) Element {
	mut x := start.frame.x
	mut y := start.frame.y
	mut width := start.frame.width
	mut height := start.frame.height
	mut rotation := start.rotation
	mut background := start.box.bg
	mut corner_radius := start.box.radius
	mut text_color := start.text_style.color
	mut text_background := start.text_style.background_color
	mut font_size := start.text_style.size
	mut padding_left := start.padding_left
	if target := targets.x {
		x = interpolate(x, target, progress)
	}
	if target := targets.y {
		y = interpolate(y, target, progress)
	}
	if target := targets.width {
		width = interpolate(width, target, progress)
	}
	if target := targets.height {
		height = interpolate(height, target, progress)
	}
	if target := targets.rotation {
		rotation = interpolate(rotation, target, progress)
	}
	if target := targets.background {
		background = interpolate_color(background, target, progress)
	}
	if target := targets.corner_radius {
		corner_radius = interpolate(corner_radius, target, progress)
	}
	if target := targets.text_color {
		text_color = interpolate_color(text_color, target, progress)
	}
	if target := targets.text_background {
		text_background = interpolate_color(text_background, target, progress)
	}
	if target := targets.font_size {
		font_size = interpolate(font_size, target, progress)
	}
	if target := targets.padding_left {
		padding_left = interpolate(padding_left, target, progress)
	}
	mut result := Element{
		...start
		frame: Rect{
			...start.frame
			x: x
			y: y
			width: width
			height: height
		}
		box: BoxStyle{
			...start.box
			bg: background
			radius: corner_radius
		}
		text_style: TextStyle{
			...start.text_style
			color: text_color
			background_color: text_background
			size: font_size
		}
		rotation: rotation
		padding_left: padding_left
	}
	for property in targets.properties {
		result = match property.kind {
			.number {
				set_number_animation_property(result, property.name, interpolate(animation_number_property_value(start, property.name), property.number, progress))
			}
			.color {
				set_color_animation_property(result, property.name, interpolate_color(animation_color_property_value(start, property.name), property.color, progress))
			}
		}
	}
	return result
}

fn animation_number_property_value(element Element, property string) f64 {
	return match property {
		'x' { element.frame.x }
		'y' { element.frame.y }
		'width' { element.frame.width }
		'height' { element.frame.height }
		'rotation' { element.rotation }
		'corner_radius' { element.box.radius }
		'box.border_left' { element.box.border_left }
		'box.border_top' { element.box.border_top }
		'box.border_right' { element.box.border_right }
		'box.border_bottom' { element.box.border_bottom }
		'font_size' { element.text_style.size }
		'text_style.head_indent' { element.text_style.head_indent }
		'text_style.first_line_indent' { element.text_style.first_line_indent }
		'text_style.hyphenation_factor' { element.text_style.hyphenation_factor }
		'text_style.lines' { f64(element.text_style.lines) }
		'padding_left' { element.padding_left }
		'keyboard' { f64(element.keyboard) }
		'value' { element.value }
		'min_value' { element.min_value }
		'max_value' { element.max_value }
		'step' { element.step }
		'padding' { element.padding }
		'slider_style.track_width' { element.slider_style.track_width }
		'slider_style.thumb_size' { element.slider_style.thumb_size }
		'toggle_down_box.radius' { element.toggle_down_box.radius }
		'toggle_down_box.border_left' { element.toggle_down_box.border_left }
		'toggle_down_box.border_top' { element.toggle_down_box.border_top }
		'toggle_down_box.border_right' { element.toggle_down_box.border_right }
		'toggle_down_box.border_bottom' { element.toggle_down_box.border_bottom }
		'toggle_down_text_style.size' { element.toggle_down_text_style.size }
		'toggle_down_text_style.head_indent' { element.toggle_down_text_style.head_indent }
		'toggle_down_text_style.first_line_indent' {
			element.toggle_down_text_style.first_line_indent
		}
		'toggle_down_text_style.hyphenation_factor' {
			element.toggle_down_text_style.hyphenation_factor
		}
		'toggle_down_text_style.lines' { f64(element.toggle_down_text_style.lines) }
		else { 0.0 }
	}
}

fn animation_color_property_value(element Element, property string) u32 {
	return match property {
		'background' { element.box.bg }
		'box.border_color' { element.box.border_color }
		'text_color' { element.text_style.color }
		'text_background' { element.text_style.background_color }
		'slider_style.track_color' { element.slider_style.track_color }
		'slider_style.value_track_color' { element.slider_style.value_track_color }
		'slider_style.thumb_color' { element.slider_style.thumb_color }
		'switch_style.inactive_track_color' { element.switch_style.inactive_track_color }
		'switch_style.active_track_color' { element.switch_style.active_track_color }
		'switch_style.thumb_color' { element.switch_style.thumb_color }
		'switch_style.disabled_track_color' { element.switch_style.disabled_track_color }
		'switch_style.disabled_thumb_color' { element.switch_style.disabled_thumb_color }
		'toggle_down_box.bg' { element.toggle_down_box.bg }
		'toggle_down_box.border_color' { element.toggle_down_box.border_color }
		'toggle_down_text_style.color' { element.toggle_down_text_style.color }
		'toggle_down_text_style.background_color' {
			element.toggle_down_text_style.background_color
		}
		else { u32(0) }
	}
}

fn set_number_animation_property(element Element, property string, value f64) Element {
	return match property {
		'x' { Element{ ...element, frame: Rect{ ...element.frame, x: value } } }
		'y' { Element{ ...element, frame: Rect{ ...element.frame, y: value } } }
		'width' { Element{ ...element, frame: Rect{ ...element.frame, width: value } } }
		'height' { Element{ ...element, frame: Rect{ ...element.frame, height: value } } }
		'rotation' { Element{ ...element, rotation: value } }
		'corner_radius' { Element{ ...element, box: BoxStyle{ ...element.box, radius: value } } }
		'box.border_left' {
			Element{ ...element, box: BoxStyle{ ...element.box, border_left: value } }
		}
		'box.border_top' {
			Element{ ...element, box: BoxStyle{ ...element.box, border_top: value } }
		}
		'box.border_right' {
			Element{ ...element, box: BoxStyle{ ...element.box, border_right: value } }
		}
		'box.border_bottom' {
			Element{ ...element, box: BoxStyle{ ...element.box, border_bottom: value } }
		}
		'font_size' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, size: value } }
		}
		'text_style.head_indent' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, head_indent: value } }
		}
		'text_style.first_line_indent' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, first_line_indent: value } }
		}
		'text_style.hyphenation_factor' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, hyphenation_factor: value } }
		}
		'text_style.lines' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, lines: int(math.round(value)) } }
		}
		'padding_left' { Element{ ...element, padding_left: value } }
		'keyboard' { Element{ ...element, keyboard: int(math.round(value)) } }
		'value' { Element{ ...element, value: value } }
		'min_value' { Element{ ...element, min_value: value } }
		'max_value' { Element{ ...element, max_value: value } }
		'step' { Element{ ...element, step: value } }
		'padding' { Element{ ...element, padding: value } }
		'slider_style.track_width' {
			Element{ ...element, slider_style: SliderStyle{ ...element.slider_style, track_width: value } }
		}
		'slider_style.thumb_size' {
			Element{ ...element, slider_style: SliderStyle{ ...element.slider_style, thumb_size: value } }
		}
		'toggle_down_box.radius' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, radius: value } }
		}
		'toggle_down_box.border_left' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, border_left: value } }
		}
		'toggle_down_box.border_top' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, border_top: value } }
		}
		'toggle_down_box.border_right' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, border_right: value } }
		}
		'toggle_down_box.border_bottom' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, border_bottom: value } }
		}
		'toggle_down_text_style.size' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, size: value } }
		}
		'toggle_down_text_style.head_indent' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, head_indent: value } }
		}
		'toggle_down_text_style.first_line_indent' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, first_line_indent: value } }
		}
		'toggle_down_text_style.hyphenation_factor' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, hyphenation_factor: value } }
		}
		'toggle_down_text_style.lines' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, lines: int(math.round(value)) } }
		}
		else { element }
	}
}

fn set_color_animation_property(element Element, property string, value u32) Element {
	return match property {
		'background' { Element{ ...element, box: BoxStyle{ ...element.box, bg: value } } }
		'box.border_color' {
			Element{ ...element, box: BoxStyle{ ...element.box, border_color: value } }
		}
		'text_color' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, color: value } }
		}
		'text_background' {
			Element{ ...element, text_style: TextStyle{ ...element.text_style, background_color: value } }
		}
		'slider_style.track_color' {
			Element{ ...element, slider_style: SliderStyle{ ...element.slider_style, track_color: value } }
		}
		'slider_style.value_track_color' {
			Element{ ...element, slider_style: SliderStyle{ ...element.slider_style, value_track_color: value } }
		}
		'slider_style.thumb_color' {
			Element{ ...element, slider_style: SliderStyle{ ...element.slider_style, thumb_color: value } }
		}
		'switch_style.inactive_track_color' {
			Element{ ...element, switch_style: SwitchStyle{ ...element.switch_style, inactive_track_color: value } }
		}
		'switch_style.active_track_color' {
			Element{ ...element, switch_style: SwitchStyle{ ...element.switch_style, active_track_color: value } }
		}
		'switch_style.thumb_color' {
			Element{ ...element, switch_style: SwitchStyle{ ...element.switch_style, thumb_color: value } }
		}
		'switch_style.disabled_track_color' {
			Element{ ...element, switch_style: SwitchStyle{ ...element.switch_style, disabled_track_color: value } }
		}
		'switch_style.disabled_thumb_color' {
			Element{ ...element, switch_style: SwitchStyle{ ...element.switch_style, disabled_thumb_color: value } }
		}
		'toggle_down_box.bg' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, bg: value } }
		}
		'toggle_down_box.border_color' {
			Element{ ...element, toggle_down_box: BoxStyle{ ...element.toggle_down_box, border_color: value } }
		}
		'toggle_down_text_style.color' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, color: value } }
		}
		'toggle_down_text_style.background_color' {
			Element{ ...element, toggle_down_text_style: TextStyle{ ...element.toggle_down_text_style, background_color: value } }
		}
		else { element }
	}
}

fn merge_animation_properties(base Element, values Element, properties []string) Element {
	mut result := Element{
		...base
		frame: Rect{
			...base.frame
			x: if 'x' in properties { values.frame.x } else { base.frame.x }
			y: if 'y' in properties { values.frame.y } else { base.frame.y }
			width: if 'width' in properties { values.frame.width } else { base.frame.width }
			height: if 'height' in properties { values.frame.height } else { base.frame.height }
		}
		box: BoxStyle{
			...base.box
			bg: if 'background' in properties { values.box.bg } else { base.box.bg }
			radius: if 'corner_radius' in properties { values.box.radius } else { base.box.radius }
		}
		text_style: TextStyle{
			...base.text_style
			color: if 'text_color' in properties {
				values.text_style.color
			} else {
				base.text_style.color
			}
			background_color: if 'text_background' in properties {
				values.text_style.background_color
			} else {
				base.text_style.background_color
			}
			size: if 'font_size' in properties {
				values.text_style.size
			} else {
				base.text_style.size
			}
		}
		rotation: if 'rotation' in properties { values.rotation } else { base.rotation }
		padding_left: if 'padding_left' in properties {
			values.padding_left
		} else {
			base.padding_left
		}
	}
	for property in properties {
		if animation_property_kind_matches(property, .number) {
			result = set_number_animation_property(result, property, animation_number_property_value(values, property))
		} else if animation_property_kind_matches(property, .color) {
			result = set_color_animation_property(result, property, animation_color_property_value(values, property))
		}
	}
	return result
}

fn merge_suppressed_animation_properties(base Element, values Element, suppressed map[string]bool) Element {
	mut properties := []string{}
	for property, is_suppressed in suppressed {
		if is_suppressed {
			properties << property
		}
	}
	return merge_animation_properties(base, values, properties)
}

fn reset_widget_animations() {
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	runtime.runs = map[string]AnimationRun{}
	runtime.driver_running = false
	runtime.mutex.unlock()
}
