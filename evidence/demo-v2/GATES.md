# demo v2 — gates (2026-10-15T18:11Z)

Measured: https://kit.ichisieben.dev (index.html, app.js, content.js, grid.json and tutorial.js identical to commit 3bdb15c by md5)

Ran on: **Windows 10, not the Mac** — the Mac lane hung after the Playwright download (see docs/DECISIONES.md, V1c). Lighthouse on this machine is noisy: the same code gave TBT 431 and 224 ms in back-to-back runs.

Lighthouse mobile, median of 5: **perf 88** · a11y 100 · best-practices 100 · SEO 100 · LCP 1565 ms · CLS 0 · TBT 434 ms
LCP element: `<p class="lead reveal is-in">`

| run | perf | a11y | LCP ms | CLS | TBT ms |
|---|---|---|---|---|---|
| 1 | 88 | 100 | 1565 | 0 | 434 |
| 2 | 95 | 100 | 1552 | 0 | 172 |
| 3 | 87 | 100 | 1590 | 0 | 434 |
| 4 | 80 | 100 | 1683 | 0 | 706 |
| 5 | 88 | 100 | 1780 | 0 | 402 |

axe: **0 violations**
- light: 0
- dark: 0
- tour: 0
- session: 0
- m390: 0

Flicker (cut = >30% of pixels with |ΔL| > 24/255 per 60 Hz frame in one pair): **0 cuts**
- load: 44 frames, 0 cuts (navigation, not counted)
- first-visit: 87 frames, 0 cuts (navigation, not counted)
- context: 148 frames, 0 cuts
- cache: 223 frames, 0 cuts
- git: 159 frames, 0 cuts
- session: 178 frames, 0 cuts
- theme: 85 frames, 0 cuts
- tour: 252 frames, 0 cuts
- scroll: 119 frames, 0 cuts
- mobile-git: 89 frames, 0 cuts
- reduced-cache: 131 frames, 0 cuts

Screenshots: 15
Gates: perf FAIL · a11y ok · cls ok · axe ok · flicker ok
