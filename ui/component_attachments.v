// Copyright 2024 - 2026 Longbridge <https://longbridge.com>
// SPDX-License-Identifier: Apache-2.0
// Adapted from gpui-kit crates/component/src/attachment.rs. The size geometry,
// the status rules (title and description inherit the attachment's status
// unless they name their own, retry only while failed, progress only while
// uploading), the scrim strengths and the corner controls' metrics are ported
// to V; frame layout, file-type detection, sizes in words, the middle
// ellipsis, the dashed border, the rounded preview mask and action decoding
// are new UI2 implementations. See third_party/gpui-kit.
module ui2

import encoding.hex
import math

// AttachmentStatus is an attachment's place in its upload lifecycle. The
// application owns the upload and rebuilds with the status it is in.
pub enum AttachmentStatus {
	pending    // Chosen, not uploading yet: a dashed border.
	uploading  // A spinner, or with progress a ring, a bar and a percentage.
	processing // Uploaded and being processed: a spinner.
	failed     // A danger border and description, a retry control when offered.
	complete   // Ready. The default.
}

pub fn (status AttachmentStatus) is_pending() bool {
	return status == .pending
}

pub fn (status AttachmentStatus) is_uploading() bool {
	return status == .uploading
}

pub fn (status AttachmentStatus) is_processing() bool {
	return status == .processing
}

pub fn (status AttachmentStatus) is_failed() bool {
	return status == .failed
}

pub fn (status AttachmentStatus) is_complete() bool {
	return status == .complete
}

// is_in_progress is true while uploading or processing, when the title
// shimmers and the media shows a spinner.
pub fn (status AttachmentStatus) is_in_progress() bool {
	return status == .uploading || status == .processing
}

// description is the status in words, which an attachment shows when the
// application gives no description of its own.
pub fn (status AttachmentStatus) description() string {
	return match status {
		.pending { 'Ready to upload' }
		.uploading { 'Uploading' }
		.processing { 'Processing…' }
		.failed { 'Upload failed' }
		.complete { 'Ready' }
	}
}

// AttachmentFileKind is the family of a file, which picks its icon.
pub enum AttachmentFileKind {
	file // Anything else.
	image
	video
	audio
	pdf
	document
	text
	spreadsheet
	presentation
	archive
	code
}

// symbol is the icon a file of this kind shows; symbol_known is true for each.
pub fn (kind AttachmentFileKind) symbol() string {
	return match kind {
		.file { 'doc' }
		.image { 'photo' }
		.video { 'video' }
		.audio { 'mic' }
		.pdf, .document { 'doc.text.fill' }
		.text { 'text.alignleft' }
		.spreadsheet { 'tablecells' }
		.presentation { 'chart.bar.doc.horizontal' }
		.archive { 'square.stack.3d.up' }
		.code { 'curlybraces' }
	}
}

// title names the kind in words, for a file whose name has no extension.
pub fn (kind AttachmentFileKind) title() string {
	return match kind {
		.file { 'File' }
		.image { 'Image' }
		.video { 'Video' }
		.audio { 'Audio' }
		.pdf { 'PDF' }
		.document { 'Document' }
		.text { 'Text' }
		.spreadsheet { 'Spreadsheet' }
		.presentation { 'Presentation' }
		.archive { 'Archive' }
		.code { 'Code' }
	}
}

const attachment_extension_kinds = {
	'png':      AttachmentFileKind.image
	'jpg':      .image
	'jpeg':     .image
	'gif':      .image
	'webp':     .image
	'heic':     .image
	'heif':     .image
	'bmp':      .image
	'tif':      .image
	'tiff':     .image
	'svg':      .image
	'ico':      .image
	'avif':     .image
	'mp4':      .video
	'mov':      .video
	'm4v':      .video
	'avi':      .video
	'mkv':      .video
	'webm':     .video
	'wmv':      .video
	'mp3':      .audio
	'wav':      .audio
	'm4a':      .audio
	'aac':      .audio
	'flac':     .audio
	'ogg':      .audio
	'opus':     .audio
	'aiff':     .audio
	'pdf':      .pdf
	'doc':      .document
	'docx':     .document
	'rtf':      .document
	'odt':      .document
	'pages':    .document
	'txt':      .text
	'md':       .text
	'markdown': .text
	'log':      .text
	'xls':      .spreadsheet
	'xlsx':     .spreadsheet
	'csv':      .spreadsheet
	'tsv':      .spreadsheet
	'ods':      .spreadsheet
	'numbers':  .spreadsheet
	'ppt':      .presentation
	'pptx':     .presentation
	'odp':      .presentation
	'key':      .presentation
	'zip':      .archive
	'rar':      .archive
	'7z':       .archive
	'tar':      .archive
	'gz':       .archive
	'tgz':      .archive
	'bz2':      .archive
	'xz':       .archive
	'dmg':      .archive
	'iso':      .archive
	'v':        .code
	'c':        .code
	'h':        .code
	'cpp':      .code
	'hpp':      .code
	'rs':       .code
	'go':       .code
	'py':       .code
	'js':       .code
	'ts':       .code
	'tsx':      .code
	'jsx':      .code
	'java':     .code
	'kt':       .code
	'swift':    .code
	'rb':       .code
	'php':      .code
	'cs':       .code
	'sh':       .code
	'sql':      .code
	'json':     .code
	'xml':      .code
	'html':     .code
	'css':      .code
	'yaml':     .code
	'yml':      .code
	'toml':     .code
}

