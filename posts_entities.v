module main

struct Post {
pub mut:
	id int @[primary; sql: serial]
	title string
	body string
	deleted int
	date i64
}

