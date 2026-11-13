module main

import veb
import time

@['/edit/post/:post_id']
pub fn (mut app App) edit(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	post := app.get_post_by_id(post_id) or { return app.r_home(mut ctx) }
	invalid := ctx.invalid_newpost
	ctx.invalid_newpost = false
	return $veb.html()
}

@['/save/post/:post_id'; post]
pub fn (mut app App) save_post(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	title := ctx.form['post_title'] or { '' }
	body := ctx.form['post_body'] or { '' }
	ctx.invalid_newpost = false

	if title != '' && body != '' {
		ctx.invalid_newpost = false
		app.update_post(post_id, title, body)
		return app.r_home(mut ctx)
	} else {
		ctx.invalid_newpost = true
		return ctx.redirect('/edit/post/${post_id}/')
	}
	return app.r_home(mut ctx)
}

@['/new/post'; post]
pub fn (mut app App) create_new_post(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	title := ctx.form['post_title'] or { '' }
	body := ctx.form['post_body'] or { '' }
	ctx.invalid_newpost = false

	if title.len > 0 && body.len > 0 { // Seems to not like large data in `body`
		t := time.now()
		app.insert_new_post(Post{
			title: title
			body: body
			date: t.unix()
		})
		return app.r_home(mut ctx)
	} else {
		ctx.invalid_newpost = true
		return ctx.redirect('/newpost')
	}
}

@['/view/post/:post_id']
pub fn (mut app App) viewpost(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	post := app.get_post_by_id(post_id) or { return app.r_home(mut ctx) }
	if post.title == '' {
		return app.r_home(mut ctx)
	}
	return $veb.html()
}

@['/delete/post/:post_id']
pub fn (mut app App) delete_post_handle(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	app.delete_post(post_id)
	return app.r_home(mut ctx)
}

@['/searchresults'; post]
pub fn (mut app App) searchresults(mut ctx Context) veb.Result {
	app.prepare(mut ctx)

	query := ctx.form['search'] or { '' }
	mut rel_post := []Post{}

	if query.len >= 1 {
		for post in app.get_all_posts() {
			if post.title.contains(query) || post.body.contains(query) {
				rel_post << post
			}
		}
	}

	return $veb.html()
}
