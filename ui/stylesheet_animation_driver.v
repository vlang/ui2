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
		drive_transitions(g_style_prev_elements, current)
	}
	drive_keyframes(current, had_prev)
	g_style_prev_elements = new_elements.clone()
	g_style_prev_valid = true
}

// drive_transitions walks old and current in parallel by id and starts a
// tween for every transitioned property whose resolved value changed.
fn drive_transitions(old map[string]Element, current Element) {
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
	if current.id.len > 0 {
		if old_el := old_by_id[current.id] {
			if current.style_transitions.len > 0 {
				mut entries := []TransitionEntry{}
				for tr in current.style_transitions {
					targets := changed_transition_targets(old_el, current, tr)
					if targets.len > 0 {
						entries << TransitionEntry{ targets: targets, spec: tr }
					}
				}
				if entries.len == 1 {
					start_transition(current.id, old_el, entries[0].targets, entries[0].spec)
				} else if entries.len > 1 {
					start_parallel_transitions(current.id, old_el, entries)
				}
			}
		}
	}
	for child in current.children {
		walk_for_transitions(child, old_by_id)
	}
}

// TransitionEntry is one shorthand entry's changed targets plus its timing.
struct TransitionEntry {
	targets []AnimationProperty
	spec    StyleTransition
}

// changed_transition_targets diffs old vs current for one transition entry,
// returning the tween targets for every covered animatable property whose
// resolved value changed.
fn changed_transition_targets(old_el Element, current Element, tr StyleTransition) []AnimationProperty {
	mut targets := []AnimationProperty{}
	props := if tr.properties.len == 0 || (tr.properties.len == 1 && tr.properties[0] == 'all') {
		all_animatable_properties()
	} else {
		tr.properties.clone()
	}
	for p in props {
		for ap in css_anim_properties(p) {
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
					targets << animation_number_property(ap, new_val_num)
				}
			} else {
				if old_val_col != new_val_col {
					targets << animation_color_property(ap, new_val_col)
				}
			}
		}
	}
	return targets
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

// css_anim_property kept for single-property callers (returns first).
fn css_anim_property(name string) string {
	props := css_anim_properties(name)
	if props.len > 0 {
		return props[0]
	}
	return ''
}

fn all_animatable_properties() []string {
	// A conservative subset of commonly transitioned properties.
	return ['x', 'y', 'width', 'height', 'rotation', 'background', 'corner_radius', 'text_color',
		'font_size', 'box.opacity', 'box.border_color', 'box.border_left', 'box.border_top',
		'box.border_right', 'box.border_bottom', 'box.shadow.opacity', 'box.shadow.blur', 'box.shadow.x',
		'box.shadow.y', 'padding_left']
}

fn start_transition(id string, old_el Element, targets []AnimationProperty, tr StyleTransition) {
	seed_transition_run(id, old_el)
	// Transitions overlay the declared end value, which the cascade already
	// provides, so release the run on completion instead of retaining it.
	mut anim := animation(AnimationConfig{
		duration:      tr.duration
		delay:         tr.delay
		transition:    tr.timing
		transition_fn: tr.timing_fn
		fill_mode:     'none'
		properties:    targets
	})
	anim.start(id)
}

// start_parallel_transitions runs several changed shorthand entries
// concurrently: one tween child per entry under a .parallel parent, so the
// second entry no longer replaces the first. The parent lives as long as
// the slowest child.
fn start_parallel_transitions(id string, old_el Element, entries []TransitionEntry) {
	seed_transition_run(id, old_el)
	mut children := []Animation{}
	mut slowest := 0.0
	for entry in entries {
		tr := entry.spec
		children << animation(AnimationConfig{
			duration:      tr.duration
			delay:         tr.delay
			transition:    tr.timing
			transition_fn: tr.timing_fn
			fill_mode:     'none'
			properties:    entry.targets
		})
		if tr.duration + tr.delay > slowest {
			slowest = tr.duration + tr.delay
		}
	}
	anim := Animation{
		duration:   slowest
		fill_mode:  'none'
		kind:       .parallel
		children:   children
		properties: collect_animation_properties(children)
	}
	anim.start(id)
}

// seed_transition_run records the previous displayed element so the runtime
// captures it as the tween's start: start() sees previous.initialized==true
// and uses previous.last (old_el) as the tween's start, animating old -> new.
// Without the seed, a first transition would start at the new value (zero distance).
fn seed_transition_run(id string, old_el Element) {
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
}

