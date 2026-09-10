module main

import ui2

const radio_width = 680
const radio_height = 370
const radio_vml_source = $embed_file('demo_radio.vml').to_string()

pub struct CountryChoice {
pub:
	id   int
	name string
}

pub struct RadioDemo {
pub:
	countries []CountryChoice
pub mut:
	compact          bool = true
	selected_country string = 'United States'
	message          string = 'Country: United States'
}

fn initial_radio_demo() RadioDemo {
	return RadioDemo{
		countries: [
			CountryChoice{ id: 1, name: 'United States' },
			CountryChoice{ id: 2, name: 'Canada' },
			CountryChoice{ id: 3, name: 'United Kingdom' },
			CountryChoice{ id: 4, name: 'Australia' },
		]
	}
}

pub fn (mut app RadioDemo) select_country(country string) {
	app.selected_country = country
	app.message = 'Country: ${country}'
}

fn main() {
	ui2.run_vml[RadioDemo](
		source: radio_vml_source
		model: initial_radio_demo()
		title: 'Radio Choices'
		width: radio_width
		height: radio_height
	) or { panic(err) }
}
