module ui2_c

import ui2

$if !macos && !windows && !linux {
	$compile_error('the C shared library currently supports macOS, Windows and Linux')
}

#define UI2_IMPLEMENTATION
#include "@VMODROOT/c/ui2.h"
#include <string.h>

struct C.ui2_node {}

struct C.ui2_config {
	title     &char
	width     int
	height    int
	build     CBuildFn
	event     CEventFn
	user_data voidptr
	key       CEventFn
	scroll    CEventFn
}

struct C.ui2_box_style {
	background    u32
	radius        f64
	transparent   int
	border_color  u32
	border_left   f64
	border_top    f64
	border_right  f64
	border_bottom f64
}

struct C.ui2_text_style {
	color         u32
	size          f64
	font_family   &char
	bold          int
	italic        int
	underline     int
	strikethrough int
	align         int
	valign        int
	lines         int
}

type CBuildFn = fn (voidptr) &C.ui2_node
type CEventFn = fn (voidptr, &char)

@[heap]
struct Node {
mut:
	element    ui2.Element
	children   []&Node
	parent     voidptr
	generation u64
}

@[heap]
struct ApiState {
mut:
	build      CBuildFn = unsafe { nil }
	event      CEventFn = unsafe { nil }
	key        CEventFn = unsafe { nil }
	scroll     CEventFn = unsafe { nil }
	user_data  voidptr
	building   bool
	running    bool
	title      string = 'App'
	width      int    = 800
	height     int    = 600
	generation u64
	// Root every handle while foreign code builds. A foreign runtime's heap
	// need not be visible to V's collector.
	nodes      []&Node
	last_tree  ui2.Element
	last_error string
}

const api_state = &ApiState{}

fn state() &ApiState {
	return unsafe { api_state }
}

fn input(s &char) string {
	if s == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(s) }
}

fn fail(message string) {
	mut st := state()
	if st.last_error.len == 0 {
		st.last_error = message
	}
}

fn node(handle &C.ui2_node) ?&Node {
	st := state()
	if !st.building || handle == unsafe { nil } {
		fail('widget handles may only be used inside build')
		return none
	}
	n := unsafe { &Node(handle) }
	if n.generation != st.generation {
		fail('widget handle belongs to an earlier build')
		return none
	}
	return n
}

fn configure(config &C.ui2_config) bool {
	mut st := state()
	if st.running || st.building {
		fail('ui2 is already running or building')
		return false
	}
	st.last_error = ''
	if config == unsafe { nil } || config.build == unsafe { nil } {
		fail('config and build callback are required')
		return false
	}
	if config.width < 0 || config.height < 0 {
		fail('window dimensions must not be negative')
		return false
	}
	st.build = config.build
	st.event = config.event
	st.key = config.key
	st.scroll = config.scroll
	st.user_data = config.user_data
	title := input(config.title)
	st.title = if title.len == 0 { 'App' } else { title }
	st.width = if config.width == 0 { 800 } else { config.width }
	st.height = if config.height == 0 { 600 } else { config.height }
	return true
}

fn release_callbacks() {
	mut st := state()
	st.build = unsafe { nil }
	st.event = unsafe { nil }
	st.key = unsafe { nil }
	st.scroll = unsafe { nil }
	st.user_data = unsafe { nil }
}

fn snapshot(n &Node, depth int) !ui2.Element {
	if depth > 512 {
		return error('widget tree exceeds 512 levels')
	}
	mut children := []ui2.Element{cap: n.children.len}
	for child in n.children {
		children << snapshot(child, depth + 1)!
	}
	return ui2.Element{
		...n.element
		children: children
	}
}

fn build_tree() ui2.Element {
	mut st := state()
	if st.building {
		fail('build callback must not reenter ui2')
		return st.last_tree
	}
	st.building = true
	st.last_error = ''
	st.generation++
	st.nodes = []&Node{}
	defer {
		st.building = false
		st.nodes = []&Node{}
	}
	handle := st.build(st.user_data)
	root := node(handle) or { return st.last_tree }
	if st.last_error.len > 0 {
		return st.last_tree
	}
	if root.element.kind != .screen {
		fail('build must return a screen')
		return st.last_tree
	}
	tree := snapshot(root, 0) or {
		fail(err.msg())
		return st.last_tree
	}
	ui2.validate_element_tree(tree) or {
		fail(err.msg())
		return st.last_tree
	}
	st.last_tree = tree
	return tree
}

fn dispatch_event(id string) {
	st := state()
	if st.event != unsafe { nil } {
		st.event(st.user_data, &char(id.str))
	}
	if st.running { ui2.request_refresh() }
}

fn dispatch_key(key string) {
	st := state()
	if st.key != unsafe { nil } {
		st.key(st.user_data, &char(key.str))
	}
	if st.running { ui2.request_refresh() }
}

