module main

import strconv

// ensure_settings_schema creates the single-row settings table, seeds it, and
// upgrades databases that still use the legacy key/value `setting` table.
fn (mut app App) ensure_settings_schema() {
	app.db.execute("CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY CHECK (id = 1), blog_title TEXT NOT NULL DEFAULT '', blog_description TEXT NOT NULL DEFAULT '', accent_foreground TEXT NOT NULL DEFAULT '#007711', theme TEXT NOT NULL DEFAULT 'default', posts_per_page INTEGER NOT NULL DEFAULT 10)") or {
		panic(err)
	}

	app.upgrade_settings_table()

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

// upgrade_settings_table adds the theme column to databases created before
// themes existed and drops the retired custom_css column when SQLite allows it.
// CREATE TABLE IF NOT EXISTS leaves older tables untouched, so this is guarded.
fn (mut app App) upgrade_settings_table() {
	columns := app.db.execute('PRAGMA table_info(settings)') or { return }
	mut has_theme := false
	mut has_custom_css := false
	for row in columns {
		if row.vals.len < 2 {
			continue
		}
		match row.vals[1] {
			'theme' { has_theme = true }
			'custom_css' { has_custom_css = true }
			else {}
		}
	}

	if !has_theme {
		app.db.execute("ALTER TABLE settings ADD COLUMN theme TEXT NOT NULL DEFAULT 'default'") or {
			eprintln("Couldn't add the theme column: ${err}")
		}
	}

	if has_custom_css {
		app.db.execute('ALTER TABLE settings DROP COLUMN custom_css') or {
			eprintln("Couldn't drop the retired custom_css column: ${err}")
		}
	}
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
		update Settings set blog_title = settings.blog_title, blog_description = settings.blog_description, accent_foreground = settings.accent_foreground, theme = settings.theme, posts_per_page = settings.posts_per_page where id == 1
	}!
}
