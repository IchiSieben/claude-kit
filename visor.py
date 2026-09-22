#!/usr/bin/env python3
"""
visor.py — un vistazo a tus sesiones de Claude Code, resumido.

Tres bloques: esta sesion, las sesiones vivas en paralelo, y el consumo rodante.
Lee los transcripts locales (~/.claude/projects/<proyecto>/<sesion>.jsonl). Solo metadatos.

Limite honesto: la cuota RESTANTE (5h/7d) no esta en los transcripts; solo la expone el
payload de la status line. Aqui ves lo CONSUMIDO en cada ventana, que es la tendencia.

Uso:  python visor.py [--session <id>] [--live-min 15] [--claude-dir DIR] [--no-color]
"""
import argparse, json, os, re, sys, time, datetime as dt
from collections import defaultdict
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass

# Pesos relativos a un token de input fresco. cache_read ~0.10x esta documentado;
# los otros son los multiplicadores estandar de la API. Sirven para COMPARAR, no para facturar.
W = {"input": 1.0, "cache_read": 0.10, "cache_write": 1.25, "output": 5.0}
C = {"r":"\033[31m","y":"\033[33m","g":"\033[32m","b":"\033[1m","d":"\033[2m","m":"\033[35m","c":"\033[36m","x":"\033[0m"}

def nocolor():
    for k in C: C[k] = ""

def dig(o, *paths):
    for p in paths:
        cur = o; ok = True
        for part in p.split("."):
            if isinstance(cur, dict) and part in cur: cur = cur[part]
            else: ok = False; break
        if ok and cur is not None: return cur
    return None

def ts_of(rec):
    t = dig(rec, "timestamp", "ts", "time", "message.timestamp")
    if isinstance(t, (int, float)):
        return t / (1000 if t > 1e11 else 1)
    if isinstance(t, str):
        try: return dt.datetime.fromisoformat(t.replace("Z", "+00:00")).timestamp()
        except ValueError: return None
    return None

def scan(path, since=None):
    """Devuelve agregados de un transcript, opcionalmente solo desde un timestamp."""
    a = {"models": defaultdict(lambda: defaultdict(int)), "skills": defaultdict(int),
         "agents": defaultdict(int), "tools": defaultdict(int),
         "first": None, "last": None, "turns": 0, "cost": 0.0}
    try: fh = path.open(encoding="utf-8", errors="replace")
    except OSError: return a
    with fh:
        for line in fh:
            line = line.strip()
            if not line: continue
            try: r = json.loads(line)
            except json.JSONDecodeError: continue
            if not isinstance(r, dict): continue
            t = ts_of(r)
            if t is not None:
                if a["first"] is None or t < a["first"]: a["first"] = t
                if a["last"]  is None or t > a["last"]:  a["last"]  = t
            if since is not None and (t is None or t < since): continue
            if dig(r, "message.role", "role", "type") in ("user", "user_message"): a["turns"] += 1
            u = dig(r, "message.usage", "usage")
            if isinstance(u, dict):
                m = a["models"][dig(r, "message.model", "model") or "?"]
                m["input"]       += u.get("input_tokens", 0) or 0
                m["output"]      += u.get("output_tokens", 0) or 0
                m["cache_read"]  += u.get("cache_read_input_tokens", 0) or 0
                m["cache_write"] += u.get("cache_creation_input_tokens", 0) or 0
                m["req"] += 1
                c = dig(r, "costUSD", "cost_usd", "message.cost_usd")
                if isinstance(c, (int, float)): a["cost"] += float(c)
            blocks = dig(r, "message.content", "content")
            if isinstance(blocks, list):
                for b in blocks:
                    if isinstance(b, dict) and b.get("type") == "tool_use":
                        n = b.get("name", "?"); a["tools"][n] += 1
                        i = b.get("input") or {}
                        if n in ("Skill", "SlashCommand"):
                            v = i.get("skill") or i.get("command")
                            if v: a["skills"][str(v)] += 1
                        if n in ("Agent", "Task"):
                            v = i.get("subagent_type")
                            if v: a["agents"][str(v)] += 1
    return a

def eq_units(models):
    return sum(v * W[k] for m in models.values() for k, v in m.items() if k in W)

def totals(models):
    t = defaultdict(int)
    for m in models.values():
        for k, v in m.items(): t[k] += v
    return t

def human(n):
    for u, d in (("B", 1e9), ("M", 1e6), ("k", 1e3)):
        if n >= d: return f"{n/d:,.1f}{u}"
    return f"{n:,.0f}"

