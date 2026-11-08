// SPDX-License-Identifier: Apache-2.0
// Includes attachment status-rule cases adapted from GPUI Kit (Longbridge,
// copyright 2024 - 2026); other tests are new. See third_party/gpui-kit.
module ui2

import math

// ── Helpers ─────────────────────────────────────────────────────────

fn attachments_find(el Element, id string) ?Element {
	if el.id == id {
		return el
	}
	for child in el.children {
		if found := attachments_find(child, id) {
			return found
		}
	}
	return none
}

fn attachments_labels(el Element) []string {
	mut found := []string{}
	if el.kind == .label && !el.hidden {
		found << el.text
	}
	for child in el.children {
		found << attachments_labels(child)
	}
	return found
}

fn attachments_symbols(el Element) []string {
	mut found := []string{}
	if el.kind == .image && el.image_path.starts_with('symbol:') {
		found << el.image_path['symbol:'.len..]
	}
	for child in el.children {
		found << attachments_symbols(child)
	}
	return found
}

fn attachments_images(el Element) []Element {
	mut found := []Element{}
	if el.kind == .image && !el.image_path.starts_with('symbol:') {
		found << el
	}
	for child in el.children {
		found << attachments_images(child)
	}
	return found
}

fn attachments_has_role(el Element, role string) bool {
	if el.accessibility_role == role {
		return true
	}
	for child in el.children {
		if attachments_has_role(child, role) {
			return true
		}
	}
	return false
}

fn attachments_card(el Element, id string) Element {
	return attachments_find(el, component_part_id(id, 'card')) or { panic('no card') }
}

fn attachments_report() AttachmentConfig {
	return AttachmentConfig{
		id:    'report'
		name:  'quarterly-report.pdf'
		bytes: 2_516_582
	}
}

// ── Pure helpers ────────────────────────────────────────────────────

fn test_attachment_status_helpers_and_words() {
	assert AttachmentStatus.pending.is_pending()
	assert AttachmentStatus.uploading.is_uploading()
	assert AttachmentStatus.processing.is_processing()
	assert AttachmentStatus.failed.is_failed()
	assert AttachmentStatus.complete.is_complete()
	assert AttachmentStatus.uploading.is_in_progress()
	assert AttachmentStatus.processing.is_in_progress()
	assert !AttachmentStatus.pending.is_in_progress()
	assert !AttachmentStatus.failed.is_in_progress()
	assert !AttachmentStatus.complete.is_in_progress()
	assert AttachmentStatus.pending.description() == 'Ready to upload'
	assert AttachmentStatus.failed.description() == 'Upload failed'
}

fn test_attachment_file_kind_from_name_and_mime() {
	assert attachment_extension('Report.PDF') == 'pdf'
	assert attachment_extension('dir.v/notes') == ''
	assert attachment_extension('C:\\files\\photo.JPEG') == 'jpeg'
	assert attachment_extension('backup.tar.gz') == 'tar.gz'
	assert attachment_extension('.env') == ''
	assert attachment_extension('trailing.') == ''
	assert attachment_extension('weird.p@f') == ''
	assert attachment_file_kind('Report.PDF', '') == .pdf
	assert attachment_file_kind('photo.heic', '') == .image
	assert attachment_file_kind('clip.mov', '') == .video
	assert attachment_file_kind('memo.m4a', '') == .audio
	assert attachment_file_kind('table.csv', '') == .spreadsheet
	assert attachment_file_kind('deck.pptx', '') == .presentation
	assert attachment_file_kind('backup.tar.gz', '') == .archive
	assert attachment_file_kind('main.v', '') == .code
	assert attachment_file_kind('notes.md', '') == .text
	assert attachment_file_kind('mystery.bin', '') == .file
	// A MIME type it knows wins over the extension; an unknown one does not.
	assert attachment_file_kind('upload', 'image/png') == .image
	assert attachment_file_kind('scan.bin', 'application/pdf; charset=binary') == .pdf
	assert attachment_file_kind('scan.pdf', 'application/octet-stream') == .pdf
	assert attachment_file_kind('readme', 'text/plain') == .text
	assert attachment_file_kind('', 'VIDEO/MP4') == .video
	for kind in [AttachmentFileKind.file, .image, .video, .audio, .pdf, .document, .text, .spreadsheet,
		.presentation, .archive, .code] {
		assert symbol_known(kind.symbol()), kind.symbol()
	}
	assert attachment_type_text('report.pdf', '') == 'PDF'
	assert attachment_type_text('upload', 'image/png') == 'Image'
	assert attachment_type_text('', '') == ''
}