const attachment_mime_kinds = {
	'application/pdf':                                                           AttachmentFileKind.pdf
	'application/msword':                                                        .document
	'application/rtf':                                                           .document
	'application/vnd.openxmlformats-officedocument.wordprocessingml.document':   .document
	'application/vnd.oasis.opendocument.text':                                   .document
	'application/vnd.ms-excel':                                                  .spreadsheet
	'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':         .spreadsheet
	'application/vnd.oasis.opendocument.spreadsheet':                            .spreadsheet
	'text/csv':                                                                  .spreadsheet
	'application/vnd.ms-powerpoint':                                             .presentation
	'application/vnd.openxmlformats-officedocument.presentationml.presentation': .presentation
	'application/vnd.oasis.opendocument.presentation':                           .presentation
	'application/zip':                                                           .archive
	'application/gzip':                                                          .archive
	'application/x-tar':                                                         .archive
	'application/x-7z-compressed':                                               .archive
	'application/vnd.rar':                                                       .archive
	'application/x-rar-compressed':                                              .archive
	'application/json':                                                          .code
	'application/javascript':                                                    .code
	'application/xml':                                                           .code
	'text/html':                                                                 .code
	'text/css':                                                                  .code
	'text/javascript':                                                           .code
	'text/xml':                                                                  .code
}

// attachment_extension is a file name's extension in lower case, without the
// dot: `pdf` for `Report.PDF`, `tar.gz` for an archive named so, and empty for
// a name without one, including a dot file such as `.env`.
pub fn attachment_extension(name string) string {
	base := name.all_after_last('/').all_after_last('\\').trim_space()
	dot := base.last_index('.') or { return '' }
	if dot <= 0 || dot == base.len - 1 {
		return ''
	}
	ext := base[dot + 1..].to_lower()
	if ext.len > 10 || !ext.bytes().all(it.is_alnum()) {
		return ''
	}
	if ext in ['gz', 'bz2', 'xz'] && base[..dot].to_lower().ends_with('.tar') {
		return 'tar.' + ext
	}
	return ext
}

// attachment_file_kind decides what a file is from its MIME type, when that is
// one it knows, and otherwise from its name's extension.
pub fn attachment_file_kind(name string, mime string) AttachmentFileKind {
	essence := mime.all_before(';').trim_space().to_lower()
	if essence.len > 0 {
		if kind := attachment_mime_kinds[essence] {
			return kind
		}
		family := essence.all_before('/')
		match family {
			'image' { return .image }
			'video' { return .video }
			'audio' { return .audio }
			else {}
		}
	}
	ext := attachment_extension(name)
	if ext.starts_with('tar.') {
		return .archive
	}
	if kind := attachment_extension_kinds[ext] {
		return kind
	}
	if essence.starts_with('text/') {
		return .text
	}
	return .file
}

// attachment_type_text is how the description names a file's type: its
// extension in capitals, or the kind's title when it has none.
pub fn attachment_type_text(name string, mime string) string {
	ext := attachment_extension(name)
	if ext.len > 0 {
		return ext.to_upper()
	}
	kind := attachment_file_kind(name, mime)
	return if kind == .file && name.len == 0 && mime.len == 0 { '' } else { kind.title() }
}

// attachment_size_text writes a byte count the way a person reads it: `512 B`,
// `2.4 MB`, `18 KB`. Units are powers of 1024, with one decimal below ten. A
// negative count is unknown and gives an empty string.
pub fn attachment_size_text(bytes i64) string {
	if bytes < 0 {
		return ''
	}
	if bytes < 1024 {
		return '${bytes} B'
	}
	units := ['KB', 'MB', 'GB', 'TB', 'PB', 'EB']
	mut value := f64(bytes) / 1024
	mut unit := 0
	for value >= 1024 && unit < units.len - 1 {
		value /= 1024
		unit++
	}
	mut shown := if value < 10 { math.round(value * 10) / 10 } else { math.round(value) }
	// Rounding can reach the next unit: 1023.7 KB is shown as 1 MB.
	if shown >= 1024 && unit < units.len - 1 {
		shown = 1
		unit++
	}
	number := if shown < 10 && shown != math.round(shown) {
		'${shown:.1f}'
	} else {
		'${i64(shown)}'
	}
	return '${number} ${units[unit]}'
}

// attachment_meta_text is the default description of a ready file: its type
// and size, such as `PDF · 2.4 MB`, leaving out whichever is unknown.
pub fn attachment_meta_text(name string, mime string, bytes i64) string {
	return [attachment_type_text(name, mime), attachment_size_text(bytes)].filter(it.len > 0).join(' · ')
}

// attachment_glyph_em is about how wide a character is, in ems, in a bold
// sans-serif face such as SF or Roboto. component_text_width_estimate gives
// every Latin character the same width, which overstates a lower-case file
// name by a fifth and understates one full of m and w.
fn attachment_glyph_em(r rune) f64 {
	if r >= 0x2e80 {
		return 1.0
	}
	if r in [`i`, `l`, `j`, `.`, `,`, `:`, `;`, `'`, `|`, `!`] {
		return 0.3
	}
	if r in [`f`, `t`, `r`, `-`, `(`, `)`, `[`, `]`, ` `, `I`, `/`, `\\`] {
		return 0.4
	}
	if r in [`m`, `w`] {
		return 0.85
	}
	if r in [`M`, `W`] {
		return 0.92
	}
	if r >= `A` && r <= `Z` {
		return 0.7
	}
	if r >= `0` && r <= `9` {
		return 0.6
	}
	return if r == `…` { 0.8 } else { 0.58 }
}

// attachment_text_width estimates how wide text renders in bold at font_size,
// a little generously, character by character.
pub fn attachment_text_width(text string, font_size f64) f64 {
	mut ems := 0.0
	for r in text.runes() {
		ems += attachment_glyph_em(r)
	}
	return ems * font_em_pixels(font_size) * 1.04
}

