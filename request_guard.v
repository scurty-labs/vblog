module main

// A request counts as same-site unless the browser says it came from another
// site. Sec-Fetch-Site is sent by every modern browser, including on the
// top-level GET navigations that the delete links are reached by; Origin and
// Referer are the fallback for older ones. Anything we cannot place is treated
// as foreign, so a page on another site cannot borrow a logged-in browser.
fn same_site_request(ctx &Context) bool {
	site := ctx.req.header.get_custom('Sec-Fetch-Site') or { '' }
	if site.len > 0 {
		return site == 'same-origin' || site == 'none'
	}

	host := request_authority(ctx)
	if host.len == 0 {
		return false
	}

	origin := ctx.req.header.get(.origin) or { '' }
	if origin.len > 0 {
		return request_host(origin) == host
	}

	referer := ctx.req.header.get(.referer) or { '' }
	if referer.len > 0 {
		return request_host(referer) == host
	}

	return false
}

// request_authority is the host[:port] this request was addressed to, which is
// what an Origin or Referer has to agree with.
fn request_authority(ctx &Context) string {
	if ctx.req.host.len > 0 {
		return ctx.req.host
	}
	return ctx.req.header.get(.host) or { '' }
}

// request_host drops the scheme, any userinfo and the path from a URL, leaving
// the host[:port] that the Host header carries.
fn request_host(url string) string {
	mut rest := url.trim_space()
	if index := rest.index('://') {
		rest = rest[index + 3..]
	}
	rest = rest.all_before('/')
	if at := rest.last_index('@') {
		rest = rest[at + 1..]
	}
	return rest
}

// Mutating handlers use this instead of a bare `ctx.is_admin`: they need the
// session *and* a request that did not originate somewhere else.
fn (app &App) is_admin_request(ctx &Context) bool {
	return ctx.is_admin && same_site_request(ctx)
}
