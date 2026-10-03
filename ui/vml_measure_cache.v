module ui2

import math

// VLayoutMeasureCache reuses intrinsic sizes within one VML construction.
// Each Flex level measures a subtree before and after assigning its width, and
// nested levels repeat that, so identical requests multiply with depth. A cache
// lives for one build and is then dropped: nothing needs invalidating, and any
// change of content or constraints inside the build is a different key.
//
// Keys are structural rather than node paths. Repeater items share a path, and
// expressions that read an ancestor's size resolve the same source node to
// different content during measurement and evaluation.
@[heap]
struct VLayoutMeasureCache {
mut:
	shapes    map[voidptr]VMeasureShape
	shape_ids map[string]int
	preferred map[string]Rect
	// computed counts preferred-size measurements that missed the cache.
	computed int
	// nesting counts container measurements in progress.
	nesting int
}

struct VMeasureShape {
	// Holding the node keeps its address from being reused during the build.
	node &VNode
	id   int
}

// shape interns a node's measurement inputs: tag, id, resolved properties and
// children. Children are interned first, so each node costs only its own data.
fn (mut cache VLayoutMeasureCache) shape(node &VNode) int {
	if known := cache.shapes[voidptr(node)] {
		return known.id
	}
	mut key := []string{cap: node.props.len * 2 + node.children.len + 2}
	key << '${node.tag.len}:${node.tag}${node.id.len}:${node.id}'
	for name, value in node.props {
		key << '${name.len}:${name}${value.len}:${value}'
	}
	key << '|'
	for child in node.children {
		key << cache.shape(child).str()
	}
	canonical := key.join(',')
	id := cache.shape_ids[canonical] or {
		next := cache.shape_ids.len
		cache.shape_ids[canonical] = next
		next
	}
	cache.shapes[voidptr(node)] = VMeasureShape{
		node: unsafe { node }
		id:   id
	}
	return id
}

fn (mut cache VLayoutMeasureCache) preferred_key(node &VNode, probe Rect, depends_on_probe bool) string {
	shape := cache.shape(node)
	if !depends_on_probe {
		return shape.str()
	}
	return '${shape}:${math.f64_bits(probe.width)}:${math.f64_bits(probe.height)}'
}
