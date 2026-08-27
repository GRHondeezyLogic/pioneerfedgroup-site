// ─────────────────────────────────────────────────────────────────────────────
//  PIONEER FEDERAL GROUP — raymarched wallpaper, four worlds
//  0 event horizon · 1 nebula forge · 2 open water · 3 granite frontier
// ─────────────────────────────────────────────────────────────────────────────

struct U {
  res       : vec4f,  // w, h, 1/w, 1/h
  timing    : vec4f,  // time, dt, frame, —
  scene     : vec4f,  // sceneF, blend, idxA, idxB
  scroll    : vec4f,  // progress, velocity, —, —
  pointer   : vec4f,  // mx, my, smx, smy
  grade     : vec4f,  // dim, quality, shiftY, shiftX
  progs     : vec4f,  // per-scene scroll progress 0..1 ×4
};
@group(0) @binding(0) var<uniform> u : U;

// ── small utils ──────────────────────────────────────────────────────────────

const PI  = 3.14159265359;
const TAU = 6.28318530718;

fn hash11(p: f32) -> f32 { return fract(sin(p * 127.1) * 43758.5453); }
fn hash13(p: vec3f) -> f32 {
  var q = fract(p * 0.1031);
  q += dot(q, q.zyx + 31.32);
  return fract((q.x + q.y) * q.z);
}
fn hash12(p: vec2f) -> f32 {
  var q = fract(vec3f(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

fn vnoise3(p: vec3f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let w = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(hash13(i + vec3f(0,0,0)), hash13(i + vec3f(1,0,0)), w.x),
        mix(hash13(i + vec3f(0,1,0)), hash13(i + vec3f(1,1,0)), w.x), w.y),
    mix(mix(hash13(i + vec3f(0,0,1)), hash13(i + vec3f(1,0,1)), w.x),
        mix(hash13(i + vec3f(0,1,1)), hash13(i + vec3f(1,1,1)), w.x), w.y),
    w.z);
}

fn fbm3(p0: vec3f, oct: i32) -> f32 {
  var p = p0;
  var a = 0.5;
  var s = 0.0;
  for (var i = 0; i < 8; i++) {
    if (i >= oct) { break; }
    s += a * vnoise3(p);
    p = p * 2.13 + vec3f(11.5, 7.3, 5.1);
    a *= 0.5;
  }
  return s;
}

fn vnoise2(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let w = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash12(i), hash12(i + vec2f(1, 0)), w.x),
             mix(hash12(i + vec2f(0, 1)), hash12(i + vec2f(1, 1)), w.x), w.y);
}

fn fbm2(p0: vec2f, oct: i32) -> f32 {
  var p = p0;
  var a = 0.5;
  var s = 0.0;
  for (var i = 0; i < 6; i++) {
    if (i >= oct) { break; }
    s += a * vnoise2(p);
    p = p * 2.17 + vec2f(9.2, 3.7);
    a *= 0.5;
  }
  return s;
}

// steps from quality: 1 → hi, 0 → lo
fn steps(lo: f32, hi: f32) -> i32 {
  return i32(mix(lo, hi, clamp(u.grade.y, 0.0, 1.0)) + 0.5);
}

