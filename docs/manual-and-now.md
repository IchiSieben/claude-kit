---
lesson:
  route: code-like-me
  order: 8
  level: 1
---

# The manual, `/ahora`, and where the numbers live

## `home/.claude/MANUAL.md`: seven chapters, loaded on demand

| # | Chapter |
|---|---|
| 1 | Lanes and routing |
| 2 | Session lifecycle |
| 3 | HANDOFF |
| 4 | Status-line glossary |
| 5 | Delegation |
| 6 | Security |
| 7 | Cost and quota |

`/manual` prints this index verbatim; `/manual <1-7>` prints one chapter verbatim. The
`manual` skill resolves the file itself (`~/.claude/MANUAL.md`, mirrored on every machine,
falling back to the repo copy) and is explicit that it must not summarize, shorten or
"improve" the output — the reader is checking the exact rule and its `Fuente:` line.

Source: `home/.claude/MANUAL.md` (index); `home/.claude/skills/manual/SKILL.md`.

## Why the manual is never loaded per session

`CLAUDE.md` is re-read every session and carries a comment capping it under 70 lines,
explicitly calling that a *context budget, not a style rule* — it must be shrunk by cutting
prose, never by cutting a rule, and every rule in it must trace to a repeated failure.
`MANUAL.md` is roughly 500 lines of Spanish written for a human, not the model, and is
deliberately not `@`-imported: doing so would load that much text into every session for
content only the owner reads.

Source: `home/.claude/CLAUDE.md` (header comment, lines 2-3); `docs/statusline-internals.md`
§"The manual".

## The split: CLAUDE.md is what, MANUAL.md is why

`CLAUDE.md`'s own header states it directly: *"The WHY behind every rule below, with
examples and open questions: MANUAL.md... Rules live HERE; if the two disagree, this file
wins and the manual is stale."* `CLAUDE.md` and `rules/` hold what the model must obey;
`MANUAL.md` holds the why and the worked example, for a human. Nothing the model must *do*
may live only in the manual — if it did, the model would never see it. The `manual` skill
repeats the same rule from the reading side: never answer a rules question from memory when
the manual covers it, print the chapter instead.

Source: `home/.claude/CLAUDE.md` (header comment, line 3); `home/.claude/skills/manual/SKILL.md`
§Rules; `docs/statusline-internals.md` §"The manual".

## `/ahora`: state now, one action, the threshold behind it

`/ahora` runs `statusline.sh --ahora`, the same evaluator the bar itself uses, so the two
can never disagree — that is the layer rule from chapter 1 applied to the bar itself: a
model does not have to DO this, only show it. It prints exactly three lines and stops: (1)
`ahora:` the numbers the status line last saw and how old that snapshot is, (2) `hacé:` the
action of the single highest-priority threshold currently crossed, and (3) `por qué:` which
threshold, its condition, and the source file.

It cannot read quota from transcripts because the 5h quota and the cache hit ratio exist
only inside the status line's own JSON payload — they are not written into the conversation
transcript at all. So `/ahora` reads the bar's last snapshot for the current directory (a
skill is not handed `$CLAUDE_SESSION_ID`, confirmed by measurement) rather than computing
anything from history, and an old snapshot means the numbers it reports are old, which the
line says explicitly.

Source: `home/.claude/skills/ahora/SKILL.md`.

## `rules/thresholds.json`: the one place the numbers live

The manual states this about itself, verbatim in its header (Spanish):

> "Los umbrales que aparecen en los capítulos 2, 4 y 7 no están escritos en este manual ni
> en el código: viven en `rules/thresholds.json`, que es lo que leen la barra, los hooks y
> `/ahora`. Si un número de acá no coincide con ese archivo, el archivo tiene razón."

In English: *the thresholds that appear in chapters 2, 4 and 7 are not written in this
manual or in the code: they live in `rules/thresholds.json`, which is what the bar, the
hooks and `/ahora` read. If a number here disagrees with that file, the file is right.*

`thresholds.json` itself carries the same contract in its own `_readme` block: each entry
has a stable `id` (looked up by id, never position), a `priority` (lower fires first, and
the bar shows only the single lowest-priority match), a `condition`, and a `source` —
"No source = it is invented and must be deleted." A metric that could not be measured reads
as `-1` and never matches, because unknown must never look like zero. A missing or
unreadable file is not license to fall back to a hardcoded default: the bar prints an amber
`⚠ umbrales` and stops colouring and hinting instead.

Source: `home/.claude/MANUAL.md` (header, lines 18-20); `home/.claude/rules/thresholds.json`
(`_readme`).

## `Fuente:` and `[PENDIENTE]` as features, not gaps

Every rule in the manual carries a `Fuente:` line naming the file it came from. A rule with
no source is treated as invented and must be deleted — `verify.sh` audits this. Items still
genuinely undecided are marked `[PENDIENTE]` and must never be resolved on the fly; the
`manual` skill repeats this explicitly: `[PENDIENTE]` markers are real, they mean the
decision was never made, and a question about one must be reported as pending, not
answered. Two such items were live in the manual and were closed on 2026-09-18 (the context
band and the default action after a handoff); two remain open as of this writing: when
`opusplan` applies (chapter 1), and the spending budget (chapter 7).

This is deliberate discipline, not an oversight the kit hasn't gotten to: it keeps every
claim traceable and keeps the model from ever fabricating a decided-sounding answer to a
question nobody has actually settled.

Source: `home/.claude/MANUAL.md` (opening paragraph and both chapters' `[PENDIENTE]`
sections); `home/.claude/skills/manual/SKILL.md` §Rules; `docs/statusline-internals.md`
§"The manual".
