@[has_globals]
module ui2

import math

__global g_style_prev_elements = map[string]Element{}
__global g_style_prev_valid = false

struct StyleTransitionRun {
	start      AnimationProperty
	target     AnimationProperty
	spec       StyleTransition
	started_at i64
}

struct StylePropertyStop {
	at    f64
	value AnimationProperty
}

struct StyleKeyframeTrack {
	property string
	stops    []StylePropertyStop
}

struct StyleKeyframeRun {
	name   string
	slot   int
	tracks []StyleKeyframeTrack
mut:
	spec       StyleAnimation
	started_at i64
	paused_at  i64
	paused     bool
	finished   bool
}

struct StyleElementAnimations {
mut:
	transitions map[string]StyleTransitionRun
	animations  []StyleKeyframeRun
}

fn style_animation_history_exists() bool {
	return g_style_prev_valid
}

fn clear_style_animations() {
	mut runtime := animation_runtime()
	runtime.mutex.lock()
	runtime.style_runs = map[string]StyleElementAnimations{}
	runtime.mutex.unlock()
	reset_style_animation_history()
}

fn reset_style_animation_history() {
	g_style_prev_elements = map[string]Element{}
	g_style_prev_valid = false
}

// CSS owns a separate set of timelines. Removing a rule never cancels an
// imperative animation on the same element, and each comma entry keeps its clock.
fn style_animation_drive(current Element) {
	style_animation_drive_at(current, animation_now_ms())
}

fn style_animation_drive_at(current Element, now i64) {
	mut runtime := animation_runtime()
	runtime.mutex.lock()
	mut seen := map[string]bool{}
	mut changed := walk_style_animations(current, []Stylesheet{}, now, mut seen)
	for id, _ in runtime.style_runs {
		if id !in seen {
			runtime.style_runs.delete(id)
			changed = true
		}
	}
	runtime.mutex.unlock()
	g_style_prev_elements = index_elements_by_id(current)
	g_style_prev_valid = true
	if changed { schedule_animation_frames() }
}

fn index_elements_by_id(root Element) map[string]Element {
	mut out := map[string]Element{}
	mut stack := [root]
	for stack.len > 0 {
		el := stack.pop()
		if el.id.len > 0 { out[el.id] = el }
		for child in el.children { stack << child }
	}
	return out
}

fn walk_style_animations(current Element, ancestor_sheets []Stylesheet, now i64, mut seen map[string]bool) bool {
	mut changed := false
	mut sheets := ancestor_sheets.clone()
	if !stylesheet_is_empty(current.stylesheet) { sheets << current.stylesheet }
	if current.id.len > 0 {
		seen[current.id] = true
		mut runtime := animation_runtime()
		mut state := runtime.style_runs[current.id] or { StyleElementAnimations{} }
		mut covered := map[string]bool{}
		if old_el := g_style_prev_elements[current.id] {
			displayed, _ := apply_style_animation_node(old_el, now)
			state = runtime.style_runs[current.id] or { state }
			for spec in current.style_transitions {
				props := if spec.properties.len == 0 || spec.properties == ['all'] {
					all_animatable_properties()
				} else {
					spec.properties
				}
				for prop in props {
					for name in css_anim_properties(prop) { covered[name] = true }
				}
				for target in changed_transition_targets(old_el, current, spec) {
					if spec.duration <= 0 {
						state.transitions.delete(target.name)
						continue
					}
					state.transitions[target.name] = StyleTransitionRun{
						start:      style_property_value(displayed, target.name)
						target:     target
						spec:       spec
						started_at: now
					}
					changed = true
				}
			}
		}
		for name, _ in state.transitions {
			if name !in covered {
				state.transitions.delete(name)
				changed = true
			}
		}
		mut next := []StyleKeyframeRun{}
		mut used := map[int]bool{}
		for slot, spec in current.style_animations {
			if spec.name.len == 0 || spec.name == 'none' || spec.duration <= 0
				|| (!spec.infinite && spec.iteration_count <= 0) {
				continue
			}
			mut found := false
			for previous_index, previous in state.animations {
				if previous_index in used || previous.name != spec.name { continue }
				used[previous_index] = true
				mut run := StyleKeyframeRun{ ...previous, slot: slot }
				if previous.spec != spec {
					run.finished = false
					changed = true
				}
				paused := spec.play_state == 'paused'
				if paused && !run.paused {
					run.paused_at = now
					changed = true
				}
				if !paused && run.paused {
					run.started_at += now - run.paused_at
					changed = true
				}
				run.paused = paused
				run.spec = spec
				next << run
				found = true
				break
			}
			if found { continue }
			if keyframes := find_keyframes(sheets, spec.name) {
				tracks := build_keyframe_tracks(sheets, keyframes, current)
				if tracks.len == 0 { continue }
				next << StyleKeyframeRun{
					name:       spec.name
					slot:       slot
					spec:       spec
					tracks:     tracks
					started_at: now
					paused_at:  now
					paused:     spec.play_state == 'paused'
				}
				changed = true
			}
		}
		if next.len != state.animations.len { changed = true }
		state.animations = next
		if state.animations.len > 0 || state.transitions.len > 0 {
			runtime.style_runs[current.id] = state
		} else {
			runtime.style_runs.delete(current.id)
		}
	}
	for child in current.children {
		child_changed := walk_style_animations(child, sheets, now, mut seen)
		changed = changed || child_changed
	}
	return changed
}

