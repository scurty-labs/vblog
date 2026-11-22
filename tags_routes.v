module main

import strconv
import veb

// /tags is the admin's tag manager: every tag with its post count, plus
// rename, remove and attach forms.
@['/tags']
pub fn (mut app App) tags(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	ctx.recent_posts = app.get_admin_posts('all', 100)
	ctx.page_title = 'Tags — ${ctx.settings.blog_title}'
	return $veb.html()
}

@['/tags/rename'; post]
pub fn (mut app App) rename_tag_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	old := normalize_tag(ctx.form['old'] or { '' })
	new_name := normalize_tag(ctx.form['new'] or { '' })
	if old.len > 0 && new_name.len > 0 && old != new_name {
		app.rename_tag(old, new_name)
	}
	return ctx.redirect('/tags')
}

@['/tags/remove'; post]
pub fn (mut app App) remove_tag_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	tag := normalize_tag(ctx.form['tag'] or { '' })
	if tag.len > 0 {
		app.remove_tag(tag)
	}
	return ctx.redirect('/tags')
}

@['/tags/add'; post]
pub fn (mut app App) add_tag_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	tag := (ctx.form['tag'] or { '' }).trim_space()
	post_id := strconv.atoi((ctx.form['post_id'] or { '0' }).trim_space()) or { 0 }
	if tag.len > 0 && post_id > 0 {
		app.add_tag_to_post(post_id, tag)
	}
	return ctx.redirect('/tags')
}

// /tag/:tag lists every published post carrying a tag, newest first.
@['/tag/:tag']
pub fn (mut app App) tag_page(mut ctx Context, tag string) veb.Result {
	app.prepare(mut ctx)
	tag_name := normalize_tag(tag)
	if tag_name.len == 0 {
		return app.r_home(mut ctx)
	}
	tag_posts := app.get_posts_by_tag(tag_name)
	ctx.page_title = 'Tagged “${tag_name}” — ${ctx.settings.blog_title}'
	ctx.page_description = '${tag_posts.len} post(s) tagged ${tag_name}.'
	return $veb.html()
}
