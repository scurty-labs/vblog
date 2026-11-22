module main

// set_toast_from_query turns the ?saved= flag a save handler redirects with
// into the confirmation the page it lands on shows as a toast. The message is
// built here rather than in the handler so every page can render it without
// knowing where the visitor came from.
fn (mut ctx Context) set_toast_from_query() {
	ctx.toast_tone = 'success'
	ctx.toast_icon = 'i-check'
	at := (ctx.query['at'] or { '' }).i64()
	match ctx.query['saved'] or { '' } {
		'draft' {
			ctx.toast_message = 'Draft saved. Only you can see it for now.'
		}
		'scheduled' {
			ctx.toast_message = if at > 0 {
				'Post scheduled for ${ctx.format_datetime(at)}.'
			} else {
				'Post scheduled.'
			}
			ctx.toast_tone = 'info'
			ctx.toast_icon = 'i-clock'
		}
		'published' {
			ctx.toast_message = 'Post published.'
		}
		'updated' {
			ctx.toast_message = 'Changes saved.'
		}
		'page' {
			ctx.toast_message = 'Page saved.'
		}
		'page-created' {
			ctx.toast_message = 'Page created.'
		}
		else {}
	}
}
