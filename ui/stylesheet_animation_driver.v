@[has_globals]
module ui2

// runtime but keyed to declared (pre-animation) trees.
__global g_style_prev_elements = map[string]Element{}
__global g_style_prev_valid = false
// Tracks which (id, animation-name) pairs were matching on the previous
// frame, so keyframes animations start only on entry.
__global g_style_prev_anim_matches = map[string]bool{}

fn style_animation_drive(current Element) {
	had_prev := g_style_prev_valid
	new_elements := index_elements_by_id(current)
	if had_prev {
		drive_transitions(g_style_prev_elements, current, new_elements)
	}
	drive_keyframes(current, had_prev)
	g_style_prev_elements = new_elements.clone()
	g_style_prev_valid = true
}

// drive_transitions walks old and current in parallel by id and starts a
// tween for every transitioned property whose resolved value changed.
fn drive_transitions(old map[string]Element, current Element, new_elements map[string]Element) {
	walk_for_transitions(current, old)
}

fn index_elements_by_id(root Element) map[string]Element {
	mut out := map[string]Element{}
	mut stack := [root]
	for stack.len > 0 {
		el := stack.pop()
		if el.id.len > 0 {
			out[el.id] = el
		}
		for child in el.children {
			stack << child
		}
	}
	return out
}

fn walk_for_transitions(current Element, old_by_id map[string]Element) {
	if old_el := old_by_id[current.id] {
		if current.id.len > 0 && current.style_transitions.len > 0 {
			for tr in current.style_transitions {
				props := if tr.properties.len == 0 || (tr.properties.len == 1 && tr.properties[0] == 'all') {
					// 'all': try every animatable property
					all_animatable_properties()
				} else {
					tr.properties.clone()
				}
				mut targets := []AnimationProperty{}
				mut changed := false
				for p in props {
					ap := css_anim_property(p)
					if ap == '' {
						continue
					}
					if !is_animatable_property(ap, .number) && !is_animatable_property(ap, .color) {
						continue
					}
					kind := if is_animatable_property(ap, .color) {
						AnimationPropertyKind.color
					} else {
						AnimationPropertyKind.number
					}
					old_val_num := animation_number_property_value(old_el, ap)
					new_val_num := animation_number_property_value(current, ap)
					old_val_col := animation_color_property_value(old_el, ap)
					new_val_col := animation_color_property_value(current, ap)
					if kind == .number {
						if old_val_num != new_val_num {
							changed = true
							targets << animation_number_property(ap, new_val_num)
						}
					} else {
						if old_val_col != new_val_col {
							changed = true
							targets << animation_color_property(ap, new_val_col)
						}
					}
				}
				if changed && targets.len > 0 {
					start_transition(current.id, old_el, targets, tr)
				}
			}
		}
	}
	for child in current.children {
		walk_for_transitions(child, old_by_id)
	}
}

fn css_anim_property(name string) string {
	l := name.to_lower().trim_space()
	match l {
		'x' { return 'x' }
		'y' { return 'y' }
		'width' { return 'width' }
		'height' { return 'height' }
		'rotation' { return 'rotation' }
		'opacity' { return 'box.opacity' }
		'background', 'background-color' { return 'background' }
		'corner-radius', 'border-radius' { return 'corner_radius' }
		'color' { return 'text_color' }
		'font-size' { return 'font_size' }
		'border-color' { return 'box.border_color' }
		'border-width', 'border-left-width' { return 'box.border_left' }
		'padding-left' { return 'padding_left' }
		else { return l }
	}
}

fn all_animatable_properties() []string {
	// A conservative subset of commonly transitioned properties.
	return ['x', 'y', 'width', 'height', 'rotation', 'background', 'corner_radius', 'text_color',
		'font_size', 'box.opacity', 'box.border_color', 'box.border_left', 'box.border_top',
		'box.border_right', 'box.border_bottom', 'box.shadow.opacity', 'box.shadow.blur', 'box.shadow.x',
		'box.shadow.y', 'padding_left', 'opacity']
}

fn start_transition(id string, old_el Element, targets []AnimationProperty, tr StyleTransition) {
	// Seed a run with the old displayed element so the runtime captures it as start.
	mut runtime := g_animation_runtime
	runtime.mutex.lock()
	if id !in runtime.runs {
		runtime.runs[id] = AnimationRun{
			initialized: true
			start:       old_el
			last:        old_el
			status:      .running
		}
	}
	runtime.mutex.unlock()
	mut anim := animation(AnimationConfig{
		duration:      tr.duration
		delay:         tr.delay
		transition:    tr.timing
		transition_fn: tr.timing_fn
		properties:    targets
	})
	// apply delay by adjusting? runtime doesn't support delay directly; skip for v1
	anim.start(id)
}

