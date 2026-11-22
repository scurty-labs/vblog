Most writing is not finished in one sitting. A blog that only offers "publish" pushes you to write in public; a blog that offers drafts, schedules and tags lets you write badly first, and sort it out later.

## Three states, one editor

Every post is in exactly one state, and the dashboard filters on it:

- **Draft** — saved and private. Only you can read it, and it never appears in the feed or on the front page.
- **Scheduled** — published, but with a future timestamp. It stays hidden until that moment, then appears without you doing anything.
- **Published** — visible now, in the feed, on its page and in the sitemap.

The editor is the same for all three. Save as a draft while the argument is still moving, set a schedule once it is done, or press publish now if it is ready and you would rather not wait.

## Tags, kept small

Tags are comma-separated on the editor and rendered as a cloud in the sidebar, each with a count. Two pieces of advice, offered without charge:

1. **Tag by subject, not by mood.** "markdown" will still make sense in a year; "quick" will not.
2. **Let the list stay under control.** Ten tags describe most blogs. If a tag has one post in it, it is not a category yet — it is a note to yourself.

Every tag gets its own archive at `/tag/<tag>`, and each article ends with related posts drawn from shared tags, so a reader who arrives from a search engine has somewhere to go next.

## A schedule that is just a date

There is no queue and no cron job: a scheduled post carries a publish time, and every public query compares it against the clock. That means the post appears on the first request after the time passes, even if the server was asleep until then.

The one thing to remember is the clock itself. If the machine's time zone is wrong, your schedule is wrong by the same amount, so set the server's clock once and leave it alone.

## Duplicating instead of retyping

The dashboard can duplicate any post into a fresh draft. It is the quickest way to re-use a template — a monthly roundup, a link list, a photo post — without keeping an empty draft around forever.

## Deleting without losing

Deleting a post hides it from every view but keeps the row, so an accidental click is recoverable with one SQL statement and a little nerve. It also means links people have already shared stop resolving visibly rather than silently turning into a different post.

None of this is complicated, which is the point. The workflow should be quiet enough that you forget it is there and just write.
