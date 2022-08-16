module main

import vweb

struct Setting {
pub mut:
	id int
	key string
	value string
}

struct Settings {
pub mut:
	blog_title string
	blog_description string
	accent_foreground string
	custom_css string
	posts_per_page string
}

// -- TODO: Change! Use maps instead. --
pub fn (mut app App) load_settings() Settings {
	data := sql app.db { select from Setting }
	mut settings := Settings{}
	settings.blog_title = setting_get(data, 'blog_title')
	settings.blog_description = setting_get(data, 'blog_description')
	settings.accent_foreground = setting_get(data, 'accent_foreground')
	settings.custom_css = setting_get(data, 'custom_css')
	settings.posts_per_page = setting_get(data, 'posts_per_page')
	return settings
}

// Cringe...
fn setting_get(arr []Setting, key string) string {
	for i in arr {
		if i.key == key { return i.value }
	}
	return ''
}

pub fn (mut app App) commit_settings()  {

	// What have I done?!
	blog_title := app.settings.blog_title
	sql app.db { update Setting set value = blog_title where key == 'blog_title' }
	
	blog_description := app.settings.blog_description
	sql app.db { update Setting set value = blog_description where key == 'blog_description' }
	
	accent_foreground := app.settings.accent_foreground
	sql app.db { update Setting set value = accent_foreground where key == 'accent_foreground' }
	
	custom_css := app.settings.custom_css
	sql app.db { update Setting set value = custom_css where key == 'custom_css' }
	
	posts_per_page := app.settings.posts_per_page
	sql app.db { update Setting set value = posts_per_page where key == 'posts_per_page' }
}

[post]
['/save/settings']
pub fn (mut app App) save_settings() vweb.Result {
	if !app.auth() { return app.r_home() }
	
	// Oof. Uwu. What am I working on? CSGO GUI??
	app.settings.blog_title = app.form['blog_title']
	app.settings.blog_description = app.form['blog_description']
	app.settings.accent_foreground = app.form['accent_foreground']
	app.settings.custom_css = app.form['custom_css']
	app.settings.posts_per_page = app.form['posts_per_page']
	app.commit_settings()
	
	return app.r_home()
}
