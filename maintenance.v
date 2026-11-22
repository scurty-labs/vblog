module main

import os
import db.sqlite

// Maintenance flags run instead of the web server and instead of setup, so they
// work whether or not config.json is in place. Every one of them asks before it
// touches anything: the reset flags throw work away that cannot be recovered,
// and --reset-pass asks for the current password first.

// run_command_line_options handles the maintenance flags and returns true when
// the process is finished. An empty command line returns false, and the server
// starts as usual.
fn run_command_line_options() bool {
	args := os.args[1..]
	if args.len == 0 {
		return false
	}

	mut truncate_db := false
	mut truncate_media := false
	mut reset_defaults := false
	mut reset_pass := false
	for arg in args {
		match arg {
			'--truncate-db' {
				truncate_db = true
			}
			'--truncate-media' {
				truncate_media = true
			}
			'--reset-defaults' {
				reset_defaults = true
			}
			'--reset-pass' {
				reset_pass = true
			}
			'--version', '-V' {
				println('vblog ${app_version()}')
				return true
			}
			'--help', '-h' {
				print_usage()
				return true
			}
			else {
				eprintln('Unknown option: ${arg}')
				print_usage()
				exit(1)
			}
		}
	}

	if truncate_db {
		truncate_database()
	}
	if truncate_media {
		truncate_media_library()
	}
	if reset_defaults {
		reset_settings_defaults()
	}
	if reset_pass {
		reset_admin_password()
	}
	return true
}

// app_version reads the version out of v.mod, embedded at build time, so
// --version and the setup banner cannot drift from the module metadata.
fn app_version() string {
	manifest := $embed_file('v.mod').to_string()
	for line in manifest.split_into_lines() {
		text := line.trim_space()
		if !text.starts_with('version:') {
			continue
		}
		value := text.all_after(':').trim_space()
		if value.len >= 2 && value.starts_with("'") && value.ends_with("'") {
			return value[1..value.len - 1]
		}
		return value
	}
	return 'unknown'
}

fn print_usage() {
	println('Usage: ./vblog [options]')
	println('')
	println('Options:')
	println('  --truncate-db      Delete every post and page (and with them every tag).')
	println('                     Settings are kept.')
	println('  --truncate-media   Delete every file in the media folder.')
	println('  --reset-defaults   Set the blog settings back to their defaults.')
	println('  --reset-pass       Change the admin password (asks for the account details first).')
	println('  --version, -V      Print the version and exit.')
	println('  --help, -h         Show this message.')
	println('')
	println('Each option asks before it changes anything.')
}

// confirm asks the question every maintenance option needs answered first.
// Anything but an explicit yes — including the empty string an exhausted stdin
// returns — means the blog is left alone.
fn confirm(question string) bool {
	answer := os.input('${question} [y/N]: ').trim_space().to_lower()
	return answer in ['y', 'yes']
}

// truncate_database empties the blog: posts, pages and, since tags live on the
// post row, the tags as well. Settings are deliberately kept, so a blog can be
// cleared of content without losing its title, theme and layout choices.
fn truncate_database() {
	if !os.exists('primary.sqlite') {
		println('No database found; nothing to truncate.')
		return
	}
	mut app := &App{}
	app.db = sqlite.connect('primary.sqlite') or {
		eprintln('Database Error: ${err}')
		exit(1)
	}

	// The schema helper makes this work on a database created by an older
	// release, where the Post table or a column may still be missing.
	app.ensure_post_schema()

	posts := sql app.db {
		select count from Post where is_page == 0
	} or { 0 }
	pages := sql app.db {
		select count from Post where is_page == 1
	} or { 0 }
	if posts == 0 && pages == 0 {
		println('There are no posts or pages to delete.')
		return
	}

	println('This deletes ${posts} posts and ${pages} pages, and every tag with them.')
	println('The settings are kept. There is no undo.')
	if !confirm('Delete all posts and pages?') {
		println('Cancelled; nothing was deleted.')
		return
	}

	app.db.execute('DELETE FROM Post') or {
		eprintln("Couldn't clear the posts: ${err}")
		exit(1)
	}
	println('Deleted ${posts} posts and ${pages} pages.')
}

