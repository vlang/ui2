module ui2

// Flex is an opt-in layout. Declared dimensions are preferred sizes; its parent
// owns the final frame. Existing Row/Column/BoxLayout documents keep their rules.
fn v_flex_config(node &VNode, frame Rect, children []FlexLayoutChild) !FlexLayoutConfig {
	padding := node.prop_or('padding', '0').f64()
	return FlexLayoutConfig{
		id:          node.id
		frame:       frame
		box:         v_box(node)
		orientation: box_orientation(node.prop_or('orientation', 'horizontal'))!
		padding:     BoxPadding{
			left:   node.prop_or('padding_left', padding.str()).f64()
			top:    node.prop_or('padding_top', padding.str()).f64()
			right:  node.prop_or('padding_right', padding.str()).f64()
			bottom: node.prop_or('padding_bottom', padding.str()).f64()
		}
		gap:         node.prop_or('gap', '0').f64()
		line_gap:    node.prop_or('line_gap', '-1').f64()
		wrap:        node.prop_bool('wrap')
		justify:     flex_justify(node.prop_or('justify', 'start'))!
		align:       flex_alignment(node.prop_or('align_items', 'stretch'))!
		children:    children
	}
}

fn v_flex_child(node &VNode, preferred Rect) !FlexLayoutChild {
	return FlexLayoutChild{
		element:        Element{ frame: preferred }
		basis:          node.prop_or('flex_basis', '-1').f64()
		grow:           node.prop_or('flex_grow', '0').f64()
		shrink:         node.prop_or('flex_shrink', '1').f64()
		minimum_width:  node.prop_or('min_width', '0').f64()
		minimum_height: node.prop_or('min_height', '0').f64()
		maximum_width:  node.prop_or('max_width', '-1').f64()
		maximum_height: node.prop_or('max_height', '-1').f64()
		align_self:     flex_alignment(node.prop_or('align_self', 'auto'))!
	}
}

fn v_flex_items(node &VNode, available Rect, mut cache VLayoutMeasureCache) ![]FlexLayoutChild {
	mut items := []FlexLayoutChild{}
	for child in node.children {
		if !v_is_layout_metadata(child) {
			items << v_flex_child(child, v_layout_preferred(child, available, mut cache)!)!
		}
	}
	return items
}

fn v_layout_preferred(node &VNode, available Rect, mut cache VLayoutMeasureCache) !Rect {
	width := v_dimension(node, 'width', -1)
	height := v_dimension(node, 'height', -1)
	probe := rect(0, 0, if width >= 0 { width } else { available.width }, if height >= 0 {
		height
	} else {
		available.height
	})
	if width >= 0 && height >= 0 {
		return probe
	}
	container := node.tag in ['FlexLayout', 'GridLayout']
	// Only measurements inside another container's measurement repeat. Keying
	// the direct children of a single Flex would cost more than it could save.
	if !container && cache.nesting == 0 {
		return v_layout_leaf_preferred(node, width, height)!
	}
	// A leaf reads only its declared dimensions, so the probe is not part of it.
	key := cache.preferred_key(node, probe, container)
	if cached := cache.preferred[key] {
		return cached
	}
	cache.computed++
	if !container {
		result := v_layout_leaf_preferred(node, width, height)!
		cache.preferred[key] = result
		return result
	}
	cache.nesting++
	defer {
		cache.nesting--
	}
	mut preferred := Rect{}
	if node.tag == 'FlexLayout' {
		config := v_flex_config(node, probe, []FlexLayoutChild{})!
		inner := rect(0, 0, box_max(0, probe.width - config.padding.left - config.padding.right),
			box_max(0, probe.height - config.padding.top - config.padding.bottom))
		initial := v_flex_items(node, inner, mut cache)!
		frames_before_measure := flex_layout_frames(FlexLayoutConfig{ ...config, children: initial })!
		items := v_flex_remeasure_plain(node, config, initial, frames_before_measure, mut cache)!
		preferred = flex_layout_preferred_size(FlexLayoutConfig{ ...config, children: items })!
		if config.wrap && config.orientation == .horizontal {
			frames := flex_layout_frames(FlexLayoutConfig{ ...config, frame: rect(0, 0, probe.width, 0), children: items })!
			mut bottom := config.padding.top
			for frame in frames {
				bottom = box_max(bottom, frame.y + frame.height)
			}
			preferred = rect(0, 0, preferred.width, bottom + config.padding.bottom)
		}
	} else if node.tag == 'GridLayout' {
		mut sizes := []Rect{}
		mut spans := []GridSpan{}
		mut visible := []&VNode{}
		for child in node.children {
			if !v_is_layout_metadata(child) {
				sizes << v_layout_preferred(child, probe, mut cache)!
				spans << v_grid_span(child)
				visible << child
			}
		}
		config := v_grid_config(node, probe)!
		spanned := GridLayoutConfig{ ...config, child_spans: spans }
		initial := grid_layout_preferred_size(spanned, sizes)!
		// Grid row heights also depend on the width of each assigned cell. Use
		// its natural height for this width-only probe so padding/gaps fit even
		// when the parent's available height is zero during measurement.
		cells := grid_layout_frames(GridLayoutConfig{ ...spanned, frame: rect(0, 0, probe.width, initial.height) }, sizes.len)!
		for index, child in visible {
			if v_dimension(child, 'height', -1) >= 0 { continue }
			measured := v_layout_preferred(v_layout_node_width(child, cells[index].width),
				rect(0, 0, cells[index].width, probe.height), mut cache)!
			sizes[index] = rect(0, 0, sizes[index].width, measured.height)
		}
		preferred = grid_layout_preferred_size(spanned, sizes)!
	}
	result := v_layout_declared_or(width, height, preferred)
	cache.preferred[key] = result
	return result
}

