module main

import os
import time
import strings
import net.http

// The media folder is plain files on disk. It is mounted at /media by the
// server, so the same path works as both the upload destination and the public
// URL. Mount it from a volume in production to keep uploads off the repo.
const media_dir = 'media'
const max_media_bytes = 32 * 1024 * 1024

// The media folder shares the blog's origin, so refuse files a browser would
// run as a page or an executable. Everything else is fair game.
const blocked_media_extensions = ['html', 'htm', 'xhtml', 'shtml', 'php', 'phtml', 'phar', 'cgi',
	'pl', 'py', 'rb', 'sh', 'bash', 'exe', 'bat', 'cmd', 'ps1', 'msi']

fn (mut app App) ensure_media_schema() {
	os.mkdir_all(media_dir) or {
		eprintln("Couldn't create the media folder: ${err}")
	}
	app.db.execute("CREATE TABLE IF NOT EXISTS Media (id INTEGER PRIMARY KEY AUTOINCREMENT, file_name TEXT NOT NULL, title TEXT NOT NULL DEFAULT '', alt TEXT NOT NULL DEFAULT '', mime TEXT NOT NULL DEFAULT '', size INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL DEFAULT 0)") or {
		panic(err)
	}
}

// sync_media_library reconciles the database with the folder, so files dropped
// into a mounted media/ directory show up in the gallery and deleted files
// leave it.
fn (mut app App) sync_media_library() {
	files := os.ls(media_dir) or { []string{} }
	rows := sql app.db {
		select from Media
	} or { []Media{} }

	mut by_name := map[string]Media{}
	for row in rows {
		by_name[row.file_name] = row
	}

	mut seen := map[string]bool{}
	now := time.now().unix()
	for name in files {
		if name.starts_with('.') {
			continue
		}
		path := os.join_path(media_dir, name)
		if os.is_dir(path) {
			continue
		}
		seen[name] = true
		new_size := i64(os.file_size(path))
		if name !in by_name {
			app.insert_media(Media{
				file_name:  name
				title:      media_default_title(name)
				mime:       media_mime_for(name)
				size:       new_size
				created_at: now
			})
		} else if by_name[name].size != new_size {
			row_id := by_name[name].id
			sql app.db {
				update Media set size = new_size where id == row_id
			} or {}
		}
	}

	for row in rows {
		if row.file_name !in seen {
			sql app.db {
				delete from Media where id == row.id
			} or {}
		}
	}
}

fn (mut app App) get_media_items() []Media {
	items := sql app.db {
		select from Media order by created_at desc
	} or { []Media{} }
	return items
}

fn (mut app App) get_media_by_id(media_id int) ?Media {
	items := sql app.db {
		select from Media where id == media_id limit 1
	} or { []Media{} }
	if items.len == 0 {
		return none
	}
	return items[0]
}

fn (mut app App) insert_media(item Media) {
	sql app.db {
		insert item into Media
	} or {
		eprintln("Couldn't record the uploaded file: ${err}")
	}
}

fn (mut app App) update_media_details(media_id int, title string, alt string) {
	sql app.db {
		update Media set title = title, alt = alt where id == media_id
	} or {
		eprintln("Couldn't update the media details: ${err}")
	}
}

fn (mut app App) remove_media(item Media) {
	os.rm(os.join_path(media_dir, item.file_name)) or {
		eprintln("Couldn't remove ${item.file_name}: ${err}")
	}
	sql app.db {
		delete from Media where id == item.id
	} or {
		eprintln("Couldn't remove the media record: ${err}")
	}
}

