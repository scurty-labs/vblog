module main

import vweb
import crypto.md5

pub fn (mut app App) admin() vweb.Result {
	if app.auth() { return app.r_home() }
	invalid := app.invalid_userpass
	return $vweb.html()
}

pub fn (mut app App) r_home() vweb.Result {
	return app.redirect('/')
}

pub fn (mut app App) logout() vweb.Result {
	if app.auth() { app.set_cookie(name:'token', value:'') }
	return app.r_home()
}

pub fn (mut app App) settings() vweb.Result {
	if !app.auth() { return app.r_home() }
	//app.settings = app.load_settings()
	return $vweb.html()
}

@[post]
@['/auth_login']
pub fn (mut app App) auth_login() vweb.Result {

	//println('entering login authentication')

	app.config = load_config()

	form_username := app.form['username']
	form_password := app.form['password']

	// Validate form data
	if form_username == '' || form_password == '' {
		app.invalid_userpass = true
		//println('invalid form data valid')
	}else{

		// Does form data match config?
		salt := app.config.client_salt
		secret := app.config.client_secret
		username := app.config.admin_username
		password := app.config.admin_password
		email := app.config.admin_email

		//println(app.config.admin_username + ' ' + form_username)

		// Check username
		if form_username == username {

			//println('username valid')

			// Validate password with client salt and client secret
			password_hash := md5.sum('$salt$password$secret'.bytes()).hex()
			form_password_hash := md5.sum('$salt$form_password$secret'.bytes()).hex()

			if form_password_hash == password_hash {

				auth_token := md5.sum('$salt$password$username$email$secret'.bytes()).hex()
				app.set_login_token(auth_token)

				app.is_admin = true
				//println('login successful')

			}else{
				//println('password is invalid')
				app.invalid_userpass = true
			}

		}else{
			app.invalid_userpass = true
			//println('invalid username')
		}

	}

	return app.redirect('/')
}
