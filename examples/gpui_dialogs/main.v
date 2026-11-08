module main

import ui2

// A gallery of the in-window overlays: a form dialog (open from the start), a
// dialog whose body scrolls, a destructive alert dialog, and a sheet on each
// side of the window. The application owns every open flag: overlays emit
// actions, their decoders turn them into requests, and the handlers below
// answer them. Escape and Enter come from on_key_event, and Tab is kept
// inside the top overlay with a focus trap.

const window_width = 960
const window_height = 700

@[heap]
struct Gallery {
mut:
	dark          bool
	animate       bool = true
	profile_open  bool = true
	terms_open    bool
	alert_open    bool
	alert_subject string = 'project'
	sheet_open    bool
	sheet_side    ui2.SheetSide = .right
	sheet_size    f64           = 340
	// The profile as saved, and as being edited in the dialog.
	saved_name     string = 'Ada Lovelace'
	saved_email    string = 'ada@example.com'
	saved_username string = 'ada'
	name           string = 'Ada Lovelace'
	email          string = 'ada@example.com'
	username       string = 'ada'
	display_name   string = 'Analytical Engine'
	line_numbers   bool   = true
	accepted_terms bool
	status         string = 'The profile dialog is open: Tab and Shift+Tab stay in its fields, Escape or Cancel closes it.'
}

const gallery = &Gallery{}

fn window_frame() ui2.Rect {
	b := ui2.bounds()
	return ui2.rect(0, 0, b.width, b.height)
}

fn theme_of(app &Gallery) ui2.ComponentTheme {
	return ui2.component_theme(app.dark)
}

// ── Overlay configurations, shared by the build and the handlers ────

// Text fields stay light in both themes: AppKit draws a bezeled field white
// whatever background it is given, so dark text is the one that always shows.
const field_style = ui2.TextStyle{
	color: 0x172033
	size:  14
}

fn field_box(theme ui2.ComponentTheme) ui2.BoxStyle {
	return ui2.BoxStyle{
		bg:            0xffffff
		radius:        6
		border_color:  theme.border
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}
}

// toggle is a checkbox with its title as a separate label, because AppKit draws
// a checkbox title in the system text color, which a dark theme would hide.
fn toggle(id string, title string, checked bool, frame ui2.Rect, theme ui2.ComponentTheme) []ui2.Element {
	return [
		ui2.Element{
			...ui2.checkbox(id, '', checked, ui2.rect(frame.x, frame.y, 22, frame.height),
				ui2.TextStyle{})
			accessibility_label: title
		},
		ui2.label('', title, ui2.rect(frame.x + 28, frame.y, frame.width - 28, frame.height),
			ui2.TextStyle{
				color: theme.foreground
				size:  14
			}),
	]
}

fn caption(text string, frame ui2.Rect, theme ui2.ComponentTheme) ui2.Element {
	return ui2.label('', text, frame, ui2.TextStyle{
		color: theme.foreground
		size:  13
		bold:  true
	})
}

fn profile_config(app &Gallery, frame ui2.Rect) ui2.DialogConfig {
	theme := theme_of(app)
	base := ui2.DialogConfig{
		id:          'profile'
		frame:       frame
		open:        app.profile_open
		title:       'Edit profile'
		description: 'Make changes to your profile here. Click Save changes when you are done.'
		buttons:     [
			ui2.DialogButton{
				id:   'cancel'
				text: 'Cancel'
				role: .cancel
			},
			ui2.DialogButton{
				id:      'save'
				text:    'Save changes'
				role:    .confirm
				enabled: app.name.trim_space().len > 0
			},
		]
		theme:       theme
	}
	width := ui2.dialog_body_width(base)
	mut children := []ui2.Element{}
	for index, field in [['profile-name', 'Name', app.name], ['profile-email', 'Email', app.email],
		['profile-username', 'Username', app.username]] {
		y := f64(index) * 64
		children << caption(field[1], ui2.rect(0, y, width, 20), theme)
		children << ui2.text_field_with_change_and_submit(field[0], 'profile-submit', field[1],
			field[2], ui2.rect(0, y + 24, width, 32), field_box(theme), field_style, ui2.keyboard_default)
	}
	// A left-aligned text action: a view with button behavior around a label, since a
	// button title is always centered.
	children << ui2.Element{
		...ui2.button_view('delete-account', ui2.rect(0, 196, 140, 24), ui2.BoxStyle{
			transparent: true
		}, [
			ui2.label('', 'Delete account…', ui2.rect(0, 0, 140, 24), ui2.TextStyle{
				color:     theme.danger
				size:      13
				underline: true
			}),
		])
		cursor:             ui2.cursor_pointing_hand
		accessibility_role: 'link'
	}
	return ui2.DialogConfig{
		...base
		children: children
	}
}

