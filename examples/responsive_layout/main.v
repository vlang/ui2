@[has_globals]
module main

import math
import os
import ui2

pub struct Project {
pub:
	id          int
	title       string
	description string
}

pub struct ResponsiveApp {
pub mut:
	created  int
	projects []Project = [
		Project{ id: 1, title: 'Design system', description: 'Shared controls and typography' },
		Project{ id: 2, title: 'Desktop app', description: 'One layout across window sizes' },
	]
}

__global responsive_app = ResponsiveApp{}

fn main() {
	width := if '--compact' in os.args { 390 } else { 1000 }
	ui2.run_window('UI2 · Responsive layout', width, 780, build, event)
}

fn build() ui2.Element {
	return responsive_tree(responsive_app, ui2.bounds()) or { panic(err) }
}

fn event(id string) {
	if id in ['create', 'create-featured'] {
		responsive_app.created++
		ui2.refresh()
	}
}

fn measured_label(id string, text string, width f64, style ui2.TextStyle) !ui2.Element {
	element := ui2.label(id, text, ui2.Rect{}, style)
	size := ui2.measure_layout_element(element, ui2.LayoutConstraints{ max_width: width }, ui2.measure_layout_text)!
	return ui2.Element{ ...element, frame: ui2.rect(0, 0, size.width, size.height) }
}

// Wrapping assigns each line its natural height before the container is placed.
fn row(id string, width f64, children []ui2.FlexChild) !ui2.Element {
	config := ui2.FlexConfig{
		id:       id
		frame:    ui2.rect(0, 0, width, 0)
		gap:      12
		line_gap: 12
		wrap:     true
		align:    .center
		children: children
	}
	frames := ui2.flex_frames(config)!
	mut height := 0.0
	for frame in frames {
		height = math.max(height, frame.y + frame.height)
	}
	return ui2.flex(ui2.FlexConfig{ ...config, frame: ui2.rect(0, 0, width, height) })!
}

fn project_card(id string, title string, description string, size ui2.Rect, featured bool) !ui2.Element {
	color := if featured { u32(0xffffff) } else { u32(0x17243d) }
	title_label := measured_label(id + '-title', title, math.max(0.0, size.width - 40),
		ui2.TextStyle{ size: 20, color: color, lines: 2 })!
	description_label := measured_label(id + '-description', description,
		math.max(0.0, size.width - 40), ui2.TextStyle{ size: 14, color: color, lines: 3 })!
	return ui2.flex(ui2.FlexConfig{
		id:          id
		frame:       ui2.rect(0, 0, size.width, size.height)
		box:         ui2.BoxStyle{ bg: if featured { u32(0x17243d) } else { u32(0xffffff) }, radius: 14 }
		orientation: .vertical
		padding:     ui2.LayoutPadding{ left: 20, right: 20, top: 20, bottom: 20 }
		gap:         10
		children:    [
			ui2.FlexChild{ element: title_label, shrink: 0 },
			ui2.FlexChild{ element: description_label, shrink: 0 },
			ui2.FlexChild{ element: ui2.view(id + '-space', ui2.Rect{}, ui2.BoxStyle{ transparent: true }, []ui2.Element{}), grow: 1 },
			ui2.FlexChild{
				element: ui2.button(if featured { 'create-featured' } else { id + '-open' },
					if featured { 'Create project' } else { 'Open project' }, ui2.rect(0, 0, 120, 36),
					ui2.BoxStyle{ bg: 0xe9effd, radius: 8 }, ui2.TextStyle{ color: 0x244eca })
				shrink:  0
			},
		]
	})!
}

fn responsive_tree(app ResponsiveApp, frame ui2.Rect) !ui2.Element {
	width := math.max(0.0, frame.width - 48)
	height := math.max(740.0, frame.height)
	toolbar := row('toolbar', width, [
		ui2.FlexChild{ element: ui2.label('heading', 'UI2 Studio', ui2.rect(0, 0, 170, 40), ui2.TextStyle{ size: 26, bold: true, color: 0x17243d }), grow: 1, minimum_width: 170 },
		ui2.FlexChild{ element: ui2.button('create', 'New project', ui2.rect(0, 0, 112, 40), ui2.BoxStyle{ bg: 0x315eeb, radius: 8 }, ui2.TextStyle{ color: 0xffffff }) },
		ui2.FlexChild{ element: ui2.button('settings', 'Settings', ui2.rect(0, 0, 98, 40), ui2.BoxStyle{ bg: 0xffffff, radius: 8 }, ui2.TextStyle{ color: 0x17243d }) },
	])!
	searchbar := row('searchbar', width, [
		ui2.FlexChild{ element: ui2.text_field('search', '', 'Search projects', ui2.rect(0, 0, 220, 38), ui2.BoxStyle{ bg: 0xffffff, radius: 8 }, ui2.TextStyle{}, 0), grow: 1, minimum_width: 150 },
		ui2.FlexChild{ element: measured_label('count', 'Created: ${app.created}', width, ui2.TextStyle{ color: 0x52627d })! },
	])!
	config := ui2.GridConfig{
		id:                     'projects'
		frame:                  ui2.rect(0, 0, width, math.max(0.0, height - 48 - toolbar.frame.height - searchbar.frame.height - 80))
		auto_columns_min_width: 240
		max_columns:            3
		spacing:                ui2.GridSpacing{ horizontal: 16, vertical: 16 }
		child_spans:            [ui2.GridSpan{ column_span: 2 }]
	}
	cells := ui2.grid_frames(config, app.projects.len + 1)!
	mut cards := [project_card('featured', 'A layout that adapts', 'Flex, grid and content sizing.', cells[0], true)!]
	for index, project in app.projects {
		cards << project_card('project-${project.id}', project.title, project.description, cells[index + 1], false)!
	}
	projects := ui2.grid(ui2.GridConfig{ ...config, children: cards })!
	page := ui2.flex(ui2.FlexConfig{
		id:          'page'
		frame:       ui2.rect(0, 0, frame.width, height)
		orientation: .vertical
		padding:     ui2.LayoutPadding{ left: 24, right: 24, top: 24, bottom: 24 }
		gap:         20
		children:    [
			ui2.FlexChild{ element: toolbar, shrink: 0 },
			ui2.FlexChild{ element: searchbar, shrink: 0 },
			ui2.FlexChild{ element: projects, grow: 1 },
			ui2.FlexChild{ element: ui2.label('instructions', 'Resize the window. Your search stays in place.', ui2.rect(0, 0, width, 20), ui2.TextStyle{ size: 12, color: 0x52627d }), shrink: 0 },
		]
	})!
	return ui2.screen(0xf2f5fa, [ui2.scroll('viewport', frame, 0xf2f5fa, [page])])
}
