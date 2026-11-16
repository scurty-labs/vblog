module main

import veb
import strconv

@['/save/settings'; post]
pub fn (mut app App) save_settings(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	mut settings := app.load_settings()
	settings.blog_title = (ctx.form['blog_title'] or { settings.blog_title }).trim_space()
	settings.blog_description = ctx.form['blog_description'] or { settings.blog_description }
	settings.footer_text = (ctx.form['footer_text'] or { settings.footer_text }).trim_space()
	accent := (ctx.form['accent_foreground'] or { settings.accent_foreground }).trim_space()
	if accent.len > 0 {
		settings.accent_foreground = accent
	}
	theme := (ctx.form['theme'] or { settings.theme }).trim_space()
	if valid_theme(theme) {
		settings.theme = theme
	}
	parsed_per_page := strconv.atoi((ctx.form['posts_per_page'] or { settings.posts_per_page.str() }).trim_space()) or {
		settings.posts_per_page
	}
	settings.posts_per_page = clamp_posts_per_page(parsed_per_page)

	app.write_settings(settings) or {
		eprintln("Couldn't save settings: ${err}")
		ctx.invalid_settings = true
		return app.settings(mut ctx)
	}

	return ctx.redirect('/settings')
}
