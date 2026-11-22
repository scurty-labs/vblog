![The Starry Night, Vincent van Gogh, 1889](/media/starry-night.jpg)

A colophon is the old printer's note at the end of a book: who set the type, on what paper, and why it looks the way it does. This is the web version.

## The engine

The site runs on [vblog], a small blogging system written in [V](https://vlang.io) and served by [veb](https://github.com/vlang/veb). Pages are rendered on the server, the database is a single SQLite file, and the whole binary ships with its templates, styles and icons. There is no build step between writing a post and reading it.

Posts are stored as Markdown and rendered when the page is requested, which keeps the archive searchable and the editor honest: what you type is what gets stored.

## The type

Body text is set in a humanist sans for interface and a serif for long reading, both served from this server rather than a font network. Line length is capped at a comfortable measure, headings use a slightly tighter tracking, and the sidebar keeps a fixed rail so the reading column never shifts as you navigate.

## The pictures

Every picture in the sample content is public domain or CC0: two paintings, a NASA photograph from the Apollo programme, and two landscape photographs. Credits are in `sample-data/CREDITS.md` in the project.

## The colours

Themes are plain CSS files under `static/themes/`, each importing a shared stylesheet and overriding a small set of tokens. Adding a theme means adding a file and one line to the theme list, not touching the templates.

If you are reading this on your own copy of the demo, none of the above is fixed. Rewrite the page, or delete it — a colophon only earns its place if you wrote it.
