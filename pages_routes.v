module main

import veb
import time

// Pages are posts flagged as pages. They keep their own URL, appear in the
// sidebar instead of the post feed and are managed from the admin dashboard.

@['/pages/:page_id']
pub fn (mut app App) viewpage(mut ctx Context, page_id int) veb.Result {
	app.prepare(mut ctx)
	page_item := app.get_post_by_id(page_id) or { return app.r_home(mut ctx) }
	if page_item.is_page == 0 || page_item.deleted != 0 {
		return app.r_home(mut ctx)
	}
	ctx.page_title = '${page_item.title} — ${ctx.settings.blog_title}'
	ctx.page_description = plain_text(page_item.body, 160)
	ctx.og_type = 'article'
	return $veb.html()
}

@['/newpage']
pub fn (mut app App) newpage(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	ctx.editor = true
	ctx.invalid_newpost = ctx.query['invalid'] or { '' } == '1'
	invalid := ctx.invalid_newpost
	ctx.page_title = 'New page — ${ctx.settings.blog_title}'
	return $veb.html()
}

@['/create/page'; post]
pub fn (mut app App) create_page(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	title := (ctx.form['post_title'] or { '' }).trim_space()
	body := ctx.form['post_body'] or { '' }
	ctx.invalid_newpost = false

	if title.len == 0 || body.len == 0 {
		return ctx.redirect('/newpage?invalid=1')
	}

	page_id := app.insert_page(Post{
		title:   title
		body:    body
		date:    time.now().unix()
		is_page: 1
	})
	if page_id == 0 {
		return ctx.redirect('/newpage?invalid=1')
	}
	return ctx.redirect('/pages/${page_id}?saved=page-created')
}

@['/edit/page/:page_id']
pub fn (mut app App) editpage(mut ctx Context, page_id int) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	page_item := app.get_post_by_id(page_id) or { return app.r_home(mut ctx) }
	if page_item.is_page == 0 || page_item.deleted != 0 {
		return app.r_home(mut ctx)
	}
	ctx.editor = true
	ctx.invalid_newpost = ctx.query['invalid'] or { '' } == '1'
	invalid := ctx.invalid_newpost
	ctx.page_title = 'Edit “${page_item.title}” — ${ctx.settings.blog_title}'
	return $veb.html()
}

@['/save/page/:page_id'; post]
pub fn (mut app App) save_page(mut ctx Context, page_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	page_item := app.get_post_by_id(page_id) or { return app.r_home(mut ctx) }
	if page_item.is_page == 0 || page_item.deleted != 0 {
		return app.r_home(mut ctx)
	}

	title := (ctx.form['post_title'] or { '' }).trim_space()
	body := ctx.form['post_body'] or { '' }
	ctx.invalid_newpost = false

	if title.len == 0 || body.len == 0 {
		return ctx.redirect('/edit/page/${page_id}?invalid=1')
	}

	app.update_post(page_id, title, body)
	return ctx.redirect('/pages/${page_id}?saved=page')
}

@['/delete/page/:page_id']
pub fn (mut app App) delete_page_handle(mut ctx Context, page_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	page_item := app.get_post_by_id(page_id) or { return app.r_home(mut ctx) }
	if page_item.is_page == 0 {
		return app.r_home(mut ctx)
	}
	app.delete_post(page_id)
	return ctx.redirect('/admin')
}

// Promoting a post turns it into a page while keeping its body and id.
@['/promote/post/:post_id']
pub fn (mut app App) promote_post(mut ctx Context, post_id int) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	post := app.get_post_by_id(post_id) or { return app.r_home(mut ctx) }
	if post.deleted != 0 {
		return app.r_home(mut ctx)
	}
	app.promote_to_page(post_id)
	return ctx.redirect('/pages/${post_id}')
}
