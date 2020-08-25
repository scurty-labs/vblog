module main

import vweb
import sqlite

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
	app.invalid_userpass = false
	app.invalid_newpost = false
}

pub fn (mut app App) init() {}

pub fn (mut app App) index() vweb.Result {
	blog_posts := app.get_all_posts()
	app.is_admin = app.auth()
	return $vweb.html()
}


