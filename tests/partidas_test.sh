#!/usr/bin/env bash
# tests/partidas_test.sh — harvest.py v2 + partidas.py against synthetic transcripts.
# Everything happens in a mktemp dir: nothing under ~/.claude or ~/claude-archive is read or
# written. Planted: a fake user (zz-tester), 21 v2 sessions (19 in the window, one in the
# previous window, one old), one v1-only archive record, and a prompt sentinel that must
# never reach an output.
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0 fail=0
ok()  { printf '  OK    %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FALLA %s — %s\n' "$1" "$2"; fail=$((fail + 1)); }

# python3 first, but chosen by RUNNING it: on Windows `python3` is the Store stub (exit 49).
PY=""
for c in python3 python; do
  if "$c" -c 'import sys' >/dev/null 2>&1; then PY=$c; break; fi
done
[ -n "$PY" ] || { echo "sin python"; exit 1; }

T=$(mktemp -d) || exit 1
trap 'rm -rf "$T"' EXIT
# native Python on Windows cannot open /tmp/...: hand it the mixed-style path
TW=$(cygpath -m "$T" 2>/dev/null || echo "$T")
NOW=2026-10-20T12:00
mkdir -p "$T/claude/rules" "$T/arch" "$T/bin"
cp home/.claude/rules/thresholds.json home/.claude/rules/models.json "$T/claude/rules/"
cp harvest.py partidas.py "$T/bin/"

echo "partidas: harvest v2 y partidas contra transcripts sintéticos"

"$PY" - "$TW" <<'PY'
import json, os, sys, datetime as dt
T = sys.argv[1]
P = os.path.join(T, "claude", "projects")
th = json.load(open(os.path.join(T, "claude", "rules", "thresholds.json"), encoding="utf-8"))
RED = int(next(t["condition"]["value"] for t in th["thresholds"] if t["id"] == "context-red") * 1000)
UTC = dt.timezone.utc
# The Windows user root is assembled, never written whole: the kit export refuses any file
# that contains that literal, and these paths are synthetic (user zz-tester).
WINU = "C:\\" + "Users\\zz-tester"
DEMO, DEMO_CWD = "C--Users-zz-tester-work-demo", WINU + "\\work\\demo"
OTHER, OTHER_CWD = "C--Users-zz-tester-work-other", WINU + "\\work\\other"
HOMED = "C--zz-home-dir"
SON, HAI, FAB = "claude-sonnet-5-5", "claude-haiku-5-5", "claude-fable-5-1"

