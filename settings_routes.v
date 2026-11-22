module main

import veb
import strconv
import os
import net.http

// Uploaded icons are tiny by nature, so they get much smaller caps than the
// media library, and only formats a browser renders as an image are accepted.
const favicon_extensions = ['ico', 'png', 'svg', 'gif', 'jpg', 'jpeg', 'webp']
const max_favicon_bytes = 512 * 1024
const logo_extensions = ['png', 'svg', 'gif', 'jpg', 'jpeg', 'webp']
const max_logo_bytes = 2 * 1024 * 1024

@['/save/settings'; post]
pub fn (mut app App) save_settings(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	mut settings := app.load_settings()
	settings.blog_title = (ctx.form['blog_title'] or { settings.blog_title }).trim_space()
	settings.blog_description = ctx.form['blog_description'] or { settings.blog_description }
	settings.footer_text = (ctx.form['footer_text'] or { settings.footer_text }).trim_space()
	settings.logo_url = (ctx.form['logo_url'] or { settings.logo_url }).trim_space()
	// Checkboxes only appear in the form when ticked, so an absent key means off.
	settings.logo_enabled = flag_from_form(ctx.form, 'logo_enabled')
	settings.show_description = flag_from_form(ctx.form, 'show_description')
	settings.show_pages = flag_from_form(ctx.form, 'show_pages')
	settings.show_tags = flag_from_form(ctx.form, 'show_tags')
	settings.show_rss = flag_from_form(ctx.form, 'show_rss')
	settings.show_post_meta = flag_from_form(ctx.form, 'show_post_meta')
	settings.show_footer = flag_from_form(ctx.form, 'show_footer')
	accent := (ctx.form['accent_foreground'] or { settings.accent_foreground }).trim_space()
	// An invalid colour would be pasted straight into every page's CSS
	// variable, so refuse it rather than break the whole theme.
	if accent.len > 0 {
		if !valid_css_color(accent) {
			// Only the accent message, so the page does not also claim the save
			// failed for no stated reason.
			ctx.invalid_accent = true
			return app.settings(mut ctx)
		}
		settings.accent_foreground = accent
	}
	theme := (ctx.form['theme'] or { settings.theme }).trim_space()
	if valid_theme(theme) {
		settings.theme = theme
	}
	timezone := (ctx.form['timezone'] or { settings.timezone }).trim_space()
	if valid_timezone(timezone) {
		settings.timezone = timezone
	}
	parsed_per_page := strconv.atoi((ctx.form['posts_per_page'] or { settings.posts_per_page.str() }).trim_space()) or {
		settings.posts_per_page
	}
	settings.posts_per_page = clamp_posts_per_page(parsed_per_page)

	app.write_settings(settings) or {
		eprintln("Couldn't save settings: ${err}")
		ctx.invalid_settings = true
		return app.settings(mut ctx)
	}

	return ctx.redirect('/settings')
}

// upload_favicon takes the Favicon section's file input and makes it the site
// icon. Each upload is its own form, so the text settings keep posting as a
// plain form and a missing file can never blank them out.
@['/upload/favicon'; post]
pub fn (mut app App) upload_favicon(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	files := ctx.files['favicon_file'] or { []http.FileData{} }
	if files.len == 0 || files[0].filename.len == 0 || files[0].data.len == 0 {
		return ctx.redirect('/settings?favicon=empty')
	}

	url := app.store_uploaded_icon(files[0], favicon_extensions, max_favicon_bytes, 'favicon') or {
		return ctx.redirect('/settings?favicon=error')
	}

	mut settings := app.load_settings()
	previous := settings.favicon_url
	settings.favicon_url = url
	app.write_settings(settings) or {
		eprintln("Couldn't save the favicon: ${err}")
		app.delete_uploaded_icon(url, 'favicon')
		return ctx.redirect('/settings?favicon=error')
	}
	app.delete_uploaded_icon(previous, 'favicon')

	return ctx.redirect('/settings?favicon=saved')
}