fn terms_config(app &Gallery, frame ui2.Rect) ui2.DialogConfig {
	theme := theme_of(app)
	clauses := ['You keep ownership of everything you create with the service.',
		'We store your projects only to show them back to you.',
		'Backups are kept for thirty days after you delete a project.',
		'You can export every project at any time, in open formats.',
		'We never sell personal data or show advertising.',
		'Shared links stay private unless you publish them.',
		'Accounts unused for two years are archived, never deleted.',
		'Support answers within two working days.', 'These terms change only with thirty days notice.',
		'Every change is listed in the public changelog.',
		'You may close your account whenever you like.', 'Closing an account removes it within a week.',
		'Disputes are settled under the law of your country.',
		'Accessibility problems are treated as bugs.',
		'Status and incidents are published on the status page.',
		'Planned maintenance is announced a week ahead.',
		'Data stays in the region you chose when signing up.',
		'Teams can move a project between regions on request.',
		'Every sign-in from a new device is reported by email.',
		'Two-factor authentication is available on every plan.',
		'Prices are fixed for the length of your subscription.',
		'Refunds are offered within thirty days of a payment.', 'Questions go to support@example.com.']
	mut children := []ui2.Element{}
	for index, clause in clauses {
		children << ui2.label('', '${index + 1}. ${clause}', ui2.rect(0, f64(index) * 30, 420,
			24), ui2.TextStyle{
			color: theme.foreground
			size:  14
		})
	}
	return ui2.DialogConfig{
		id:          'terms'
		frame:       frame
		open:        app.terms_open
		title:       'Terms of service'
		description: 'Scroll to read every clause. The body scrolls; the header and footer stay put.'
		width:       .large
		children:    children
		buttons:     [
			ui2.DialogButton{
				id:   'decline'
				text: 'Decline'
				role: .cancel
			},
			ui2.DialogButton{
				id:   'accept'
				text: 'Accept'
				role: .confirm
			},
		]
		backdrop:    .solid
		theme:       theme
	}
}

fn alert_config(app &Gallery, frame ui2.Rect) ui2.AlertDialogConfig {
	return ui2.AlertDialogConfig{
		id:             'delete'
		frame:          frame
		open:           app.alert_open
		title:          'Delete ${app.alert_subject}?'
		description:    'This permanently deletes the ${app.alert_subject} and everything in it. This action cannot be undone.'
		icon:           'trash'
		confirm_text:   'Delete'
		destructive:    true
		// Return answers Cancel, so a stray keypress deletes nothing.
		default_choice: .cancel
		// Over the profile dialog, hide both rather than show one through the other.
		backdrop:       if app.profile_open {
			ui2.DialogBackdrop.solid
		} else {
			ui2.DialogBackdrop.clear
		}
		theme:          theme_of(app)
	}
}