// attachment_middle_ellipsis shortens text to fit width at font_size by
// taking characters out of its middle, so the start of a file name and its
// extension stay readable: `quarterly-fin…report.pdf`. Widths are
// attachment_text_width estimates.
pub fn attachment_middle_ellipsis(text string, width f64, font_size f64) string {
	if attachment_text_width(text, font_size) <= width {
		return text
	}
	runes := text.runes()
	budget := width - attachment_text_width('…', font_size)
	if budget <= 0 || runes.len == 0 {
		return if width > 0 { '…' } else { '' }
	}
	widths := runes.map(attachment_text_width(it.str(), font_size))
	// The end keeps the extension and the two characters before it when they fit.
	mut min_tail := 0
	for i := runes.len - 1; i > 0; i-- {
		if runes[i] == `.` {
			if runes.len - i <= 11 {
				min_tail = runes.len - i + 2
			}
			break
		}
	}
	mut head := 0
	mut tail := 0
	mut used := 0.0
	for head + tail < runes.len {
		take_tail := tail < min_tail || head > tail
		index := if take_tail { runes.len - 1 - tail } else { head }
		if used + widths[index] > budget {
			break
		}
		used += widths[index]
		if take_tail {
			tail++
		} else {
			head++
		}
	}
	return runes[..head].string() + '…' + runes[runes.len - tail..].string()
}

// AttachmentMetrics is the geometry of one attachment size.
pub struct AttachmentMetrics {
pub:
	height           f64 // A horizontal chip's height, and the side of an image tile.
	chip_width       f64 // A horizontal chip's width when it has a title or description.
	card_width       f64 // A vertical card's width.
	media            f64 // The media square of a horizontal chip.
	glyph            f64 // The file-type and status glyphs in a chip's media.
	padding_start    f64 // Before a chip's media.
	padding_end      f64 // After a chip's text and actions.
	card_padding     f64 // Around a vertical card's preview and text.
	gap              f64 // Between media, text and actions.
	title_size       f64
	description_size f64
	radius           f64 // The card's corners.
	media_radius     f64
	action           f64 // An action button's side.
}

// attachment_metrics follows GPUI Kit's Small, Medium and Large attachments
// at a 16 px rem: medium chips are 232 × 56 with 38 px media. A vertical card
// is wider at each size, where upstream keeps it 120 wide.
pub fn attachment_metrics(size ComponentSize) AttachmentMetrics {
	return match size {
		.small {
			AttachmentMetrics{
				height:           48
				chip_width:       200
				card_width:       104
				media:            32
				glyph:            16
				padding_start:    6
				padding_end:      8
				card_padding:     6
				gap:              8
				title_size:       12
				description_size: 11
				radius:           8
				media_radius:     6
				action:           22
			}
		}
		.medium {
			AttachmentMetrics{
				height:           56
				chip_width:       232
				card_width:       120
				media:            38
				glyph:            20
				padding_start:    8
				padding_end:      12
				card_padding:     8
				gap:              10
				title_size:       13
				description_size: 12
				radius:           8
				media_radius:     6
				action:           24
			}
		}
		.large {
			AttachmentMetrics{
				height:           64
				chip_width:       272
				card_width:       144
				media:            44
				glyph:            24
				padding_start:    10
				padding_end:      16
				card_padding:     12
				gap:              12
				title_size:       14
				description_size: 13
				radius:           8
				media_radius:     6
				action:           28
			}
		}
	}
}

// The remove control rides this far outside the card's upper trailing corner,
// and the attachment's frame makes room for it.
pub const attachment_remove_overhang = 6.0
const attachment_remove_size = 20.0
const attachment_remove_glyph = 10.0
const attachment_retry_size = 24.0
const attachment_retry_glyph = 12.0
const attachment_bar_thickness = 2.0
const attachment_text_gap = 2.0
// A title is shortened to its width less the inset a native text cell keeps.
const attachment_name_inset = 4.0
// How much an image preview is darkened while in progress, and once failed.
const attachment_progress_scrim = 0.35
const attachment_failed_scrim = 0.55
// The dark disc a spinner or progress ring sits on over an image preview.
const attachment_badge_color = u32(0x1f2329)

// AttachmentAction is a button in an attachment's action slot.
pub struct AttachmentAction {
pub:
	id      string // Unique in the attachment; attachment_event_from_action reports it.
	label   string // The tooltip and accessible name, shown as text when there is no icon.
	icon    string // A symbol name symbol_known accepts.
	enabled bool = true
}

// attachment_download_action is a ready-made Download action.
pub fn attachment_download_action() AttachmentAction {
	return AttachmentAction{
		id:    'download'
		label: 'Download'
		icon:  'arrow.down.to.line'
	}
}

// attachment_open_action is a ready-made Open action.
pub fn attachment_open_action() AttachmentAction {
	return AttachmentAction{
		id:    'open'
		label: 'Open'
		icon:  'arrow.up.right.square'
	}
}

// AttachmentConfig describes GPUI Kit's Attachment: one file or image with a
// media preview, a title and description, a lifecycle status and controls.
pub struct AttachmentConfig {
pub:
	// id is required when the attachment has a control or is uploading or
	// processing, since its animations run on its parts. In a group it is the
	// item's key.
	id string
	// frame places the attachment. A zero width or height takes the natural
	// extent for the size and axis (attachment_natural_size). It includes the
	// remove control's overhang above and after the card.
	frame Rect
	name  string // The file name: the default title, file type, icon and accessible name.
	mime  string // Picks the file type when the name's extension does not.
	bytes i64 = -1 // The file size in the default description; negative is unknown.
	title string // Shown instead of name.
	// description replaces the default: the type and size (`PDF · 2.4 MB`) when
	// ready, and the status in words otherwise.
	description string
	// error_message is the failure reason: the description while failed, and
	// the tooltip unless one is set.
	error_message string
	icon          string // A symbol shown instead of the file type's icon.
	// image_path shows an image preview instead of an icon. It is scaled into
	// the media square; give image_width and image_height (its pixel size) to
	// fit a non-square image inside it alike on every renderer.
	image_path   string
	image_width  f64
	image_height f64
	status       ?AttachmentStatus // None is complete, or a group's status.
	// title_status and description_status override the status their text
	// follows: the title shimmers while in progress, the description turns
	// the danger color once failed.
	title_status       ?AttachmentStatus
	description_status ?AttachmentStatus
	// progress is the upload's percent, 0...100. While uploading it turns the
	// spinner into a ring, draws a bar along a chip's bottom edge and adds the
	// percentage to the description. It is ignored in other statuses.
	progress ?f64
	tooltip  string
	axis     LayoutOrientation = .horizontal // Vertical puts the preview above the text.
	size     ComponentSize     = .medium
	// hide_media and hide_content leave out the preview or the text; a
	// vertical attachment without text is a square image tile.
	hide_media   bool
	hide_content bool
	clickable    bool // The whole card is a button (click events).
	removable    bool // A remove control on the card's upper trailing corner.
	// remove_on_hover shows the remove control only while hovered is set, as
	// on GPUI's desktop. Leave it off on touch screens.
	remove_on_hover bool
	retryable       bool // A retry control while failed.
	actions         []AttachmentAction
	// hovered is the hover state the application keeps from hover events. A
	// clickable card takes a muted surface while hovered.
	hovered       bool
	enabled       bool = true
	reduce_motion bool // Spinners rest and the title does not shimmer.
	// surface is the color behind the attachment, default the theme's
	// background. The custom renderer, which does not clip, paints it round an
	// image tile's corners to round them.
	surface             ?u32
	accessibility_label string // Defaults to the title and description.
	theme               ComponentTheme
}

