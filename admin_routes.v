module main

import veb
import time

pub fn (mut app App) admin(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	filter := ctx.query['status'] or { 'all' }
	ctx.admin_filter = if filter in ['published', 'draft', 'scheduled'] { filter } else { 'all' }
	if ctx.is_admin {
		ctx.posts_count = app.get_posts_count()
		ctx.page_count = ctx.pages.len
		ctx.draft_count = app.get_draft_count()
		ctx.scheduled_count = app.get_scheduled_count()
		ctx.recent_posts = app.get_admin_posts(ctx.admin_filter, 50)
		ctx.scheduled_watch = app.get_scheduled_posts(5)
		ctx.server_now = time.now().unix()
		ctx.page_title = 'Dashboard — ${ctx.settings.blog_title}'
	}
	invalid := ctx.invalid_userpass
	return $veb.html()
}

// filter_class marks the active dashboard status filter.
pub fn (ctx &Context) filter_class(name string) string {
	return if ctx.admin_filter == name { 'dash-filter is-active' } else { 'dash-filter' }
}

pub fn (mut app App) r_home(mut ctx Context) veb.Result {
	return ctx.redirect('/')
}

pub fn (mut app App) logout(mut ctx Context) veb.Result {
	if app.auth(ctx) && same_site_request(ctx) {
		app.set_login_token(mut ctx, '')
	}
	return app.r_home(mut ctx)
}

pub fn (mut app App) settings(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	ctx.themes = available_themes()
	ctx.timezones = available_timezones()
	// A zone written outside the list still needs an option to sit on.
	if ctx.settings.timezone !in ctx.timezones {
		ctx.timezones.insert(0, ctx.settings.timezone)
	}
	ctx.page_title = 'Settings — ${ctx.settings.blog_title}'
	return $veb.html()
}

@['/auth_login']
@[post]
pub fn (mut app App) auth_login(mut ctx Context) veb.Result {
	// A login form posted from another site would sign the admin into the
	// attacker's session, so only accept the form from this site.
	if !same_site_request(ctx) {
		return app.r_home(mut ctx)
	}

	conf := load_config()
	app.config = conf

	form_username := ctx.form['username'] or { '' }
	form_password := ctx.form['password'] or { '' }

	if form_username == '' || form_password == '' {
		ctx.invalid_userpass = true
	} else {
		username_ok := identity_matches(conf.admin_username, hash_identity(form_username,
			conf.client_secret))
		// The password is checked even when the username is wrong, so a failed
		// sign-in costs the same either way and never says which field was wrong.
		password_ok := verify_password(conf.admin_password, form_password)
		if username_ok && password_ok {
			app.set_login_token(mut ctx, session_token(conf))
			ctx.is_admin = true
		} else {
			ctx.invalid_userpass = true
		}
	}

	return ctx.redirect('/admin')
}
