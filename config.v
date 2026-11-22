module main

import os
import crypto.rand
import json2
import strings
import crypto

// Pretty sure there's predefined variables for this somewhere? Yes. Change later.
const captial_letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const lowercase_letters = 'abcdefghijklmnopqrstuvwxyz'
const numbers = '0123456789'
const symbols = '!@#$%^&*()_+=<>{}[]-?'
// default_port is what a new install listens on; setup writes the port the
// author picks into config.json and the server reads it back from there.
const default_port = 8082

struct Config {
pub mut:
	client_salt    string // random salt mixed into the session token
	client_secret  string // random key for the session token and the identity digests
	admin_username string // keyed digest, never the name as typed
	admin_email    string // keyed digest of the lowercased address
	admin_password string // Argon2id hash, never the password as typed
	port           int
}

// string_generate returns n random characters from the salt/secret alphabet.
// The bytes come from the OS CSPRNG. Because the alphabet does not divide 256
// evenly, the few byte values that would make some characters more likely than
// others are thrown away instead of being folded in with a modulo.
fn string_generate(n int) string {
	table := captial_letters + lowercase_letters + numbers + symbols
	limit := 256 - (256 % table.len)
	mut str := strings.Builder{}
	for str.len < n {
		bytes := crypto.rand.bytes(n * 2 + 8) or {
			panic('could not read random bytes: ${err}')
		}
		for byte in bytes {
			if int(byte) >= limit {
				continue
			}
			str.write_u8(table[int(byte) % table.len])
			if str.len == n {
				break
			}
		}
	}
	return str.str()
}

// upgrade_legacy_credentials rewrites a config.json from a release that stored the
// username, email and password exactly as typed. It runs on load and saves once;
// every later load finds hashes and does nothing.
fn upgrade_legacy_credentials(mut conf Config) {
	if conf.client_secret.len == 0 || conf.admin_username.len == 0 {
		return
	}
	mut changed := false
	if !conf.admin_username.starts_with(identity_prefix) {
		conf.admin_username = hash_identity(conf.admin_username, conf.client_secret)
		changed = true
	}
	if conf.admin_email.len > 0 && !conf.admin_email.starts_with(identity_prefix) {
		conf.admin_email = hash_email(conf.admin_email, conf.client_secret)
		changed = true
	}
	if conf.admin_password.len > 0 && !conf.admin_password.starts_with(password_prefix) {
		conf.admin_password = hash_password(conf.admin_password) or {
			eprintln('Could not hash the stored password: ${err}')
			return
		}
		changed = true
	}
	if changed {
		conf.save() or {}
	}
}

fn load_config() Config {
	data := os.read_file('config.json') or { '' }
	mut conf := json2.decode[Config](data) or {
		// A missing file is the normal first-run state, so only a present but
		// unreadable config is worth a message.
		if data.len > 0 {
			eprintln('config.json could not be read; run ./vblog to create a new one.')
		}
		return Config{
			client_salt:    ''
			client_secret:  ''
			admin_username: ''
			admin_email:    ''
			admin_password: ''
			port:           default_port
		}
	}
	// config.json written before the port was a setting has no `port` key, and a
	// hand-edited file can hold a number the OS will not bind. Both go back to
	// the default rather than failing at startup.
	if conf.port < 1 || conf.port > 65535 {
		conf.port = default_port
	}
	upgrade_legacy_credentials(mut conf)
	return conf
}

fn (config Config) save() ! {
	data := json2.encode(config)
	os.write_file('config.json', data)!
	// The file holds the password and the cookie secret, so only the account
	// that runs the server should be able to read it.
	$if !windows {
		os.chmod('config.json', 0o600) or {}
	}
}

// generate_config runs the first-start interview and writes config.json. It
// returns whether to seed the sample content, or none when setup failed.
// Answers are validated as they are typed, so a typo never costs a whole run,
// and nothing is written until the account is complete.
fn generate_config() ?bool {
	setup_banner()

	setup_step(1, 'Create the admin account')
	println('  ${setup_dim('This is the only account. It signs in at /admin, once.')}')
	println('')

	mut username := ''
	for _ in 0 .. 3 {
		answer := setup_prompt('Username', 'at least 3 characters: letters, numbers, dot, dash or underscore') or {
			setup_abort()
			return none
		}
		if setup_valid_username(answer) {
			username = answer
			break
		}
		println(setup_red('  Use 3 to 32 characters: letters, numbers, dot, dash or underscore.'))
	}
	if username.len == 0 {
		setup_abort()
		return none
	}

	mut email := ''
	for _ in 0 .. 3 {
		answer := setup_prompt('Email', 'used for the admin account and the RSS feed') or {
			setup_abort()
			return none
		}
		if setup_valid_email(answer) {
			email = answer
			break
		}
		println(setup_red('  That does not look like an email address.'))
	}
	if email.len == 0 {
		setup_abort()
		return none
	}

	password := setup_password() or {
		setup_abort()
		return none
	}

	println('')
	println('  ${setup_dim('One last thing: the port the blog listens on.')}')
	println('  ${setup_dim('Press Enter for ' + default_port.str() + '.')}')
	println('')
	port := setup_prompt_port() or {
		setup_abort()
		return none
	}

	println('')
	println('  ${setup_dim('Generating a salt, a session secret and the password hash...')}')
	secret := string_generate(64)
	hashed_password := hash_password(password) or {
		eprintln(setup_red('Could not hash the password: ${err}'))
		return none
	}

	conf := &Config{
		client_salt:    string_generate(64)
		client_secret:  secret
		admin_username: hash_identity(username, secret)
		admin_email:    hash_email(email, secret)
		admin_password: hashed_password
		port:           port
	}
	conf.save() or {
		eprintln(setup_red('Could not write config.json: ${err}'))
		return none
	}

	setup_summary(username, port)
	return confirm_sample_import()
}

// confirm_sample_import asks the one question setup cannot guess: whether the
// blog should start with the demo content rather than blank. The folder check
// keeps the prompt out of installs that shipped without sample-data/.
fn confirm_sample_import() bool {
	if !os.exists(os.join_path(sample_dir, 'sample.json')) {
		println(setup_dim('  No sample-data/ folder found, so the blog starts empty.'))
		return false
	}
	println(setup_dim('─'.repeat(setup_rule_width)))
	setup_step(2, 'Sample content')
	println('  vblog can add four posts, two pages, their tags and five')
	println('  public-domain pictures, so there is something to read and')
	println('  click through before you write anything.')
	println('  ${setup_dim('Everything it adds is ordinary content you can edit or delete.')}')
	println('')
	for _ in 0 .. 3 {
		answer := os.input('  Import the sample content? [y/N]: ').trim_space().to_lower()
		match answer {
			'', 'n', 'no' {
				println('  Starting with an empty blog.')
				return false
			}
			'y', 'yes' {
				return true
			}
			setup_eof {
				return false
			}
			else {
				println(setup_red('  Please answer y or n.'))
			}
		}
	}
	return false
}
