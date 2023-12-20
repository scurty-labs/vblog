module main

import vweb

@['/save/settings'; post]
pub fn (mut app App) save_settings() vweb.Result {
	if !app.auth() {
		return app.r_home()
	}

	// Oof. Uwu. What am I working on? CSGO GUI??
	app.settings.blog_title = app.form['blog_title']
	app.settings.blog_description = app.form['blog_description']
	app.settings.accent_foreground = app.form['accent_foreground']
	app.settings.custom_css = app.form['custom_css']
	app.settings.posts_per_page = app.form['posts_per_page']
	app.commit_settings()

	return app.r_home()
}
