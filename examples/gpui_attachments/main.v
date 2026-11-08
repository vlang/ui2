module main

import os
import ui2

// Attachments ported from GPUI Kit. A chat composer holds a row of uploads in
// every status: one advances with an `after` timer, one failed and offers a
// retry, one is an image tile. Below it, a message's attachments as a list,
// preview cards in a wrapping grid, and the three sizes. The application owns
// every upload; the groups report remove, retry, click, actions and hover
// through attachment_group_event_from_action.

const composer_id = 'composer'
const sent_id = 'sent'
const previews_id = 'previews'

struct Upload {
mut:
	key      string
	name     string
	bytes    i64
	status   ui2.AttachmentStatus = .complete
	progress f64
	reason   string // Why it failed.
	image    string
	image_w  f64
	image_h  f64
	vertical bool
	tile     bool
	retry    bool
	remove   bool = true
	actions  []ui2.AttachmentAction
	click    bool
	// fails makes a retried upload fail again, so the failed state stays in view.
	fails bool
}

@[heap]
struct Gallery {
mut:
	dark     bool
	composer []Upload
	sent     []Upload
	previews []Upload
	hovered  map[string]string // The hovered item of each group.
	offset   f64               // The composer row's scroll position.
	timer    ui2.TimerId
	status   string = 'Hover a message attachment, click it, or use its actions.'
}

const gallery = &Gallery{}

// asset finds a file of the ui2 checkout: beside this example when it is run
// from the repository, else in the installed module.
fn asset(parts ...string) string {
	roots := [os.join_path(os.dir(@FILE), '..', '..'), os.join_path(os.vmodules_dir(), 'ui2')]
	for root in roots {
		path := os.join_path(root, ...parts)
		if os.exists(path) {
			return os.real_path(path)
		}
	}
	return ''
}

// logo_path is a square image that every backend can load (Win32 reads BMP).
fn logo_path() string {
	$if windows {
		return asset('examples', 'users', 'logo.bmp')
	} $else {
		return asset('examples', 'users', 'logo.png')
	}
}

fn screenshot_path() string {
	$if windows {
		return ''
	} $else {
		return asset('docs', 'images', 'widgets', 'carousel.png')
	}
}

fn initial_state(mut app Gallery) {
	logo := logo_path()
	app.composer = [
		Upload{
			key:      'logo'
			name:     'vlang-logo.png'
			bytes:    4328
			image:    logo
			vertical: true
			tile:     true
		},
		Upload{
			key:      'report'
			name:     'quarterly-report-2026-final.pdf'
			bytes:    2_516_582
			status:   .uploading
			progress: 42
		},
		Upload{
			key:    'photo'
			name:   'IMG_2041.png'
			bytes:  3_871_225
			status: .failed
			reason: 'Network error'
			image:  logo
			retry:  true
			fails:  true
		},
		Upload{
			key:    'archive'
			name:   'assets.tar.gz'
			bytes:  48_234_496
			status: .pending
		},
		Upload{
			key:    'dataset'
			name:   'survey-results.csv'
			bytes:  184_320
			status: .processing
		},
		Upload{
			key:   'notes'
			name:  'meeting-notes.md'
			bytes: 2_150
		},
	]
	app.sent = [
		Upload{
			key:     'statement'
			name:    'Q3 statement.pdf'
			bytes:   1_258_291
			remove:  false
			click:   true
			actions: [ui2.attachment_download_action(), ui2.attachment_open_action()]
		},
		Upload{
			key:     'guidelines'
			name:    'brand-guidelines-final-v3-approved-by-legal.pdf'
			bytes:   15_938_355
			remove:  false
			click:   true
			actions: [ui2.attachment_download_action(), ui2.attachment_open_action()]
		},
		Upload{
			key:     'recording'
			name:    'design-review-recording.mp4'
			bytes:   204_472_320
			remove:  false
			click:   true
			actions: [ui2.attachment_download_action()]
		},
		Upload{
			key:     'script'
			name:    'deploy.sh'
			bytes:   918
			remove:  false
			click:   true
			actions: [ui2.attachment_download_action()]
		},
	]
	app.previews = [
		Upload{
			key:      'shot'
			name:     'carousel.png'
			bytes:    46_120
			image:    screenshot_path()
			image_w:  920
			image_h:  680
			vertical: true
			actions:  [ui2.attachment_open_action()]
		},
		Upload{
			key:      'avatar'
			name:     'profile-picture.png'
			bytes:    4328
			image:    logo
			vertical: true
			status:   .uploading
			progress: 64
		},
		Upload{
			key:      'clip'
			name:     'product-demo.mov'
			bytes:    88_080_384
			vertical: true
			status:   .processing
		},
		Upload{
			key:      'scan'
			name:     'passport-scan.jpg'
			bytes:    24_117_248
			vertical: true
			status:   .failed
			reason:   'Larger than 20 MB'
		},
	]
}

