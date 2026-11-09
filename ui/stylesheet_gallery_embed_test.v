module ui2

// The shipped example sheets must always parse and lint clean: they are the
// first thing users copy from.

const gallery_sheet_source = $embed_file('../examples/stylesheet_gallery/gallery.u2ss').to_string()

fn test_shipped_gallery_sheet_parses_and_lints() {
	sheet := parse_stylesheet(gallery_sheet_source)!
	assert sheet.rules.len > 10
	notes := stylesheet_lint(sheet)
	assert !notes.has_errors(), notes.errors.join('; ')
}
