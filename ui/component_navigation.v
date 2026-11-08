module ui2

import math

pub struct BreadcrumbItem {
pub:
	id        string // Stable key; also the default action, not the element id.
	label     string
	action_id string
	enabled   bool = true
}

pub struct BreadcrumbConfig {
pub:
	id        string
	frame     Rect
	items     []BreadcrumbItem
	enabled   bool          = true
	separator string        = '/'
	size      ComponentSize = .medium
	theme     ComponentTheme
}

// breadcrumb treats its last item as the current location. Earlier items are
// native buttons with stable identities and application-owned navigation.
pub fn breadcrumb(config BreadcrumbConfig) !Element {
	component_validate_frame(config.frame)!
	component_validate_id(config.id)!
	metrics := component_metrics(config.size)
	mut children := []Element{}
	mut ids := map[string]bool{}
	if config.items.len > 0 {
		count := config.items.len
		separator_width := math.min(metrics.padding * 2, config.frame.width / (f64(count) * 2))
		widths := breadcrumb_item_widths(config.items, config.frame.width - separator_width * f64(count - 1),
			metrics)
		mut x := 0.0
		for index, item in config.items {
			if item.id.trim_space().len == 0 || item.id in ids {
				return error('breadcrumb item ids must be non-empty and unique')
			}
			ids[item.id] = true
			current := index == count - 1
			frame := rect(x, 0, widths[index], config.frame.height)
			// Centered like the button titles beside it, so the gaps around every
			// separator come out the same.
			child := if current {
				label('', item.label, frame, TextStyle{
					color: config.theme.foreground
					size:  metrics.font_size
					bold:  true
					align: .center
				})
			} else {
				button(component_part_id(config.id, 'item:' + item.id.bytes().hex()), item.label,
					frame, BoxStyle{ transparent: true }, TextStyle{
						color: if config.enabled && item.enabled {
							config.theme.primary
						} else {
							config.theme.muted_foreground
						}
						size:  metrics.font_size
					})
			}
			children << Element{
				...child
				key:                 'item:' + item.id
				action_id:           if item.action_id.len > 0 { item.action_id } else { item.id }
				enabled:             config.enabled && item.enabled && !current
				accessibility_label: item.label
				accessibility_value: if current { 'current' } else { '' }
			}
			x += widths[index]
			if !current {
				children << Element{
					...label('', config.separator, rect(x, 0, separator_width, config.frame.height), TextStyle{
						color: config.theme.muted_foreground
						size:  metrics.font_size
						align: .center
					})
					key: 'separator:' + item.id
				}
				x += separator_width
			}
		}
	}
	return component_finish(Element{
		...view(config.id, config.frame, BoxStyle{ transparent: true }, children)
		accessibility_role:  'navigation'
		accessibility_label: 'Breadcrumb'
	})
}

// breadcrumb_item_widths sizes each item to an estimate of its label and shrinks
// them all evenly when the trail is wider than the space it has. Items are packed
// from the left rather than stretched over the frame, so a separator sits next to
// the labels it divides.
fn breadcrumb_item_widths(items []BreadcrumbItem, available f64, metrics ComponentMetrics) []f64 {
	mut widths := []f64{cap: items.len}
	mut total := 0.0
	for item in items {
		width := component_text_width_estimate(item.label, metrics.font_size) + metrics.padding
		widths << width
		total += width
	}
	if total > available && total > 0 {
		scale := math.max(available, 0) / total
		for i in 0 .. widths.len {
			widths[i] *= scale
		}
	}
	return widths
}