// AttachmentEventKind is what an attachment's action asked for.
pub enum AttachmentEventKind {
	click       // The whole card.
	remove      // The remove control.
	retry       // The retry control, while failed.
	action      // A custom action; AttachmentEvent.action names it.
	hover_start // The pointer came over the attachment.
	hover_end   // The pointer left it.
}

// AttachmentEvent is a decoded attachment action.
pub struct AttachmentEvent {
pub:
	kind   AttachmentEventKind
	key    string // The attachment's id, or its item key in a group.
	action string // The custom action's id, for .action.
}

// AttachmentResolved is a config with its inherited status applied and its
// derived text worked out, shared by the builder and the decoder.
struct AttachmentResolved {
	status             AttachmentStatus
	title_status       AttachmentStatus
	description_status AttachmentStatus
	has_progress       bool
	progress           f64
	kind               AttachmentFileKind
	title              string
	description        string
	content            bool
	media              bool
	retry              bool
	hover              bool
	tooltip            string
}

fn attachment_resolve(config AttachmentConfig, inherited AttachmentStatus) AttachmentResolved {
	status := config.status or { inherited }
	title_status := config.title_status or { status }
	description_status := config.description_status or { status }
	mut has_progress := false
	mut progress := 0.0
	if status == .uploading {
		if value := config.progress {
			has_progress = true
			progress = progress_percent(value)
		}
	}
	title := if config.title.len > 0 { config.title } else { config.name }
	mut description := if description_status == .failed && config.error_message.len > 0 {
		config.error_message
	} else {
		config.description
	}
	if description.len == 0 {
		description = if description_status == .complete {
			attachment_meta_text(config.name, config.mime, config.bytes)
		} else {
			description_status.description()
		}
	}
	if has_progress && description.len > 0 {
		description += ' · ${i64(math.round(progress))}%'
	}
	content := !config.hide_content && (title.len > 0 || description.len > 0)
	return AttachmentResolved{
		status:             status
		title_status:       title_status
		description_status: description_status
		has_progress:       has_progress
		progress:           progress
		kind:               attachment_file_kind(config.name, config.mime)
		title:              title
		description:        description
		content:            content
		media:              !config.hide_media
		retry:              config.retryable && status == .failed
		hover:              config.enabled && (config.clickable
			|| (config.removable && config.remove_on_hover))
		tooltip:            if config.tooltip.len > 0 {
			config.tooltip
		} else if status == .failed {
			config.error_message
		} else {
			''
		}
	}
}

fn attachment_needs_id(config AttachmentConfig, r AttachmentResolved) bool {
	return config.clickable || config.removable || r.retry || config.actions.len > 0
		|| r.status.is_in_progress() || r.title_status.is_in_progress()
}

fn attachment_validate(config AttachmentConfig) ! {
	if !component_finite(config.image_width) || config.image_width < 0
		|| !component_finite(config.image_height) || config.image_height < 0 {
		return error('attachment image size must be finite and non-negative')
	}
	if config.icon.len > 0 && !symbol_known(config.icon) {
		return error('attachment icon `${config.icon}` is not drawn on every backend; see symbol_names()')
	}
	mut seen := map[string]bool{}
	for action in config.actions {
		if action.id.trim_space().len == 0 || action.id in seen {
			return error('attachment action ids must be non-empty and unique')
		}
		seen[action.id] = true
		if action.icon.len > 0 && !symbol_known(action.icon) {
			return error('attachment action icon `${action.icon}` is not drawn on every backend; see symbol_names()')
		}
		if action.icon.len == 0 && action.label.trim_space().len == 0 {
			return error('an attachment action needs an icon or a label')
		}
	}
}

// attachment_action_part names a custom action's part: its id in hex, so any
// id round-trips through the action string.
fn attachment_action_part(action_id string) string {
	return 'action:' + action_id.bytes().hex()
}

// attachment_hex_text decodes the lowercase hex an attachment wrote into an
// action; other spellings of the same bytes are not what it wrote.
fn attachment_hex_text(digits string) ?string {
	if digits.len == 0 {
		return none
	}
	bytes := hex.decode(digits) or { return none }
	if bytes.hex() != digits {
		return none
	}
	return bytes.bytestr()
}

fn attachment_title_height(m AttachmentMetrics) f64 {
	return math.round(m.title_size * 1.35)
}

fn attachment_description_height(m AttachmentMetrics) f64 {
	return math.round(m.description_size * 1.35)
}

// attachment_text_height is how tall the title and description stack is.
fn attachment_text_height(r AttachmentResolved, m AttachmentMetrics) f64 {
	if !r.content {
		return 0
	}
	has_title := r.title.len > 0
	has_description := r.description.len > 0
	mut height := 0.0
	if has_title {
		height += attachment_title_height(m)
	}
	if has_title && has_description {
		height += attachment_text_gap
	}
	if has_description {
		height += attachment_description_height(m)
	}
	return height
}

