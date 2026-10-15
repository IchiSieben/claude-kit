#!/usr/bin/env python3
"""
partidas.py — turns the harvest.py v2 archive into "matches": per-session play-by-play of
the habits the kit tries to teach (hand off before a long context, no frontier model on
mechanical work, no cold cache, no compaction without a handoff).

WHY separate from harvest.py: harvest extracts facts from transcripts; this only reads the
archive it wrote (plus the file sizes under projects/ for the disk table) and judges them.
Stdlib only, read-only on ~/.claude/projects/, nothing leaves the machine.

PRIVACY: the outputs carry the project label only. Never the encoded project dir, file, cwd,
session id, prompt text or user name (sessions are numbered 1..N by start). Labels matching
the extended regex in $KIT_PROTECTED_PATHS (unset: none) are shown as privado-N.

Usage:
    python partidas.py                      # last 4 weeks, archive ~/claude-archive
    python partidas.py --weeks 8 --archive DIR --claude-dir DIR
    python partidas.py --now 2026-10-15T12:00   # pin "today" (tests)
Writes partidas.json, partidas.html and partidas.txt into the archive dir.
"""
import argparse, html, json, math, os, re, sys, datetime as dt
# Windows consoles default to cp1252 and crash on non-ASCII at print time — after the work
# is already done. Force UTF-8 so a cosmetic encoding error never masks a successful run.
for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass
from collections import Counter, defaultdict
from pathlib import Path
import harvest

PLAY_IDS = ("long-no-handoff", "strong-on-mechanical", "cold-cache", "compact-no-handoff")
MECH = {"Read", "Grep", "Glob", "Bash", "PowerShell", "WebFetch"}
NOT_MECH = {"Edit", "Write", "NotebookEdit", "Agent", "Task"}
TOK_KEYS = ("input", "output", "cache_read", "cache_write")

def tier_of(rules, model):
    row = rules["models"].get(model) or rules["models"].get(re.sub(r"\[.*\]$", "", model)) or {}
    return row.get("tier")

def judge(s, rules):
    """The four rules, explicit. Each hit is (rule, human detail, the numbers that fired it)."""
    hits, cmds, red = [], s["commands"], rules["red"] * 1000
    if s["peak_context"] >= red and cmds.get("/handoff", 0) == 0:
        hits.append(("long-no-handoff", f"pico de contexto {s['peak_context']} >= {red:.0f} y 0 /handoff",
                     {"peak_context": s["peak_context"], "limit": red, "handoff": 0}))
    tools, models = s["tools"], s["models"]
    total = sum(tools.values())
    if models and total >= 5:
        dom = max(models, key=lambda m: models[m]["output"])
        mech = sum(v for k, v in tools.items() if k in MECH)
        if (tier_of(rules, dom) in ("frontier", "flagship") and mech / total >= 0.8
                and not any(k in NOT_MECH for k in tools)):
            hits.append(("strong-on-mechanical",
                         f"{tier_of(rules, dom)} dominante con {mech} de {total} herramientas de lectura y ninguna de edición",
                         {"tier": tier_of(rules, dom), "tools": total, "mechanical": mech}))
    if s["cold_cache_events"] > 3:
        hits.append(("cold-cache", f"{s['cold_cache_events']} peticiones con hit < {rules['cold']:.0f}% (límite: más de 3)",
                     {"cold_cache_events": s["cold_cache_events"], "cold_below_pct": rules["cold"]}))
    if s["compactions_without_handoff"] >= 1:
        hits.append(("compact-no-handoff", f"{s['compactions_without_handoff']} de {s['compactions']} compactaciones sin /handoff antes",
                     {"compactions_without_handoff": s["compactions_without_handoff"], "compactions": s["compactions"]}))
    return hits

def tokens(s):
    t = dict.fromkeys(TOK_KEYS, 0)
    for group in (s["models"], s["subagents"]):
        for m in group.values():
            for k in TOK_KEYS: t[k] += m[k]
    return t

