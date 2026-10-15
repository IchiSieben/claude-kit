#!/usr/bin/env python3
"""
bitacora.py — one local page answering "where did each project stop and where do I resume?".

WHY: ~40 sibling repos, and the state of each lives in a different place (HANDOFF.md, git,
history.jsonl, the harvested session summaries). This reads them all and renders one
self-contained HTML (plus a JSON twin) so the answer is a glance, not an archaeology dig.
Contract: SPEC-bitacora.md.

WHAT IT DOES NOT DO: it never writes inside the repos or ~/.claude, never touches the network
(no fetch), never exports prompt text to the JSON unless --include-prompts, and does not chart
tokens over time, show live sessions or quota (that is the enjambre visor). A missing source
degrades the card ("sin handoff", "—"); it never aborts the run.

Usage:
    python bitacora.py                      # writes bitacora.html + bitacora.json to ~/claude-archive
    python bitacora.py --dry-run            # list detected projects and the source of each field
    python bitacora.py --out DIR            # default ~/claude-archive
    python bitacora.py --root DIR           # default: the folder that holds this repo
    python bitacora.py --include-prompts    # also put the last prompt text in the JSON
    python bitacora.py --now 2026-10-15     # pin "today" (tests)
Other flags: --projects FILE, --claude-dir DIR (history.jsonl), --archive DIR (sessions.json),
--visor-dir DIR.
"""
import argparse, html, json, os, re, subprocess, sys, datetime as dt
# Windows consoles default to cp1252 and crash on non-ASCII at print time — after the work
# is already done. Force UTF-8 so a cosmetic encoding error never masks a successful run.
for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass
from pathlib import Path

try:
    import tomllib
except Exception:  # python < 3.11
    tomllib = None

HERE = Path(__file__).resolve().parent
HOME = Path.home()
ACTIVE_DAYS, PARKED_DAYS, WINDOW_DAYS = 14, 90, 30
HANDOFF_KEYS = ["IN PROGRESS", "EN CURSO", "BLOCKED", "BLOQUEADO", "Próximo", "Next"]
SKIP_NAMES = {"node_modules"}


# ---------------------------------------------------------------- helpers

def parse_when(v):
    """ISO string / epoch (s or ms) -> aware UTC datetime, or None."""
    if v in (None, ""): return None
    try:
        if isinstance(v, (int, float)):
            return dt.datetime.fromtimestamp(v / (1000 if v > 1e11 else 1), dt.timezone.utc)
        s = str(v).strip().replace("Z", "+00:00")
        d = dt.datetime.fromisoformat(s)
        return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None

def norm(p):
    """Comparable form of a path: forward slashes, lower case, no trailing slash."""
    return str(p).replace("\\", "/").rstrip("/").lower()

def encode_dir(p):
    """Claude Code's project dir name for an absolute path."""
    return re.sub(r"[:\\/._ ]", "-", str(p))

def trunc(s, n):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[:n - 1] + "…"

