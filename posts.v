module main

import vweb
import time

struct Post {
pub mut:

	id int
	title string
	body string
	deleted int
	date int
}

pub fn (mut app App) get_all_posts() []Post {
	posts := sql app.db { select from Post where deleted == 0 order by date desc }
	return posts
}

pub fn (post Post) format_date() string {
	t := time.unix(post.date)
	return t.format()
}

pub fn (mut app App) get_post_by_id(post_id int) Post {
	post := sql app.db { select from Post where id == post_id limit 1 }
	return post
}

pub fn (mut app App) update_post(post_id int, t string, b string) {
	sql app.db { update Post set title = t, body = b where id == post_id }
}

pub fn (mut app App) insert_new_post(post Post) {
	sql app.db { insert post into Post }
}

pub fn (mut app App) delete_post(post_id int) {
	sql app.db { update Post set deleted = 1 where id == post_id }
}

pub fn (mut app App) newpost() vweb.Result {
	if !app.auth() { return app.r_home() }
	invalid := app.invalid_newpost
	app.invalid_newpost = false
	return $vweb.html()
}

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

	title := app.vweb.form['post_title']
	body := app.vweb.form['post_body']
	app.invalid_newpost = false
	
	if title != '' && body != '' {
		app.invalid_newpost = false
		app.update_post(post_id, title, body)
		return app.r_home()
	}else{
		app.invalid_newpost = true
		return app.vweb.redirect('/edit/post/$post_id/')
	}
	return app.r_home()
}

[post] 
['/new/post']
pub fn (mut app App) create_new_post() vweb.Result {
	if !app.auth() { return app.r_home() }
	
	title := app.vweb.form['post_title']
	body := app.vweb.form['post_body']
	app.invalid_newpost = false
	
	if title != '' && body != '' {
		t := time.now()
		app.insert_new_post(Post{title:title, body:body, date:t.unix_time()})
		return app.r_home()
	}else{
		app.invalid_newpost = true
		return app.vweb.redirect('/newpost')
	}
}

['/view/post/:post_id']
pub fn (mut app App) viewpost(post_id int) vweb.Result {
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
	query := app.vweb.form['search']
	mut rel_post := []Post{}
	
	if query.len > 2 {
	
		for post in app.get_all_posts() {
			if post.title.contains(query) || post.body.contains(query) {
				rel_post << post
			}
		}
	
	}
	return $vweb.html()
}

