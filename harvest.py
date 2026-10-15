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

v2 (SPEC-partidas.md): every message.id is counted once (the harness stores one record per
content block, each with the same usage, so v1 inflated tokens), subagent transcripts are
folded in, and each session gains cost, peak context, cache cold events, commands and
compactions. Thresholds and prices come from rules/*.json; there is no number in this file.

Usage:
    python harvest.py                 # harvest + report
    python harvest.py --report-only   # just show what is there
    python harvest.py --out DIR       # default ~/claude-archive
"""
import argparse, json, os, re, shutil, sys, datetime as dt
# Windows consoles default to cp1252 and crash on non-ASCII at print time — after the work
# is already done. Force UTF-8 so a cosmetic encoding error never masks a successful run.
for _s in (sys.stdout, sys.stderr):
    try: _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception: pass
from collections import Counter, defaultdict
from pathlib import Path

HARVEST_VERSION = 2
CMD_RE = re.compile(r"<command-name>\s*(/[\w:-]+)\s*</command-name>")
KNOWN_CMDS = ("/clear", "/compact", "/handoff")

def iso(ts):
    if not ts: return None
    if isinstance(ts, (int, float)):
        return dt.datetime.fromtimestamp(ts / (1000 if ts > 1e11 else 1), dt.timezone.utc).isoformat()
    return str(ts)

def parse_ts(ts):
    """ISO string -> aware datetime (naive is taken as UTC), or None."""
    try: d = dt.datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except ValueError: return None
    return d if d.tzinfo else d.replace(tzinfo=dt.timezone.utc)

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

def die(msg, code=2):
    print(msg, file=sys.stderr); sys.exit(code)

NEEDED = ("context-red", "cache-cold", "cache-hit-ok")

def has_threshold(data, tid):
    return isinstance(data, dict) and any(isinstance(t, dict) and t.get("id") == tid and isinstance(dig(t, "condition.value"), (int, float))
                                          for t in data.get("thresholds", []))

def load_rules(claude_dir):
    """thresholds.json + models.json: <claude-dir>/rules/ first, then the kit's own copy.
    WHY exit 2 and no default: a threshold you cannot read is not one that is not crossed."""
    kit = Path(__file__).resolve().parent / "home" / ".claude" / "rules"
    got = {}
    for name in ("thresholds.json", "models.json"):
        for d in (Path(claude_dir) / "rules", kit):
            try: data = json.loads((d / name).read_text(encoding="utf-8"))
            except (OSError, ValueError): continue
            # an older installed copy may lack an id this version needs: not usable, try the next place
            if name == "thresholds.json" and not all(has_threshold(data, t) for t in NEEDED): continue
            got[name] = data; break
        else:
            die(f"No pude leer {name} (busqué en {Path(claude_dir) / 'rules'} y {kit}). Sin umbrales no se calcula nada.")
    threshold = lambda tid: float(next(t["condition"]["value"] for t in got["thresholds.json"]["thresholds"] if t.get("id") == tid))
    return {"models": {m["id"]: m for m in got["models.json"].get("models", []) if "id" in m},
            "red": threshold("context-red"), "cold": threshold("cache-cold"), "ok": threshold("cache-hit-ok")}

def price_row(models_by_id, model):
    row = models_by_id.get(model) or models_by_id.get(re.sub(r"\[.*\]$", "", model))
    keys = ("price_in", "price_out", "price_cache_hit", "price_cache_write_5m", "price_cache_write_1h")
    return row if row and all(isinstance(row.get(k), (int, float)) for k in keys) else None

def estimate_usd(row, usage):
    """Price-table estimate for one request. Unknown or unpriced model = 0, never a guess."""
    if not row: return 0.0
    cc = usage.get("cache_creation")
    if isinstance(cc, dict):
        w5, w1 = cc.get("ephemeral_5m_input_tokens", 0) or 0, cc.get("ephemeral_1h_input_tokens", 0) or 0
    else:
        w5, w1 = usage.get("cache_creation_input_tokens", 0) or 0, 0
    return ((usage.get("input_tokens", 0) or 0) * row["price_in"]
            + (usage.get("output_tokens", 0) or 0) * row["price_out"]
            + (usage.get("cache_read_input_tokens", 0) or 0) * row["price_cache_hit"]
            + w5 * row["price_cache_write_5m"] + w1 * row["price_cache_write_1h"]) / 1e6

def new_models():
    return defaultdict(lambda: {"requests": 0, "input": 0, "output": 0,
                                "cache_read": 0, "cache_write": 0, "cost_usd": 0.0})

def add_usage(models, r, seen, rules):
    """Count one request into `models`. A message.id already seen is a duplicate content-block
    record carrying the same usage: skipped. Returns (input, read, write, estimate) or None."""
    usage = dig(r, "message.usage", "usage")
    if not isinstance(usage, dict): return None
    mid = dig(r, "message.id")
    if mid:
        if mid in seen: return None
        seen.add(mid)
    model = dig(r, "message.model", "model") or "unknown"
    m = models[model]
    inp, read = usage.get("input_tokens", 0) or 0, usage.get("cache_read_input_tokens", 0) or 0
    write = usage.get("cache_creation_input_tokens", 0) or 0
    m["requests"] += 1
    m["input"] += inp
    m["output"] += usage.get("output_tokens", 0) or 0
    m["cache_read"] += read
    m["cache_write"] += write
    cost = dig(r, "costUSD", "cost_usd", "message.cost_usd")
    if isinstance(cost, (int, float)):
        m["cost_usd"] += float(cost)
    return inp, read, write, estimate_usd(price_row(rules["models"], model), usage)

def iter_records(fh, s, unknown_keys=None):
    """Yield dict records; count lines and unparsed into s (main file only keeps these)."""
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
        if unknown_keys is not None: unknown_keys.update(r.keys())
        yield r

def user_text(content):
    if isinstance(content, str): return content
    return "\n".join(b.get("text", "") for b in (content or []) if isinstance(b, dict) and b.get("type") == "text")

def label_of(cwds):
    """Basename of the most frequent cwd; `home` if that is the home dir."""
    if not cwds: return "sin-cwd"
    top = cwds.most_common(1)[0][0]
    norm = lambda p: p.replace("\\", "/").rstrip("/").lower()
    home = norm(str(Path.home()))
    if norm(top) == home: return "home"
    base = top.replace("\\", "/").rstrip("/").rsplit("/", 1)[-1]
    # a cwd whose last segment is the user name would leak it into the outputs
    return "home" if base.lower() == home.rsplit("/", 1)[-1] else (base or "sin-cwd")

def harvest_subagents(path, rules):
    """Fold <session>/subagents/*.jsonl in: returns (models, bytes, estimate_usd)."""
    models, seen, est, size = new_models(), set(), 0.0, 0
    for f in sorted((path.parent / path.stem / "subagents").glob("*.jsonl")):
        try: fh = f.open(encoding="utf-8", errors="replace"); size += f.stat().st_size
        except OSError: continue
        with fh:
            for r in iter_records(fh, {"lines": 0, "unparsed": 0}):
                got = add_usage(models, r, seen, rules)
                if got: est += got[3]
    return models, size, est

def harvest_session(path: Path, unknown_keys: set, rules: dict):
    s = {
        "session_id": path.stem,
        "project": path.parent.name,
        "file": str(path),
        "first_seen": None, "last_seen": None,
        "models": new_models(),
        "tools": defaultdict(int),
        "skills": defaultdict(int),
        "agents": defaultdict(int),
        "lines": 0, "unparsed": 0, "user_turns": 0,
    }
    try:
        fh = path.open(encoding="utf-8", errors="replace")
    except OSError:
        return None
    cwds, seen, seen_tools = Counter(), set(), set()
    commands = {c: 0 for c in KNOWN_CMDS}
    turns = compactions = without = handoff_since = cold = active_ms = peak = 0
    main_read = main_tot = 0
    est_main, last_cost = 0.0, None
    skip_next, first_req = False, True
    with fh:
        for r in iter_records(fh, s, unknown_keys):
            side = bool(r.get("isSidechain"))
            if isinstance(r.get("cwd"), str): cwds[r["cwd"]] += 1

            ts = iso(dig(r, "timestamp", "ts", "time", "message.timestamp"))
            if ts:
                if not s["first_seen"] or ts < s["first_seen"]: s["first_seen"] = ts
                if not s["last_seen"]  or ts > s["last_seen"]:  s["last_seen"]  = ts

            if r.get("type") == "cost-state":
                last_cost = r
            elif r.get("type") == "system":
                if r.get("subtype") == "compact_boundary":
                    compactions += 1
                    if not handoff_since: without += 1
                    handoff_since, skip_next = 0, True
                elif r.get("subtype") == "turn_duration":
                    active_ms += r.get("durationMs") or 0

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
                    text = user_text(content)
                    names = CMD_RE.findall(text)
                    if not side:
                        for name in names:
                            if name in commands: commands[name] += 1
                            if name == "/handoff": handoff_since += 1
                            if name == "/clear": skip_next = True
                        if not names and not r.get("isMeta") and not text.lstrip().startswith("<local-command-"):
                            turns += 1

            got = add_usage(s["models"], r, seen, rules)
            if got:
                inp, read, write, est = got
                est_main += est
                tot = inp + read + write
                if not side and tot:
                    peak = max(peak, tot); main_read += read; main_tot += tot
                    # the first request and the first after a compaction or /clear rewrite the
                    # cache by design: not evidence of a cold cache
                    if not (first_req or skip_next) and 100 * read / tot < rules["cold"]: cold += 1
                    first_req = skip_next = False

            # tool / skill / agent usage, wherever the harness records it
            content = dig(r, "message.content", "content")
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "tool_use":
                        if block.get("id") in seen_tools: continue
                        seen_tools.add(block.get("id"))
                        name = block.get("name", "?")
                        s["tools"][name] += 1
                        if name in ("Skill", "SlashCommand"):
                            arg = (block.get("input") or {}).get("skill") or (block.get("input") or {}).get("command")
                            if arg: s["skills"][str(arg)] += 1
                            if name == "Skill" and not side and str(arg).split(":")[-1] == "handoff":
                                commands["/handoff"] += 1; handoff_since += 1
                        if name in ("Agent", "Task"):
                            arg = (block.get("input") or {}).get("subagent_type")
                            if arg: s["agents"][str(arg)] += 1

    subs, sub_bytes, est_sub = harvest_subagents(path, rules)
    if last_cost is not None:
        harness = last_cost.get("totalCostUSD")
        if not isinstance(harness, (int, float)):
            harness = sum(v.get("costUSD", 0) or 0 for v in (last_cost.get("modelUsage") or {}).values() if isinstance(v, dict))
        cost, source = float(harness), "harness"
    elif est_main + est_sub > 0:
        cost, source = est_main + est_sub, "estimate"
    else:
        cost, source = 0.0, "none"
    t0, t1 = parse_ts(s["first_seen"]), parse_ts(s["last_seen"])
    s.update({
        "harvest_version": HARVEST_VERSION,
        "project_label": label_of(cwds),
        "bytes": path.stat().st_size + sub_bytes,
        "turns": turns, "commands": commands,
        "compactions": compactions, "compactions_without_handoff": without,
        "subagents": subs,
        "cost_usd": round(cost, 6), "cost_source": source,
        "peak_context": peak,
        "hit_pct": round(100 * main_read / main_tot, 2) if main_tot else None,
        "cold_cache_events": cold,
        "active_ms": active_ms,
        "duration_min": round((t1 - t0).total_seconds() / 60, 1) if t0 and t1 else None,
        "start_hour_local": t0.astimezone().hour if t0 else None,
    })
    for k in ("models", "subagents", "tools", "skills", "agents"):
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
    rules = None if a.report_only else load_rules(a.claude_dir)

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
        backup = out / "sessions.v1-backup.json"
        # first v2 run only: the v1 file is the one copy of records v2 cannot rebuild
        if not a.report_only and not backup.exists(): shutil.copy2(store, backup)

    files = sorted(root.glob("*/*.jsonl"))
    files = [f for f in files if ".orphaned-" not in f.name and ".superseded-" not in f.name]
    unknown_keys, new, updated = set(), 0, 0
    if rules:
        for f in files:
            s = harvest_session(f, unknown_keys, rules)
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
    v2 = sum(1 for r in rows if r.get("harvest_version") == HARVEST_VERSION)
    print(f"\n=== HARVEST ===")
    print(f"transcripts encontrados : {len(files)}")
    print(f"sesiones en el archivo  : {len(rows)}  (nuevas {new}, actualizadas {updated})")
    print(f"versión del registro    : {v2} en v2, {len(rows) - v2} solo v1")
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
