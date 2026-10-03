module ui2

fn v_modern_child_metric(parent &VNode, child &VNode, scope map[string]VValue, actual Rect, box bool, floating bool, mut cache VLayoutMeasureCache) !VLayoutChildMetrics {
	if parent.tag == 'FlexLayout' {
		// Evaluate sizing and content without registering events. The actual pass
		// below resolves actions/bindings exactly once, with the allocated frame.
		parent_props := v_measurement_node(parent, scope, actual, false)!
		config := v_flex_config(parent_props, actual, []FlexLayoutChild{})!
		available := rect(0, 0, box_max(0, actual.width - config.padding.left - config.padding.right),
			box_max(0, actual.height - config.padding.top - config.padding.bottom))
		measured := v_measurement_node(child, scope, available, true)!
		preferred := v_layout_preferred(measured, available, mut cache)!
		return VLayoutChildMetrics{
			frame:  preferred
			flex:   v_flex_child(measured, preferred)!
			source: &VNode{ ...child }
			scope:  scope.clone()
		}
	}
	metric := v_layout_child_metric(child, scope, box, floating)!
	if parent.tag == 'GridLayout' {
		return VLayoutChildMetrics{
			...metric
			span: GridSpan{
				column_span: int(v_layout_dimension(child, 'column_span', scope, 1)!)
				row_span:    int(v_layout_dimension(child, 'row_span', scope, 1)!)
			}
		}
	}
	return metric
}

// Main-axis distribution can change the width available to wrapping content.
// Measure auto heights once at that assigned width, keeping horizontal bases
// intact. Vertical layouts then distribute their updated intrinsic heights.
fn v_flex_remeasure_metrics(config FlexLayoutConfig, metrics []VLayoutChildMetrics, frames []Rect, mut cache VLayoutMeasureCache) ![]FlexLayoutChild {
	mut children := config.children.clone()
	for index, metric in metrics {
		if metric.source == unsafe { nil } { continue }
		available := rect(0, 0, frames[index].width, config.frame.height)
		assigned := v_layout_node_width(metric.source, frames[index].width)
		measured := v_measurement_node(assigned, metric.scope, available, true)!
		if v_dimension(measured, 'height', -1) >= 0 { continue }
		preferred := v_layout_preferred(measured, available, mut cache)!
		child := children[index]
		children[index] = FlexLayoutChild{
			...child
			element: Element{
				...child.element
				frame: rect(0, 0, child.element.frame.width, preferred.height)
			}
		}
	}
	return children
}

fn v_eval_layout_child(node &VNode, scope map[string]VValue, frame Rect, kind VChildLayoutKind, mut evaluation VmlEvaluation) !&VNode {
	if kind !in [.flex, .grid] || v_is_layout_metadata(node) || node.tag == 'Option' {
		return v_eval_node(node, scope, frame, mut evaluation)!
	}
	mut assigned := &VNode{ ...node, expressions: node.expressions.clone() }
	for key, value in {
		'x':      frame.x
		'y':      frame.y
		'width':  frame.width
		'height': frame.height
	} {
		assigned.expressions[key] = &VExpression{ kind: .literal, value: value.str(), line: node.line }
	}
	return v_eval_node(assigned, scope, frame, mut evaluation)!
}

fn v_eval_adaptive_child(parent &VNode, child &VNode, scope map[string]VValue, available Rect, mut evaluation VmlEvaluation) !&VNode {
	if child.tag in ['MenuItem', 'Option'] {
		return v_eval_node(child, scope, available, mut evaluation)!
	}
	if child.tag == 'LayoutVariation' {
		return error('LayoutVariation belongs to a control, not Screen')
	}
	rw := v_adaptive_number(parent, 'width', 0)!
	rh := v_adaptive_number(parent, 'height', 0)!
	bw := v_adaptive_number(parent, 'layout_breakpoint_width', 600)!
	bh := v_adaptive_number(parent, 'layout_breakpoint_height', 600)!
	v_validate_adaptive_screen(parent)!
	measured := v_measurement_node(child, scope, available, true)!
	adapted := v_adaptive_child(measured, rw, rh, available,
		adaptive_size_class(available.width, bw), adaptive_size_class(available.height, bh))!
	mut assigned := &VNode{ ...child, expressions: child.expressions.clone() }
	assigned.expressions['hidden'] = &VExpression{ kind: .literal, value: adapted.prop('hidden'), line: child.line }
	// Adapt before evaluation so descendants and actions see the actual frame.
	return v_eval_layout_child(assigned, scope, v_frame(adapted, available), .flex, mut evaluation)!
}

fn v_validate_adaptive_screen(parent &VNode) ! {
	for key in ['width', 'height', 'layout_breakpoint_width', 'layout_breakpoint_height'] {
		fallback := if key.starts_with('layout_') { 600.0 } else { 0.0 }
		if v_adaptive_number(parent, key, fallback)! <= 0 {
			return error('adaptive Screen needs positive design dimensions and size-class breakpoints')
		}
	}
}

// Resolve only the declarative properties needed for measurement. In particular
// this pass must not register bindings, assign identities, or invoke actions.
fn v_measurement_node(node &VNode, incoming_scope map[string]VValue, available Rect, descend bool) !&VNode {
	mut scope := map[string]VValue{}
	for name, value in incoming_scope {
		scope[name] = value
	}
	mut resolved := &VNode{ ...node, props: node.props.clone(), children: []&VNode{} }
	if node.id.len > 0 {
		scope[node.id] = v_object({
			'x':      v_number(0, '0')
			'y':      v_number(0, '0')
			'width':  v_number(available.width, available.width.str())
			'height': v_number(available.height, available.height.str())
		})
	}
	for key in node.property_order {
		expr := node.expressions[key] or { continue }
		value := v_eval(expr, scope)!
		resolved.props[key] = value.string_value()
		if node.id.len > 0 {
			mut object := scope[node.id] or { return error('missing measurement scope for `${node.id}`') }
			object.fields[key] = value
			scope[node.id] = object
		}
	}
	for key, expr in node.expressions {
		if key == 'id' || key in node.property_types || key.starts_with('on_') { continue }
		property := if key.starts_with('bind.') { key.all_after('bind.') } else { key }
		resolved.props[property] = v_eval(expr, scope)!.string_value()
	}
	actual := v_frame(resolved, available)
	if node.id.len > 0 {
		mut object := scope[node.id] or { return error('missing measurement scope for `${node.id}`') }
		object.fields['width'] = v_number(actual.width, actual.width.str())
		object.fields['height'] = v_number(actual.height, actual.height.str())
		scope[node.id] = object
	}
	if !descend { return resolved }
	for child in node.children {
		if child.tag != 'Repeater' {
			resolved.children << v_measurement_node(child, scope, actual, true)!
			continue
		}
		expr := child.expressions['model'] or { return error('Repeater requires `model` at line ${child.line}') }
		items := v_eval(expr, scope)!
		if items.kind != .list {
			return error('Repeater model must be a collection at line ${expr.line}')
		}
		for index, item in items.items {
			mut item_scope := scope.clone()
			item_scope['item'] = item
			item_scope['index'] = v_number(index, index.str())
			for repeated in child.children {
				resolved.children << v_measurement_node(repeated, item_scope, actual, true)!
			}
		}
	}
	return resolved
}
