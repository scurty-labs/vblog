# TODO

Post-beta roadmap. Each box is a goal, not a commit; the note under it is the shortest path I know.

## 1. User-uploadable themes

- [ ] **An admin uploads a theme in Settings and it appears in the theme list without a rebuild.**
  - Themes are already plain CSS on disk (`static/themes/`, versioned by `asset_url`), so: store uploads in `media/themes/`, serve them from `/themes/`, and replace `available_themes()` with a directory scan.
  - Roadblock: veb compiles `templates/` into the binary, so a theme cannot change HTML. Keep the theme contract CSS-only, or build a runtime template loader first — that is the bigger job and unlocks real themes.

## 2. Plugins

- [ ] **A plugin can hook post save/publish and page render without editing core files.**
  - V's templates are compiled at build time, so there is no template-level plugin point. Define a small hook interface in Go code (call it from `posts_service` and the routes) and register bundled plugins in `main`.
  - Third-party plugins without recompiling means out-of-process webhooks (post published, comment, etc.), off by default.

## 3. Independent dashboard/admin themes

- [ ] **The admin can use one theme while the public site uses another.**
  - `admin.css` currently reads the site theme's tokens and `<body>` carries the single `theme-*` class. Add an `admin_theme` setting, apply it to dashboard/editor/media/backup pages only, and ship a few admin palettes.

## 4. Modern web design

- [ ] **Public pages feel current without losing the ten themes.**
  - One pass over `style.css` and `_glass.css`: fluid type and spacing with `clamp()`, container queries for the post grid, `@view-transition` for navigation, and a `prefers-color-scheme` block per theme.

## 5. SEO

- [ ] **A default install gives search engines and social previews everything they need.**
  - Already there: sitemap, RSS, `<title>`, description, basic `og:` tags. Remaining: `/robots.txt` pointing at the sitemap, canonical and `og:url`, an `og:image` (post cover or logo) with `summary_large_image`, absolute URLs from `base_url()`, and BlogPosting/BreadcrumbList JSON-LD.

## 6. CI/CD

- [ ] **Every push is formatted, vetted, built and tested; tags produce release binaries.**
  - GitHub Actions with the official V setup action: `v fmt -verify`, `v vet`, `v -prod .`, then a linux/macos/windows matrix attached to a GitHub release on `v*` tags.
  - Start by running `v fmt -w` on the few files that already fail `-verify`; the repo already has `origin` and is 18 commits ahead of `master`, so this only needs the workflow and a first tag.