fn attachment_action_width(action AttachmentAction, m AttachmentMetrics) f64 {
	if action.icon.len > 0 {
		return m.action
	}
	return math.ceil(component_text_width_estimate(action.label, m.description_size)) + 12
}

// attachment_actions_width is how wide a row of actions is, with 4 between.
fn attachment_actions_width(actions []AttachmentAction, m AttachmentMetrics) f64 {
	mut width := 0.0
	for index, action in actions {
		width += attachment_action_width(action, m) + if index > 0 { 4.0 } else { 0.0 }
	}
	return width
}

// attachment_card_width is the card's natural width, without the overhang.
fn attachment_card_width(config AttachmentConfig, r AttachmentResolved, m AttachmentMetrics) f64 {
	if config.axis == .vertical {
		return if r.content { m.card_width } else { m.height }
	}
	if r.content {
		return m.chip_width
	}
	// Without text a chip hugs its media and actions.
	mut width := m.padding_start * 2
	if r.media {
		width += m.media
	}
	if config.actions.len > 0 {
		width += attachment_actions_width(config.actions, m) + if r.media { m.gap } else { 0.0 }
	}
	return width
}

// attachment_card_height is the card's natural height at a width.
fn attachment_card_height(config AttachmentConfig, r AttachmentResolved, m AttachmentMetrics, width f64) f64 {
	if config.axis == .horizontal || !r.content {
		return if config.axis == .vertical { width } else { m.height }
	}
	mut height := m.card_padding * 2 + attachment_text_height(r, m)
	if r.media {
		height += math.max(width - 2 * m.card_padding, 0) + m.gap
	}
	return height
}

// attachment_natural_size is the width and height an attachment takes when
// its frame leaves them zero, including the remove control's overhang.
pub fn attachment_natural_size(config AttachmentConfig) (f64, f64) {
	return attachment_natural_size_with(config, attachment_resolve(config, .complete))
}

fn attachment_natural_size_with(config AttachmentConfig, r AttachmentResolved) (f64, f64) {
	m := attachment_metrics(config.size)
	over := if config.removable { attachment_remove_overhang } else { 0.0 }
	width := attachment_card_width(config, r, m)
	return width + over, attachment_card_height(config, r, m, width) + over
}

// attachment_image_fit is where an image of the given pixel size sits inside
// box: scaled to fit and centered. An unknown size fills the box.
pub fn attachment_image_fit(box Rect, image_width f64, image_height f64) Rect {
	if image_width <= 0 || image_height <= 0 || box.width <= 0 || box.height <= 0 {
		return box
	}
	scale := math.min(box.width / image_width, box.height / image_height)
	width := image_width * scale
	height := image_height * scale
	return rect(box.x + (box.width - width) / 2, box.y + (box.height - height) / 2, width,
		height)
}

// attachment_dash_gaps lists where the card's border is interrupted to look
// dashed: dash-long strokes with gap-long breaks along the straight part of
// each edge, centered so both ends of an edge match. The rounded corners stay
// whole. Each Rect is a break on the border line.
fn attachment_dash_gaps(width f64, height f64, radius f64, dash f64, gap f64) []Rect {
	mut gaps := []Rect{}
	for edge in 0 .. 4 {
		horizontal := edge < 2
		length := (if horizontal { width } else { height }) - 2 * radius
		if length <= dash {
			continue
		}
		count := int((length - dash) / (dash + gap))
		used := f64(count) * (dash + gap) + dash
		start := radius + (length - used) / 2 + dash
		for i in 0 .. count {
			at := start + f64(i) * (dash + gap)
			gaps << match edge {
				0 { rect(at, 0, gap, 1) }
				1 { rect(at, height - 1, gap, 1) }
				2 { rect(0, at, 1, gap) }
				else { rect(width - 1, at, 1, gap) }
			}
		}
	}
	return gaps
}

// attachment_round_mask rounds the corners of whatever fills frame on the
// custom renderer, which does not clip to a rounded view: a ring in color
// hugging frame from outside, its inner edge the rounded outline. AppKit,
// UIKit and Win32 clip already, and there the ring falls on the color around
// it.
fn attachment_round_mask(frame Rect, radius f64, color u32) Element {
	band := math.ceil(radius * 0.42) + 1
	return view('', rect(frame.x - band, frame.y - band, frame.width + 2 * band, frame.height +
		2 * band), BoxStyle{
		transparent:   true
		radius:        radius + band
		border_color:  color
		border_left:   band
		border_top:    band
		border_right:  band
		border_bottom: band
	}, []Element{})
}

fn attachment_symbol(name string, frame Rect, color u32) Element {
	return Element{
		...image('', 'symbol:' + name, frame)
		text_style: TextStyle{
			color: color
			size:  frame.height
		}
	}
}

fn attachment_centered(box Rect, side f64) Rect {
	return rect(box.x + (box.width - side) / 2, box.y + (box.height - side) / 2, side,
		side)
}

// attachment_quiet stops the animations of parts the attachment is not
// showing, so a spinner or shimmer that went away does not keep the native
// backend redrawing.
fn attachment_quiet(config AttachmentConfig, r AttachmentResolved) {
	if config.id.len == 0 {
		return
	}
	media_busy := r.media && r.status.is_in_progress()
	if !media_busy || r.has_progress || config.reduce_motion {
		stop_feedback_animations(component_part_id(config.id, 'spinner'))
	}
	if !r.content || !r.title_status.is_in_progress() || config.reduce_motion {
		stop_feedback_animations(component_part_id(config.id, 'title'))
	}
	if !r.has_progress || config.axis != .horizontal {
		stop_feedback_animations(component_part_id(config.id, 'bar'))
	}
}

// stop_attachment_animations stops every animation an attachment started
// under id: call it when an uploading or processing attachment leaves the
// screen. attachment_group does this for items that leave the group.
pub fn stop_attachment_animations(id string) {
	stop_feedback_animations(id)
}

