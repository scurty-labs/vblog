// Media library helpers: drag-and-drop uploads, the image lightbox, copy-link
// buttons and the per-file details dialogs. Without JS everything falls back
// to the plain upload form and the file links.

(function () {
	'use strict';

	function ready(fn) {
		if (document.readyState !== 'loading') {
			fn();
		} else {
			document.addEventListener('DOMContentLoaded', fn);
		}
	}

	function formatBytes(bytes) {
		if (bytes < 1024) {
			return bytes + ' B';
		}
		var units = ['KB', 'MB', 'GB'];
		var value = bytes;
		var unit = -1;
		do {
			value /= 1024;
			unit++;
		} while (value >= 1024 && unit < units.length - 1);
		return value.toFixed(value >= 10 ? 0 : 1) + ' ' + units[unit];
	}

	function toast(message) {
		var element = document.getElementById('media-toast');
		if (!element) {
			return;
		}
		element.textContent = message;
		element.hidden = false;
		clearTimeout(toast.timer);
		toast.timer = setTimeout(function () {
			element.hidden = true;
		}, 1800);
	}

	function copyText(text) {
		if (navigator.clipboard && window.isSecureContext) {
			return navigator.clipboard.writeText(text);
		}
		return new Promise(function (resolve, reject) {
			var area = document.createElement('textarea');
			area.value = text;
			area.setAttribute('readonly', '');
			area.style.position = 'fixed';
			area.style.opacity = '0';
			document.body.appendChild(area);
			area.select();
			try {
				document.execCommand('copy');
				resolve();
			} catch (error) {
				reject(error);
			}
			document.body.removeChild(area);
		});
	}

	ready(function () {
		var drop = document.getElementById('media-drop');
		var input = document.getElementById('media_files');
		var form = drop ? drop.closest('form') : null;
		var selection = document.getElementById('media-selection');
		var uploadLabel = document.getElementById('media-upload-label');

		function describe(files) {
			if (!selection) {
				return;
			}
			if (!files || !files.length) {
				selection.hidden = true;
				selection.textContent = '';
				return;
			}
			var total = 0;
			for (var i = 0; i < files.length; i++) {
				total += files[i].size;
			}
			selection.hidden = false;
			selection.textContent = files.length + (files.length === 1 ? ' file · ' : ' files · ') + formatBytes(total);
		}

		if (input) {
			input.addEventListener('change', function () {
				describe(input.files);
			});
		}

		if (drop && input && form) {
			['dragenter', 'dragover'].forEach(function (name) {
				drop.addEventListener(name, function (event) {
					event.preventDefault();
					drop.classList.add('is-dragging');
				});
			});
			['dragleave', 'dragend', 'drop'].forEach(function (name) {
				drop.addEventListener(name, function () {
					drop.classList.remove('is-dragging');
				});
			});
			drop.addEventListener('drop', function (event) {
				event.preventDefault();
				if (!event.dataTransfer || !event.dataTransfer.files.length) {
					return;
				}
				input.files = event.dataTransfer.files;
				describe(input.files);
				drop.classList.add('is-uploading');
				if (uploadLabel) {
					uploadLabel.textContent = 'Uploading…';
				}
				form.submit();
			});
			form.addEventListener('submit', function () {
				if (input.files && input.files.length && uploadLabel) {
					uploadLabel.textContent = 'Uploading…';
				}
			});
		}

		var lightbox = document.getElementById('media-lightbox');
		var lightboxImage = document.getElementById('media-lightbox-image');

		function closeLightbox() {
			if (!lightbox || !lightboxImage) {
				return;
			}
			lightbox.hidden = true;
			lightboxImage.src = '';
		}

		document.addEventListener('click', function (event) {
			var target = event.target;
			if (!target || !target.closest) {
				return;
			}

			var opener = target.closest('[data-dialog]');
			if (opener) {
				var dialog = document.getElementById(opener.getAttribute('data-dialog'));
				if (dialog && typeof dialog.showModal === 'function') {
					event.preventDefault();
					dialog.showModal();
				}
				return;
			}

			var closer = target.closest('[data-close]');
			if (closer) {
				var owner = closer.closest('dialog');
				if (owner) {
					event.preventDefault();
					owner.close();
				}
				return;
			}

			var copyButton = target.closest('[data-copy]');
			if (copyButton) {
				event.preventDefault();
				var link = new URL(copyButton.getAttribute('data-copy'), window.location.origin).href;
				copyText(link).then(function () {
					toast('Link copied');
				}, function () {
					toast('Copy failed — open File details to select the URL');
				});
				return;
			}

			var preview = target.closest('[data-preview]');
			if (preview && lightbox && lightboxImage) {
				event.preventDefault();
				lightboxImage.src = preview.getAttribute('data-preview');
				lightboxImage.alt = preview.getAttribute('data-preview-alt') || '';
				lightbox.hidden = false;
			}
		});

		if (lightbox) {
			lightbox.addEventListener('click', function (event) {
				if (event.target === lightbox || (event.target.closest && event.target.closest('[data-lightbox-close]'))) {
					closeLightbox();
				}
			});
		}

		document.addEventListener('keydown', function (event) {
			if (event.key === 'Escape') {
				closeLightbox();
			}
		});

		var dialogs = document.querySelectorAll('dialog.media-dialog');
		for (var i = 0; i < dialogs.length; i++) {
			dialogs[i].addEventListener('click', function (event) {
				if (event.target === this) {
					this.close();
				}
			});
		}
	});
})();
