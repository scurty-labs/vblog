module main

import vweb
import time

pub fn (mut app App) get_all_posts() ![]Post {
	posts := sql app.db {
		select from Post where deleted == 0 order by date desc
	}!
	return posts
}

pub fn (mut app App) get_posts_count() !int {
	num := sql app.db {
		select count from Post where deleted == 0
	}!
	return num
}

pub fn (post Post) format_date() string { // Bruh...
	t := time.unix(post.date)
	return t.format()
}

pub fn (mut app App) get_post_by_id(post_id int) !Post {
	post := sql app.db {
		select from Post where id == post_id limit 1
	}!
	return post[0]
}

pub fn (mut app App) get_posts_page(page_num int, num_per int) ![]Post {
	offs := page_num * num_per
	posts := sql app.db {
		select from Post where deleted == 0 order by date desc limit num_per offset offs
	}!
	return posts
}

pub fn (mut app App) update_post(post_id int, t string, b string) ! {
	sql app.db {
		update Post set title = t, body = b where id == post_id
	}!
}

pub fn (mut app App) insert_new_post(post Post) ! {
	// println(post)
	sql app.db {
		insert post into Post
	}!
}

pub fn (mut app App) delete_post(post_id int) ! {
	sql app.db {
		update Post set deleted = 1 where id == post_id
	}!
}

pub fn (mut app App) newpost() vweb.Result {
	if !app.auth() {
		return app.r_home()
	}
	invalid := app.invalid_newpost
	app.invalid_newpost = false
	return $vweb.html()
}
