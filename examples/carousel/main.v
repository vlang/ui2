module main

import ui2

const carousel_width = 460
const carousel_height = 340
const carousel_vml_source = $embed_file('carousel.vml').to_string()

pub struct CarouselDemo {
pub mut:
	index int
}

pub fn (mut app CarouselDemo) previous() {
	app.index = ui2.carousel_previous(app.index, 3, true)
}

pub fn (mut app CarouselDemo) next() {
	app.index = ui2.carousel_next(app.index, 3, true)
}

fn main() {
	ui2.run_vml[CarouselDemo](
		source: carousel_vml_source
		model: CarouselDemo{}
		title: 'Carousel'
		width: carousel_width
		height: carousel_height
	) or { panic(err) }
}