// drive_keyframes starts @keyframes animations on entry: any (id, name)
// pair matching the current tree that did not match the previous frame
// starts. The first styled frame counts as entry for everything it matches,
// so animations present at load play instead of waiting for a rematch.
fn drive_keyframes(current Element, had_prev bool) {
	mut old_matches := map[string]bool{}
	if had_prev {
		old_matches = g_style_prev_anim_matches.clone()
	}
	mut new_matches := map[string]bool{}
	walk_for_keyframes(current, []Stylesheet{}, old_matches, mut new_matches)
	g_style_prev_anim_matches = new_matches.clone()
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
			if anim.play_state == 'paused' {
				cancel_animation(current.id)
				continue
			}
			if !(old_matches[key] or { false }) {
				// newly matching: start
				if kf := find_keyframes(sheets, anim.name) {
					start_keyframes(current.id, sheets, kf, anim)
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

fn start_keyframes(id string, sheets []Stylesheet, kf StyleKeyframes, spec StyleAnimation) {
	// Build an Animation as a sequence of tweens between stops.
	// We need start values; runtime captures from declared element on first frame.
	mut base := []Animation{}
	for i in 1 .. kf.stops.len {
		prev := kf.stops[i - 1]
		cur := kf.stops[i]
		targets := keyframe_targets(sheets, cur)
		dur := spec.duration * (cur.stop - prev.stop)
		if dur <= 0 || targets.len == 0 {
			continue
		}
		base << animation(AnimationConfig{
			duration:      dur
			transition:    spec.timing
			transition_fn: spec.timing_fn
			properties:    targets
		})
	}
	if base.len == 0 {
		// No animatable stops (zero duration, a single stop, or values that
		// do not resolve): starting an empty Animation would replace and
		// cancel the element's in-flight run, so do nothing.
		return
	}
	mut children := base.clone()
	if spec.iteration_count > 1 && spec.iteration_count <= max_keyframes_unroll {
		// Finite counts are unrolled: the runtime only repeats forever.
		// Counts above the cap degrade to infinite (see repeat below)
		// instead of allocating millions of tweens.
		for _ in 1 .. int(spec.iteration_count) {
			children << base
		}
	}
	mut total := 0.0
	for child in children {
		total += child.duration
	}
	mut anim := Animation{}
	if children.len == 1 && spec.iteration_count <= 1 {
		anim = children[0]
		anim.delay = spec.delay
		anim.fill_mode = spec.fill_mode
		anim.transition_fn = spec.timing_fn
	} else {
		anim = Animation{
			duration:      total
			delay:         spec.delay
			transition:    spec.timing
			transition_fn: spec.timing_fn
			fill_mode:     spec.fill_mode
			repeat:        spec.iteration_count == 0 || spec.iteration_count > max_keyframes_unroll
			kind:          .sequence
			children:      children
			properties:    collect_animation_properties(children)
		}
	}
	anim.start(id)
}

// max_keyframes_unroll caps finite iteration-count unrolling; larger counts
// repeat forever instead of allocating one tween per iteration.
const max_keyframes_unroll = 256

// keyframe_targets resolves one stop's declarations to tween targets.
// Colors resolve through the theme token parser; `@variable` references
// resolve against the keyframes' own sheet scope (then the global sheet).
// Anything else that does not resolve is skipped, never zeroed.
fn keyframe_targets(sheets []Stylesheet, stop StyleKeyframe) []AnimationProperty {
	mut targets := []AnimationProperty{}
	for decl in stop.declarations {
		ap := css_anim_property(decl.prop)
		if !is_animatable_property(ap, .number) && !is_animatable_property(ap, .color) {
			continue
		}
		if is_animatable_property(ap, .color) {
			if token := keyframe_color_token(sheets, decl.value) {
				targets << animation_color_property(ap, token.over(0xffffff))
			}
			continue
		}
		if val := parse_keyframe_number(decl.value) {
			targets << animation_number_property(ap, val)
		}
	}
	return targets
}

// keyframe_color_token resolves a keyframe color: a `@variable` first,
// otherwise a literal theme color.
fn keyframe_color_token(sheets []Stylesheet, raw string) ?ComponentThemeToken {
	t := raw.trim_space()
	if t.starts_with('@') {
		if v := keyframes_var_value(sheets, t) {
			if token := component_theme_token(v) {
				return token
			}
		}
		return none
	}
	if token := component_theme_token(t) {
		return token
	}
	return none
}

// keyframes_var_value looks a `@name` up in the keyframes' sheet scope,
// innermost first, then the global sheet. The cascade resolves the same way
// for ordinary declarations.
fn keyframes_var_value(sheets []Stylesheet, name string) ?string {
	dark := stylesheet_dark_mode()
	for i := sheets.len - 1; i >= 0; i-- {
		if v := sheets[i].resolve_var(name, dark) {
			return v
		}
	}
	if g_stylesheet_has_global {
		if v := g_stylesheet_global.resolve_var(name, dark) {
			return v
		}
	}
	return none
}

// parse_keyframe_number parses a plain number with an optional unit suffix
// (`8px`, `50%`, `.5`). Non-numeric values return none so typos never tween
// to zero.
fn parse_keyframe_number(raw string) ?f64 {
	t := raw.trim_space()
	if t.len == 0 {
		return none
	}
	mut end := t.len
	for end > 0 {
		c := t[end - 1]
		if (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`) || c == `%` {
			end--
		} else {
			break
		}
	}
	num := t[..end].trim_space()
	if num.len == 0 {
		return none
	}
	c0 := num[0]
	if !(c0 >= `0` && c0 <= `9`) && c0 != `+` && c0 != `-` && c0 != `.` {
		return none
	}
	return num.f64()
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