def dur(sec):
    if not sec or sec < 0: return "-"
    h, m = divmod(int(sec // 60), 60)
    return f"{h}h{m:02d}m" if h else f"{m}m"

def bar(frac, w=14):
    f = max(0, min(w, int(round(frac * w))))
    return "▓" * f + "░" * (w - f)

def guess_session(files, cwd):
    """Deduce which transcript is 'this session' when nobody told us.

    A skill does NOT receive $CLAUDE_SESSION_ID: the `!` block of a SKILL.md runs in a
    shell where the variable is not exported (measured; it is what made /ahora answer
    'no hay snapshot' with the status line running perfectly). So do what /ahora does and
    deduce it from the directory: Claude Code stores transcripts under
    ~/.claude/projects/<cwd with every non-alphanumeric char turned into a dash>/, so the
    newest .jsonl in that directory is the window you are typing in.

    Returns (path or None, slug). Two windows open on the same repo can still collide,
    which is exactly why the caller says out loud that it guessed.
    """
    slug = re.sub(r"[^A-Za-z0-9]", "-", str(cwd))
    here = [f for f in files if f.parent.name == slug]
    if not here:
        return None, slug
    return max(here, key=lambda f: f.stat().st_mtime), slug

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--claude-dir", default=os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude")))
    ap.add_argument("--session", default=os.environ.get("CLAUDE_SESSION_ID", ""))
    ap.add_argument("--live-min", type=int, default=15)
    ap.add_argument("--no-color", action="store_true")
    a = ap.parse_args()
    if a.no_color or not sys.stdout.isatty(): nocolor()

    root = Path(a.claude_dir) / "projects"
    if not root.exists(): sys.exit(f"No existe {root}")
    now = time.time()
    files = [f for f in root.glob("*/*.jsonl")
             if ".orphaned-" not in f.name and ".superseded-" not in f.name]

    # ---------- 1. ESTA SESION ----------
    print(f"\n{C['b']}━━ ESTA SESIÓN ━━{C['x']}")
    mine = next((f for f in files if f.stem == a.session), None)
    guessed = ""
    if not mine:
        # No id, or an id with no transcript: deduce it from the directory rather than
        # printing a message that tells you to pass a variable a skill can never have.
        mine, slug = guess_session(files, Path.cwd())
        if mine:
            guessed = f"   {C['d']}(sesión {mine.stem[:8]}, elegida por directorio){C['x']}"
        elif a.session:
            print(f"  {C['d']}no encontré el transcript de {a.session[:8]}…{C['x']}")
        else:
            print(f"  {C['d']}sin transcripts para este directorio ({slug}){C['x']}")
    if mine:
        s = scan(mine)
        t = totals(s["models"]); eq = eq_units(s["models"])
        ctx = t["input"] + t["cache_read"] + t["cache_write"]
        print(f"  proyecto {C['c']}{mine.parent.name}{C['x']}   {s['turns']} turnos   "
              f"{dur((s['last'] or 0) - (s['first'] or 0))}"
              + (f"   ${s['cost']:,.2f}" if s["cost"] else "") + guessed)
        for name, m in sorted(s["models"].items(), key=lambda x: -x[1]["req"]):
            share = (eq_units({name: m}) / eq) if eq else 0
            print(f"    {bar(share)} {share*100:>4.0f}%  {name:<20} {m['req']:>5} req  "
                  f"out {human(m['output']):>7}  caché {human(m['cache_read']):>7}")
        if s["skills"]:
            print("  skills:  " + ", ".join(f"{k}({v})" for k, v in sorted(s["skills"].items(), key=lambda x: -x[1])[:6]))
        if s["agents"]:
            print("  agentes: " + ", ".join(f"{k}({v})" for k, v in sorted(s["agents"].items(), key=lambda x: -x[1])[:6]))
        if s["tools"]:
            print("  tools:   " + ", ".join(f"{k}({v})" for k, v in sorted(s["tools"].items(), key=lambda x: -x[1])[:6]))

    # ---------- 2. SESIONES VIVAS ----------
    cutoff = now - a.live_min * 60
    live = sorted((f for f in files if f.stat().st_mtime >= cutoff),
                  key=lambda f: -f.stat().st_mtime)
    print(f"\n{C['b']}━━ SESIONES VIVAS{C['x']} {C['d']}(actividad en {a.live_min} min){C['x']} {C['b']}━━{C['x']}")
    if not live:
        print(f"  {C['d']}ninguna{C['x']}")
    for f in live[:8]:
        s = scan(f); t = totals(s["models"])
        ctx_k = (t["input"] + t["cache_read"] + t["cache_write"]) // 1000
        top = max(s["models"].items(), key=lambda x: x[1]["req"])[0] if s["models"] else "?"
        ago = int((now - f.stat().st_mtime) // 60)
        me = f"{C['g']}◀ aquí{C['x']}" if f is mine else ""
        print(f"  {C['c']}{f.parent.name[-34:]:<34}{C['x']} {top:<18} "
              f"{s['turns']:>4} turnos  hace {ago:>2}m  {me}")

    # ---------- 3. CONSUMO RODANTE ----------
    print(f"\n{C['b']}━━ CONSUMO{C['x']} {C['d']}(consumido, no restante){C['x']} {C['b']}━━{C['x']}")
    for label, secs in (("últimas 5 h", 5*3600), ("últimos 7 días", 7*86400)):
        since = now - secs
        agg = defaultdict(lambda: defaultdict(int)); skills = defaultdict(int); cost = 0.0
        for f in files:
            if f.stat().st_mtime < since: continue
            s = scan(f, since=since)
            for name, m in s["models"].items():
                for k, v in m.items(): agg[name][k] += v
            for k, v in s["skills"].items(): skills[k] += v
            cost += s["cost"]
        t = totals(agg); eq = eq_units(agg)
        if not eq:
            print(f"  {label:<16} {C['d']}sin actividad{C['x']}"); continue
        cheap = sum(eq_units({n: m}) for n, m in agg.items() if "sonnet" in n or "haiku" in n)
        print(f"  {C['b']}{label}{C['x']}  ·  {human(eq)} eq"
              + (f"  ·  ${cost:,.2f}" if cost else "")
              + f"  ·  {sum(m['req'] for m in agg.values())} peticiones")
        for k, w in (("cache_read","lecturas caché"),("output","output"),("cache_write","escrituras"),("input","input fresco")):
            share = t[k] * W[k] / eq
            if share < 0.005: continue
            print(f"     {bar(share)} {share*100:>4.0f}%  {w:<16} {human(t[k])}")
        pc = 100 * cheap / eq
        col = C["g"] if pc >= 35 else (C["y"] if pc >= 15 else C["r"])
        print(f"     carril barato (sonnet/haiku): {col}{pc:.0f}%{C['x']} del gasto")
        if skills:
            print("     skills: " + ", ".join(f"{k}({v})" for k, v in sorted(skills.items(), key=lambda x: -x[1])[:5]))
    print()

if __name__ == "__main__":
    main()
