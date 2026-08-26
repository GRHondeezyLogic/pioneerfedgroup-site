// ─────────────────────────────────────────────────────────────────────────────
//  PIONEER FEDERAL GROUP — shared shader wallpaper driver
//  Each page picks a scene via <body data-scene="…">:
//    "scroll" (home) — the four worlds cross-fade with page scroll
//    "0".."3"        — one world holds for the whole page
//  No WebGPU → the CSS navy gradient underneath simply stays. No dead ends.
// ─────────────────────────────────────────────────────────────────────────────

import { Renderer } from './gpu.js';

const REDUCED = matchMedia('(prefers-reduced-motion: reduce)').matches;
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);

const mode = document.body.dataset.scene || '0';
const fixedIdx = Math.max(0, Math.min(3, parseInt(mode, 10) || 0));

const state = {
  time: 0, frame: 0,
  sceneF: fixedIdx, blend: 0, idxA: fixedIdx, idxB: fixedIdx,
  progress: 0, velocity: 0,
  mx: 0, my: 0, smx: 0, smy: 0,
  dim: 1, shift: 0, shiftY: 0,
  progs: [0.5, 0.5, 0.5, 0.5],
};

function fallback(err) {
  console.warn('Shader wallpaper unavailable, static brand background stays:', err && (err.message || err));
  document.body.classList.remove('is-live');
  document.body.classList.add('no-webgpu');
}

function sampleScroll() {
  if (mode !== 'scroll' || REDUCED) return;
  const doc = document.documentElement.scrollHeight - innerHeight;
  const frac = clamp01(scrollY / Math.max(1, doc)) * 3;
  const a = Math.min(2, Math.floor(frac));
  state.idxA = a;
  state.idxB = Math.min(3, a + 1);
  state.blend = clamp01(frac - a);
  state.sceneF = frac;
}

async function start() {
  const canvas = document.getElementById('stage');
  if (!canvas) return;
  const renderer = new Renderer(canvas);

  try {
    await renderer.init();
    renderer.render(state, 1 / 60);
    await Promise.race([
      renderer.device.queue.onSubmittedWorkDone(),
      new Promise((_, rej) => setTimeout(() => rej(new Error('GPU warm-up timed out')), 9000)),
    ]);
  } catch (err) {
    fallback(err);
    return;
  }

  renderer.device.lost.then(() => fallback(new Error('GPU device lost')));

  document.body.classList.add('is-live');
  addEventListener('scroll', sampleScroll, { passive: true });
  addEventListener('pointermove', (e) => {
    state.mx = (e.clientX / innerWidth) * 2 - 1;
    state.my = (e.clientY / innerHeight) * 2 - 1;
  }, { passive: true });

  let prev = performance.now();
  const frame = (now) => {
    requestAnimationFrame(frame);
    const dt = Math.min((now - prev) / 1000, 0.05);
    prev = now;
    state.time += REDUCED ? dt * 0.3 : dt;
    state.frame++;
    const k = 1 - Math.pow(0.001, dt);
    state.smx = lerp(state.smx, state.mx, k);
    state.smy = lerp(state.smy, state.my, k);
    // on the home page push the subject right so the hero text owns the left
    const wide = innerWidth > 900;
    state.shift = lerp(state.shift, wide && mode === 'scroll' ? 0.3 : 0, k);
    state.shiftY = lerp(state.shiftY, wide ? 0 : 0.35, k);
    renderer.render(state, dt);
  };
  addEventListener('resize', () => renderer.resize());
  sampleScroll();
  requestAnimationFrame(frame);
}

// mobile nav toggle (same hook as the live site)
document.querySelectorAll('.nav-toggle').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelector('.nav-links')?.classList.toggle('open');
  });
});

start();
