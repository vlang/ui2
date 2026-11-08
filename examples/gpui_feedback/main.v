module main

import ui2

// A gallery of the feedback components: linear and circular progress, loading
// spinners, shimmer placeholders and named icons. Every animation runs while
// the window is open; the buttons change the progress value, switch the theme,
// pause motion and toggle the indeterminate modes.

@[heap]
struct Gallery {
mut:
	value         f64 = 40
	dark          bool
	reduce_motion bool
	loading       bool = true
}

const gallery = &Gallery{}

const window_width = 1000
const window_height = 790

fn section_title(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, 440, 24), ui2.TextStyle{
		color: theme.foreground
		size:  16
		bold:  true
	})
}

fn caption(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn toolbar_button(id string, text string, x f64, width f64, theme ui2.ComponentTheme, active bool) ui2.Element {
	return ui2.button(id, text, ui2.rect(x, 18, width, 28), ui2.BoxStyle{
		bg:     if active { theme.primary } else { theme.muted }
		radius: 6
	}, ui2.TextStyle{
		color: if active { theme.primary_foreground } else { theme.foreground }
		size:  13
		align: .center
	})
}

fn progress_section(mut children []ui2.Element, theme ui2.ComponentTheme, state Gallery) {
	x := 24.0
	children << section_title('Progress', x, 64, theme)
	mut y := 96.0
	for value in [0.0, 25, 75, 100] {
		children << caption('${int(value)}%', ui2.rect(x, y - 2, 40, 16), theme)
		children << ui2.linear_progress(
			id:            'bar-${int(value)}'
			frame:         ui2.rect(x + 48, y, 380, 12)
			value:         value
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) }
		y += 20
	}
	y += 6
	children << caption('Sizes at ${int(state.value)}%: thickness 4, small, medium, large',
		ui2.rect(x, y, 428, 16), theme)
	y += 22
	children << ui2.linear_progress(
		id:            'bar-xs'
		frame:         ui2.rect(x, y, 428, 10)
		value:         state.value
		thickness:     4
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	y += 16
	for size in [ui2.ComponentSize.small, .medium, .large] {
		children << ui2.linear_progress(
			id:            'bar-${size}'
			frame:         ui2.rect(x, y, 428, 12)
			value:         state.value
			size:          size
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) }
		y += 18
	}
	y += 4
	children << caption('Tones, a custom square bar, and loading', ui2.rect(x, y, 428, 16),
		theme)
	y += 22
	children << ui2.linear_progress(
		id:            'bar-success'
		frame:         ui2.rect(x, y, 206, 12)
		value:         state.value
		tone:          .success
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.linear_progress(
		id:            'bar-warning'
		frame:         ui2.rect(x + 222, y, 206, 12)
		value:         state.value
		tone:          .warning
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	y += 22
	children << ui2.linear_progress(
		id:            'bar-custom'
		frame:         ui2.rect(x, y, 428, 16)
		value:         32
		thickness:     16
		radius:        2
		tone:          .success
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	y += 26
	children << ui2.linear_progress(
		id:            'bar-loading'
		frame:         ui2.rect(x, y, 428, 12)
		value:         state.value
		loading:       state.loading
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
}

fn circle_section(mut children []ui2.Element, theme ui2.ComponentTheme, state Gallery) {
	x := 24.0
	children << section_title('Progress circle', x, 378, theme)
	mut cx := x
	for size in [ui2.ComponentSize.small, .medium, .large] {
		children << ui2.progress_circle(
			id:            'circle-${size}'
			frame:         ui2.rect(cx, 414, 24, 24)
			value:         state.value
			size:          size
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) }
		cx += 30
	}
	for i, tone in [ui2.ComponentTone.success, .warning, .danger, .neutral] {
		children << ui2.progress_circle(
			id:            'circle-tone-${i}'
			frame:         ui2.rect(cx, 410, 32, 32)
			value:         [20.0, 45, 70, 95][i]
			diameter:      32
			tone:          tone
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) }
		cx += 40
	}
	children << ui2.progress_circle(
		id:            'circle-loading-small'
		frame:         ui2.rect(cx + 8, 410, 32, 32)
		diameter:      32
		loading:       state.loading
		value:         state.value
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << caption('Value, tones, loading', ui2.rect(x, 448, 300, 16), theme)
	children << ui2.progress_circle(
		id:            'circle-label'
		frame:         ui2.rect(x, 472, 96, 96)
		value:         state.value
		diameter:      88
		label:         '${int(state.value)}%'
		caption:       'Uploaded'
		size:          .large
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.progress_circle(
		id:            'circle-big-loading'
		frame:         ui2.rect(x + 112, 472, 96, 96)
		diameter:      88
		loading:       state.loading
		value:         state.value
		label:         if state.loading { '' } else { '${int(state.value)}%' }
		caption:       if state.loading { 'Loading' } else { 'Done' }
		tone:          .success
		size:          .large
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.progress_circle(
		id:            'circle-inline'
		frame:         ui2.rect(x + 232, 506, 20, 20)
		value:         state.value
		size:          .medium
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.label('', 'Downloading… ${int(state.value)}%', ui2.rect(x + 258, 506, 180,
		20), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})
}

fn spinner_section(mut children []ui2.Element, theme ui2.ComponentTheme, state Gallery) {
	x := 520.0
	children << section_title('Loading spinner', x, 64, theme)
	mut y := 96.0
	for kind in [ui2.LoadingSpinnerKind.dots, .ring] {
		children << caption(if kind == .dots { 'dots (Loader)' } else { 'ring (LoaderCircle)' },
			ui2.rect(x, y + 8, 120, 16), theme)
		mut sx := x + 128
		sizes := if kind == .dots { [12.0, 16, 24] } else { [12.0, 16, 24, 32] }
		for i, diameter in sizes {
			children << ui2.loading_spinner(
				id:            'spin-${kind}-${i}'
				frame:         ui2.rect(sx, y, 32, 32)
				kind:          kind
				diameter:      diameter
				reduce_motion: state.reduce_motion
				theme:         theme
			) or { panic(err) }
			sx += 40
		}
		tones := if kind == .dots {
			[ui2.ComponentTone.primary]
		} else {
			[ui2.ComponentTone.primary, .success]
		}
		for i, tone in tones {
			children << ui2.loading_spinner(
				id:            'spin-${kind}-tone-${i}'
				frame:         ui2.rect(sx, y, 32, 32)
				kind:          kind
				size:          .large
				tone:          tone
				reduce_motion: state.reduce_motion
				theme:         theme
			) or { panic(err) }
			sx += 32
		}
		y += 40
	}
	children << ui2.loading_spinner(
		id:            'spin-inline'
		frame:         ui2.rect(x, y + 8, 16, 16)
		kind:          .ring
		size:          .medium
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.label('', 'Loading data…', ui2.rect(x + 24, y + 6, 140, 20), ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
	// A busy button: the spinner sits on the primary fill, so its resting cells
	// take a track mixed with that fill rather than with the page background.
	children << ui2.view('saving', ui2.rect(x + 180, y, 124, 32), ui2.BoxStyle{
		bg:     theme.primary
		radius: 6
	}, [
		ui2.loading_spinner(
			id:            'spin-button'
			frame:         ui2.rect(12, 8, 16, 16)
			kind:          .ring
			color:         theme.primary_foreground
			background:    theme.primary
			reduce_motion: state.reduce_motion
			theme:         theme
		) or { panic(err) },
		ui2.label('', 'Saving…', ui2.rect(36, 6, 80, 20), ui2.TextStyle{
			color: theme.primary_foreground
			size:  13
			bold:  true
		}),
	])
}

fn shimmer_section(mut children []ui2.Element, theme ui2.ComponentTheme, state Gallery) {
	x := 520.0
	children << section_title('Shimmer', x, 236, theme)
	mut shapes := [ui2.ShimmerShape{
		frame:  ui2.rect(0, 0, 44, 44)
		circle: true
	}, ui2.ShimmerShape{
		frame:  ui2.rect(56, 6, 180, 12)
		radius: 6
	}, ui2.ShimmerShape{
		frame:  ui2.rect(56, 26, 120, 12)
		radius: 6
	}]
	shapes << ui2.shimmer_paragraph(0, 60, 440, 3, 12, 8)
	shapes << ui2.ShimmerShape{
		frame:  ui2.rect(0, 132, 440, 56)
		radius: 8
	}
	children << ui2.shimmer(
		id:            'card'
		frame:         ui2.rect(x, 268, 440, 188)
		shapes:        shapes
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.shimmer_text(
		id:            'thinking'
		frame:         ui2.rect(x, 468, 200, 22)
		text:          'Thinking…'
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << ui2.shimmer_text(
		id:              'generating'
		frame:           ui2.rect(x + 210, 468, 230, 22)
		text:            'Generating a response…'
		duration:        3
		color:           theme.muted_foreground
		highlight_color: theme.primary
		reduce_motion:   state.reduce_motion
		theme:           theme
	) or { panic(err) }
	children << ui2.shimmer(
		id:            'reverse'
		frame:         ui2.rect(x, 500, 440, 12)
		shapes:        [ui2.ShimmerShape{
			frame:  ui2.rect(0, 0, 440, 12)
			radius: 6
		}]
		reverse:       true
		spread_pixels: 48
		reduce_motion: state.reduce_motion
		theme:         theme
	) or { panic(err) }
	children << caption('Reverse sweep with a fixed 48 px half-width band', ui2.rect(x, 518, 440,
		16), theme)
}

fn icon_section(mut children []ui2.Element, theme ui2.ComponentTheme) {
	x := 24.0
	children << section_title('Icon', x, 586, theme)
	names := ui2.icon_names()
	columns := 27
	for i, name in names {
		column := i % columns
		row := i / columns
		children << ui2.with_tooltip(ui2.named_icon(
			id:    'icon-${name}'
			frame: ui2.rect(x + f64(column) * 35, 618 + f64(row) * 32, 24, 24)
			name:  name
			size:  .large
			theme: theme
		) or { panic(err) }, name.str())
	}
	y := 618 + f64((names.len + columns - 1) / columns) * 32 + 8
	children << caption('Sizes 12, 14, 16, 24, 32 and colors', ui2.rect(x, y + 6, 220, 16),
		theme)
	mut ix := x + 230
	for size in [12.0, 14, 16, 24, 32] {
		children << ui2.named_icon(
			frame:      ui2.rect(ix, y, 32, 32)
			name:       .settings
			pixel_size: size
			theme:      theme
		) or { panic(err) }
		ix += 38
	}
	for i, tone in [ui2.ComponentTone.primary, .success, .warning, .danger] {
		color, _ := theme.colors(tone)
		children << ui2.named_icon(
			frame: ui2.rect(ix + 12 + f64(i) * 36, y + 4, 24, 24)
			name:  [ui2.IconName.info, .star, .padlock, .delete][i]
			color: color
			size:  .large
			theme: theme
		) or { panic(err) }
	}
	children << ui2.named_icon(
		frame:    ui2.rect(ix + 168, y + 4, 24, 24)
		name:     .download
		rotation: 90
		size:     .large
		theme:    theme
	) or { panic(err) }
	children << caption('rotation: 90 (AppKit/UIKit)', ui2.rect(ix + 200, y + 10, 200, 16),
		theme)
}

fn build() ui2.Element {
	state := unsafe { gallery }
	theme := ui2.component_theme(state.dark)
	mut children := [
		ui2.label('', 'Feedback components', ui2.rect(24, 18, 300, 28), ui2.TextStyle{
			color: theme.foreground
			size:  20
			bold:  true
		}),
		toolbar_button('less', '−10', 470, 48, theme, false),
		toolbar_button('more', '+10', 524, 48, theme, false),
		toolbar_button('loading', 'Loading', 590, 90, theme, state.loading),
		toolbar_button('motion', 'Reduce motion', 686, 120, theme, state.reduce_motion),
		toolbar_button('theme', 'Dark theme', 812, 100, theme, state.dark),
	]
	progress_section(mut children, theme, state)
	circle_section(mut children, theme, state)
	spinner_section(mut children, theme, state)
	shimmer_section(mut children, theme, state)
	icon_section(mut children, theme)
	return ui2.screen(theme.background, children)
}

fn on_event(event string) {
	mut state := unsafe { gallery }
	match event {
		'less' { state.value = ui2.progress_percent(state.value - 10) }
		'more' { state.value = ui2.progress_percent(state.value + 10) }
		'loading' { state.loading = !state.loading }
		'motion' { state.reduce_motion = !state.reduce_motion }
		'theme' { state.dark = !state.dark }
		else { return }
	}
	ui2.refresh()
}

fn main() {
	ui2.run_window('UI2 Feedback Components', window_width, window_height, build, on_event)
}
