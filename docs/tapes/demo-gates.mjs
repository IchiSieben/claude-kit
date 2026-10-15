// docs/tapes/demo-gates.mjs — the demo's gates and media, run on the Mac by docs/tapes/demo-gates.sh.
//
//   node docs/tapes/demo-gates.mjs <base-url> <out-dir>
//
// 1. Lighthouse, mobile, 5 runs -> median performance; a11y, CLS, LCP of the median run.
// 2. axe-core on five states (light, dark, tour open, session mode, 390 px).
// 3. Flicker: CDP screencast of scripted moments; a CUT is a frame pair where more than 30% of
//    the pixels change luma by more than 24/255 per 60 Hz frame (the Landing's _flicker.mts rule,
//    scaled by the pair's real interval). Cold loads are reported, never counted.
// 4. Screenshots: 4 sections x (light, dark, 390 px) + 3 tour steps -> <out>/*.png
// 5. The card clip: controls moved with real clicks, wires and halos visible -> <out>/clip.webm
// Writes <out>/GATES.md and <out>/gates.json. Exit 0 = every gate passed.
import { chromium } from "playwright";
import { AxeBuilder } from "@axe-core/playwright";
import lighthouse from "lighthouse";
import * as chromeLauncher from "chrome-launcher";
import jpeg from "jpeg-js";
import { mkdirSync, writeFileSync, readdirSync, renameSync } from "node:fs";
import { join } from "node:path";

const BASE = process.argv[2], OUT = process.argv[3];
mkdirSync(OUT, { recursive: true });
const SEEN = { "ic7-tutorial:seen:claude-kit-demo-v2": "1", "kitdemo-lang": "es" };
const R = { lighthouse: [], axe: {}, flicker: [], shots: [], clip: null };
const log = (...a) => console.log("[gates]", ...a);
const wait = ms => new Promise(r => setTimeout(r, ms));

async function ctx(browser, { w = 1440, h = 900, theme = "dark", seen = true, reduce = false, mobile = false, video = null } = {}) {
  const c = await browser.newContext({
    viewport: { width: w, height: h }, deviceScaleFactor: mobile ? 2 : 1, isMobile: mobile, hasTouch: mobile,
    colorScheme: theme, reducedMotion: reduce ? "reduce" : "no-preference", locale: "es-PE",
    ...(video ? { recordVideo: { dir: video, size: { width: 1280, height: 720 } } } : {}),
  });
  const ls = { ...(seen ? SEEN : { "kitdemo-lang": "es" }), "kitdemo-theme": theme };
  await c.addInitScript(o => { for (const [k, v] of Object.entries(o)) try { localStorage.setItem(k, v); } catch (e) {} }, ls);
  return c;
}
async function open(c, path = "/") {
  const p = await c.newPage();
  await p.goto(BASE + path, { waitUntil: "networkidle" });
  await p.waitForFunction(() => document.querySelectorAll("#cards .card").length > 0);
  await wait(900);
  return p;
}

// ---------------------------------------------------------------- 1. Lighthouse
async function runLighthouse() {
  for (let i = 0; i < 5; i++) {
    const chrome = await chromeLauncher.launch({ chromePath: chromium.executablePath(), chromeFlags: ["--headless=new", "--no-sandbox"] });
    try {
      const r = await lighthouse(BASE + "/", { port: chrome.port, output: "json", logLevel: "error" });
      const a = r.lhr.audits, c = r.lhr.categories;
      const row = { perf: Math.round(c.performance.score * 100), a11y: Math.round(c.accessibility.score * 100),
        bp: Math.round(c["best-practices"].score * 100), seo: Math.round(c.seo.score * 100),
        lcp: Math.round(a["largest-contentful-paint"].numericValue), cls: +a["cumulative-layout-shift"].numericValue.toFixed(3),
        tbt: Math.round(a["total-blocking-time"].numericValue),
        lcpEl: a["largest-contentful-paint-element"]?.details?.items?.[0]?.items?.[0]?.node?.snippet || "",
        a11yFails: Object.values(a).filter(x => x.score === 0 && r.lhr.categories.accessibility.auditRefs.some(f => f.id === x.id)).map(x => x.id) };
      R.lighthouse.push(row); log("lighthouse", i + 1, JSON.stringify(row));
    } finally { await chrome.kill(); }
  }
}