fn attachment_busy(config AttachmentConfig, r AttachmentResolved, box Rect, color u32, background u32) !Element {
	big := box.width >= 64
	if r.has_progress {
		diameter := if big { 32.0 } else { 20.0 }
		return progress_circle(
			id:                  component_part_id(config.id, 'ring')
			frame:               attachment_centered(box, diameter)
			value:               r.progress
			diameter:            diameter
			color:               color
			background:          background
			accessibility_label: 'Upload progress'
			theme:               config.theme
		)!
	}
	side := if big { 24.0 } else { 16.0 }
	return loading_spinner(
		id:                  component_part_id(config.id, 'spinner')
		frame:               attachment_centered(box, side)
		diameter:            side
		color:               color
		background:          background
		reduce_motion:       config.reduce_motion
		accessibility_label: r.status.description()
		theme:               config.theme
	)!
}

fn attachment_retry_disc(config AttachmentConfig, r AttachmentResolved, box Rect) Element {
	side := math.min(attachment_retry_size, math.max(box.width - 10, 16))
	glyph := math.min(attachment_retry_glyph, math.round(side / 2))
	return Element{
		...button_view(component_part_id(config.id, 'retry'), attachment_centered(box, side),
			BoxStyle{
				bg:     config.theme.background
				radius: side / 2
				shadow: box_shadow(0x000000, 0.2, 4, 1)
			}, [
				attachment_symbol('arrow.clockwise', rect((side - glyph) / 2, (side - glyph) / 2,
					glyph, glyph), if config.enabled {
					config.theme.danger
				} else {
					config.theme.muted_foreground
				}),
			])
		enabled:             config.enabled
		cursor:              cursor_pointing_hand
		tooltip:             'Retry'
		accessibility_label: 'Retry ${r.title}'.trim_space()
	}
}

// attachment_media draws the media slot in frame: the image or file-type icon,
// with the status treatment over it.
fn attachment_media(config AttachmentConfig, r AttachmentResolved, m AttachmentMetrics, frame Rect, radius f64) ![]Element {
	theme := config.theme
	local := component_local(frame)
	has_image := config.image_path.len > 0
	failed_icon := r.status == .failed && !has_image
	fill := if failed_icon {
		interpolate_color(theme.danger, theme.background, 0.88)
	} else {
		theme.muted
	}
	mut children := []Element{}
	if has_image {
		children << image('', config.image_path, attachment_image_fit(local, config.image_width,
			config.image_height))
		if r.status.is_in_progress() || r.status == .failed {
			children << view('', local, BoxStyle{
				bg:      0x000000
				opacity: if r.status == .failed {
					attachment_failed_scrim
				} else {
					attachment_progress_scrim
				}
				radius:  radius
			}, []Element{})
		}
		if r.status.is_in_progress() {
			big := frame.width >= 64
			disc := if big { 44.0 } else { 28.0 }
			children << view('', attachment_centered(local, disc), BoxStyle{
				bg:     attachment_badge_color
				radius: disc / 2
			}, []Element{})
			children << attachment_busy(config, r, attachment_centered(local, disc), 0xffffff,
				attachment_badge_color)!
		} else if r.status == .failed {
			if r.retry {
				children << attachment_retry_disc(config, r, local)
			} else {
				children << attachment_symbol('exclamationmark.circle', attachment_centered(local,
					m.glyph), 0xffffff)
			}
		}
	} else {
		glyph := if config.axis == .vertical && frame.width >= 64 {
			math.round(frame.width * 0.3)
		} else {
			m.glyph
		}
		if r.status.is_in_progress() {
			children << attachment_busy(config, r, local, theme.primary, fill)!
		} else if r.status == .failed {
			if r.retry {
				children << attachment_retry_disc(config, r, local)
			} else {
				children << attachment_symbol('exclamationmark.circle', attachment_centered(local,
					glyph), theme.danger)
			}
		} else {
			symbol := if config.icon.len > 0 { config.icon } else { r.kind.symbol() }
			children << Element{
				...attachment_symbol(symbol, attachment_centered(local, glyph), theme.foreground)
				accessibility_role:  'img'
				accessibility_label: r.kind.title()
			}
		}
	}
	return [
		view('', frame, BoxStyle{
			bg:     fill
			radius: radius
		}, children),
	]
}

// attachment_text lays the title and description out in area: centered in a
// chip, from the top in a vertical card.
fn attachment_text(config AttachmentConfig, r AttachmentResolved, m AttachmentMetrics, area Rect, vertical bool) ![]Element {
	theme := config.theme
	mut children := []Element{}
	title_height := attachment_title_height(m)
	description_height := attachment_description_height(m)
	total := attachment_text_height(r, m)
	mut y := if vertical { area.y } else { area.y + math.round((area.height - total) / 2) }
	if r.title.len > 0 {
		shown := attachment_middle_ellipsis(r.title, math.max(area.width - attachment_name_inset,
			0), m.title_size)
		frame := rect(area.x, y, area.width, title_height)
		if r.title_status.is_in_progress() && config.id.len > 0 {
			children << shimmer_text(
				id:                  component_part_id(config.id, 'title')
				frame:               frame
				text:                shown
				color:               theme.foreground
				font_size:           m.title_size
				bold:                true
				reduce_motion:       config.reduce_motion
				accessibility_label: r.title
				theme:               theme
			)!
		} else {
			children << Element{
				...label('', shown, frame, TextStyle{
					color: theme.foreground
					size:  m.title_size
					bold:  true
				})
				accessibility_label: r.title
			}
		}
		y += title_height + attachment_text_gap
	}
	if r.description.len > 0 {
		color := if r.description_status == .failed { theme.danger } else { theme.muted_foreground }
		style := TextStyle{
			color: color
			size:  m.description_size
		}
		if r.retry {
			// The link sits at the end of the line, where it lines up from card to
			// card whatever the estimate makes of the text before it.
			retry_width := math.min(math.ceil(component_text_width_estimate('Retry', m.description_size)) + 4,
				area.width)
			children << label('', r.description, rect(area.x, y, math.max(area.width - retry_width - 4,
				0), description_height), style)
			children << Element{
				...button_view(component_part_id(config.id, 'retry-link'), rect(area.x +
					area.width - retry_width, y, retry_width, description_height), BoxStyle{
					transparent: true
				}, [
					label('', 'Retry', rect(0, 0, retry_width, description_height), TextStyle{
						color: if config.enabled { theme.primary } else { theme.muted_foreground }
						size:  m.description_size
						bold:  true
						align: .right
					}),
				])
				action_id:           component_part_id(config.id, 'retry')
				enabled:             config.enabled
				cursor:              cursor_pointing_hand
				accessibility_label: 'Retry ${r.title}'.trim_space()
			}
		} else {
			children << label('', r.description, rect(area.x, y, area.width, description_height),
				style)
		}
	}
	return children
}