// reset_settings_defaults puts the single settings row back to the values a
// fresh install starts with, without touching any content.
fn reset_settings_defaults() {
	if !os.exists('primary.sqlite') {
		println('No database found; nothing to reset.')
		return
	}
	mut app := &App{}
	app.db = sqlite.connect('primary.sqlite') or {
		eprintln('Database Error: ${err}')
		exit(1)
	}
	app.ensure_settings_schema()

	current := app.load_settings()
	println('This resets the blog title, description, logo, footer, theme, accent')
	println('colour and display switches to their defaults.')
	println('Current title: "${current.blog_title}", theme: "${current.theme}".')
	println('The posts, pages and media are kept. There is no undo.')
	if !confirm('Reset the settings to their defaults?') {
		println('Cancelled; the settings were left alone.')
		return
	}

	// Re-seeding the one row is the same path setup uses on a fresh database.
	app.db.execute('DELETE FROM settings') or {
		eprintln("Couldn't clear the settings: ${err}")
		exit(1)
	}
	seed := default_settings()
	sql app.db {
		insert seed into Settings
	} or {
		eprintln("Couldn't restore the default settings: ${err}")
		exit(1)
	}
	println('Settings reset to their defaults.')
}

// reset_admin_password changes the admin password once the author proves they
// know the current one. It is the recovery path for a forgotten password on a
// machine that can already run the binary, so the username and the old password
// are both checked before a new one is asked for.
fn reset_admin_password() {
	if !os.exists('config.json') {
		println('No config.json found; run ./vblog to create an account first.')
		exit(1)
	}
	conf := load_config()
	if conf.admin_username.len == 0 || conf.admin_password.len == 0 {
		println('config.json holds no admin account; run ./vblog to create one.')
		exit(1)
	}

	println('')
	println('Reset the admin password.')
	println('The username, email and current password are checked first.')
	println('')

	username := os.input('  Username: ').trim_space()
	email := os.input('  Email: ').trim_space()
	password := read_secret('  Current password: ').trim_space()
	// One message for all three, so a wrong guess never says which of them was
	// right.
	username_ok := identity_matches(conf.admin_username, hash_identity(username, conf.client_secret))
	email_ok := identity_matches(conf.admin_email, hash_email(email, conf.client_secret))
	password_ok := verify_password(conf.admin_password, password)
	if !username_ok || !email_ok || !password_ok {
		println('')
		println('That username, email and password do not match the account in config.json.')
		println('Nothing was changed.')
		exit(1)
	}

	println('')
	new_password := setup_password() or {
		println('No new password entered; config.json was left alone.')
		exit(1)
	}

	stored := hash_password(new_password) or {
		eprintln('Could not hash the new password: ${err}')
		exit(1)
	}
	mut updated := conf
	updated.admin_password = stored
	updated.save() or {
		eprintln('Could not write config.json: ${err}')
		exit(1)
	}
	println('')
	println('Password updated in config.json. Every signed-in browser is signed out.')
	println('Sign in at /admin with the new password.')
}

// truncate_media_library removes the files in media/ and then lets the normal
// folder sync drop the records that pointed at them, so the media page is not
// left listing files that no longer exist.
fn truncate_media_library() {
	files := os.ls(media_dir) or {
		println('No media folder found; nothing to truncate.')
		return
	}

	mut targets := []string{}
	for name in files {
		if name.starts_with('.') {
			continue
		}
		path := os.join_path(media_dir, name)
		if os.is_dir(path) {
			continue
		}
		targets << name
	}
	if targets.len == 0 {
		println('The media folder is already empty.')
		return
	}

	println('This deletes ${targets.len} files from ${media_dir}/.')
	println('The posts that link to them are kept. There is no undo.')
	if !confirm('Delete every media file?') {
		println('Cancelled; nothing was deleted.')
		return
	}

	mut removed := 0
	for name in targets {
		os.rm(os.join_path(media_dir, name)) or {
			eprintln("Couldn't remove ${name}: ${err}")
			continue
		}
		removed++
	}

	if os.exists('primary.sqlite') {
		mut app := &App{}
		app.db = sqlite.connect('primary.sqlite') or {
			eprintln('Database Error: ${err}')
			exit(1)
		}
		app.ensure_media_schema()
		app.sync_media_library()
	}
	println('Removed ${removed} media files.')
}
