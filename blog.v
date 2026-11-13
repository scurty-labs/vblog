module main

import veb
import db.sqlite
import markdown // v install markdown

const (
	port = 8082
)

pub struct Context {
	veb.Context
pub mut:
	settings         Settings
	is_admin         bool
	invalid_userpass bool
	invalid_newpost  bool
}

pub struct App {
	veb.StaticHandler
pub mut:
	db            sqlite.DB
	config        Config
	settings      Settings
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

	app.settings = app.load_settings()

	app.handle_static('static', true) or { panic(err) }

	app.serve_static('/pure-min.css', 'static/css/pure-min.css') or { panic(err) }
	app.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css') or {
		panic(err)
	}
	app.serve_static('/style.css', 'static/css/style.css') or { panic(err) }

	veb.run[App, Context](mut app, port)
}

// prepare loads the current blog settings and admin state for one request.
pub fn (mut app App) prepare(mut ctx Context) {
	ctx.settings = app.load_settings()
	ctx.is_admin = app.auth(ctx)
}

pub fn (mut app App) index(mut ctx Context) veb.Result {
	app.prepare(mut ctx)

	blog_posts := app.get_posts_page(0, ctx.settings.posts_per_page.int())
	max_pages := app.get_posts_count() / ctx.settings.posts_per_page.int()

	return $veb.html()
}

pub fn (ctx &Context) as_html(str string) veb.RawHtml {
	return veb.RawHtml(markdown.to_html(str))
}

// 'page/:page_num' can change but the link will not be a consistant result over time; better to have a UUID/HASH
//  for each page and therefore results are unchanging.
@['/page/:page_num']
pub fn (mut app App) page(mut ctx Context, page_num int) veb.Result {
	app.prepare(mut ctx)

	max_pages := app.get_posts_count() / ctx.settings.posts_per_page.int()
	mut blog_posts := []Post{}
	mut invalid := false
	if page_num <= max_pages {
		blog_posts = app.get_posts_page(page_num, ctx.settings.posts_per_page.int())
	} else {
		invalid = true
	}
	return $veb.html()
}
