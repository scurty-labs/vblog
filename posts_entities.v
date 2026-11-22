module main

struct Post {
pub mut:
	id         int    @[primary; sql: serial]
	title      string
	body       string
	tags       string
	status     string
	publish_at i64
	deleted    int
	date       i64
	is_page    int
}
