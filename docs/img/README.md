# docs/img — screenshot notes for the owner

Not a build artifact: `tools/build-kit.sh` never touches this directory (see its header
comment). These are hand-captured screenshots plus the synthetic renders from
`docs/tapes/render-states.sh` (`statusline-warm/cooling/cold/near-compact/stale-handoff.png`
and `statusline-states.gif`, which do not need this note — they are generated from fixtures,
not real sessions, so there is nothing to disclose about them).

## The four real captures show bypass mode

Checked 2026-09-22: all four real screenshots currently used in `README.md` / `README.es.md`
show `▶▶ bypass permissions on` in their prompt-mode row —

- `statusline-map.png`
- `statusline-fable-push-hint.png`
- `statusline-sonnet-subagent.png`
- `statusline-fable-dirty-handoff.png`

This page does not retake any of them. It records the decision so the owner can act on it at
home, where a default-mode terminal is available.

**`statusline-map.png` gets recaptured in default mode.** It is the generic teaching image for
`docs/statusline.md`'s callout table — the one image most likely to be someone's first look at
the bar — and showing bypass there as if it were the normal state is misleading.

**Keep exactly one bypass capture, captioned honestly: `statusline-sonnet-subagent.png`.** Of
the four, this is the one where bypass mode is contextually true, not incidental — it shows a
`redactor` subagent mid-task, which is what unattended/agent-driven work actually looks like.
Suggested caption, replacing the current README lines for this image:

> Unattended runs use bypass with a scoped prompt, a hard stop and reviewer gates — see
> Roadmap → UNATTENDED. This capture shows that mode, not the default one.

**`statusline-fable-push-hint.png` and `statusline-fable-dirty-handoff.png` are not covered by
the "keep one" rule** — they illustrate the push-hint and stale-HANDOFF signals, which have
nothing to do with bypass mode, so bypass showing in them is incidental, not honest context.
Recapture both in default mode next time the owner is home; nothing about their content
depends on the permission mode.
