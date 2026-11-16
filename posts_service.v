module main

import veb
import time

// ensure_post_schema upgrades databases created before tags, drafts and
// scheduled publishing existed. A brand new database has no Post table yet;
// the ORM creates it from the struct on first insert, so there is nothing to do.
fn (mut app App) ensure_post_schema() {
	columns := app.db.execute('PRAGMA table_info(Post)') or { return }
	if columns.len == 0 {
		return
	}

	mut has := map[string]bool{}
	for row in columns {
		if row.vals.len > 1 {
			has[row.vals[1]] = true
		}
	}

	if !has['is_page'] {
		app.db.execute('ALTER TABLE Post ADD COLUMN is_page INTEGER NOT NULL DEFAULT 0') or {
			eprintln("Couldn't add the is_page column: ${err}")
		}
	}
	if !has['tags'] {
		app.db.execute("ALTER TABLE Post ADD COLUMN tags TEXT NOT NULL DEFAULT ''") or {
			eprintln("Couldn't add the tags column: ${err}")
		}
	}
	if !has['status'] {
		app.db.execute("ALTER TABLE Post ADD COLUMN status TEXT NOT NULL DEFAULT 'published'") or {
			eprintln("Couldn't add the status column: ${err}")
		}
	}
	if !has['publish_at'] {
		app.db.execute('ALTER TABLE Post ADD COLUMN publish_at INTEGER NOT NULL DEFAULT 0') or {
			eprintln("Couldn't add the publish_at column: ${err}")
		}
	}
}

const demo_post_title = 'The V/veb style guide'

// ensure_demo_post seeds one long style-guide post the first time this build
// runs, so the blog has a page that shows every Markdown style. The
// user_version guard means deleting the post does not bring it back.
fn (mut app App) ensure_demo_post() {
	versions := app.db.execute('PRAGMA user_version') or { return }
	if versions.len > 0 && versions[0].vals.len > 0 && versions[0].vals[0].int() >= 2 {
		return
	}
	demo_title := demo_post_title
	count := sql app.db {
		select count from Post where title == demo_title
	} or { 0 }
	if count == 0 {
		post_id := app.insert_post(Post{
			title:  demo_post_title
			body:   $embed_file('demo_post.md').to_string()
			tags:   'style, markdown, demo'
			status: 'published'
			date:   time.now().unix()
		})
		if post_id == 0 {
			return
		}
	}
	app.db.execute('PRAGMA user_version = 2') or {}
}

// get_all_posts returns every live row, including pages and drafts. Admin and
// tag bookkeeping use it; public feeds use get_published_posts instead.
pub fn (mut app App) get_all_posts() []Post {
	posts := sql app.db {
		select from Post where deleted == 0 order by date desc
	} or {
		[]Post{}
	}
	return posts
}

// get_posts_count is the number of posts a visitor can read right now.
pub fn (mut app App) get_posts_count() int {
	now := time.now().unix()
	num := sql app.db {
		select count from Post where deleted == 0 && is_page == 0 && status == 'published' && publish_at <= now
	} or { 0 }
	return num
}

pub fn (mut app App) get_draft_count() int {
	num := sql app.db {
		select count from Post where deleted == 0 && is_page == 0 && status == 'draft'
	} or { 0 }
	return num
}

pub fn (mut app App) get_scheduled_count() int {
	now := time.now().unix()
	num := sql app.db {
		select count from Post where deleted == 0 && is_page == 0 && status == 'published' && publish_at > now
	} or { 0 }
	return num
}

// format_date renders the publish date in a compact, human form.
pub fn (post Post) format_date() string {
	t := time.unix(post.published_time())
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	month := if t.month >= 1 && t.month <= 12 { months[t.month - 1] } else { '' }
	return '${month} ${t.day}, ${t.year}'
}

// published_time is the date the post appeared (or will appear) publicly.
pub fn (post Post) published_time() i64 {
	if post.publish_at > 0 {
		return post.publish_at
	}
	return post.date
}