class Sess:
    n = 0
    def __init__(self, name, proj, cwd, base):
        Sess.n += 1
        self.name, self.proj, self.cwd, self.t = name, proj, cwd, base
        self.sid = f"deadbeef-0000-4000-8000-{Sess.n:012d}"
        self.recs, self.sub, self.k, self.tid = [], [], 0, 0
        self.user(f"PROMPTSENTINEL-{name}")
    def ts(self, sec=10):
        self.t += dt.timedelta(seconds=sec)
        return self.t.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    def add(self, r, sub=False):
        r.setdefault("timestamp", self.ts()); r.setdefault("cwd", self.cwd)
        r.setdefault("sessionId", self.sid); r.setdefault("isSidechain", sub)
        (self.sub if sub else self.recs).append(r)
    def user(self, text, **kw):
        self.add({"type": "user", "message": {"role": "user", "content": text}, **kw})
    def cmd(self, name, **kw):
        self.user(f"<command-name>{name}</command-name>\n<command-message>{name[1:]}</command-message>", **kw)
    def tool_result(self):
        self.add({"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "x", "content": "ok"}]}})
    def req(self, model, i, o, r, w, tools=(), cc=None, sub=False):
        # the harness stores ONE record per content block, every copy with the same usage
        self.k += 1
        mid = f"msg_{self.name}_{self.k}"
        usage = {"input_tokens": i, "output_tokens": o, "cache_read_input_tokens": r, "cache_creation_input_tokens": w}
        if cc: usage["cache_creation"] = cc
        blocks = [{"type": "text", "text": "respuesta"}]
        for name, inp in tools:
            self.tid += 1
            blocks.append({"type": "tool_use", "id": f"toolu_{self.name}_{self.tid}", "name": name, "input": inp})
        for b in blocks:
            self.add({"type": "assistant", "message": {"id": mid, "role": "assistant", "model": model, "content": [b], "usage": usage}}, sub=sub)
    def cost(self, x):
        self.add({"type": "cost-state", "totalCostUSD": x, "modelUsage": {SON: {"costUSD": x}}})
    def compact(self):
        self.add({"type": "system", "subtype": "compact_boundary", "content": "Conversation compacted"})
    def write(self):
        d = os.path.join(P, self.proj); os.makedirs(d, exist_ok=True)
        def dump(path, recs):
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                for r in recs: f.write(json.dumps(r) + "\n")
        dump(os.path.join(d, self.sid + ".jsonl"), self.recs)
        if self.sub:
            sd = os.path.join(d, self.sid, "subagents"); os.makedirs(sd, exist_ok=True)
            dump(os.path.join(sd, "agent-1.jsonl"), self.sub)

def base(k): return dt.datetime(2026, 9, 24, 7, 0, tzinfo=UTC) + dt.timedelta(days=k, hours=k % 5)
order, S, k = [], {}, 0
def new(name, proj=DEMO, cwd=DEMO_CWD, b=None):
    global k
    s = Sess(name, proj, cwd, b or base(k)); k += 1 if b is None else 0
    S[name] = s
    if b is None: order.append(name)
    return s

s = new("dedupe")
s.req(SON, 100, 50, 1000, 200, tools=[("Read", {}), ("Grep", {})])      # 3 copies of one message
s.tool_result()
s.cmd("/clear")
s.user("PROMPTSENTINEL second typed prompt")
s.req(SON, 10, 20, 2000, 0)
s.cmd("/clear", isSidechain=True)                                         # sidechain: ignored
s.user("PROMPTSENTINEL typed inside a sidechain", isSidechain=True)
s.user("PROMPTSENTINEL meta record", isMeta=True)
s.add({"type": "system", "subtype": "turn_duration", "durationMs": 1800000})
s.add({"type": "system", "subtype": "turn_duration", "durationMs": 1800000})
s.cost(0.5); s.cost(1.25)
s.req(HAI, 5, 5, 0, 0, sub=True, tools=[("Read", {})])                   # subagent message in 2 records

s = new("est")
s.req(SON, 1000, 2000, 3000, 500, cc={"ephemeral_5m_input_tokens": 300, "ephemeral_1h_input_tokens": 200})
s.req(HAI, 400, 100, 0, 100, sub=True)

s = new("long");       s.req(SON, 0, 1, RED, 1000)
s = new("long_hand");  s.req(SON, 0, 1, RED, 1000); s.cmd("/handoff")
s = new("long_below"); s.req(SON, 0, 1, RED - 2000, 1000)
s = new("long_edge");  s.req(SON, 0, 1, RED - 1000, 1000)                 # peak == limit exactly

def mech(name, model, tools):
    s = new(name); s.req(model, 10, 5000, 100, 0, tools=tools); return s
mech("mech", FAB, [("Read", {})] * 3 + [("Grep", {}), ("Bash", {})])
mech("mech_edit", FAB, [("Read", {})] * 4 + [("Edit", {})])
mech("mech_cheap", SON, [("Read", {})] * 3 + [("Grep", {}), ("Bash", {})])
mech("mech80", FAB, [("Read", {})] * 4 + [("TodoWrite", {})])
mech("mech75", FAB, [("Read", {})] * 6 + [("TodoWrite", {})] * 2)
mech("mech4", FAB, [("Read", {})] * 4)
s = new("mech_dom"); s.req(SON, 10, 5000, 100, 0, tools=[("Read", {})] * 5); s.req(FAB, 10, 10, 100, 0)

COLD = (1000, 5, 0, 1000)
s = new("cold"); s.req(SON, 10, 5, 5000, 0)
for _ in range(5): s.req(SON, *COLD)
s = new("cold3"); s.req(SON, 10, 5, 5000, 0)
for _ in range(3): s.req(SON, *COLD)
s.req(SON, 200, 5, 600, 200)                                              # hit exactly 60 %: not cold
s.req(SON, 10, 5, 5000, 0)
s = new("cold_skip")
s.req(SON, *COLD); s.req(SON, *COLD); s.compact()                         # r1 first, r2 counts
s.req(SON, *COLD); s.req(SON, *COLD); s.cmd("/clear")                     # r3 after compact, r4 counts
s.req(SON, *COLD); s.req(SON, *COLD); s.req(SON, *COLD)                   # r5 after /clear, r6 r7 count

s = new("comp")
s.cmd("/compact")
s.compact()                                                               # no handoff yet
s.cmd("/handoff"); s.compact()                                            # covered
s.cmd("/handoff", isSidechain=True); s.compact()                          # sidechain handoff does not count
s.req(SON, 1, 1, 0, 0, tools=[("Skill", {"skill": "handoff"})]); s.compact()   # covered by the Skill

s = new("home", HOMED, os.path.expanduser("~")); s.req(SON, 10, 5, 100, 0); s.cost(0.75)
s = new("other1", OTHER, OTHER_CWD); s.req(SON, 10, 5, 100, 0); s.cost(2.0)
s = new("prev", OTHER, OTHER_CWD, dt.datetime(2026, 9, 10, 8, 0, tzinfo=UTC)); s.req(SON, 10, 5, 100, 0)
s = new("old", OTHER, OTHER_CWD, dt.datetime(2026, 7, 1, 8, 0, tzinfo=UTC)); s.req(SON, 10, 5, 100, 0)
for s in S.values(): s.write()

empty = os.path.join(P, "C--Users-zz-tester-work-empty")
os.makedirs(os.path.join(empty, "x"));
open(os.path.join(empty, "notes.txt"), "wb").write(b"n" * 700)
open(os.path.join(empty, "x", "y.bin"), "wb").write(b"y" * 300)

v1 = [{"session_id": "v1only-0001", "project": "C--Users-zz-tester-v1", "file": WINU + "\\v1.jsonl",
       "first_seen": "2026-09-01T00:00:00Z", "last_seen": "2026-09-01T01:00:00Z", "models": {}, "tools": {},
       "skills": {}, "agents": {}, "lines": 1, "unparsed": 0, "user_turns": 2}]
with open(os.path.join(T, "arch", "sessions.json"), "w", encoding="utf-8", newline="\n") as f: json.dump(v1, f, indent=1)
with open(os.path.join(T, "sessions.orig.json"), "w", encoding="utf-8", newline="\n") as f: json.dump(v1, f, indent=1)
json.dump({"order": order, "sid": {n: x.sid for n, x in S.items()},
           "starts": {n: x.recs[0]["timestamp"] for n, x in S.items()}},
          open(os.path.join(T, "expect.json"), "w"))
PY

# --- harvest v2 ---------------------------------------------------------------------------
"$PY" harvest.py --claude-dir "$TW/claude" --out "$TW/arch" > "$T/h1.log" 2>&1; rc=$?
if [ $rc -eq 0 ]; then ok "harvest v2: corre y sale 0"; else bad "harvest v2: corre y sale 0" "rc=$rc: $(tail -2 "$T/h1.log" | tr '\n' ' ')"; fi
if cmp -s "$T/arch/sessions.v1-backup.json" "$T/sessions.orig.json"; then ok "primera corrida: sessions.v1-backup.json es copia exacta del v1"
else bad "primera corrida: sessions.v1-backup.json es copia exacta del v1" "falta o difiere"; fi

"$PY" harvest.py --claude-dir "$TW/claude" --out "$TW/arch" > "$T/h2.log" 2>&1; rc=$?
if [ $rc -eq 0 ] && cmp -s "$T/arch/sessions.v1-backup.json" "$T/sessions.orig.json"; then ok "segunda corrida: el respaldo v1 no se vuelve a escribir"
else bad "segunda corrida: el respaldo v1 no se vuelve a escribir" "rc=$rc"; fi

cp "$T/arch/sessions.json" "$T/sessions.before-report.json"
"$PY" harvest.py --report-only --claude-dir "$TW/claude" --out "$TW/arch" > "$T/hr.log" 2>&1; rc=$?
if [ $rc -eq 0 ] && grep -q '=== HARVEST ===' "$T/hr.log" && cmp -s "$T/arch/sessions.json" "$T/sessions.before-report.json"; then ok "--report-only imprime el informe y no toca el archivo"
else bad "--report-only imprime el informe y no toca el archivo" "rc=$rc"; fi

# --- partidas ------------------------------------------------------------------------------
"$PY" partidas.py --archive "$TW/arch" --claude-dir "$TW/claude" --weeks 4 --now "$NOW" > "$T/p1.log" 2>&1; rc=$?
if [ $rc -eq 0 ]; then ok "partidas: corre y sale 0"; else bad "partidas: corre y sale 0" "rc=$rc: $(tail -2 "$T/p1.log" | tr '\n' ' ')"; fi
for f in partidas.json partidas.html partidas.txt; do
  if [ -s "$T/arch/$f" ]; then ok "partidas: escribe $f"; else bad "partidas: escribe $f" "no existe o está vacío"; fi
done

"$PY" - "$TW" <<'PY' > "$T/checks.out" 2>&1
import json, os, sys, datetime as dt
from collections import Counter
T = sys.argv[1]
L = lambda p: json.load(open(os.path.join(T, p), encoding="utf-8"))
E, A, D = L("expect.json"), L("arch/sessions.json"), L("arch/partidas.json")
models = {m["id"]: m for m in L("claude/rules/models.json")["models"]}
th = L("claude/rules/thresholds.json")["thresholds"]
tv = lambda i: next(t["condition"]["value"] for t in th if t["id"] == i)
byid = {s["session_id"]: s for s in A}
hs = lambda n: byid[E["sid"][n]]
def chk(label, cond, why=""): print(("OK|" if cond else "BAD|") + label + "|" + str(why).replace("\n", " ")[:220])
local = lambda iso: dt.datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
order = E["order"]

d = hs("dedupe")
chk("dedupe: 3 copias de un mensaje cuentan una vez",
    d["models"]["claude-sonnet-5-5"] == {"requests": 2, "input": 110, "output": 70, "cache_read": 3000, "cache_write": 200, "cost_usd": 0.0}, d["models"])
chk("dedupe: las herramientas de las copias no se duplican", d["tools"] == {"Read": 1, "Grep": 1}, d["tools"])
chk("subagentes: duplicados cuentan una vez y salen aparte",
    d["subagents"].get("claude-haiku-5-5", {}).get("requests") == 1 and d["subagents"]["claude-haiku-5-5"]["input"] == 5, d["subagents"])
chk("costo: último cost-state gana (harness)", d["cost_usd"] == 1.25 and d["cost_source"] == "harness", (d["cost_usd"], d["cost_source"]))
e = hs("est")
def est(m, i, o, r, w5, w1):
    x = models[m]; return (i * x["price_in"] + o * x["price_out"] + r * x["price_cache_hit"] + w5 * x["price_cache_write_5m"] + w1 * x["price_cache_write_1h"]) / 1e6
want = est("claude-sonnet-5-5", 1000, 2000, 3000, 300, 200) + est("claude-haiku-5-5", 400, 100, 0, 100, 0)
chk("costo: sin cost-state se estima (escritura 5m/1h + subagente) y se marca estimate",
    e["cost_source"] == "estimate" and abs(e["cost_usd"] - want) < 1e-5, (e["cost_usd"], want))
chk("turnos: /clear, meta y sidechain no son turnos", d["turns"] == 2, d["turns"])
chk("v1 conserva user_turns con su regla", d["user_turns"] == 6, d["user_turns"])
chk("comandos: /clear del hilo principal cuenta, el de sidechain no", d["commands"] == {"/clear": 1, "/compact": 0, "/handoff": 0}, d["commands"])
chk("pico de contexto y hit% de la cadena principal", d["peak_context"] == 2010 and d["hit_pct"] == 90.63, (d["peak_context"], d["hit_pct"]))
chk("active_ms suma turn_duration", d["active_ms"] == 3600000, d["active_ms"])
sz = lambda p: os.path.getsize(p)
base = os.path.join(T, "claude", "projects", "C--Users-zz-tester-work-demo", E["sid"]["dedupe"])
chk("bytes = principal + subagents", d["bytes"] == sz(base + ".jsonl") + sz(os.path.join(base, "subagents", "agent-1.jsonl")), d["bytes"])
chk("start_hour_local en hora local", d["start_hour_local"] == local(E["starts"]["dedupe"]).hour, d["start_hour_local"])
chk("claves v1 intactas en un registro v2",
    all(k in d for k in ("session_id", "project", "file", "first_seen", "last_seen", "models", "tools", "skills", "agents", "lines", "unparsed", "user_turns")) and d["harvest_version"] == 2)
chk("project_label: basename del cwd, home si es el home",
    d["project_label"] == "demo" and hs("home")["project_label"] == "home" and hs("other1")["project_label"] == "other",
    (d["project_label"], hs("home")["project_label"]))
cs = hs("cold_skip")
chk("frío: primera petición y la que sigue a compactación o /clear no cuentan", cs["cold_cache_events"] == 4, cs["cold_cache_events"])
chk("frío: hit exactamente en el umbral no es frío", hs("cold3")["cold_cache_events"] == 3, hs("cold3")["cold_cache_events"])
c = hs("comp")
chk("compactions_without_handoff: /handoff y Skill handoff cubren, el de sidechain no",
    (c["compactions"], c["compactions_without_handoff"]) == (4, 2), (c["compactions"], c["compactions_without_handoff"]))
chk("comandos: /handoff por comando y por Skill, /compact", c["commands"] == {"/clear": 0, "/compact": 1, "/handoff": 2}, c["commands"])
v1 = [s for s in A if s["session_id"] == "v1only-0001"][0]
chk("sesión solo en el archivo conserva su registro v1", v1 == json.load(open(os.path.join(T, "sessions.orig.json")))[0] and "harvest_version" not in v1)

# plays: exactly where planted
EXP = {"long": ["long-no-handoff"], "long_edge": ["long-no-handoff"], "mech": ["strong-on-mechanical"], "mech80": ["strong-on-mechanical"],
       "cold": ["cold-cache"], "cold_skip": ["cold-cache", "compact-no-handoff"], "comp": ["compact-no-handoff"]}
win = D["per_session"]
got = {order[r["n"] - 1]: r["plays"] for r in win if r["plays"]}
chk("jugadas: cada regla dispara donde se plantó y en ningún otro lado", got == EXP, got)
chk("jugadas: plays[] coincide con per_session", sorted((p["n"], p["rule"]) for p in D["plays"]) == sorted((order.index(n) + 1, r) for n, rs in EXP.items() for r in rs))
rc = Counter(p["rule"] for p in D["plays"])
chk("jugadas: dos por regla", dict(rc) == {"long-no-handoff": 2, "strong-on-mechanical": 2, "cold-cache": 2, "compact-no-handoff": 2}, dict(rc))
chk("jugadas: contexto en el límite exacto dispara; con /handoff o por debajo no",
    "long_edge" in got and "long_hand" not in got and "long_below" not in got)
chk("jugadas: strong-on-mechanical con 80% dispara, 75%, <5 llamadas, Edit o modelo barato no",
    "mech80" in got and not ({"mech75", "mech4", "mech_edit", "mech_cheap"} & set(got)))
chk("jugadas: el modelo dominante es el de más salida, no el más caro", "mech_dom" not in got)
chk("jugadas: strong-on-mechanical va marcada heurística", all(p["heuristic"] == (p["rule"] == "strong-on-mechanical") for p in D["plays"]))
chk("jugadas: cada fila trae los números que la dispararon", all(p["detail"] and p["values"] for p in D["plays"]))

# aggregates and shape
chk("conteos: v2, solo v1, ventana y ventana anterior",
    (D["sessions_v2"], D["sessions_v1_only"], len(win), D["previous_window"]["sessions"]) == (21, 1, 19, 1),
    (D["sessions_v2"], D["sessions_v1_only"], len(win), D["previous_window"]["sessions"]))
chk("per_session: numeración 1..N por inicio", [r["n"] for r in win] == list(range(1, 20)))
chk("umbrales usados salen de thresholds.json",
    D["thresholds_used"] == {"context-red": tv("context-red"), "cache-cold": tv("cache-cold"), "cache-hit-ok": tv("cache-hit-ok")}, D["thresholds_used"])
weeks = Counter("%d-W%02d" % local(E["starts"][n]).isocalendar()[:2] for n in E["starts"])
chk("by_week: semanas ISO locales, ordenadas, con todas las sesiones v2",
    [(w["week"], w["sessions"]) for w in D["by_week"]] == sorted(weeks.items()), [(w["week"], w["sessions"]) for w in D["by_week"]])
chk("by_project: etiquetas y costos", {p["label"]: p["cost_usd"] for p in D["by_project"] if p["label"] != "demo"} == {"other": 2.0, "home": 0.75}
    and abs(next(p for p in D["by_project"] if p["label"] == "demo")["cost_usd"] - sum(r["cost_usd"] for r in win if r["label"] == "demo")) < 1e-3,
    [(p["label"], p["cost_usd"]) for p in D["by_project"]])
chk("by_project: ordenado por costo", [p["cost_usd"] for p in D["by_project"]] == sorted((p["cost_usd"] for p in D["by_project"]), reverse=True))
chk("histograma de hora de inicio en hora local", D["start_hours"] == [Counter(local(E["starts"][n]).hour for n in order)[h] for h in range(24)])
PR = os.path.join(T, "claude", "projects")
exp = {"demo": 0, "other": 0, "home": 0, "sin-sesiones": 0}
for dd, lab in (("C--Users-zz-tester-work-demo", "demo"), ("C--Users-zz-tester-work-other", "other"), ("C--zz-home-dir", "home"), ("C--Users-zz-tester-work-empty", "sin-sesiones")):
    for b, _, ns in os.walk(os.path.join(PR, dd)): exp[lab] += sum(sz(os.path.join(b, x)) for x in ns)
chk("disco por proyecto: bytes de todo el árbol, sin-sesiones, orden descendente",
    D["disk_by_project"] == [{"label": k, "bytes": v} for k, v in sorted(exp.items(), key=lambda kv: -kv[1])], D["disk_by_project"])
chk("disco: la carpeta sin sesiones suma sus 1000 bytes", exp["sin-sesiones"] == 1000)
def keys(o):
    if isinstance(o, dict):
        for k, v in o.items(): yield k; yield from keys(v)
    elif isinstance(o, list):
        for v in o: yield from keys(v)
bad = {"project", "file", "cwd", "session_id", "sessionId"} & set(keys(D))
chk("privacidad: partidas.json no trae project, file, cwd ni ids de sesión", not bad, bad)
txt = open(os.path.join(T, "arch", "partidas.txt"), encoding="utf-8").read().splitlines()
chk("txt: 12 líneas o menos, con las jugadas por regla",
    0 < len(txt) <= 12 and any("long-no-handoff 2 · strong-on-mechanical 2 · cold-cache 2 · compact-no-handoff 2" in l for l in txt), len(txt))
PY
while IFS='|' read -r st lab why; do
  case "$st" in
    OK)  ok "$lab" ;;
    BAD) bad "$lab" "$why" ;;
    *)   bad "checker de datos" "$st $lab $why" ;;
  esac
