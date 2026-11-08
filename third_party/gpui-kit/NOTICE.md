# GPUI Kit attribution

Source: https://github.com/longbridge/gpui-kit
Revisions: `1b6059c13315dc5c304759ad3aa666e0b6e301d8` (batch 1),
`f8cf0bd964f9ef2e5b7be79f3a8fc391371feb4a` (later batches) and `d4c56812`
(speech)
Copyright 2024 - 2026 Longbridge <https://longbridge.com>

These files adapt GPUI Kit logic or tests and are distributed under
Apache-2.0; the complete license is in `LICENSE-APACHE` alongside this notice.
Each carries an SPDX header naming it.

| File | Adapted from |
| --- | --- |
| `ui/pagination.v` | The controlled pagination state and page-window algorithm of `crates/base/src/pagination.rs`. The V version changes types and error handling, caps visible-page allocation, adds guarded action encoding/decoding, and renders through UI2's elements. |
| `ui/component_catalog_test.v` | Pagination behavior tests from the same file, beside new UI2 regression tests. |
| `ui/component_choice_rating.v` | The rating click rule of `crates/component/src/rating.rs` (clicking a filled star sets the value to the star before it). |
| `ui/component_inputs_number.v` | The stepping rules of `step_value` in `crates/base/src/number_input.rs`. |
| `ui/component_inputs_test.v` | Some number-input stepping cases from the same file, beside new tests. |
| `ui/component_feedback_progress.v` | Size presets, the track opacity, the stroke formula, both loading curves and the reduced-motion inset of `crates/component/src/progress/progress.rs` and `progress_circle.rs`. |
| `ui/component_feedback_shimmer.v` | Spread clamping, band center and padding, layered widths and the highlight-color rule of `crates/component/src/shimmer.rs`. |
| `ui/component_feedback_test.v` | Shimmer spread, band and highlight cases from the same file, beside new tests. |
| `ui/component_popovers_position.v` | The side choice (preferred, else opposite, else roomier), alignment and clamping of `crates/base/src/positioner.rs`, and the arrow's corner clearance of `crates/component/src/popover.rs`. |
| `ui/component_popovers.v` | The hover-card timing rules of `crates/base/src/hover_card.rs`. |
| `ui/component_popovers_menu.v` | The keyboard navigation rules of `crates/component/src/menu/popup_menu.rs`. |
| `ui/component_popovers_test.v` | Placement cases from upstream's positioner tests, beside new tests. |
| `ui/component_datetime_calendar.v` | The range-selection rule, matcher kinds and days/months/years views of `crates/base/src/calendar.rs`. |
| `ui/component_datetime_time.v` | The segment editing rules of `SegmentEditor` in `crates/base/src/time_field.rs`. |
| `ui/component_datetime_test.v` | Month-grid, range and time-segment cases from those files, beside new tests. |
| `ui/component_color_model.v` | The hex formats read and written by `parse_hex`/`hex_string` in `crates/base/src/color_picker.rs`. |
| `ui/component_color_test.v` | That file's malformed-hex cases, beside new tests. |
| `ui/component_lists.v` | The row model and wrapping keyboard navigation of `crates/component/src/list/cache.rs` and `list.rs`. |
| `ui/component_lists_search.v` | The matching, group and highlight rules of `crates/component/src/searchable_list/`. |
| `ui/component_pickers_command.v` | The filtering and navigation rules of `crates/component/src/command/state.rs`. |
| `ui/component_panels.v` | The resize handle's indicator levels and grab padding of `crates/component/src/resizable.rs`, and the fixed-panel container-resize rule of `crates/base/src/resizable/mod.rs`. |
| `ui/component_panels_dock_view.v` | The dock chrome rules of `crates/component/src/dock/tab_panel.rs`: toggle placement, the collapsed bottom strip, single-panel title bars, zoom, and no close on a dock's last panel. |
| `ui/component_panels_test.v` | Fixed-panel sizing cases from `crates/base/src/resizable/mod.rs`, beside new tests. |
| `ui/component_form_test.v` | Label-orientation and hidden-field cases from `crates/component/src/form/tests.rs`, beside new tests. |
| `ui/component_settings.v` | The search selection (`SettingsFilter::selected_index`), search matching (`SettingItem::is_match`) and Reset-all scope (`SettingGroup::reset`) of `crates/component/src/setting/`. |
| `ui/component_settings_test.v` | Search-selection, footer and search-reset scenarios from `crates/component/src/setting/tests.rs`, beside new tests. |
| `ui/component_attachments.v` | The size geometry, status inheritance, retry and progress rules, scrim strengths and corner-control metrics of `crates/component/src/attachment.rs`. |
| `ui/component_attachments_test.v` | Status-rule cases from the same file, beside new tests. |
| `ui/component_questionnaire.v` | The schema checks, answer and status rules, validation order, completion and submit events, navigation and choose/confirm behaviour of `crates/base/src/questionnaire/state.rs` and `types.rs`. |
| `ui/component_questionnaire_input.v` | The key rules and focus order of `crates/base/src/questionnaire/keyboard.rs` and `state.rs`. |
| `ui/component_speech.v` | The session lifecycle and level meter of `crates/component/src/speech/state.rs` and `level.rs`, and the phrase spacing and utterance-restart check of `system/macos.rs`. |
| `ui/speech.v` | The recognition result handling of `crates/component/src/speech/system/macos.rs`. |
| `ui/component_speech_test.v` | Phrase-spacing and utterance-reset cases from `system/macos.rs`, beside new tests. |
| `ui/component_theme_registry_builtin.v` | Theme sets from GPUI Kit's bundled `themes/` (revision `d4c56812`), whose palettes credit Catppuccin, Ethan Schoonover (Solarized), Pavel Pertsev (Gruvbox), Folke Lemaitre (Tokyo Night), Ayu and shadcn. |
| `ui/component_theme_registry_parse.v` | The color, gradient and fallback rules of GPUI Kit's theme file format (`crates/component/src/theme/`). |
| `ui/component_theme_registry_test.v` | Theme parsing cases from the same crate, beside new tests. |
| `ui/component_editor_theme.v` | The light and dark syntax palettes of GPUI Kit's `default-theme.json`. |
| `ui/component_navigation2_tabs.v` | The tab variants' sizes, paddings, gaps and colors, the sliding indicator and the reveal-with-peek rule of `crates/component/src/tab/tab.rs` and `tab_bar.rs`. |
| `ui/component_navigation2_tabs_draw.v` | The folder tab outline and the variant drawing of the same files. |
| `ui/component_navigation2_tree.v` | The keyboard model and reveal of `crates/base/src/tree.rs`. |
| `ui/component_basics_test.v` | Label highlight cases from `crates/component/src/label.rs`, beside new tests. |

`ui/component_charts_special_sankey_layout.v` is a new V implementation of the
d3-sankey layout algorithm (https://github.com/d3/d3-sankey, Copyright 2015 Mike
Bostock, BSD-3-Clause), which GPUI Kit's SankeyChart also follows; no d3 code is
included.

Every other component implementation is new V code following the GPUI Kit
catalog's documented concepts, not copied Rust. It, the examples and the
documentation use UI2's existing MIT license. No GPUI Kit assets or runtime are
included, and this does not change the license of existing UI2 files.