// ---------------------------------------------------------------- 2. axe
async function runAxe(browser) {
  const states = {
    light: { theme: "light" }, dark: { theme: "dark" }, tour: { theme: "dark", seen: false },
    session: { theme: "dark", act: async p => { await p.click("#tab-session"); await wait(700); } },
    m390: { theme: "dark", w: 390, h: 844, mobile: true },
  };
  for (const [name, s] of Object.entries(states)) {
    const c = await ctx(browser, s), p = await open(c);
    if (s.seen === false) await p.waitForSelector(".ic7-tutorial-on", { timeout: 5000 });
    if (s.act) await s.act(p);
    await p.evaluate(() => document.querySelectorAll(".reveal,.reveal-stagger,.tree").forEach(e => e.classList.add("is-in")));
    await wait(900);
    const r = await new AxeBuilder({ page: p }).analyze();
    R.axe[name] = r.violations.map(v => ({ id: v.id, impact: v.impact, n: v.nodes.length, target: v.nodes[0]?.target?.join(" ") }));
    log("axe", name, r.violations.length);
    await c.close();
  }
}

// ---------------------------------------------------------------- 3. flicker
function luma(buf) {
  const { width, height, data } = jpeg.decode(buf, { useTArray: true });
  const AW = 160, AH = Math.round(160 * height / width), L = new Float32Array(AW * AH);
  for (let y = 0; y < AH; y++) for (let x = 0; x < AW; x++) {
    const i = ((Math.floor(y * height / AH) * width) + Math.floor(x * width / AW)) * 4;
    L[y * AW + x] = .2126 * data[i] + .7152 * data[i + 1] + .0722 * data[i + 2];
  }
  return L;
}
async function screencast(p, fn) {
  const s = await p.context().newCDPSession(p), frames = [];
  s.on("Page.screencastFrame", f => { frames.push({ t: f.metadata.timestamp * 1000, b: Buffer.from(f.data, "base64") }); s.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {}); });
  await s.send("Page.startScreencast", { format: "jpeg", quality: 70, everyNthFrame: 1 });
  await fn(); await wait(300);
  await s.send("Page.stopScreencast"); await s.detach();
  return frames;
}
function cuts(frames) {
  const out = []; let prev = null;
  for (const f of frames) {
    const L = luma(f.b);
    if (prev) {
      const dt = Math.max(16.7, f.t - prev.t), thr = 24 * dt / (1000 / 60);
      let n = 0, min = 255, max = 0;
      for (let i = 0; i < L.length; i++) { if (Math.abs(L[i] - prev.L[i]) > thr) n++; if (prev.L[i] < min) min = prev.L[i]; if (prev.L[i] > max) max = prev.L[i]; }
      const frac = n / L.length;
      if (max - min > 8 && frac > .3) out.push({ at: Math.round(f.t - frames[0].t), frac: +frac.toFixed(2) });
    }
    prev = { t: f.t, L };
  }
  return out;
}
async function runFlicker(browser) {
  const radio = (c, v) => `input[name="c${c}"][value="${v}"]`;
  const clickRadio = async (p, c, v) => { await p.locator(radio(c, v)).locator("xpath=..").click(); await wait(1300); };
  const M = [
    { id: "load", nav: true, run: async p => { await p.goto(BASE + "/?f=" + Date.now(), { waitUntil: "load" }); await wait(3000); } },
    { id: "first-visit", nav: true, seen: false, run: async p => { await p.goto(BASE + "/?f=" + Date.now(), { waitUntil: "load" }); await wait(3500); } },
    { id: "context", run: async p => { await p.locator("#ctx").focus(); for (let i = 0; i < 3; i++) { await p.keyboard.press("ArrowRight"); await wait(1300); } } },
    { id: "cache", run: async p => { await clickRadio(p, 2, 1); await clickRadio(p, 2, 2); await clickRadio(p, 2, 0); } },
    { id: "git", run: async p => { for (const v of [1, 2, 3, 0]) await clickRadio(p, 4, v); } },
    { id: "session", run: async p => { await p.click("#tab-session"); await wait(800); await p.click("#play"); await wait(7000); } },
    { id: "theme", run: async p => { await p.click("#theme"); await wait(1300); await p.click("#theme"); await wait(1300); } },
    { id: "tour", seen: false, run: async p => { for (let i = 0; i < 3; i++) { await wait(2500); await p.keyboard.press("ArrowRight"); } await wait(2500); } },
    { id: "scroll", run: async p => { await p.mouse.move(700, 400); for (let i = 0; i < 80; i++) { await p.mouse.wheel(0, 60); await wait(50); } await wait(1200); } },
    { id: "mobile-git", mobile: true, run: async p => { await p.evaluate(() => scrollTo(0, 900)); await wait(600); for (const v of [1, 2]) await clickRadio(p, 4, v); } },
    { id: "reduced-cache", reduce: true, run: async p => { await clickRadio(p, 2, 2); await clickRadio(p, 2, 0); } },
  ];
  for (const m of M) {
    const c = await ctx(browser, { seen: m.seen !== false, reduce: m.reduce, mobile: m.mobile, w: m.mobile ? 390 : 1280, h: m.mobile ? 844 : 720 });
    const p = m.nav ? await c.newPage() : await open(c);
    if (!m.nav && !m.mobile && m.id !== "scroll" && m.id !== "tour") await p.evaluate(() => { const s = document.querySelector("#screen"); scrollTo(0, s.getBoundingClientRect().top + scrollY - 70); });
    await wait(400);
    const frames = await screencast(p, () => m.run(p));
    const k = cuts(frames);
    R.flicker.push({ id: m.id, nav: !!m.nav, frames: frames.length, cuts: k });
    log("flicker", m.id, frames.length, "frames", k.length, "cuts", m.nav ? "(not counted)" : "");
    await c.close();
  }
}

