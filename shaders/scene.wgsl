// ─────────────────────────────────────────────────────────────────────────────
//  PIONEER FEDERAL GROUP — scene pass
//  Four raymarched scenes in one fragment shader, cross-warped by scroll,
//  re-graded to the brand: deep navy fields, regulation gold light.
//    0  THE STANDARD      Schwarzschild geodesics + gold accretion disk
//    1  OUR STORY         navy & gold volumetric fBm shell around a star
//    2  WHAT WE DELIVER   heightfield ocean under a gold aurora
//    3  HOW WE DELIVER    ridged terrain above a cloud sea at dawn
// ─────────────────────────────────────────────────────────────────────────────

struct U {
  res:    vec4f,   // w, h, 1/w, 1/h
  time:   vec4f,   // t, dt, frame, _
  scene:  vec4f,   // continuous, blend, idxA, idxB
  scroll: vec4f,   // global 0..1, velocity, _, _
  mouse:  vec4f,   // raw x,y  smoothed z,w
  cam:    vec4f,   // dim, quality, shift y, shift x
  progs:  vec4f,   // per-scene local progress
};
@group(0) @binding(0) var<uniform> u: U;

const PI = 3.14159265;

struct VOut {
  @builtin(position) pos: vec4f,
  @location(0) uv: vec2f,
};

@vertex
fn vs(@builtin(vertex_index) vi: u32) -> VOut {
  var tri = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0));
  var o: VOut;
  o.pos = vec4f(tri[vi], 0.0, 1.0);
  o.uv  = tri[vi] * 0.5 + 0.5;
  return o;
}

// Two scenes are alive during a handover, so buy the frame back by marching
// coarser exactly while the picture is being torn apart anyway.
fn load() -> f32 {
  return 1.0 - 0.42 * sin(PI * clamp(u.scene.y, 0.0, 1.0));
}
fn steps(lo: f32, hi: f32) -> i32 {
  return i32(mix(lo, hi, u.cam.y) * load());
}

// ── hashing / noise ──────────────────────────────────────────────────────────

fn hash13(p0: vec3f) -> f32 {
  var p = fract(p0 * 0.1031);
  p += dot(p, p.zyx + 31.32);
  return fract((p.x + p.y) * p.z);
}

fn hash33(p0: vec3f) -> vec3f {
  var p = fract(p0 * vec3f(0.1031, 0.1030, 0.0973));
  p += dot(p, p.yxz + 33.33);
  return fract((p.xxy + p.yxx) * p.zyx);
}