fn dispatch_scroll(id string) {
	st := state()
	if st.scroll != unsafe { nil } {
		st.scroll(st.user_data, &char(id.str))
	}
}

@[export: 'ui2_abi_version']
pub fn abi_version() u32 {
	return 1
}

@[export: 'ui2_last_error']
pub fn last_error() &char {
	return &char(state().last_error.str)
}

@[export: 'ui2_validate']
pub fn validate(config &C.ui2_config) int {
	if !configure(config) {
		return -1
	}
	defer { release_callbacks() }
	build_tree()
	return if state().last_error.len == 0 { 0 } else { -1 }
}

@[export: 'ui2_run']
pub fn run(config &C.ui2_config) int {
	if !configure(config) {
		return -1
	}
	mut st := state()
	defer {
		st.running = false
		release_callbacks()
	}
	// Validate before any renderer creates a window or mutates native state.
	build_tree()
	if st.last_error.len > 0 {
		return -1
	}
	st.running = true
	$if macos || windows || linux {
		ui2.on_key(dispatch_key)
		ui2.on_scroll(dispatch_scroll)
		ui2.run_window(st.title, st.width, st.height, build_tree, dispatch_event)
	} $else {
		ui2.run(build_tree, dispatch_event)
	}
	return if st.last_error.len == 0 { 0 } else { -1 }
}

@[export: 'ui2_create']
pub fn create(kind int, id &char, x f64, y f64, width f64, height f64) &C.ui2_node {
	mut st := state()
	if !st.building {
		fail('widgets may only be created inside build')
		return unsafe { nil }
	}
	if kind < 0 || kind > int(ui2.Kind.opengl) {
		fail('unknown widget kind')
		return unsafe { nil }
	}
	if width < 0 || height < 0 {
		fail('widget dimensions must not be negative')
		return unsafe { nil }
	}
	mut n := &Node{
		generation: st.generation
		element:    ui2.Element{
			kind:  unsafe { ui2.Kind(kind) }
			id:    input(id)
			frame: ui2.rect(x, y, width, height)
			box:   ui2.BoxStyle{ transparent: kind == int(ui2.Kind.checkbox) }
		}
	}
	st.nodes << n
	return unsafe { &C.ui2_node(n) }
}

@[export: 'ui2_add']
pub fn add(parent &C.ui2_node, child &C.ui2_node) {
	mut p := node(parent) or { return }
	mut c := node(child) or { return }
	if p.element.kind !in [.screen, .view, .scroll] {
		fail('only screens, views and scrolls can have children')
		return
	}
	if c.parent != unsafe { nil } || c.element.kind == .screen {
		fail('a widget may have only one parent and screens must be roots')
		return
	}
	mut ancestor := p
	for {
		if ancestor == c {
			fail('widget tree contains a cycle')
			return
		}
		if ancestor.parent == unsafe { nil } { break }
		ancestor = unsafe { &Node(ancestor.parent) }
	}
	c.parent = voidptr(p)
	p.children << c
}

@[export: 'ui2_set_text']
pub fn set_text(handle &C.ui2_node, text &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, text: input(text) }
}

@[export: 'ui2_set_key']
pub fn set_key(handle &C.ui2_node, key &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, key: input(key) }
}

@[export: 'ui2_set_action']
pub fn set_action(handle &C.ui2_node, action &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, action_id: input(action) }
}

@[export: 'ui2_set_tooltip']
pub fn set_tooltip(handle &C.ui2_node, tooltip &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, tooltip: input(tooltip) }
}

@[export: 'ui2_set_placeholder']
pub fn set_placeholder(handle &C.ui2_node, placeholder &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, placeholder: input(placeholder) }
}

@[export: 'ui2_set_image']
pub fn set_image(handle &C.ui2_node, path &char) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, image_path: input(path) }
}

@[export: 'ui2_set_box_style']
pub fn set_box_style(handle &C.ui2_node, style &C.ui2_box_style) {
	mut n := node(handle) or { return }
	if style == unsafe { nil } {
		fail('box style is required')
		return
	}
	n.element = ui2.Element{
		...n.element
		box: ui2.BoxStyle{
			bg:            style.background
			radius:        style.radius
			transparent:   style.transparent != 0
			border_color:  style.border_color
			border_left:   style.border_left
			border_top:    style.border_top
			border_right:  style.border_right
			border_bottom: style.border_bottom
		}
	}
}

@[export: 'ui2_set_text_style']
pub fn set_text_style(handle &C.ui2_node, style &C.ui2_text_style) {
	mut n := node(handle) or { return }
	if style == unsafe { nil } {
		fail('text style is required')
		return
	}
	if style.align < 0 || style.align > 2 || style.valign < 0 || style.valign > 2
		|| style.size <= 0 || style.lines < 0 {
		fail('invalid text style')
		return
	}
	n.element = ui2.Element{
		...n.element
		text_style: ui2.TextStyle{
			color:         style.color
			size:          style.size
			font_family:   input(style.font_family)
			bold:          style.bold != 0
			italic:        style.italic != 0
			underline:     style.underline != 0
			strikethrough: style.strikethrough != 0
			align:         unsafe { ui2.Align(style.align) }
			valign:        unsafe { ui2.VAlign(style.valign) }
			lines:         style.lines
		}
	}
}