def agg(rows):
    """Totals for a group of per-session rows. Hit% is weighted over the main-file models
    (read / (input + read + write)), not an average of per-session percentages."""
    t, read, tot = dict.fromkeys(TOK_KEYS, 0), 0, 0
    for r in rows:
        for k in TOK_KEYS: t[k] += r["tokens"][k]
        read += r["_read"]; tot += r["_tot"]
    return {"sessions": len(rows), "turns": sum(r["turns"] for r in rows), "tokens": t,
            "cost_usd": round(sum(r["cost_usd"] for r in rows), 4),
            "hit_pct": round(100 * read / tot, 2) if tot else None,
            "plays": sum(len(r["plays"]) for r in rows)}

def disk_by_project(claude_dir, label_of_dir):
    root = Path(claude_dir) / "projects"
    by = defaultdict(int)
    if root.is_dir():
        for d in sorted(p for p in root.iterdir() if p.is_dir()):
            size = 0
            for base, _, names in os.walk(d):
                for n in names:
                    try: size += os.path.getsize(os.path.join(base, n))
                    except OSError: pass
            by[label_of_dir.get(d.name, "sin-sesiones")] += size
    return sorted(by.items(), key=lambda kv: -kv[1])

# ---------- rendering ----------

def esc(x): return html.escape(str(x), quote=True)

def nice(v):
    if v <= 0: return 1
    e = 10 ** math.floor(math.log10(v))
    return next(m * e for m in (1, 2, 2.5, 5, 10) if v <= m * e)

def human_bytes(n):
    for u in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024 or u == "TB": return f"{n:.0f} {u}" if u == "B" else f"{n:.1f} {u}"
        n /= 1024

