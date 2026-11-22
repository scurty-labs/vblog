module main

import time
import net.http

pub fn (app &App) set_login_token(mut ctx Context, token string) {
	// HttpOnly keeps the token out of reach of any script on the page, and
	// SameSite=Lax keeps the browser from attaching it to cross-site POSTs.
	ctx.set_cookie(http.Cookie{
		name:      'token'
		value:     token
		path:      '/'
		expires:   time.now().add_days(7)
		http_only: true
		same_site: .same_site_lax_mode
	})
}

// auth is true when the request carries the session cookie this config produces.
pub fn (mut app App) auth(ctx &Context) bool {
	app.config = load_config()
	return token_matches(session_token(app.config), ctx.get_cookie('token') or { '' })
}