// attachment_action_buttons lays the custom actions out from x. Over a
// vertical card's preview they are discs on the surface color; in a chip they
// are bare glyphs.
fn attachment_action_buttons(config AttachmentConfig, r AttachmentResolved, m AttachmentMetrics, x f64, y f64, raised bool) []Element {
	theme := config.theme
	mut children := []Element{}
	mut left := x
	for action in config.actions {
		width := attachment_action_width(action, m)
		enabled := config.enabled && action.enabled
		color := if enabled { theme.foreground } else { theme.muted_foreground }
		content := if action.icon.len > 0 {
			glyph := math.round(m.action * 0.58)
			attachment_symbol(action.icon, rect((width - glyph) / 2, (m.action - glyph) / 2,
				glyph, glyph), color)
		} else {
			label('', action.label, rect(0, 0, width, m.action), TextStyle{
				color: if enabled { theme.primary } else { theme.muted_foreground }
				size:  m.description_size
				bold:  true
				align: .center
			})
		}
		box := if raised {
			BoxStyle{
				bg:            theme.background
				radius:        if action.icon.len > 0 { m.action / 2 } else { m.media_radius }
				border_color:  theme.border
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
			}
		} else {
			BoxStyle{
				transparent: true
				radius:      m.media_radius
			}
		}
		children << Element{
			...button_view(component_part_id(config.id, attachment_action_part(action.id)),
				rect(left, y, width, m.action), box, [content])
			key:                 'action:' + action.id
			enabled:             enabled
			cursor:              cursor_pointing_hand
			tooltip:             action.label
			accessibility_label: '${action.label} ${r.title}'.trim_space()
		}
		left += width + 4
	}
	return children
}

// attachment_summary is the attachment's accessible name and the status it
// announces.
fn attachment_summary(config AttachmentConfig, r AttachmentResolved) (string, string) {
	name := if config.accessibility_label.len > 0 {
		config.accessibility_label
	} else {
		[r.title, r.description].filter(it.len > 0).join(', ')
	}
	mut value := r.status.description()
	if r.has_progress {
		value += ' ${progress_value_text(r.progress)}'
	}
	return name, value
}

pub fn attachment(config AttachmentConfig) !Element {
	return attachment_build(config, .complete)
}

