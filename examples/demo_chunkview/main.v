module main

import ui2

const chunkview_width = 820
const chunkview_height = 560
const chunkview_vml_source = $embed_file('demo_chunkview.vml').to_string()

pub struct ChunkviewDemo {
pub mut:
	first_open  bool = true
	second_open bool = true
	alignment   string = 'Center'
	text_align  string = 'center'
	status      string = 'Both styled chunks are visible.'
}

pub fn (mut app ChunkviewDemo) sections_changed() {
	app.status = if app.first_open && app.second_open {
		'Both styled chunks are visible.'
	} else if app.first_open {
		'Only the first styled chunk is visible.'
	} else if app.second_open {
		'Only the second styled chunk is visible.'
	} else {
		'Both styled chunks are hidden.'
	}
}

pub fn (mut app ChunkviewDemo) alignment_changed() {
	app.text_align = match app.alignment {
		'Left' { 'left' }
		'Right' { 'right' }
		else { 'center' }
	}
}

pub fn (mut app ChunkviewDemo) reset_chunks() {
	app.first_open = true
	app.second_open = true
	app.alignment = 'Center'
	app.text_align = 'center'
	app.sections_changed()
}

fn main() {
	ui2.run_vml[ChunkviewDemo](
		source: chunkview_vml_source
		model: ChunkviewDemo{}
		title: 'Chunk View'
		width: chunkview_width
		height: chunkview_height
	) or {
		panic(err)
	}
}
