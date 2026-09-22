#!/usr/bin/env python3
"""
harvest.py — extracts durable metrics from Claude Code transcripts before they expire.

WHY: Claude Code deletes transcripts older than cleanupPeriodDays (default 30).
Everything you would want to analyse later — tokens, models, cost, duration, which
skills and agents ran — lives only in those files. This writes a small, permanent
summary so the history survives the sweep.

WHAT IT DOES NOT DO: it stores metadata only. It never copies message content, prompt
text or history.jsonl. Transcripts can contain secrets (a tool that read a .env, a command
that printed a token); the summary this produces is safe to sync or publish, the raw
transcripts and history.jsonl are not.

Usage:
    python harvest.py                 # harvest + report
    python harvest.py --report-only   # just show what is there
    python harvest.py --out DIR       # default ~/claude-archive
"""
import argparse, json, os, sys, datetime as dt
# Windows consoles default to cp1252 and crash on non-ASCII at print time — after the work
# is already done. Force UTF-8 so a cosmetic encoding error never masks a successful run.
for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass
from collections import defaultdict
from pathlib import Path

def iso(ts):
    if not ts: return None
    if isinstance(ts, (int, float)):
        return dt.datetime.fromtimestamp(ts / (1000 if ts > 1e11 else 1), dt.timezone.utc).isoformat()
    return str(ts)

def dig(obj, *keys):
    """Tolerant nested get: returns the first key path that exists."""
    for k in keys:
        cur = obj
        ok = True
        for part in k.split("."):
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                ok = False; break
        if ok and cur is not None:
            return cur
    return None

