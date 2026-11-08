module webview

import time

#include "@VMODROOT/webview/webview_test_darwin.h"

fn C.ui2_webview_test_pump(int)
fn C.ui2_webview_test_cookie(voidptr, &char, &char, &char)
fn C.ui2_webview_test_user_close(voidptr)
fn C.ui2_webview_test_width(voidptr) int
fn C.ui2_webview_test_delegate() voidptr
fn C.ui2_webview_test_new_delegate() voidptr
fn C.ui2_webview_test_set_delegate(voidptr)
fn C.ui2_webview_test_release_delegate(voidptr)
fn C.ui2_webview_test_late_native_read(voidptr) int

fn await_js(view &WebView, expected string) {
	deadline := time.now().add(10 * time.second)
	for time.now() < deadline {
		C.ui2_webview_test_pump(25)
		if view.js_value() == expected {
			return
		}
	}
	assert view.js_value() == expected
}

fn await_cookie(view &WebView, name string, domain string, expected string) {
	deadline := time.now().add(10 * time.second)
	for time.now() < deadline {
		if view.cookie(name, domain) == expected {
			return
		}
		C.ui2_webview_test_pump(25)
	}
	assert view.cookie(name, domain) == expected
}

fn test_native_windows_keep_independent_results_and_host_delegate() {
	delegate := C.ui2_webview_test_delegate()
	sentinel := C.ui2_webview_test_new_delegate()
	C.ui2_webview_test_set_delegate(sentinel)
	defer {
		C.ui2_webview_test_set_delegate(delegate)
		C.ui2_webview_test_release_delegate(sentinel)
	}
	first := new_window(
		url:        'about:blank'
		title:      'ui2.webview first test'
		width:      420
		height:     300
		persistent: false
		js_on_init: 'window.webkit.messageHandlers.vui.postMessage(document.readyState)'
	)
	second := new_window(
		url:        'about:blank'
		title:      'ui2.webview second test'
		persistent: false
	)
	defer {
		first.close()
		second.close()
	}
	assert first.obj != unsafe { nil }
	assert second.obj != first.obj
	assert C.ui2_webview_test_delegate() == sentinel
	assert C.ui2_webview_test_width(first.native) == 420
	await_js(first, 'loading')
	second.eval_js('"second value"')
	await_js(second, 'second value')
	assert first.js_value() == 'loading'
	first.eval_js('window.webkit.messageHandlers.vui.postMessage("first value"); "first value"')
	await_js(first, 'first value')
	assert second.js_value() == 'second value'
	first.load('about:blank')
	assert first.js_value() == ''
	await_js(first, 'loading')
	assert second.js_value() == 'second value'
	first.close()
	assert !first.is_open()
	assert first.js_value() == ''
	assert second.is_open()
	C.ui2_webview_test_user_close(second.native)
	assert !second.is_open()
	assert C.ui2_webview_test_delegate() == sentinel
}

fn worker_eval(view &WebView, completed chan bool) {
	view.eval_js('"worker value"')
	completed <- true
}

fn worker_cookie(view &WebView, completed chan string) {
	completed <- view.cookie('http_only_session', '.example.test')
}

fn worker_close(view &WebView, completed chan bool) {
	view.close()
	completed <- true
}

fn test_worker_calls_and_cookie_stores_are_isolated() {
	first := new_window(url: 'about:blank', persistent: false)
	second := new_window(url: 'about:blank', persistent: false)
	defer {
		first.close()
		second.close()
	}
	C.ui2_webview_test_pump(250)
	mut evaluated := chan bool{cap: 1}
	spawn worker_eval(first, evaluated)
	await_js(first, 'worker value')
	assert <-evaluated
	assert second.js_value() == ''
	C.ui2_webview_test_cookie(first.native, c'http_only_session', c'.example.test', c'first-secret')
	await_cookie(first, 'http_only_session', 'example.test', 'first-secret')
	assert second.cookie('http_only_session', '.example.test') == ''
	assert first.cookie('http_only_session', 'different.test') == ''
	mut cookies := chan string{cap: 1}
	spawn worker_cookie(first, cookies)
	deadline := time.now().add(10 * time.second)
	mut cookie := ''
	mut got_cookie := false
	for time.now() < deadline && !got_cookie {
		C.ui2_webview_test_pump(25)
		select {
			value := <-cookies {
				cookie = value
				got_cookie = true
			}
			else {
			}
		}
	}
	assert got_cookie
	assert cookie == 'first-secret'
	first.delete_all_cookies()
	await_cookie(first, 'http_only_session', '.example.test', '')
	C.ui2_webview_test_pump(250)
	await_cookie(first, 'http_only_session', '.example.test', '')
	mut closed := chan bool{cap: 1}
	spawn worker_close(first, closed)
	assert <-closed
	C.ui2_webview_test_pump(100)
	assert !first.is_open()
	assert second.is_open()
	assert first.cookie('http_only_session', '.example.test') == ''
}

fn worker_native_read(obj voidptr, completed chan int) {
	completed <- C.ui2_webview_test_late_native_read(obj)
}

fn test_cookie_timeout_and_late_native_reader_are_safe_after_close() {
	view := new_window(url: 'about:blank', persistent: false)
	defer {
		view.close()
	}
	C.ui2_webview_test_pump(250)
	mut cookies := chan string{cap: 1}
	start := time.now()
	spawn worker_cookie(view, cookies)
	// Deliberately withhold the main run loop so the worker must time out.
	time.sleep(3200 * time.millisecond)
	mut received := false
	mut value := 'pending'
	select {
		cookie := <-cookies {
			value = cookie
			received = true
		}
		else {
		}
	}
	assert received
	assert value == ''
	assert time.since(start) < 5 * time.second
	view.close()
	assert !view.is_open()
	mut native_reads := chan int{cap: 1}
	spawn worker_native_read(view.obj, native_reads)
	deadline := time.now().add(10 * time.second)
	mut detached := 0
	for time.now() < deadline {
		C.ui2_webview_test_pump(25)
		select {
			result := <-native_reads {
				detached = result
				assert detached == 1
				assert view.js_value() == ''
				return
			}
			else {
			}
		}
	}
	assert detached == 1
}
