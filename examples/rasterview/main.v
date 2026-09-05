module main

import os
import ui2

const rasterview_width = 560
const rasterview_height = 500
const rasterview_qml_source = $embed_file('rasterview.qml').to_string()

pub struct RasterviewDemo {
pub:
	image_path string
pub mut:
	show_details bool = true
	status       string = 'Bundled repository logo loaded.'
}

fn raster_logo_path() string {
	$if windows {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.bmp'))
	} $else {
		return os.real_path(os.join_path(os.dir(@FILE), '..', 'users', 'logo.png'))
	}
}

fn initial_rasterview() RasterviewDemo {
	return RasterviewDemo{ image_path: raster_logo_path() }
}

pub fn (mut app RasterviewDemo) toggle_details() {
	app.show_details = !app.show_details
	app.status = if app.show_details { 'Image details shown.' } else { 'Image details hidden.' }
}

fn main() {
	ui2.run_qml[RasterviewDemo](
		source: rasterview_qml_source
		model: initial_rasterview()
		title: 'Raster View'
		width: rasterview_width
		height: rasterview_height
	) or { panic(err) }
}
