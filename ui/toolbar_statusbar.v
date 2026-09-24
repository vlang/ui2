module ui2

// Toolbar provides a horizontal container for action buttons and tools.
// By default, it uses a light-gray background and a thin bottom border.
pub fn toolbar(id string, frame Rect, children []Element) Element {
	return view(id, frame, BoxStyle{
		bg: 0xeeeeee
		border_bottom: 1.0
		border_color: 0xcccccc
	}, children)
}