done < "$T/checks.out"
grep -q '^OK|' "$T/checks.out" || bad "checker de datos" "no produjo resultados: $(tail -3 "$T/checks.out" | tr '\n' ' ')"

# --- privacy of the three outputs ----------------------------------------------------------
HOMEBASE=$("$PY" -c 'import os;print(os.path.basename(os.path.expanduser("~")))')
for needle in 'zz-tester' 'C--' 'C:\' '/Users/' 'deadbeef' 'PROMPTSENTINEL' 'v1only'; do
  n=$(cat "$T/arch/partidas.json" "$T/arch/partidas.html" "$T/arch/partidas.txt" | grep -cF -- "$needle")
  if [ "$n" -eq 0 ]; then ok "privacidad: ninguna salida contiene '$needle'"; else bad "privacidad: ninguna salida contiene '$needle'" "$n líneas"; fi
done
if [ "${#HOMEBASE}" -ge 4 ]; then
  n=$(cat "$T/arch/partidas.json" "$T/arch/partidas.html" "$T/arch/partidas.txt" | grep -ciF -- "$HOMEBASE")
  if [ "$n" -eq 0 ]; then ok "privacidad: ninguna salida contiene el usuario real"; else bad "privacidad: ninguna salida contiene el usuario real" "$n líneas"; fi
