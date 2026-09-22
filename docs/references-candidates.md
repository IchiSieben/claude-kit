# Reference candidates — owner to pick

Five citations in the kit could not be resolved to a real, checkable paper (see
[`docs/references.md`](references.md) → Unverified). As of 2026-09-22, the rules that used to
cite them have been re-anchored to what *is* verified — Panickssery et al. 2024 for the
reviewer-strength gate — and the five names have been removed from the kit's own prose. They
survive only here, as candidates, so the owner can resolve or formally drop each one without
re-running the search from scratch.

For each: up to 3 candidates found, with why none is a confident match.

## Xiang 2026

Cited (until this pass) for "reviewer must be at least as strong as the author" / the
forced-choice review rubric.

1. Bandyopadhyay, "Can LLMs Judge Better Than They Generate?" [arXiv:2606.28050](https://arxiv.org/abs/2606.28050) — same topic family (judge/generator asymmetry), different author, no "Xiang" byline found on any matching 2026 paper.

No paper by an author named Xiang, published 2026, matching this claim was found. Candidate 1
is the closest topical match, offered so the owner can check it is not a co-author or a
mis-transcribed name from Panickssery's citation list.

## Yang 2026

Cited (until this pass) alongside Xiang 2026 for the same forced-choice rubric claim.

1. "Stop Automating Peer Review Without Rigorous Evaluation," credits a Diyi Yang — but the paper is about ICML's human peer-review policy, not an LLM code-review rubric. Topic mismatch, not a candidate match.

No 2026 paper on weaker-reviewer harm or cross-model review rubrics by an author named Yang was
found. Recommendation: drop, or replace with a first-hand description ("own practice, not yet
backed by a paper") if the owner cannot supply the source.

## Lodha 2026

Not cited anywhere in the kit's `home/.claude/` tree (grepped 2026-09-22, zero hits before and
after this pass). No rule references it, so there is nothing to re-anchor — only this entry,
in case the owner remembers what it was meant to support.

No candidates found; the search terms tried ("Lodha 2026 LLM agent", "Lodha arxiv 2026 agentic")
returned nothing plausible.

## Min 2026 ("CAT")

Same situation as Lodha: not cited anywhere in the kit's tree. No paper introducing a "CAT"
method/benchmark by a first author named Min, dated 2026, was found.

No candidates found.

## Tufano 2026

Cited (until this pass) in `skills/spec/SKILL.md` for "writing the contract (pre/post-conditions,
undefined behavior) before code measurably improves bug detection."

Fresh search run 2026-09-22 (not just the earlier pass already recorded in `references.md`):

1. "Breaking the Myth: Can Small Models Infer Postconditions Too?" [arXiv:2507.10182](https://arxiv.org/pdf/2507.10182) — right topic (postcondition inference), no Tufano byline, 2025 not 2026.
2. "Beyond Postconditions: Can Large Language Models infer Formal Contracts for..." [arXiv:2510.12702](https://arxiv.org/pdf/2510.12702) — right topic, no Tufano byline, 2025.
3. Michele Tufano's own confirmed 2023-2024 work ("Predicting Code Coverage without Execution," [arXiv:2307.13383](https://arxiv.org/abs/2307.13383); AutoDev, 2024) — right author, wrong topic (coverage prediction / dev-agent automation, not pre/post-conditions) and wrong year.

No 2026 paper by a first-author Tufano on contracts-before-code and bug detection exists yet.
The kit's rule for this claim now reads "own practice" until one of the two 2025 contract-inference
papers above gets a 2026 successor that actually names Tufano, or the owner supplies a different
source.
