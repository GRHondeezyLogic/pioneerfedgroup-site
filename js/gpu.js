// ─────────────────────────────────────────────────────────────────────────────
//  WebGPU renderer: scene pass → bloom chain → composite
// ─────────────────────────────────────────────────────────────────────────────

const HDR = 'rgba16float';

export class Renderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.u = new Float32Array(28);          // 7 × vec4
    this.scale = 1;
    this.maxScale = Math.min(window.devicePixelRatio || 1, 1.6);
    this.quality = 1;
    this.fps = 60;
    this._acc = 0;
    this._n = 0;
    this._lastTune = 0;
  }

  async init() {
    if (!navigator.gpu) throw new Error('WebGPU is not available in this browser.');
    const adapter = await navigator.gpu.requestAdapter({ powerPreference: 'high-performance' });
    if (!adapter) throw new Error('No suitable GPU adapter was found.');

    const device = await adapter.requestDevice();
    this.device = device;
    this.ctx = this.canvas.getContext('webgpu');
    this.format = navigator.gpu.getPreferredCanvasFormat();
    this.ctx.configure({ device, format: this.format, alphaMode: 'opaque' });

    const [sceneSrc, postSrc] = await Promise.all([
      fetch('./shaders/scene.wgsl').then((r) => r.text()),
      fetch('./shaders/post.wgsl').then((r) => r.text()),
    ]);

    const sceneMod = device.createShaderModule({ code: sceneSrc, label: 'scene' });
    const postMod = device.createShaderModule({ code: postSrc, label: 'post' });

    for (const m of [sceneMod, postMod]) {
      const info = await m.getCompilationInfo();
      const errs = info.messages.filter((x) => x.type === 'error');
      if (errs.length) {
        throw new Error(`${m.label}.wgsl:${errs[0].lineNum} — ${errs[0].message}`);
      }
    }

    this.ubo = device.createBuffer({
      size: this.u.byteLength,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    this.sampler = device.createSampler({
      magFilter: 'linear',
      minFilter: 'linear',
      addressModeU: 'clamp-to-edge',
      addressModeV: 'clamp-to-edge',
    });

    const F = GPUShaderStage.FRAGMENT;
    this.sceneBGL = device.createBindGroupLayout({
      entries: [{ binding: 0, visibility: F, buffer: { type: 'uniform' } }],
    });
    this.postBGL = device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: F, buffer: { type: 'uniform' } },
        { binding: 1, visibility: F, sampler: { type: 'filtering' } },
        { binding: 2, visibility: F, texture: { sampleType: 'float' } },
        { binding: 3, visibility: F, texture: { sampleType: 'float' } },
      ],
    });

    const mk = (mod, entry, layout, target) =>
      device.createRenderPipeline({
        layout: device.createPipelineLayout({ bindGroupLayouts: [layout] }),
        vertex: { module: mod, entryPoint: 'vs' },
        fragment: { module: mod, entryPoint: entry, targets: [{ format: target }] },
        primitive: { topology: 'triangle-list' },
      });

    this.pScene = mk(sceneMod, 'fs', this.sceneBGL, HDR);
    this.pBright = mk(postMod, 'fsBright', this.postBGL, HDR);
    this.pBlurH = mk(postMod, 'fsBlurH', this.postBGL, HDR);
    this.pBlurV = mk(postMod, 'fsBlurV', this.postBGL, HDR);
    this.pComp = mk(postMod, 'fsComp', this.postBGL, this.format);

    this.sceneBG = device.createBindGroup({
      layout: this.sceneBGL,
      entries: [{ binding: 0, resource: { buffer: this.ubo } }],
    });

    this.resize();
    return this;
  }

  resize() {
    const d = this.device;
    const w = Math.max(2, Math.round(window.innerWidth * this.scale));
    const h = Math.max(2, Math.round(window.innerHeight * this.scale));
    if (w === this.w && h === this.h) return;
    this.w = w;
    this.h = h;

    this.canvas.width = w;
    this.canvas.height = h;
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';

    for (const t of [this.texScene, this.texA, this.texB]) t?.destroy();

    const usage = GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING;
    const bw = Math.max(2, w >> 2);
    const bh = Math.max(2, h >> 2);

    this.texScene = d.createTexture({ size: [w, h], format: HDR, usage });
    this.texA = d.createTexture({ size: [bw, bh], format: HDR, usage });
    this.texB = d.createTexture({ size: [bw, bh], format: HDR, usage });

    this.vScene = this.texScene.createView();
    this.vA = this.texA.createView();
    this.vB = this.texB.createView();

    const bg = (a, b) =>
      d.createBindGroup({
        layout: this.postBGL,
        entries: [
          { binding: 0, resource: { buffer: this.ubo } },
          { binding: 1, resource: this.sampler },
          { binding: 2, resource: a },
          { binding: 3, resource: b },
        ],
      });

    this.bgBright = bg(this.vScene, this.vScene);
    this.bgAB = bg(this.vA, this.vA);   // reads A → writes B
    this.bgBA = bg(this.vB, this.vB);   // reads B → writes A
    this.bgComp = bg(this.vScene, this.vA);
  }

  // rolling fps → render scale, so weak GPUs stay smooth instead of stuttering
  _tune(dt, now) {
    this._acc += dt;
    this._n++;
    if (this._n < 30) return;
    this.fps = 1 / (this._acc / this._n);
    this._acc = 0;
    this._n = 0;
    if (now - this._lastTune < 1.2) return;

    // A blurry frame is worse than a slightly slow one, so the floor is high and
    // the climb back up is quicker than the drop.
    const before = this.scale;
    if (this.fps < 40) this.scale = Math.max(0.72, this.scale * 0.92);
    else if (this.fps > 55) this.scale = Math.min(this.maxScale, this.scale * 1.08);

    if (Math.abs(this.scale - before) > 0.02) {
      this._lastTune = now;
      this.quality = Math.max(0, Math.min(1, (this.scale - 0.72) / 0.5));
      this.resize();
    }
  }

  render(s, dt) {
    const d = this.device;
    if (!d) return;
    this._tune(dt, s.time);

    const u = this.u;
    u[0] = this.w; u[1] = this.h; u[2] = 1 / this.w; u[3] = 1 / this.h;
    u[4] = s.time; u[5] = dt; u[6] = s.frame; u[7] = 0;
    u[8] = s.sceneF; u[9] = s.blend; u[10] = s.idxA; u[11] = s.idxB;
    u[12] = s.progress; u[13] = s.velocity; u[14] = 0; u[15] = 0;
    u[16] = s.mx; u[17] = s.my; u[18] = s.smx; u[19] = s.smy;
    u[20] = s.dim; u[21] = this.quality; u[22] = s.shiftY; u[23] = s.shift;
    u[24] = s.progs[0]; u[25] = s.progs[1]; u[26] = s.progs[2]; u[27] = s.progs[3];
    d.queue.writeBuffer(this.ubo, 0, u);

    const enc = d.createCommandEncoder();
    const pass = (view, pipe, group) => {
      const p = enc.beginRenderPass({
        colorAttachments: [{ view, loadOp: 'clear', storeOp: 'store', clearValue: { r: 0, g: 0, b: 0, a: 1 } }],
      });
      p.setPipeline(pipe);
      p.setBindGroup(0, group);
      p.draw(3);
      p.end();
    };

    pass(this.vScene, this.pScene, this.sceneBG);
    pass(this.vA, this.pBright, this.bgBright);
    pass(this.vB, this.pBlurH, this.bgAB);
    pass(this.vA, this.pBlurV, this.bgBA);
    pass(this.ctx.getCurrentTexture().createView(), this.pComp, this.bgComp);

    d.queue.submit([enc.finish()]);
  }
}
