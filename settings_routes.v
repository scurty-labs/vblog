module main

import veb

@['/save/settings'; post]
pub fn (mut app App) save_settings(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	// Oof. Uwu. What am I working on? CSGO GUI??
	app.settings.blog_title = ctx.form['blog_title'] or { '' }
	app.settings.blog_description = ctx.form['blog_description'] or { '' }
	app.settings.accent_foreground = ctx.form['accent_foreground'] or { '' }
	app.settings.custom_css = ctx.form['custom_css'] or { '' }
	app.settings.posts_per_page = ctx.form['posts_per_page'] or { '' }
	app.commit_settings()

	return app.r_home(mut ctx)
}
