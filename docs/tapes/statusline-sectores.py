#!/usr/bin/env python3
"""docs/tapes/statusline-sectores.py — draw docs/img/statusline-sectores{,.en}.svg.

The two lines of the bar as real text (not a screenshot), every sector underlined in the colour
of its group and tagged with its number from docs/statusline.md. The text is the bar's actual
output for the "cooling" fixture (docs/fixtures/2-cooling.json) with a small repo around it.
Colours are CSS variables with a light and a dark set, switched by prefers-color-scheme and by
a `data-theme` attribute on the page's root, so the Landing can inline it under either theme.

Run from the kit root:  python3 docs/tapes/statusline-sectores.py
"""
from html import escape
from pathlib import Path

CW = 8.4          # advance of one cell at font-size 14 in a monospace font (0.6 em)
X0, PAD = 24, 24

# group -> (light, dark)
GROUPS = {
    "ctx":   ("#1f6feb", "#58a6ff"),
    "cost":  ("#0e7c7b", "#3fb9b7"),
    "quota": ("#8250df", "#bc8cff"),
    "cache": ("#bc4c00", "#ff9a52"),
    "git":   ("#1a7f37", "#56d364"),
    "hand":  ("#9a6700", "#e3b341"),
    "sess":  ("#57606a", "#9da7b3"),
    "hint":  ("#bf3989", "#ff7ac6"),
}
NAMES = {
    "es": {"ctx": "Modelo y contexto", "cost": "Costo y tiempo", "quota": "Cuota del plan",
           "cache": "Caché", "git": "Git", "hand": "HANDOFF", "sess": "Sesión y umbrales",
           "hint": "Pista (qué hacer)"},
    "en": {"ctx": "Model and context", "cost": "Cost and time", "quota": "Plan quota",
           "cache": "Cache", "git": "Git", "hand": "HANDOFF", "sess": "Session and thresholds",
           "hint": "Hint (what to do)"},
}
TITLE = {"es": "La barra de estado de claude-kit: 18 sectores en 8 grupos",
         "en": "The claude-kit status line: 18 sectors in 8 groups"}
NOTE = {"es": "#16 (⚠ umbrales) solo aparece si rules/thresholds.json no se puede leer. @mac es la máquina.",
        "en": "#16 (⚠ umbrales) only shows when rules/thresholds.json cannot be read. @mac is the machine."}

# (number or None, group or None, text, colour of the text in the real bar)
L1 = [(1, "ctx", "Opus 5.5", "b"), (None, None, " ", ""), (2, "ctx", "·high", ""),
      (None, None, " ", ""), (None, "ctx", "@mac", ""), (None, None, " ", ""),
      (3, "ctx", "▓▓▓▓▓▓▓▓▓░░░░░░┋░░░░", "amb"), (None, None, " ", ""),
      (4, "ctx", "180k/400k", "amb"), (None, None, " · ", ""), (5, "ctx", "18% of 1M", ""),
      (None, None, " · ", ""), (6, "cost", "$7.10", ""), (None, None, " · ", ""),
      (7, "cost", "90m", ""), (None, None, " · ", ""), (10, "cache", "⚡︎ enfriando · 4m", "amb")]
L2 = [(8, "quota", "5h 41%", ""), (None, None, "  ", ""), (9, "quota", "7d 87%", ""),
      (None, None, "  ", ""), (11, "cache", "hit 79%", "amb"), (None, None, " ", ""),
      (12, "cache", "(4 miss)", ""), (None, None, "  ", ""), (13, "git", "+213/-15", "grn"),
      (None, None, "  ", ""), (14, "git", "⎇ main ↑1 ↓0 ●2 ?1", ""), (None, None, "  ", ""),
      (15, "hand", "⚠HANDOFF 14:05 ·2f ·1c ·0s", "amb"), (None, None, "  ", ""),
      (17, "sess", "[mi-sesion]", ""), (None, None, "  ", ""),
      (18, "hint", "→ manda un turno corto para recalentar, o /handoff si vas a parar", "mag")]


def cells(s: str) -> int:
    return sum(0 if ord(c) in (0xFE0E, 0xFE0F) else 1 for c in s)