fn (u Upload) config() ui2.AttachmentConfig {
	return ui2.AttachmentConfig{
		id:            u.key
		name:          u.name
		bytes:         u.bytes
		status:        u.status
		progress:      u.progress
		error_message: u.reason
		image_path:    u.image
		image_width:   u.image_w
		image_height:  u.image_h
		axis:          if u.vertical { .vertical } else { .horizontal }
		hide_content:  u.tile
		retryable:     u.retry
		removable:     u.remove
		clickable:     u.click
		actions:       u.actions
		tooltip:       if u.status == .failed && !u.retry && u.reason.len > 0 {
			'${u.reason} · Remove to send'
		} else {
			''
		}
	}
}

fn composer_config(app &Gallery, frame ui2.Rect, surface u32, theme ui2.ComponentTheme) ui2.AttachmentGroupConfig {
	return ui2.AttachmentGroupConfig{
		id:            composer_id
		frame:         frame
		items:         app.composer.map(it.config())
		hovered:       app.hovered[composer_id]
		edge_fade:     surface
		scroll_offset: app.offset
		surface:       surface
		theme:         theme
	}
}

fn sent_config(app &Gallery, frame ui2.Rect, theme ui2.ComponentTheme) ui2.AttachmentGroupConfig {
	return ui2.AttachmentGroupConfig{
		id:      sent_id
		frame:   frame
		items:   app.sent.map(it.config())
		layout:  .list
		gap:     8
		hovered: app.hovered[sent_id]
		theme:   theme
	}
}

fn previews_config(app &Gallery, frame ui2.Rect, theme ui2.ComponentTheme) ui2.AttachmentGroupConfig {
	return ui2.AttachmentGroupConfig{
		id:      previews_id
		frame:   frame
		items:   app.previews.map(it.config())
		layout:  .wrap
		hovered: app.hovered[previews_id]
		theme:   theme
	}
}

fn symbol(name string, frame ui2.Rect, color u32) ui2.Element {
	return ui2.Element{
		...ui2.image('', 'symbol:' + name, frame)
		text_style: ui2.TextStyle{
			color: color
		}
	}
}

fn heading(text string, x f64, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, 420, 22), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
}

fn note(text string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 18), ui2.TextStyle{
		color: theme.muted_foreground
		size:  12
	})
}