def harvest_session(path: Path, unknown_keys: set):
    s = {
        "session_id": path.stem,
        "project": path.parent.name,
        "file": str(path),
        "first_seen": None, "last_seen": None,
        "models": defaultdict(lambda: {"requests": 0, "input": 0, "output": 0,
                                       "cache_read": 0, "cache_write": 0, "cost_usd": 0.0}),
        "tools": defaultdict(int),
        "skills": defaultdict(int),
        "agents": defaultdict(int),
        "lines": 0, "unparsed": 0, "user_turns": 0,
    }
    try:
        fh = path.open(encoding="utf-8", errors="replace")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            s["lines"] += 1
            try:
                r = json.loads(line)
            except json.JSONDecodeError:
                s["unparsed"] += 1
                continue
            if not isinstance(r, dict):
                s["unparsed"] += 1
                continue
            unknown_keys.update(k for k in r.keys())

            ts = iso(dig(r, "timestamp", "ts", "time", "message.timestamp"))
            if ts:
                if not s["first_seen"] or ts < s["first_seen"]: s["first_seen"] = ts
                if not s["last_seen"]  or ts > s["last_seen"]:  s["last_seen"]  = ts

            role = dig(r, "message.role", "role", "type")
            if role in ("user", "user_message"):
                # Tool results are stored as synthetic user messages. Only a plain string or
                # a text block is a prompt the human actually typed.
                content = dig(r, "message.content", "content")
                if isinstance(content, str):
                    typed = bool(content.strip())
                else:
                    typed = any(isinstance(b, dict) and b.get("type") == "text" for b in (content or []))
                if typed:
                    s["user_turns"] += 1

            usage = dig(r, "message.usage", "usage")
            if isinstance(usage, dict):
                model = dig(r, "message.model", "model") or "unknown"
                m = s["models"][model]
                m["requests"]    += 1
                m["input"]       += usage.get("input_tokens", 0) or 0
                m["output"]      += usage.get("output_tokens", 0) or 0
                m["cache_read"]  += usage.get("cache_read_input_tokens", 0) or 0
                m["cache_write"] += usage.get("cache_creation_input_tokens", 0) or 0
                cost = dig(r, "costUSD", "cost_usd", "message.cost_usd")
                if isinstance(cost, (int, float)):
                    m["cost_usd"] += float(cost)

            # tool / skill / agent usage, wherever the harness records it
            content = dig(r, "message.content", "content")
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        name = block.get("name", "?")
                        s["tools"][name] += 1
                        if name in ("Skill", "SlashCommand"):
                            arg = (block.get("input") or {}).get("skill") or (block.get("input") or {}).get("command")
                            if arg: s["skills"][str(arg)] += 1
                        if name in ("Agent", "Task"):
                            arg = (block.get("input") or {}).get("subagent_type")
                            if arg: s["agents"][str(arg)] += 1

    for k in ("models", "tools", "skills", "agents"):
        s[k] = {kk: (dict(vv) if isinstance(vv, dict) else vv) for kk, vv in s[k].items()}
    return s

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--claude-dir", default=os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude")))
    ap.add_argument("--out", default=str(Path.home() / "claude-archive"))
    ap.add_argument("--report-only", action="store_true")
    a = ap.parse_args()

    root = Path(a.claude_dir) / "projects"
    if not root.exists():
        sys.exit(f"No encontré {root}. Pasa --claude-dir con la ruta correcta.")

    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    store = out / "sessions.json"
    known = {}
    if store.exists():
        try:
            known = {s["session_id"]: s for s in json.loads(store.read_text(encoding="utf-8"))}
        except Exception as e:
            # Never rebuild from scratch: the archive holds sessions that no longer exist on
            # disk, and overwriting it here would erase exactly what this script preserves.
            sys.exit(f"{store} no se pudo leer ({e}). No se sobreescribe: repara o restaura el archivo a mano.")

    files = sorted(root.glob("*/*.jsonl"))
    files = [f for f in files if ".orphaned-" not in f.name and ".superseded-" not in f.name]
    unknown_keys, new, updated = set(), 0, 0
    for f in files:
        s = harvest_session(f, unknown_keys)
        if not s: continue
        if s["session_id"] in known: updated += 1
        else: new += 1
        known[s["session_id"]] = s

    rows = sorted(known.values(), key=lambda r: r.get("first_seen") or "")
    if not a.report_only:
        # Write to a sibling and rename: a Ctrl-C leaves the old file intact, never half of the new one.
        tmp = store.with_name(store.name + ".tmp")
        tmp.write_text(json.dumps(rows, indent=1, ensure_ascii=False), encoding="utf-8")
        os.replace(tmp, store)

    tot = defaultdict(float); permodel = defaultdict(lambda: defaultdict(float))
    for r in rows:
        for model, m in r["models"].items():
            for k, v in m.items():
                tot[k] += v; permodel[model][k] += v
    dates = [r["first_seen"][:10] for r in rows if r.get("first_seen")]
    print(f"\n=== HARVEST ===")
    print(f"transcripts encontrados : {len(files)}")
    print(f"sesiones en el archivo  : {len(rows)}  (nuevas {new}, actualizadas {updated})")
    if dates: print(f"rango de fechas         : {min(dates)} → {max(dates)}")
    print(f"\ntokens totales: in {tot['input']:,.0f} · out {tot['output']:,.0f} · "
          f"cache_read {tot['cache_read']:,.0f} · cache_write {tot['cache_write']:,.0f}")
    if tot["cache_read"] + tot["input"] > 0:
        print(f"ratio de caché: {100*tot['cache_read']/(tot['cache_read']+tot['cache_write']+tot['input']):.1f}%")
    if tot["cost_usd"]: print(f"costo registrado: ${tot['cost_usd']:,.2f}")
    print("\npor modelo:")
    for model, m in sorted(permodel.items(), key=lambda x: -x[1]["input"]):
        print(f"  {model:<32} {m['requests']:>6.0f} req  in {m['input']:>12,.0f}  out {m['output']:>10,.0f}  cache {m['cache_read']:>12,.0f}")
    skills = defaultdict(int)
    for r in rows:
        for k, v in r["skills"].items(): skills[k] += v
    if skills:
        print("\nskills más usadas:", ", ".join(f"{k}({v})" for k, v in sorted(skills.items(), key=lambda x:-x[1])[:10]))
    print(f"\n--- calibración (pásame esto) ---")
    print("claves vistas en las líneas:", ", ".join(sorted(unknown_keys))[:600])
    bad = sum(r["unparsed"] for r in rows)
    print(f"líneas no parseadas: {bad}")
    if not tot["input"]:
        print("!! No extraje tokens. El formato difiere de lo que asumí — mándame esta salida y lo ajusto.")
    if not a.report_only:
        print(f"\nguardado en: {store}")

if __name__ == "__main__":
    main()