// image_kind_from_bytes recognises the image formats the blog accepts by their
// leading bytes, so a file cannot pass as a PNG just by being named .png.
fn image_kind_from_bytes(data string) string {
	limit := if data.len < 512 { data.len } else { 512 }
	head := data[..limit]
	if head.len >= 8 && head[..8] == '\x89PNG\r\n\x1a\n' {
		return 'png'
	}
	if head.len >= 3 && head[..3] == '\xff\xd8\xff' {
		return 'jpeg'
	}
	if head.len >= 6 && (head[..6] == 'GIF87a' || head[..6] == 'GIF89a') {
		return 'gif'
	}
	if head.len >= 12 && head[..4] == 'RIFF' && head[8..12] == 'WEBP' {
		return 'webp'
	}
	if head.len >= 4 && head[..4] == '\x00\x00\x01\x00' {
		return 'ico'
	}
	if looks_like_svg(data) {
		return 'svg'
	}
	return ''
}

fn looks_like_svg(data string) bool {
	limit := if data.len < 4096 { data.len } else { 4096 }
	head := data[..limit].trim_space().to_lower()
	return head.starts_with('<svg') || (head.starts_with('<?xml') && head.contains('<svg'))
}

// svg_is_safe screens SVG uploads for the constructs that would turn a file
// opened directly from the media folder into script running on the blog's
// origin. It is a deny-list, not a sanitiser: it stops the obvious payloads.
fn svg_is_safe(data string) bool {
	limit := if data.len < 262144 { data.len } else { 262144 }
	text := data[..limit].to_lower()
	blocked := ['<script', '<foreignobject', 'onload=', 'onerror=', 'onclick=', 'onmouseover=',
		'javascript:']
	for needle in blocked {
		if text.contains(needle) {
			return false
		}
	}
	return true
}

// image_extension_kind is the sniffed kind an extension must match; anything
// not listed here (documents, archives, video) is not content-checked.
fn image_extension_kind(ext string) string {
	return match ext {
		'png' { 'png' }
		'jpg', 'jpeg' { 'jpeg' }
		'gif' { 'gif' }
		'webp' { 'webp' }
		'ico' { 'ico' }
		'svg' { 'svg' }
		else { '' }
	}
}

// media_content_allowed makes sure an upload claiming to be an image really is
// one, and that an SVG carries no script. The folder is served from the blog's
// own origin, so a masquerading file is worth refusing.
fn media_content_allowed(name string, data string) bool {
	if !name.contains('.') {
		return true
	}
	expected := image_extension_kind(name.all_after_last('.').to_lower())
	if expected.len == 0 {
		return true
	}
	kind := image_kind_from_bytes(data)
	if kind != expected {
		return false
	}
	if kind == 'svg' {
		return svg_is_safe(data)
	}
	return true
}

// store_media_upload writes one multipart file into media/ and records it.
fn (mut app App) store_media_upload(file http.FileData) bool {
	if file.filename.len == 0 || file.data.len == 0 {
		return false
	}
	if file.data.len > max_media_bytes {
		return false
	}
	name := media_safe_name(file.filename)
	if name.len == 0 || media_blocked(name) {
		return false
	}
	if !media_content_allowed(name, file.data) {
		return false
	}
	stored_name := media_unique_name(name)
	path := os.join_path(media_dir, stored_name)
	os.write_file_array(path, file.data.bytes()) or {
		eprintln("Couldn't save the uploaded file: ${err}")
		return false
	}
	app.insert_media(Media{
		file_name:  stored_name
		title:      media_default_title(name)
		mime:       media_mime_for(stored_name)
		size:       i64(file.data.len)
		created_at: time.now().unix()
	})
	return true
}

// media_safe_name turns a browser-supplied file name into a URL-safe, flat
// name. Slashes and dots that could escape media/ are dropped.
fn media_safe_name(raw string) string {
	base := raw.replace('\\', '/').all_after_last('/').trim_space().to_lower()
	mut name := strings.Builder{}
	mut pending_dash := false
	for ch in base {
		if (ch >= `a` && ch <= `z`) || (ch >= `0` && ch <= `9`) || ch == `.`
			|| ch == `-` || ch == `_` {
			name.write_u8(ch)
			pending_dash = false
		} else if (ch == ` ` || ch == `+` || ch == `(` || ch == `)` || ch == `[` || ch == `]`)
			&& !pending_dash && name.len > 0 {
			name.write_u8(`-`)
			pending_dash = true
		}
	}
	mut result := name.str().trim_space().trim('-').trim('.')
	if result.len > 100 {
		ext := if result.contains('.') { result.all_after_last('.') } else { '' }
		stem := if result.contains('.') { result.all_before_last('.') } else { result }
		result = if ext.len > 0 && ext.len < 12 { '${stem[..90]}.${ext}' } else { stem[..100] }
		result = result.trim('-').trim('.')
	}
	return result
}

