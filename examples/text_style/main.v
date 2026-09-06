module main

import os
import ui2

const text_style_width = 900
const text_style_height = 620
const text_style_qml_source = $embed_file('text_style.qml').to_string()
const text_style_max_fonts = 60

pub struct FontEntry {
pub:
	id     int
	key    string
	family string
	file   string
}

pub struct TextStyleDemo {
pub:
	fonts []FontEntry
pub mut:
	selected    int = 1
	family      string
	file        string
	sample      string = 'il était une fois V ....'
	size_choice string = '30'
	font_size   f64 = 30
	bold        bool
	italic      bool
	status      string
}

// text_style_font_dirs mirrors the trees ui2 itself indexes, so a family picked
// here is one the custom renderer can also resolve to a file.
fn text_style_font_dirs() []string {
	home := os.home_dir()
	$if linux {
		return [os.join_path(home, '.local', 'share', 'fonts'), os.join_path(home, '.fonts'),
			'/usr/local/share/fonts', '/usr/share/fonts']
	} $else $if macos {
		return [os.join_path(home, 'Library', 'Fonts'), '/Library/Fonts', '/System/Library/Fonts']
	} $else $if windows {
		windir := os.getenv('WINDIR')
		return if windir.len > 0 { [os.join_path(windir, 'Fonts')] } else { [] }
	} $else {
		return []
	}
}

// font_family_name turns a file name into the family to declare. Files that
// name a weight or a slant are left out: ui2 reaches those through `bold` and
// `italic` on the style, so listing them separately would offer the same face
// twice.
fn font_family_name(base string) ?string {
	lower := base.to_lower()
	if lower.contains('[') || lower.contains('variablefont') {
		return none
	}
	for marker in ['bold', 'italic', 'oblique', 'light', 'thin', 'medium', 'black', 'heavy',
		'condensed', 'semi', 'extra'] {
		if lower.contains(marker) {
			return none
		}
	}
	mut name := base
	for suffix in ['-Regular', '_Regular', 'Regular', '-Book', '-Roman'] {
		if name.len > suffix.len && name.ends_with(suffix) {
			name = name[..name.len - suffix.len]
			break
		}
	}
	trimmed := name.trim_right('-_ ')
	return if trimmed.len == 0 { none } else { trimmed }
}

fn discover_fonts() []FontEntry {
	mut seen := map[string]bool{}
	mut names := []string{}
	mut files := map[string]string{}
	for dir in text_style_font_dirs() {
		if !os.is_dir(dir) {
			continue
		}
		for extension in ['.ttf', '.otf'] {
			for path in os.walk_ext(dir, extension) {
				base := os.file_name(path).all_before_last('.')
				family := font_family_name(base) or { continue }
				key := family.to_lower()
				if key in seen {
					continue
				}
				seen[key] = true
				names << family
				files[family] = os.file_name(path)
			}
		}
	}
	names.sort()
	mut fonts := []FontEntry{cap: names.len}
	for family in names {
		if fonts.len == text_style_max_fonts {
			break
		}
		fonts << FontEntry{
			id: fonts.len + 1
			key: 'font-${fonts.len + 1}'
			family: family
			file: files[family] or { '' }
		}
	}
	return fonts
}

fn text_style_demo() TextStyleDemo {
	mut fonts := discover_fonts()
	if fonts.len == 0 {
		// A machine with no readable font tree still gets a working demo: these
		// are the generic families every backend maps to something.
		fonts = [
			FontEntry{
				id: 1
				key: 'font-1'
				family: 'System'
				file: 'built in'
			},
			FontEntry{
				id: 2
				key: 'font-2'
				family: 'Serif'
				file: 'built in'
			},
			FontEntry{
				id: 3
				key: 'font-3'
				family: 'Monospace'
				file: 'built in'
			},
		]
	}
	mut app := TextStyleDemo{
		fonts: fonts
	}
	app.choose_font(1)
	return app
}

pub fn (mut app TextStyleDemo) choose_font(id int) {
	for font in app.fonts {
		if font.id == id {
			app.selected = id
			app.family = font.family
			app.file = font.file
			app.describe()
			return
		}
	}
}

fn (mut app TextStyleDemo) describe() {
	mut traits := []string{}
	if app.bold {
		traits << 'bold'
	}
	if app.italic {
		traits << 'italic'
	}
	emphasis := if traits.len > 0 { ' · ' + traits.join(' ') } else { '' }
	app.status = '${app.family} · ${int(app.font_size)} pt${emphasis} · ${app.file} · ${app.fonts.len} families found'
}

pub fn (mut app TextStyleDemo) size_changed() {
	size := app.size_choice.f64()
	app.font_size = if size < 6 { 6.0 } else { size }
	app.describe()
}

pub fn (mut app TextStyleDemo) emphasis_changed() {
	app.describe()
}

fn main() {
	ui2.run_qml[TextStyleDemo](
		source: text_style_qml_source
		model: text_style_demo()
		title: 'Text Style'
		width: text_style_width
		height: text_style_height
	) or { panic(err) }
}
