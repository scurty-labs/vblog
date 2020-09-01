module main

import strconv
import vweb
import sqlite
import markdown

const (
	port = 8082
)

struct App {
pub mut:
	vweb vweb.Context
	db sqlite.DB
	config Config
	settings Settings
	invalid_userpass bool
	invalid_newpost bool
	is_admin bool
	search_res_nr int
}

fn main() {
	vweb.run<App>(port)
}

pub fn (mut app App) init_once() {

	app.config = load_config()
	if app.config.client_secret.len == 0 {
		println('Cannot find configuration file. Entering setup...')
		generate_config()
		exit(1)
	}
	
	app.vweb.handle_static('.')
	
	app.vweb.serve_static('/pure-min.css', 'static/css/pure-min.css', 'text/css')
	app.vweb.serve_static('/pure-grids-responsive-min.css', 'static/css/pure-grids-responsive-min.css', 'text/css')
	app.vweb.serve_static('/style.css', 'static/css/style.css', 'text/css')
	
	app.db = sqlite.connect('primary.sqlite') or {
		println('Database Error!')
		panic(err)
	}
	
	app.load_settings()
	
	// Initialize Defaults
	app.invalid_userpass = false
	app.invalid_newpost = false
}

pub fn (mut app App) init() {

	// Refresh Settings
	app.load_settings()

}

pub fn (mut app App) index() vweb.Result {
	//blog_posts := app.get_all_posts()
	blog_posts := app.get_posts_page(0, strconv.atoi(app.settings.posts_per_page))
	max_pages := (app.get_posts_count() / strconv.atoi(app.settings.posts_per_page))
	app.is_admin = app.auth()
	return $vweb.html()
}

pub fn (mut app App) as_html(str string) vweb.RawHtml {
	return vweb.RawHtml(markdown.to_html(str))
}

['/page/:page_num']
pub fn (mut app App) page(page_num int) vweb.Result {
	max_pages := (app.get_posts_count() / strconv.atoi(app.settings.posts_per_page))
	mut blog_posts := []Post{}
	mut invalid := false
	if page_num <= max_pages {
		blog_posts = app.get_posts_page(page_num, strconv.atoi(app.settings.posts_per_page))
	}else{
		invalid = true
	}
	return $vweb.html()
}


