module main

struct Setting {
pub mut:
	id    int
	key   string
	value string
}

struct Settings {
pub mut:
	blog_title        string
	blog_description  string
	accent_foreground string
	custom_css        string
	posts_per_page    string
}

// -- TODO: Change! Use maps instead. --
pub fn (mut app App) load_settings() !Settings {
	data := sql app.db {
		select from Setting
	}!
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
		if i.key == key {
			return i.value
		}
	}
	return ''
}