fi

# --- html: self-contained, themed, mobile ---------------------------------------------------
H="$T/arch/partidas.html"
if [ "$(grep -c 'http' "$H")" -eq 0 ]; then ok "html: sin ninguna referencia http (sin red)"; else bad "html: sin ninguna referencia http (sin red)" "$(grep -m1 -o '.\{20\}http.\{20\}' "$H")"; fi
if [ "$(grep -c '<script' "$H")" -eq 0 ]; then ok "html: sin <script>"; else bad "html: sin <script>" "hay scripts"; fi
if grep -q 'prefers-color-scheme:dark' "$H" && grep -q '#0D1117' "$H" && grep -q '#2DD4BF' "$H" && grep -q '#FFFFFF' "$H" && grep -q '#0D9488' "$H"; then ok "html: tokens del visor claro y oscuro"
else bad "html: tokens del visor claro y oscuro" "faltan"; fi
if grep -q '"JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace' "$H" && grep -q '"Space Grotesk", system-ui, sans-serif' "$H"; then ok "html: pilas de fuentes del visor"
else bad "html: pilas de fuentes del visor" "faltan"; fi
if grep -q 'name="viewport"' "$H" && grep -q 'overflow-x:auto' "$H" && [ "$(grep -o '<svg' "$H" | wc -l)" -ge 5 ]; then ok "html: viewport móvil, tablas con scroll propio y 5+ gráficos SVG"
else bad "html: viewport móvil, tablas con scroll propio y 5+ gráficos SVG" "faltan"; fi
if grep -q 'long-no-handoff' "$H" && grep -q 'Disco por proyecto' "$H"; then ok "html: tabla de jugadas y disco por proyecto"; else bad "html: tabla de jugadas y disco por proyecto" "faltan"; fi

