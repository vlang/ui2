module ui2

fn test_web_html_page_embeds_renderer_and_config() {
	page := web_html_page(WebPageConfig{
		title:        'Counter'
		token:        'secret'
		width:        320
		height:       240
		dpr:          2.0
		ws_path:      '/events'
		snapshot_url: '/snapshot'
	})
	assert page.contains('<!DOCTYPE html>')
	assert page.contains('<div id="ui2-root"></div>')
	assert page.contains('"token":"secret"')
	assert page.contains('"wsPath":"/events"')
	assert page.contains('"snapshotUrl":"/snapshot"')
	assert page.contains('function connect()')
	assert page.contains('<title>Counter</title>')
}

fn test_web_html_page_escapes_title() {
	page := web_html_page(WebPageConfig{ title: '<script>x</script>' })
	assert page.contains('&lt;script&gt;')
	assert !page.contains('<title><script>')
}

fn test_web_renderer_embeds_snapshot_and_patch_dispatch() {
	// Both server -> client envelopes are handled by the embedded renderer.
	assert web_renderer_js.contains("message.type === 'snapshot'")
	assert web_renderer_js.contains("message.type === 'patch'")
	assert web_renderer_js.contains("message.type === 'error'")
	// The two patch op kinds the renderer understands.
	assert web_renderer_js.contains("'replace_children'")
	assert web_renderer_js.contains("'update'")
	// Element events carry the desktop action identity alongside the state id.
	assert web_renderer_js.contains('dto.action_id || dto.id')

	page := web_html_page(WebPageConfig{ title: 'Dispatch' })
	assert page.contains(web_renderer_js)
}

fn test_web_renderer_avoids_unsafe_html_injection() {
	// A literal </script> inside the JS would close the embedding <script>
	// element early; the renderer also never writes raw HTML, so all element
	// text is escaped by the DOM rather than parsed as markup.
	assert !web_renderer_js.contains('</script>')
	assert !web_renderer_js.contains('innerHTML')
	assert !web_renderer_js.contains('outerHTML')
	assert !web_renderer_js.contains('insertAdjacentHTML')

	page := web_html_page(WebPageConfig{ title: '<b>bold</b>' })
	assert page.contains('&lt;b&gt;bold&lt;/b&gt;')
	assert !page.contains('<title><b>')
}
