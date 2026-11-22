module main

import os

// asset_url appends the file's modification time to one of the blog's own
// static assets. veb serves static files without validators, so a browser can
// otherwise keep an old script or stylesheet after an edit and lose whatever
// depends on it — a toast that never reveals itself, for one. Vendored files
// keep their plain URLs: they change with a new release, not an edit.
pub fn (ctx &Context) asset_url(path string) string {
	file := asset_file(path)
	stamp := os.file_last_mod_unix(file)
	if stamp <= 0 {
		return path
	}
	return '${path}?v=${stamp}'
}

// asset_file maps a public asset URL to the file served for it. The three
// stylesheets in static/css are also mounted at short root URLs.
fn asset_file(path string) string {
	name := path.trim_left('/')
	if name in ['style.css', 'admin.css', 'pure-min.css', 'pure-grids-responsive-min.css'] {
		return os.join_path('static', 'css', name)
	}
	return os.join_path('static', name)
}

// theme_url versions the stylesheet of the theme in use.
pub fn (ctx &Context) theme_url() string {
	return ctx.asset_url('/themes/${ctx.settings.theme}.css')
}
