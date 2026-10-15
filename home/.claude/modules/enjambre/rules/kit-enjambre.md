# More than one machine: enjambre (claude-kit module)

- Your other machines are worker nodes for anything headless: tests, builds, renders,
  transcription, long `claude -p` jobs. Their names are the `host` entries of enjambre's
  `nodes.toml` (and `ENJAMBRE_GUARD_HOSTS`).
- Delegate through enjambre, never with a raw `ssh <node>`:
  `python $ENJAMBRE_HOME/enjambre.py run|status|collect ...` (it routes, queues and keeps a
  ledger; `run --dry-run` shows the route without spending). Repo: https://github.com/IchiSieben/enjambre
- Before the first delegation in a repo: read its `docs/DELEGAR.md` if present; the repo needs an
  `AGENTS.md` at its root with a `tests-cmd:` line, the one command a node may run.
- If the node is down or busy, enjambre says so: queue or run locally; do not work around it with
  ssh. The `enjambre-ssh-guard` hook blocks it; `ENJAMBRE_RAW_SSH=1` skips it once, logged.
