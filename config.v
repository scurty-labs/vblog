module main

import os
import rand
import json

const (
	captial_letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	lowercase_letters='abcdefghijklmnopqrstuvwxyz'
	numbers = '0123456789'
	symbols = '!@#$%^&*()_+=<>{}[]-?'
)

struct Config {
pub mut:
	client_salt string
	client_secret string
	admin_username string
	admin_email string
	admin_password string
}

// TODO: Generate random integers in a more secure way
fn string_generate(n int) string {
    table := captial_letters + lowercase_letters + numbers + symbols
	characters := table.split('')
    mut str := []string{}
	mut seed := rand.intn(100000) or {0}
    rand.seed([u32(seed), 0])
	for _ in 0..n {
		seed = rand.intn(100000) or {0}
    	rand.seed([u32(seed), 0])
		str << characters[rand.intn(characters.len) or {0} ]
	}
	return str.join('')
}

fn load_config() Config {
	data := os.read_file('config.json') or { '' }
	conf := json.decode(Config, data) or {
		eprintln('Error: Can\'t load config data!')
		return Config{client_salt:'', client_secret:'', admin_username:'', admin_email:'', admin_password:''}
	}
	return conf
}

fn (config Config) save() {
	data := json.encode(config)
	//println(data) // Debug
	os.write_file('config.json', data) or {
		eprintln('Error: Saving configuration failed.')
	}
}

fn generate_config() {

	username := os.input('Blog Username: ')
	email := os.input('Email: ') // TODO: Check for valid email format
	
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
			admin_password: pass1
		}
		conf.save()
		println('Ready.')
	}else{
		println('Passwords do not match...')
	}
}