# --- empty data renders "sin datos" ---------------------------------------------------------
mkdir -p "$T/arch4" "$T/claude4/projects"; cp "$T/claude/rules" -r "$T/claude4/rules"; echo '[]' > "$T/arch4/sessions.json"
"$PY" partidas.py --archive "$TW/arch4" --claude-dir "$TW/claude4" --now "$NOW" > "$T/p4.log" 2>&1; rc=$?
if [ $rc -eq 0 ] && grep -q 'sin datos' "$T/arch4/partidas.html" && grep -q 'sin datos' "$T/arch4/partidas.txt"; then ok "archivo vacío: las tres salidas dicen 'sin datos'"
else bad "archivo vacío: las tres salidas dicen 'sin datos'" "rc=$rc $(tail -1 "$T/p4.log")"; fi

# --- KIT_PROTECTED_PATHS ----------------------------------------------------------------------
mkdir -p "$T/arch2"; cp "$T/arch/sessions.json" "$T/arch2/"
KIT_PROTECTED_PATHS='^(other|home)$' "$PY" partidas.py --archive "$TW/arch2" --claude-dir "$TW/claude" --now "$NOW" > "$T/p2.log" 2>&1; rc=$?
n=$(cat "$T/arch2/partidas.json" "$T/arch2/partidas.html" "$T/arch2/partidas.txt" | grep -cE '"(other|home)"|>(other|home)<|(other|home) \$')
if [ $rc -eq 0 ] && [ "$n" -eq 0 ] && grep -q 'privado-1' "$T/arch2/partidas.json" && grep -q 'privado-2' "$T/arch2/partidas.json" && grep -q '"demo"' "$T/arch2/partidas.json"; then ok "KIT_PROTECTED_PATHS: las etiquetas protegidas salen como privado-N y demo se queda"
else bad "KIT_PROTECTED_PATHS: las etiquetas protegidas salen como privado-N y demo se queda" "rc=$rc fugas=$n"; fi