fn test_attachment_size_text_is_human_readable() {
	assert attachment_size_text(-1) == ''
	assert attachment_size_text(0) == '0 B'
	assert attachment_size_text(1023) == '1023 B'
	assert attachment_size_text(1024) == '1 KB'
	assert attachment_size_text(12 * 1024 + 300) == '12 KB'
	assert attachment_size_text(2_516_582) == '2.4 MB'
	assert attachment_size_text(1536) == '1.5 KB'
	// Rounding carries into the next unit instead of showing 1024 KB.
	assert attachment_size_text(1024 * 1024 - 100) == '1 MB'
	assert attachment_size_text(i64(5) * 1024 * 1024 * 1024) == '5 GB'
	assert attachment_size_text(max_i64).ends_with('EB')
	assert attachment_meta_text('report.pdf', '', 2_516_582) == 'PDF · 2.4 MB'
	assert attachment_meta_text('report.pdf', '', -1) == 'PDF'
	assert attachment_meta_text('', '', 2048) == '2 KB'
}

fn test_attachment_middle_ellipsis_keeps_the_extension() {
	assert attachment_middle_ellipsis('short.pdf', 400, 13) == 'short.pdf'
	name := 'quarterly-financial-report-final-version.pdf'
	width := attachment_text_width('quarterly-fin…report.pdf', 13)
	shown := attachment_middle_ellipsis(name, width, 13)
	assert shown.contains('…')
	assert shown.ends_with('.pdf')
	assert shown.starts_with('quarterly')
	assert attachment_text_width(shown, 13) <= width + 1e-9
	// Characters, not bytes, are taken out.
	wide := attachment_middle_ellipsis('報告書のドラフト最終版.docx', attachment_text_width('報告…ft.docx',
		13), 13)
	assert wide.runes().len < '報告書のドラフト最終版.docx'.runes().len
	assert wide.ends_with('.docx')
	assert attachment_middle_ellipsis(name, 0, 13) == ''
	assert attachment_middle_ellipsis(name, 3, 13) == '…'
	// Narrow letters take less room than wide ones.
	assert attachment_text_width('illl', 13) < attachment_text_width('mmmm', 13)
	assert attachment_text_width('漢字', 13) > attachment_text_width('ab', 13)
}

fn test_attachment_metrics_follow_upstream_sizes() {
	small := attachment_metrics(.small)
	medium := attachment_metrics(.medium)
	large := attachment_metrics(.large)
	assert [small.height, medium.height, large.height] == [48.0, 56, 64]
	assert [small.chip_width, medium.chip_width, large.chip_width] == [200.0, 232, 272]
	assert [small.media, medium.media, large.media] == [32.0, 38, 44]
	assert [small.title_size, medium.title_size, large.title_size] == [12.0, 13, 14]
}

fn test_attachment_image_fit_and_dash_gaps() {
	box := rect(0, 0, 100, 100)
	assert attachment_image_fit(box, 0, 0) == box
	assert attachment_image_fit(box, 200, 100) == rect(0, 25, 100, 50)
	assert attachment_image_fit(rect(10, 10, 40, 40), 100, 200) == rect(20, 10, 20, 40)
	gaps := attachment_dash_gaps(232, 56, 8, 5, 3)
	assert gaps.len > 0
	for gap in gaps {
		// Breaks lie on the border line and clear of the rounded corners.
		on_edge := gap.y == 0 || gap.y == 55 || gap.x == 0 || gap.x == 231
		assert on_edge
		if gap.height == 1 {
			assert gap.x >= 8 && gap.x + gap.width <= 232 - 8
		} else {
			assert gap.y >= 8 && gap.y + gap.height <= 56 - 8
		}
	}
	assert attachment_dash_gaps(16, 16, 8, 5, 3).len == 0
}

// ── Attachment ──────────────────────────────────────────────────────

