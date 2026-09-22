---
name: manual
description: Print the kit's operating manual — the index with no argument, or one numbered chapter with `/manual 3`. Covers routing lanes, session lifecycle, HANDOFF, the status line glossary, delegation, security and cost. Use when asked how the kit works, which model or effort to use, what a status-line symbol means, or what the non-negotiable rules are.
disable-model-invocation: true
argument-hint: "[chapter number 1-7, empty for the index]"
allowed-tools: Bash(awk *) Bash(sed *) Bash(test *) Bash(ls *)
---

# Manual: $ARGUMENTS

`MANUAL.md` is mirrored to `~/.claude/MANUAL.md` on every machine, so this works from any
repo. Fall back to the repo copy only if the mirrored one is missing.

Resolve the file first:

```bash
M="$HOME/.claude/MANUAL.md"
[ -f "$M" ] || M="$HOME/claude-kit/home/.claude/MANUAL.md"
[ -f "$M" ] || { echo "No encuentro MANUAL.md. Corré: bash kit-update.sh"; exit 1; }
```

## No argument — print the index

```bash
sed -n '1,/^---$/p' "$M"
```

That is the header plus the chapter table. Print it verbatim, then add one line:
`Para un capítulo: /manual <número>`. Do not summarise it and do not add commentary.

## With a number — print that chapter

```bash
awk -v n="$ARGUMENTS." '/^## [0-9]+\./{p=($2==n)} p' "$M"
```

Print the output **verbatim**. This is a reference document: reformatting it, shortening it
or "improving" it defeats the purpose, because the reader is checking the exact rule and its
`Fuente:` line.

If the command prints nothing, the chapter does not exist — say so and print the index instead.

## Rules

- The manual is the source for the *why*; `CLAUDE.md` and `rules/` are the source for what the
  model must do. If they disagree, `CLAUDE.md` wins and the manual is out of date — say so.
- Never answer a question about kit rules from memory when the manual covers it. Print the
  chapter.
- `[PENDIENTE]` markers are real: they mean the decision was never made. Never resolve one on
  the fly — report it as pending.