pub fn (post Post) reading_time() int {
	mut words := 0
	for line in post.body.split('\n') {
		for word in line.split(' ') {
			if word.trim_space().len > 0 {
				words++
			}
		}
	}
	mut minutes := (words + 199) / 200
	if minutes < 1 {
		minutes = 1
	}
	return minutes
}

pub fn (post Post) is_scheduled() bool {
	return post.status == 'published' && post.publish_at > time.now().unix()
}

pub fn (post Post) is_draft() bool {
	return post.status == 'draft'
}

pub fn (post Post) status_label() string {
	if post.is_page == 1 {
		return 'Page'
	}
	if post.status == 'draft' {
		return 'Draft'
	}
	if post.publish_at > time.now().unix() {
		return 'Scheduled'
	}
	return 'Published'
}

pub fn (post Post) status_class() string {
	if post.status == 'draft' {
		return 'draft'
	}
	if post.publish_at > time.now().unix() {
		return 'scheduled'
	}
	return 'published'
}

// publish_at_input renders the stored schedule for a datetime-local input.
pub fn (post Post) publish_at_input() string {
	if post.publish_at <= 0 {
		return ''
	}
	t := time.unix(post.publish_at)
	return '${t.year}-${two_digits(t.month)}-${two_digits(t.day)}T${two_digits(t.hour)}:${two_digits(t.minute)}'
}

fn two_digits(n int) string {
	if n < 10 {
		return '0${n}'
	}
	return '${n}'
}

// parse_publish_at converts a datetime-local value into a Unix timestamp.
// An empty or malformed value means "no schedule".
pub fn parse_publish_at(value string) i64 {
	clean := value.trim_space().replace('T', ' ')
	if clean.len < 16 {
		return 0
	}
	t := time.parse(clean + ':00') or { return 0 }
	return t.unix()
}

pub fn (mut app App) get_post_by_id(post_id int) ?Post {
	posts := sql app.db {
		select from Post where id == post_id limit 1
	} or { []Post{} }
	if posts.len == 0 {
		return none
	}
	return posts[0]
}

pub fn (mut app App) get_pages_count(num_per int) int {
	if num_per <= 0 {
		return 0
	}
	count := app.get_posts_count()
	return (count + num_per - 1) / num_per
}

pub fn (mut app App) get_posts_page(page_num int, num_per int) []Post {
	if num_per <= 0 {
		return []Post{}
	}
	now := time.now().unix()
	offs := (page_num - 1) * num_per
	posts := sql app.db {
		select from Post where deleted == 0 && is_page == 0 && status == 'published' && publish_at <= now order by date desc limit num_per offset offs
	} or { []Post{} }
	return posts
}

// get_published_posts loads the public feed for tags, related posts and feeds.
pub fn (mut app App) get_published_posts() []Post {
	now := time.now().unix()
	posts := sql app.db {
		select from Post where deleted == 0 && is_page == 0 && status == 'published' && publish_at <= now order by date desc
	} or { []Post{} }
	return posts
}

// get_recent_published_posts is the bounded query used by feeds.
pub fn (mut app App) get_recent_published_posts(limit int) []Post {
	if limit <= 0 {
		return []Post{}
	}
	now := time.now().unix()
	posts := sql app.db {
		select from Post where deleted == 0 && is_page == 0 && status == 'published' && publish_at <= now order by date desc limit limit
	} or { []Post{} }
	return posts
}