fn test_attachment_defaults_to_a_complete_medium_chip() {
	el := attachment(attachments_report()) or { panic(err) }
	assert el.id == 'report'
	assert el.frame == rect(0, 0, 232, 56)
	assert el.accessibility_role == 'group'
	assert el.accessibility_label == 'quarterly-report.pdf, PDF · 2.4 MB'
	assert el.accessibility_value == 'Ready'
	labels := attachments_labels(el)
	assert labels == ['quarterly-report.pdf', 'PDF · 2.4 MB']
	assert attachments_symbols(el) == ['doc.text.fill']
	card := attachments_card(el, 'report')
	assert card.box.border_left == 1
	assert card.box.border_color == ComponentTheme{}.border
	assert !card.button_behavior
	assert !el.hoverable
	// A static attachment needs no id.
	anonymous := attachment(name: 'notes.txt') or { panic(err) }
	assert attachments_symbols(anonymous) == ['text.alignleft']
	if _ := attachment(name: 'x.pdf', frame: rect(0, 0, -1, 10)) {
		assert false, 'negative frame accepted'
	}
}

fn test_attachment_frame_and_natural_size() {
	w, h := attachment_natural_size(attachments_report())
	assert w == 232 && h == 56
	rw, rh := attachment_natural_size(AttachmentConfig{
		...attachments_report()
		removable: true
	})
	assert rw == 232 + attachment_remove_overhang
	assert rh == 56 + attachment_remove_overhang
	sw, sh := attachment_natural_size(AttachmentConfig{
		...attachments_report()
		size: .small
	})
	assert sw == 200 && sh == 48
	tw, th := attachment_natural_size(AttachmentConfig{
		...attachments_report()
		axis:         .vertical
		hide_content: true
	})
	assert tw == 56 && th == 56
	vw, vh := attachment_natural_size(AttachmentConfig{
		...attachments_report()
		axis: .vertical
	})
	assert vw == 120
	assert vh == 8 + 104 + 10 + 18 + 2 + 16 + 8
	// Media only, the chip hugs its media.
	mw, _ := attachment_natural_size(AttachmentConfig{
		...attachments_report()
		hide_content: true
	})
	assert mw == 8 + 38 + 8
	stretched := attachment(AttachmentConfig{
		...attachments_report()
		frame: rect(20, 30, 400, 0)
	}) or { panic(err) }
	assert stretched.frame == rect(20, 30, 400, 56)
}

fn test_attachment_interactive_parts_require_an_id() {
	for config in [
		AttachmentConfig{
			name:      'a.pdf'
			removable: true
		},
		AttachmentConfig{
			name:      'a.pdf'
			clickable: true
		},
		AttachmentConfig{
			name:   'a.pdf'
			status: .uploading
		},
		AttachmentConfig{
			name:    'a.pdf'
			actions: [attachment_download_action()]
		},
	] {
		if _ := attachment(config) {
			assert false, 'interactive attachment accepted without an id'
		}
	}
	if _ := attachment(AttachmentConfig{
		...attachments_report()
		actions: [attachment_open_action(), attachment_open_action()]
	})
	{
		assert false, 'duplicate action ids accepted'
	}
	if _ := attachment(AttachmentConfig{
		...attachments_report()
		icon: 'no.such.symbol'
	})
	{
		assert false, 'unknown icon accepted'
	}
	if _ := attachment(AttachmentConfig{
		...attachments_report()
		image_width: math.nan()
	})
	{
		assert false, 'NaN image size accepted'
	}
}

fn test_attachment_uploading_with_progress() {
	el := attachment(AttachmentConfig{
		...attachments_report()
		status:   .uploading
		progress: 61.6
	}) or { panic(err) }
	labels := attachments_labels(el)
	assert 'Uploading · 62%' in labels
	assert el.accessibility_value == 'Uploading 61.6%'
	// The media's ring and the bottom bar both report the progress.
	ring := attachments_find(el, component_part_id('report', 'ring')) or { panic('no ring') }
	assert ring.accessibility_value == '61.6%'
	bar := attachments_find(el, component_part_id('report', 'bar')) or { panic('no bar') }
	assert bar.accessibility_role == 'progressbar'
	assert bar.frame.y + bar.frame.height == 55
	// The title shimmers while in progress.
	assert attachments_find(el, component_part_id('report', 'title')) != none
	// Progress is clamped and ignored outside uploading.
	over := attachment(AttachmentConfig{
		...attachments_report()
		status:   .uploading
		progress: 140
	}) or { panic(err) }
	assert 'Uploading · 100%' in attachments_labels(over)
	processing := attachment(AttachmentConfig{
		...attachments_report()
		status:   .processing
		progress: 40
	}) or { panic(err) }
	assert attachments_labels(processing).contains('Processing…')
	assert attachments_find(processing, component_part_id('report', 'ring')) == none
	assert attachments_find(processing, component_part_id('report', 'bar')) == none
	assert attachments_find(processing, component_part_id('report', 'spinner')) != none
	stop_attachment_animations('report')
}

