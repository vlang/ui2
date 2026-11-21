module ui2

import json2

// web_renderer_js is the DOM renderer, embedded at compile time so the served
// page is part of the single deployable binary. The source lives in
// web/renderer/ and is type-checked JS; there is no run-time toolchain.
const web_renderer_js = $embed_file('../web/renderer/renderer.js').to_string()

pub struct WebPageConfig {
	title        string
	token        string
	width        int
	height       int
	dpr          f64
	ws_path      string @[json: 'wsPath']
	snapshot_url string @[json: 'snapshotUrl']
}

// web_html_page builds the single page the browser loads. The renderer reads
// ui2-config to learn the websocket token and the initial viewport, then pulls
// the first frame from snapshot_url.
pub fn web_html_page(cfg WebPageConfig) string {
	raw := json2.encode(cfg)
	// Inside a JSON <script> block a literal `<` can terminate the element.
	safe := raw.replace('<', '\\u003c').replace('>', '\\u003e').replace('&', '\\u0026')
	title := if cfg.title.len > 0 { cfg.title } else { 'ui2' }
	return '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${web_escape_html(title)}</title>
<style>
html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #ffffff; overflow: hidden; }
#ui2-root { position: relative; transform-origin: top left; }
</style>
</head>
<body>
<div id="ui2-root"></div>
<script id="ui2-config" type="application/json">${safe}</script>
<script>
${web_renderer_js}
</script>
</body>
</html>
'
}

fn web_escape_html(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
}
