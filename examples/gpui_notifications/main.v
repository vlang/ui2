module main

import ui2

// Notifications and copy buttons ported from GPUI Kit. The application owns a
// NotificationList: buttons push notifications, the stacks report close,
// action, click and hover through notification_event_from_action, and every
// list change returns timers that schedule() runs with `after`.

const gallery_toasts = 'toasts'
const gallery_api_key = 'sk-1234567890abcdef'
const gallery_share_url = 'https://github.com/vlang/ui2'
const gallery_column = 470.0

@[heap]
struct Gallery {
mut:
	notes     ui2.NotificationList
	clips     ui2.ClipboardFeedback
	placement ui2.NotificationPlacement = .top_right
	dark      bool
	uploading bool
	clipboard bool   = true // clipboard_supported(), read once at startup.
	status    string = 'Push a notification, then hover a stack to pause its countdown.'
}

const gallery = &Gallery{
	notes: ui2.NotificationList{
		max_visible: 4
	}
}

fn (mut app Gallery) push(n ui2.Notification) {
	app.notes.schedule(gallery_toasts, app.notes.push(ui2.Notification{
		...n
		placement: if n.placement == .inherit { app.placement } else { n.placement }
	}))
}

fn heading(text string, y f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(24, y, gallery_column, 24), ui2.TextStyle{
		color: theme.foreground
		size:  15
		bold:  true
	})
}

fn note(text string, x f64, y f64, width f64, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, ui2.rect(x, y, width, 22), ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	})
}

fn demo_button(id string, title string, x f64, y f64, width f64, theme ui2.ComponentTheme, selected bool) ui2.Element {
	return ui2.button(id, title, ui2.rect(x, y, width, 30), ui2.BoxStyle{
		bg:     if selected { theme.primary } else { theme.muted }
		radius: 6
	}, ui2.TextStyle{
		color: if selected { theme.primary_foreground } else { theme.foreground }
		size:  13
		align: .center
	})
}

fn placement_title(placement ui2.NotificationPlacement) string {
	return placement.str().replace('_', ' ')
}