// ---------------------------------------------------------------- 4. screenshots
async function runShots(browser) {
  const sections = [["hero", "#barra"], ["significado", "#significado"], ["llevas", "#llevas"], ["sesion", "#barra"]];
  for (const [mode, opt] of [["light", { theme: "light" }], ["dark", { theme: "dark" }], ["390", { theme: "dark", w: 390, h: 844, mobile: true }]]) {
    const c = await ctx(browser, opt), p = await open(c);
    for (const [name, sel] of sections) {
      if (name === "sesion") { await p.click("#tab-session"); await wait(500); await p.locator("#tline").fill("7"); await p.dispatchEvent("#tline", "input"); }
      await p.evaluate(s => { const e = document.querySelector(s); scrollTo(0, e.getBoundingClientRect().top + scrollY - (s === "#barra" ? 0 : 40)); document.querySelectorAll(".reveal,.reveal-stagger,.tree").forEach(x => x.classList.add("is-in")); }, name === "sesion" ? "#stage" : sel);
      await wait(1600);
      const f = join(OUT, `${mode}-${name}.png`); await p.screenshot({ path: f }); R.shots.push(f);
    }
    await c.close();
  }
  const c = await ctx(browser, { theme: "dark", seen: false }), p = await open(c);
  await p.waitForSelector(".ic7-tutorial-on");
  for (const [i, n] of [[0, 1], [2, 3], [5, 6]]) {
    while (+(await p.locator(".ic7-tutorial-count").innerText()).split(" ")[0] < n) { await p.keyboard.press("ArrowRight"); await wait(300); }
    await wait(i === 0 ? 1200 : 5200);
    const f = join(OUT, `tour-${n}.png`); await p.screenshot({ path: f }); R.shots.push(f);
  }
  await c.close();
}