def draw(lang: str) -> str:
    width = X0 * 2 + CW * max(sum(cells(t) for *_, t, _ in L1), sum(cells(t) for *_, t, _ in L2))
    y1, y2 = 92, 126
    height = 300
    css_light = "".join(f"--g-{k}:{v[0]};" for k, v in GROUPS.items())
    css_dark = "".join(f"--g-{k}:{v[1]};" for k, v in GROUPS.items())
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" class="slmap" viewBox="0 0 {width:.0f} {height}" '
           f'role="img" aria-labelledby="slmap-t" font-family="\'JetBrains Mono\', ui-monospace, '
           f'SFMono-Regular, Menlo, Consolas, monospace">',
           f'<title id="slmap-t">{escape(TITLE[lang])}</title>',
           "<style>",
           f".slmap{{--bg:#ffffff;--term:#f6f8fa;--fg:#1f2328;--dim:#57606a;--amb:#9a6700;--grn:#1a7f37;"
           f"--red:#cf222e;--mag:#bf3989;{css_light}}}",
           f"@media (prefers-color-scheme: dark){{:root:not([data-theme=\"light\"]) .slmap,.slmap{{"
           f"--bg:#0d1117;--term:#161b22;--fg:#e6edf3;--dim:#9da7b3;--amb:#e3b341;--grn:#56d364;"
           f"--red:#ff7b72;--mag:#ff7ac6;{css_dark}}}}}",
           f":root[data-theme=\"dark\"] .slmap{{--bg:#0d1117;--term:#161b22;--fg:#e6edf3;--dim:#9da7b3;"
           f"--amb:#e3b341;--grn:#56d364;--red:#ff7b72;--mag:#ff7ac6;{css_dark}}}",
           f":root[data-theme=\"light\"] .slmap{{--bg:#ffffff;--term:#f6f8fa;--fg:#1f2328;--dim:#57606a;"
           f"--amb:#9a6700;--grn:#1a7f37;--red:#cf222e;--mag:#bf3989;{css_light}}}",
           ".slmap text{font-size:14px;fill:var(--fg)}",
           ".slmap .n{font-size:11px;font-weight:700;fill:var(--bg)}",
           ".slmap .lg{font-size:13px}.slmap .ti{font-size:15px;font-weight:700}",
           ".slmap .no{font-size:12px;fill:var(--dim)}",
           "</style>",
           f'<rect width="100%" height="100%" rx="10" fill="var(--bg)"/>',
           f'<text class="ti" x="{X0}" y="30">{escape(TITLE[lang])}</text>',
           f'<rect x="{X0 - 10}" y="{y1 - 24}" width="{width - 2 * X0 + 20:.0f}" height="{y2 - y1 + 40}" '
           f'rx="6" fill="var(--term)"/>']

    def line(segs, y, above):
        x = X0
        for num, grp, txt, col in segs:
            w = CW * cells(txt)
            if grp:
                out.append(f'<rect x="{x:.1f}" y="{y + 5}" width="{w:.1f}" height="3" fill="var(--g-{grp})"/>')
            fill = {"b": "", "amb": "var(--amb)", "grn": "var(--grn)", "mag": "var(--mag)"}.get(col, "")
            style = f' style="fill:{fill}"' if fill else ""
            weight = ' font-weight="700"' if col == "b" else ""
            out.append(f'<text x="{x:.1f}" y="{y}"{style}{weight} xml:space="preserve">{escape(txt)}</text>')
            if num is not None:
                cx = x + min(w, 60) / 2
                cy = y - 30 if above else y + 26
                out.append(f'<circle cx="{cx:.1f}" cy="{cy}" r="9" fill="var(--g-{grp})"/>')
                out.append(f'<text class="n" x="{cx:.1f}" y="{cy + 4}" text-anchor="middle">{num}</text>')
            x += w

    line(L1, y1, True)
    line(L2, y2, False)

    nums = {}
    for num, grp, *_ in L1 + L2:
        if num is not None:
            nums.setdefault(grp, []).append(num)
    nums.setdefault("sess", []).insert(0, 16)
    lx, ly = X0, 196
    for i, (grp, name) in enumerate(NAMES[lang].items()):
        cx = lx + (i % 4) * 300
        cy = ly + (i // 4) * 26
        label = f"{name} · " + ", ".join(f"#{n}" for n in sorted(nums.get(grp, [])))
        out.append(f'<rect x="{cx}" y="{cy - 11}" width="14" height="14" rx="3" fill="var(--g-{grp})"/>')
        out.append(f'<text class="lg" x="{cx + 22}" y="{cy + 1}">{escape(label)}</text>')
    out.append(f'<text class="no" x="{X0}" y="{height - 18}">{escape(NOTE[lang])}</text>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    img = Path(__file__).resolve().parents[1] / "img"
    for lang, name in (("es", "statusline-sectores.svg"), ("en", "statusline-sectores.en.svg")):
        (img / name).write_text(draw(lang), encoding="utf-8", newline="\n")
        print("wrote", img / name)
