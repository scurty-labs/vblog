module main

import strconv
import time
import veb

// /backups is the admin's safety net: it lists the folders in backups/,
// takes a fresh copy on demand, restores one and schedules automatic runs.
@['/backups']
pub fn (mut app App) backups(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}

	ctx.backups = list_backups()
	ctx.backup_schedule = load_backup_schedule()
	mut intervals := backup_intervals.clone()
	if ctx.backup_schedule.interval_hours !in intervals {
		intervals << ctx.backup_schedule.interval_hours
		intervals.sort()
	}
	ctx.backup_intervals = intervals
	ctx.backup_count = ctx.backups.len
	ctx.backup_bytes = 0
	for entry in ctx.backups {
		ctx.backup_bytes += entry.size
	}
	ctx.backup_last = if ctx.backups.len > 0 { ctx.backups[0].created_at } else { 0 }
	ctx.backup_next = backup_next_run(ctx.backup_schedule)

	ctx.backup_created = ctx.query['created'] or { '' }
	ctx.backup_restored = ctx.query['restored'] or { '' }
	ctx.backup_saved = ctx.query['schedule'] or { '' }
	ctx.backup_error = ctx.query['error'] or { '' }
	ctx.backup_page = true
	ctx.page_title = 'Backups — ${ctx.settings.blog_title}'
	ctx.page_description = '${ctx.backup_count} backups of the database, settings and media.'
	return $veb.html()
}

@['/backups/create'; post]
pub fn (mut app App) create_backup_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}
	schedule := load_backup_schedule()
	name := create_backup_snapshot(mut app.db, schedule.keep) or {
		eprintln("Couldn't take a backup: ${err}")
		return ctx.redirect('/backups?error=create')
	}
	return ctx.redirect('/backups?created=${name}')
}

@['/backups/schedule'; post]
pub fn (mut app App) save_backup_schedule_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	mut schedule := load_backup_schedule()
	schedule.enabled = flag_from_form(ctx.form, 'backup_enabled') != 0
	interval := strconv.atoi((ctx.form['backup_interval_hours'] or { schedule.interval_hours.str() }).trim_space()) or {
		schedule.interval_hours
	}
	schedule.interval_hours = clamp_backup_interval(interval)
	keep := strconv.atoi((ctx.form['backup_keep'] or { schedule.keep.str() }).trim_space()) or {
		schedule.keep
	}
	schedule.keep = clamp_backup_keep(keep)

	save_backup_schedule(schedule) or {
		eprintln("Couldn't save the backup schedule: ${err}")
		return ctx.redirect('/backups?error=schedule')
	}
	return ctx.redirect('/backups?schedule=1')
}

@['/backups/restore'; post]
pub fn (mut app App) restore_backup_handle(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !app.is_admin_request(ctx) {
		return app.r_home(mut ctx)
	}

	name := (ctx.form['backup'] or { '' }).trim_space()
	app.restore_backup(name) or {
		eprintln("Couldn't restore ${name}: ${err}")
		return ctx.redirect('/backups?error=restore')
	}

	// The backup carries its own config.json, so a session created against the
	// current one may no longer be valid. Send those to the login page instead
	// of a page that would look broken.
	if !app.auth(ctx) {
		return ctx.redirect('/admin')
	}
	return ctx.redirect('/backups?restored=${name}')
}

pub fn (ctx &Context) backup_bytes_label() string {
	return human_size(ctx.backup_bytes)
}

pub fn (ctx &Context) backup_latest_label() string {
	if ctx.backup_last <= 0 {
		return 'None yet'
	}
	return backup_time_label(ctx.backup_last)
}

pub fn (ctx &Context) backup_schedule_label() string {
	return if ctx.backup_schedule.enabled { 'Enabled' } else { 'Off' }
}

pub fn (ctx &Context) backup_next_label() string {
	if !ctx.backup_schedule.enabled {
		return 'Turn on to run automatically'
	}
	if ctx.backup_next <= time.now().unix() {
		return 'Next run due now'
	}
	return 'Next run ${backup_time_label(ctx.backup_next)}'
}

pub fn (ctx &Context) backup_enabled_attr() string {
	return if ctx.backup_schedule.enabled { 'checked' } else { '' }
}

pub fn (ctx &Context) backup_interval_selected(hours int) string {
	return if ctx.backup_schedule.interval_hours == hours { 'selected' } else { '' }
}

pub fn (ctx &Context) backup_interval_label(hours int) string {
	return match hours {
		1 { 'Every hour' }
		6 { 'Every 6 hours' }
		12 { 'Twice a day' }
		24 { 'Once a day' }
		48 { 'Every 2 days' }
		72 { 'Every 3 days' }
		168 { 'Once a week' }
		else { 'Every ${hours} hours' }
	}
}

// backup_show_message is true when the page arrived with something to report,
// so the template can keep the notices together.
pub fn (ctx &Context) backup_show_message() bool {
	return ctx.backup_created.len > 0 || ctx.backup_restored.len > 0 || ctx.backup_saved.len > 0
		|| ctx.backup_error.len > 0
}
