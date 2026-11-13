module main

import veb
import time

pub fn (mut app App) get_all_posts() []Post {
	posts := sql app.db {
		select from Post where deleted == 0 order by date desc
	} or {
		[]Post{}
	}
	return posts
}

pub fn (mut app App) get_posts_count() int {
	num := sql app.db {
		select count from Post where deleted == 0
	} or { 0 }
	return num
}

pub fn (post Post) format_date() string { // Bruh...
	t := time.unix(post.date)
	return t.format()
}

pub fn (mut app App) get_post_by_id(post_id int) ?Post {
	posts := sql app.db {
		select from Post where id == post_id limit 1
	} or { []Post{} }
	if posts.len == 0 {
		return none
	}
	return posts[0]
}

pub fn (mut app App) get_pages_count(num_per int) int {
	if num_per <= 0 {
		return 0
	}
	count := app.get_posts_count()
	return (count + num_per - 1) / num_per
}

pub fn (mut app App) get_posts_page(page_num int, num_per int) []Post {
	offs := (page_num - 1) * num_per
	posts := sql app.db {
		select from Post where deleted == 0 order by date desc limit num_per offset offs
	} or { []Post{} }
	return posts
}

pub fn (mut app App) update_post(post_id int, t string, b string) {
	sql app.db {
		update Post set title = t, body = b where id == post_id
	} or {
		eprintln("Couldn't update existing post!")
	}
}

pub fn (mut app App) insert_new_post(post Post) {
	// println(post)
	sql app.db {
		insert post into Post
	} or {
		eprintln("Couldn't insert new post!")
	}
}

pub fn (mut app App) delete_post(post_id int) {
	sql app.db {
		update Post set deleted = 1 where id == post_id
	} or {
		eprintln("Couldn't set delete flag on existing post!")
	}
}

pub fn (mut app App) newpost(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	invalid := ctx.invalid_newpost
	ctx.invalid_newpost = false
	return $veb.html()
}
