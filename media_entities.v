module main

import time

// Media is one uploaded file. The file on disk in media/ is the source of
// truth; this row only stores what the filesystem cannot: a display title,
// alt text and the upload time.
struct Media {
pub mut:
	id         int @[primary; sql: serial]
	file_name  string
	title      string
	alt        string
	mime       string
	size       i64
	created_at i64
}

const media_kind_filters = ['all', 'image', 'video', 'audio', 'document', 'other']
const media_sorts = ['newest', 'oldest', 'name', 'size']

pub fn (item Media) url() string {
	return '/media/${item.file_name}'
}

pub fn (item Media) is_image() bool {
	return item.mime.starts_with('image/')
}

pub fn (item Media) kind() string {
	if item.mime.starts_with('image/') {
		return 'image'
	}
	if item.mime.starts_with('video/') {
		return 'video'
	}
	if item.mime.starts_with('audio/') {
		return 'audio'
	}
	if item.mime.starts_with('text/') || item.mime == 'application/pdf'
		|| item.mime == 'application/json' || item.mime.contains('wordprocessingml')
		|| item.mime.contains('spreadsheetml') || item.mime.contains('presentationml')
		|| item.mime == 'application/msword' || item.mime == 'application/vnd.ms-excel' {
		return 'document'
	}
	return 'other'
}

pub fn (item Media) kind_label() string {
	return match item.kind() {
		'image' { 'Image' }
		'video' { 'Video' }
		'audio' { 'Audio' }
		'document' { 'Document' }
		else { 'File' }
	}
}

pub fn (item Media) display_title() string {
	if item.title.len > 0 {
		return item.title
	}
	return media_stem(item.file_name)
}

pub fn (item Media) alt_text() string {
	if item.alt.len > 0 {
		return item.alt
	}
	return item.display_title()
}

// extension is the short uppercase label shown on files without a thumbnail.
pub fn (item Media) extension() string {
	if !item.file_name.contains('.') {
		return 'FILE'
	}
	ext := item.file_name.all_after_last('.').to_upper()
	if ext.len > 4 {
		return ext[..4]
	}
	return ext
}

pub fn (item Media) size_label() string {
	return human_size(item.size)
}

pub fn (item Media) date_label() string {
	if item.created_at <= 0 {
		return '—'
	}
	t := time.unix(item.created_at)
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	month := if t.month >= 1 && t.month <= 12 { months[t.month - 1] } else { '' }
	return '${month} ${t.day}, ${t.year}'
}

pub fn human_size(bytes i64) string {
	if bytes < 1024 {
		return '${bytes} B'
	}
	mut value := f64(bytes)
	mut unit := 0
	units := ['KB', 'MB', 'GB', 'TB']
	for value >= 1024 && unit < units.len - 1 {
		value /= 1024
		unit++
	}
	return '${value:.1f} ${units[unit - 1]}'
}

// filter_media applies the gallery's search, type filter and ordering to the
// already-loaded library, which keeps the page to one query.
fn filter_media(items []Media, query string, kind string, sort_by string) []Media {
	needle := query.to_lower()
	mut out := []Media{}
	for item in items {
		if kind != 'all' && item.kind() != kind {
			continue
		}
		if needle.len > 0 {
			haystack := '${item.file_name} ${item.title} ${item.alt}'.to_lower()
			if !haystack.contains(needle) {
				continue
			}
		}
		out << item
	}
	match sort_by {
		'oldest' {
			out.sort(a.created_at < b.created_at)
		}
		'name' {
			out.sort(a.file_name < b.file_name)
		}
		'size' {
			out.sort(a.size > b.size)
		}
		else {
			out.sort(a.created_at > b.created_at)
		}
	}
	return out
}
