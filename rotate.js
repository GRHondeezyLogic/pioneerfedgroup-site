// Rotating highlight word — builds stacked spans from data-rotate JSON,
// cycles with a fade/rise. Static first word when reduced motion is set.
document.querySelectorAll('.rotator').forEach(function (el) {
  var words;
  try { words = JSON.parse(el.getAttribute('data-rotate') || '[]'); }
  catch (e) { return; }
  if (!words.length) return;

  el.textContent = '';
  var spans = words.map(function (w, i) {
    var s = document.createElement('span');
    s.textContent = w;
    if (i === 0) s.className = 'on';
    el.appendChild(s);
    return s;
  });

  if (words.length < 2) return;
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  var i = 0;
  setInterval(function () {
    spans[i].classList.remove('on');
    i = (i + 1) % spans.length;
    spans[i].classList.add('on');
  }, 2600);
});

// Scroll reveal — cards and panels rise in as they enter the viewport.
(function () {
  var els = document.querySelectorAll('.card, .value, .cert-card, .person, .mark-panel, .sam-panel, .data-block, .contact-card');
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