// ---------------------------------------------------------------- 5. the clip
async function runClip(browser) {
  const dir = join(OUT, "video");
  const c = await ctx(browser, { w: 1920, h: 1080, theme: "dark", video: dir }), p = await open(c);
  await p.evaluate(() => { const s = document.querySelector("#screen"); scrollTo(0, s.getBoundingClientRect().top + scrollY - 64); });
  await wait(1200);
  const at = async (sel, ms) => { const b = await p.locator(sel).boundingBox(); await p.mouse.move(b.x + b.width / 2, b.y + b.height / 2, { steps: 12 }); await p.mouse.down(); await p.mouse.up(); await wait(ms); };
  const radio = (c, v) => `.ctl[data-c="${c}"] label:nth-child(${v + 1}) span`;
  await p.locator("#ctx").focus();
  for (let i = 0; i < 2; i++) { await p.keyboard.press("ArrowRight"); await wait(2200); }
  await at(radio(2, 1), 2400); await at(radio(2, 2), 2400);
  await at(radio(4, 2), 2000); await at(radio(4, 3), 2000);
  await at(radio(3, 2), 2600);
  await c.close();
  const v = readdirSync(dir).find(f => f.endsWith(".webm"));
  renameSync(join(dir, v), join(OUT, "clip.webm")); R.clip = join(OUT, "clip.webm");
  log("clip", R.clip);
}

// ---------------------------------------------------------------- report
const median = a => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];
function report() {
  const L = R.lighthouse, perf = median(L.map(r => r.perf)), med = L.find(r => r.perf === perf) || {};
  const axeN = Object.values(R.axe).reduce((n, v) => n + v.length, 0);
  const cutN = R.flicker.filter(f => !f.nav).reduce((n, f) => n + f.cuts.length, 0);
  const pass = { perf: perf >= 95, a11y: med.a11y === 100, cls: med.cls === 0, axe: axeN === 0, flicker: cutN === 0 };
  const md = [`# demo v2 — gates (${new Date().toISOString().slice(0, 16)}Z)`, "",
    `Lighthouse mobile, median of ${L.length}: **perf ${perf}** · a11y ${med.a11y} · best-practices ${med.bp} · SEO ${med.seo} · LCP ${med.lcp} ms · CLS ${med.cls} · TBT ${med.tbt} ms`,
    `LCP element: \`${(med.lcpEl || "").replace(/`/g, "'").slice(0, 120)}\``, "",
    "| run | perf | a11y | LCP ms | CLS | TBT ms |", "|---|---|---|---|---|---|", ...L.map((r, i) => `| ${i + 1} | ${r.perf} | ${r.a11y} | ${r.lcp} | ${r.cls} | ${r.tbt} |`), "",
    `axe: **${axeN} violations**`, ...Object.entries(R.axe).map(([k, v]) => `- ${k}: ${v.length ? v.map(x => `${x.id} (${x.impact}, ${x.n}: \`${x.target}\`)`).join("; ") : "0"}`), "",
    `Flicker (cut = >30% of pixels with |ΔL| > 24/255 per 60 Hz frame in one pair): **${cutN} cuts**`,
    ...R.flicker.map(f => `- ${f.id}: ${f.frames} frames, ${f.cuts.length} cuts${f.nav ? " (navigation, not counted)" : ""}${f.cuts.length ? " at " + f.cuts.map(c => `${c.at} ms (${c.frac})`).join(", ") : ""}`), "",
    `Screenshots: ${R.shots.length}`, `Gates: ${Object.entries(pass).map(([k, v]) => `${k} ${v ? "ok" : "FAIL"}`).join(" · ")}`];
  writeFileSync(join(OUT, "GATES.md"), md.join("\n") + "\n");
  writeFileSync(join(OUT, "gates.json"), JSON.stringify({ ...R, pass }, null, 1));
  console.log(md.join("\n"));
  return Object.values(pass).every(Boolean);
}

const browser = await chromium.launch();
const ONLY = (process.env.GATES_ONLY || "").split(",").filter(Boolean);  // e.g. GATES_ONLY=lighthouse,axe
const step = async (name, fn) => { if (ONLY.length && !ONLY.includes(name)) return; try { await fn(); } catch (e) { log("STEP FAILED", name, e.stack || e); R[name + "Error"] = String(e); } };
await step("lighthouse", runLighthouse);
await step("axe", () => runAxe(browser));
await step("flicker", () => runFlicker(browser));
await step("shots", () => runShots(browser));
await step("clip", () => runClip(browser));
await browser.close();
process.exit(report() ? 0 : 1);
