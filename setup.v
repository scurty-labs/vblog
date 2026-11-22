module main

import os

// Setup is the first thing a new install shows, so it is written as two short
// steps with a visible frame, plain-language hints and answers that are checked
// before anything is written to disk. Colours disappear when output is piped,
// and every prompt accepts scripted stdin, so `printf` can still drive it.

const setup_rule_width = 62
const setup_eof = '<EOF>'
const setup_min_password = 8

fn setup_style(code string, text string) string {
	if !stdout_is_terminal() {
		return text
	}
	return '\x1b[${code}m${text}\x1b[0m'
}

fn setup_bold(text string) string {
	return setup_style('1', text)
}

fn setup_dim(text string) string {
	return setup_style('2', text)
}

fn setup_cyan(text string) string {
	return setup_style('36', text)
}

fn setup_green(text string) string {
	return setup_style('32', text)
}

fn setup_yellow(text string) string {
	return setup_style('33', text)
}

fn setup_red(text string) string {
	return setup_style('31', text)
}

fn setup_rule() string {
	return setup_cyan('─'.repeat(setup_rule_width))
}

// setup_banner introduces the program and says why it is asking questions.
fn setup_banner() {
	println('')
	println(setup_rule())
	println('  ${setup_bold('vblog')} ${setup_dim('v${app_version()}')}')
	println('  A fast, self-contained blog written in V.')
	println(setup_rule())
	println('')
	println('No config.json found, so this is the first run.')
	println('Two short steps and the blog is ready to serve.')
	println('')
}

// setup_step labels the current question group.
fn setup_step(number int, title string) {
	println('${setup_cyan('[' + number.str() + '/2]')} ${setup_bold(title)}')
}

// setup_abort is the one closing message for every failed answer sequence.
fn setup_abort() {
	println('')
	println(setup_red('Setup stopped before writing config.json. Run ./vblog again when ready.'))
}

// setup_prompt asks once, showing the hint above the field, and re-asks when the
// answer is empty. Closed input (Ctrl-D, or a script that ran out of lines) ends
// setup instead of looping forever.
fn setup_prompt(label string, hint string) ?string {
	if hint.len > 0 {
		println('  ${setup_dim(hint)}')
	}
	for _ in 0 .. 3 {
		answer := os.input('  ${label}: ').trim_space()
		if answer == setup_eof {
			println('')
			return none
		}
		if answer.len > 0 {
			return answer
		}
		println(setup_red('  ${label} cannot be empty.'))
	}
	return none
}

fn setup_valid_username(value string) bool {
	if value.len < 3 || value.len > 32 {
		return false
	}
	for ch in value {
		allowed := (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || (ch >= `0` && ch <= `9`)
			|| ch == `.` || ch == `_` || ch == `-`
		if !allowed {
			return false
		}
	}
	return true
}

fn setup_valid_email(value string) bool {
	if value.contains(' ') || value.contains('\t') {
		return false
	}
	at := value.index('@') or { return false }
	local := value[..at]
	domain := value[at + 1..]
	if local.len == 0 || domain.len < 3 {
		return false
	}
	return domain.contains('.') && !domain.starts_with('.') && !domain.ends_with('.')
}

// setup_password reads a password twice, hiding it from the terminal, and gives
// the author three tries to match the two entries.
fn setup_password() ?string {
	for _ in 0 .. 3 {
		pass := read_secret('  ${setup_dim('at least ${setup_min_password} characters')}\n  Password: ').trim_space()
		if pass == setup_eof {
			return none
		}
		if pass.len < setup_min_password {
			println(setup_red('  Use at least ${setup_min_password} characters.'))
			continue
		}
		again := read_secret('  Confirm password: ').trim_space()
		if again == setup_eof {
			return none
		}
		if pass == again {
			return pass
		}
		println(setup_red('  The two passwords did not match. Try again.'))
	}
	return none
}

// setup_prompt_port asks for the listening port. Empty answers take the default,
// so pressing Enter is the whole answer for almost everyone.
fn setup_prompt_port() ?int {
	for _ in 0 .. 3 {
		answer := os.input('  Port [${default_port}]: ').trim_space()
		if answer == setup_eof {
			println('')
			return none
		}
		if answer.len == 0 {
			return default_port
		}
		mut digits := true
		for ch in answer {
			if ch < `0` || ch > `9` {
				digits = false
				break
			}
		}
		value := if digits { answer.int() } else { 0 }
		if value >= 1 && value <= 65535 {
			return value
		}
		println(setup_red('  Use a port number between 1 and 65535, or press Enter for ${default_port}.'))
	}
	return none
}

// setup_summary tells the author what was written, where to sign in and what to
// keep private; it prints after config.json exists on disk.
fn setup_summary(username string, port int) {
	println('')
	println(setup_green('  Configuration saved to config.json.'))
	println('')
	println('  ${setup_bold('Admin sign-in')}   http://localhost:${port}/admin')
	println('  ${setup_bold('Username')}        ${username}')
	println('')
	println(setup_yellow('  Keep config.json private: it holds your session key and password hash.'))
	println('')
}