fn sheet_config(app &Gallery, frame ui2.Rect) ui2.SheetConfig {
	theme := theme_of(app)
	horizontal := app.sheet_side in [.left, .right]
	base := ui2.SheetConfig{
		id:         'sheet'
		frame:      frame
		open:       app.sheet_open
		side:       app.sheet_side
		panel_size: if horizontal { app.sheet_size } else { 230 }
		resizable:  horizontal
		theme:      theme
	}
	match app.sheet_side {
		.right {
			cfg := ui2.SheetConfig{
				...base
				title:       'Workspace settings'
				description: 'Drag the left edge to resize.'
				buttons:     [
					ui2.DialogButton{
						id:   'cancel'
						text: 'Cancel'
						role: .cancel
					},
					ui2.DialogButton{
						id:   'apply'
						text: 'Apply'
						role: .confirm
					},
				]
			}
			width := (ui2.sheet_layout(cfg) or { panic(err) }).content_width
			mut children := [
				caption('Workspace name', ui2.rect(0, 0, width, 20), theme),
				ui2.text_field_with_change('sheet-display', 'Workspace name', app.display_name,
					ui2.rect(0, 24, width, 32), field_box(theme), field_style, ui2.keyboard_default),
			]
			children << toggle('sheet-lines', 'Show line numbers', app.line_numbers, ui2.rect(0,
				72, width, 24), theme)
			return ui2.SheetConfig{
				...cfg
				children: children
			}
		}
		.left {
			cfg := ui2.SheetConfig{
				...base
				title:       'Navigation'
				description: 'Drag the right edge to resize.'
			}
			width := (ui2.sheet_layout(cfg) or { panic(err) }).content_width
			mut children := []ui2.Element{}
			for index, page in ['Home', 'Projects', 'Team', 'Settings', 'Help'] {
				children << ui2.with_action(ui2.button_view('nav-${index}', ui2.rect(0,
					f64(index) * 40, width, 36), ui2.BoxStyle{
					bg:     theme.muted
					radius: 6
				}, [
					ui2.label('', page, ui2.rect(12, 0, width - 24, 36), ui2.TextStyle{
						color: theme.foreground
						size:  14
					}),
				]), 'nav:${page}')
			}
			return ui2.SheetConfig{
				...cfg
				children: children
			}
		}
		.top {
			mut children := []ui2.Element{}
			for index, note in ['Build 214 finished in 3 min 12 s.',
				'Grace Hopper commented on “Analytical engine”.',
				'Your export of “Notes on the engine” is ready.'] {
				children << ui2.label('', note, ui2.rect(0, f64(index) * 26, 600, 22),
					ui2.TextStyle{
						color: theme.foreground
						size:  14
					})
			}
			return ui2.SheetConfig{
				...base
				title:       'Notifications'
				description: 'Three new notifications.'
				children:    children
			}
		}
		.bottom {
			mut children := []ui2.Element{}
			for index, row in [['Esc', 'Close the top overlay'], ['Tab', 'Next field in the overlay'],
				['Shift + Tab', 'Previous field in the overlay'], ['Return', 'Confirm the dialog']] {
				y := f64(index) * 34
				children << ui2.kbd(
					keys:  row[0].split(' + ')
					frame: ui2.rect(0, y, 104, 28)
					theme: theme
				) or { panic(err) }
				children << ui2.label('', row[1], ui2.rect(120, y, 360, 28), ui2.TextStyle{
					color: theme.foreground
					size:  14
				})
			}
			return ui2.SheetConfig{
				...base
				title:       'Keyboard shortcuts'
				description: 'What the keys do while an overlay is open.'
				children:    children
			}
		}
	}
}

// ── Focus traps ─────────────────────────────────────────────────────

// top_trap is the trap of the overlay on top: only it may hold focus.
fn top_trap(app &Gallery, frame ui2.Rect) ?ui2.FocusTrap {
	if app.alert_open {
		return ui2.FocusTrap{}
	}
	if app.sheet_open {
		return ui2.FocusTrap{
			ids: ui2.focus_trap_ids(sheet_config(app, frame).children)
		}
	}
	if app.terms_open {
		return ui2.FocusTrap{}
	}
	if app.profile_open {
		return ui2.FocusTrap{
			ids: ui2.focus_trap_ids(profile_config(app, frame).children)
		}
	}
	return none
}

