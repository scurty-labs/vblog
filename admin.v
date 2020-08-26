module main

import vweb
import crypto.md5

// -- TODO: CHANGE THESE VALUES AS NEEDED -- //
const (
	salt = '9348v&**veds02591684ferb8g45))'
	admin_username = 'admin'
	admin_password = 'asdf'
)

pub fn (mut app App) admin() vweb.Result {
	if app.auth() { return app.r_home() }
	invalid := app.invalid_userpass
	return $vweb.html()
}

pub fn (mut app App) r_home() vweb.Result {
	return app.vweb.redirect('/')
}

pub fn (mut app App) logout() vweb.Result {
	if app.auth() { app.vweb.set_cookie(name:'auth_token', value:'') }
	return app.r_home()
}

pub fn (mut app App) settings() vweb.Result {
	if !app.auth() { return app.r_home() }
	app.load_settings()
	return $vweb.html()
}

[post]
['/auth_login']
pub fn (mut app App) auth_login() vweb.Result {
	if app.auth() { return app.r_home() }
	username := app.vweb.form['username']
	password := app.vweb.form['password']
	if username != '' && password != '' {
		if password == 'asdf' {
			app.invalid_userpass = false
			app.vweb.set_cookie(name:'auth_token', value:md5.sum('$salt$admin_username$admin_password'.bytes()).hex())
		}else{
			app.invalid_userpass = true
			return app.vweb.redirect('/admin')
		}
	}else{
		app.invalid_userpass = true
		return app.vweb.redirect('/admin')
		
	}
	return app.r_home()
}

pub fn (mut app App) auth() bool {
	token := md5.sum('$salt$admin_username$admin_password'.bytes()).hex()
	session := app.vweb.get_cookie('auth_token') or { '' }
	if session != '' {
		if session == token { return true }
	}
	return false
}