fn build() ui2.Element {
	app := unsafe { gallery }
	theme := ui2.component_theme(app.dark)
	page := theme.background
	mut children := []ui2.Element{}
	children << ui2.label('', 'Attachments', ui2.rect(24, 18, 400, 30), ui2.TextStyle{
		color: theme.foreground
		size:  22
		bold:  true
	})
	children << ui2.link(
		id:    'theme'
		text:  'Toggle light / dark'
		frame: ui2.rect(24, 50, 136, 24)
		theme: theme
	) or { panic(err) }

	// A chat composer: the attachment row above the message field.
	children << heading('Chat composer', 24, 88, theme)
	children << note('A row that scrolls sideways. The upload advances on a timer; retry the failed photo; remove anything.',
		24, 110, 700, theme)
	composer := ui2.rect(24, 136, 996, 158)
	row_frame := ui2.rect(12, 8, composer.width - 24, 82)
	composer_children := [
		ui2.attachment_group(composer_config(app, row_frame, page, theme)) or { panic(err) },
		ui2.view('', ui2.rect(12, 98, composer.width - 24, 1), ui2.BoxStyle{
			bg: theme.border
		}, []ui2.Element{}),
		symbol('paperclip', ui2.rect(16, 118, 20, 20), theme.muted_foreground),
		ui2.label('', 'Ask anything about these files…', ui2.rect(46, 110, 420, 36),
			ui2.TextStyle{
				color: theme.muted_foreground
				size:  14
			}),
		ui2.button_view('send', ui2.rect(composer.width - 48, 112, 32, 32), ui2.BoxStyle{
			bg:     theme.primary
			radius: 16
		}, [
			symbol('arrow.up', ui2.rect(8, 8, 16, 16), theme.primary_foreground),
		]),
	]
	children << ui2.view('composer-box', composer, ui2.BoxStyle{
		bg:            page
		radius:        14
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, composer_children)

	// A sent message's attachments: a list of clickable chips with actions.
	children << heading('Sent with a message', 24, 320, theme)
	children << note('A list: whole-card click, hover, download and open.', 24, 342, 420,
		theme)
	children << ui2.attachment_group(sent_config(app, ui2.rect(24, 368, 420, 248), theme)) or {
		panic(err)
	}

	// Preview cards: vertical attachments in a wrapping grid.
	children << heading('Preview cards', 480, 320, theme)
	children << note('Vertical cards wrap; an image keeps its colors under a scrim.', 480, 342,
		540, theme)
	children << ui2.attachment_group(previews_config(app, ui2.rect(480, 368, 540, 190),
		theme)) or { panic(err) }

	// The three sizes.
	children << heading('Sizes', 24, 638, theme)
	mut x := 24.0
	for size in [ui2.ComponentSize.small, .medium, .large] {
		el := ui2.attachment(
			frame: ui2.rect(x, 666, 0, 0)
			name:  'contract-${size}.docx'
			bytes: 86_016
			size:  size
			theme: theme
		) or { panic(err) }
		children << el
		x += el.frame.width + 16
	}
	children << ui2.label('', app.status, ui2.rect(480, 580, 540, 40), ui2.TextStyle{
		color: theme.foreground
		size:  13
		lines: 0
	})
	return ui2.screen(page, children)
}

// advance moves the uploads of list that know their progress along, and
// reports whether any is still uploading.
fn advance(mut list []Upload) bool {
	mut moving := false
	for mut u in list {
		if u.status != .uploading {
			continue
		}
		u.progress += if u.vertical { 3 } else { 5 }
		if u.progress < 100 {
			moving = true
		} else if u.fails {
			u.status = .failed
			u.reason = 'Network error'
		} else {
			u.status = .processing
			finish(u.key)
		}
	}
	return moving
}

// tick advances the uploads, which then process for a moment and finish. It
// schedules itself while anything is uploading, and otherwise uploads the
// report again a little later, so the demo keeps moving.
fn tick() {
	mut app := unsafe { gallery }
	composer_moving := advance(mut app.composer)
	previews_moving := advance(mut app.previews)
	if composer_moving || previews_moving {
		app.timer = ui2.after(0.25, tick)
		return
	}
	app.timer = ui2.after(3, fn () {
		mut g := unsafe { gallery }
		for mut u in g.composer {
			if u.key == 'report' && u.status == .complete {
				u.status = .uploading
				u.progress = 0
			}
		}
		tick()
	})
}

// complete turns a processing upload of list complete.
fn complete(mut list []Upload, key string) {
	for mut u in list {
		if u.key == key && u.status == .processing {
			u.status = .complete
		}
	}
}

// finish completes a processing upload after a moment.
fn finish(key string) {
	ui2.after(1.2, fn [key] () {
		mut g := unsafe { gallery }
		complete(mut g.composer, key)
		complete(mut g.previews, key)
	})
}

// restart_ticking runs the next tick soon, replacing whichever was pending,
// so there is only ever one chain of ticks.
fn restart_ticking() {
	mut app := unsafe { gallery }
	ui2.cancel_timer(app.timer)
	app.timer = ui2.after(0.25, tick)
}

// handle_group applies an event of group id to its uploads and returns them.
fn handle_group(mut app Gallery, id string, uploads []Upload, event ui2.AttachmentEvent) []Upload {
	mut list := uploads.clone()
	mut index := -1
	for i, u in list {
		if u.key == event.key {
			index = i
		}
	}
	if index < 0 {
		return list
	}
	name := list[index].name
	match event.kind {
		.hover_start {
			app.hovered[id] = event.key
		}
		.hover_end {
			if app.hovered[id] == event.key {
				app.hovered[id] = ''
			}
		}
		.remove {
			list.delete(index)
			app.status = 'Removed ${name}.'
		}
		.retry {
			list[index].status = .uploading
			list[index].progress = 0
			list[index].reason = ''
			app.status = 'Retrying ${name}…'
		}
		.click {
			app.status = 'Opened ${name}.'
		}
		.action {
			app.status = '${event.action.capitalize()}: ${name}'
		}
	}
	return list
}

fn on_event(event string) {
	mut app := unsafe { gallery }
	theme := ui2.component_theme(app.dark)
	page := theme.background
	zero := ui2.rect(0, 0, 0, 0)
	if decoded := ui2.attachment_group_event_from_action(composer_config(app, zero, page,
		theme), event)
	{
		app.composer = handle_group(mut app, composer_id, app.composer, decoded)
		if decoded.kind == .retry {
			restart_ticking()
		}
	} else if decoded := ui2.attachment_group_event_from_action(sent_config(app, zero,
		theme), event)
	{
		app.sent = handle_group(mut app, sent_id, app.sent, decoded)
	} else if decoded := ui2.attachment_group_event_from_action(previews_config(app, zero,
		theme), event)
	{
		app.previews = handle_group(mut app, previews_id, app.previews, decoded)
		if decoded.kind == .retry {
			restart_ticking()
		}
	} else if event == 'theme' {
		app.dark = !app.dark
	} else if event == 'send' {
		app.status = 'Sent the message with ${app.composer.len} attachments.'
	} else {
		return
	}
	ui2.refresh()
}

fn on_scroll(id string) {
	mut app := unsafe { gallery }
	if id == ui2.attachment_group_scroll_id(composer_id) {
		app.offset = ui2.scroll_horizontal_offset(id)
		ui2.request_refresh()
	}
}

fn main() {
	mut app := unsafe { gallery }
	initial_state(mut app)
	ui2.on_scroll(on_scroll)
	restart_ticking()
	ui2.run_window('GPUI Kit attachments', 1044, 752, build, on_event)
}
