# Module `enjambre` — when you have more than one machine

Optional. Nothing here is installed by a plain `sync-to-home.sh`; it goes in only with

```bash
bash sync-to-home.sh --with enjambre
```

[enjambre](https://github.com/IchiSieben/enjambre) turns your other machines into worker nodes:
a job is a `TASK-*.md`, enjambre routes it, runs it in a clean worktree on the node and brings the
branch back. What this kit and enjambre share lives here:

| File | Installed to | What it does |
|---|---|---|
| `hooks/enjambre-ssh-guard.sh` | `~/.claude/hooks/` | `PreToolUse` (Bash, PowerShell): blocks a raw `ssh <node>` to one of your nodes outside the enjambre repos, so delegation stays visible in enjambre's ledger. `ENJAMBRE_RAW_SSH=1` skips it once, and the skip is logged |
| `rules/kit-enjambre.md` | `~/.claude/rules/` | The always-loaded paragraph: delegate through enjambre, never ssh by hand; what a repo needs before its first job |
| `settings.json` | merged into `~/.claude/settings.json` | Registers the hook. Appended to `hooks.PreToolUse` only if that exact command is not there yet |

## Which hosts count as nodes

Every `host = "..."` in enjambre's `nodes.toml` except `local` — the file at `$ENJAMBRE_NODES`, by
default `$ENJAMBRE_HOME/nodes.toml`, by default `~/enjambre/nodes.toml` — plus the space-separated
names in `ENJAMBRE_GUARD_HOSTS`. No file and no names: the hook blocks nothing. Put the two
variables in `settings.json` → `env` (they are per machine only if the values differ; the paths
usually do not).

The check reads only a word in **command position**: `grep 'ssh mac' docs/` is text and passes;
`bash -c "ssh mac ls"`, `nohup ssh mac …` and `user@mac` are an ssh to `mac` and are blocked.
Inside a directory named `enjambre` or `enjambre-*` nothing is blocked: that is where raw ssh to a
node is the job.

## The `enj` block of the status line

Not a file of this module: it is already in `statusline.sh` and stays blank on a machine without
the swarm. enjambre's visor writes `~/.enjambre/visor/summary.txt` (`<epoch>\t<text>`) every five
minutes; the bar shows `enj ⬡2/2 ⚙1 ≈$17 hoy` (nodes alive, jobs running, today's usage) and,
when the file is older than `enjambre-stale` in `rules/thresholds.json`, `enj ⌛Nm` in amber
instead of old numbers. `CC_ENJ_SUMMARY` points it at another file.

## Keep passing the flag

The mirror's `hooks` key is replaced by the repo's on every sync, so a later
`sync-to-home.sh` **without** `--with enjambre` drops the hook's registration (the hook file and
the rule stay on disk, inert). Pass the flag on every sync on a machine that uses the module.
`sync-from-home.sh` will copy the installed hook and rule back into `home/.claude/`; delete them
there before committing if you do not want them in your mirror.

Tests: `bash tests/enjambre_module_test.sh` (hook: blocks `ssh mac`, lets `ssh otro` through, bypass,
exempt repos; sync: nothing without the flag, idempotent with it).
