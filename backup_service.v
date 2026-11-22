module main

import os
import time
import json2
import db.sqlite

// Backups are plain folders under backups/, one per run:
//
//   backups/2026-11-16_21-30-00/primary.sqlite
//                               /config.json
//                               /media/...
//
// A folder keeps a snapshot readable with ordinary tools and makes restoring a
// file copy instead of an unpacking step. scripts/backup.sh writes the same
// layout, so backups taken from the shell show up in the admin list too.
const backups_dir = 'backups'
const backup_schedule_file = 'schedule.json'
const backup_db_name = 'primary.sqlite'
const backup_config_name = 'config.json'
const backup_default_interval_hours = 24
const backup_default_keep = 10
const backup_min_interval_hours = 1
const backup_max_interval_hours = 720
const backup_min_keep = 1
const backup_max_keep = 100
const backup_intervals = [1, 3, 6, 12, 24, 48, 72, 168]

// BackupSchedule is the automatic-backup setting stored next to the backups, so
// the folder is the only thing that has to exist for the feature to work. It
// also means the schedule can be edited by hand while the server is stopped.
struct BackupSchedule {
pub mut:
	enabled        bool
	interval_hours int
	keep           int
	last_run       i64
}

// BackupEntry is one folder in backups/, as listed on the admin page.
struct BackupEntry {
pub mut:
	name        string
	created_at  i64
	size        i64
	media_count int
	has_config  bool
}

struct BackupTotals {
mut:
	bytes i64
	files int
}

pub fn (entry BackupEntry) size_label() string {
	return human_size(entry.size)
}

pub fn (entry BackupEntry) date_label() string {
	return backup_time_label(entry.created_at)
}

pub fn (entry BackupEntry) media_label() string {
	if entry.media_count == 1 {
		return '1 file'
	}
	return '${entry.media_count} files'
}

fn backup_time_label(ts i64) string {
	if ts <= 0 {
		return '—'
	}
	// time.unix() is UTC; the folder names come from the server's local clock,
	// so the labels have to be local too or they disagree with them.
	t := time.unix(ts).local()
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	month := if t.month >= 1 && t.month <= 12 { months[t.month - 1] } else { '' }
	return '${month} ${t.day}, ${t.year} · ${t.hour:02}:${t.minute:02}'
}

fn load_backup_schedule() BackupSchedule {
	mut schedule := BackupSchedule{
		interval_hours: backup_default_interval_hours
		keep:           backup_default_keep
	}
	path := os.join_path(backups_dir, backup_schedule_file)
	if !os.exists(path) {
		return schedule
	}
	data := os.read_file(path) or { return schedule }
	loaded := json2.decode[BackupSchedule](data) or { return schedule }
	schedule = loaded
	schedule.interval_hours = clamp_backup_interval(schedule.interval_hours)
	schedule.keep = clamp_backup_keep(schedule.keep)
	return schedule
}

fn save_backup_schedule(schedule BackupSchedule) ! {
	os.mkdir_all(backups_dir)!
	os.write_file(os.join_path(backups_dir, backup_schedule_file), json2.encode(schedule))!
}

fn clamp_backup_interval(hours int) int {
	if hours < backup_min_interval_hours {
		return backup_min_interval_hours
	}
	if hours > backup_max_interval_hours {
		return backup_max_interval_hours
	}
	return hours
}

fn clamp_backup_keep(keep int) int {
	if keep < backup_min_keep {
		return backup_min_keep
	}
	if keep > backup_max_keep {
		return backup_max_keep
	}
	return keep
}

// backup_next_run is when the scheduler will take its next copy. A schedule
// that has never run is due straight away.
fn backup_next_run(schedule BackupSchedule) i64 {
	if !schedule.enabled {
		return 0
	}
	if schedule.last_run <= 0 {
		return time.now().unix()
	}
	return schedule.last_run + i64(schedule.interval_hours) * 3600
}

// tally_dir adds up a folder for the size and file counts shown in the list.
fn tally_dir(path string, mut totals BackupTotals) {
	names := os.ls(path) or { return }
	for name in names {
		full := os.join_path(path, name)
		if os.is_dir(full) {
			tally_dir(full, mut totals)
		} else {
			totals.bytes += os.file_size(full)
			totals.files++
		}
	}
}

// list_backups returns the folders that hold a database snapshot, newest first.
// Names start with the date, so a reverse name sort is a reverse date sort.
fn list_backups() []BackupEntry {
	mut entries := []BackupEntry{}
	names := os.ls(backups_dir) or { return entries }
	for name in names {
		if name.starts_with('.') {
			continue
		}
		dir := os.join_path(backups_dir, name)
		if !os.is_dir(dir) || !os.exists(os.join_path(dir, backup_db_name)) {
			continue
		}
		mut totals := BackupTotals{}
		tally_dir(dir, mut totals)
		mut media_totals := BackupTotals{}
		media_path := os.join_path(dir, media_dir)
		if os.exists(media_path) {
			tally_dir(media_path, mut media_totals)
		}
		entries << BackupEntry{
			name:        name
			created_at:  os.file_last_mod_unix(dir)
			size:        totals.bytes
			media_count: media_totals.files
			has_config:  os.exists(os.join_path(dir, backup_config_name))
		}
	}
	entries.sort(a.name > b.name)
	return entries
}

