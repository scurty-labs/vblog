module main

import os
import rand
import time
import crypto.md5
import json

const (
	captial_letters = 'ABCDEFGHIJLMNOPQURSTUVWXYZ'
	lowercase_letters = 'abcdefghijklmnopqurstuwxyz'
	numbers = '0123456789'
	symbols = '!@#$%^&*()_+=|/\:<>{}[]-`,.?'
)

struct Config {
pub mut:
	client_salt string
	client_secret string 
	admin_username string
	admin_email string
	admin_password string
}

// FROM KRYPTY
fn string_generate(n int) string {
    table := captial_letters + lowercase_letters + numbers + symbols
	characters := table.split('')
    mut str := []string{}
    rand.seed([u32(time.now().unix), 0])
	for _ in 0..n {
		str << characters[rand.intn(characters.len)]
	}
	return str.join('')
}

fn load_config() Config {
	data := os.read_file('config.json') or { '' }
	conf := json.decode(Config, data) or {
		return Config{client_salt:'', client_secret:'', admin_username:'', admin_email:'', admin_password:''}
	}
	return conf
}

fn (config Config) save() {
	data := json.encode(config)
	os.write_file(data, 'config.json') or {
		println('error saving config.json')
	}
}

fn generate_config() {

	username := os.input('Blog Username: ')
	email := os.input('Email: ')
	
	pass1 := os.input('Enter Password: ')
	pass2 := os.input('Confirm Password: ')
	
	if pass1 == pass2 {
		println('Generating configuration...')
		
		salt := string_generate(64)
		secret := string_generate(64)
		
		conf := &Config{
			client_salt: salt
			client_secret: secret
			admin_username: username
			admin_email: email
			admin_password: md5.sum('$salt$secret$username$email$pass1$email'.bytes()).hex()
		}
		conf.save()
		println('Finished.')
	}else{
		println('Passwords do not match...')
	}
}
