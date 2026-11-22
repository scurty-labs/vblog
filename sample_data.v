module main

import os
import time
import json2

// Sample content lives next to the binary so a fresh install can be given
// something to look at. See sample-data/README.md for the folder layout.
const sample_dir = 'sample-data'

// SampleItem is one post or page listed in sample-data/sample.json.
struct SampleItem {
	file     string
	title    string
	tags     string
	days_ago int
}

struct SampleManifest {
	posts  []SampleItem
	pages  []SampleItem
	images []string
}

// import_sample_data copies the sample pictures into media/ and inserts the
// sample posts and pages. It runs once, from setup, only when the user asks for
// it: a missing or broken folder is reported and skipped, never fatal, so the
// blog still starts with default settings and the style-guide post.
fn (mut app App) import_sample_data() {
	manifest_path := os.join_path(sample_dir, 'sample.json')
	data := os.read_file(manifest_path) or {
		println('No sample data found in ${sample_dir}/, starting with an empty blog.')
		return
	}
	manifest := json2.decode[SampleManifest](data) or {
		println("Couldn't read ${manifest_path}: ${err}. Starting with an empty blog.")
		return
	}

	images := app.import_sample_images(manifest.images)
	mut posts := 0
	mut pages := 0
	for item in manifest.posts {
		if app.import_sample_item(item, false) {
			posts++
		}
	}
	for item in manifest.pages {
		if app.import_sample_item(item, true) {
			pages++
		}
	}

	if posts == 0 && pages == 0 && images == 0 {
		println('Sample data was already imported; nothing to add.')
		return
	}
	println('Imported ${posts} sample posts, ${pages} pages and ${images} pictures.')
	println('They can be edited or deleted from /admin once the server is running.')
}

// import_sample_images copies the listed files into media/ and returns how many
// were new. Existing files are left alone so an upload is never overwritten.
fn (mut app App) import_sample_images(images []string) int {
	mut copied := 0
	for image in images {
		src := os.join_path(sample_dir, image)
		bytes := os.read_bytes(src) or {
			println("Skipped missing sample image ${src}.")
			continue
		}
		name := image.all_after_last('/')
		if name.len == 0 {
			continue
		}
		os.mkdir_all(media_dir) or { continue }
		dst := os.join_path(media_dir, name)
		if os.exists(dst) {
			continue
		}
		os.write_file_array(dst, bytes) or {
			println("Couldn't copy ${name} into ${media_dir}/: ${err}")
			continue
		}
		copied++
	}
	return copied
}

// import_sample_item reads one Markdown file and inserts it as a post or page.
// A row with the same title already exists means the content was imported
// before, so the item is skipped instead of duplicated.
fn (mut app App) import_sample_item(item SampleItem, is_page bool) bool {
	body := os.read_file(os.join_path(sample_dir, item.file)) or {
		println("Skipped missing sample file ${item.file}.")
		return false
	}
	title := item.title
	count := sql app.db {
		select count from Post where title == title
	} or { 0 }
	if count > 0 {
		return false
	}
	days_ago := if item.days_ago > 0 { i64(item.days_ago) } else { 0 }
	post := Post{
		title:   item.title
		body:    body
		tags:    item.tags
		status:  'published'
		date:    time.now().unix() - days_ago * 86400
		is_page: if is_page { 1 } else { 0 }
	}
	if is_page {
		return app.insert_page(post) != 0
	}
	return app.insert_post(post) != 0
}
