module main

// Mega cringe...
pub fn (mut app App) commit_settings() {
	// What have I done?!
	blog_title := app.settings.blog_title
	sql app.db {
		update Setting set value = blog_title where key == 'blog_title'
	} or { eprintln("Couldn't update settings.") }

	blog_description := app.settings.blog_description
	sql app.db {
		update Setting set value = blog_description where key == 'blog_description'
	} or { eprintln("Couldn't update settings.") }

	accent_foreground := app.settings.accent_foreground
	sql app.db {
		update Setting set value = accent_foreground where key == 'accent_foreground'
	} or { eprintln("Couldn't update settings.") }

	custom_css := app.settings.custom_css
	sql app.db {
		update Setting set value = custom_css where key == 'custom_css'
	} or { eprintln("Couldn't update settings.") }

	posts_per_page := app.settings.posts_per_page
	sql app.db {
		update Setting set value = posts_per_page where key == 'posts_per_page'
	} or { eprintln("Couldn't update settings.") }
}