fn build() ui2.Element {
	app := unsafe { gallery }
	theme := ui2.component_theme(app.dark)
	window := ui2.bounds()
	mut children := []ui2.Element{}
	children << ui2.label('', 'Notifications & clipboard', ui2.rect(24, 18, gallery_column, 30),
		ui2.TextStyle{
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

	children << heading('Push a notification', 88, theme)
	kinds := [['info', 'Info'], ['success', 'Success'], ['warning', 'Warning'], ['error', 'Error'],
		['plain', 'Plain']]
	for index, kind in kinds {
		children << demo_button('push:' + kind[0], kind[1], 24 + f64(index) * 92, 118, 86,
			theme, false)
	}
	features := [['action', 'With action'], ['clickable', 'Clickable'], ['content', 'Content'],
		['upload', if app.uploading {
			'Finish upload'
		} else {
			'Start upload'
		}], ['clear', 'Clear all']]
	for index, feature in features {
		children << demo_button('push:' + feature[0], feature[1], 24 + f64(index) * 92, 156,
			86, theme, false)
	}

	children << heading('Placement of new notifications', 202, theme)
	placements := [ui2.NotificationPlacement.top_left, .top_center, .top_right, .bottom_left,
		.bottom_center, .bottom_right]
	for index, placement in placements {
		children << demo_button('place:${placement}', placement_title(placement), 24 +
			f64(index % 3) * 150, 232 + f64(index / 3) * 38, 144, theme, placement == app.placement)
	}
	paused := if app.notes.is_paused() {
		'Countdowns paused: the pointer is over a stack.'
	} else {
		'Countdowns running.'
	}
	children << note(paused, 24, 314, gallery_column, theme)
	children << note('${app.notes.len()} in the list, ${app.notes.visible().len} shown (at most ${app.notes.max_visible} at a time).',
		24, 336, gallery_column, theme)
	children << ui2.label('', app.status, ui2.rect(24, 358, gallery_column, 40), ui2.TextStyle{
		color: theme.foreground
		size:  13
		lines: 0
	})

	children << heading('Clipboard', 408, theme)
	children << note('API key', 24, 446, 80, theme)
	children << ui2.copyable_text(
		id:                  'api-key'
		frame:               ui2.rect(104, 438, 300, 36)
		text:                gallery_api_key
		monospace:           true
		copied:              app.clips.copied('api-key')
		supported:           app.clipboard
		accessibility_label: 'Copy API key'
		tooltip:             'Copy API key'
		theme:               theme
	) or { panic(err) }
	children << note('Share URL', 24, 492, 80, theme)
	children << ui2.label('', gallery_share_url, ui2.rect(104, 492, 210, 22), ui2.TextStyle{
		color: theme.foreground
		size:  13
	})
	children << ui2.clipboard_button(
		id:                  'url'
		frame:               ui2.rect(314, 491, 24, 24)
		copied:              app.clips.copied('url')
		supported:           app.clipboard
		accessibility_label: 'Copy URL'
		tooltip:             'Copy URL'
		theme:               theme
	) or { panic(err) }
	children << ui2.clipboard_button(
		id:        'link'
		frame:     ui2.rect(346, 488, 104, 30)
		label:     'Copy link'
		copied:    app.clips.copied('link')
		supported: app.clipboard
		theme:     theme
	) or { panic(err) }

	children << note('States: idle, copied, unsupported, labeled copied', 24, 532, gallery_column,
		theme)
	children << ui2.clipboard_button(
		id:    'state-idle'
		frame: ui2.rect(24, 560, 24, 24)
		theme: theme
	) or {
		panic(err)
	}
	children << ui2.clipboard_button(
		id:     'state-copied'
		frame:  ui2.rect(56, 560, 24, 24)
		copied: true
		theme:  theme
	) or { panic(err) }
	children << ui2.clipboard_button(
		id:        'state-unsupported'
		frame:     ui2.rect(88, 560, 24, 24)
		supported: false
		theme:     theme
	) or { panic(err) }
	children << ui2.clipboard_button(
		id:     'state-labeled'
		frame:  ui2.rect(124, 557, 104, 30)
		label:  'Copy link'
		copied: true
		theme:  theme
	) or { panic(err) }

	// Drawn last, so the stacks sit on top of everything else.
	children << ui2.notification_stacks(
		id:    gallery_toasts
		frame: ui2.rect(0, 0, window.width, window.height)
		list:  app.notes
		theme: theme
	) or { panic(err) }
	return ui2.screen(theme.background, children)
}

fn push_demo(mut app Gallery, name string) {
	match name {
		'info' {
			app.push(kind: .info, message: 'File saved successfully.')
		}
		'success' {
			app.push(
				kind:    .success
				title:   'Payment processed'
				message: 'Your card was charged \$24.00.'
			)
		}
		'warning' {
			app.push(kind: .warning, message: 'Network connection is unstable.')
		}
		'error' {
			app.push(kind: .error, message: 'Failed to save file. Please try again.')
		}
		'plain' {
			app.push(message: 'This is a notification.')
		}
		'action' {
			app.push(
				key:     'connection'
				kind:    .error
				title:   'Connection lost'
				message: 'Unable to connect to the server.'
				action:  'Retry'
			)
		}
		'clickable' {
			app.push(kind: .info, message: 'Click to view details.', clickable: true)
		}
		'content' {
			theme := ui2.component_theme(app.dark)
			app.push(
				kind:           .success
				title:          'Batch operation complete'
				message:        'Processed 150 items.'
				autohide:       false
				content_height: 30
				content:        [
					ui2.view('', ui2.rect(0, 4, 200, 6), ui2.BoxStyle{ bg: theme.muted, radius: 3 }, [
						ui2.view('', ui2.rect(0, 0, 196, 6), ui2.BoxStyle{
							bg:     theme.success
							radius: 3
						}, []ui2.Element{}),
					]),
					ui2.label('', '147 succeeded, 3 failed', ui2.rect(0, 12, 240, 18), ui2.TextStyle{
						color: theme.muted_foreground
						size:  12
					}),
				]
			)
		}
		'upload' {
			if app.uploading {
				app.push(
					key:     'upload'
					kind:    .success
					title:   'Upload complete'
					message: 'report.pdf was uploaded.'
				)
			} else {
				app.push(
					key:      'upload'
					kind:     .info
					title:    'File upload'
					message:  'Uploading report.pdf…'
					autohide: false
				)
			}
			app.uploading = !app.uploading
		}
		'clear' {
			app.notes.schedule(gallery_toasts, app.notes.clear())
		}
		else {}
	}
}

fn on_event(event string) {
	mut app := unsafe { gallery }
	if decoded := ui2.notification_event_from_action(gallery_toasts, app.notes, event) {
		match decoded.kind {
			.action {
				app.status = 'Retrying the connection (action on “${decoded.key}”).'
			}
			.click {
				app.status = 'Opened the details of notification ${decoded.seq}.'
			}
			.close {
				app.status = 'Closed notification ${decoded.seq}.'
			}
			else {}
		}
		app.notes.schedule(gallery_toasts, app.notes.respond(decoded))
		ui2.refresh()
		return
	}
	if app.clips.copy_from_action('api-key', gallery_api_key, event) {
		app.push(kind: .success, message: 'API key copied to the clipboard.')
	} else if app.clips.copy_from_action('url', gallery_share_url, event)
		|| app.clips.copy_from_action('link', gallery_share_url, event) {
		app.push(kind: .success, message: 'URL copied: ${gallery_share_url}')
	} else if event.starts_with('push:') {
		push_demo(mut app, event['push:'.len..])
	} else if event.starts_with('place:') {
		for placement in [ui2.NotificationPlacement.top_left, .top_center, .top_right, .bottom_left,
			.bottom_center, .bottom_right] {
			if event == 'place:${placement}' {
				app.placement = placement
				app.status = 'New notifications appear at the ${placement_title(placement)}.'
			}
		}
	} else if event == 'theme' {
		app.dark = !app.dark
	} else {
		return
	}
	ui2.refresh()
}

fn main() {
	mut app := unsafe { gallery }
	app.clipboard = ui2.clipboard_supported()
	if !app.clipboard {
		app.status = 'This platform has no clipboard; the copy buttons cannot copy.'
	}
	// A few notifications are already on screen when the window opens.
	app.push(
		kind:     .success
		title:    'Payment processed'
		message:  'Your card ending in 4242 was charged \$24.00.'
		duration: 8
	)
	app.push(
		key:     'connection'
		kind:    .error
		title:   'Connection lost'
		message: 'Unable to reach the sync server.'
		action:  'Retry'
	)
	app.push(
		kind:      .warning
		title:     'Scheduled maintenance'
		message:   'Maintenance begins in 30 minutes.'
		autohide:  false
		placement: .bottom_right
	)
	app.push(
		kind:      .info
		message:   'Hover a stack to pause its countdown.'
		duration:  8
		placement: .bottom_right
	)
	app.notes.schedule(gallery_toasts, app.notes.settle())
	ui2.run_window('GPUI Kit notifications', 900, 640, build, on_event)
}
