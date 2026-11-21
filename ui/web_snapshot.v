module ui2

import json2

// WebSnapshot is the v0 wire envelope for the web backend (see
// docs/web-backend.md). It carries one validated element tree plus the window
// geometry the tree was built for. v1 sends full snapshots on every refresh;
// keyed diffs reuse Element.key/Element.id reconciliation later.
pub struct WebSnapshot {
pub:
	title  string
	width  int
	height int
	dpr    f64
	seq    u64
	root   Element
}

// web_snapshot validates root and encodes one snapshot frame.
pub fn web_snapshot(title string, width int, height int, dpr f64, seq u64, root Element) !string {
	validate_element_tree(root)!
	return json2.encode(WebSnapshot{
		title:  title
		width:  width
		height: height
		dpr:    dpr
		seq:    seq
		root:   root
	})
}

// web_snapshot_decode decodes one snapshot frame and validates its tree, so a
// corrupt or ambiguous payload fails before any renderer touches state.
pub fn web_snapshot_decode(data string) !WebSnapshot {
	snap := json2.decode[WebSnapshot](data)!
	validate_element_tree(snap.root)!
	return snap
}
