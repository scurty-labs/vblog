module main

import time

// default_timezone keeps an existing blog where it already was: the server's
// own zone, which is what pages rendered in before the setting existed.
const default_timezone = 'Local'

// available_timezones is what the settings page offers. IANA names carry their
// own daylight-saving rules, so a schedule keeps the wall clock the author
// typed through a transition; Local follows whatever zone the server uses.
fn available_timezones() []string {
	return [
		'Local',
		'UTC',
		'Europe/London',
		'Europe/Dublin',
		'Europe/Lisbon',
		'Europe/Paris',
		'Europe/Berlin',
		'Europe/Madrid',
		'Europe/Rome',
		'Europe/Amsterdam',
		'Europe/Stockholm',
		'Europe/Warsaw',
		'Europe/Athens',
		'Europe/Helsinki',
		'Europe/Istanbul',
		'Europe/Moscow',
		'Africa/Cairo',
		'Africa/Johannesburg',
		'Africa/Lagos',
		'Asia/Jerusalem',
		'Asia/Dubai',
		'Asia/Karachi',
		'Asia/Kolkata',
		'Asia/Dhaka',
		'Asia/Bangkok',
		'Asia/Jakarta',
		'Asia/Shanghai',
		'Asia/Hong_Kong',
		'Asia/Tokyo',
		'Asia/Seoul',
		'Australia/Perth',
		'Australia/Brisbane',
		'Australia/Sydney',
		'Australia/Melbourne',
		'Pacific/Auckland',
		'America/Anchorage',
		'America/Los_Angeles',
		'America/Denver',
		'America/Chicago',
		'America/New_York',
		'America/Halifax',
		'America/Mexico_City',
		'America/Sao_Paulo',
	]
}

// valid_timezone reports whether the host can resolve a zone name.
fn valid_timezone(name string) bool {
	if name.len == 0 {
		return false
	}
	time.load_location(name) or { return false }
	return true
}

// zone_location resolves a stored zone name, falling back to UTC so a value
// from an old or hand-edited database can never stop a page from rendering.
fn zone_location(name string) &time.Location {
	return time.load_location(name) or { time.load_location('UTC') or { panic(err) } }
}

// parse_wall_time reads a datetime-local value as the author's wall clock in
// `loc` and returns the matching instant. The second pass settles the hour a
// daylight-saving change makes ambiguous or skips.
fn parse_wall_time(value string, loc &time.Location) i64 {
	clean := value.trim_space().replace('T', ' ')
	if clean.len < 16 {
		return 0
	}
	guess := time.parse(clean + ':00') or { return 0 }
	mut instant := guess.unix()
	for _ in 0 .. 2 {
		zone := loc.zone_at(instant) or { return guess.unix() }
		instant = guess.unix() - i64(zone.offset)
	}
	return instant
}

// wall_in shows an instant on the blog's clock.
fn wall_in(ts i64, loc &time.Location) time.Time {
	return time.unix(ts).in(loc) or { time.unix(ts) }
}

// zone is the location every displayed and parsed time uses for this request.
fn (ctx &Context) zone() &time.Location {
	if ctx.tz != unsafe { nil } {
		return ctx.tz
	}
	return zone_location(ctx.settings.timezone)
}

// post_date renders a publish date in the blog's zone.
pub fn (ctx &Context) post_date(post Post) string {
	t := wall_in(post.published_time(), ctx.zone())
	return '${month_name(t.month)} ${t.day}, ${t.year}'
}

// publish_input fills the editor's datetime-local field with the same wall
// clock the author typed, so opening a post never shifts its schedule.
pub fn (ctx &Context) publish_input(post Post) string {
	if post.publish_at <= 0 {
		return ''
	}
	t := wall_in(post.publish_at, ctx.zone())
	return '${t.year}-${two_digits(t.month)}-${two_digits(t.day)}T${two_digits(t.hour)}:${two_digits(t.minute)}'
}

// format_datetime renders an instant as "2 Jan 2030, 10:30" in the blog's zone.
pub fn (ctx &Context) format_datetime(ts i64) string {
	t := wall_in(ts, ctx.zone())
	return '${t.day} ${month_name(t.month)} ${t.year}, ${two_digits(t.hour)}:${two_digits(t.minute)}'
}

fn month_name(month int) string {
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	if month >= 1 && month <= 12 {
		return months[month - 1]
	}
	return ''
}

// timezone_label names a zone option in plain words.
pub fn (ctx &Context) timezone_label(name string) string {
	if name == 'Local' {
		return 'Local (server time)'
	}
	return name.replace('_', ' ')
}
