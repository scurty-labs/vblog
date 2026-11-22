module main

import os
import term
import term.termios

// stdout_is_terminal keeps setup's colours and frames for a real terminal and
// plain text for a piped or redirected run (logs, provisioning scripts, tests).
// vlib's term module owns the isatty/TERM=dumb check, so setup does not.
fn stdout_is_terminal() bool {
	return term.can_show_color_on_stdout()
}

// read_secret reads one line with terminal echo turned off through vlib's
// termios wrapper, so a typed password never lands on screen or in scrollback.
// When stdin is not a terminal (piped answers), it reads the line normally.
fn read_secret(prompt string) string {
	print(prompt)
	os.flush()
	$if linux || macos {
		mut original := termios.Termios{}
		if termios.tcgetattr(0, mut original) == 0 {
			mut hidden := original
			hidden.disable_echo()
			termios.set_state(0, hidden)
			line := os.get_line()
			termios.set_state(0, original)
			println('')
			return line
		}
	}
	return os.get_line()
}