fn test_attachment_failed_shows_reason_and_retry() {
	el := attachment(AttachmentConfig{
		...attachments_report()
		status:        .failed
		error_message: 'Network error'
		retryable:     true
	}) or { panic(err) }
	card := attachments_card(el, 'report')
	theme := ComponentTheme{}
	assert card.box.border_color == theme.danger
	assert card.tooltip == 'Network error'
	assert 'Network error' in attachments_labels(el)
	assert 'Retry' in attachments_labels(el)
	disc := attachments_find(el, component_part_id('report', 'retry')) or { panic('no retry') }
	assert disc.button_behavior
	link := attachments_find(el, component_part_id('report', 'retry-link')) or {
		panic('no retry link')
	}
	assert link.action_id == component_part_id('report', 'retry')
	// Without retry a failure is a rejection with an alert glyph.
	rejected := attachment(AttachmentConfig{
		...attachments_report()
		status: .failed
	}) or { panic(err) }
	assert attachments_find(rejected, component_part_id('report', 'retry')) == none
	assert 'exclamationmark.circle' in attachments_symbols(rejected)
	assert 'Upload failed' in attachments_labels(rejected)
	// Retry reaches the attachment only while failed.
	complete := attachment(AttachmentConfig{
		...attachments_report()
		retryable: true
	}) or { panic(err) }
	assert attachments_find(complete, component_part_id('report', 'retry')) == none
}

fn test_attachment_text_inherits_status_unless_overridden() {
	theme := ComponentTheme{}
	failed := attachment(AttachmentConfig{
		...attachments_report()
		status:             .failed
		description:        'Previous upload completed'
		description_status: .complete
	}) or { panic(err) }
	mut found := false
	for child in attachments_card(failed, 'report').children {
		if child.kind == .label && child.text == 'Previous upload completed' {
			assert child.text_style.color == theme.muted_foreground
			found = true
		}
	}
	assert found
	// A title told it is complete does not shimmer while the card uploads.
	steady := attachment(AttachmentConfig{
		...attachments_report()
		status:       .uploading
		title_status: .complete
	}) or { panic(err) }
	assert attachments_find(steady, component_part_id('report', 'title')) == none
	stop_attachment_animations('report')
}

fn test_attachment_pending_border_is_dashed() {
	el := attachment(AttachmentConfig{
		...attachments_report()
		status: .pending
	}) or { panic(err) }
	card := attachments_card(el, 'report')
	assert card.box.border_left == 0
	assert card.children.len > 20
	assert 'Ready to upload' in attachments_labels(el)
}

fn test_attachment_image_preview_and_tile() {
	preview := attachment(
		id:         'shot'
		name:       'screenshot.png'
		image_path: 'shot.png'
		status:     .uploading
	) or { panic(err) }
	images := attachments_images(preview)
	assert images.len == 1
	assert images[0].frame == rect(0, 0, 38, 38)
	stop_attachment_animations('shot')
	tile := attachment(
		id:           'tile'
		name:         'photo.png'
		image_path:   'photo.png'
		image_width:  400
		image_height: 200
		axis:         .vertical
		hide_content: true
	) or { panic(err) }
	assert tile.frame == rect(0, 0, 56, 56)
	assert attachments_labels(tile).len == 0
	assert tile.accessibility_label == 'photo.png, PNG'
	fitted := attachments_images(tile)
	assert fitted[0].frame == rect(0, 13.5, 54, 27)
}

