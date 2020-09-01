module main

import vweb
import crypto.md5

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
	
	// Client Admin Data
	salt := app.config.client_salt
	secret := app.config.client_secret
	usr := app.config.admin_username
	pswd := app.config.admin_password
	
	admin_hash := md5.sum('$salt$secret$usr$pswd'.bytes()).hex()
	entered_hash := md5.sum('$salt$secret$username$password'.bytes()).hex()
	
	if username != '' && password != '' {
	
		if entered_hash == admin_hash {
			app.invalid_userpass = false
			app.vweb.set_cookie(name:'auth_token', value:admin_hash)
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

	// Client Admin Data
	salt := app.config.client_salt
	secret := app.config.client_secret
	usr := app.config.admin_username
	pswd := app.config.admin_password

	token := md5.sum('$salt$secret$usr$pswd'.bytes()).hex()
	session := app.vweb.get_cookie('auth_token') or { '' }
	if session != '' {
		if session == token { return true }
	}
	return false
}
