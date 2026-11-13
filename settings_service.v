module main

import strconv

// ensure_settings_schema creates the single-row settings table, seeds it, and
// upgrades databases that still use the legacy key/value `setting` table.
fn (mut app App) ensure_settings_schema() {
	app.db.execute("CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY CHECK (id = 1), blog_title TEXT NOT NULL DEFAULT '', blog_description TEXT NOT NULL DEFAULT '', accent_foreground TEXT NOT NULL DEFAULT '#007711', custom_css TEXT NOT NULL DEFAULT '', posts_per_page INTEGER NOT NULL DEFAULT 10)") or {
		panic(err)
	}

	count := sql app.db {
		select count from Settings
	} or { 0 }
	if count == 0 {
		seed := default_settings()
		sql app.db {
			insert seed into Settings
		} or { panic(err) }
	}

	app.migrate_legacy_settings()
}

fn (mut app App) migrate_legacy_settings() {
	tables := app.db.execute("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'setting'") or {
		return
	}
	if tables.len == 0 {
		return
	}

	legacy := sql app.db {
		select from Setting
	} or { []Setting{} }

	if legacy.len > 0 {
		mut settings := app.load_settings()
		for row in legacy {
			match row.key {
				'blog_title' { settings.blog_title = row.value }
				'blog_description' { settings.blog_description = row.value }
				'accent_foreground' { settings.accent_foreground = row.value }
				'custom_css' { settings.custom_css = row.value }
				'posts_per_page' {
					parsed := strconv.atoi(row.value.trim_space()) or { settings.posts_per_page }
					settings.posts_per_page = clamp_posts_per_page(parsed)
				}
				else {}
			}
		}
		app.write_settings(settings) or {
			eprintln("Couldn't migrate settings: ${err}")
			return
		}
	}

	app.db.execute('DROP TABLE setting') or {
		eprintln("Couldn't drop legacy setting table: ${err}")
	}
}

fn (mut app App) write_settings(settings Settings) ! {
	sql app.db {
		update Settings set blog_title = settings.blog_title, blog_description = settings.blog_description, accent_foreground = settings.accent_foreground, custom_css = settings.custom_css, posts_per_page = settings.posts_per_page where id == 1
	}!
}
