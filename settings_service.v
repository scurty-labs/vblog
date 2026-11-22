module main

import strconv

// ensure_settings_schema creates the single-row settings table, seeds it, and
// upgrades databases that still use the legacy key/value `setting` table.
fn (mut app App) ensure_settings_schema() {
	app.db.execute("CREATE TABLE IF NOT EXISTS settings (id INTEGER PRIMARY KEY CHECK (id = 1), blog_title TEXT NOT NULL DEFAULT '', blog_description TEXT NOT NULL DEFAULT '', logo_url TEXT NOT NULL DEFAULT '', logo_enabled INTEGER NOT NULL DEFAULT 0, favicon_url TEXT NOT NULL DEFAULT '', footer_text TEXT NOT NULL DEFAULT '${default_footer_text}', accent_foreground TEXT NOT NULL DEFAULT '#00dddd', theme TEXT NOT NULL DEFAULT '${default_theme}', timezone TEXT NOT NULL DEFAULT '${default_timezone}', posts_per_page INTEGER NOT NULL DEFAULT 10, show_description INTEGER NOT NULL DEFAULT 1, show_pages INTEGER NOT NULL DEFAULT 1, show_tags INTEGER NOT NULL DEFAULT 1, show_rss INTEGER NOT NULL DEFAULT 1, show_post_meta INTEGER NOT NULL DEFAULT 1, show_footer INTEGER NOT NULL DEFAULT 1)") or {
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
	app.migrate_default_theme()
}

// migrate_default_theme moves databases still on the old default over to the
// new one once. user_version guards it, so picking 'default' later still sticks.
fn (mut app App) migrate_default_theme() {
	versions := app.db.execute('PRAGMA user_version') or { return }
	if versions.len > 0 && versions[0].vals.len > 0 && versions[0].vals[0].int() >= 1 {
		return
	}
	app.db.execute("UPDATE settings SET theme = '${default_theme}' WHERE theme = 'default'") or {
		return
	}
	app.db.execute('PRAGMA user_version = 1') or {}
}

// upgrade_settings_table adds every column introduced after the first release
// to databases that predate it, and drops the retired custom_css column when
// SQLite allows it. CREATE TABLE IF NOT EXISTS leaves older tables untouched,
// so each addition needs its own guarded ALTER.
fn (mut app App) upgrade_settings_table() {
	columns := app.db.execute('PRAGMA table_info(settings)') or { return }
	mut existing := map[string]bool{}
	for row in columns {
		if row.vals.len < 2 {
			continue
		}
		existing[row.vals[1]] = true
	}

	// Column name -> the type and default used when adding it to an old table.
	additions := {
		'theme':            "TEXT NOT NULL DEFAULT '${default_theme}'"
		'timezone':         "TEXT NOT NULL DEFAULT '${default_timezone}'"
		'footer_text':      "TEXT NOT NULL DEFAULT '${default_footer_text}'"
		'logo_url':         "TEXT NOT NULL DEFAULT ''"
		'logo_enabled':     'INTEGER NOT NULL DEFAULT 0'
		'favicon_url':      "TEXT NOT NULL DEFAULT ''"
		'show_description': 'INTEGER NOT NULL DEFAULT 1'
		'show_pages':       'INTEGER NOT NULL DEFAULT 1'
		'show_tags':        'INTEGER NOT NULL DEFAULT 1'
		'show_rss':         'INTEGER NOT NULL DEFAULT 1'
		'show_post_meta':   'INTEGER NOT NULL DEFAULT 1'
		'show_footer':      'INTEGER NOT NULL DEFAULT 1'
	}

	for name, definition in additions {
		if existing[name] {
			continue
		}
		app.db.execute('ALTER TABLE settings ADD COLUMN ${name} ${definition}') or {
			eprintln("Couldn't add the ${name} column: ${err}")
		}
	}

	if existing['custom_css'] {
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
		update Settings set blog_title = settings.blog_title, blog_description = settings.blog_description, logo_url = settings.logo_url, logo_enabled = settings.logo_enabled, favicon_url = settings.favicon_url, footer_text = settings.footer_text, accent_foreground = settings.accent_foreground, theme = settings.theme, timezone = settings.timezone, posts_per_page = settings.posts_per_page, show_description = settings.show_description, show_pages = settings.show_pages, show_tags = settings.show_tags, show_rss = settings.show_rss, show_post_meta = settings.show_post_meta, show_footer = settings.show_footer where id == 1
	}!
}
