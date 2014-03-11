/* Load this script using conditional IE comments if you need to support IE 7 and IE 6. */

window.onload = function() {
	function addIcon(el, entity) {
		var html = el.innerHTML;
		el.innerHTML = '<span style="font-family: \'icomoon\'">' + entity + '</span>' + html;
	}
	var icons = {
			'icon-play' : '&#xe000;',
			'icon-close' : '&#xe002;',
			'icon-plus' : '&#xe003;',
			'icon-minus' : '&#xe004;',
			'icon-menu' : '&#xe005;',
			'icon-forward' : '&#xe006;',
			'icon-share' : '&#xe007;',
			'icon-console' : '&#xe008;',
			'icon-paragraph-center' : '&#xe009;',
			'icon-paragraph-left' : '&#xe00a;',
			'icon-paragraph-right' : '&#xe00b;',
			'icon-paragraph-justify' : '&#xe00c;',
			'icon-filter' : '&#xe00d;',
			'icon-filter-2' : '&#xe00e;',
			'icon-radio-checked' : '&#xe00f;',
			'icon-radio-unchecked' : '&#xe010;',
			'icon-volume-high' : '&#xe011;',
			'icon-volume-medium' : '&#xe012;',
			'icon-volume-low' : '&#xe013;',
			'icon-last' : '&#xe014;',
			'icon-volume-mute' : '&#xe015;',
			'icon-volume-mute-2' : '&#xe016;',
			'icon-cog' : '&#xe017;',
			'icon-bubble' : '&#xe018;',
			'icon-cancel-circle' : '&#xe001;',
			'icon-pause' : '&#xe019;',
			'icon-pause-2' : '&#xe01a;'
		},
		els = document.getElementsByTagName('*'),
		i, attr, html, c, el;
	for (i = 0; ; i += 1) {
		el = els[i];
		if(!el) {
			break;
		}
		attr = el.getAttribute('data-icon');
		if (attr) {
			addIcon(el, attr);
		}
		c = el.className;
		c = c.match(/icon-[^\s'"]+/);
		if (c && icons[c[0]]) {
			addIcon(el, icons[c[0]]);
		}
	}
};