module ui2

import math
import strconv

fn v_adaptive_number(node &VNode, key string, fallback f64) !f64 {
	raw := node.prop(key)
	if raw.len == 0 {
		return fallback
	}
	value := strconv.atof64(raw) or {
		return error('`${key}` on `${node.id}` must be a plain number')
	}
	if math.is_nan(value) || math.is_inf(value, 0) {
		return error('`${key}` must be finite')
	}
	return value
}

fn v_adaptive_axis(raw string) !AdaptiveAxis {
	return match raw {
		'start' { AdaptiveAxis.start }
		'end' { AdaptiveAxis.end }
		'center' { AdaptiveAxis.center }
		'stretch' { AdaptiveAxis.stretch }
		else { return error('layout axis must be start, end, center or stretch; got `${raw}`') }
	}
}

fn v_adaptive_class(raw string) !AdaptiveSizeClass {
	return match raw {
		'any' { AdaptiveSizeClass.any }
		'compact' { AdaptiveSizeClass.compact }
		'regular' { AdaptiveSizeClass.regular }
		else { return error('size class must be any, compact or regular; got `${raw}`') }
	}
}

fn v_adaptive_layout_with_defaults(node &VNode, base AdaptiveLayout) !AdaptiveLayout {
	hidden := node.prop_or('hidden', base.hidden.str())
	if hidden !in ['true', 'false'] {
		return error('`hidden` must be true or false')
	}
	layout := AdaptiveLayout{
		horizontal: v_adaptive_axis(node.prop_or('layout_x', base.horizontal.str()))!
		vertical:   v_adaptive_axis(node.prop_or('layout_y', base.vertical.str()))!
		min_width:  v_adaptive_number(node, 'layout_min_width', base.min_width)!
		max_width:  v_adaptive_number(node, 'layout_max_width', base.max_width)!
		min_height: v_adaptive_number(node, 'layout_min_height', base.min_height)!
		max_height: v_adaptive_number(node, 'layout_max_height', base.max_height)!
		hidden:     hidden == 'true'
	}
	validate_adaptive_layout(layout)!
	return layout
}

// The IDE and the runtime read the same declarative rules.
pub fn adaptive_layout_from_vnode(node &VNode) !AdaptiveLayout {
	return v_adaptive_layout_with_defaults(node, AdaptiveLayout{})!
}

pub fn adaptive_variations_from_vnode(node &VNode) ![]AdaptiveLayoutVariation {
	base := adaptive_layout_from_vnode(node)!
	mut variations := []AdaptiveLayoutVariation{}
	mut selectors := map[string]bool{}
	for child in node.children {
		if child.tag != 'LayoutVariation' {
			continue
		}
		if child.children.len > 0 {
			return error('LayoutVariation cannot contain child controls')
		}
		for key, _ in child.props {
			if key !in ['width_class', 'height_class', 'reference_width', 'reference_height', 'x',
				'y', 'width', 'height', 'layout_x', 'layout_y', 'layout_min_width', 'layout_max_width',
				'layout_min_height', 'layout_max_height', 'hidden'] {
				return error('unsupported LayoutVariation property `${key}`')
			}
		}
		width_class := v_adaptive_class(child.prop_or('width_class', 'any'))!
		height_class := v_adaptive_class(child.prop_or('height_class', 'any'))!
		if width_class == .any && height_class == .any {
			return error('Any/Any is the base layout, not a LayoutVariation')
		}
		selector := '${width_class}/${height_class}'
		if selector in selectors {
			return error('duplicate LayoutVariation `${selector}` on `${node.id}`')
		}
		selectors[selector] = true
		for key in ['reference_width', 'reference_height', 'x', 'y', 'width', 'height'] {
			if child.prop(key).len == 0 {
				return error('LayoutVariation requires `${key}`')
			}
		}
		reference_width := v_adaptive_number(child, 'reference_width', 0)!
		reference_height := v_adaptive_number(child, 'reference_height', 0)!
		width := v_adaptive_number(child, 'width', 0)!
		height := v_adaptive_number(child, 'height', 0)!
		if reference_width <= 0 || reference_height <= 0 || width < 0 || height < 0 {
			return error('LayoutVariation needs a positive reference canvas and non-negative control size')
		}
		variations << AdaptiveLayoutVariation{
			width_class:      width_class
			height_class:     height_class
			frame:            rect(v_adaptive_number(child, 'x', 0)!,
				v_adaptive_number(child, 'y', 0)!, width, height)
			reference_width:  reference_width
			reference_height: reference_height
			layout:           v_adaptive_layout_with_defaults(child, base)!
		}
	}
	return variations
}

// Return a new node, leaving the parsed document untouched for the next resize.
fn v_adaptive_child(node &VNode, reference_width f64, reference_height f64, available Rect, width_class AdaptiveSizeClass, height_class AdaptiveSizeClass) !&VNode {
	mut layout := adaptive_layout_from_vnode(node)!
	// Missing dimensions describe the saved canvas, not the current viewport.
	// The resolver applies the viewport delta exactly once.
	mut design := rect(v_adaptive_number(node, 'x', 0)!, v_adaptive_number(node, 'y', 0)!, v_adaptive_number(node,
		'width', reference_width)!, v_adaptive_number(node, 'height', reference_height)!)
	if design.width < 0 || design.height < 0 {
		return error('adaptive control dimensions must be non-negative')
	}
	mut rw := reference_width
	mut rh := reference_height
	variations := adaptive_variations_from_vnode(node)!
	index := adaptive_variation_index(variations, width_class, height_class)
	if index >= 0 {
		variation := variations[index]
		design = variation.frame
		rw = variation.reference_width
		rh = variation.reference_height
		layout = variation.layout
	}
	resolved := adaptive_layout_frame(design, rw, rh, available, layout)
	mut props := node.props.clone()
	props['x'] = resolved.x.str()
	props['y'] = resolved.y.str()
	props['width'] = resolved.width.str()
	props['height'] = resolved.height.str()
	props['hidden'] = layout.hidden.str()
	return &VNode{
		...node
		props:    props
		children: node.children.filter(it.tag != 'LayoutVariation')
	}
}

fn v_adaptive_children(node &VNode, available Rect) ![]Element {
	rw := v_adaptive_number(node, 'width', 0)!
	rh := v_adaptive_number(node, 'height', 0)!
	bw := v_adaptive_number(node, 'layout_breakpoint_width', 600)!
	bh := v_adaptive_number(node, 'layout_breakpoint_height', 600)!
	if rw <= 0 || rh <= 0 || bw <= 0 || bh <= 0 {
		return error('adaptive Screen needs positive design dimensions and size-class breakpoints')
	}
	wc := adaptive_size_class(available.width, bw)
	hc := adaptive_size_class(available.height, bh)
	mut children := []Element{}
	for child in node.children {
		if child.tag in ['MenuItem', 'Option'] {
			continue
		}
		if child.tag == 'LayoutVariation' {
			return error('LayoutVariation belongs to a control, not Screen')
		}
		resolved := v_adaptive_child(child, rw, rh, available, wc, hc)!
		children << node_to_element(resolved, available)!
	}
	return children
}
