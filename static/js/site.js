// Tiny progressive-enhancement helpers for themes. No dependencies: scroll
// reveals plus the Markdown editor. Everything degrades to fully visible
// content. The `js` flag is set inline in the head so nothing flashes.

(function () {
	'use strict';

	function ready(fn) {
		if (document.readyState !== 'loading') {
			fn();
		} else {
			document.addEventListener('DOMContentLoaded', fn);
		}
	}

	// Collapsible menus: the sidebar nav, the dashboard menu and the admin
	// dock each hide behind a toggle on small screens. The toggles only exist
	// in the markup and only appear when this script runs, so without JS every
	// menu stays fully visible.
	function wireMenuToggle(toggleClass, scopeClass, openLabel, closedLabel) {
		var toggle = document.querySelector('.' + toggleClass);

		if (!toggle) {
			return;
		}

		var scope = toggle.closest('.' + scopeClass);

		if (!scope) {
			return;
		}

		var label = toggle.querySelector('span');

		toggle.addEventListener('click', function () {
			var open = scope.classList.toggle('is-open');

			toggle.setAttribute('aria-expanded', open ? 'true' : 'false');

			if (label) {
				label.textContent = open ? openLabel : closedLabel;
			}
		});
	}

	// Row action menus: on small screens each dashboard table row hides its
	// action buttons behind a "..." toggle. Only the toggle's click handler
	// is wired here, so without JS the buttons stay visible inline.
	function wireRowMenus() {
		var toggles = document.querySelectorAll('.row-menu-toggle');

		if (!toggles.length) {
			return;
		}

		function closeMenus(except) {
			for (var i = 0; i < toggles.length; i++) {
				var menu = toggles[i].closest('.row-menu');

				if (!menu || menu === except) {
					continue;
				}

				menu.classList.remove('is-open');
				toggles[i].setAttribute('aria-expanded', 'false');
			}
		}

		for (var i = 0; i < toggles.length; i++) {
			toggles[i].addEventListener('click', function (event) {
				event.stopPropagation();

				var menu = this.closest('.row-menu');
				var open = menu.classList.toggle('is-open');

				this.setAttribute('aria-expanded', open ? 'true' : 'false');
				closeMenus(menu);
			});
		}

		document.addEventListener('click', function () {
			closeMenus(null);
		});

		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape') {
				closeMenus(null);
			}
		});
	}

	// Pagination: on phones the page numbers fold into a pop-up menu behind a
	// "Page N of M" toggle, so a long archive never covers part of the article.
	// The toggle is created here and the pager only becomes `is-enhanced` now,
	// so without JS the numbers stay visible and the pager keeps working.
	function wirePager() {
		var pagers = document.querySelectorAll('.pagination');

		if (!pagers.length) {
			return;
		}

		function closePagers(except) {
			for (var i = 0; i < pagers.length; i++) {
				var toggle = pagers[i].querySelector('.pager-toggle');

				if (!toggle || pagers[i] === except) {
					continue;
				}

				pagers[i].classList.remove('is-open');
				toggle.setAttribute('aria-expanded', 'false');
			}
		}

		for (var i = 0; i < pagers.length; i++) {
			var pager = pagers[i];
			var list = pager.querySelector('.page_list');
			var links = list ? list.querySelectorAll('.page-link') : [];

			if (!links.length) {
				continue;
			}

			// The pager skips pages now, so the current page and the archive's
			// length come from the numbers themselves, not from the item count.
			var current = 1;
			var total = 1;

			for (var j = 0; j < links.length; j++) {
				var number = parseInt(links[j].textContent, 10);

				if (isNaN(number)) {
					continue;
				}

				total = Math.max(total, number);

				if (links[j].classList.contains('is-current') || links[j].getAttribute('aria-current') === 'page') {
					current = number;
				}
			}

			if (!list.id) {
				list.id = 'page_list';
			}

			var toggle = pager.querySelector('.pager-toggle');

			if (!toggle) {
				toggle = document.createElement('button');
				toggle.type = 'button';
				toggle.className = 'pager-toggle';
				toggle.innerHTML = '<span class="pager-toggle-text"></span>' +
					'<svg class="pager-caret" viewBox="0 0 24 24" aria-hidden="true"><path d="m6 9 6 6 6-6"></path></svg>';
				pager.insertBefore(toggle, list);
			}

			var label = toggle.querySelector('.pager-toggle-text');

			if (label) {
				label.textContent = 'Page ' + current + ' of ' + total;
			}

			toggle.setAttribute('aria-expanded', 'false');
			toggle.setAttribute('aria-controls', list.id);
			pager.classList.add('is-enhanced');

			toggle.addEventListener('click', function (event) {
				event.stopPropagation();

				var pager = this.closest('.pagination');
				var open = !pager.classList.contains('is-open');

				closePagers(open ? pager : null);
				pager.classList.toggle('is-open', open);
				this.setAttribute('aria-expanded', open ? 'true' : 'false');

				// The phone menu can scroll once an archive runs to many pages,
				// so open it on the page the reader is already on.
				if (!open) {
					return;
				}

				var active = pager.querySelector('.page-link.is-current, .page-link[aria-current="page"]');

				if (active && typeof active.scrollIntoView === 'function') {
					active.scrollIntoView({ block: 'nearest' });
				}

				if (active && typeof active.focus === 'function') {
					active.focus({ preventScroll: true });
				}
			});

			// The open menu behaves like one for the keyboard too: arrows move
			// between the page numbers, Home and End jump to the ends, and Escape
			// closes it and puts focus back on the toggle.
			toggle.addEventListener('keydown', function (event) {
				if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') {
					return;
				}

				event.preventDefault();
				this.click();
			});

			list.addEventListener('keydown', function (event) {
				var opened = this.closest('.pagination');

				if (event.key === 'Escape') {
					event.preventDefault();
					opened.classList.remove('is-open');

					var opener = opened.querySelector('.pager-toggle');

					if (opener) {
						opener.setAttribute('aria-expanded', 'false');
						opener.focus();
					}

					return;
				}

				var items = this.querySelectorAll('.page-link');

				if (!items.length) {
					return;
				}

				var index = -1;

				for (var k = 0; k < items.length; k++) {
					if (items[k] === document.activeElement) {
						index = k;
						break;
					}
				}

				var next = -1;

				if (event.key === 'ArrowDown') {
					next = index < 0 ? 0 : Math.min(items.length - 1, index + 1);
				} else if (event.key === 'ArrowUp') {
					next = index < 0 ? items.length - 1 : Math.max(0, index - 1);
				} else if (event.key === 'Home') {
					next = 0;
				} else if (event.key === 'End') {
					next = items.length - 1;
				}

				if (next < 0) {
					return;
				}

				event.preventDefault();
				items[next].focus();
			});
		}

		document.addEventListener('click', function () {
			closePagers(null);
		});

		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape') {
				closePagers(null);
			}
		});
	}

	// Back to top: a small glass button floats in the top-right corner once the
	// reader is a screen or so down the page, and takes them back up. It is
	// created here, so nothing floats over the page without JS.
	function wireToTop() {
		var button = document.createElement('button');

		button.type = 'button';
		button.className = 'to-top';
		button.setAttribute('aria-label', 'Back to top');
		button.setAttribute('title', 'Back to top');
		button.innerHTML = '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 19V5"></path><path d="m6 11 6-6 6 6"></path></svg>';
		document.body.appendChild(button);

		var shown = false;

		function update() {
			var visible = (window.pageYOffset || window.scrollY || 0) > 400;

			if (visible === shown) {
				return;
			}

			shown = visible;
			button.classList.toggle('is-visible', visible);
		}

		button.addEventListener('click', function () {
			var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

			window.scrollTo({ top: 0, left: 0, behavior: reduce ? 'auto' : 'smooth' });
		});

		window.addEventListener('scroll', update, { passive: true });

		update();
	}

	// Content images: clicking one opens it full-screen in a modal dialog,
	// with arrows through the rest of the images in that post or page. The
	// dialog and the `is-zoomable` class only exist once this runs, so without
	// JS the images behave exactly as before.
	function wireImageViewer() {
		var images = [];
		var contents = document.querySelectorAll('.post_content');

		for (var c = 0; c < contents.length; c++) {
			var found = contents[c].querySelectorAll('img');

			for (var i = 0; i < found.length; i++) {
				var image = found[i];

				// An image wrapped in a link keeps the author's link behaviour.
				if (image.closest('a') || image.classList.contains('is-zoomable')) {
					continue;
				}

				image.classList.add('is-zoomable');
				image.tabIndex = 0;
				image.setAttribute('role', 'button');
				image.setAttribute('aria-label', image.alt ? 'View image: ' + image.alt : 'View image');

				image.addEventListener('click', onImageClick);
				image.addEventListener('keydown', onImageKey);

				images.push(image);
			}
		}

		if (!images.length) {
			return;
		}

		var viewer = null;
		var viewerImage = null;
		var viewerCaption = null;
		var opener = null;
		var current = 0;
		var cleaned = true;

		// The dialog's own `close` event is not relied on for teardown (and is
		// skipped by some engines), so every path calls this once by hand.
		function cleanup() {
			if (cleaned) {
				return;
			}

			cleaned = true;
			document.body.classList.remove('has-image-viewer');

			if (opener && document.contains(opener)) {
				opener.focus();
			}

			opener = null;
		}

		function closeViewer() {
			if (!viewer || !viewer.open) {
				return;
			}

			viewer.close();
			cleanup();
		}

		function onImageClick(event) {
			event.preventDefault();
			openViewer(this);
		}

		function onImageKey(event) {
			if (event.key !== 'Enter' && event.key !== ' ') {
				return;
			}

			event.preventDefault();
			openViewer(this);
		}

		function makeButton(className, label, icon) {
			var button = document.createElement('button');

			button.type = 'button';
			button.className = className;
			button.setAttribute('aria-label', label);
			button.innerHTML = '<svg class="icon" aria-hidden="true"><use href="#i-' + icon + '"></use></svg>';

			return button;
		}

		function buildViewer() {
			var dialog = document.createElement('dialog');

			dialog.className = 'image-viewer';
			dialog.setAttribute('aria-label', 'Image viewer');

			var figure = document.createElement('figure');

			figure.className = 'image-viewer-figure';

			viewerImage = document.createElement('img');
			viewerImage.className = 'image-viewer-img';
			viewerImage.alt = '';
			viewerImage.draggable = false;

			viewerCaption = document.createElement('figcaption');
			viewerCaption.className = 'image-viewer-caption';

			figure.appendChild(viewerImage);
			figure.appendChild(viewerCaption);

			var close = makeButton('image-viewer-close', 'Close image', 'close');
			var prev = makeButton('image-viewer-prev', 'Previous image', 'arrow-left');
			var next = makeButton('image-viewer-next', 'Next image', 'arrow-right');

			close.addEventListener('click', closeViewer);

			prev.addEventListener('click', function () {
				step(-1);
			});

			next.addEventListener('click', function () {
				step(1);
			});

			dialog.appendChild(figure);
			dialog.appendChild(close);
			dialog.appendChild(prev);
			dialog.appendChild(next);

			// A click on the backdrop, or anywhere around the image, closes it.
			dialog.addEventListener('click', function (event) {
				if (event.target.closest('.image-viewer-img') || event.target.closest('button')) {
					return;
				}

				closeViewer();
			});

			// Escape closes the dialog natively; take over so the page unlocks and
			// focus returns to the image the reader came from.
			dialog.addEventListener('cancel', function (event) {
				event.preventDefault();
				closeViewer();
			});

			dialog.addEventListener('keydown', function (event) {
				if (event.key === 'ArrowLeft') {
					event.preventDefault();
					step(-1);
				} else if (event.key === 'ArrowRight') {
					event.preventDefault();
					step(1);
				}
			});

			dialog.addEventListener('close', cleanup);

			document.body.appendChild(dialog);

			return dialog;
		}

		function show(index) {
			var image = images[index];

			if (!image) {
				return;
			}

			current = index;
			viewerImage.src = image.currentSrc || image.src;
			viewerImage.alt = image.alt || '';
			viewerCaption.textContent = image.alt || '';
			viewer.classList.toggle('is-single', images.length < 2);
		}

		function step(delta) {
			show((current + delta + images.length) % images.length);
		}

		function openViewer(image) {
			var index = images.indexOf(image);

			if (index === -1) {
				return;
			}

			if (!viewer) {
				viewer = buildViewer();
			}

			if (typeof viewer.showModal !== 'function') {
				window.open(image.currentSrc || image.src, '_blank', 'noopener');
				return;
			}

			opener = image;
			cleaned = false;
			show(index);
			document.body.classList.add('has-image-viewer');
			viewer.showModal();
		}
	}

	// Settings: the page warns before a link or a closed tab throws away unsaved
	// edits, shows that reminder in the save bar, and previews the accent
	// colour in the swatch while it is typed.
	function wireSettingsForm() {
		var form = document.querySelector('.settings-form');

		if (!form) {
			return;
		}

		var savebar = document.querySelector('.settings-save');
		var dirty = savebar ? savebar.querySelector('.settings-dirty') : null;
		var accent = form.querySelector('input[name="accent_foreground"]');
		var swatch = document.querySelector('.settings-color .swatch');
		var accentBar = document.querySelector('.accent_bar');
		var changed = false;

		function markChanged() {
			changed = true;

			if (dirty) {
				dirty.hidden = false;
			}
		}

		function markSaved() {
			changed = false;

			if (dirty) {
				dirty.hidden = true;
			}
		}

		form.addEventListener('input', markChanged);
		form.addEventListener('change', markChanged);
		form.addEventListener('submit', markSaved);

		// The upload controls belong to their own forms, so an upload is a save
		// too: it should not trigger the unsaved-changes warning on the way out.
		var uploaders = document.querySelectorAll('#logo-upload, #favicon-upload');

		for (var u = 0; u < uploaders.length; u++) {
			uploaders[u].addEventListener('submit', markSaved);
		}

		if (accent) {
			accent.addEventListener('input', function () {
				var value = accent.value.trim();
				var valid = /^(#[0-9a-f]{3,8}|(rgb|rgba|hsl|hsla)\([0-9.,%\/\s+-]+\)|[a-z]+)$/i.test(value);

				accent.removeAttribute('aria-invalid');

				if (!valid) {
					accent.setAttribute('aria-invalid', 'true');
					return;
				}

				// Show the colour on the field's swatch and on the sidebar's accent
				// bar, so it can be judged before the form is saved.
				if (swatch) {
					swatch.style.background = value;
				}

				if (accentBar) {
					accentBar.style.background = value;
				}
			});
		}

		window.addEventListener('beforeunload', function (event) {
			if (!changed) {
				return;
			}

			event.preventDefault();
			event.returnValue = '';
		});
	}

	// Toasts: short confirmations in the corner after a save, and the
	// announcement that a scheduled post's time has arrived. The save toast's
	// markup is rendered by the server; this reveals it, dismisses it after a
	// few seconds and tidies the address bar so a refresh does not repeat it.
	function activateToast(toast) {
		var timer = null;

		function disarm() {
			if (timer) {
				window.clearTimeout(timer);
				timer = null;
			}
		}

		function dismiss() {
			disarm();
			toast.classList.remove('is-visible');
			window.setTimeout(function () {
				if (toast.parentNode) {
					toast.parentNode.removeChild(toast);
				}
			}, 250);
		}

		function arm() {
			disarm();
			timer = window.setTimeout(dismiss, 5000);
		}

		var close = toast.querySelector('.toast-close');

		if (close) {
			close.addEventListener('click', dismiss);
		}

		// Keep it on screen while it is read or reached by the keyboard.
		toast.addEventListener('mouseenter', disarm);
		toast.addEventListener('mouseleave', arm);
		toast.addEventListener('focusin', disarm);
		toast.addEventListener('focusout', arm);

		window.requestAnimationFrame(function () {
			toast.classList.add('is-visible');
		});
		arm();
	}

	function showToast(message, tone, href) {
		var stack = document.getElementById('toast-stack');

		if (!stack) {
			return;
		}

		var toast = document.createElement('div');
		toast.className = 'toast toast-' + (tone || 'success');
		toast.setAttribute('data-toast', '');

		var icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
		icon.setAttribute('class', 'icon');
		icon.setAttribute('aria-hidden', 'true');

		var use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
		use.setAttribute('href', tone === 'info' ? '#i-clock' : '#i-check');
		icon.appendChild(use);

		var text = document.createElement('p');
		text.className = 'toast-text';
		text.textContent = message;

		if (href) {
			var link = document.createElement('a');
			link.href = href;
			link.textContent = 'View';
			text.appendChild(document.createTextNode(' '));
			text.appendChild(link);
		}

		var close = document.createElement('button');
		close.type = 'button';
		close.className = 'toast-close';
		close.setAttribute('aria-label', 'Dismiss');
		close.innerHTML = '<svg class="icon" aria-hidden="true"><use href="#i-close"></use></svg>';

		toast.appendChild(icon);
		toast.appendChild(text);
		toast.appendChild(close);
		stack.appendChild(toast);
		activateToast(toast);
	}

	function wireToasts() {
		var stack = document.getElementById('toast-stack');

		if (!stack) {
			return;
		}

		// Only now may the stylesheet hide a toast for its entrance animation;
		// until this runs a toast is plainly visible, so a stale script can
		// never leave the confirmation invisible.
		stack.classList.add('is-wired');

		var rendered = stack.querySelectorAll('[data-toast]');

		for (var i = 0; i < rendered.length; i++) {
			activateToast(rendered[i]);
		}

		if (window.history && window.history.replaceState && window.URL) {
			var url = new URL(window.location.href);

			if (url.searchParams.has('saved')) {
				url.searchParams.delete('saved');
				url.searchParams.delete('at');
				window.history.replaceState(null, '', url.pathname + url.search + url.hash);
			}
		}

		wireScheduledToasts();
	}

	// The dashboard lists scheduled posts; each is announced as live at its
	// publish time, so the author sees it happen without reloading.
	function wireScheduledToasts() {
		var watch = document.querySelector('.toast-watch');

		if (!watch) {
			return;
		}

		var serverNow = parseInt(watch.getAttribute('data-server-now'), 10);

		if (isNaN(serverNow)) {
			return;
		}

		var loadedAt = Date.now();
		var items = watch.querySelectorAll('[data-publish-at]');

		for (var i = 0; i < items.length; i++) {
			var at = parseInt(items[i].getAttribute('data-publish-at'), 10);

			if (isNaN(at)) {
				continue;
			}

			var delay = at * 1000 - (serverNow * 1000 + (Date.now() - loadedAt));

			// setTimeout cannot wait longer than about 24.8 days; anything
			// further out is simply picked up on the next visit.
			if (delay > 2147483000) {
				continue;
			}

			window.setTimeout((function (item) {
				return function () {
					var title = item.getAttribute('data-title') || 'A scheduled post';
					showToast('“' + title + '” is live now.', 'live', item.getAttribute('data-href'));
				};
			})(items[i]), Math.max(0, delay));
		}
	}

	ready(function () {
		wireMenuToggle('site-menu-toggle', 'site-brand', 'Close', 'Menu');
		wireMenuToggle('dash-menu-toggle', 'dash-nav', 'Close', 'Menu');
		wireMenuToggle('admin-bar-toggle', 'admin-bar', 'Close', 'Admin');
		wireRowMenus();
		wirePager();
		wireToTop();
		wireImageViewer();

		wireSettingsForm();
		wireToasts();

		// Markdown editor for posts and pages (EasyMDE, vendored locally).
		var markdownFields = document.querySelectorAll('textarea[data-markdown]');

		if (markdownFields.length && window.EasyMDE) {
			var wide = window.matchMedia('(min-width: 62em)').matches;

			for (var m = 0; m < markdownFields.length; m++) {
				var mde = new EasyMDE({
					element: markdownFields[m],
					autoDownloadFontAwesome: false,
					spellChecker: false,
					forceSync: true,
					lineWrapping: true,
					minHeight: '30rem',
					placeholder: markdownFields[m].getAttribute('placeholder') || 'Write in Markdown...',
					status: ['words', 'lines'],
					sideBySideFullscreen: false,
					syncSideBySidePreviewScroll: true,
					// Match the server's Markdown: a single newline is a space, not a <br>.
					renderingConfig: { singleLineBreaks: false },
					toolbar: ['bold', 'italic', 'heading', '|', 'quote', 'unordered-list', 'ordered-list', '|', 'link', 'image', 'code', 'table', '|', 'side-by-side']
				});

				// Dock the live preview on the right where there is room for it;
				// on phones the toolbar toggle opens it instead of squeezing both.
				if (wide) {
					mde.toggleSideBySide();
				}
			}

			// Ctrl/⌘ + S saves the post or page instead of the browser dialog.
			document.addEventListener('keydown', function (event) {
				if (!(event.metaKey || event.ctrlKey) || !event.key || event.key.toLowerCase() !== 's') {
					return;
				}

				var form = event.target && event.target.closest ? event.target.closest('form.editor-form') : null;

				if (!form) {
					return;
				}

				event.preventDefault();

				if (typeof form.requestSubmit === 'function') {
					form.requestSubmit();
				} else {
					form.submit();
				}
			}, true);
		}

		var reveal = document.querySelectorAll('.reveal');

		if (!('IntersectionObserver' in window)) {
			for (var i = 0; i < reveal.length; i++) {
				reveal[i].classList.add('is-visible');
			}
			return;
		}

		// Any visible sliver counts: a single post shown in full is taller than
		// the screen, so a ratio threshold would keep it hidden until the reader
		// scrolled. The bottom root margin still delays the fade a little.
		var observer = new IntersectionObserver(function (entries) {
			for (var i = 0; i < entries.length; i++) {
				if (entries[i].isIntersecting) {
					entries[i].target.classList.add('is-visible');
					observer.unobserve(entries[i].target);
				}
			}
		}, { rootMargin: '0px 0px -8% 0px', threshold: 0 });

		for (var j = 0; j < reveal.length; j++) {
			observer.observe(reveal[j]);
		}
	});
})();
