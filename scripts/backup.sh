#!/bin/sh
# Copy the database, config.json and media/ into backups/<timestamp>/ — the same
# folder layout the admin Backups page lists and restores.
#
#   sh scripts/backup.sh                 # keep the newest 10
#   VBLOG_BACKUP_KEEP=5 sh scripts/backup.sh
#
# The database is snapshotted with sqlite3's .backup, which is consistent while
# the server is running; a plain `cp` of a live database can be torn. Backups can
# also be taken from the admin page, and automatic ones run while the server is
# up.

set -eu

cd "$(dirname "$0")/.."

keep="${VBLOG_BACKUP_KEEP:-10}"

if [ ! -f primary.sqlite ]; then
	echo "No primary.sqlite in $(pwd); nothing to back up." >&2
	exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
	echo "sqlite3 is needed to snapshot the database (install the sqlite3 package)." >&2
	exit 1
fi

stamp=$(date +%Y-%m-%d_%H-%M-%S)
name="$stamp"
dest="backups/$name"
suffix=2
while [ -e "$dest" ]; do
	name="$stamp-$suffix"
	dest="backups/$name"
	suffix=$((suffix + 1))
done

mkdir -p "$dest"

if ! sqlite3 primary.sqlite ".backup '$dest/primary.sqlite'"; then
	echo "Snapshot failed; removed the partial backup." >&2
	rm -rf "$dest"
	exit 1
fi

if [ -f config.json ]; then
	cp config.json "$dest/config.json"
fi

if [ -d media ]; then
	cp -R media "$dest/media"
fi

# Prune oldest first, keeping the newest $keep folders.
count=0
for dir in $(ls -1d backups/*/ 2>/dev/null | sort -r); do
	count=$((count + 1))
	if [ "$count" -gt "$keep" ]; then
		rm -rf "$dir"
	fi
done

printf 'Backed up to %s (%s)\n' "$dest" "$(du -sh "$dest" | cut -f1)"
