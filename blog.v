module main

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
	settings Settings
	invalid_userpass bool
	invalid_newpost bool
	is_admin bool
	search_res_nr int
	posts_per_page int
}

fn main() {
	vweb.run<App>(port)
}

pub fn (mut app App) init_once() {
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
	app.posts_per_page = 5
	app.invalid_userpass = false
	app.invalid_newpost = false
}

pub fn (mut app App) init() {}

pub fn (mut app App) index() vweb.Result {
	//blog_posts := app.get_all_posts()
	blog_posts := app.get_posts_page(0, app.posts_per_page)
	max_pages := (app.get_posts_count() / app.posts_per_page)
	app.is_admin = app.auth()
	return $vweb.html()
}

pub fn (mut app App) as_html(str string) vweb.RawHtml {
	return vweb.RawHtml(markdown.to_html(str))
}

['/page/:page_num']
pub fn (mut app App) page(page_num int) vweb.Result {
	max_pages := (app.get_posts_count() / app.posts_per_page)
	mut blog_posts := []Post{}
	mut invalid := false
	if page_num <= max_pages {
		blog_posts = app.get_posts_page(page_num, app.posts_per_page)
	}else{
		invalid = true
	}
	return $vweb.html()
}