// Leaf measurement uses the renderer's font metrics, keeping text in its
// existing point units. Other container types keep declared geometry.
fn v_layout_leaf_preferred(node &VNode, width f64, height f64) !Rect {
	el := node_to_element(node, rect(0, 0, box_max(0, width), box_max(0, height)))!
	measured := measure_layout_element(el, LayoutConstraints{}, measure_layout_text)!
	return v_layout_declared_or(width, height, rect(0, 0, measured.width, measured.height))
}

fn v_layout_declared_or(width f64, height f64, preferred Rect) Rect {
	return rect(0, 0, if width >= 0 { width } else { preferred.width }, if height >= 0 {
		height
	} else {
		preferred.height
	})
}

fn v_layout_node_at(node &VNode, frame Rect) &VNode {
	mut placed := &VNode{ ...node, props: node.props.clone() }
	placed.props['x'] = frame.x.str()
	placed.props['y'] = frame.y.str()
	placed.props['width'] = frame.width.str()
	placed.props['height'] = frame.height.str()
	return placed
}

fn v_layout_node_width(node &VNode, width f64) &VNode {
	mut assigned := &VNode{ ...node, props: node.props.clone(), expressions: node.expressions.clone() }
	assigned.props['width'] = width.str()
	assigned.expressions['width'] = &VExpression{ kind: .literal, value: width.str(), line: node.line }
	return assigned
}

fn v_flex_remeasure_plain(node &VNode, config FlexLayoutConfig, initial []FlexLayoutChild, frames []Rect, mut cache VLayoutMeasureCache) ![]FlexLayoutChild {
	mut children := initial.clone()
	mut index := 0
	for node_child in node.children {
		if v_is_layout_metadata(node_child) { continue }
		if v_dimension(node_child, 'height', -1) < 0 {
			available := rect(0, 0, frames[index].width, config.frame.height)
			preferred := v_layout_preferred(v_layout_node_width(node_child, frames[index].width), available, mut
				cache)!
			child := children[index]
			children[index] = FlexLayoutChild{
				...child
				element: Element{
					...child.element
					frame: rect(0, 0, child.element.frame.width, preferred.height)
				}
			}
		}
		index++
	}
	return children
}

fn v_flex(node &VNode, frame Rect) !Element {
	if node.prop_bool('__layout_resolved') {
		return view(node.id, frame, v_box(node), v_children(node, rect(0, 0, frame.width, frame.height))!)
	}
	config := v_flex_config(node, rect(0, 0, frame.width, frame.height), []FlexLayoutChild{})!
	inner := rect(0, 0, box_max(0, frame.width - config.padding.left - config.padding.right),
		box_max(0, frame.height - config.padding.top - config.padding.bottom))
	// Static documents convert each nested Flex separately; one cache per Flex
	// still shares the repeated subtree measurements below it.
	mut cache := VLayoutMeasureCache{}
	initial := v_flex_items(node, inner, mut cache)!
	first := flex_layout_frames(FlexLayoutConfig{ ...config, children: initial })!
	children_at_width := v_flex_remeasure_plain(node, config, initial, first, mut cache)!
	frames := flex_layout_frames(FlexLayoutConfig{ ...config, children: children_at_width })!
	mut children := []Element{}
	mut index := 0
	for child in node.children {
		if v_is_layout_metadata(child) { continue }
		children << node_to_element(v_layout_node_at(child, frames[index]), frames[index])!
		index++
	}
	return view(node.id, frame, v_box(node), children)
}

fn v_grid_span(node &VNode) GridSpan {
	return GridSpan{
		column_span: node.prop_or('column_span', '1').int()
		row_span:    node.prop_or('row_span', '1').int()
	}
}