fn media_blocked(name string) bool {
	if !name.contains('.') {
		return false
	}
	return name.all_after_last('.').to_lower() in blocked_media_extensions
}

fn media_unique_name(name string) string {
	if !os.exists(os.join_path(media_dir, name)) {
		return name
	}
	stem := if name.contains('.') { name.all_before_last('.') } else { name }
	ext := if name.contains('.') { '.${name.all_after_last('.')}' } else { '' }
	mut i := 1
	for i < 10000 {
		candidate := '${stem}-${i}${ext}'
		if !os.exists(os.join_path(media_dir, candidate)) {
			return candidate
		}
		i++
	}
	return '${stem}-${i}${ext}'
}

fn media_stem(name string) string {
	if name.contains('.') {
		return name.all_before_last('.')
	}
	return name
}

fn media_default_title(name string) string {
	clean := media_stem(name).replace('_', ' ').replace('-', ' ').trim_space()
	if clean.len == 0 {
		return name
	}
	if clean.len == 1 {
		return clean.to_upper()
	}
	return clean[..1].to_upper() + clean[1..]
}

fn media_mime_for(name string) string {
	if !name.contains('.') {
		return 'application/octet-stream'
	}
	return match name.all_after_last('.').to_lower() {
		'jpg', 'jpeg' { 'image/jpeg' }
		'png' { 'image/png' }
		'gif' { 'image/gif' }
		'webp' { 'image/webp' }
		'avif' { 'image/avif' }
		'svg' { 'image/svg+xml' }
		'bmp' { 'image/bmp' }
		'ico' { 'image/x-icon' }
		'tif', 'tiff' { 'image/tiff' }
		'heic' { 'image/heic' }
		'mp4', 'm4v' { 'video/mp4' }
		'webm' { 'video/webm' }
		'mov' { 'video/quicktime' }
		'mp3' { 'audio/mpeg' }
		'wav' { 'audio/wav' }
		'ogg', 'oga' { 'audio/ogg' }
		'm4a' { 'audio/mp4' }
		'flac' { 'audio/flac' }
		'pdf' { 'application/pdf' }
		'txt', 'md', 'markdown', 'log' { 'text/plain' }
		'csv' { 'text/csv' }
		'html', 'htm' { 'text/html' }
		'css' { 'text/css' }
		'js' { 'text/javascript' }
		'json' { 'application/json' }
		'xml' { 'application/xml' }
		'zip' { 'application/zip' }
		'gz', 'tgz' { 'application/gzip' }
		'rar' { 'application/vnd.rar' }
		'7z' { 'application/x-7z-compressed' }
		'tar' { 'application/x-tar' }
		'doc' { 'application/msword' }
		'docx' { 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }
		'xls' { 'application/vnd.ms-excel' }
		'xlsx' { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
		'ppt' { 'application/vnd.ms-powerpoint' }
		'pptx' { 'application/vnd.openxmlformats-officedocument.presentationml.presentation' }
		'woff' { 'font/woff' }
		'woff2' { 'font/woff2' }
		'ttf' { 'font/ttf' }
		'otf' { 'font/otf' }
		else { 'application/octet-stream' }
	}
}

// media_escape percent-encodes a search term for links in the gallery.
fn media_escape(value string) string {
	mut out := strings.Builder{}
	for b in value.bytes() {
		if (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`) || (b >= `0` && b <= `9`)
			|| b == `-` || b == `_` || b == `.` || b == `~` {
			out.write_u8(b)
		} else {
			out.write_string('%${int(b):02X}')
		}
	}
	return out.str()
}
