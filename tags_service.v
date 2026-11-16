module main

import time

// Tag helpers. Tags are stored as a comma-separated slug string on the post, so
// listing a post never needs a join. Lists (sidebar clouds, tag pages and
// related posts) filter in memory; a personal blog has few enough posts that
// this stays far faster than extra round trips.

struct TagCount {
pub:
	tag   string
	count int
}

struct RelatedPost {
	post   Post
	shared int
}

// normalize_tag turns free text into a URL-safe slug: lower case, spaces to
// dashes and only letters, digits, dashes and underscores kept.
fn normalize_tag(raw string) string {
	mut out := []u8{}
	for ch in raw.trim_space().to_lower() {
		if (ch >= `a` && ch <= `z`) || (ch >= `0` && ch <= `9`) || ch == `-` || ch == `_` {
			out << ch
		} else if ch == ` ` || ch == `\t` {
			out << `-`
		}
	}
	mut slug := out.bytestr()
	for slug.contains('--') {
		slug = slug.replace('--', '-')
	}
	return slug.trim('-')
}

// normalize_tags cleans a comma-separated field, removes duplicates and keeps
// the stored format consistent: "v-lang, notes".
fn normalize_tags(input string) string {
	mut seen := map[string]bool{}
	mut tags := []string{}
	for raw in input.split(',') {
		tag := normalize_tag(raw)
		if tag.len > 0 && tag.len <= 40 && !seen[tag] {
			seen[tag] = true
			tags << tag
		}
	}
	return tags.join(', ')
}

// update_post_tags writes one post's tag field. All admin tag bookkeeping
// shares this path so renames, removals and additions stay consistent.
fn (mut app App) update_post_tags(post_id int, tags string) {
	sql app.db {
		update Post set tags = tags where id == post_id
	} or {
		eprintln("Couldn't update post tags!")
	}
}

// rename_tag moves every use of old to new_name, merging when new_name is
// already on the same post.
pub fn (mut app App) rename_tag(old string, new_name string) {
	for post in app.get_all_posts() {
		if !post.has_tag(old) {
			continue
		}
		mut tags := []string{}
		for tag in post.tag_list() {
			if tag == old {
				if new_name !in tags {
					tags << new_name
				}
			} else if tag !in tags {
				tags << tag
			}
		}
		app.update_post_tags(post.id, normalize_tags(tags.join(', ')))
	}
}

// remove_tag strips a tag from every post that carries it.
pub fn (mut app App) remove_tag(tag string) {
	for post in app.get_all_posts() {
		if !post.has_tag(tag) {
			continue
		}
		mut tags := []string{}
		for t in post.tag_list() {
			if t != tag && t !in tags {
				tags << t
			}
		}
		app.update_post_tags(post.id, normalize_tags(tags.join(', ')))
	}
}

// add_tag_to_post attaches a tag to one post; nothing is created otherwise.
pub fn (mut app App) add_tag_to_post(post_id int, tag string) {
	slug := normalize_tag(tag)
	if slug.len == 0 {
		return
	}
	post := app.get_post_by_id(post_id) or { return }
	mut tags := post.tag_list()
	if slug !in tags {
		tags << slug
	}
	app.update_post_tags(post.id, normalize_tags(tags.join(', ')))
}

pub fn (post &Post) tag_list() []string {
	mut out := []string{}
	for raw in post.tags.split(',') {
		tag := raw.trim_space()
		if tag.len > 0 {
			out << tag
		}
	}
	return out
}

fn (post &Post) has_tag(tag string) bool {
	return tag in post.tag_list()
}

pub fn (mut app App) get_tag_counts() []TagCount {
	// Only the tags column is needed, so do not load every post body here.
	now := time.now().unix()
	rows := app.db.execute("SELECT tags FROM Post WHERE deleted = 0 AND is_page = 0 AND status = 'published' AND publish_at <= ${now}") or {
		return []TagCount{}
	}
	mut counts := map[string]int{}
	for row in rows {
		if row.vals.len == 0 {
			continue
		}
		for raw in row.vals[0].split(',') {
			tag := raw.trim_space()
			if tag.len > 0 {
				counts[tag] = counts[tag] + 1
			}
		}
	}
	mut list := []TagCount{}
	for tag, count in counts {
		list << TagCount{
			tag:   tag
			count: count
		}
	}
	list.sort(a.tag < b.tag)
	return list
}

pub fn (mut app App) get_posts_by_tag(tag string) []Post {
	slug := normalize_tag(tag)
	mut out := []Post{}
	if slug.len == 0 {
		return out
	}
	for post in app.get_published_posts() {
		if post.has_tag(slug) {
			out << post
		}
	}
	return out
}

pub fn (mut app App) get_related_posts(post &Post, limit int) []Post {
	mut related := []RelatedPost{}
	for other in app.get_published_posts() {
		if other.id == post.id {
			continue
		}
		mut shared := 0
		for tag in post.tag_list() {
			if other.has_tag(tag) {
				shared++
			}
		}
		if shared > 0 {
			related << RelatedPost{
				post:   other
				shared: shared
			}
		}
	}
	related.sort(a.shared > b.shared)
	mut out := []Post{}
	for item in related {
		if out.len >= limit {
			break
		}
		out << item.post
	}
	return out
}

// plain_text produces a compact description for meta tags and feeds.
pub fn plain_text(body string, max_len int) string {
	mut text := body.replace('\r\n', ' ').replace('\n', ' ')
	for token in ['#', '*', '_', '`', '>', '[', ']', '(', ')', '!', '|'] {
		text = text.replace(token, '')
	}
	text = text.trim_space()
	for text.contains('  ') {
		text = text.replace('  ', ' ')
	}
	if max_len > 0 && text.len > max_len {
		// Cut on a word boundary so a multi-byte character is never split.
		mut cut := text[..max_len]
		if space := cut.last_index(' ') {
			cut = cut[..space]
		}
		return cut.trim_space() + '…'
	}
	return text
}

fn xml_escape(s string) string {
	return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"',
		'&quot;').replace("'", '&apos;')
}
