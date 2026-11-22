module main

import veb
import db.sqlite
import markdown // v install markdown
import time

pub struct Context {
	veb.Context
pub mut:
	settings         Settings
	tz               &time.Location
	themes           []string
	timezones        []string
	search_query     string
	posts_count      int
	page_count       int
	draft_count      int
	scheduled_count  int
	recent_posts     []Post
	pages            []Post
	tags             []TagCount
	related_posts    []Post
	admin_filter     string
	page_title       string
	page_description string
	page_links       []int
	invalid_accent   bool
	toast_message    string
	toast_tone       string
	toast_icon       string
	scheduled_watch  []Post
	server_now       i64
	og_type          string
	editor           bool
	is_admin         bool
	invalid_userpass bool
	invalid_newpost  bool
	invalid_settings bool
	media_items      []Media
	media_query      string
	media_kind       string
	media_sort       string
	media_count      int
	media_images     int
	media_bytes      i64
	media_uploaded   string
	media_skipped    string
	media_error      string
	media_page       bool
	backups          []BackupEntry
	backup_schedule  BackupSchedule
	backup_intervals []int
	backup_count     int
	backup_bytes     i64
	backup_last      i64
	backup_next      i64
	backup_created   string
	backup_restored  string
	backup_saved     string
	backup_error     string
	backup_page      bool
}

pub struct App {
	veb.StaticHandler
pub mut:
	db            sqlite.DB
	config        Config
	search_res_nr int
}

fn main() {
	mut app := &App{}

	if run_command_line_options() {
		return
	}

	app.config = load_config()
	mut import_samples := false
	if app.config.client_secret.len == 0 { // My C days are catching up...
		import_samples = generate_config() or { exit(1) }
		app.config = load_config()
		if app.config.client_secret.len == 0 {
			println('Setup did not finish; run ./vblog again to retry.')
			exit(1)
		}
	}

	app.db = sqlite.connect('primary.sqlite') or {
		println('Database Error!')
		panic(err)
	}

	app.ensure_settings_schema()
	app.ensure_post_schema()
	app.ensure_media_schema()
	// Both the style-guide post and the rest of the sample content are part of
	// the same offer. Declining it leaves a genuinely empty blog; nothing is
	// written behind the author's back.
	if import_samples {
		app.ensure_demo_post()
		app.import_sample_data()
	}
	app.sync_media_library()

	// Automatic backups run on their own connection, so they keep working while
	// requests are being served.
	spawn run_backup_scheduler()

	app.handle_static('static', true) or { panic(err) }
	// Media is served by serve_media_file rather than a mounted folder: one
	// route means every upload, old or new, gets the same MIME type and the
	// same security headers.

	app.serve_static('/pure-min.css', 'static/css/pure-min.css') or { panic(err) }
	app.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css') or {
		panic(err)
	}
	app.serve_static('/style.css', 'static/css/style.css') or { panic(err) }
	app.serve_static('/admin.css', 'static/css/admin.css') or { panic(err) }

	veb.run[App, Context](mut app, app.config.port)
}

// prepare loads the current blog settings and admin state for one request.
pub fn (mut app App) prepare(mut ctx Context) {
	ctx.settings = app.load_settings()
	// Resolve the blog's zone once per request; every date shown or schedule
	// parsed in this response goes through it.
	ctx.tz = zone_location(ctx.settings.timezone)
	ctx.is_admin = app.auth(ctx)
	ctx.pages = app.get_pages()
	ctx.tags = app.get_tag_counts()
	ctx.editor = false
	ctx.media_page = false
	ctx.backup_page = false
	ctx.page_title = ctx.settings.blog_title
	ctx.page_description = plain_text(ctx.settings.blog_description, 160)
	ctx.og_type = 'website'
	// Response hardening for every page. None of it changes how the blog
	// renders: browsers must trust the declared type, may not frame the blog
	// inside another site, and other origins only learn where a visit came from.
	ctx.set_custom_header('X-Content-Type-Options', 'nosniff') or {}
	ctx.set_custom_header('X-Frame-Options', 'DENY') or {}
	ctx.set_custom_header('Referrer-Policy', 'strict-origin-when-cross-origin') or {}
	ctx.set_toast_from_query()
}

pub fn (mut app App) index(mut ctx Context) veb.Result {
	app.prepare(mut ctx)

	per_page := ctx.settings.posts_per_page
	blog_posts := app.get_posts_page(1, per_page)
	total_pages := app.get_pages_count(per_page)
	ctx.page_links = page_links(1, total_pages)

	return $veb.html()
}

// Browsers, feed readers and some tools still ask for /favicon.ico even when
// the page links its icon, so answer with the uploaded one instead of a 404.
@['/favicon.ico']
pub fn (mut app App) favicon_ico(mut ctx Context) veb.Result {
	settings := app.load_settings()
	if settings.favicon_url.len > 0 {
		return ctx.redirect(settings.favicon_url)
	}
	return ctx.not_found()
}

pub fn (ctx &Context) as_html(str string) veb.RawHtml {
	return veb.RawHtml(markdown_to_html(str))
}

// markdown_to_html renders Markdown and tiles any paragraph that holds two or
// more images into a gallery, so images on consecutive lines become a grid.
fn markdown_to_html(str string) string {
	html := markdown.to_html(str)
	mut out := []string{}
	mut rest := html
	for {
		start := rest.index('<p>') or { break }
		close := rest[start..].index('</p>') or { break }
		end := start + close
		inner := rest[start + 3..end]
		if is_image_paragraph(inner) {
			out << rest[..start]
			out << '<div class="post-gallery">' + inner + '</div>'
		} else {
			out << rest[..end + 4]
		}
		rest = rest[end + 4..]
	}
	out << rest
	return out.join('')
}

// is_image_paragraph is true when a paragraph contains nothing but images.
fn is_image_paragraph(inner string) bool {
	mut rest := inner.trim_space()
	mut images := 0
	for rest.starts_with('<img') {
		close := rest.index('>') or { return false }
		rest = rest[close + 1..].trim_space()
		images++
	}
	return images >= 2 && rest.len == 0
}

// 'page/:page_num' can change but the link will not be a consistant result over time; better to have a UUID/HASH
//  for each page and therefore results are unchanging.
@['/page/:page_num']
pub fn (mut app App) page(mut ctx Context, page_num int) veb.Result {
	app.prepare(mut ctx)

	per_page := ctx.settings.posts_per_page
	total_pages := app.get_pages_count(per_page)
	mut blog_posts := []Post{}
	mut invalid := false
	ctx.page_links = page_links(page_num, total_pages)
	ctx.page_title = 'Page ${page_num} — ${ctx.settings.blog_title}'
	if page_num >= 1 && page_num <= total_pages {
		blog_posts = app.get_posts_page(page_num, per_page)
	} else {
		invalid = true
	}
	return $veb.html()
}