fn test_attachment_actions_click_and_remove() {
	config := AttachmentConfig{
		...attachments_report()
		clickable: true
		removable: true
		actions:   [attachment_download_action(), AttachmentAction{
			id:      'share:1'
			label:   'Share'
			icon:    'square.and.arrow.up'
			enabled: false
		}]
	}
	el := attachment(config) or { panic(err) }
	assert el.hoverable
	card := attachments_card(el, 'report')
	assert card.button_behavior
	assert card.frame == rect(0, attachment_remove_overhang, 232, 56)
	remove := attachments_find(el, component_part_id('report', 'remove')) or { panic('no remove') }
	assert remove.frame == rect(232 + attachment_remove_overhang - 20, 0, 20, 20)
	assert !remove.hidden
	assert remove.accessibility_label == 'Remove quarterly-report.pdf'
	download := attachments_find(el, component_part_id('report', attachment_action_part('download'))) or {
		panic('no download')
	}
	assert download.tooltip == 'Download'
	assert download.enabled
	share := attachments_find(el, component_part_id('report', attachment_action_part('share:1'))) or {
		panic('no share')
	}
	assert !share.enabled
	hidden := attachment(AttachmentConfig{
		...config
		remove_on_hover: true
	}) or { panic(err) }
	assert (attachments_find(hidden, component_part_id('report', 'remove')) or { panic('') }).hidden
	shown := attachment(AttachmentConfig{
		...config
		remove_on_hover: true
		hovered:         true
	}) or { panic(err) }
	assert !(attachments_find(shown, component_part_id('report', 'remove')) or { panic('') }).hidden
	assert attachments_card(shown, 'report').box.bg != ComponentTheme{}.background
}

fn test_attachment_vertical_card_places_text_below_the_preview() {
	el := attachment(AttachmentConfig{
		...attachments_report()
		axis:       .vertical
		image_path: 'report.png'
		actions:    [attachment_open_action()]
	}) or { panic(err) }
	images := attachments_images(el)
	assert images[0].frame == rect(0, 0, 104, 104)
	card := attachments_card(el, 'report')
	mut title_y := 0.0
	for child in card.children {
		if child.kind == .label && child.accessibility_label == 'quarterly-report.pdf' {
			// Shortened in the middle to the card's width.
			assert child.text.ends_with('.pdf') && child.text.contains('…')
			title_y = child.frame.y
		}
	}
	assert title_y == 8 + 104 + 10
	open := attachments_find(el, component_part_id('report', attachment_action_part('open'))) or {
		panic('no open')
	}
	// The action rides the preview's upper trailing corner on a raised disc.
	assert open.frame.x + open.frame.width <= 120 - 8
	assert open.frame.y < 8 + 104
	assert !open.box.transparent
}

fn test_attachment_event_decoding() {
	config := AttachmentConfig{
		...attachments_report()
		clickable:       true
		removable:       true
		remove_on_hover: true
		retryable:       true
		actions:         [attachment_download_action(), AttachmentAction{
			id:      'share'
			label:   'Share'
			icon:    'square.and.arrow.up'
			enabled: false
		}]
	}
	card_action := component_part_id('report', 'card')
	click := attachment_event_from_action(config, card_action) or { panic('click rejected') }
	assert click.kind == .click && click.key == 'report'
	remove := attachment_event_from_action(config, component_part_id('report', 'remove')) or {
		panic('remove rejected')
	}
	assert remove.kind == .remove
	download := attachment_event_from_action(config, component_part_id('report', attachment_action_part('download'))) or {
		panic('download rejected')
	}
	assert download.kind == .action && download.action == 'download'
	// Retry only while failed.
	assert attachment_event_from_action(config, component_part_id('report', 'retry')) == none
	failed := AttachmentConfig{
		...config
		status: .failed
	}
	retry := attachment_event_from_action(failed, component_part_id('report', 'retry')) or {
		panic('retry rejected')
	}
	assert retry.kind == .retry
	// Foreign, malformed, disabled and forged actions are rejected.
	for action in ['report', 'other:component:card', component_part_id('report', ''),
		component_part_id('report', 'cardx'), component_part_id('report', 'action:'),
		component_part_id('report', 'action:zz'),
		component_part_id('report', 'action:646F776E6C6F6164'),
		component_part_id('report', attachment_action_part('share')),
		component_part_id('report', attachment_action_part('upload')),
		component_part_id('report', 'retry-link')] {
		assert attachment_event_from_action(config, action) == none, action
	}
	disabled := AttachmentConfig{
		...config
		enabled: false
	}
	assert attachment_event_from_action(disabled, card_action) == none
	assert attachment_event_from_action(AttachmentConfig{
		...config
		clickable: false
	}, card_action) == none
	// Hover: a change is an event, a repeat is not.
	hover := component_part_id('report', 'hover')
	start := attachment_event_from_action(config, 'pointer:enter:${hover}:4:5') or {
		panic('hover rejected')
	}
	assert start.kind == .hover_start
	assert attachment_event_from_action(config, 'pointer:leave:${hover}:4:5') == none
	hovered := AttachmentConfig{
		...config
		hovered: true
	}
	assert attachment_event_from_action(hovered, 'pointer:enter:${hover}:4:5') == none
	end := attachment_event_from_action(hovered, 'pointer:leave:${hover}:4:5') or {
		panic('leave rejected')
	}
	assert end.kind == .hover_end
	assert attachment_event_from_action(config, 'pointer:down:${hover}:4:5') == none
	assert attachment_event_from_action(attachments_report(), 'pointer:enter:${hover}:4:5') == none
}

