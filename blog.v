module main

import veb
import db.sqlite
import markdown // v install markdown

const port = 8082

pub struct Context {
	veb.Context
pub mut:
	settings         Settings
	themes           []string
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

	app.config = load_config()
	if app.config.client_secret.len == 0 { // My C days are catching up...
		println('Cannot find configuration file. Entering setup...')
		generate_config()
		exit(1)
	}

	app.db = sqlite.connect('primary.sqlite') or {
		println('Database Error!')
		panic(err)
	}

	app.ensure_settings_schema()
	app.ensure_post_schema()
	app.ensure_demo_post()
	app.ensure_media_schema()
	app.sync_media_library()

	app.handle_static('static', true) or { panic(err) }
	app.mount_static_folder_at(media_dir, '/media') or { panic(err) }

	app.serve_static('/pure-min.css', 'static/css/pure-min.css') or { panic(err) }
	app.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css') or {
		panic(err)
	}
	app.serve_static('/style.css', 'static/css/style.css') or { panic(err) }
	app.serve_static('/admin.css', 'static/css/admin.css') or { panic(err) }

	veb.run[App, Context](mut app, port)
}

// prepare loads the current blog settings and admin state for one request.
pub fn (mut app App) prepare(mut ctx Context) {
	ctx.settings = app.load_settings()
	ctx.is_admin = app.auth(ctx)
	ctx.pages = app.get_pages()
	ctx.tags = app.get_tag_counts()
	ctx.editor = false
	ctx.media_page = false
	ctx.page_title = ctx.settings.blog_title
	ctx.page_description = plain_text(ctx.settings.blog_description, 160)
	ctx.og_type = 'website'
}

pub fn (mut app App) index(mut ctx Context) veb.Result {
	app.prepare(mut ctx)

	per_page := ctx.settings.posts_per_page
	blog_posts := app.get_posts_page(1, per_page)
	total_pages := app.get_pages_count(per_page)

	return $veb.html()
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
	ctx.page_title = 'Page ${page_num} — ${ctx.settings.blog_title}'
	if page_num >= 1 && page_num <= total_pages {
		blog_posts = app.get_posts_page(page_num, per_page)
	} else {
		invalid = true
	}
	return $veb.html()
}
