module main

import veb
import net.http
import os

// The media library: uploads live in media/, are linked from /media/<file>,
// and gallery metadata (title, alt text) lives in the Media table.
@['/media']
pub fn (mut app App) media(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	app.ensure_media_schema()
	app.sync_media_library()

	all := app.get_media_items()

	ctx.media_query = (ctx.query['q'] or { '' }).trim_space()
	kind := ctx.query['type'] or { 'all' }
	ctx.media_kind = if kind in media_kind_filters { kind } else { 'all' }
	sort_by := ctx.query['sort'] or { 'newest' }
	ctx.media_sort = if sort_by in media_sorts { sort_by } else { 'newest' }

	ctx.media_count = all.len
	ctx.media_bytes = 0
	ctx.media_images = 0
	for item in all {
		ctx.media_bytes += item.size
		if item.is_image() {
			ctx.media_images++
		}
	}
	ctx.media_items = filter_media(all, ctx.media_query, ctx.media_kind, ctx.media_sort)

	ctx.media_uploaded = ctx.query['uploaded'] or { '' }
	ctx.media_skipped = ctx.query['skipped'] or { '' }
	ctx.media_error = ctx.query['error'] or { '' }
	ctx.media_page = true
	ctx.page_title = 'Media — ${ctx.settings.blog_title}'
	ctx.page_description = '${ctx.media_count} files in the media library.'
	return $veb.html()
}

@['/upload/media'; post]
pub fn (mut app App) upload_media(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	app.ensure_media_schema()

	files := ctx.files['media_files'] or { []http.FileData{} }
	mut stored := 0
	mut skipped := 0
	for file in files {
		if app.store_media_upload(file) {
			stored++
		} else if file.filename.len > 0 || file.data.len > 0 {
			skipped++
		}
	}

	if stored == 0 {
		return ctx.redirect('/media?error=1')
	}
	mut target := '/media?uploaded=${stored}'
	if skipped > 0 {
		target += '&skipped=${skipped}'
	}
	return ctx.redirect(target)
}

// serve_media_file serves uploads made after boot. The folder mount covers the
// Every uploaded file is served here, which supplies a MIME type for formats
// veb does not know and keeps the security headers on images too.
@['/media/:file']
pub fn (mut app App) serve_media_file(mut ctx Context, file string) veb.Result {
	if file.len == 0 || file.starts_with('.') || file.contains('..') || file.contains('/')
		|| file.contains('\\') {
		return ctx.not_found()
	}
	path := os.join_path(media_dir, file)
	if !os.exists(path) || os.is_dir(path) {
		return ctx.not_found()
	}
	ctx.custom_mime_types[os.file_ext(file).to_lower()] = media_mime_for(file)
	ctx.set_custom_header('X-Content-Type-Options', 'nosniff') or {}
	if os.file_ext(file).to_lower() == '.svg' {
		// An SVG opened on its own is a document, so sandbox it: it may draw,
		// but it cannot run script on the blog's origin.
		ctx.set_custom_header('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox") or {}
	}
	return ctx.file(path)
}

@['/media/save/:media_id'; post]
pub fn (mut app App) save_media_details(mut ctx Context, media_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	item := app.get_media_by_id(media_id) or { return ctx.redirect('/media') }
	title := (ctx.form['media_title'] or { '' }).trim_space()
	alt := (ctx.form['media_alt'] or { '' }).trim_space()
	app.update_media_details(item.id, title, alt)
	return ctx.redirect('/media')
}

@['/media/delete/:media_id']
pub fn (mut app App) delete_media_handle(mut ctx Context, media_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	if item := app.get_media_by_id(media_id) {
		app.remove_media(item)
	}
	return ctx.redirect('/media')
}

pub fn (ctx &Context) media_filter_class(name string) string {
	return if ctx.media_kind == name { 'dash-filter is-active' } else { 'dash-filter' }
}

pub fn (ctx &Context) media_sort_selected(name string) string {
	return if ctx.media_sort == name { ' selected' } else { '' }
}

// media_href keeps the current search and ordering when switching type.
pub fn (ctx &Context) media_href(kind string) string {
	mut href := '/media?type=${kind}&sort=${ctx.media_sort}'
	if ctx.media_query.len > 0 {
		href += '&q=${media_escape(ctx.media_query)}'
	}
	return href
}

pub fn (ctx &Context) media_size_label() string {
	return human_size(ctx.media_bytes)
}