// ── Group ───────────────────────────────────────────────────────────

fn attachments_group() AttachmentGroupConfig {
	return AttachmentGroupConfig{
		id:     'composer'
		frame:  rect(10, 20, 500, 80)
		status: .uploading
		items:  [
			AttachmentConfig{
				id:        'a'
				name:      'a.pdf'
				removable: true
			},
			AttachmentConfig{
				id:        'b'
				name:      'b.zip'
				status:    .failed
				retryable: true
			},
			AttachmentConfig{
				id:           'c'
				name:         'c.png'
				image_path:   'c.png'
				axis:         .vertical
				hide_content: true
			},
		]
	}
}

fn test_attachment_group_row_inherits_status_and_aligns_cards() {
	config := attachments_group()
	el := attachment_group(config) or { panic(err) }
	assert el.accessibility_role == 'list'
	scroller := attachments_find(el, attachment_group_scroll_id('composer')) or { panic('no scroll') }
	assert scroller.kind == .scroll
	assert scroller.scroll_mode == .horizontal_only
	assert scroller.children.len == 3
	a := scroller.children[0]
	b := scroller.children[1]
	c := scroller.children[2]
	assert a.id == attachment_group_item_id('composer', 'a')
	assert a.key == 'a'
	// Every card shares a top edge below the remove control's overhang.
	assert a.frame.y == 4
	assert b.frame.y == 4 + attachment_remove_overhang
	assert c.frame.y == 4 + attachment_remove_overhang
	assert b.frame.x == a.frame.width + 12
	// Inherited and own statuses.
	assert a.accessibility_value == 'Uploading'
	assert b.accessibility_value == 'Upload failed'
	assert c.accessibility_value == 'Uploading'
	frames := attachment_group_frames(config)
	assert frames.len == 3
	w, h := attachment_group_content_size(config)
	assert w == frames[2].x + frames[2].width
	assert h == 4 + attachment_remove_overhang + 56 + 12
	stop_attachment_animations('composer')
}

fn test_attachment_group_wrap_and_list_layouts() {
	base := attachments_group()
	wrapped := attachment_group_frames(AttachmentGroupConfig{
		...base
		frame:  rect(0, 0, 300, 400)
		layout: .wrap
	})
	assert wrapped[0].y == 0
	assert wrapped[1].x == 0
	assert wrapped[1].y > wrapped[0].y
	listed := attachment_group_frames(AttachmentGroupConfig{
		...base
		frame:  rect(0, 0, 400, 400)
		layout: .list
		gap:    8
	})
	// Chips stretch to the width; cards line up on the left and the right,
	// and every line leaves room above for a remove control.
	assert listed[0].width == 400
	assert listed[1].x == 0 && listed[1].width == 400 - attachment_remove_overhang
	assert listed[1].y == listed[0].y + listed[0].height + 8 + attachment_remove_overhang
	assert listed[2].width == 56
	el := attachment_group(AttachmentGroupConfig{
		...base
		layout: .list
	}) or { panic(err) }
	scroller := attachments_find(el, attachment_group_scroll_id('composer')) or { panic('no scroll') }
	assert scroller.kind == .scroll
	assert scroller.scroll_mode == .vertical_only
	// A list that fits does not scroll.
	roomy := attachment_group(AttachmentGroupConfig{
		...base
		frame:  rect(0, 0, 400, 400)
		layout: .list
	}) or { panic(err) }
	body := attachments_find(roomy, attachment_group_scroll_id('composer')) or { panic('no body') }
	assert body.kind == .view
	stop_attachment_animations('composer')
}