// valid_backup_name keeps a form value from reaching any folder but backups/.
fn valid_backup_name(name string) bool {
	if name.len == 0 || name.len > 64 {
		return false
	}
	for ch in name {
		allowed := (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`) || (ch >= `0` && ch <= `9`)
			|| ch == `-` || ch == `_`
		if !allowed {
			return false
		}
	}
	return true
}

// backup_unique_name is the folder name for a new backup: sortable, readable
// and unique even when two runs land in the same second.
fn backup_unique_name() string {
	now := time.now()
	base := '${now.year:04}-${now.month:02}-${now.day:02}_${now.hour:02}-${now.minute:02}-${now.second:02}'
	mut name := base
	mut suffix := 2
	for os.exists(os.join_path(backups_dir, name)) {
		name = '${base}-${suffix}'
		suffix++
	}
	return name
}

fn copy_tree(src string, dst string) ! {
	os.mkdir_all(dst)!
	names := os.ls(src)!
	for name in names {
		from := os.join_path(src, name)
		to := os.join_path(dst, name)
		if os.is_dir(from) {
			copy_tree(from, to)!
		} else {
			os.cp(from, to)!
		}
	}
}

// clear_media_folder empties media/ but keeps dotfiles such as .gitkeep.
fn clear_media_folder() ! {
	if !os.exists(media_dir) {
		os.mkdir_all(media_dir)!
		return
	}
	names := os.ls(media_dir)!
	for name in names {
		if name.starts_with('.') {
			continue
		}
		full := os.join_path(media_dir, name)
		if os.is_dir(full) {
			os.rmdir_all(full)!
		} else {
			os.rm(full)!
		}
	}
}

// create_backup_snapshot writes one backup folder and prunes older ones. The
// database goes through SQLite's own VACUUM INTO so the copy is consistent
// while the blog keeps serving requests; a plain file copy can be torn.
fn create_backup_snapshot(mut db sqlite.DB, keep int) !string {
	os.mkdir_all(backups_dir)!
	name := backup_unique_name()
	dir := os.join_path(backups_dir, name)
	os.mkdir_all(dir) or { return err }
	db.execute("VACUUM INTO '${os.join_path(dir, backup_db_name)}'") or {
		os.rmdir_all(dir) or {}
		return err
	}
	if os.exists(backup_config_name) {
		os.cp(backup_config_name, os.join_path(dir, backup_config_name)) or {
			os.rmdir_all(dir) or {}
			return err
		}
	}
	if os.exists(media_dir) {
		copy_tree(media_dir, os.join_path(dir, media_dir)) or {
			os.rmdir_all(dir) or {}
			return err
		}
	}
	prune_backups(keep)
	return name
}

// prune_backups deletes the oldest folders once more than `keep` exist.
fn prune_backups(keep int) {
	limit := clamp_backup_keep(keep)
	for index, entry in list_backups() {
		if index < limit {
			continue
		}
		os.rmdir_all(os.join_path(backups_dir, entry.name)) or {
			eprintln("Couldn't prune the ${entry.name} backup: ${err}")
		}
	}
}

// restore_files replaces the live database, config and media with one backup's
// copy. Everything on disk that the backup does not contain is removed, which
// is what the confirmation dialog on the Backups page warns about.
fn restore_files(dir string) ! {
	os.cp(os.join_path(dir, backup_db_name), backup_db_name)!
	if os.exists(os.join_path(dir, backup_config_name)) {
		os.cp(os.join_path(dir, backup_config_name), backup_config_name)!
	}
	clear_media_folder()!
	backup_media := os.join_path(dir, media_dir)
	if os.exists(backup_media) {
		copy_tree(backup_media, media_dir)!
	}
}

fn (mut app App) restore_backup(name string) ! {
	if !valid_backup_name(name) {
		return error('That is not a valid backup name.')
	}
	dir := os.join_path(backups_dir, name)
	if !os.exists(os.join_path(dir, backup_db_name)) {
		return error('Backup ${name} has no database snapshot.')
	}

	// The open handle has to go before the file is replaced underneath it. The
	// connection is reopened whatever happens, so a failed copy cannot leave the
	// blog without a database.
	app.db.close() or {}
	restored := restore_files(dir)
	app.db = sqlite.connect(backup_db_name) or { panic(err) }
	restored or { return err }

	// The restored database may predate a schema change, so bring it up to date
	// and reconcile the media table with the files just copied in.
	app.ensure_settings_schema()
	app.ensure_post_schema()
	app.ensure_media_schema()
	app.sync_media_library()
}

// run_backup_scheduler is the automatic half of the Backups page. It wakes up
// every half minute, reads the schedule from disk and takes a copy when one is
// due. It keeps its own database connection: the server's handle belongs to the
// request threads.
fn run_backup_scheduler() {
	for {
		time.sleep(30 * time.second)
		mut schedule := load_backup_schedule()
		if !schedule.enabled {
			continue
		}
		now := time.now().unix()
		if schedule.last_run > 0 && now - schedule.last_run < i64(schedule.interval_hours) * 3600 {
			continue
		}
		mut db := sqlite.connect(backup_db_name) or {
			eprintln('Scheduled backup skipped: ${err}')
			continue
		}
		name := create_backup_snapshot(mut db, schedule.keep) or {
			db.close() or {}
			eprintln('Scheduled backup failed: ${err}')
			continue
		}
		db.close() or {}
		schedule.last_run = time.now().unix()
		save_backup_schedule(schedule) or {
			eprintln("Couldn't record the scheduled backup: ${err}")
		}
		println('Scheduled backup written to ${backups_dir}/${name}.')
	}
}
