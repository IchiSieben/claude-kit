# References

The kit cites evidence for a few of its rules. References are expected to change as the
evidence does — a paper gets retracted, a stronger study replaces it, or someone finds the kit
is citing a paper for a claim it doesn't actually make. If you want to challenge, replace or add
a reference, open an issue with `.github/ISSUE_TEMPLATE/reference.md`.

This page only lists references that could be resolved to a real, checkable source and read.
Anything cited by the kit that could not be verified this way is in the last section, not here.

## Verified

### Review

| Reference | Cited by | What it actually found |
|---|---|---|
| Panickssery et al., "LLM Evaluators Recognize and Favor Their Own Generations," NeurIPS 2024. [arXiv:2404.13076](https://arxiv.org/abs/2404.13076) | `skills/xreview/SKILL.md` ("same-model self-review is biased toward approval") · `MANUAL.md` §5 ("sesgo de auto-preferencia") | Self-preference bias is real and scales with self-recognition ability: the more reliably a model can tell its own output apart from another's, the more it favors that output, even when human raters see the two as equal quality. |
| Mathews & Nagappan, "Test-Driven Development and LLM-based Code Generation," ASE 2024. [Related preprint discussion](https://arxiv.org/abs/2402.13521) | `skills/spec/SKILL.md` ("tests-as-spec raise solve rates") | Their TGen approach generates code from an initial set of tests inside a TDD loop; feeding tests to the model as an executable spec measurably improved the accuracy and reliability of the generated code. |

### Learning

| Reference | Cited by | What it actually found |
|---|---|---|
| Shen & Tamkin, "How AI Impacts Skill Formation," Feb 2026. [arXiv:2601.20245](https://arxiv.org/pdf/2601.20245) | `rules/learning-mode.md` ("delegating fully lowers comprehension... explanations alongside code... preserve it") | RCT with 52 junior programmers learning an unfamiliar Python library, half with an AI assistant. The AI group scored lower on a comprehension quiz overall (50% vs 67%), but the effect depended on *how* people used the assistant: those who delegated ("write this code") scored below 40%, while those who used it as a tutor ("why does this work?") scored above 65% — matching or beating the no-AI group. The kit's rule reflects this correctly. |

## Context, routing & cost, and multi-agent design — background reading, not directly cited

The kit's rules on context budgets (`rules/context-hygiene.md`), model routing (`skills/route/SKILL.md`),
and delegation (`MANUAL.md` §5) are consistent with the following well-known results, but a grep of
the kit's `home/.claude/` tree found no line that names any of these five papers. They are listed
here because they were given to the person writing this page as candidate justifications; the kit
itself does not currently cite them. Do not read the rows below as "the kit says X because paper Y" —
read them as "here is what the field has published on the topic that rule addresses."

| Reference | Related kit rule | What it actually found |
|---|---|---|
| Chen, Zaharia & Zou, "FrugalGPT: How to Use Large Language Models While Reducing Cost and Improving Performance," 2023. [arXiv:2305.05176](https://arxiv.org/abs/2305.05176) | `skills/route/SKILL.md` (cheap-first cascade) | An LLM cascade that learns which combination of cheap/expensive models to try, in order, per query. Matches GPT-4-level accuracy at up to 98% lower cost in their experiments. |
| Ong et al., "RouteLLM: Learning to Route LLMs with Preference Data," ICLR 2025. [arXiv:2406.18665](https://arxiv.org/abs/2406.18665) | `skills/route/SKILL.md` (routing rules table) | Trains a binary router on ~80k Chatbot Arena battles plus synthetic data to predict, per query, whether a weak or strong model will win — a learned cost/quality trade-off, not a hand-written rule table like the kit's. |
| Liu et al., "Lost in the Middle: How Language Models Use Long Contexts," 2023. [arXiv:2307.03172](https://arxiv.org/abs/2307.03172) | `rules/context-hygiene.md` (working band, summarize instead of pasting full logs) | Retrieval accuracy over long contexts is U-shaped: models find information best near the start or end of the context and worst in the middle, even when the context fits the window. |
| Chroma, "Context Rot: How Increasing Input Tokens Impacts LLM Performance," technical report, July 2025. [research.trychroma.com](https://www.trychroma.com/research/context-rot) | `rules/context-hygiene.md` (absolute-token working band, not percentage of window) | Across 18 models, performance is not flat as input length grows — it degrades unevenly depending on needle-distractor similarity, haystack structure and other factors, so "fits in the context window" is not the same as "the model will use it reliably." |
| Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" 2025 (MAST taxonomy). [arXiv:2503.13657](https://arxiv.org/abs/2503.13657) | `MANUAL.md` §5 (subagents execute, main thread decides; keep coordination minimal) | Analysis of 1,642 traces from 7 multi-agent frameworks found 41-86.7% task failure rates and built a 14-mode failure taxonomy (MAST) across design, inter-agent misalignment and verification issues — evidence that adding agents adds a real coordination-failure surface, not a free win. |
| Narayan, Biderman, Eyuboglu et al., "Minions: Cost-efficient Collaboration Between On-device and Cloud Language Models," 2025 (ICML 2025). [arXiv:2502.15964](https://arxiv.org/abs/2502.15964) | `skills/route/SKILL.md` / `MANUAL.md` §5 (cheap tasks stay local/small) | A small on-device model reads the full local context and only sends short, decomposed sub-tasks to a cloud model; their naive protocol cuts remote cost ~30x while keeping ~87% of the frontier model's accuracy. |
| Belcak, Heinrich, Diao et al. (NVIDIA), "Small Language Models are the Future of Agentic AI," 2025. [arXiv:2506.02153](https://arxiv.org/abs/2506.02153) | `skills/route/SKILL.md` (haiku/sonnet for mechanical work) | Argues most single-purpose, repetitive steps inside agentic systems don't need a frontier model: small models (under ~10B params) can serve them at a fraction of the cost, reserving large generalist models for genuinely open-ended steps. |

## Unverified — owner to confirm

The kit's `MANUAL.md` §5 cites `Xiang 2026` for "reviewer must be at least as strong as the author,"
and `skills/xreview/SKILL.md` cites `Panickssery 2024; Xiang 2026, Yang 2026` for the forced-choice
review rubric. Neither `Xiang` nor `Yang` resolves to a specific, findable 2026 paper:

- **Xiang 2026** — searched arXiv for LLM-judge / reviewer-strength-asymmetry papers by an author
  named Xiang published in 2026; found no matching paper. The closest topical match, "Can LLMs
  Judge Better Than They Generate?" (arXiv:2606.28050), is by a different author (Bandyopadhyay)
  and is about judge/generator asymmetry in general, not "reviewer ≥ author."
- **Yang 2026** — searched for a 2026 paper on weaker LLM reviewers causing harmful edits or on
  cross-model code-review rubrics; found "Stop Automating Peer Review Without Rigorous Evaluation,"
  which credits feedback to a Diyi Yang, but that paper is about ICML's human peer-review policy, not
  about an LLM code-review rubric — it does not match the claim it is cited for.

`MANUAL.md` itself does not mention `Lodha 2026` or `Min 2026` / "CAT" anywhere — a grep of the whole
`home/.claude/` tree found no trace of either name. Searches for a 2026 arXiv paper by a "Lodha" on
LLM agents, and for a 2026 paper by "Min" introducing something called "CAT," returned no plausible
match. These two references cannot be tied to any specific rule in the kit as it stands today; the
owner should say what they were meant to support, or drop them.

`skills/spec/SKILL.md` also cites `Tufano et al. 2026` for "writing the contract... measurably
improves bug detection." No 2026 paper by a first author Tufano on preconditions/postconditions and
bug detection could be found; only earlier Tufano work (2024 and prior) on unrelated code-review
topics turned up. Listed here rather than under Verified.

---

The kit's own rules cite these sources with `Fuente:` lines directly inside `MANUAL.md` — this page
exists to check those citations against the real papers, not to replace them.
