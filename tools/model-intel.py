#!/usr/bin/env python3
"""model-intel.py — harvest the current Claude model catalogue without spending a single LLM token.

Reads Anthropic's public docs (models overview, pricing, deprecations), extracts the model table,
writes a machine-readable snapshot and a human diff log. Meant to run weekly from a cron /
GitHub Action; `/route` and the manual read the snapshot instead of remembering numbers.

Outputs (relative to the repo root, override with --out):
  home/.claude/rules/models.json   current catalogue: id, family, tier, context, max_output,
                                   price_in, price_out, thinking, default_effort, cutoff,
                                   fetched_at, source urls
  docs/model-intel-log.md          append-only diff: new / removed / changed models per run

Exit codes: 0 no change · 3 catalogue changed (use it to open an issue or notify) · 1 fetch failed.

Design notes (why it is shaped like this):
- No LLM in the loop: the table is structured on the page; a regex is deterministic and free.
  This is the kit's layer rule — a model only ORCHESTRATES what code cannot do.
- Judgement (which lane gets which model, effort per task) is NOT harvested. It lives in
  rules/routing.json, edited by hand, and this script only reports when its inputs moved.
- Benchmarks (Artificial Analysis, LMArena) are deliberately out of v0: they are noisy, change
  methodology, and most have no stable public endpoint. Add them as a second source only after
  a month of stable runs of this one; keep them in a separate file so a failure there never
  blocks the catalogue.
- The docs site may serve a Markdown twin of each page (`<url>.md`) — tried first because it is
  smaller and stable; HTML is the fallback. Neither is guaranteed: if both parsers find zero
  models, the script fails loudly (exit 1) instead of writing an empty catalogue.
"""
from __future__ import annotations
import argparse, datetime as dt, html, json, re, ssl, sys, urllib.request, pathlib

PAGES = {
    "overview": "https://platform.claude.com/docs/en/models/overview",
    "pricing": "https://platform.claude.com/docs/en/about-claude/pricing",
    "deprecations": "https://platform.claude.com/docs/en/about-claude/model-deprecations",
}
UA = {"User-Agent": "model-intel/0.1 (+https://github.com/IchiSieben/claude-kit)"}
# Matches both naming schemes: claude-opus-5-5, claude-haiku-4-5-20251001, claude-3-5-haiku-20241022.
ID_RE = re.compile(r"\bclaude-(?:[0-9]+-)*(fable|mythos|opus|sonnet|haiku)(?:-[0-9a-z]+)*\b")
PRICE_RE = re.compile(r"\$\s?([0-9]+(?:\.[0-9]+)?)\s*/\s*(?:input |output )?MTok", re.I)
TOK_RE = re.compile(r"\b(\d+(?:\.\d+)?)\s*([KM])\b", re.I)
MONTH_RE = re.compile(r"\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+20\d\d\b")