fn hash21(p: vec2f) -> f32 {
  var p3 = fract(vec3f(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

fn noise3(x: vec3f) -> f32 {
  let i = floor(x);
  let f = fract(x);
  let w = f * f * (3.0 - 2.0 * f);
  let a = mix(hash13(i + vec3f(0.0, 0.0, 0.0)), hash13(i + vec3f(1.0, 0.0, 0.0)), w.x);
  let b = mix(hash13(i + vec3f(0.0, 1.0, 0.0)), hash13(i + vec3f(1.0, 1.0, 0.0)), w.x);
  let c = mix(hash13(i + vec3f(0.0, 0.0, 1.0)), hash13(i + vec3f(1.0, 0.0, 1.0)), w.x);
  let d = mix(hash13(i + vec3f(0.0, 1.0, 1.0)), hash13(i + vec3f(1.0, 1.0, 1.0)), w.x);
  return mix(mix(a, b, w.y), mix(c, d, w.y), w.z);
}

fn noise2(x: vec2f) -> f32 { return noise3(vec3f(x, 0.37)); }

const M3 = mat3x3f(0.00, 0.80, 0.60, -0.80, 0.36, -0.48, -0.60, -0.48, 0.64);
const M2 = mat2x2f(1.60, 1.20, -1.20, 1.60);

fn fbm3(p0: vec3f, oct: i32) -> f32 {
  var p = p0;
  var a = 0.5;
  var s = 0.0;
  for (var i = 0; i < oct; i = i + 1) {
    s += a * noise3(p);
    p = M3 * p * 2.02;
    a *= 0.5;
  }
  return s;
}

fn fbm2(p0: vec2f, oct: i32) -> f32 {
  var p = p0;
  var a = 0.5;
  var s = 0.0;
  for (var i = 0; i < oct; i = i + 1) {
    s += a * noise2(p);
    p = M2 * p;
    a *= 0.5;
  }
  return s;
}

// ── shared sky furniture ─────────────────────────────────────────────────────

fn starfield(rd: vec3f, t: f32) -> vec3f {
  var col = vec3f(0.0);
  for (var l = 0; l < 3; l = l + 1) {
    let sc = 26.0 * (1.0 + f32(l) * 1.75);
    let s  = rd * sc;
    let id = floor(s);
    let fp = fract(s) - 0.5;
    let h  = hash33(id + f32(l) * 37.1);
    if (h.x > 0.962) {
      let off = (vec3f(h.y, h.z, h.x) - 0.5) * 0.62;
      let d   = length(fp - off);
      let tw  = 0.55 + 0.45 * sin(t * 1.9 + h.y * 60.0);
      let b   = pow(clamp(1.0 - d * 2.7, 0.0, 1.0), 13.0) * tw;
      let tint = mix(vec3f(0.68, 0.80, 1.0), vec3f(1.0, 0.86, 0.66), h.z);
      col += tint * b * (1.7 - f32(l) * 0.4);
    }
  }
  return col;
}

fn galaxyBand(rd: vec3f) -> vec3f {
  let a = abs(dot(rd, normalize(vec3f(0.32, 0.86, -0.40))));
  let band = pow(clamp(1.0 - a, 0.0, 1.0), 10.0);
  let n = fbm3(rd * 5.0, 4);
  return mix(vec3f(0.03, 0.06, 0.12), vec3f(0.15, 0.12, 0.06), n) * band * 0.70;
}

fn camBasis(ro: vec3f, ta: vec3f) -> mat3x3f {
  let cw = normalize(ta - ro);
  let cu = normalize(cross(cw, vec3f(0.0, 1.0, 0.0)));
  let cv = cross(cu, cw);
  return mat3x3f(cu, cv, cw);
}

// ═════════════════════════════════════════════════════════════════════════════
//  00 · SINGULARITY
// ═════════════════════════════════════════════════════════════════════════════

fn diskSample(hp: vec3f, r: f32, rdir: vec3f, t: f32) -> vec3f {
  // Keplerian shear: rotate the sample point instead of the angle → no seam.
  let kep = t * 6.6 / pow(r, 1.5);
  let ca = cos(kep);
  let sa = sin(kep);
  let rp = vec3f(hp.x * ca - hp.z * sa, 0.0, hp.x * sa + hp.z * ca);

  var d = fbm3(vec3f(rp.x * 0.52, r * 0.85, rp.z * 0.52), 5);
  d = pow(clamp(d * 1.85 - 0.26, 0.0, 1.0), 1.25);

  let x = clamp((r - 2.55) / 9.2, 0.0, 1.0);
  var c = mix(vec3f(1.0, 0.95, 0.82), vec3f(0.85, 0.62, 0.22), pow(x, 0.55));
  c = mix(c, vec3f(0.36, 0.25, 0.08), smoothstep(0.5, 1.0, x));

  let edge = smoothstep(2.55, 3.15, r) * (1.0 - smoothstep(8.6, 12.0, r));
  var inten = edge * (0.24 + 1.45 * d) * pow(2.95 / r, 2.05) * 0.44;

  // relativistic beaming: the approaching limb is brighter and bluer
  let vdir = normalize(cross(vec3f(0.0, 1.0, 0.0), hp));
  let beta = clamp(0.60 * sqrt(2.7 / r), 0.0, 0.82);
  let g = 1.0 / (sqrt(max(1.0 - beta * beta, 1e-3)) * (1.0 - beta * dot(vdir, -rdir)));
  inten *= pow(clamp(g, 0.05, 3.2), 2.7);
  c = mix(c, c * vec3f(0.62, 0.84, 1.5), clamp((g - 1.0) * 0.85, 0.0, 1.0));

  return c * inten;
}

fn sceneBlackHole(p: vec2f, prog: f32) -> vec3f {
  let t = u.time.x;
  let e = smoothstep(0.0, 1.0, prog);

  let orb  = t * 0.042 + u.mouse.z * 0.28;
  let dist = mix(16.5, 12.2, e);
  let hgt  = mix(0.85, 2.6, e) + u.mouse.w * 0.9;

  let ro = vec3f(cos(orb) * dist, hgt, sin(orb) * dist);
  let cb = camBasis(ro, vec3f(0.0));
  let rd = normalize(cb * vec3f(p, 1.75));

  var pos = ro;
  var dir = rd;
  let hv  = cross(pos, dir);
  let h2  = dot(hv, hv);

  var col = vec3f(0.0);
  var captured = false;

  let n = steps(130.0, 200.0);
  for (var i = 0; i < n; i = i + 1) {
    let r = length(pos);
    if (r < 1.0) { captured = true; break; }
    if (r > 48.0 && dot(pos, dir) > 0.0) { break; }

    let dt   = clamp(r * 0.075, 0.025, 0.62);
    let prev = pos;
    let acc  = -1.5 * h2 * pos / pow(dot(pos, pos), 2.5);
    dir = dir + acc * dt;
    pos = pos + dir * dt;

    // equatorial crossing → exact hit by interpolation, so the disk stays crisp
    if (prev.y * pos.y < 0.0) {
      let k  = prev.y / (prev.y - pos.y);
      let hp = mix(prev, pos, k);
      let rr = length(hp.xz);
      if (rr > 2.5 && rr < 12.2) {
        col += diskSample(hp, rr, normalize(dir), t);
      }
    }
  }

  if (!captured) {
    let e2 = normalize(dir);
    col += starfield(e2, t) * 0.95 + galaxyBand(e2);
  }
  return col;
}

// ═════════════════════════════════════════════════════════════════════════════
//  01 · NEBULA — a shell of gas around a young star, seen from outside
// ═════════════════════════════════════════════════════════════════════════════

fn nebulaDensity(p: vec3f, t: f32, oct: i32) -> f32 {
  let r = length(p);
  // hollow inside (the star blew it clear), fading to vacuum outside
  let shell = smoothstep(1.5, 4.2, r) * (1.0 - smoothstep(6.4, 10.4, r));
  if (shell < 0.008) { return 0.0; }
  let q = p * 0.36 + vec3f(0.0, 0.0, t * 0.025);
  let d = fbm3(q, oct) * 2.50 - 1.05;
  return clamp(d, 0.0, 1.0) * shell;
}

fn sceneNebula(p: vec2f, prog: f32) -> vec3f {
  let t = u.time.x;
  let e = smoothstep(0.0, 1.0, prog);

  let orb = t * 0.035 + u.mouse.z * 0.22;
  let R = mix(21.0, 15.5, e);
  let ro = vec3f(sin(orb) * R, 2.2 + sin(t * 0.045) * 1.2 + u.mouse.w * 1.3, -cos(orb) * R);
  let cb = camBasis(ro, vec3f(0.0, 0.0, 0.0));
  let rd = normalize(cb * vec3f(p, 1.7));

  var col = starfield(rd, t) * 0.9 + galaxyBand(rd) * 0.7 + vec3f(0.005, 0.005, 0.014);

  let oct = 4;
  let n   = steps(30.0, 44.0);

  var tt = max(R - 11.5, 0.5) + hash21(p * 137.0 + t * 0.7) * 0.6;
  var trans = 1.0;

  for (var i = 0; i < n; i = i + 1) {
    let sp = ro + rd * tt;
    let d  = nebulaDensity(sp, t, oct);
    if (d > 0.012) {
      // step toward the star: the density we clear is the light that reaches us
      let toStar = -normalize(sp);
      let dl = nebulaDensity(sp + toStar * 0.85, t, oct);
      let grad = clamp((d - dl) * 2.8 + 0.10, 0.0, 1.0);

      let ion = exp(-max(length(sp) - 3.0, 0.0) * 0.36);

      var c = mix(vec3f(0.05, 0.09, 0.22), vec3f(0.93, 0.70, 0.30), grad);
      c += vec3f(1.0, 0.62, 0.20) * pow(grad, 2.4) * ion * 2.1;
      c += vec3f(0.18, 0.26, 0.95) * (1.0 - grad) * 0.20;
      c *= 0.22 + ion * 1.15;

      let a = d * 0.52;
      col += c * a * trans * 1.30;
      trans *= (1.0 - a);
      if (trans < 0.02) { break; }
    }
    tt += 0.52 + tt * 0.020;
  }

  // the star itself, dimmed by whatever gas ended up in front of it
  let along = dot(-ro, rd);
  if (along > 0.0) {
    let perp = length(-ro - rd * along);
    let glow = 1.0 / (1.0 + perp * perp * 2.2);
    col += vec3f(1.0, 0.80, 0.62) * pow(glow, 3.5) * 2.4 * trans;
    col += vec3f(0.55, 0.60, 0.90) * glow * 0.22 * trans;
  }
  return col;
}

// ═════════════════════════════════════════════════════════════════════════════
//  02 · TIDES
// ═════════════════════════════════════════════════════════════════════════════

fn aurora(rd: vec3f, t: f32, n: i32) -> vec3f {
  var acc = vec3f(0.0);
  if (rd.y < 0.006) { return acc; }
  let fade = 1.0 / f32(n);
  for (var i = 0; i < n; i = i + 1) {
    let fi = f32(i) / f32(n);
    let ht = 0.50 + fi * 0.85;
    let pt = rd * (ht / rd.y);
    let q  = pt.xz * vec2f(0.34, 0.10) + vec2f(t * 0.030, -t * 0.010);
    var v  = fbm2(q, 4);
    v = pow(clamp(v * 2.0 - 0.46, 0.0, 1.0), 3.0);
    // curtains: vertical banding so it reads as ribbons, not fog
    v *= 0.42 + 0.58 * abs(sin(pt.x * 0.9 + fbm2(q * 2.1, 2) * 8.0));
    let c = mix(vec3f(0.95, 0.72, 0.28), vec3f(0.52, 0.64, 0.98), fi * fi);
    acc += c * v * fade * 4.6;
  }
  return acc * smoothstep(0.0, 0.13, rd.y);
}

fn skyNight(rd: vec3f, t: f32, n: i32) -> vec3f {
  var col = mix(vec3f(0.020, 0.038, 0.072), vec3f(0.002, 0.006, 0.022),
                smoothstep(-0.05, 0.55, rd.y));
  col += starfield(rd, t) * smoothstep(-0.03, 0.20, rd.y) * 0.95;
  let md = normalize(vec3f(-0.52, 0.13, -0.84));
  let s  = max(dot(rd, md), 0.0);
  col += vec3f(0.80, 0.88, 1.0) * pow(s, 1400.0) * 5.0;
  col += vec3f(0.24, 0.34, 0.58) * pow(s, 10.0) * 0.30;
  col += aurora(rd, t, n);
  return col;
}

fn seaOctave(uv0: vec2f, choppy: f32) -> f32 {
  let uv = uv0 + vec2f(noise2(uv0));
  let wv = 1.0 - abs(sin(uv));
  let sw = abs(cos(uv));
  let w  = mix(wv, sw, wv);
  return pow(1.0 - pow(w.x * w.y, 0.65), choppy);
}

fn seaHeight(p: vec3f, oct: i32, t: f32) -> f32 {
  var freq = 0.16;
  var amp = 0.62;
  var choppy = 4.0;
  var uv = p.xz;
  uv.x *= 0.75;
  let st = t * 0.72;
  var h = 0.0;
  for (var i = 0; i < oct; i = i + 1) {
    var d = seaOctave((uv + st) * freq, choppy);
    d += seaOctave((uv - st) * freq, choppy);
    h += d * amp;
    uv = M2 * uv;
    freq *= 1.9;
    amp *= 0.22;
    choppy = mix(choppy, 1.0, 0.2);
  }
  return h;
}

fn seaNormal(p: vec3f, eps: f32, t: f32) -> vec3f {
  let h = seaHeight(p, 5, t);
  let a = seaHeight(p + vec3f(eps, 0.0, 0.0), 5, t);
  let b = seaHeight(p + vec3f(0.0, 0.0, eps), 5, t);
  return normalize(vec3f(h - a, eps, h - b));
}

fn sceneOcean(p: vec2f, prog: f32) -> vec3f {
  let t = u.time.x;
  let e = smoothstep(0.0, 1.0, prog);

  let nSky = steps(18.0, 32.0);

  let ro = vec3f(t * 0.55, 2.6 + e * 2.4, t * 0.22);
  let pitch = -0.045 + e * 0.075 + u.mouse.w * 0.05;
  let yaw   = 0.25 + u.mouse.z * 0.16 + sin(t * 0.05) * 0.05;
  let fwd = normalize(vec3f(sin(yaw), pitch, cos(yaw)));
  let cb  = camBasis(ro, ro + fwd);
  let rd  = normalize(cb * vec3f(p, 1.85));

  if (rd.y > -0.006) { return skyNight(rd, t, nSky); }

  // heightfield bisection
  var tn = 0.0;
  var tx = 700.0;
  var hx = (ro + rd * tx).y - seaHeight(ro + rd * tx, 3, t);
  if (hx > 0.0) { return skyNight(rd, t, nSky); }
  var hn = ro.y - seaHeight(ro, 3, t);
  var tm = 0.0;
  for (var i = 0; i < 8; i = i + 1) {
    tm = mix(tn, tx, hn / (hn - hx));
    let q = ro + rd * tm;
    let hm = q.y - seaHeight(q, 3, t);
    if (hm < 0.0) { tx = tm; hx = hm; } else { tn = tm; hn = hm; }
  }

  let sp = ro + rd * tm;
  let nrm = seaNormal(sp, max(0.02, tm * 0.0018), t);
  let refl = reflect(rd, nrm);
  let rup = vec3f(refl.x, abs(refl.y) + 0.02, refl.z);

  var fres = clamp(1.0 - dot(nrm, -rd), 0.0, 1.0);
  fres = 0.04 + 0.86 * pow(fres, 4.0);

  // the reflection carries the scene, so it gets the cheaper sky
  let sky = skyNight(normalize(rup), t, max(10, nSky / 2));

  var col = vec3f(0.004, 0.026, 0.045);
  col = mix(col, sky * 1.25, fres);

  // subsurface glow where the crests are thin
  let crest = clamp(sp.y * 0.55 + 0.35, 0.0, 1.0);
  col += vec3f(0.05, 0.20, 0.32) * crest * crest * 0.35 * max(1.0 - tm * 0.006, 0.0);

  // moon glint
  let md = normalize(vec3f(-0.52, 0.13, -0.84));
  col += vec3f(0.95, 0.98, 1.0) * pow(max(dot(refl, md), 0.0), 200.0) * 3.2;

  // horizon haze
  col = mix(col, skyNight(normalize(vec3f(rd.x, 0.006, rd.z)), t, nSky) * 0.92,
            smoothstep(90.0, 620.0, tm));
  return col;
}

// ═════════════════════════════════════════════════════════════════════════════
//  03 · FIRST LIGHT
// ═════════════════════════════════════════════════════════════════════════════

const SUN = vec3f(0.60, 0.085, 0.80);
const CLOUD_Y = 96.0;

fn terrainH(q: vec2f, oct: i32) -> f32 {
  var p = q * 0.0052;
  var a = 1.0;
  var s = 0.0;
  var norm = 0.0;
  for (var i = 0; i < oct; i = i + 1) {
    let v = noise2(p);
    s += a * (1.0 - abs(v * 2.0 - 1.0));
    norm += a;
    p = M2 * p;
    a *= 0.46;
  }
  return pow(clamp(s / norm, 0.0, 1.0), 2.3) * 300.0 - 62.0;
}

fn skyDawn(rd: vec3f, t: f32) -> vec3f {
  let sun = normalize(SUN);
  let sd = max(dot(rd, sun), 0.0);
  let y  = clamp(rd.y * 1.25 + 0.06, 0.0, 1.0);

  var col = mix(vec3f(0.90, 0.46, 0.26), vec3f(0.09, 0.17, 0.42), pow(y, 0.55));
  col = mix(col, vec3f(0.025, 0.05, 0.18), smoothstep(0.5, 1.0, y));

  col += vec3f(1.0, 0.44, 0.14) * pow(sd, 5.0) * 0.9;
  col += vec3f(1.0, 0.74, 0.44) * pow(sd, 260.0) * 5.0;
  col += vec3f(1.0, 0.66, 0.34) * pow(sd, 2600.0) * 26.0;

  if (rd.y > 0.02) {
    let cp = rd.xz / rd.y * 0.30 + vec2f(t * 0.006, t * 0.002);
    var c = fbm2(cp, 5);
    c = smoothstep(0.46, 0.86, c) * smoothstep(0.02, 0.30, rd.y);
    let lit = mix(vec3f(0.26, 0.19, 0.28), vec3f(1.0, 0.66, 0.40), pow(sd, 1.4));
    col = mix(col, lit, c * 0.70);
  }
  return col;
}

fn sceneDawn(p: vec2f, prog: f32) -> vec3f {
  let t = u.time.x;
  let e = smoothstep(0.0, 1.0, prog);
  let sun = normalize(SUN);

  let ro = vec3f(t * 1.6, 178.0 + e * 46.0, -220.0 - t * 1.4);
  let pitch = -0.045 + e * 0.055 + u.mouse.w * 0.045;
  let yaw   = 0.10 + u.mouse.z * 0.12;
  let fwd = normalize(vec3f(sin(yaw), pitch, cos(yaw)));
  let cb  = camBasis(ro, ro + fwd);
  let rd  = normalize(cb * vec3f(p, 1.95));

  var col = skyDawn(rd, t);
  let sd = max(dot(rd, sun), 0.0);
  let fogCol = mix(vec3f(0.34, 0.34, 0.44), vec3f(1.0, 0.55, 0.24), pow(sd, 2.6));

  // ── terrain ───────────────────────────────────────────────────────────────
  let n = steps(90.0, 150.0);
  var tt = 4.0;
  var hit = -1.0;
  for (var i = 0; i < n; i = i + 1) {
    let sp = ro + rd * tt;
    if (sp.y > 260.0 && rd.y > 0.0) { break; }
    let h = sp.y - terrainH(sp.xz, 6);
    if (h < 0.0022 * tt) { hit = tt; break; }
    tt += max(h * 0.34, tt * 0.004);
    if (tt > 4200.0) { break; }
  }

  if (hit > 0.0) {
    let sp = ro + rd * hit;
    let ep = max(1.2, hit * 0.0035);
    let hc = terrainH(sp.xz, 6);
    let nrm = normalize(vec3f(hc - terrainH(sp.xz + vec2f(ep, 0.0), 6),
                              ep,
                              hc - terrainH(sp.xz + vec2f(0.0, ep), 6)));

    let dif = clamp(dot(nrm, sun), 0.0, 1.0);
    let sky = clamp(0.5 + 0.5 * nrm.y, 0.0, 1.0);

    let slope = clamp(1.0 - nrm.y, 0.0, 1.0);
    let alt   = clamp((sp.y - 40.0) / 150.0, 0.0, 1.0);
    var rock = mix(vec3f(0.070, 0.055, 0.055), vec3f(0.140, 0.105, 0.090),
                   noise2(sp.xz * 0.012));
    let snow = smoothstep(0.45, 0.85, alt) * smoothstep(0.60, 0.26, slope);
    rock = mix(rock, vec3f(0.80, 0.82, 0.90), snow);

    var lit = rock * (vec3f(1.50, 0.72, 0.32) * dif * 2.6
                    + vec3f(0.16, 0.22, 0.42) * sky * 0.55);
    lit += vec3f(1.0, 0.58, 0.26) * pow(clamp(1.0 + dot(rd, nrm), 0.0, 1.0), 5.0) * dif * 0.22;

    let fogAmt = 1.0 - exp(-0.00095 * hit);
    col = mix(lit, fogCol, fogAmt);
    col += vec3f(1.0, 0.50, 0.20) * pow(sd, 7.0) * fogAmt * 0.5;
  }

  // ── the cloud sea the ridges stand in ─────────────────────────────────────
  if (rd.y < -0.004) {
    let tc = (CLOUD_Y - ro.y) / rd.y;
    if (tc > 0.0 && (hit < 0.0 || tc < hit)) {
      let cp = ro + rd * tc;
      var cv = fbm2(cp.xz * 0.0045 + vec2f(t * 0.004, t * 0.0015), 5);
      // only let the cloud sea gather in the distance — up close a plane this
      // wide reads as a flat sheet under the camera, not as weather
      cv = smoothstep(0.40, 0.70, cv) * smoothstep(240.0, 1100.0, tc);
      let cfog = 1.0 - exp(-0.00095 * tc);
      var ccol = mix(vec3f(0.62, 0.46, 0.46), vec3f(1.0, 0.78, 0.56), pow(sd, 1.8));
      ccol = mix(ccol, fogCol, cfog);
      col = mix(col, ccol, cv * 0.92);
    }
  }
  return col;
}

// ═════════════════════════════════════════════════════════════════════════════

fn renderScene(idx: i32, p: vec2f) -> vec3f {
  if (idx == 0) { return sceneBlackHole(p, u.progs.x); }
  if (idx == 1) { return sceneNebula(p, u.progs.y); }
  if (idx == 2) { return sceneOcean(p, u.progs.z); }
  return sceneDawn(p, u.progs.w);
}

@fragment
fn fs(in: VOut) -> @location(0) vec4f {
  // fit to the shorter axis, so a portrait phone widens the view instead of
  // cropping into it; cam.zw then push the subject clear of the type column
  let asp = u.res.x / u.res.y;
  let fit = select(vec2f(1.0, 1.0 / asp), vec2f(asp, 1.0), asp >= 1.0);
  let p = (in.uv * 2.0 - 1.0) * fit - vec2f(u.cam.w, u.cam.z);

  let b = clamp(u.scene.y, 0.0, 1.0);
  let warp = sin(PI * b);

  var pa = p;
  var pb = p;
  if (warp > 0.002) {
    let n = fbm3(vec3f(p * 2.2, u.time.x * 0.30), 3) - 0.5;
    let k = warp * 0.26;
    pa = p * (1.0 + k * 1.15) + vec2f(n * k * 0.85, n * k * 0.45);
    pb = p * (1.0 - k * 0.65) - vec2f(n * k * 0.65, n * k * 0.35);
  }

  // sharpen the crossfade so the muddy 50/50 average passes quickly, and
  // dissolve it with noise so it reads as matter reorganising, not a dip to grey
  var mixT = smoothstep(0.16, 0.84, b);
  if (warp > 0.002) {
    let grain = fbm3(vec3f(p * 3.1, u.time.x * 0.12), 3);
    mixT = clamp(mixT + (grain - 0.5) * 0.55 * warp, 0.0, 1.0);
  }

  var col = vec3f(0.0);
  if (mixT < 0.999) { col = renderScene(i32(u.scene.z), pa); }
  if (mixT > 0.001) {
    let cb = renderScene(i32(u.scene.w), pb);
    col = select(cb, mix(col, cb, mixT), mixT < 0.999);
  }

  // a spark along the seam, not a whiteout
  col += vec3f(0.85, 0.92, 1.0) * pow(warp, 14.0) * 0.16;

  return vec4f(col, 1.0);
}