// get_admin_posts returns posts for the dashboard, optionally filtered by
// published, draft or scheduled state.
pub fn (mut app App) get_admin_posts(filter string, limit int) []Post {
	all := sql app.db {
		select from Post where deleted == 0 && is_page == 0 order by date desc limit 200
	} or { []Post{} }
	now := time.now().unix()
	mut out := []Post{}
	for post in all {
		match filter {
			'draft' {
				if post.status == 'draft' {
					out << post
				}
			}
			'scheduled' {
				if post.status == 'published' && post.publish_at > now {
					out << post
				}
			}
			'published' {
				if post.status == 'published' && post.publish_at <= now {
					out << post
				}
			}
			else {
				out << post
			}
		}
	}
	if limit > 0 && out.len > limit {
		return out[..limit]
	}
	return out
}

// get_pages lists pages for the sidebar and the admin panel.
pub fn (mut app App) get_pages() []Post {
	pages := sql app.db {
		select from Post where deleted == 0 && is_page == 1 order by title
	} or { []Post{} }
	return pages
}

pub fn (mut app App) update_post(post_id int, t string, b string) {
	sql app.db {
		update Post set title = t, body = b where id == post_id
	} or {
		eprintln("Couldn't update existing post!")
	}
}

pub fn (mut app App) update_post_details(post_id int, t string, b string, tags string, status string, publish_at i64, date i64) {
	sql app.db {
		update Post set title = t, body = b, tags = tags, status = status, publish_at = publish_at, date = date where id == post_id
	} or {
		eprintln("Couldn't update existing post!")
	}
}

pub fn (mut app App) insert_new_post(post Post) {
	sql app.db {
		insert post into Post
	} or {
		eprintln("Couldn't insert new post!")
	}
}

// insert_post stores a post and returns its id, used by duplicate.
pub fn (mut app App) insert_post(post Post) int {
	sql app.db {
		insert post into Post
	} or {
		eprintln("Couldn't insert new post!")
		return 0
	}
	return app.last_post_id()
}

fn (mut app App) last_post_id() int {
	rows := app.db.execute('SELECT id FROM Post ORDER BY id DESC LIMIT 1') or { return 0 }
	if rows.len == 0 || rows[0].vals.len == 0 {
		return 0
	}
	return rows[0].vals[0].int()
}

// insert_page stores a page and returns its id so the admin lands on it.
pub fn (mut app App) insert_page(page Post) int {
	sql app.db {
		insert page into Post
	} or {
		eprintln("Couldn't insert new page!")
		return 0
	}
	return app.last_post_id()
}

// promote_to_page flags an existing post as a page, keeping its id and body.
pub fn (mut app App) promote_to_page(post_id int) {
	sql app.db {
		update Post set is_page = 1 where id == post_id
	} or {
		eprintln("Couldn't promote post to a page!")
	}
}

pub fn (mut app App) delete_post(post_id int) {
	sql app.db {
		update Post set deleted = 1 where id == post_id
	} or {
		eprintln("Couldn't set delete flag on existing post!")
	}
}

pub fn (mut app App) publish_post_now(post_id int) {
	now := time.now().unix()
	sql app.db {
		update Post set status = 'published', publish_at = 0, date = now where id == post_id
	} or {
		eprintln("Couldn't publish post!")
	}
}

pub fn (mut app App) unpublish_post(post_id int) {
	sql app.db {
		update Post set status = 'draft', publish_at = 0 where id == post_id
	} or {
		eprintln("Couldn't unpublish post!")
	}
}

// duplicate_post copies a post into a fresh draft and returns the new id.
pub fn (mut app App) duplicate_post(post_id int) int {
	post := app.get_post_by_id(post_id) or { return 0 }
	return app.insert_post(Post{
		title:   '${post.title} (copy)'
		body:    post.body
		tags:    post.tags
		status:  'draft'
		date:    time.now().unix()
		is_page: 0
	})
}

pub fn (mut app App) newpost(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	if !ctx.is_admin {
		return app.r_home(mut ctx)
	}
	ctx.editor = true
	ctx.invalid_newpost = ctx.query['invalid'] or { '' } == '1'
	invalid := ctx.invalid_newpost
	ctx.page_title = 'New post — ${ctx.settings.blog_title}'
	return $veb.html()
}