fn test_attachment_group_rejects_bad_items_and_shows_edge_fades() {
	if _ := attachment_group(AttachmentGroupConfig{
		id:    'g'
		items: [AttachmentConfig{
			id: 'x'
		}, AttachmentConfig{
			id: 'x'
		}]
	})
	{
		assert false, 'duplicate keys accepted'
	}
	if _ := attachment_group(AttachmentGroupConfig{
		id:    'g'
		items: [AttachmentConfig{}]
	})
	{
		assert false, 'empty key accepted'
	}
	if _ := attachment_group(AttachmentGroupConfig{
		items: []
	})
	{
		assert false, 'group accepted without an id'
	}
	narrow := AttachmentGroupConfig{
		...attachments_group()
		frame:     rect(0, 0, 200, 80)
		edge_fade: u32(0xffffff)
	}
	start := attachment_group(narrow) or { panic(err) }
	assert attachments_find(start, component_part_id('composer', 'fade:leading')) == none
	assert attachments_find(start, component_part_id('composer', 'fade:trailing')) != none
	middle := attachment_group(AttachmentGroupConfig{
		...narrow
		scroll_offset: 50
	}) or { panic(err) }
	assert attachments_find(middle, component_part_id('composer', 'fade:leading')) != none
	content_width, _ := attachment_group_content_size(narrow)
	end := attachment_group(AttachmentGroupConfig{
		...narrow
		scroll_offset: content_width - 200
	}) or { panic(err) }
	assert attachments_find(end, component_part_id('composer', 'fade:trailing')) == none
	stop_attachment_animations('composer')
}

fn test_attachment_group_event_decoding() {
	config := attachments_group()
	remove := attachment_group_event_from_action(config, component_part_id(attachment_group_item_id('composer',
		'a'), 'remove')) or { panic('remove rejected') }
	assert remove.kind == .remove && remove.key == 'a'
	// b failed itself; a inherits uploading, so it has no retry.
	retry := attachment_group_event_from_action(config, component_part_id(attachment_group_item_id('composer',
		'b'), 'retry')) or { panic('retry rejected') }
	assert retry.kind == .retry && retry.key == 'b'
	assert attachment_group_event_from_action(config, component_part_id(attachment_group_item_id('composer',
		'a'), 'retry')) == none
	// Removing b is not offered, and a key that left the group is gone.
	assert attachment_group_event_from_action(config, component_part_id(attachment_group_item_id('composer',
		'b'), 'remove')) == none
	assert attachment_group_event_from_action(config, component_part_id(attachment_group_item_id('composer',
		'z'), 'remove')) == none
	for action in ['composer', component_part_id('composer', 'item:'),
		component_part_id('composer', 'item:6G:component:remove'),
		component_part_id('composer', 'item:6A:component:remove'),
		component_part_id('other', 'item:61:component:remove'),
		component_part_id('composer', 'scroll')] {
		assert attachment_group_event_from_action(config, action) == none, action
	}
	disabled := AttachmentGroupConfig{
		...config
		enabled: false
	}
	assert attachment_group_event_from_action(disabled, component_part_id(attachment_group_item_id('composer',
		'a'), 'remove')) == none
	// Hover follows the group's hovered key.
	clickable := AttachmentGroupConfig{
		...config
		items: config.items.map(AttachmentConfig{
			...it
			clickable: true
		})
	}
	hover := component_part_id(attachment_group_item_id('composer', 'c'), 'hover')
	start := attachment_group_event_from_action(clickable, 'pointer:enter:${hover}:1:2') or {
		panic('hover rejected')
	}
	assert start.kind == .hover_start && start.key == 'c'
	assert attachment_group_event_from_action(AttachmentGroupConfig{
		...clickable
		hovered: 'c'
	}, 'pointer:enter:${hover}:1:2') == none
}

fn test_attachment_group_forgets_animations_of_removed_items() {
	config := attachments_group()
	attachment_group(config) or { panic(err) }
	spinner := component_part_id(attachment_group_item_id('composer', 'a'), 'spinner')
	mut running := false
	for name, _ in g_animation_runtime.runs {
		if name.starts_with(spinner) {
			running = true
		}
	}
	assert running
	attachment_group(AttachmentGroupConfig{
		...config
		items: config.items[1..]
	}) or { panic(err) }
	for name, _ in g_animation_runtime.runs {
		assert !name.starts_with(spinner), name
	}
	stop_attachment_animations('composer')
}
