module main

// Typed, single-row blog settings. The row always has id == 1.
struct Settings {
pub mut:
	id                int
	blog_title        string
	blog_description  string
	accent_foreground string
	theme             string
	posts_per_page    int
}

const default_theme = 'default'

// available_themes lists the stylesheets under static/themes; adding a theme
// only requires dropping a matching .css file there and adding its name here.
fn available_themes() []string {
	return ['default', 'dark', 'sepia', 'ocean']
}

fn valid_theme(name string) bool {
	return name in available_themes()
}

fn default_settings() Settings {
	return Settings{
		id:                1
		blog_title:        'My Blog'
		blog_description:  'A personal blogging system written in V.'
		accent_foreground: '#007711'
		theme:             default_theme
		posts_per_page:    10
	}
}

// Legacy key/value row, kept only so existing databases can be migrated.
struct Setting {
pub mut:
	id    int
	key   string
	value string
}

pub fn (mut app App) load_settings() Settings {
	rows := sql app.db {
		select from Settings where id == 1 limit 1
	} or { []Settings{} }
	if rows.len == 0 {
		return default_settings()
	}
	mut settings := rows[0]
	if !valid_theme(settings.theme) {
		settings.theme = default_theme
	}
	return settings
}

fn clamp_posts_per_page(n int) int {
	if n < 1 {
		return 1
	}
	if n > 100 {
		return 100
	}
	return n
}
