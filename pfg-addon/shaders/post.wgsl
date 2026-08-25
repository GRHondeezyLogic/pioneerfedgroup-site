// ─────────────────────────────────────────────────────────────────────────────
//  EVENT HORIZON — post chain
//  bright-pass → separable blur (×2) → composite (CA, grain, vignette, ACES)
// ─────────────────────────────────────────────────────────────────────────────

struct U {
  res:    vec4f,
  time:   vec4f,
  scene:  vec4f,
  scroll: vec4f,
  mouse:  vec4f,
  cam:    vec4f,
  progs:  vec4f,
};

@group(0) @binding(0) var<uniform> u: U;
@group(0) @binding(1) var samp: sampler;
@group(0) @binding(2) var texA: texture_2d<f32>;
@group(0) @binding(3) var texB: texture_2d<f32>;

struct VOut {
  @builtin(position) pos: vec4f,
  @location(0) uv: vec2f,
};

@vertex
fn vs(@builtin(vertex_index) vi: u32) -> VOut {
  var tri = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0));
  var o: VOut;
  o.pos = vec4f(tri[vi], 0.0, 1.0);
  o.uv  = vec2f(tri[vi].x, -tri[vi].y) * 0.5 + 0.5;
  return o;
}

// ── bright pass ──────────────────────────────────────────────────────────────

@fragment
fn fsBright(in: VOut) -> @location(0) vec4f {
  let c = textureSample(texA, samp, in.uv).rgb;
  let l = dot(c, vec3f(0.2126, 0.7152, 0.0722));
  let knee = 0.55;
  let thr = 0.72;
  let soft = clamp(l - thr + knee, 0.0, 2.0 * knee);
  let w = max(soft * soft / (4.0 * knee + 1e-4), max(l - thr, 0.0)) / max(l, 1e-4);
  return vec4f(c * w, 1.0);
}

// ── separable gaussian (9-tap, linear-sampled to 5 fetches) ──────────────────

const W0 = 0.2270270270;
const W1 = 0.3162162162;
const W2 = 0.0702702703;
const O1 = 1.3846153846;
const O2 = 3.2307692308;

fn blur(uv: vec2f, dir: vec2f) -> vec3f {
  let d = vec2f(textureDimensions(texA, 0));
  let px = dir / d * 1.35;
  var c = textureSample(texA, samp, uv).rgb * W0;
  c += textureSample(texA, samp, uv + px * O1).rgb * W1;
  c += textureSample(texA, samp, uv - px * O1).rgb * W1;
  c += textureSample(texA, samp, uv + px * O2).rgb * W2;
  c += textureSample(texA, samp, uv - px * O2).rgb * W2;
  return c;
}

@fragment
fn fsBlurH(in: VOut) -> @location(0) vec4f {
  return vec4f(blur(in.uv, vec2f(1.0, 0.0)), 1.0);
}

@fragment
fn fsBlurV(in: VOut) -> @location(0) vec4f {
  return vec4f(blur(in.uv, vec2f(0.0, 1.0)), 1.0);
}

// ── composite ────────────────────────────────────────────────────────────────

fn aces(x: vec3f) -> vec3f {
  let a = 2.51; let b = 0.03; let c = 2.43; let d = 0.59; let e = 0.14;
  return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3f(0.0), vec3f(1.0));
}

fn hash21(p: vec2f) -> f32 {
  var p3 = fract(vec3f(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

@fragment
fn fsComp(in: VOut) -> @location(0) vec4f {
  let uv = in.uv;
  let ctr = uv - 0.5;
  let r2 = dot(ctr, ctr);

  // chromatic aberration grows with scroll velocity and scene transitions
  let warp = sin(3.14159 * clamp(u.scene.y, 0.0, 1.0));
  let ca = (0.0006 + min(abs(u.scroll.y) * 0.00010, 0.0040) + warp * 0.0055) * (0.25 + r2 * 1.6);

  var col: vec3f;
  col.r = textureSample(texA, samp, uv - ctr * ca).r;
  col.g = textureSample(texA, samp, uv).g;
  col.b = textureSample(texA, samp, uv + ctr * ca).b;

  let bloom = textureSample(texB, samp, uv).rgb;
  col += bloom * (0.72 + warp * 0.20);

  // exposure + global dim (driven by scroll into the outro)
  col *= u.cam.x;

  col = aces(col * 1.06);

  // vignette
  col *= 1.0 - smoothstep(0.18, 0.92, r2 * 1.75) * 0.72;

  // film grain, slightly stronger in the shadows where banding would show
  let g = hash21(uv * u.res.xy + fract(u.time.x) * 731.0) - 0.5;
  let lum = dot(col, vec3f(0.2126, 0.7152, 0.0722));
  col += g * (0.012 + 0.022 * (1.0 - lum));

  // display transfer
  col = pow(max(col, vec3f(0.0)), vec3f(1.0 / 2.2));
  return vec4f(col, 1.0);
}