fn changed_transition_targets(old_el Element, current Element, spec StyleTransition) []AnimationProperty {
	mut targets := []AnimationProperty{}
	props := if spec.properties.len == 0 || spec.properties == ['all'] {
		all_animatable_properties()
	} else {
		spec.properties
	}
	for prop in props {
		for name in css_anim_properties(prop) {
			if !is_animatable_property(name, .number) && !is_animatable_property(name, .color) {
				continue
			}
			old := style_property_value(old_el, name)
			target := style_property_value(current, name)
			if old != target { targets << target }
		}
	}
	return targets
}

fn style_property_value(el Element, name string) AnimationProperty {
	if is_animatable_property(name, .color) {
		return animation_color_property(name, animation_color_property_value(el, name))
	}
	return animation_number_property(name, animation_number_property_value(el, name))
}

fn css_anim_properties(name string) []string {
	l := name.to_lower().trim_space()
	match l {
		'x' { return ['x'] }
		'y' { return ['y'] }
		'width' { return ['width'] }
		'height' { return ['height'] }
		'rotation' { return ['rotation'] }
		'opacity' { return ['box.opacity'] }
		'background', 'background-color' { return ['background'] }
		'corner-radius', 'border-radius' { return ['corner_radius'] }
		'color' { return ['text_color'] }
		'font-size' { return ['font_size'] }
		'border-color' { return ['box.border_color'] }
		'border-width' {
			return ['box.border_left', 'box.border_top', 'box.border_right', 'box.border_bottom']
		}
		'padding-left' { return ['padding_left'] }
		else { return [l] }
	}
}

fn all_animatable_properties() []string {
	// A conservative subset of commonly transitioned properties.
	return ['x', 'y', 'width', 'height', 'rotation', 'background', 'corner_radius', 'text_color',
		'font_size', 'box.opacity', 'box.border_color', 'box.border_left', 'box.border_top',
		'box.border_right', 'box.border_bottom', 'box.shadow.opacity', 'box.shadow.blur', 'box.shadow.x',
		'box.shadow.y', 'padding_left']
}

fn find_keyframes(sheets []Stylesheet, name string) ?StyleKeyframes {
	for i := sheets.len - 1; i >= 0; i-- {
		if kf := sheets[i].keyframes[name] { return kf }
	}
	if has_global_stylesheet() {
		if kf := global_stylesheet().keyframes[name] { return kf }
	}
	return none
}

fn build_keyframe_tracks(sheets []Stylesheet, kf StyleKeyframes, declared Element) []StyleKeyframeTrack {
	mut stops := map[string][]StylePropertyStop{}
	for frame in kf.stops {
		for value in keyframe_targets_for_element(sheets, frame, declared) {
			mut track := stops[value.name] or { []StylePropertyStop{} }
			if track.len > 0 && track.last().at == frame.stop { track.delete_last() }
			track << StylePropertyStop{ at: frame.stop, value: value }
			stops[value.name] = track
		}
	}
	mut tracks := []StyleKeyframeTrack{}
	for property, values in stops {
		mut track := values.clone()
		underlying := style_property_value(declared, property)
		if track[0].at != 0 { track.prepend(StylePropertyStop{ at: 0, value: underlying }) }
		if track.last().at != 1 { track << StylePropertyStop{ at: 1, value: underlying } }
		tracks << StyleKeyframeTrack{ property: property, stops: track }
	}
	return tracks
}

fn keyframe_targets(sheets []Stylesheet, stop StyleKeyframe) []AnimationProperty {
	return keyframe_targets_for_element(sheets, stop, Element{})
}

fn keyframe_targets_for_element(sheets []Stylesheet, stop StyleKeyframe, declared Element) []AnimationProperty {
	mut scopes := []Stylesheet{}
	if has_global_stylesheet() { scopes << global_stylesheet() }
	scopes << sheets
	qenv := stylesheet_query_env(stylesheet_dark_mode(), stylesheet_live_dpi())
	lctx := StyleLengthCtx{
		win_w:  qenv.width
		win_h:  qenv.height
		cont_w: declared.frame.width
		cont_h: declared.frame.height
		insets: qenv.insets
	}
	mut targets := []AnimationProperty{}
	for decl in stop.declarations {
		value := cascade_resolve_value(decl.value, scopes, stylesheet_dark_mode(), declared.style_custom_properties, map[string]string{}) or { continue }
		for name in css_anim_properties(decl.prop) {
			if is_animatable_property(name, .color) {
				token := component_theme_token(value) or { continue }
				targets << animation_color_property(name, token.over(0xffffff))
			} else if is_animatable_property(name, .number) {
				mut number := 0.0
				if name == 'box.opacity' {
					raw := value.trim_space()
					percent := raw.ends_with('%')
					n := query_plain_number(if percent { raw[..raw.len - 1] } else { raw }) or { continue }
					number = unit_clamp(if percent { n / 100 } else { n })
				} else {
					number = style_length_px(value, lctx) or { continue }
				}
				targets << animation_number_property(name, number)
			}
		}
	}
	return normalized_animation_properties(targets)
}