// tab moves focus within the top overlay. While one is open Tab never reaches
// the page behind it, even when the overlay has nothing to focus.
fn tab(backwards bool) {
	app := unsafe { gallery }
	trap := top_trap(app, window_frame()) or { return }
	ui2.consume_key()
	if next := ui2.focus_trap_target([trap], ui2.focused_id(), backwards) {
		ui2.focus(next)
	}
}

// focus_soon focuses id once the overlay holding it has been rendered.
fn focus_soon(id string) {
	ui2.after(0.05, fn [id] () {
		ui2.focus(id)
	})
}

// ── Opening and answering overlays ──────────────────────────────────

fn open_profile(mut app Gallery) {
	app.profile_open = true
	app.status = 'Editing the profile.'
	cfg := profile_config(app, window_frame())
	if app.animate {
		(ui2.dialog_open_animation(cfg) or { panic(err) }).start(ui2.dialog_surface_id(cfg.id))
	}
	if first := (ui2.FocusTrap{
		ids: ui2.focus_trap_ids(cfg.children)
	}).first()
	{
		focus_soon(first)
	}
}

fn answer_profile(mut app Gallery, event ui2.DialogEvent) {
	if event.reason == .confirm {
		app.saved_name = app.name.trim_space()
		app.saved_email = app.email.trim_space()
		app.saved_username = app.username.trim_space()
		app.status = 'Saved the profile of ${app.saved_name}.'
	} else {
		app.status = 'Closed the profile without saving (${event.reason}).'
	}
	// Controlled fields: the declared text is the saved one again.
	app.name = app.saved_name
	app.email = app.saved_email
	app.username = app.saved_username
	app.profile_open = false
	ui2.dismiss_keyboard()
}

fn open_alert(mut app Gallery, subject string) {
	ui2.dismiss_keyboard()
	app.alert_subject = subject
	app.alert_open = true
	app.status = 'Asking before deleting the ${subject}.'
	if app.animate {
		(ui2.alert_dialog_open_animation(alert_config(app, window_frame())) or { panic(err) }).start(ui2.dialog_surface_id('delete'))
	}
}

fn answer_alert(mut app Gallery, choice ui2.AlertDialogChoice) {
	app.alert_open = false
	if choice == .cancel {
		app.status = 'Kept the ${app.alert_subject}.'
		return
	}
	app.status = 'Deleted the ${app.alert_subject}.'
	if app.alert_subject == 'account' {
		app.profile_open = false
	}
}

fn answer_terms(mut app Gallery, event ui2.DialogEvent) {
	app.terms_open = false
	app.accepted_terms = event.reason == .confirm
	app.status = if app.accepted_terms { 'Accepted the terms.' } else { 'Declined the terms.' }
}

fn open_sheet(mut app Gallery, side ui2.SheetSide) {
	ui2.dismiss_keyboard()
	app.sheet_side = side
	app.sheet_open = true
	app.status = 'Opened the ${side} sheet.'
	cfg := sheet_config(app, window_frame())
	if app.animate {
		(ui2.sheet_open_animation(cfg) or { panic(err) }).start(ui2.sheet_panel_id(cfg.id))
	}
}

// close_sheet slides the sheet out before it is removed, when animating.
fn close_sheet(mut app Gallery, why string) {
	app.status = why
	if !app.animate {
		app.sheet_open = false
		return
	}
	slide := ui2.sheet_close_animation(sheet_config(app, window_frame()), fn () {
		mut state := unsafe { gallery }
		state.sheet_open = false
	}) or { panic(err) }
	slide.start(ui2.sheet_panel_id('sheet'))
}

fn answer_sheet(mut app Gallery, event ui2.DialogEvent) {
	if event.reason == .confirm {
		close_sheet(mut app, 'Applied the workspace settings.')
	} else {
		close_sheet(mut app, 'Closed the sheet (${event.reason}).')
	}
}

