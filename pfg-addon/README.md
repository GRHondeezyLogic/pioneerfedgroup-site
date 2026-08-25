# Shader Wallpaper Add-On — Notes

Files from the modernization session. Everything else in the project (copy, structure, form, instructions) is unchanged from what you already have.

## Files
- `css/site.css` — full stylesheet: design tokens (navy/gold palette, font stacks), frosted-glass panel system over the live background, responsive, reduced-motion
- `js/gpu.js` — WebGPU renderer (scene pass → bloom → composite)
- `js/bg.js` — per-page wallpaper driver: reads `body[data-scene]`, scroll crossfade, no-GPU fallback
- `shaders/scene.wgsl` — 4 raymarched scenes, re-graded to navy/gold
- `shaders/post.wgsl` — post chain (bloom, ACES, grain)
- `fonts/GeistMono-Variable.woff2` — mono font for labels/badges

## Wiring (already in the 6 HTML pages)
- `<canvas id="stage">` + `.fx-scrim` div at top of `<body>`
- `body data-scene=`: `scroll` (home — crossfades all 4 scenes), `0`–`3` (subpages, fixed scene)
- Google Fonts link (Archivo + Public Sans) in each `<head>`
- `js/rotate.js` and `js/bg.js` (module) before `</body>`

## Behavior
- No WebGPU → `body.no-webgpu` keeps a static navy gradient. Intentional, not a bug.
- Content sits on `--glass` panels (`backdrop-filter: blur(18px)`) so text stays readable over motion.
- Typography = three tokens at top of site.css: `--f-display`, `--f-body`, `--f-mono`.