fn attachment_build(config AttachmentConfig, inherited AttachmentStatus) !Element {
	component_validate_frame(config.frame)!
	r := attachment_resolve(config, inherited)
	if attachment_needs_id(config, r) {
		component_validate_id(config.id)!
	}
	attachment_validate(config)!
	attachment_quiet(config, r)
	theme := config.theme
	m := attachment_metrics(config.size)
	over := if config.removable { attachment_remove_overhang } else { 0.0 }
	card_width := if config.frame.width > 0 {
		math.max(config.frame.width - over, 0)
	} else {
		attachment_card_width(config, r, m)
	}
	card_height := if config.frame.height > 0 {
		math.max(config.frame.height - over, 0)
	} else {
		attachment_card_height(config, r, m, card_width)
	}
	vertical := config.axis == .vertical
	tile := vertical && !r.content
	hovered := r.hover && config.hovered
	surface := if hovered && config.clickable {
		interpolate_color(theme.muted, theme.background, 0.5)
	} else {
		theme.background
	}
	behind := config.surface or { theme.background }
	border := if r.status == .failed { theme.danger } else { theme.border }
	dashed := r.status == .pending
	mut children := []Element{}
	if dashed {
		// The border is a ring of its own, with breaks painted over its straight
		// runs: AppKit draws a view's own border above its children.
		children << view('', rect(0, 0, card_width, card_height), BoxStyle{
			transparent:   true
			radius:        m.radius
			border_color:  interpolate_color(theme.border, theme.muted_foreground, 0.35)
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
		}, []Element{})
		for gap in attachment_dash_gaps(card_width, card_height, m.radius, 5, 3) {
			children << view('', gap, BoxStyle{ bg: surface }, []Element{})
		}
	}
	if vertical {
		if r.media {
			if tile {
				inner := rect(1, 1, math.max(card_width - 2, 0), math.max(card_height - 2, 0))
				inner_radius := math.max(m.radius - 1, 0)
				children << attachment_media(config, r, m, inner, inner_radius)!
				if config.image_path.len > 0 {
					children << attachment_round_mask(rect(0, 0, card_width, card_height),
						m.radius, behind)
					// The mask covers the card's border; draw it again on top.
					children << view('', rect(0, 0, card_width, card_height), BoxStyle{
						transparent:   true
						radius:        m.radius
						border_color:  border
						border_left:   if dashed { 0.0 } else { 1.0 }
						border_top:    if dashed { 0.0 } else { 1.0 }
						border_right:  if dashed { 0.0 } else { 1.0 }
						border_bottom: if dashed { 0.0 } else { 1.0 }
					}, []Element{})
				}
			} else {
				side := math.max(card_width - 2 * m.card_padding, 0)
				frame := rect(m.card_padding, m.card_padding, side, side)
				children << attachment_media(config, r, m, frame, m.media_radius)!
				if config.image_path.len > 0 {
					children << attachment_round_mask(frame, m.media_radius, surface)
				}
			}
		}
		if r.content {
			top := if r.media {
				m.card_padding + math.max(card_width - 2 * m.card_padding, 0) + m.gap
			} else {
				m.card_padding
			}
			children << attachment_text(config, r, m, rect(m.card_padding + 4, top, math.max(card_width - 2 * m.card_padding - 8,
				0), math.max(card_height - top - m.card_padding, 0)), true)!
		}
		if config.actions.len > 0 {
			inset := m.card_padding + 4
			width := attachment_actions_width(config.actions, m)
			children << attachment_action_buttons(config, r, m, card_width - inset - width - if config.removable {
				6.0
			} else {
				0.0
			}, inset + if config.removable { 6.0 } else { 0.0 }, true)
		}
	} else {
		mut left := if r.media || r.content { m.padding_start } else { m.padding_end }
		if r.media {
			side := math.min(m.media, math.max(card_height - 2, 0))
			frame := rect(left, math.round((card_height - side) / 2), side, side)
			children << attachment_media(config, r, m, frame, m.media_radius)!
			if config.image_path.len > 0 {
				children << attachment_round_mask(frame, m.media_radius, surface)
			}
			left += side + m.gap
		}
		mut right := card_width - if r.content { m.padding_end } else { m.padding_start }
		if config.actions.len > 0 {
			width := attachment_actions_width(config.actions, m)
			children << attachment_action_buttons(config, r, m, right - width, math.round((card_height - m.action) / 2),
				false)
			right -= width + m.gap
		}
		if r.content {
			children << attachment_text(config, r, m, rect(left, 0, math.max(right - left, 0),
				card_height), false)!
		}
		if r.has_progress && card_width > 2 * m.radius {
			// A thin bar along the bottom edge, inside the border and clear of the
			// rounded corners.
			children << linear_progress(
				id:                  component_part_id(config.id, 'bar')
				frame:               rect(m.radius, card_height - 1 - attachment_bar_thickness,
					card_width - 2 * m.radius, attachment_bar_thickness)
				value:               r.progress
				thickness:           attachment_bar_thickness
				reduce_motion:       config.reduce_motion
				color:               theme.primary
				track_color:         interpolate_color(theme.primary, surface, 0.85)
				accessibility_label: 'Upload progress'
				theme:               theme
			)!
		}
	}
	solid_border := if dashed { 0.0 } else { 1.0 }
	mut card := Element{
		...view(component_part_id(config.id, 'card'), rect(0, over, card_width, card_height),
			BoxStyle{
				bg:            surface
				radius:        m.radius
				border_color:  border
				border_left:   solid_border
				border_top:    solid_border
				border_right:  solid_border
				border_bottom: solid_border
			}, children)
		tooltip: r.tooltip
	}
	name, value := attachment_summary(config, r)
	if config.clickable {
		card = Element{
			...with_button_behavior(card)
			enabled:             config.enabled
			cursor:              cursor_pointing_hand
			accessibility_label: name
			accessibility_value: value
		}
	}
	mut parts := [card]
	if config.removable {
		glyph := attachment_remove_glyph
		side := attachment_remove_size
		parts << Element{
			...button_view(component_part_id(config.id, 'remove'), rect(card_width + over - side,
				0, side, side), BoxStyle{
				bg:            theme.background
				radius:        side / 2
				border_color:  theme.border
				border_left:   1
				border_top:    1
				border_right:  1
				border_bottom: 1
				shadow:        box_shadow(0x000000, 0.12, 3, 1)
			}, [
				attachment_symbol('xmark', rect((side - glyph) / 2, (side - glyph) / 2, glyph,
					glyph), if config.enabled {
					theme.foreground
				} else {
					theme.muted_foreground
				}),
			])
			hidden:              config.remove_on_hover && !hovered
			enabled:             config.enabled
			cursor:              cursor_pointing_hand
			tooltip:             'Remove'
			accessibility_label: 'Remove ${r.title}'.trim_space()
		}
	}
	mut root := Element{
		...view(config.id, rect(config.frame.x, config.frame.y, card_width + over, card_height + over),
			BoxStyle{ transparent: true }, parts)
		accessibility_role:  'group'
		accessibility_label: name
		accessibility_value: value
	}
	if r.hover {
		root = Element{
			...with_hover(root)
			action_id: component_part_id(config.id, 'hover')
		}
	}
	return component_finish(root)
}

// attachment_event_from_action decodes an action, or a hover event, that an
// attachment built from config emitted. It rejects foreign and malformed
// actions, controls the attachment does not show or has disabled (retry
// outside the failed status, an action it does not have), and hover changes
// that change nothing.
pub fn attachment_event_from_action(config AttachmentConfig, action string) ?AttachmentEvent {
	return attachment_decode(config, config.id, .complete, action)
}

fn attachment_decode(config AttachmentConfig, key string, inherited AttachmentStatus, action string) ?AttachmentEvent {
	if config.id.len == 0 {
		return none
	}
	r := attachment_resolve(config, inherited)
	if pointer := parse_pointer_event(action) {
		if !r.hover || (pointer.phase != 'enter' && pointer.phase != 'leave') {
			return none
		}
		part := component_action_part(config.id, pointer.action) or { return none }
		entering := pointer.phase == 'enter'
		if part != 'hover' || entering == config.hovered {
			return none
		}
		return AttachmentEvent{
			kind: if entering { .hover_start } else { .hover_end }
			key:  key
		}
	}
	if !config.enabled {
		return none
	}
	part := component_action_part(config.id, action) or { return none }
	match part {
		'card' {
			if config.clickable {
				return AttachmentEvent{
					kind: .click
					key:  key
				}
			}
		}
		'remove' {
			if config.removable {
				return AttachmentEvent{
					kind: .remove
					key:  key
				}
			}
		}
		'retry' {
			if r.retry {
				return AttachmentEvent{
					kind: .retry
					key:  key
				}
			}
		}
		else {
			if part.starts_with('action:') {
				wanted := attachment_hex_text(part['action:'.len..]) or { return none }
				for item in config.actions {
					if item.id == wanted && item.enabled {
						return AttachmentEvent{
							kind:   .action
							key:    key
							action: item.id
						}
					}
				}
			}
		}
	}
	return none
}