@[export: 'ui2_set_flags']
pub fn set_flags(handle &C.ui2_node, flags u32) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{
		...n.element
		native_style:          flags & 1 != 0
		enabled:               flags & 2 == 0
		hidden:                flags & 4 != 0
		readonly:              flags & 8 != 0
		secure:                flags & 16 != 0
		emit_change:           flags & 32 != 0
		button_behavior:       flags & 64 != 0
		clickable:             flags & 128 != 0
		draggable:             flags & 256 != 0
		persistent_scrollbars: flags & 512 != 0
	}
}

@[export: 'ui2_set_checked']
pub fn set_checked(handle &C.ui2_node, checked int) {
	mut n := node(handle) or { return }
	n.element = ui2.Element{ ...n.element, checked: checked != 0 }
}

@[export: 'ui2_set_scroll_mode']
pub fn set_scroll_mode(handle &C.ui2_node, mode int) {
	mut n := node(handle) or { return }
	if mode < 0 || mode > 2 {
		fail('unknown scroll mode')
		return
	}
	n.element = ui2.Element{ ...n.element, scroll_mode: unsafe { ui2.ScrollMode(mode) } }
}

@[export: 'ui2_set_slider']
pub fn set_slider(handle &C.ui2_node, value f64, min f64, max f64, step f64, vertical int) {
	mut n := node(handle) or { return }
	if max < min || step < 0 {
		fail('invalid slider range or step')
		return
	}
	n.element = ui2.Element{
		...n.element
		value:       ui2.slider_clamped_value(value, min, max)
		min_value:   min
		max_value:   max
		step:        step
		orientation: if vertical != 0 { .vertical } else { .horizontal }
	}
}

@[export: 'ui2_add_option']
pub fn add_option(handle &C.ui2_node, text &char) {
	mut n := node(handle) or { return }
	if n.element.kind != .dropdown {
		fail('options require a dropdown')
		return
	}
	value := input(text)
	mut entries := n.element.menu.clone()
	entries << ui2.MenuEntry{ id: value, title: value }
	n.element = ui2.Element{ ...n.element, menu: entries }
}

@[export: 'ui2_refresh']
pub fn refresh() {
	if state().running { ui2.request_refresh() }
}

@[export: 'ui2_quit']
pub fn quit() {
	if state().running { ui2.quit() }
}

@[export: 'ui2_bounds']
pub fn bounds(width &f64, height &f64) {
	st := state()
	b := if st.running { ui2.bounds() } else { ui2.rect(0, 0, st.width, st.height) }
	unsafe {
		if width != nil { *width = b.width }
		if height != nil { *height = b.height }
	}
}

@[export: 'ui2_get_text']
pub fn get_text(id &char, buffer &char, capacity usize) usize {
	value := ui2.text(input(id))
	if buffer != unsafe { nil } && capacity > 0 {
		count := if usize(value.len) < capacity - 1 { usize(value.len) } else { capacity - 1 }
		unsafe {
			C.memcpy(buffer, value.str, count)
			buffer[count] = 0
		}
	}
	return usize(value.len) + 1
}

@[export: 'ui2_update_text']
pub fn update_text(id &char, text &char) {
	ui2.set_text(input(id), input(text))
}

@[export: 'ui2_focus']
pub fn focus(id &char) {
	ui2.focus(input(id))
}

@[export: 'ui2_get_value']
pub fn get_value(id &char) f64 {
	return ui2.slider_value(input(id))
}

@[export: 'ui2_update_value']
pub fn update_value(id &char, value f64) {
	ui2.set_slider_value(input(id), value)
}

@[export: 'ui2_get_checked']
pub fn get_checked(id &char) int {
	return if ui2.control_checked(input(id)) { 1 } else { 0 }
}

@[export: 'ui2_update_checked']
pub fn update_checked(id &char, checked int) {
	ui2.set_control_checked(input(id), checked != 0)
}

@[export: 'ui2_scroll_to']
pub fn scroll_to(id &char, x f64, y f64) {
	name := input(id)
	ui2.scroll_to_horizontal_offset(name, x)
	ui2.scroll_to_offset(name, y)
}

@[export: 'ui2_get_scroll']
pub fn get_scroll(id &char, x &f64, y &f64) {
	name := input(id)
	unsafe {
		if x != nil { *x = ui2.scroll_horizontal_offset(name) }
		if y != nil { *y = ui2.scroll_offset(name) }
	}
}
