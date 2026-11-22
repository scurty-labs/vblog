module main

// Typed, single-row blog settings. The row always has id == 1.
//
// The show_* fields are 0/1 flags (SQLite has no boolean type): each one is a
// switch on the settings page that hides a piece of the blog the author may
// not want, so a blog can be as bare or as busy as its owner likes.
struct Settings {
pub mut:
	id                int
	blog_title        string
	blog_description  string
	logo_url          string
	logo_enabled      int
	favicon_url       string
	footer_text       string
	accent_foreground string
	theme             string
	timezone          string
	posts_per_page    int
	show_description  int
	show_pages        int
	show_tags         int
	show_rss          int
	show_post_meta    int
	show_footer       int
}

const default_theme = 'neon'

const default_footer_text = 'Powered by [veb](https://github.com/vlang/veb), written in the [V Programming Language](https://vlang.io/). · [RSS](/rss.xml) · [Sitemap](/sitemap.xml)'

// available_themes lists the stylesheets under static/themes; adding a theme
// only requires dropping a matching .css file there and adding its name here.
fn available_themes() []string {
	return [
		'default',
		'glass',
		'dark',
		'sepia',
		'ocean',
		'noir',
		'sakura',
		'forest',
		'neon',
		'sunset',
	]
}

fn valid_theme(name string) bool {
	return name in available_themes()
}

// checked renders a checkbox's `checked` attribute from a 0/1 settings flag.
pub fn (ctx &Context) checked(flag int) string {
	if flag != 0 {
		return 'checked'
	}
	return ''
}

// flag_from_form reads a 0/1 switch out of a submitted form. Checkbox values
// are only sent when ticked, so a missing key turns the setting off.
fn flag_from_form(form map[string]string, key string) int {
	if key !in form {
		return 0
	}
	return 1
}

// theme_label is the display name for a theme slug; settings store lowercase.
pub fn (ctx &Context) theme_label(name string) string {
	if name.len == 0 {
		return name
	}
	return name[..1].to_upper() + name[1..]
}

fn default_settings() Settings {
	return Settings{
		id:                1
		blog_title:        'My Blog'
		blog_description:  'A personal blogging system written in V.'
		logo_url:          ''
		logo_enabled:      0
		favicon_url:       ''
		footer_text:       default_footer_text
		accent_foreground: '#00dddd'
		theme:             default_theme
		timezone:          default_timezone
		posts_per_page:    10
		show_description:  1
		show_pages:        1
		show_tags:         1
		show_rss:          1
		show_post_meta:    1
		show_footer:       1
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

// valid_css_color keeps a bad value out of the `--accent` custom property,
// where it would silently break the accent everywhere. Hex, rgb()/rgba() and
// hsl()/hsla() cover the settings page's hint, and plain colour names are
// accepted since CSS understands them too.
fn valid_css_color(value string) bool {
	v := value.trim_space()
	if v.len == 0 {
		return false
	}
	if v.starts_with('#') {
		hex := v[1..]
		if hex.len !in [3, 4, 6, 8] {
			return false
		}
		for ch in hex {
			is_hex := (ch >= `0` && ch <= `9`) || (ch >= `a` && ch <= `f`) || (ch >= `A` && ch <= `F`)
			if !is_hex {
				return false
			}
		}
		return true
	}
	for prefix in ['rgb(', 'rgba(', 'hsl(', 'hsla('] {
		if v.starts_with(prefix) && v.ends_with(')') {
			inner := v[prefix.len..v.len - 1].trim_space()
			if inner.len == 0 {
				return false
			}
			for ch in inner {
				allowed := (ch >= `0` && ch <= `9`) || ch == `.` || ch == `,` || ch == `%`
					|| ch == ` ` || ch == `/` || ch == `-` || ch == `+`
				if !allowed {
					return false
				}
			}
			return true
		}
	}
	return v.to_lower() in ['black', 'white', 'red', 'green', 'blue', 'teal', 'orange', 'purple',
		'gray', 'grey', 'silver', 'navy', 'maroon', 'olive', 'lime', 'aqua', 'fuchsia', 'yellow',
		'pink', 'brown', 'gold', 'coral', 'crimson', 'indigo', 'violet', 'turquoise', 'salmon',
		'khaki', 'plum', 'orchid', 'beige', 'ivory', 'tan']
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