def _ssl_context() -> ssl.SSLContext:
    """certifi's bundle when installed: some Windows Pythons ship an expired root and fail TLS
    against the docs site with CERTIFICATE_VERIFY_FAILED (seen 2026-09-26). CI uses the system store."""
    try:
        import certifi  # type: ignore
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def fetch(url: str, timeout: int = 30) -> str:
    ctx, last = _ssl_context(), None
    for candidate in (url + ".md", url):
        try:
            req = urllib.request.Request(candidate, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as r:
                body = r.read().decode("utf-8", "replace")
                if body.strip():
                    return body
        except Exception as e:  # noqa: BLE001 — we want the fallback, then a loud failure
            last = e
    raise RuntimeError(f"fetch failed: {url}: {last}")


def to_text(page: str) -> str:
    """Markdown passes through; HTML is flattened to '| a | b |' lines so the table parser reads both."""
    if "<html" not in page[:2000].lower():
        return page
    page = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", page, flags=re.S | re.I)
    page = re.sub(r"<tr[^>]*>", "\n| ", page, flags=re.I)
    page = re.sub(r"</t[dh]>", " | ", page, flags=re.I)
    page = re.sub(r"</tr>", "\n", page, flags=re.I)
    page = re.sub(r"<br\s*/?>", " ", page, flags=re.I)
    page = re.sub(r"<[^>]+>", " ", page)
    return html.unescape(page)


def _clean(cell: str) -> str:
    """Strip markdown links, code ticks, footnote markers and extra spaces from one table cell."""
    cell = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", cell)
    cell = re.sub(r"<sup>.*?</sup>|<[^>]+>|`", "", cell)
    return re.sub(r"\s+", " ", cell).strip()


def tables(text: str) -> list[list[list[str]]]:
    """Every pipe table in the text as a list of rows of cleaned cells (separator rows dropped)."""
    out, cur = [], []
    for line in text.splitlines() + [""]:
        if line.lstrip().startswith("|"):
            cells = [_clean(c) for c in line.strip().strip("|").split("|")]
            if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
                cur.append(cells)
        elif cur:
            out.append(cur)
            cur = []
    return out


def _tokens(cell: str) -> int | None:
    m = TOK_RE.search(cell)
    return int(float(m.group(1)) * (1_000_000 if m.group(2).upper() == "M" else 1_000)) if m else None


def _slug(name: str) -> str:
    """'Claude Opus 4.5 (retired ...)' -> 'claude-opus-4-5'."""
    name = re.sub(r"\(.*?\)", "", name).strip().lower()
    return re.sub(r"[^a-z0-9]+", "-", name).strip("-")


def _empty(mid: str) -> dict:
    return {"id": mid, "family": ID_RE.search(mid).group(1), "tier": None, "name": None,
            "context": None, "max_output": None, "price_in": None, "price_out": None,
            "price_cache_hit": None, "price_cache_write_5m": None, "price_cache_write_1h": None, "thinking": None, "default_effort": None, "cutoff": None,
            "latency": None, "state": None, "retirement": None, "current": False}


def _price(cells: list[str], i: int | None) -> float | None:
    if i is None or i >= len(cells):
        return None
    m = PRICE_RE.search(cells[i])
    return float(m.group(1)) if m else None


def parse_models(overview: str, pricing: str = "", deprecations: str = "") -> dict[str, dict]:
    """Regex/table parse of the three pages (layout as of 2026-09-26, see docs/model-intel-log.md):
    - overview: ONE transposed table, models are columns; row labels are the first cell.
    - deprecations: 'API model name | Current state | Deprecated | Tentative retirement date'.
    - pricing: 'Model | Base input tokens | ... | Cache hits ... | Output tokens', keyed by display name.
    Fields a page does not expose stay null. `current` = in the overview's lineup table."""
    models: dict[str, dict] = {}

    for t in tables(overview):
        by_label = {r[0].lower(): r[1:] for r in t if r}
        ids = by_label.get("claude api id")
        if not ids:
            continue
        names = t[0][1:]
        for col, raw in enumerate(ids):
            m = ID_RE.search(raw)
            if not m:
                continue
            row = models.setdefault(m.group(0), _empty(m.group(0)))

            def cell(label: str) -> str:
                vals = by_label.get(label) or []
                return vals[col] if col < len(vals) else ""

            row["current"] = True
            row["name"] = names[col] if col < len(names) else None
            prices = [float(p) for p in PRICE_RE.findall(cell("pricing"))]
            if len(prices) >= 2:
                row["price_in"], row["price_out"] = prices[0], prices[1]
            row["context"] = _tokens(cell("context window"))
            row["max_output"] = _tokens(cell("max output"))
            th = cell("thinking").lower()
            row["thinking"] = "adaptive" if "adaptive" in th else "extended" if "extended" in th else (th or None)
            eff = cell("default effort").lower()
            row["default_effort"] = eff if eff in ("low", "medium", "high", "xhigh", "max") else None
            cm = MONTH_RE.search(cell("reliable knowledge cutoff"))
            row["cutoff"] = cm.group(0) if cm else None
            row["latency"] = cell("comparative latency") or None

    for t in tables(deprecations):
        head = [c.lower() for c in t[0]]
        if "api model name" not in head or "current state" not in head:
            continue
        i_id, i_st = head.index("api model name"), head.index("current state")
        i_ret = next((i for i, h in enumerate(head) if "retirement" in h), None)
        for r in t[1:]:
            m = ID_RE.search(r[i_id]) if i_id < len(r) else None
            if not m:
                continue
            row = models.setdefault(m.group(0), _empty(m.group(0)))
            row["state"] = r[i_st].lower() if i_st < len(r) else None
            if i_ret is not None and i_ret < len(r):
                row["retirement"] = r[i_ret]

    # Pricing rows are keyed by display name: 'Claude Haiku 4.5' -> claude-haiku-4-5[-YYYYMMDD],
    # legacy 'Claude Haiku 3.5' -> claude-3-5-haiku[-YYYYMMDD].
    def ids_for(name: str) -> list[str]:
        parts = _slug(name).split("-")
        cands = {"-".join(parts), "-".join(["claude"] + parts[2:] + parts[1:2])}
        return [mid for mid in models
                if any(mid == c or re.fullmatch(re.escape(c) + r"-\d{8}", mid) for c in cands)]

    for t in tables(pricing):
        head = [c.lower() for c in t[0]]
        if not head or head[0] != "model" or not any("input" in h for h in head):
            continue
        i_in = next(i for i, h in enumerate(head) if "input" in h)
        i_out = next((i for i, h in enumerate(head) if "output" in h), None)
        i_hit = next((i for i, h in enumerate(head) if "hit" in h), None)
        i_w5 = next((i for i, h in enumerate(head) if "5m" in h and "write" in h), None)
        i_w1h = next((i for i, h in enumerate(head) if "1h" in h and "write" in h), None)
        for r in t[1:]:
            for mid in ids_for(r[0]):
                row = models[mid]
                if row["price_in"] is None:
                    row["price_in"] = _price(r, i_in)
                if row["price_out"] is None:
                    row["price_out"] = _price(r, i_out)
                row["price_cache_hit"] = _price(r, i_hit)
                row["price_cache_write_5m"] = _price(r, i_w5)
                row["price_cache_write_1h"] = _price(r, i_w1h)
                row["name"] = row["name"] or re.sub(r"\(.*?\)", "", r[0]).strip()
        break  # the first model table is the standard API price list; later ones are per-platform
    return models


def tier_of(family: str) -> str:
    return {"fable": "frontier", "mythos": "frontier", "opus": "flagship",
            "sonnet": "balanced", "haiku": "fast"}.get(family, "unknown")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=".", help="repo root")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    root = pathlib.Path(a.out)
    snap_path = root / "home/.claude/rules/models.json"
    log_path = root / "docs/model-intel-log.md"

    texts, errors = {}, []
    for key, url in PAGES.items():
        try:
            texts[key] = to_text(fetch(url))
        except Exception as e:  # noqa: BLE001
            errors.append(f"{key}: {e}")
    if "overview" not in texts:
        print("FAIL: models overview unreachable:", *errors, file=sys.stderr)
        return 1

    models = parse_models(texts["overview"], texts.get("pricing", ""), texts.get("deprecations", ""))
    if not any(r["current"] for r in models.values()):
        print("FAIL: zero current models parsed — page layout changed; fix parse_models before trusting anything", file=sys.stderr)
        return 1
    for row in models.values():
        row["tier"] = tier_of(row["family"])
        row["deprecated"] = row["state"] in ("deprecated", "retired")

    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()
    snapshot = {"fetched_at": now, "sources": PAGES, "errors": errors,
                "models": sorted(models.values(), key=lambda r: (not r["current"], r["tier"], r["id"]))}

    old = json.loads(snap_path.read_text()) if snap_path.exists() else {"models": []}
    old_by = {m["id"]: m for m in old["models"]}
    new_by = {m["id"]: m for m in snapshot["models"]}
    added = sorted(set(new_by) - set(old_by))
    removed = sorted(set(old_by) - set(new_by))
    changed = []
    for mid in set(new_by) & set(old_by):
        diff = {k: (old_by[mid].get(k), v) for k, v in new_by[mid].items()
                if k not in ("fetched_at",) and old_by[mid].get(k) != v and v is not None}
        if diff:
            changed.append((mid, diff))

    lines = [f"## {now}", ""]
    lines += [f"- NEW {m}: {json.dumps(new_by[m])}" for m in added]
    lines += [f"- REMOVED {m}" for m in removed]
    lines += [f"- CHANGED {m}: " + ", ".join(f"{k} {o}→{n}" for k, (o, n) in d.items()) for m, d in changed]
    lines += [f"- WARN {e}" for e in errors]
    if not (added or removed or changed):
        lines.append("- no change")
    print("\n".join(lines))

    if a.dry_run:
        return 3 if (added or removed or changed) else 0
    snap_path.parent.mkdir(parents=True, exist_ok=True)
    snap_path.write_text(json.dumps(snapshot, indent=2) + "\n", encoding="utf-8", newline="\n")
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with open(log_path, "a", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n\n")
    return 3 if (added or removed or changed) else 0


if __name__ == "__main__":
    sys.exit(main())