def svg_bars(items, fmt, desc):
    """Vertical bars. items = [(label, value)]; hand-written SVG, scales with the container."""
    W, H, L, R, T, B = 480, 210, 46, 8, 16, 28
    top = nice(max(v for _, v in items))
    ph, slot = H - T - B, (W - L - R) / len(items)
    bw = slot * 0.62
    p = [f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="{esc(desc)}">']
    for i in range(4):
        y = T + ph - ph * i / 3
        p.append(f'<line class="gl" x1="{L}" x2="{W-R}" y1="{y:.1f}" y2="{y:.1f}"/>'
                 f'<text class="tx" x="{L-6}" y="{y+4:.1f}" text-anchor="end">{esc(fmt(top * i / 3))}</text>')
    for i, (lab, v) in enumerate(items):
        h, x = ph * v / top, L + slot * i + (slot - bw) / 2
        if v > 0:
            p.append(f'<rect class="bar" x="{x:.1f}" y="{T+ph-h:.1f}" width="{bw:.1f}" height="{h:.1f}"/>'
                     f'<text class="tx" x="{x+bw/2:.1f}" y="{T+ph-h-4:.1f}" text-anchor="middle">{esc(fmt(v))}</text>')
        p.append(f'<text class="tx" x="{x+bw/2:.1f}" y="{H-8}" text-anchor="middle">{esc(lab)}</text>')
    return "".join(p) + "</svg>"

def svg_hbars(items, desc):
    """Horizontal bars. items = [(label, value, value_text)]."""
    W, LW, RW, RH = 480, 130, 84, 26
    top = max(v for _, v, _ in items) or 1
    p = [f'<svg viewBox="0 0 {W} {RH*len(items)+4}" role="img" aria-label="{esc(desc)}">']
    for i, (lab, v, txt) in enumerate(items):
        y, w = i * RH + 4, (W - LW - RW) * v / top
        short = lab if len(lab) <= 17 else lab[:16] + "…"
        p.append(f'<text class="tx" x="{LW-8}" y="{y+15}" text-anchor="end">{esc(short)}</text>'
                 f'<rect class="bar" x="{LW}" y="{y+2}" width="{max(w,1):.1f}" height="{RH-8}"/>'
                 f'<text class="tx" x="{LW+max(w,1)+6:.1f}" y="{y+15}">{esc(txt)}</text>')
    return "".join(p) + "</svg>"

def svg_line(weeks, cold, ok):
    """Hit% per week (0-100) with the cache-cold and cache-hit-ok lines from thresholds.json."""
    W, H, L, R, T, B = 480, 210, 46, 8, 16, 28
    ph, slot = H - T - B, (W - L - R) / len(weeks)
    yy = lambda v: T + ph - ph * v / 100
    p = [f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="hit de caché por semana">']
    for v in (0, 50, 100):
        p.append(f'<line class="gl" x1="{L}" x2="{W-R}" y1="{yy(v):.1f}" y2="{yy(v):.1f}"/>'
                 f'<text class="tx" x="{L-6}" y="{yy(v)+4:.1f}" text-anchor="end">{v}%</text>')
    for v, name, cls in ((cold, "cache-cold", "wl"), (ok, "cache-hit-ok", "ol")):
        p.append(f'<line class="{cls}" x1="{L}" x2="{W-R}" y1="{yy(v):.1f}" y2="{yy(v):.1f}"/>'
                 f'<text class="tx" x="{W-R}" y="{yy(v)-4:.1f}" text-anchor="end">{name} {v:g}%</text>')
    run, pts = [], []
    for i, (lab, v) in enumerate(weeks):
        x = L + slot * i + slot / 2
        p.append(f'<text class="tx" x="{x:.1f}" y="{H-8}" text-anchor="middle">{esc(lab)}</text>')
        if v is None:
            if run: pts.append(run); run = []
        else:
            run.append((x, yy(v), v))
    if run: pts.append(run)
    for seg in pts:
        p.append(f'<polyline class="ln" points="{" ".join(f"{x:.1f},{y:.1f}" for x, y, _ in seg)}"/>')
        for x, y, v in seg:
            p.append(f'<circle class="dot" cx="{x:.1f}" cy="{y:.1f}" r="3.5"/>'
                     f'<text class="tx" x="{x:.1f}" y="{y-8:.1f}" text-anchor="middle">{v:.0f}</text>')
    return "".join(p) + "</svg>"

MONO = '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace'
TEXT = '"Space Grotesk", system-ui, sans-serif'
CSS = """:root{--bg:#FFFFFF;--fg:#1F2328;--muted:#59636E;--accent:#0D9488;--card:#F6F8FA;--line:#D1D9E0;--warn:#9A6700}
@media (prefers-color-scheme:dark){:root{--bg:#0D1117;--fg:#E6EDF3;--muted:#8B949E;--accent:#2DD4BF;--card:#161B22;--line:#30363D;--warn:#E3B341}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 @TEXT@}
main{max-width:880px;margin:0 auto;padding:20px 16px 48px}
h1{font-size:1.5rem;margin:0 0 4px}h2{font-size:1.05rem;margin:32px 0 8px;color:var(--accent)}
.mono,td.n,.k b{font-family:@MONO@}
.sub,.nd,.note{color:var(--muted);font-size:.85rem;margin:2px 0}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(130px,1fr));gap:8px;margin-top:16px}
.k{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:10px 12px}
.k b{display:block;font-size:1.3rem}.k span{color:var(--muted);font-size:.8rem}
svg{width:100%;height:auto;display:block}
.tx{fill:var(--muted);font-size:11px;font-family:@MONO@}
.gl{stroke:var(--line);stroke-width:1}.bar{fill:var(--accent)}
.ln{fill:none;stroke:var(--accent);stroke-width:2}.dot{fill:var(--accent)}
.wl{stroke:var(--warn);stroke-width:1.5;stroke-dasharray:5 4}.ol{stroke:var(--accent);stroke-width:1.5;stroke-dasharray:2 4}
.sc{overflow-x:auto}table{border-collapse:collapse;width:100%;font-size:.85rem}
th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--muted);font-weight:500}td.n{white-space:nowrap}
.tag{color:var(--warn);font-size:.75rem}
"""

def block(title, body, note=""):
    return f"<section><h2>{esc(title)}</h2>{body}" + (f'<p class="note">{esc(note)}</p>' if note else "") + "</section>"

def render_html(d):
    w, th = d["window_weeks"], d["thresholds_used"]
    tot = d["totals"]
    cards = [(tot["sessions"], "sesiones"), (f"{tot['active_hours']:.1f} h", "horas activas"), (tot["turns"], "turnos"),
             (f"${tot['cost_usd']:.2f}", "costo"), ("sin datos" if tot["hit_pct"] is None else f"{tot['hit_pct']:.1f}%", "hit de caché"),
             (tot["plays"], "jugadas")]
    out = [block(f"Últimas {w} semanas", '<div class="cards">' + "".join(
        f'<div class="k"><b>{esc(v)}</b><span>{esc(k)}</span></div>' for v, k in cards) + "</div>",
        f"Ventana {d['window']['from']} a {d['window']['to']}. En todo el archivo: {d['sessions_v2']} sesiones con "
        f"transcrito (juzgables) y {d['sessions_v1_only']} solo v1, cuyo transcrito ya borró el barrido de 30 días.")]
    weeks = d["by_week"][-8:]
    nd = '<p class="nd">sin datos</p>'
    out.append(block("Costo por semana", svg_bars([(x["week"][-3:], x["cost_usd"]) for x in weeks], lambda v: f"${v:.2f}" if v < 10 else f"${v:.0f}", "costo por semana") if weeks else nd,
                     "Costo del harness cuando existe; si no, estimado con la tabla de precios (cota inferior). Últimas 8 semanas."))
    out.append(block("Hit de caché por semana", svg_line([(x["week"][-3:], x["hit_pct"]) for x in weeks], th["cache-cold"], th["cache-hit-ok"]) if weeks else nd,
                     "Lectura de caché sobre entrada + lectura + escritura. Líneas: umbrales cache-cold y cache-hit-ok."))
    prj = d["by_project"][:8]
    if prj:
        cost = svg_hbars([(x["label"], x["cost_usd"], f"${x['cost_usd']:.2f}") for x in prj], "costo por proyecto")
        tk = lambda x: sum(x["tokens"].values())
        toks = svg_hbars([(x["label"], tk(x), f"{tk(x)/1e6:.1f} M") for x in sorted(prj, key=lambda x: -tk(x))], "tokens por proyecto")
        body = "<h3 class='sub'>Costo (USD)</h3>" + cost + "<h3 class='sub'>Tokens (entrada + salida + caché)</h3>" + toks
    else: body = nd
    out.append(block("Costo y tokens por proyecto", body, "Ventana actual; incluye subagentes."))
    hrs = d["start_hours"]
    out.append(block("A qué hora empiezas", svg_bars([(str(h) if h % 3 == 0 else "", c) for h, c in enumerate(hrs)], lambda v: f"{v:.0f}", "sesiones por hora de inicio") if sum(hrs) else nd,
                     "Hora local de inicio de cada sesión de la ventana."))
    if d["plays"]:
        rows = "".join(f"<tr><td class='n'>{p['n']}</td><td>{esc(p['label'])}</td><td class='n'>{esc(p['week'])}</td>"
                       f"<td class='n'>{esc(p['rule'])}{' <span class=tag>heurística</span>' if p['heuristic'] else ''}</td><td>{esc(p['detail'])}</td></tr>"
                       for p in d["plays"])
        body = f"<div class='sc'><table><tr><th>#</th><th>proyecto</th><th>semana</th><th>regla</th><th>números</th></tr>{rows}</table></div>"
    else: body = '<p class="nd">sin jugadas en la ventana</p>'
    out.append(block("Jugadas", body, f"long-no-handoff: contexto >= {th['context-red']:g}k sin /handoff · strong-on-mechanical: modelo frontier/flagship en trabajo de lectura (heurística) · cold-cache: más de 3 peticiones con hit < {th['cache-cold']:g}% · compact-no-handoff: compactación sin /handoff previo."))
    dk = d["disk_by_project"][:12]
    out.append(block("Disco por proyecto", svg_hbars([(x["label"], x["bytes"], human_bytes(x["bytes"])) for x in dk], "disco por proyecto") if dk else nd,
                     "Bytes de todo lo que hay bajo projects/ (subcarpetas incluidas), por proyecto."))
    return ('<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>Partidas</title><style>{CSS.replace("@MONO@", MONO).replace("@TEXT@", TEXT)}</style></head><body><main><h1>Partidas</h1>'
            f'<p class="sub">Tus sesiones de Claude Code como partidas · generado {esc(d["generated"][:16])}</p>'
            + "".join(out) + "</main></body></html>\n")

def render_txt(d):
    w, t, th = d["window_weeks"], d["totals"], d["thresholds_used"]
    if not t["sessions"]:
        return f"PARTIDAS · últimas {w} semanas ({d['window']['from']} a {d['window']['to']})\nsin datos: ninguna sesión v2 en la ventana (solo v1: {d['sessions_v1_only']}).\n"
    hit = lambda x: "sin datos" if x is None else f"{x:.1f}%"
    cnt = Counter(p["rule"] for p in d["plays"])
    top = " · ".join(f"{x['label']} ${x['cost_usd']:.2f}" for x in d["by_project"][:3])
    prev = d["previous_window"]
    if prev.get("v1_only"):
        # The 30-day sweep deleted those transcripts: what is left of that window is a sample,
        # and its v1 records double-count tokens. A delta against it would be noise, not news.
        change = (f"sin comparación: las {w} semanas anteriores solo conservan {prev['sessions']} sesiones con "
                  f"transcrito; otras {prev['v1_only']} están solo en el archivo v1 (el barrido de 30 días borró "
                  f"sus transcritos).")
    elif prev["sessions"]:
        change = (f"Frente a las {w} semanas anteriores: costo ${prev['cost_usd']:.2f} → ${t['cost_usd']:.2f}, "
                  f"hit {hit(prev['hit_pct'])} → {hit(t['hit_pct'])}, jugadas {prev['plays']} → {t['plays']}.")
    else:
        change = f"No hay sesiones v2 en las {w} semanas anteriores para comparar."
    lines = [f"PARTIDAS · últimas {w} semanas ({d['window']['from']} a {d['window']['to']})",
             f"Sesiones: {t['sessions']} · turnos: {t['turns']} · horas activas: {t['active_hours']:.1f}",
             f"Costo: ${t['cost_usd']:.2f} ({t['cost_harness']} sesiones con costo del harness, {t['cost_estimate']} estimadas: cota inferior)",
             f"Caché: hit {hit(t['hit_pct'])} (frío < {th['cache-cold']:g}%, bueno >= {th['cache-hit-ok']:g}%)",
             f"Proyectos por costo: {top}",
             "Jugadas: " + " · ".join(f"{r} {cnt.get(r, 0)}" for r in PLAY_IDS),
             "strong-on-mechanical es una heurística: modelo fuerte en trabajo de lectura, sin ediciones.",
             "Cambió: " + change]
    return "\n".join(lines) + "\n"

# ---------- main ----------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", default=str(Path.home() / "claude-archive"))
    ap.add_argument("--claude-dir", default=os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude")))
    ap.add_argument("--weeks", type=int, default=4)
    ap.add_argument("--now", default=None)
    a = ap.parse_args()

    rules = harvest.load_rules(a.claude_dir)
    try: now = dt.datetime.fromisoformat(a.now.replace("Z", "+00:00")) if a.now else dt.datetime.now()
    except ValueError: harvest.die(f"--now no es una fecha ISO: {a.now}")
    now = now.astimezone()  # a naive --now means local time
    protect = os.environ.get("KIT_PROTECTED_PATHS", "")
    try: protect_re = re.compile(protect) if protect else None
    except re.error as e: harvest.die(f"KIT_PROTECTED_PATHS no es una expresión válida ({e}).")

    store = Path(a.archive) / "sessions.json"
    try: sessions = json.loads(store.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e: harvest.die(f"No pude leer {store} ({e}). Corre harvest.py primero.")
    v2 = [s for s in sessions if s.get("harvest_version") == harvest.HARVEST_VERSION]
    v1_only = len(sessions) - len(v2)

    hidden = {}
    def shown(label):
        if protect_re and protect_re.search(label):
            return hidden.setdefault(label, f"privado-{len(hidden) + 1}")
        return label
    for lab in sorted({s["project_label"] for s in v2}): shown(lab)

    placed = sorted((s for s in v2 if harvest.parse_ts(s.get("first_seen"))), key=lambda s: harvest.parse_ts(s["first_seen"]))
    span = dt.timedelta(weeks=a.weeks)
    def in_range(s, lo, hi): return lo <= harvest.parse_ts(s["first_seen"]).astimezone() <= hi
    win = [s for s in placed if in_range(s, now - span, now)]
    prev = [s for s in placed if in_range(s, now - 2 * span, now - span) and not in_range(s, now - span, now)]

    def row(s, n):
        t0 = harvest.parse_ts(s["first_seen"]).astimezone()
        y, wk, _ = t0.isocalendar()
        plays = judge(s, rules)
        tk = tokens(s)
        return {"n": n, "week": f"{y}-W{wk:02d}", "date": t0.date().isoformat(), "label": shown(s["project_label"]),
                "start_hour": t0.hour, "turns": s["turns"], "tokens": tk, "cost_usd": s["cost_usd"], "cost_source": s["cost_source"],
                "hit_pct": s["hit_pct"], "peak_context": s["peak_context"], "cold_cache_events": s["cold_cache_events"],
                "compactions": s["compactions"], "compactions_without_handoff": s["compactions_without_handoff"],
                "commands": s["commands"], "active_min": round(s["active_ms"] / 60000, 1), "duration_min": s["duration_min"],
                "bytes": s["bytes"], "plays": [p[0] for p in plays], "_plays": plays,
                "_read": sum(m["cache_read"] for m in s["models"].values()),
                "_tot": sum(m["input"] + m["cache_read"] + m["cache_write"] for m in s["models"].values())}
    prev_v1 = sum(1 for s in sessions if s.get("harvest_version") != harvest.HARVEST_VERSION
                  and harvest.parse_ts(s.get("first_seen")) and in_range(s, now - 2 * span, now - span))
    rows = [row(s, i) for i, s in enumerate(win, 1)]
    prev_rows = [row(s, i) for i, s in enumerate(prev, 1)]
    all_rows = [row(s, i) for i, s in enumerate(placed, 1)]

    plays = [{"n": r["n"], "label": r["label"], "week": r["week"], "rule": rule, "detail": detail, "values": vals,
              "heuristic": rule == "strong-on-mechanical"} for r in rows for rule, detail, vals in r["_plays"]]
    totals = agg(rows)
    totals.update(active_hours=round(sum(r["active_min"] for r in rows) / 60, 2),
                  cost_harness=sum(r["cost_source"] == "harness" for r in rows),
                  cost_estimate=sum(r["cost_source"] == "estimate" for r in rows))
    by_week = []
    for wk in sorted({r["week"] for r in all_rows}):
        by_week.append({"week": wk, **agg([r for r in all_rows if r["week"] == wk])})
    by_project = sorted(({"label": lab, **agg([r for r in rows if r["label"] == lab])} for lab in {r["label"] for r in rows}),
                        key=lambda x: (-x["cost_usd"], x["label"]))
    per_dir = defaultdict(Counter)
    for s in v2: per_dir[s["project"]][shown(s["project_label"])] += 1
    disk = [{"label": shown(lab) if lab != "sin-sesiones" else lab, "bytes": b}
            for lab, b in disk_by_project(a.claude_dir, {d: c.most_common(1)[0][0] for d, c in per_dir.items()})]
    hours = [0] * 24
    for r in rows: hours[r["start_hour"]] += 1
    num = lambda v: int(v) if v == int(v) else v
    data = {"generated": now.isoformat(timespec="seconds"), "window_weeks": a.weeks,
            "window": {"from": (now - span).date().isoformat(), "to": now.date().isoformat()},
            "thresholds_used": {"context-red": num(rules["red"]), "cache-cold": num(rules["cold"]), "cache-hit-ok": num(rules["ok"])},
            "sessions_v2": len(v2), "sessions_v1_only": v1_only, "totals": totals,
            "previous_window": {**agg(prev_rows), "v1_only": prev_v1},
            "per_session": [{k: v for k, v in r.items() if not k.startswith("_")} for r in rows],
            "by_project": by_project, "by_week": by_week, "plays": plays,
            "disk_by_project": disk, "start_hours": hours}

    out = Path(a.archive)
    for name, text in (("partidas.json", json.dumps(data, indent=1, ensure_ascii=False) + "\n"),
                       ("partidas.html", render_html(data)), ("partidas.txt", render_txt(data))):
        with open(out / name, "w", encoding="utf-8", newline="\n") as fh: fh.write(text)
    print(f"partidas: {len(v2)} sesiones v2 ({len(rows)} en las últimas {a.weeks} semanas), {v1_only} solo v1, {len(plays)} jugadas → {out}")

if __name__ == "__main__":
    main()
