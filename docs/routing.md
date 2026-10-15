---
lesson:
  route: code-like-me
  order: 2
  level: 1
---

# Routing: layer, then lane

## The layer question, first

Before picking a model, ask whether one is needed at all. Deterministic, repeatable work
goes to code that runs without a model (Python/SQL/shell). Judgment, glue and variable
inputs go to instructions (skills, agents, rules). The question that decides it: *does a
model have to DO this, or only ORCHESTRATE it?*

Source: `home/.claude/CLAUDE.md` §Routing.

## The lanes

| Lane | Agent | Model | Effort | Tools | When |
|---|---|---|---|---|---|
| Trivial | `mecanico` | haiku | — | Read, Grep, Glob, Bash | Search, list, read logs, extract, count, rename |
| Mechanical | `operario` | sonnet | low | (all) | The decision is already made; it only needs writing |
| Prose | `redactor` | sonnet | medium | (all) | READMEs, commits, reports, TDRs, translations |
| Recon | `investigador` | sonnet | medium | (all) | Before touching a repo the session doesn't know |
| Ambiguous | `profundo` | opus | xhigh | (all) | Root cause unclear, real architectural trade-offs |

Source: `home/.claude/CLAUDE.md` §Routing table; frontmatter of `home/.claude/agents/mecanico.md`,
`operario.md`, `redactor.md`, `investigador.md`, `profundo.md`. `mecanico` is the only one of
the five whose frontmatter restricts `tools:`; the other four inherit the full toolset.

A sixth agent, `reviewer` (opus, high, tools restricted to `Read, Grep, Glob, Bash(git *)`),
does not appear in this table because it is not a lane you route ordinary work to — see
`docs/reviewer.md`.

## The six rules

1. **Recon first.** More than 3-4 files to read: delegate to `investigador` instead of
   reading them in this thread. Only the summary comes back.
2. **The main thread decides, subagents execute.** The session settles the what and the
   how; the writing is delegated.
3. **`profundo` is earned, not assumed.** The trigger is ambiguity, not size. A 20-file
   refactor with the pattern already defined is `operario`.
4. **Do not delegate what is already in context.** Handing a file already read to a
   subagent makes it more expensive, not cheaper.
5. **More reasoning in the same thread: `ultrathink`**, rather than raising the session
   level.
6. **Never switch the session model to get a review.** Reviewer >= author, but switching
   mid-session invalidates the prompt cache; spawn `reviewer` instead.

Source: `home/.claude/CLAUDE.md` §Routing, rules 1-6.

## The cheap path is the default

`CLAUDE_CODE_SUBAGENT_MODEL=sonnet` is set in `home/.claude/settings.json`. Every
delegation, unless an agent's own frontmatter overrides the model (as `mecanico` does with
`haiku` and `profundo`/`reviewer` do with `opus`), already runs on the cheap model. A large
session with zero subagent calls is not using this lever.

Source: `home/.claude/settings.json` (`CLAUDE_CODE_SUBAGENT_MODEL`).

## `/route`

The `route` skill (`home/.claude/skills/route/SKILL.md`) recommends model, effort and
execution mode (main session / subagent / new session / worktree / `claude -p` batch) for a
described task, before work starts. It answers in a fixed table (type, model, effort,
where, cache cost, needs SPEC.md, needs plan mode, external review after) plus one line of
reasoning.

Its cheap-first cascade: mechanical work is sonnet/medium; a feature in known code is
opus/high (or sonnet/high if the pattern already exists); unclear-cause debugging is
opus/high starting from a reproduction command; architecture/security/long autonomous runs
are fable/high-xhigh with plan mode and a SPEC.md first; research/exploration goes to the
`Explore` subagent; and for review, the reviewer must be at least as strong as the author —
sonnet-written code gets an opus review, opus-written gets fable, and fable-written gets
tests plus an external CLI review (same-model self-review adds ~nothing).

The skill names the prompt-cache cost explicitly: each model (and, on most models, each
effort level) has its own prompt cache, so switching either mid-session forces the next
request to re-read the whole conversation with no cache hits — cache reads bill at roughly
10% of standard input, making a switch deep into a long session the most expensive keystroke
available. Its conclusions: never recommend switching the session model to get a review
(spawn `reviewer` instead); pick model and effort at the top of a session, and recommend a
new session rather than a switch if the task needs a different one; `opusplan` re-switches
the model on every plan-mode toggle, so it's not recommended for long sessions; and
`/rewind` beats `/compact` when abandoning a path, because rewind truncates back to an
already-cached prefix while compact builds a new one.

Source: `home/.claude/skills/route/SKILL.md`.
