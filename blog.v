module main

import vweb
import sqlite
import markdown

const (
	port = 8082
)

struct App {
	vweb.Context
pub mut:
	db sqlite.DB
	config Config
	settings Settings
	invalid_userpass bool
	invalid_newpost bool
	is_admin bool
	search_res_nr int
}

fn main() {
	mut app := &App{}

	app.config = load_config()
	if app.config.client_secret.len == 0 {
		println('Cannot find configuration file. Entering setup...')
		generate_config()
		exit(1)
	}

	app.db = sqlite.connect('primary.sqlite') or {
		println('Database Error!')
		panic(err)
	}

	app.settings = app.load_settings()

	app.handle_static('static', true)
	
	app.serve_static('/pure-min.css', 'static/css/pure-min.css')
	app.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css')
	app.serve_static('/style.css', 'static/css/style.css')
	
	vweb.run(app, port)
}

pub fn (mut app App) init_once() {
	
	// Initialize Defaults
	app.invalid_userpass = false
	app.invalid_newpost = false
	
}

pub fn (mut app App) index() vweb.Result {
	app.settings = app.load_settings() // Must be called first!! TODO: Call in `before_request()`?

	//println(app.get_posts_count().str() + ' - posts per pages: $app.settings.posts_per_page')
	//println(app.get_posts_page(0, app.settings.posts_per_page.int()))

	blog_posts := app.get_posts_page(0, app.settings.posts_per_page.int())
	max_pages := app.get_posts_count() / app.settings.posts_per_page.int()
	
	app.is_admin = app.auth()
	return $vweb.html()
}

pub fn (mut app App) as_html(str string) vweb.RawHtml {
	return vweb.RawHtml(markdown.to_html(str))
}

['/page/:page_num']
pub fn (mut app App) page(page_num int) vweb.Result {
	//println('post count: $app.get_posts_count()')
	app.settings = app.load_settings()
	max_pages := app.get_posts_count() / app.settings.posts_per_page.int()
	mut blog_posts := []Post{}
	mut invalid := false
	if page_num <= max_pages {
		blog_posts = app.get_posts_page(page_num, app.settings.posts_per_page.int() )
	}else{
		invalid = true
	}
	return $vweb.html()
}


