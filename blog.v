module main

import vweb
import db.sqlite
import markdown // v install markdown

const (
	port = 8082
)

struct App {
	vweb.Context
pub mut:
	db               sqlite.DB
	config           Config
	settings         Settings
	invalid_userpass bool
	invalid_newpost  bool
	is_admin         bool
	search_res_nr    int
}

fn main() {
	mut app := &App{} // Initializing a referenced struct like this isn't good practice. We have initializers!

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

	app.settings = app.load_settings()!

	app.handle_static('static', true) // Should be was is

	app.serve_static('/pure-min.css', 'static/css/pure-min.css')
	app.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css')
	app.serve_static('/style.css', 'static/css/style.css')

	vweb.run(app, port)
}

pub fn (mut app App) init_server() {
	// Initialize defaults. Note: This is stupid. You have middleware/vweb_global now...
	app.invalid_userpass = false
	app.invalid_newpost = false
}

// Be sure to keep blog settings updated before each request
pub fn (mut app App) before_request() {
	app.settings = app.load_settings() or { Settings{} } // Must be called first!!
}

pub fn (mut app App) index() !vweb.Result {
	// println(app.get_posts_count().str() + ' - posts per pages: $app.settings.posts_per_page')
	// println(app.get_posts_page(0, app.settings.posts_per_page.int()))

	blog_posts := app.get_posts_page(0, app.settings.posts_per_page.int())!
	max_pages := app.get_posts_count()! / app.settings.posts_per_page.int()

	app.is_admin = app.auth()
	return $vweb.html()
}

pub fn (mut app App) as_html(str string) vweb.RawHtml {
	return vweb.RawHtml(markdown.to_html(str))
}

// 'page/:page_num' can change but the link will not be a consistant result over time; better to have a UUID/HASH
//  for each page and therefore results are unchanging.
['/page/:page_num']
pub fn (mut app App) page(page_num int) !vweb.Result {
	// println('post count: $app.get_posts_count()')
	// app.settings = app.load_settings()
	max_pages := app.get_posts_count()! / app.settings.posts_per_page.int()
	mut blog_posts := []Post{}
	mut invalid := false
	if page_num <= max_pages {
		blog_posts = app.get_posts_page(page_num, app.settings.posts_per_page.int())!
	} else {
		invalid = true
	}
	return $vweb.html()
}