// decode_overlay offers an event to the open overlays, top one first.
fn decode_overlay(mut app Gallery, event string) bool {
	frame := window_frame()
	if app.alert_open {
		if choice := ui2.alert_dialog_choice_from_action(alert_config(app, frame), event) {
			answer_alert(mut app, choice)
			return true
		}
	}
	if app.sheet_open {
		cfg := sheet_config(app, frame)
		if size := ui2.sheet_size_from_pointer(cfg, event) {
			app.sheet_size = size
			return true
		}
		if request := ui2.sheet_event_from_action(cfg, event) {
			answer_sheet(mut app, request)
			return true
		}
	}
	if app.terms_open {
		if request := ui2.dialog_event_from_action(terms_config(app, frame), event) {
			answer_terms(mut app, request)
			return true
		}
	}
	if app.profile_open {
		if request := ui2.dialog_event_from_action(profile_config(app, frame), event) {
			answer_profile(mut app, request)
			return true
		}
	}
	return false
}

fn handle_event(event string) {
	mut app := unsafe { gallery }
	if !decode_overlay(mut app, event) {
		match event {
			'open-profile' {
				open_profile(mut app)
			}
			'open-terms' {
				app.terms_open = true
				app.status = 'Reading the terms.'
				if app.animate {
					(ui2.dialog_open_animation(terms_config(app, window_frame())) or { panic(err) }).start(ui2.dialog_surface_id('terms'))
				}
			}
			'open-delete' {
				open_alert(mut app, 'project')
			}
			'delete-account' {
				open_alert(mut app, 'account')
			}
			'sheet-left' {
				open_sheet(mut app, .left)
			}
			'sheet-right' {
				open_sheet(mut app, .right)
			}
			'sheet-top' {
				open_sheet(mut app, .top)
			}
			'sheet-bottom' {
				open_sheet(mut app, .bottom)
			}
			'animate' {
				app.animate = !app.animate
			}
			'dark' {
				app.dark = !app.dark
			}
			'profile-name' {
				app.name = ui2.text('profile-name')
			}
			'profile-email' {
				app.email = ui2.text('profile-email')
			}
			'profile-username' {
				app.username = ui2.text('profile-username')
			}
			'profile-submit' {
				// Return in a field: AppKit gives it to the field, not to on_key_event.
				if app.profile_open && app.name.trim_space().len > 0 {
					answer_profile(mut app, ui2.DialogEvent{
						reason: .confirm
						button: 'save'
					})
				}
			}
			'sheet-display' {
				app.display_name = ui2.text('sheet-display')
			}
			'sheet-lines' {
				app.line_numbers = !app.line_numbers
			}
			else {
				if event.starts_with('nav:') {
					close_sheet(mut app, 'Navigated to ${event['nav:'.len..]}.')
				} else {
					return
				}
			}
		}
	}
	ui2.refresh()
}

// handle_key_event gives Escape and Enter to the overlay on top, then Tab to
// its focus trap.
fn handle_key_event(event ui2.KeyEvent) {
	mut app := unsafe { gallery }
	frame := window_frame()
	mut handled := false
	if app.alert_open {
		if choice := ui2.alert_dialog_key_choice(alert_config(app, frame), event) {
			answer_alert(mut app, choice)
			handled = true
		}
	} else if app.sheet_open {
		if request := ui2.sheet_key_event(sheet_config(app, frame), event) {
			answer_sheet(mut app, request)
			handled = true
		}
	} else if app.terms_open {
		if request := ui2.dialog_key_event(terms_config(app, frame), event) {
			answer_terms(mut app, request)
			handled = true
		}
	} else if app.profile_open {
		if request := ui2.dialog_key_event(profile_config(app, frame), event) {
			answer_profile(mut app, request)
			handled = true
		}
	}
	if handled {
		ui2.consume_key()
		ui2.refresh()
		return
	}
	if backwards := ui2.focus_trap_direction(event) {
		tab(backwards)
	}
}

// handle_key catches Tab pressed in a focused AppKit text field, which only
// the string key handler hears.
fn handle_key(key string) {
	if backwards := ui2.focus_trap_key_direction(key) {
		tab(backwards)
	}
}

// ── The page ────────────────────────────────────────────────────────