def days_between(now, then):
    return max(0, int((now - then).total_seconds() // 86400))

def ago(days):
    if days is None: return "—"
    return "hoy" if days == 0 else f"hace {days} d"

def clean_url(u):
    """Drop credentials from a URL (https://user:tok@host/...)."""
    return re.sub(r"//[^/@\s]+@", "//", u or "")

def remote_to_web(u):
    u = (u or "").strip()
    if not u: return ""
    m = re.match(r"^(?:ssh://)?git@([^:/]+)[:/](.+)$", u)
    if m: u = f"https://{m.group(1)}/{m.group(2)}"
    u = clean_url(u)
    if u.endswith(".git"): u = u[:-4]
    return u if re.match(r"^https?://", u) else ""

def web_url(u):
    u = (u or "").strip()
    if not u: return ""
    if not re.match(r"^[a-z]+://", u): u = "https://" + u
    return u if re.match(r"^https?://", u) else ""

def git(d, *args):
    """stdout of a git call (10 s timeout, no index.lock), or None on any failure."""
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0")
    try:
        r = subprocess.run(["git", "-C", str(d), *args], capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=10, env=env)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


# ---------------------------------------------------------------- discovery

def load_toml(path):
    if tomllib is None or not path.is_file(): return []
    try:
        with open(path, "rb") as f:
            return tomllib.load(f).get("project", [])
    except Exception as e:
        print(f"aviso: projects.toml ilegible ({e})", file=sys.stderr)
        return []

def discover(root, entries):
    """-> (projects, missing_toml). Each project: dict(name, path, toml, kind)."""
    found = {}
    missing = []
    for e in entries:
        rel = str(e.get("path", "")).strip()
        if not rel: continue
        p = root / rel
        if p.is_dir():
            found[norm(p.resolve())] = {"name": e.get("name") or p.name, "path": p, "toml": e}
        else:
            missing.append({"name": e.get("name") or rel, "path": rel})
    if root.is_dir():
        for c in sorted(root.iterdir(), key=lambda x: x.name):
            if not c.is_dir() or c.name.startswith(("_", ".")) or c.name in SKIP_NAMES: continue
            if (c / ".git").exists() or (c / "HANDOFF.md").is_file():
                found.setdefault(norm(c.resolve()), {"name": c.name, "path": c, "toml": None})
    projects = sorted(found.values(), key=lambda x: (x["name"].lower(), norm(x["path"])))
    for pr in projects:
        pr["worktrees"] = []
        pr["aliases"] = []
    # fold worktrees (.git is a FILE) under their main repo's card
    index = {norm(pr["path"].resolve()): pr for pr in projects}
    kept = []
    for pr in projects:
        g = pr["path"] / ".git"
        if g.is_file():
            common = git(pr["path"], "rev-parse", "--path-format=absolute", "--git-common-dir")
            if common:
                main = Path(common)
                main_dir = main.parent if main.name == ".git" else main
                host = index.get(norm(main_dir.resolve()))
                if host is not None and host is not pr:
                    host["worktrees"].append(pr["path"].name)
                    host["aliases"].append(pr["path"])
                    continue
        kept.append(pr)
    return kept, sorted(missing, key=lambda m: m["name"].lower())


# ---------------------------------------------------------------- per-source readers

def read_handoff(d):
    """-> dict(present, line, age_days_mtime source) for <d>/HANDOFF.md."""
    f = d / "HANDOFF.md"
    if not f.is_file(): return {"present": False}
    try:
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        mtime = dt.datetime.fromtimestamp(f.stat().st_mtime, dt.timezone.utc)
    except Exception:
        return {"present": False}
    def strip(l):
        return re.sub(r"^[\s#>*\-+]+", "", l).replace("**", "").replace("`", "").strip()
    line = None
    for i, raw in enumerate(lines):
        t = strip(raw)
        for k in HANDOFF_KEYS:
            if t.lower().startswith(k.lower()) and not (len(t) > len(k) and t[len(k)].isalnum()):
                rest = t[len(k):].strip(" :-—")
                if rest:
                    line = t
                else:
                    for nxt in lines[i + 1:]:
                        n = strip(nxt)
                        if n and not nxt.lstrip().startswith("#"):
                            line = f"{k}: {n}"; break
                break
        if line: break
    if not line:
        for raw in lines:
            if raw.strip() and not raw.lstrip().startswith("#"):
                line = strip(raw); break
    return {"present": True, "line": trunc(line or "(vacío)", 160), "mtime": mtime}

def read_git(d):
    if not (d / ".git").exists(): return {"present": False}
    g = {"present": True}
    g["branch"] = git(d, "rev-parse", "--abbrev-ref", "HEAD")
    last = git(d, "log", "-1", "--format=%h%x1f%s%x1f%cI")
    if last and last.count("\x1f") == 2:
        h, s, c = last.split("\x1f")
        g["commit"] = {"hash": h, "subject": trunc(s, 80), "date": c}
    st = git(d, "status", "--porcelain")
    g["dirty"] = None if st is None else len([x for x in st.splitlines() if x.strip()])
    ab = git(d, "rev-list", "--left-right", "--count", "@{u}...HEAD")
    if ab and len(ab.split()) == 2:
        g["behind"], g["ahead"] = (int(x) for x in ab.split())
    g["remote"] = remote_to_web(git(d, "config", "--get", "remote.origin.url") or "")
    return g

def read_history(path, projects):
    """Latest prompt per project from history.jsonl. -> (map name->(ts, text), count map)."""
    latest, counts = {}, {}
    if not path.is_file(): return latest, counts, False
    keyed = []
    for pr in projects:
        for p in [pr["path"], *pr["aliases"]]:
            keyed.append((norm(p), pr["name"]))
    keyed.sort(key=lambda x: -len(x[0]))
    cache = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for raw in f:
                try: r = json.loads(raw)
                except Exception: continue
                if not isinstance(r, dict): continue
                pp = r.get("project")
                if not isinstance(pp, str): continue
                if pp not in cache:
                    n = norm(pp)
                    cache[pp] = next((nm for k, nm in keyed if n == k or n.startswith(k + "/")), None)
                nm = cache[pp]
                if nm is None: continue
                ts = parse_when(r.get("timestamp"))
                if ts is None: continue
                counts[nm] = counts.get(nm, 0) + 1
                if nm not in latest or ts >= latest[nm][0]:
                    latest[nm] = (ts, str(r.get("display") or ""))
    except Exception as e:
        print(f"aviso: history.jsonl ilegible ({e})", file=sys.stderr)
    return latest, counts, True

def read_sessions(path, projects, now):
    """Per project: last session time + 30-day totals. -> (map, present)."""
    out = {}
    if not path.is_file(): return out, False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, dict): data = data.get("sessions", list(data.values()))
    except Exception as e:
        print(f"aviso: sessions.json ilegible ({e})", file=sys.stderr)
        return out, False
    keyed = []
    for pr in projects:
        for p in [pr["path"], *pr["aliases"]]:
            keyed.append((encode_dir(p.resolve()).lower(), pr["name"]))
    keyed.sort(key=lambda x: -len(x[0]))
    cut = now - dt.timedelta(days=WINDOW_DAYS)
    for s in data if isinstance(data, list) else []:
        if not isinstance(s, dict) or not isinstance(s.get("project"), str): continue
        n = s["project"].lower()
        nm = next((nm for k, nm in keyed if n == k or n.startswith(k + "-")), None)
        if nm is None: continue
        o = out.setdefault(nm, {"last": None, "sessions": 0, "input": 0, "output": 0,
                                "cache_read": 0, "cache_write": 0, "cost_usd": 0.0, "has_tokens": False})
        last = parse_when(s.get("last_seen")) or parse_when(s.get("first_seen"))
        if last and (o["last"] is None or last > o["last"]): o["last"] = last
        if last and last >= cut:
            o["sessions"] += 1
            models = s.get("models") or {}
            tot_cost = 0.0
            for m in models.values():
                if not isinstance(m, dict): continue
                for k in ("input", "output", "cache_read", "cache_write"):
                    v = m.get(k) or 0
                    if v: o["has_tokens"] = True
                    o[k] += v
                tot_cost += m.get("cost_usd") or 0.0
            o["cost_usd"] += s["cost_usd"] if isinstance(s.get("cost_usd"), (int, float)) else tot_cost
    return out, True


# ---------------------------------------------------------------- assemble

def classify(last, now):
    if last is None: return "archivado"
    d = days_between(now, last)
    return "activo" if d <= ACTIVE_DAYS else "parado" if d <= PARKED_DAYS else "archivado"

def build(args, now):
    root = Path(args.root).expanduser()
    projects_file = Path(args.projects) if args.projects else HERE / "projects.toml"
    projects, missing = discover(root, load_toml(projects_file))
    hist_path = Path(args.claude_dir).expanduser() / "history.jsonl"
    sess_path = Path(args.archive).expanduser() / "sessions.json"
    hist, hist_n, hist_ok = read_history(hist_path, projects)
    sess, sess_ok = read_sessions(sess_path, projects, now)
    cards = []
    for pr in projects:
        d, nm, t = pr["path"], pr["name"], pr["toml"] or {}
        src = {}
        g = read_git(d)
        src["git"] = "git" if g["present"] else "— (sin .git)"
        h = read_handoff(d)
        src["handoff"] = "HANDOFF.md" if h["present"] else "— (sin handoff)"
        cands = []
        if g.get("commit"):
            c = parse_when(g["commit"]["date"])
            if c: cands.append((c, "git"))
        lp = hist.get(nm)
        if lp: cands.append((lp[0], "history.jsonl"))
        ss = sess.get(nm)
        if ss and ss["last"]: cands.append((ss["last"], "sessions.json"))
        last, last_src = max(cands, key=lambda x: x[0]) if cands else (None, "—")
        src["last_activity"] = last_src
        src["last_prompt"] = "history.jsonl" if lp else "—"
        src["tokens_30d"] = "sessions.json" if (ss and ss["has_tokens"]) else "—"
        src["links"] = "projects.toml" if pr["toml"] else "derivado (git/carpeta)"
        card = {
            "name": nm,
            "path": str(d),
            "status": classify(last, now),
            "last_activity": last.isoformat() if last else None,
            "last_activity_source": last_src,
            "last_activity_days": days_between(now, last) if last else None,
            "git": {k: v for k, v in g.items()},
            "handoff": ({"present": True, "line": h["line"], "age_days": days_between(now, h["mtime"])}
                        if h["present"] else {"present": False}),
            "last_prompt_at": lp[0].isoformat() if lp else None,
            "prompts_matched": hist_n.get(nm, 0),
            "tokens_30d": None,
            "worktrees": sorted(pr["worktrees"]),
            "one_line": t.get("one_line") or "",
            "links": {
                "folder": d.resolve().as_uri(),
                "github": web_url(t.get("repo", "").removesuffix(".git")) or g.get("remote", ""),
                "site": web_url(t.get("domain", "")),
                "drive": (t.get("drive") or "").strip(),
            },
            "_sources": src,
            "_prompt_text": trunc(lp[1], 140) if lp and lp[1].strip() else "",
        }
        if ss and ss["has_tokens"]:
            card["tokens_30d"] = {k: ss[k] for k in ("sessions", "input", "output", "cache_read", "cache_write")}
            card["tokens_30d"]["cost_usd"] = round(ss["cost_usd"], 4)
        cards.append(card)
    cards.sort(key=lambda c: (c["last_activity"] is None, _neg(c["last_activity"]), c["name"].lower()))
    return cards, missing, {"history": hist_ok, "sessions": sess_ok}

def _neg(iso):
    d = parse_when(iso)
    return -d.timestamp() if d else 0


# ---------------------------------------------------------------- render

CSS = """
:root{--bg:#0D1117;--fg:#E6EDF3;--muted:#8B949E;--accent:#2DD4BF;--accent-strong:#2DD4BF;--line:#30363D;--card:#161B22;
--mono:"JetBrains Mono",ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;--text:"Space Grotesk",system-ui,sans-serif}
@media (prefers-color-scheme:light){:root{--bg:#FFFFFF;--fg:#1F2328;--muted:#59636E;--accent:#0D9488;--accent-strong:#0F766E;--line:#D1D9E0;--card:#F6F8FA}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 var(--text);overflow-wrap:anywhere}
.wrap{max-width:1100px;margin:0 auto;padding:16px}
h1{font-size:1.4rem;margin:0 0 4px}
a{color:var(--accent-strong)}
.muted{color:var(--muted)}
.mono{font-family:var(--mono);font-size:.82rem}
.head{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:baseline;margin-bottom:12px}
.filters{display:flex;gap:8px;margin:8px 0 16px;flex-wrap:wrap}
.filters button{font:inherit;background:var(--card);color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:6px 12px;cursor:pointer}
.filters button[aria-pressed=true]{border-color:var(--accent);color:var(--accent-strong)}
.grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fill,minmax(min(100%,320px),1fr))}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px;min-width:0}
.card h2{font-size:1.05rem;margin:0 0 6px;display:flex;justify-content:space-between;gap:8px;align-items:baseline}
.badge{font:600 .72rem var(--mono);border:1px solid var(--line);border-radius:99px;padding:1px 8px;white-space:nowrap}
.badge.activo{color:var(--accent-strong);border-color:var(--accent)}
.row{margin:4px 0}
.k{color:var(--muted);font:.78rem var(--mono);display:block}
.btns{display:flex;flex-wrap:wrap;gap:6px;margin-top:10px}
.btn{font:.8rem var(--mono);border:1px solid var(--line);border-radius:6px;padding:3px 8px;text-decoration:none}
.warn{color:var(--accent-strong)}
details{margin-top:24px}
footer{margin-top:24px;color:var(--muted);font-size:.85rem}
"""

JS = """
(function(){var f=document.getElementById('filters');if(!f)return;f.hidden=false;
var cs=document.querySelectorAll('.card');
f.addEventListener('click',function(e){var b=e.target.closest('button');if(!b)return;
var v=b.getAttribute('data-f');
f.querySelectorAll('button').forEach(function(x){x.setAttribute('aria-pressed',x===b?'true':'false')});
cs.forEach(function(c){var s=c.getAttribute('data-status');
c.hidden=!(v==='todos'||(v==='activos'&&s==='activo')||(v==='parados'&&s==='parado'))})})})();
"""

def e(s): return html.escape(str(s), quote=True)

def render_card(c):
    g, h = c["git"], c["handoff"]
    rows = []
    last = c["last_activity"]
    rows.append(f'<div class="row"><span class="k">última actividad ({e(c["last_activity_source"])})</span>'
                f'{e(ago(c["last_activity_days"]))}</div>')
    if c["one_line"]:
        rows.append(f'<div class="row muted">{e(trunc(c["one_line"], 160))}</div>')
    if h["present"]:
        rows.append(f'<div class="row"><span class="k">handoff · {e(ago(h["age_days"]))}</span>{e(h["line"])}</div>')
    else:
        rows.append('<div class="row"><span class="k">handoff</span><span class="warn">sin handoff</span></div>')
    if g["present"]:
        cm = g.get("commit")
        if cm:
            txt = f'{cm["hash"]} {cm["subject"]} · {cm["date"][:10]}'
        else:
            txt = "—"
        dirty = g.get("dirty")
        extra = "cambios sin commitear: —" if dirty is None else (
            f"{dirty} archivos sin commitear" if dirty else "limpio")
        if "ahead" in g and (g["ahead"] or g["behind"]):
            extra += f' · ↑{g["ahead"]} ↓{g["behind"]}'
        rows.append(f'<div class="row"><span class="k">git · {e(g.get("branch") or "—")}</span>'
                    f'<span class="mono">{e(txt)}</span><br>{e(extra)}</div>')
    else:
        rows.append('<div class="row"><span class="k">git</span>sin git</div>')
    if c["last_prompt_at"]:
        d = parse_when(c["last_prompt_at"])
        txt = c["_prompt_text"]
        rows.append(f'<div class="row"><span class="k">último prompt · {e(c["last_prompt_at"][:10])}</span>'
                    f'{e(txt) if txt else "—"}</div>')
    t = c["tokens_30d"]
    if t:
        rows.append(f'<div class="row"><span class="k">30 días</span>'
                    f'{t["input"] + t["output"]:,} tokens (in+out) · ${t["cost_usd"]:.2f}</div>')
    if c["worktrees"]:
        rows.append(f'<div class="row muted">worktrees: {e(", ".join(c["worktrees"]))}</div>')
    L = c["links"]
    b = [f'<a class="btn" href="{e(L["folder"])}">carpeta</a>']
    if L["github"]: b.append(f'<a class="btn" href="{e(L["github"])}">GitHub</a>')
    if L["site"]: b.append(f'<a class="btn" href="{e(L["site"])}">sitio</a>')
    if L["drive"]:
        if re.match(r"^https?://", L["drive"]):
            b.append(f'<a class="btn" href="{e(L["drive"])}">Drive</a>')
        else:
            b.append(f'<span class="btn" title="{e(L["drive"])}">Drive: {e(trunc(L["drive"], 40))}</span>')
    return (f'<article class="card" data-status="{e(c["status"])}"><h2><span>{e(c["name"])}</span>'
            f'<span class="badge {e(c["status"])}">{e(c["status"])}</span></h2>'
            + "".join(rows) + f'<div class="btns">{"".join(b)}</div></article>')

def render_html(cards, missing, links, generated):
    n = {s: sum(1 for c in cards if c["status"] == s) for s in ("activo", "parado", "archivado")}
    head_links = []
    head_links.append(f'<a href="{e(links["visor"])}">visor de enjambre</a>' if links["visor"]
                      else '<span class="muted">visor de enjambre: no instalado</span>')
    if links["partidas"]:
        head_links.append(f'<a href="{e(links["partidas"])}">partidas</a>')
    miss = ""
    if missing:
        li = "".join(f'<li class="mono">{e(m["name"])} → {e(m["path"])}</li>' for m in missing)
        miss = (f'<details><summary>en projects.toml pero no en disco ({len(missing)})</summary>'
                f'<ul>{li}</ul></details>')
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bitácora</title><style>{CSS}</style></head><body><div class="wrap">
<div class="head"><h1>Bitácora</h1><span class="muted">{n["activo"]} activos · {n["parado"]} parados · {n["archivado"]} archivados</span>
<span>{" · ".join(head_links)}</span></div>
<div class="filters" id="filters" hidden>
<button data-f="todos" aria-pressed="true">todos</button><button data-f="activos" aria-pressed="false">activos</button><button data-f="parados" aria-pressed="false">parados</button></div>
<div class="grid">
{chr(10).join(render_card(c) for c in cards)}
</div>
{miss}
<footer>Aquí: estado por proyecto (handoff, git, último prompt, 30 días). Sesiones en vivo, cuota y tokens en el tiempo: visor de enjambre. Gasto por partida: partidas.html.
<br><span class="mono">generado <time data-generated>{e(generated)}</time></span></footer>
</div><script>{JS}</script></body></html>
"""

def find_links(args):
    visor = ""
    vd = Path(args.visor_dir).expanduser()
    if vd.is_dir():
        hs = sorted(vd.glob("*.html"))
        if hs: visor = hs[0].resolve().as_uri()
    pa = Path(args.archive).expanduser() / "partidas.html"
    return {"visor": visor, "partidas": pa.resolve().as_uri() if pa.is_file() else ""}


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description="Bitácora: where did each project stop?")
    # Default root: the folder holding this repo, i.e. its sibling repos. No personal path.
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--projects", default=None)
    ap.add_argument("--claude-dir", default=str(HOME / ".claude"))
    ap.add_argument("--archive", default=str(HOME / "claude-archive"))
    ap.add_argument("--out", default=None)
    ap.add_argument("--visor-dir", default=str(HOME / ".enjambre" / "visor"))
    ap.add_argument("--include-prompts", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--now", default=None)
    args = ap.parse_args()
    now = parse_when(args.now) if args.now else dt.datetime.now(dt.timezone.utc)
    if now is None:
        print("--now ilegible", file=sys.stderr); return 2
    cards, missing, avail = build(args, now)

    if args.dry_run:
        print(f"root: {args.root}  ·  {len(cards)} proyectos  ·  {len(missing)} en projects.toml sin carpeta")
        print(f"fuentes: history.jsonl {'ok' if avail['history'] else 'NO ENCONTRADO'}, "
              f"sessions.json {'ok' if avail['sessions'] else 'NO ENCONTRADO'}")
        for c in cards:
            print(f"- {c['name']}  [{c['status']}]  {c['path']}")
            for k, v in c["_sources"].items():
                print(f"    {k:14} <- {v}")
            if c["worktrees"]: print(f"    worktrees      : {', '.join(c['worktrees'])}")
        for m in missing: print(f"- (sin carpeta) {m['name']} -> {m['path']}")
        print("dry-run: no se escribió nada")
        return 0

    out = Path(args.out).expanduser() if args.out else Path(args.archive).expanduser()
    out.mkdir(parents=True, exist_ok=True)
    generated = now.strftime("%Y-%m-%d %H:%M UTC")
    links = find_links(args)
    page = render_html(cards, missing, links, generated)
    pub = []
    for c in cards:
        x = {k: v for k, v in c.items() if not k.startswith("_")}
        if args.include_prompts: x["last_prompt"] = c["_prompt_text"]
        pub.append(x)
    data = {"generated": generated, "root": str(Path(args.root).expanduser()), "projects": pub,
            "missing_in_disk": missing, "links": links}
    with open(out / "bitacora.html", "w", encoding="utf-8", newline="\n") as f: f.write(page)
    with open(out / "bitacora.json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True); f.write("\n")
    print(f"{len(cards)} proyectos -> {out / 'bitacora.html'}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
