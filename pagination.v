module main

// page_links is the numbered list the pager renders: the first and last pages,
// a window around the current one, and a 0 wherever pages were skipped. Keeping
// the list short means the combo box stays a menu instead of a scroll of every
// page an archive has ever had.
fn page_links(current int, total int) []int {
	mut links := []int{}
	if total <= 0 {
		return links
	}
	page_now := if current < 1 {
		1
	} else if current > total {
		total
	} else {
		current
	}
	mut last := 0
	for page := 1; page <= total; page++ {
		near := page <= 2 || page > total - 2 || (page >= page_now - 2 && page <= page_now + 2)
		if !near {
			continue
		}
		if last > 0 && page > last + 1 {
			links << 0
		}
		links << page
		last = page
	}
	return links
}
