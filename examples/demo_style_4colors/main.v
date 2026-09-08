module main

import ui2

const style_colors_width = 640
const style_colors_height = 420
const style_colors_vml_source = $embed_file('demo_style_4colors.vml').to_string()

pub struct StyleFourColorsDemo {
pub mut:
	palette string = 'Classic'
	color0  string = '#FFFFFF'
	color1  string = '#E5E7EB'
	color2  string = '#BFDBFE'
	color3  string = '#111827'
	enabled bool = true
	status  string = 'Classic palette selected.'
}

pub fn (mut app StyleFourColorsDemo) palette_changed() {
	match app.palette {
		'Ocean' {
			app.color0 = '#F0F9FF'
			app.color1 = '#BAE6FD'
			app.color2 = '#0EA5E9'
			app.color3 = '#0C4A6E'
		}
		'Sunset' {
			app.color0 = '#FFF7ED'
			app.color1 = '#FED7AA'
			app.color2 = '#F97316'
			app.color3 = '#7C2D12'
		}
		'Forest' {
			app.color0 = '#F0FDF4'
			app.color1 = '#BBF7D0'
			app.color2 = '#22C55E'
			app.color3 = '#14532D'
		}
		else {
			app.palette = 'Classic'
			app.color0 = '#FFFFFF'
			app.color1 = '#E5E7EB'
			app.color2 = '#BFDBFE'
			app.color3 = '#111827'
		}
	}
	app.status = '${app.palette} palette selected.'
}

pub fn (mut app StyleFourColorsDemo) apply_palette() {
	app.status = '${app.palette} palette applied to the preview.'
}

fn main() {
	ui2.run_vml[StyleFourColorsDemo](
		source: style_colors_vml_source
		model: StyleFourColorsDemo{}
		title: 'Four Colors'
		width: style_colors_width
		height: style_colors_height
	) or { panic(err) }
}
