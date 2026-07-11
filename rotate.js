// Rotating highlight word — words are stacked in one grid cell so the line
// never reflows. Each incoming word cascades in letter by letter, then a
// gold underline sweeps beneath it. Static first word under reduced motion.
document.querySelectorAll('.rotator').forEach(function (el) {
  var words;
  try { words = JSON.parse(el.getAttribute('data-rotate') || '[]'); }
  catch (e) { return; }
  if (!words.length) return;

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  el.textContent = '';

  var spans = words.map(function (w, i) {
    var s = document.createElement('span');
    if (reduced) {
      s.textContent = w;
    } else {
      w.split('').forEach(function (c, j) {
        var ch = document.createElement('i');
        ch.className = 'ch';
        ch.textContent = c === ' ' ? ' ' : c;
        ch.style.transitionDelay = (j * 28) + 'ms';
        s.appendChild(ch);
      });
    }
    if (i === 0) s.className = 'on';
    el.appendChild(s);
    return s;
  });

  if (words.length < 2 || reduced) return;
  var i = 0;
  setInterval(function () {
    spans[i].classList.remove('on');
    i = (i + 1) % spans.length;
    spans[i].classList.add('on');
  }, 3000);
});

// Scroll reveal — cards and panels rise in as they enter the viewport.
(function () {
  var els = document.querySelectorAll('.card, .value, .cert-card, .person, .mark-panel, .sam-panel, .data-block, .contact-card, .quote-band');
  if (!('IntersectionObserver' in window) ||
      window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  els.forEach(function (el) { el.classList.add('reveal'); });
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (en.isIntersecting) { en.target.classList.add('in'); io.unobserve(en.target); }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
  els.forEach(function (el) { io.observe(el); });
})();
