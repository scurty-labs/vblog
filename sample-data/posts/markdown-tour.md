Every page on this blog is written in Markdown, so it is worth knowing what the renderer handles before you start writing. This post is a reference you can keep around and delete when it stops being useful.

## Headings and paragraphs

Use `#` for a top-level heading and up to six hashes for deeper ones; the post title is already a heading, so most articles start at `##`. Paragraphs are separated by a blank line. A single newline inside a paragraph is kept as a soft break, which means you can write one sentence per line in the source and still get a tidy paragraph.

That is how this paragraph is written. It reads the same in the editor and on the page.

## Emphasis and inline code

Use **bold** for a phrase that matters, *italics* for a title or a word in another language, and `inline code` for a filename, a command or a setting. You can combine them: a **draft that is still `unpublished`** reads fine too. Strike-through works as well, ~~like this~~, mostly for corrections.

Links are ordinary Markdown: point at an [external page](https://vlang.io), at another post, or at a path like `/tag/notes`. Internal links keep the reader on your site, which is usually what you want.

## Lists

Unordered lists suit collections; ordered lists suit sequences:

- posts, pages and drafts
- tags and a tag cloud
- the media library

1. Write the body.
2. Add tags.
3. Save as a draft.
4. Publish.

Nested lists work by indenting:

- Publishing states
    - draft: only you can see it
    - scheduled: published automatically at a future time
    - published: visible on the front page

## Quotes and code

> A blog is a conversation with your future self, who will have forgotten the details you are sure you will remember.

A blockquote holds more than one paragraph, if you need it to:

> The second paragraph belongs to the same quotation because the two are not separated by a blank line inside the quote.

Fenced code blocks keep their whitespace and ignore Markdown syntax:

```sh
v -prod .
./vblog
```

```sql
select title, date from Post where status = 'draft' order by date desc;
```

## Tables

| Element | Markdown | Notes |
| --- | --- | --- |
| Heading | `## Title` | the post title is separate |
| Bold | `**word**` | renders in the theme's strong colour |
| Link | `[text](url)` | internal and external links |
| Image | `![alt](url)` | alt text is read by screen readers |

Tables are on with pipes and a separator row, so pasting a spreadsheet excerpt mostly works.

## Images and galleries

A single image sits at the width of the article:

![A lake in the Jacques-Cartier national park](/media/jacques-cartier-lake.jpg)

When two or more images sit in the same paragraph — no blank line between them — they are tiled into a gallery, which is the tidier way to show a set:

![The Great Wave, Hokusai](/media/great-wave.jpg)
![Starry Night, Vincent van Gogh](/media/starry-night.jpg)

Write alt text that describes the picture, not the filename. It is what a reader on a slow connection or a screen reader actually gets.

## The last rule

That is the whole syntax. If a feature is missing, write around it in plain paragraphs — a post that reads well beat a post that uses every control.
