module ui2

// The subject index must never change cascade results: an indexed sheet
// (built by parse) applies identically to the same rules without an index
// (hand-built literal, full scan), element-by-element with equal warnings.
fn test_stylesheet_index_parity() {
	sheet := parse_stylesheet('
@accent: #2563eb;
Button { background: @accent; color: white; }
Button.primary, Label.title { border-radius: 6px; }
.primary { border-color: #1d4ed8; border-width: 2px; }
#save-btn { opacity: 0.9; }
* { font-size: 14px; }
:hover { opacity: 0.5; }
View .title { color: #334155; }
View > Button { border-width: 1px; }
Label:first-child { font-weight: bold; }
.missing { color: red; }
Nonexistent { opacity: 0.1; }
Card, Dialog, Popover { opacity: 0.95; }
#gone { color: blue; }
.unused-class { border-radius: 9px; }
Screen View Label.title { font-size: 22px; }
Button.primary.selected { opacity: 0.8; }
@media (max-width: 560px) { Label.title { font-size: 18px; } }
') or { panic(err) }
	unindexed := Stylesheet{
		rules:      sheet.rules.clone()
		variables:  sheet.variables.clone()
		light_vars: sheet.light_vars.clone()
		dark_vars:  sheet.dark_vars.clone()
		imports:    sheet.imports.clone()
	}
	assert stylesheet_index_covers(sheet)
	assert !stylesheet_index_covers(unindexed)
	mut card_children := []Element{}
	card_children << with_classes(label('t1', 'one', rect(0, 0, 100, 18), TextStyle{}),
		'title')
	card_children << with_classes(button('save-btn', 'Save', rect(0, 20, 96, 38),
		BoxStyle{}, TextStyle{}), 'primary')
	mut root_children := []Element{}
	root_children << with_classes(view('card1', rect(0, 0, 200, 100), BoxStyle{},
		card_children), 'card')
	root_children << label('plain', 'hi', rect(0, 100, 100, 18), TextStyle{})
	root := view('root', rect(0, 0, 400, 800), BoxStyle{}, root_children)
	for env in [StyleMatchEnv{}, StyleMatchEnv{ hovered: 'save-btn', dark: true, dpi: 2.0 }] {
		a, wa := apply_stylesheet_ex(root, sheet, env)
		b, wb := apply_stylesheet_ex(root, unindexed, env)
		assert wa.len == wb.len
		for i, w in wa {
			assert w == wb[i]
		}
		assert stylesheet_index_trees_equal(a, b)
	}
}

fn stylesheet_index_trees_equal(a Element, b Element) bool {
	if a.kind != b.kind || a.id != b.id || a.text != b.text {
		return false
	}
	if a.classes != b.classes {
		return false
	}
	if a.box != b.box || a.text_style != b.text_style {
		return false
	}
	if a.children.len != b.children.len {
		return false
	}
	for i, child in a.children {
		if !stylesheet_index_trees_equal(child, b.children[i]) {
			return false
		}
	}
	return true
}