// drive_keyframes starts @keyframes animations on entry.
fn drive_keyframes(current Element, had_prev bool) {
	if !had_prev {
		mut baseline := map[string]bool{}
		collect_matches(current, mut baseline)
		g_style_prev_anim_matches = baseline.clone()
		return
	}
	old_matches := g_style_prev_anim_matches.clone()
	mut new_matches := map[string]bool{}
	walk_for_keyframes(current, []Stylesheet{}, old_matches, mut new_matches)
	g_style_prev_anim_matches = new_matches.clone()
}

fn collect_matches(current Element, mut out map[string]bool) {
	if current.id.len > 0 {
		for anim in current.style_animations {
			if anim.name.len > 0 {
				out[current.id + '\x00' + anim.name] = true
			}
		}
	}
	for child in current.children {
		collect_matches(child, mut out)
	}
}

fn walk_for_keyframes(current Element, ancestor_sheets []Stylesheet, old_matches map[string]bool, mut new_matches map[string]bool) {
	mut sheets := ancestor_sheets.clone()
	if !stylesheet_is_empty(current.stylesheet) {
		sheets << current.stylesheet
	}
	if current.id.len > 0 && current.style_animations.len > 0 {
		for anim in current.style_animations {
			if anim.name.len == 0 {
				continue
			}
			key := current.id + '\x00' + anim.name
			new_matches[key] = true
			if !(old_matches[key] or { false }) {
				// newly matching: start
				if kf := find_keyframes(sheets, anim.name) {
					start_keyframes(current.id, kf, anim)
				}
			}
		}
	}
	for child in current.children {
		walk_for_keyframes(child, sheets, old_matches, mut new_matches)
	}
}

fn find_keyframes(sheets []Stylesheet, name string) ?StyleKeyframes {
	for i := sheets.len - 1; i >= 0; i-- {
		if kf := sheets[i].keyframes[name] {
			return kf
		}
	}
	if g_stylesheet_has_global {
		if kf := g_stylesheet_global.keyframes[name] {
			return kf
		}
	}
	return none
}

fn start_keyframes(id string, kf StyleKeyframes, spec StyleAnimation) {
	// Build an Animation as a sequence of tweens between stops.
	mut children := []Animation{}
	mut prev_stop := 0.0
	// We need start values; runtime captures from declared element on first frame.
	for i in 1 .. kf.stops.len {
		prev := kf.stops[i - 1]
		cur := kf.stops[i]
		mut targets := []AnimationProperty{}
		for decl in cur.declarations {
			ap := css_anim_property(decl.prop)
			if ap == '' {
				continue
			}
			if !is_animatable_property(ap, .number) && !is_animatable_property(ap, .color) {
				continue
			}
			if is_animatable_property(ap, .color) {
				if token := component_theme_token(decl.value) {
					targets << animation_color_property(ap, token.over(0xffffff))
				}
				continue
			}
			val := decl.value.f64()
			targets << animation_number_property(ap, val)
		}
		dur := spec.duration * (cur.stop - prev.stop)
		if dur <= 0 {
			continue
		}
		child := animation(AnimationConfig{
			duration:      dur
			transition:    spec.timing
			transition_fn: spec.timing_fn
			properties:    targets
		})
		children << child
		prev_stop = cur.stop
	}
	mut anim := Animation{}
	if children.len == 1 {
		anim = children[0]
		anim.delay = spec.delay
		anim.fill_mode = spec.fill_mode
		anim.transition_fn = spec.timing_fn
	} else {
		anim = Animation{
			duration:      spec.duration
			delay:         spec.delay
			transition:    spec.timing
			transition_fn: spec.timing_fn
			fill_mode:     spec.fill_mode
			repeat:        spec.iteration_count == 0
			kind:          .sequence
			children:      children
			properties:    collect_animation_properties(children)
		}
	}
	if spec.iteration_count == 0 {
		anim.repeat = true
	}
	anim.start(id)
}

fn collect_animation_properties(children []Animation) []string {
	mut out := []string{}
	for c in children {
		for p in c.properties {
			if p !in out {
				out << p
			}
			for pp in c.animated_properties() {
				if pp !in out {
					out << pp
				}
			}
		}
	}
	return out
}
