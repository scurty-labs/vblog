module main

import time
import crypto.md5

pub fn (mut app App) set_login_token(token string) {
	app.set_cookie_with_expire_date('token',token,time.now().add_days(7))
}

// Config rework is in progress...
pub fn (mut app App) auth() bool {

	app.config = load_config()

	// Server Admin Data
	salt := app.config.client_salt
	secret := app.config.client_secret
	username := app.config.admin_username
	password := app.config.admin_password
	email := app.config.admin_email

	auth_token_v := md5.sum('$salt$password$username$email$secret'.bytes()).hex().str()
	auth_token_is := app.get_cookie('token') or { '' }

	//println(auth_token_v + ' - ' + auth_token_is)

	if auth_token_v == auth_token_is  { // must be true
		app.is_admin = true
		return true
	}
	return false
}
