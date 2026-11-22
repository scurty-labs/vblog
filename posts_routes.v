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
	if post.is_page == 1 || post.deleted != 0 {
		return ctx.redirect('/edit/page/${post_id}')
	}
	ctx.editor = true
	ctx.invalid_newpost = ctx.query['invalid'] or { '' } == '1'
	invalid := ctx.invalid_newpost
	ctx.page_title = 'Edit “${post.title}” — ${ctx.settings.blog_title}'
	return $veb.html()
}

@['/save/post/:post_id'; post]
pub fn (mut app App) save_post(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	post := app.get_post_by_id(post_id) or { return app.r_home(mut ctx) }
	if post.is_page == 1 || post.deleted != 0 {
		return app.r_home(mut ctx)
	}

	title := (ctx.form['post_title'] or { '' }).trim_space()
	body := ctx.form['post_body'] or { '' }

	if title.len == 0 || body.len == 0 {
		return ctx.redirect('/edit/post/${post_id}?invalid=1')
	}

	status := if (ctx.form['post_status'] or { 'published' }) == 'draft' {
		'draft'
	} else {
		'published'
	}
	now := time.now().unix()
	mut publish_at := parse_wall_time(ctx.form['publish_at'] or { '' }, ctx.zone())
	if status == 'draft' || (publish_at > 0 && publish_at <= now) {
		publish_at = 0
	}
	mut date := post.date
	if status == 'published' {
		if publish_at > 0 {
			date = publish_at
		} else if post.publish_at > 0 {
			// Clearing a schedule publishes the post now, not in the future.
			date = now
		}
	}
	// A draft made from a scheduled post must not keep its future date.
	if publish_at == 0 && date > now {
		date = now
	}

	app.update_post_details(post_id, title, body, normalize_tags(ctx.form['post_tags'] or {
		''
	}), status, publish_at, date)

	// The page the editor lands on carries the confirmation: a draft, a new
	// schedule, a post that just went live, or a plain update.
	was_live := post.status == 'published' && post.publish_at == 0
	mut toast := 'updated'
	if status == 'draft' {
		toast = 'draft'
	} else if publish_at > 0 {
		toast = 'scheduled'
	} else if !was_live {
		toast = 'published'
	}
	if publish_at > 0 {
		return ctx.redirect('/view/post/${post_id}?saved=${toast}&at=${publish_at}')
	}
	return ctx.redirect('/view/post/${post_id}?saved=${toast}')
}

@['/new/post'; post]
pub fn (mut app App) create_new_post(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	title := (ctx.form['post_title'] or { '' }).trim_space()
	body := ctx.form['post_body'] or { '' }

	if title.len == 0 || body.len == 0 {
		return ctx.redirect('/newpost?invalid=1')
	}

	status := if (ctx.form['post_status'] or { 'published' }) == 'draft' {
		'draft'
	} else {
		'published'
	}
	now := time.now().unix()
	mut publish_at := parse_wall_time(ctx.form['publish_at'] or { '' }, ctx.zone())
	if status == 'draft' || (publish_at > 0 && publish_at <= now) {
		publish_at = 0
	}
	date := if publish_at > 0 { publish_at } else { now }

	post_id := app.insert_post(Post{
		title:      title
		body:       body
		tags:       normalize_tags(ctx.form['post_tags'] or { '' })
		status:     status
		publish_at: publish_at
		date:       date
	})
	if post_id == 0 {
		return ctx.redirect('/newpost?invalid=1')
	}
	toast := if status == 'draft' {
		'draft'
	} else if publish_at > 0 {
		'scheduled'
	} else {
		'published'
	}
	if publish_at > 0 {
		return ctx.redirect('/view/post/${post_id}?saved=${toast}&at=${publish_at}')
	}
	return ctx.redirect('/view/post/${post_id}?saved=${toast}')
}

@['/view/post/:post_id']
pub fn (mut app App) viewpost(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	post := app.get_post_by_id(post_id) or { return app.r_home(mut ctx) }
	if post.title == '' || post.deleted != 0 {
		return app.r_home(mut ctx)
	}
	if post.is_page == 1 {
		return ctx.redirect('/pages/${post_id}')
	}
	// Drafts and scheduled posts are private until they go live, except to the
	// signed-in admin previewing their own work.
	if !ctx.is_admin && (post.status == 'draft' || post.is_scheduled()) {
		return app.r_home(mut ctx)
	}
	ctx.page_title = '${post.title} — ${ctx.settings.blog_title}'
	ctx.page_description = plain_text(post.body, 160)
	ctx.og_type = 'article'
	ctx.related_posts = app.get_related_posts(&post, 3)
	return $veb.html()
}

@['/delete/post/:post_id']
pub fn (mut app App) delete_post_handle(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	app.delete_post(post_id)
	return app.r_home(mut ctx)
}

// Publishing controls used by the dashboard and the post preview.
@['/publish/post/:post_id']
pub fn (mut app App) publish_post_handle(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	if post := app.get_post_by_id(post_id) {
		if post.deleted == 0 && post.is_page == 0 {
			app.publish_post_now(post_id)
		}
	}
	return ctx.redirect('/admin')
}

@['/unpublish/post/:post_id']
pub fn (mut app App) unpublish_post_handle(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	if post := app.get_post_by_id(post_id) {
		if post.deleted == 0 && post.is_page == 0 {
			app.unpublish_post(post_id)
		}
	}
	return ctx.redirect('/admin')
}

@['/duplicate/post/:post_id']
pub fn (mut app App) duplicate_post_handle(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	copy_id := app.duplicate_post(post_id)
	if copy_id == 0 {
		return ctx.redirect('/admin')
	}
	return ctx.redirect('/edit/post/${copy_id}')
}

@['/searchresults'; post]
pub fn (mut app App) searchresults(mut ctx Context) veb.Result {
	app.prepare(mut ctx)

	query := (ctx.form['search'] or { '' }).trim_space()
	ctx.search_query = query
	mut rel_post := []Post{}

	if query.len > 0 {
		needle := query.to_lower()
		for post in app.get_published_posts() {
			if post.title.to_lower().contains(needle) || post.body.to_lower().contains(needle)
				|| post.tags.to_lower().contains(needle) {
				rel_post << post
			}
		}
	}
	ctx.page_title = 'Search: ${query} — ${ctx.settings.blog_title}'
	ctx.page_description = '${rel_post.len} result(s) for “${query}”.'
	return $veb.html()
}
