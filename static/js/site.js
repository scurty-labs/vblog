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

	ready(function () {
		wireMenuToggle('site-menu-toggle', 'site-brand', 'Close', 'Menu');
		wireMenuToggle('dash-menu-toggle', 'dash-nav', 'Close', 'Menu');
		wireMenuToggle('admin-bar-toggle', 'admin-bar', 'Close', 'Admin');

		// Theme picker: choosing a theme applies it right away instead of
		// waiting for the Save button. Without JS the form still saves normally.
		var themePicker = document.querySelector('select[name="theme"]');

		if (themePicker && themePicker.form) {
			themePicker.addEventListener('change', function () {
				themePicker.form.submit();
			});
		}

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

		var observer = new IntersectionObserver(function (entries) {
			for (var i = 0; i < entries.length; i++) {
				if (entries[i].isIntersecting) {
					entries[i].target.classList.add('is-visible');
					observer.unobserve(entries[i].target);
				}
			}
		}, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

		for (var j = 0; j < reveal.length; j++) {
			observer.observe(reveal[j]);
		}
	});
})();