// Iterations are evaluated arithmetically, so fractional and large finite
// counts remain finite without allocating copies of their keyframes.
fn style_keyframe_position(run StyleKeyframeRun, now i64) (f64, bool, bool) {
	clock := if run.paused { run.paused_at } else { now }
	elapsed := f64(clock - run.started_at) / 1000.0 - run.spec.delay
	mut position := 0.0
	mut cycle := 0.0
	mut finished := false
	if elapsed < 0 {
		if run.spec.fill_mode !in ['backwards', 'both'] { return 0, false, false }
	} else {
		iterations := elapsed / run.spec.duration
		if !run.spec.infinite && iterations >= run.spec.iteration_count {
			finished = true
			if run.spec.fill_mode !in ['forwards', 'both'] { return 0, false, true }
			cycle = math.floor(run.spec.iteration_count)
			position = math.fmod(run.spec.iteration_count, 1)
			if position == 0 {
				position = 1
				cycle = math.max(cycle - 1, 0)
			}
		} else {
			cycle = math.floor(iterations)
			position = math.fmod(iterations, 1)
		}
	}
	reversed := run.spec.direction == 'reverse'
		|| (run.spec.direction == 'alternate' && math.fmod(cycle, 2) == 1)
		|| (run.spec.direction == 'alternate-reverse' && math.fmod(cycle, 2) == 0)
	return if reversed { 1 - position } else { position }, true, finished
}

fn style_apply_property_pair(el Element, from AnimationProperty, to AnimationProperty, progress f64) Element {
	start := apply_animation_targets(el, AnimationTargets{ properties: [from] }, 1)
	return apply_animation_targets(start, AnimationTargets{ properties: [to] }, progress)
}

// Called under the animation runtime mutex, alongside the imperative pass.
fn apply_style_animation_node(declared Element, now i64) (Element, bool) {
	mut runtime := animation_runtime()
	mut state := runtime.style_runs[declared.id] or { return declared, false }
	mut out := declared
	for i in 0 .. state.animations.len {
		mut run := state.animations[i]
		position, contributes, finished := style_keyframe_position(run, now)
		run.finished = finished
		state.animations[i] = run
		if !contributes { continue }
		for track in run.tracks {
			for stop in 1 .. track.stops.len {
				left := track.stops[stop - 1]
				right := track.stops[stop]
				if position > right.at && stop < track.stops.len - 1 { continue }
				progress := unit_clamp((position - left.at) / (right.at - left.at))
				eased := apply_animation_transition(Animation{ transition: run.spec.timing, transition_fn: run.spec.timing_fn }, progress)
				out = style_apply_property_pair(out, left.value, right.value, eased)
				break
			}
		}
	}
	// CSS transitions have precedence over keyframe animation values.
	for name, run in state.transitions {
		elapsed := f64(now - run.started_at) / 1000.0 - run.spec.delay
		if elapsed >= run.spec.duration {
			state.transitions.delete(name)
			continue
		}
		progress := unit_clamp(elapsed / run.spec.duration)
		eased := apply_animation_transition(Animation{ transition: run.spec.timing, transition_fn: run.spec.timing_fn }, progress)
		out = style_apply_property_pair(out, run.start, run.target, eased)
	}
	runtime.style_runs[declared.id] = state
	return out, true
}

fn style_animation_needs_frame(id string) bool {
	runtime := animation_runtime()
	state := runtime.style_runs[id] or { return false }
	return state.transitions.len > 0 || state.animations.any(!it.paused && !it.finished)
}

fn style_animations_need_frames(now i64) bool {
	runtime := animation_runtime()
	for _, state in runtime.style_runs {
		for _, run in state.transitions {
			if f64(now - run.started_at) <= (run.spec.duration + run.spec.delay) * 1000 + 34 {
				return true
			}
		}
		for run in state.animations {
			if run.paused || run.finished { continue }
			if run.spec.infinite || f64(now - run.started_at) <= (run.spec.duration * run.spec.iteration_count + run.spec.delay) * 1000 + 34 {
				return true
			}
		}
	}
	return false
}

fn element_has_style_animation_specs(el Element) bool {
	if el.style_transitions.len > 0 || el.style_animations.len > 0 || el.style_transition_values.len > 0 || el.style_animation_values.len > 0 {
		return true
	}
	return el.children.any(element_has_style_animation_specs(it))
}