fn trigger(id string, text string, frame ui2.Rect, theme ui2.ComponentTheme, danger bool) ui2.Element {
	return ui2.button(id, text, frame, ui2.BoxStyle{
		bg:            theme.background
		radius:        6
		border_color:  if danger { theme.danger } else { theme.border }
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
	}, ui2.TextStyle{
		color: if danger { theme.danger } else { theme.foreground }
		size:  14
		align: .center
	})
}

fn build() ui2.Element {
	app := unsafe { gallery }
	theme := theme_of(app)
	frame := window_frame()
	muted := ui2.TextStyle{
		color: theme.muted_foreground
		size:  13
	}
	mut children := [
		ui2.label('', 'Dialogs, alert dialogs and sheets', ui2.rect(24, 18, 600, 30),
			ui2.TextStyle{
				color: theme.foreground
				size:  22
				bold:  true
			}),
		ui2.label('', 'In-window overlays. The application owns every open flag and answers the actions they emit.',
			ui2.rect(24, 52, 900, 20), muted),
		ui2.label('', 'Dialogs', ui2.rect(24, 88, 120, 20), muted),
		trigger('open-profile', 'Edit profile', ui2.rect(24, 112, 140, 32), theme, false),
		trigger('open-terms', 'Terms of service', ui2.rect(176, 112, 160, 32), theme, false),
		trigger('open-delete', 'Delete project…', ui2.rect(348, 112, 160, 32), theme, true),
		ui2.label('', 'Sheets', ui2.rect(552, 88, 120, 20), muted),
	]
	for index, side in ['left', 'right', 'top', 'bottom'] {
		children << trigger('sheet-${side}', side.capitalize(), ui2.rect(552 + f64(index) * 96,
			112, 84, 32), theme, false)
	}
	children << toggle('animate', 'Animate', app.animate, ui2.rect(676, 22, 110, 24), theme)
	children << toggle('dark', 'Dark theme', app.dark, ui2.rect(800, 22, 136, 24), theme)
	children << ui2.group_box(
		id:       'account'
		title:    'Account'
		frame:    ui2.rect(24, 176, 440, 150)
		theme:    theme
		children: [
			ui2.description_list(
				frame: ui2.rect(0, 0, 424, 90)
				theme: theme
				items: [ui2.DescriptionItem{'Name', app.saved_name},
					ui2.DescriptionItem{'Email', app.saved_email},
					ui2.DescriptionItem{'Username', '@${app.saved_username}'}]
			) or { panic(err) },
		]
	) or { panic(err) }
	children << ui2.group_box(
		id:       'projects'
		title:    'Projects'
		frame:    ui2.rect(496, 176, 440, 150)
		theme:    theme
		children: [
			ui2.description_list(
				frame: ui2.rect(0, 0, 424, 90)
				theme: theme
				items: [ui2.DescriptionItem{'Workspace', app.display_name}, ui2.DescriptionItem{'Terms', if app.accepted_terms {
					'Accepted'
				} else {
					'Not accepted'
				}}, ui2.DescriptionItem{'Line numbers', if app.line_numbers {
					'Shown'
				} else {
					'Hidden'
				}}]
			) or { panic(err) },
		]
	) or { panic(err) }
	children << ui2.inline_alert(
		id:          'status'
		title:       'Last action'
		description: app.status
		frame:       ui2.rect(24, frame.height - 96, frame.width - 48, 72)
		theme:       theme
	) or { panic(err) }
	// Overlays come last so they are drawn over the page, the top one last.
	children << ui2.modal_dialog(profile_config(app, frame)) or { panic(err) }
	children << ui2.modal_dialog(terms_config(app, frame)) or { panic(err) }
	children << ui2.sheet(sheet_config(app, frame)) or { panic(err) }
	children << ui2.alert_dialog(alert_config(app, frame)) or { panic(err) }
	return ui2.screen(theme.background, children)
}

fn main() {
	ui2.on_key_event(handle_key_event)
	ui2.on_key(handle_key)
	ui2.run_window('GPUI Kit dialogs', window_width, window_height, build, handle_event)
}
