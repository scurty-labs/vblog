# Sample data

Optional demo content for a fresh vblog install: four posts, two pages, the tags
those posts use, and five pictures that are public domain or CC0.

During the first start, after the admin account is created, setup asks whether to
import this folder. Answering `y` copies the images into `media/` and inserts the
posts and pages into `primary.sqlite`, each with a publish date a few days in the
past so the front page is not a single block of identical timestamps. Answering
`n` leaves the database empty: no posts, no pages, just the default settings.

The import runs once, during setup. Everything it adds is ordinary content, so it
can be edited or deleted from `/admin` afterwards; deleting a sample post does not
bring it back.

## Layout

```
sample-data/
├── sample.json          # what to import: files, titles, tags, relative dates
├── posts/*.md           # post bodies, plain Markdown
├── pages/*.md           # page bodies
├── images/*.jpg         # pictures copied into media/ on import
└── CREDITS.md           # image licences
```

`sample.json` lists each item with a `file` inside this folder, a `title`, comma
separated `tags` and `days_ago`, the number of days before setup to date it.
Pages are imported with the same fields but never get tags or a date in the feed.

## Editing the samples

The Markdown files are the source of truth for the text and are not parsed for
front matter, so they can be opened in any editor. Add an entry to `sample.json`
when you add a file, and keep the paths relative to this folder. Images are copied
as-is and picked up by the media library's folder scan, so their titles come from
their file names — use descriptive names.

If this folder is missing or unreadable at setup time, the import is skipped with
a note and the blog starts blank. Keep it next to the `vblog` binary if you want
the prompt to work.