fn rotY(p: vec3f, a: f32) -> vec3f {
  let c = cos(a); let s = sin(a);
  return vec3f(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}
fn rotX(p: vec3f, a: f32) -> vec3f {
  let c = cos(a); let s = sin(a);
  return vec3f(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

// ── palette (site brand) ─────────────────────────────────────────────────────
// navy  #0C2340 · paper #F5F2EA · gold #C9A84C · ice #9FC3E0

const NAVY  = vec3f(0.047, 0.137, 0.251);
const NAVY2 = vec3f(0.016, 0.039, 0.078);
const PAPER = vec3f(0.961, 0.949, 0.918);
const GOLD  = vec3f(0.788, 0.659, 0.298);
const ICE   = vec3f(0.624, 0.765, 0.878);

// ════════════════════════════════════════════════════════════════════════════
//  SCENE 0 — EVENT HORIZON
//  A Schwarzschild black hole with a thin accretion disk, starfield behind.
//  Light bends: the ray direction deflects near the photon sphere.
// ════════════════════════════════════════════════════════════════════════════

fn stars(rd: vec3f, t: f32) -> vec3f {
  var col = vec3f(0.0);
  // two layers of cell stars
  for (var L = 0; L < 2; L++) {
    let sc = 60.0 + f32(L) * 40.0;
    let p = rd * sc;
    let id = floor(p);
    let h = hash13(id + f32(L) * 17.0);
    if (h > 0.92) {
      let fr = fract(p) - 0.5;
      let d = length(fr);
      let tw = 0.75 + 0.25 * sin(t * (1.0 + h * 3.0) + h * 40.0);
      let star = smoothstep(0.28, 0.0, d) * (h - 0.92) * 12.5 * tw;
      let tint = mix(PAPER, ICE, hash13(id + 3.7));
      col += star * tint;
    }
  }
  return col;
}

fn diskColor(p: vec3f, t: f32) -> vec4f {
  // thin disk in the xz plane at |r| in [1.9, 5.2]
  let r = length(p.xz);
  if (r < 1.9 || r > 5.2) { return vec4f(0.0); }
  let ang = atan2(p.z, p.x);
  // differential rotation: inner orbits faster
  let swirl = ang - t * 2.2 / pow(r, 1.5);
  let band = fbm3(vec3f(cos(swirl), sin(swirl), r * 2.0) * vec3f(3.0, 3.0, 1.4) + vec3f(0.0, 0.0, t * 0.15), 5);
  let edge = smoothstep(1.9, 2.6, r) * smoothstep(5.2, 3.4, r);
  let heat = smoothstep(5.2, 2.0, r);            // hotter toward the hole
  var col = mix(GOLD * 0.7, PAPER * 1.5, heat);  // gold rim → white-hot inner
  col = mix(col, ICE * 0.8, band * 0.35);
  let dens = edge * (0.35 + 0.65 * band);
  return vec4f(col * dens, dens);
}

fn scene0(ro0: vec3f, rd0: vec3f, t: f32) -> vec3f {
  // camera outside, looking slightly down at the hole at origin
  var ro = ro0 + vec3f(0.0, 0.6, -7.5);
  var rd = rd0;
  rd = rotX(rd, -0.16);

  var col = vec3f(0.0);
  var trans = 1.0;
  var pos = ro;
  var dir = rd;
  var glow = 0.0;

  let n = steps(60.0, 90.0);
  let dt0 = 0.16;
  for (var i = 0; i < 200; i++) {
    if (i >= n) { break; }
    let r2 = dot(pos, pos);
    let r = sqrt(r2);
    if (r < 0.85) { trans = 0.0; break; }        // captured
    // gravitational deflection ~ 1/r^2, adaptive step
    let defl = 0.055 / max(r2, 0.9);
    dir = normalize(dir - pos * defl);
    let st = dt0 * clamp(r * 0.5, 0.5, 2.0);
    pos += dir * st;
    // photon-sphere glow
    glow += 0.012 / (abs(r - 1.5) * 14.0 + 1.0);
    // cross the disk plane
    if (abs(pos.y) < 0.09) {
      let d = diskColor(pos, t);
      col += d.rgb * d.a * trans * 0.55;
      trans *= 1.0 - d.a * 0.5;
      if (trans < 0.02) { break; }
    }
    if (r > 26.0) { break; }
  }

  // bent starfield + faint navy haze
  col += stars(dir, t) * trans * 0.85;
  col += NAVY2 * (0.35 + 0.2 * fbm3(dir * 3.0 + t * 0.02, 3)) * trans;
  col += PAPER * glow * trans * 0.9;             // white photon ring
  col += GOLD * glow * 0.35;                     // gold fringe
  return col;
}

// ════════════════════════════════════════════════════════════════════════════
//  SCENE 1 — NEBULA FORGE
//  A dense navy/emission nebula: fbm density march with gold core lighting.
// ════════════════════════════════════════════════════════════════════════════

fn nebDensity(p: vec3f, t: f32) -> f32 {
  var q = p;
  q += 0.35 * vec3f(
    fbm3(p * 0.8 + vec3f(0.0, 0.0, t * 0.05), 4) - 0.5,
    fbm3(p * 0.8 + vec3f(4.7, 1.3, t * 0.04), 4) - 0.5,
    fbm3(p * 0.8 + vec3f(9.1, 2.6, t * 0.06), 4) - 0.5);
  let d = fbm3(q * 1.1 + vec3f(0.0, 0.0, t * 0.03), 5);
  let core = exp(-dot(p, p) * 0.55);
  return clamp(d * 1.35 - 0.42, 0.0, 1.0) * (0.35 + 1.4 * core);
}

fn scene1(ro0: vec3f, rd0: vec3f, t: f32) -> vec3f {
  var ro = ro0 + vec3f(0.0, 0.0, -4.2);
  var rd = rd0;

  var col = NAVY2 * 0.5 + stars(rd, t) * 0.5;
  var trans = 1.0;

  let n = steps(30.0, 44.0);
  let st = 6.0 / f32(n);
  let jitter = hash12(u.res.xy * 0.0 + vec2f(u.timing.z * 0.618, u.timing.z * 0.318));
  var dist = 1.2 + st * (jitter + hash13(vec3f(rd.xy * 90.0, u.timing.z)) * 0.5);

  for (var i = 0; i < 90; i++) {
    if (i >= n) { break; }
    let p = ro + rd * dist;
    let dens = nebDensity(p, t);
    if (dens > 0.01) {
      let core = exp(-dot(p, p) * 0.5);
      // emission: gold at the forge heart, ice in the mid shell, navy far out
      var emit = GOLD * core * 1.6 + ICE * exp(-dot(p, p) * 0.22) * 0.5 + NAVY * 0.35;
      let a = clamp(dens * 1.9 * st, 0.0, 1.0);
      col += emit * a * trans * dens;
      trans *= 1.0 - a * 0.85;
      if (trans < 0.03) { break; }
    }
    dist += st;
  }
  // bright star at the heart
  let coreGlow = exp(-8.0 * acos(clamp(dot(rd, normalize(vec3f(0.0, 0.05, -1.0) - ro0) * 0.0 + normalize(-ro), -1.0, 1.0))));
  col += (GOLD * 1.2 + PAPER * 0.6) * coreGlow * trans * 0.8;
  return col;
}

// ════════════════════════════════════════════════════════════════════════════
//  SCENE 2 — OPEN WATER
//  Raymarched ocean swell, low sun, gold glitter path, horizon haze.
// ════════════════════════════════════════════════════════════════════════════

fn waveH(p: vec2f, t: f32) -> f32 {
  var h = 0.0;
  h += sin(p.x * 0.32 + t * 0.9) * 0.42;
  h += sin(dot(p, vec2f(0.24, 0.31)) + t * 1.24) * 0.30;
  h += sin(dot(p, vec2f(-0.18, 0.42)) + t * 1.71) * 0.18;
  h += (fbm2(p * 0.55 + vec2f(t * 0.22, t * 0.13), 4) - 0.5) * 0.55;
  return h;
}

fn scene2(ro0: vec3f, rd0: vec3f, t: f32) -> vec3f {
  var ro = ro0 + vec3f(0.0, 2.1, -6.0);
  var rd = rotX(rd0, -0.05);

  let sunDir = normalize(vec3f(0.35, 0.16, 1.0));

  // sky
  let sd = clamp(dot(rd, sunDir), 0.0, 1.0);
  var sky = mix(NAVY * 0.9, NAVY2, clamp(rd.y * 2.2 + 0.25, 0.0, 1.0));
  sky += GOLD * pow(sd, 6.0) * 0.55;             // warm haze near the sun
  sky += PAPER * pow(sd, 90.0) * 1.4;            // sun disc glow
  sky += ICE * pow(clamp(rd.y, 0.0, 1.0), 2.0) * 0.12;
  // slow clouds
  if (rd.y > 0.02) {
    let cuv = rd.xz / (rd.y + 0.12);
    let cl = fbm2(cuv * 0.8 + vec2f(t * 0.015, 0.0), 5);
    sky = mix(sky, mix(NAVY, PAPER, 0.35), smoothstep(0.55, 0.85, cl) * 0.35 * smoothstep(0.02, 0.2, rd.y));
  }

  if (rd.y >= -0.005) { return sky; }

  // march the heightfield
  var col = sky;
  var tcur = (ro.y - 2.2) / max(-rd.y, 0.02) * 0.4;
  var hit = false;
  var p = ro;
  let n = steps(45.0, 70.0);
  for (var i = 0; i < 160; i++) {
    if (i >= n) { break; }
    p = ro + rd * tcur;
    let h = waveH(p.xz, t);
    let dh = p.y - h;
    if (dh < 0.02) { hit = true; break; }
    tcur += clamp(dh * 0.55, 0.06, 2.4);
    if (tcur > 160.0) { break; }
  }
  if (hit) {
    let e = 0.12;
    let hx = waveH(p.xz + vec2f(e, 0.0), t) - waveH(p.xz - vec2f(e, 0.0), t);
    let hz = waveH(p.xz + vec2f(0.0, e), t) - waveH(p.xz - vec2f(0.0, e), t);
    let nrm = normalize(vec3f(-hx, 2.0 * e, -hz));
    let fres = pow(1.0 - clamp(dot(-rd, nrm), 0.0, 1.0), 5.0);
    // deep navy water, sky reflection by fresnel
    var wcol = mix(NAVY2 * 0.8, NAVY * 1.15, clamp(nrm.y, 0.0, 1.0));
    wcol = mix(wcol, sky, clamp(fres * 0.85 + 0.08, 0.0, 1.0));
    // gold glitter path
    let refl = reflect(rd, nrm);
    let glit = pow(clamp(dot(refl, sunDir), 0.0, 1.0), 240.0);
    let sparkle = hash12(floor(p.xz * 14.0) + floor(t * 7.0));
    wcol += GOLD * glit * (2.2 + sparkle * 2.0);
    wcol += PAPER * pow(clamp(dot(refl, sunDir), 0.0, 1.0), 24.0) * 0.18;
    // foam on crests
    let crest = smoothstep(0.55, 0.95, waveH(p.xz, t));
    wcol = mix(wcol, PAPER * 0.75, crest * 0.22 * fbm2(p.xz * 2.6 + t * 0.35, 3));
    // distance haze into the horizon
    col = mix(wcol, sky, clamp(1.0 - exp(-tcur * 0.016), 0.0, 1.0));
  }
  return col;
}

// ════════════════════════════════════════════════════════════════════════════
//  SCENE 3 — GRANITE FRONTIER
//  Ridged-fbm mountain field, snow line, dawn sun, drifting mist.
// ════════════════════════════════════════════════════════════════════════════

fn ridge(x: f32) -> f32 { return 1.0 - abs(2.0 * x - 1.0); }

fn terrainH(p: vec2f) -> f32 {
  var a = 0.55;
  var s = 0.0;
  var q = p * 0.16;
  for (var i = 0; i < 5; i++) {
    let v = ridge(vnoise2(q));
    s += v * v * a;
    q = q * 2.11 + vec2f(13.7, 7.9);
    a *= 0.52;
  }
  return s * 7.0;
}

fn scene3(ro0: vec3f, rd0: vec3f, t: f32) -> vec3f {
  var ro = ro0 + vec3f(0.0, 4.6, -9.0);
  var rd = rotX(rd0, -0.10);

  let sunDir = normalize(vec3f(-0.45, 0.30, 1.0));

  // dawn sky: navy zenith to warm horizon
  let sd = clamp(dot(rd, sunDir), 0.0, 1.0);
  var sky = mix(mix(GOLD * 0.55 + NAVY * 0.6, NAVY, 0.45), NAVY2, clamp(rd.y * 1.9 + 0.1, 0.0, 1.0));
  sky += GOLD * pow(sd, 5.0) * 0.8;
  sky += PAPER * pow(sd, 70.0) * 1.6;

  if (rd.y >= 0.0 && ro.y > terrainH(ro.xz) + 0.4) {
    // still may hit farther peaks if looking slightly down only; cheap out
    if (rd.y > 0.02) { return sky; }
  }

  var col = sky;
  var tcur = 0.3;
  var hit = false;
  var p = ro;
  let nSky = steps(18.0, 32.0);
  for (var i = 0; i < 220; i++) {
    if (i >= 220) { break; }
    p = ro + rd * tcur;
    let dh = p.y - terrainH(p.xz);
    if (dh < 0.03) { hit = true; break; }
    tcur += clamp(dh * 0.5, 0.08, 3.0);
    if (tcur > 220.0) { break; }
  }

  if (hit) {
    let e = 0.22;
    let hx = terrainH(p.xz + vec2f(e, 0.0)) - terrainH(p.xz - vec2f(e, 0.0));
    let hz = terrainH(p.xz + vec2f(0.0, e)) - terrainH(p.xz - vec2f(0.0, e));
    let nrm = normalize(vec3f(-hx, 2.0 * e, -hz));
    let lam = clamp(dot(nrm, sunDir), 0.0, 1.0);

    // granite → snow by altitude and slope
    let snowLine = 3.1 + fbm2(p.xz * 0.4, 3) * 1.4;
    let snow = smoothstep(snowLine, snowLine + 1.2, p.y) * smoothstep(0.35, 0.75, nrm.y);
    var mcol = mix(vec3f(0.10, 0.12, 0.16), PAPER * 0.95, snow);
    // granite strata banding
    mcol *= 0.85 + 0.15 * sin(p.y * 3.1 + fbm2(p.xz * 0.8, 3) * 4.0);
    // lighting: warm key, navy ambient, ice rim
    var lit = mcol * (NAVY * 0.9 + (GOLD * 0.9 + PAPER * 0.5) * lam);
    lit += ICE * pow(clamp(dot(nrm, normalize(sunDir + rd)), 0.0, 1.0), 3.0) * 0.10 * snow;
    // valley mist
    let mist = exp(-max(p.y - 1.2, 0.0) * 0.9) * fbm3(vec3f(p.xz * 0.35, t * 0.05), 4);
    lit = mix(lit, mix(NAVY, PAPER, 0.30), clamp(mist * 0.8, 0.0, 1.0) * 0.5);
    // aerial perspective
    col = mix(lit, sky, clamp(1.0 - exp(-tcur * 0.012), 0.0, 1.0));
  }
  return col;
}

// ════════════════════════════════════════════════════════════════════════════
//  ENTRY — camera, cross-fade, grade
// ════════════════════════════════════════════════════════════════════════════

fn renderScene(idx: i32, ro: vec3f, rd: vec3f, t: f32) -> vec3f {
  switch idx {
    case 0: { return scene0(ro, rd, t); }
    case 1: { return scene1(ro, rd, t); }
    case 2: { return scene2(ro, rd, t); }
    default: { return scene3(ro, rd, t); }
  }
}

@vertex fn vs(@builtin(vertex_index) vi: u32) -> @builtin(position) vec4f {
  let xy = vec2f(f32((vi << 1u) & 2u), f32(vi & 2u)) * 2.0 - 1.0;
  return vec4f(xy, 0.0, 1.0);
}

@fragment fn fs(@builtin(position) fc: vec4f) -> @location(0) vec4f {
  let uv = (fc.xy * u.res.zw) * 2.0 - 1.0;
  let aspect = u.res.x * u.res.z; // w/h? -> use w*(1/h)
  let t = u.timing.x;

  // camera
  var ro = vec3f(0.0);
  // gentle parallax from the smoothed pointer, plus per-scene drift
  let px = u.pointer.z * 0.10;
  let py = u.pointer.w * 0.06;
  var rd = normalize(vec3f(uv.x * (u.res.x / u.res.y), uv.y, 1.35));
  rd = rotY(rd, px + sin(t * 0.05) * 0.012);
  rd = rotX(rd, -py + cos(t * 0.04) * 0.008);

  // horizontal shift so hero text owns the left on the home page
  rd = rotY(rd, -u.grade.w * 0.35);
  rd = rotX(rd, -u.grade.z * 0.30);

  let ia = i32(u.scene.z + 0.5);
  let ib = i32(u.scene.w + 0.5);
  let blend = clamp(u.scene.y, 0.0, 1.0);

  var col = renderScene(ia, ro, rd, t);
  if (blend > 0.001 && ib != ia) {
    let cb = renderScene(ib, ro, rd, t);
    col = mix(col, cb, blend * blend * (3.0 - 2.0 * blend));
  }

  // grade: vignette, dim, dither
  let r = length(uv * vec2f(0.72, 1.0));
  col *= 1.0 - 0.32 * smoothstep(0.55, 1.35, r);
  col *= u.grade.x;
  col += (hash13(vec3f(fc.xy, u.timing.z)) - 0.5) * (1.5 / 255.0);

  return vec4f(col, 1.0);
}
