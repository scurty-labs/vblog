module main

import vweb
import time

['/edit/post/:post_id']
pub fn (mut app App) edit(post_id int) vweb.Result {
	if !app.auth() { return app.r_home() }
	post := app.get_post_by_id(post_id)
	invalid := app.invalid_newpost
	app.invalid_newpost = false // I GUESS THIS IS A GLOBAL VARIABLE?! Lol...
	return $vweb.html()
}

[post]
['/save/post/:post_id']
pub fn (mut app App) save_post(post_id int) vweb.Result {
	if !app.auth() { return app.r_home() }

	title := app.form['post_title']
	body := app.form['post_body']
	app.invalid_newpost = false

	if title != '' && body != '' {
		app.invalid_newpost = false
		app.update_post(post_id, title, body)
		return app.r_home()
	}else{
		app.invalid_newpost = true
		return app.redirect('/edit/post/$post_id/')
	}
	return app.r_home()
}

[post]
['/new/post']
pub fn (mut app App) create_new_post() vweb.Result {
	if !app.auth() { return app.r_home() }

	title := app.form['post_title']
	body := app.form['post_body']
	app.invalid_newpost = false

	if title.len > 0 && body.len > 0 { // Seems to not like large data in `body`
		t := time.now()
		app.insert_new_post(Post{title:title, body:body, date:t.unix_time() })
		return app.r_home()
	}else{
		app.invalid_newpost = true
		return app.redirect('/newpost')
	}
}

['/view/post/:post_id']
pub fn (mut app App) viewpost(post_id int) vweb.Result {
	app.settings = app.load_settings()
	post := app.get_post_by_id(post_id)
	if post.title == '' {
		return app.r_home()
	}
	return $vweb.html()
}

['/delete/post/:post_id']
pub fn (mut app App) delete_post_handle(post_id int) vweb.Result {
	if !app.auth() { return app.r_home() }

	app.delete_post(post_id)
	return app.r_home()
}

[post]
['/searchresults']
pub fn (mut app App) searchresults() vweb.Result {
	query := app.form['search']
	mut rel_post := []Post{}

	if query.len >= 1 {
		for post in app.get_all_posts() {
			if post.title.contains(query) || post.body.contains(query) {
				rel_post << post
			}
		}
	}

	return $vweb.html()
}