module main

import veb
import crypto.md5

pub fn (mut app App) admin(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if ctx.is_admin {
		return app.r_home(mut ctx)
	}
	invalid := ctx.invalid_userpass
	return $veb.html()
}

pub fn (mut app App) r_home(mut ctx Context) veb.Result {
	return ctx.redirect('/')
}

pub fn (mut app App) logout(mut ctx Context) veb.Result {
	if app.auth(ctx) {
		app.set_login_token(mut ctx, '')
	}
	return app.r_home(mut ctx)
}

pub fn (mut app App) settings(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	return $veb.html()
}

@[post]
@['/auth_login']
pub fn (mut app App) auth_login(mut ctx Context) veb.Result {

	//println('entering login authentication')

	app.config = load_config()

	form_username := ctx.form['username'] or { '' }
	form_password := ctx.form['password'] or { '' }

	// Validate form data
	if form_username == '' || form_password == '' {
		ctx.invalid_userpass = true
		//println('invalid form data valid')
	} else {

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
				app.set_login_token(mut ctx, auth_token)

				ctx.is_admin = true
				//println('login successful')

			} else {
				//println('password is invalid')
				ctx.invalid_userpass = true
			}

		} else {
			ctx.invalid_userpass = true
			//println('invalid username')
		}

	}

	return ctx.redirect('/')
}
