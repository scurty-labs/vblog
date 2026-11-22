module main

import veb

// RSS 2.0 feed of the latest published posts.
@['/rss.xml']
pub fn (mut app App) rss_feed(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	base := xml_escape(app.base_url(ctx))
	posts := app.get_recent_published_posts(20)

	mut items := []string{}
	for post in posts {
		mut categories := ''
		for tag in post.tag_list() {
			categories += '<category>${xml_escape(tag)}</category>'
		}
		items << '<item><title>${xml_escape(post.title)}</title><link>${base}/view/post/${post.id}</link><guid isPermaLink="true">${base}/view/post/${post.id}</guid><description>${xml_escape(plain_text(post.body,
			320))}</description>${categories}</item>'
	}

	xml := '<?xml version="1.0" encoding="UTF-8"?>\n<rss version="2.0"><channel><title>${xml_escape(ctx.settings.blog_title)}</title><link>${base}/</link><description>${xml_escape(plain_text(ctx.settings.blog_description,
		200))}</description><language>en</language>${items.join('')}</channel></rss>'

	return ctx.send_response_to_client('application/rss+xml; charset=utf-8', xml)
}

// Sitemap with every public post, page and tag archive.
@['/sitemap.xml']
pub fn (mut app App) sitemap(mut ctx Context) veb.Result {
	app.prepare(mut ctx)
	base := xml_escape(app.base_url(ctx))
	mut urls := []string{}
	urls << '<url><loc>${base}/</loc></url>'
	for post in app.get_published_posts() {
		urls << '<url><loc>${base}/view/post/${post.id}</loc></url>'
	}
	for page in app.get_pages() {
		urls << '<url><loc>${base}/pages/${page.id}</loc></url>'
	}
	for tag in app.get_tag_counts() {
		urls << '<url><loc>${base}/tag/${tag.tag}</loc></url>'
	}

	xml := '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.join('')}</urlset>'
	return ctx.send_response_to_client('application/xml; charset=utf-8', xml)
}

fn (app &App) base_url(ctx &Context) string {
	host := ctx.req.host
	if host.len > 0 {
		return 'http://${host}'
	}
	return 'http://localhost:${app.config.port}'
}