# --- thresholds unreadable: exit 2, no numeric fallback ------------------------------------------
mkdir -p "$T/c2/projects" "$T/c2/rules" "$T/c3/projects" "$T/c3/rules"
cp "$T/claude/rules/models.json" "$T/c2/rules/"; cp "$T/claude/rules/models.json" "$T/c3/rules/"
printf '{nope' > "$T/c3/rules/thresholds.json"
for pair in "c2:falta" "c3:ilegible"; do
  cdir=${pair%%:*}; why=${pair##*:}
  "$PY" "$TW/bin/harvest.py" --claude-dir "$TW/$cdir" --out "$TW/arch3-$cdir" > "$T/x1.log" 2>&1; rc1=$?
  "$PY" "$TW/bin/partidas.py" --archive "$TW/arch" --claude-dir "$TW/$cdir" > "$T/x2.log" 2>&1; rc2=$?
  if [ $rc1 -eq 2 ] && [ $rc2 -eq 2 ] && grep -q 'thresholds.json' "$T/x1.log" && grep -q 'thresholds.json' "$T/x2.log"; then ok "thresholds.json $why: harvest y partidas salen 2 y nombran el archivo"
  else bad "thresholds.json $why: harvest y partidas salen 2 y nombran el archivo" "harvest=$rc1 partidas=$rc2"; fi
done

echo
if (( fail )); then printf '%d OK, %d FALLA(S).\n' "$pass" "$fail"; exit 1; fi
printf '%d OK, 0 fallas.\n' "$pass"