@['/remove/favicon']
pub fn (mut app App) remove_favicon(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	mut settings := app.load_settings()
	previous := settings.favicon_url
	settings.favicon_url = ''
	app.write_settings(settings) or {
		eprintln("Couldn't remove the favicon: ${err}")
		return ctx.redirect('/settings?favicon=error')
	}
	app.delete_uploaded_icon(previous, 'favicon')

	return ctx.redirect('/settings?favicon=removed')
}

// upload_logo takes the Logo section's file input and makes it the sidebar
// logo. Uploading one switches the logo on, since that is clearly the intent.
@['/upload/logo'; post]
pub fn (mut app App) upload_logo(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	files := ctx.files['logo_file'] or { []http.FileData{} }
	if files.len == 0 || files[0].filename.len == 0 || files[0].data.len == 0 {
		return ctx.redirect('/settings?logo=empty')
	}

	url := app.store_uploaded_icon(files[0], logo_extensions, max_logo_bytes, 'logo') or {
		return ctx.redirect('/settings?logo=error')
	}

	mut settings := app.load_settings()
	previous := settings.logo_url
	settings.logo_url = url
	settings.logo_enabled = 1
	app.write_settings(settings) or {
		eprintln("Couldn't save the logo: ${err}")
		app.delete_uploaded_icon(url, 'logo')
		return ctx.redirect('/settings?logo=error')
	}
	app.delete_uploaded_icon(previous, 'logo')

	return ctx.redirect('/settings?logo=saved')
}

// remove_logo clears the logo and switches it off, mirroring the favicon. Only
// a file this app stored under the logo. prefix is deleted.
@['/remove/logo']
pub fn (mut app App) remove_logo(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	mut settings := app.load_settings()
	previous := settings.logo_url
	settings.logo_url = ''
	settings.logo_enabled = 0
	app.write_settings(settings) or {
		eprintln("Couldn't remove the logo: ${err}")
		return ctx.redirect('/settings?logo=error')
	}
	app.delete_uploaded_icon(previous, 'logo')

	return ctx.redirect('/settings?logo=removed')
}

// store_uploaded_icon writes one uploaded image into media/ under a fresh name,
// so a new upload never overwrites the old file and browsers get a new URL
// instead of a cached one. Returns the public URL to store in settings.
fn (mut app App) store_uploaded_icon(file http.FileData, extensions []string, max_bytes int, prefix string) ?string {
	if file.filename.len == 0 || file.data.len == 0 || file.data.len > max_bytes {
		return none
	}
	name := media_safe_name(file.filename)
	if !name.contains('.') {
		return none
	}
	ext := name.all_after_last('.').to_lower()
	if ext !in extensions {
		return none
	}
	if !media_content_allowed(name, file.data) {
		return none
	}
	os.mkdir_all(media_dir) or {}
	stored := media_unique_name('${prefix}.${ext}')
	os.write_file_array(os.join_path(media_dir, stored), file.data.bytes()) or {
		eprintln("Couldn't save the uploaded image: ${err}")
		return none
	}
	return '/media/${stored}'
}

// delete_uploaded_icon clears out an image this app stored for a setting. Only
// files carrying that setting's own prefix directly inside media/ are touched,
// so media the author uploaded separately and linked to stays put.
fn (mut app App) delete_uploaded_icon(url string, prefix string) {
	if !url.starts_with('/media/') {
		return
	}
	name := url.all_after('/media/')
	if !name.starts_with('${prefix}.') || name.contains('/') {
		return
	}
	os.rm(os.join_path(media_dir, name)) or {}
}

// upload_status is the ?logo= / ?favicon= outcome of the last upload, so the
// settings page can explain what happened after its redirect.
pub fn (ctx &Context) upload_status(name string) string {
	return ctx.query[name] or { '' }
}
