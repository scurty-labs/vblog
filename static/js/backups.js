// Backups page: opens the per-backup restore confirmation dialog. Without JS
// nothing opens, so a restore never happens by accident.

(function () {
	'use strict';

	function ready(fn) {
		if (document.readyState !== 'loading') {
			fn();
		} else {
			document.addEventListener('DOMContentLoaded', fn);
		}
	}

	ready(function () {
		var dialogs = document.querySelectorAll('dialog.backup-dialog');

		if (!dialogs.length) {
			return;
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
			}
		});

		for (var i = 0; i < dialogs.length; i++) {
			dialogs[i].addEventListener('click', function (event) {
				if (event.target === this) {
					this.close();
				}
			});

			dialogs[i].addEventListener('cancel', function (event) {
				event.preventDefault();
				this.close();
			});
		}
	});
})();
