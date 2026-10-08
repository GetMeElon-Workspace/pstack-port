# Upstream provenance

This repo is the Devin port of record for pstack.

## Source

- Upstream: [cursor/plugins](https://github.com/cursor/plugins), `pstack/` directory
- Author: Lauren Tan ([poteto](https://x.com/poteto)), MIT license
- Last synced upstream SHA: `ccb5507cec1546dc88135c1139c811e6c59115ba` (pstack version 0.15.15)
- Vendored at the same SHA: `cursor-team-kit/skills/{deslop,control-cli,control-ui}`

## File map

| Upstream path | Repo path | Notes |
|---|---|---|
| `pstack/skills/<n>/` | `skills/<n>/` | verbatim plus transforms below |
| `pstack/automations/benny/skills/<n>/` | `skills/benny-<n>/` | renamed so all skills live in one flat dir |
| `pstack/automations/benny/{README,FOR_AGENTS,templates}` | `docs/benny/` | verbatim |
| `cursor-team-kit/skills/{deslop,control-cli,control-ui}/` | `skills/<n>/` | vendored so pstack references resolve |
| `pstack/agents/*.md` | `agents/` | verbatim plus transforms below |
| `pstack/docs/` | `docs/` | verbatim |
| `pstack/LICENSE` | `LICENSE` | verbatim |
| `pstack/README.md` | `docs/upstream-README.md` | reference copy; the root README is ours |
| `pstack/assets/` | `assets/` | verbatim (plugin logo) |
| `pstack/.cursor-plugin/plugin.json` | `.devin-plugin/plugin.json` | regenerated; Cursor-only keys dropped: `logo`, `category`, `tags`, `skills`, `agents` |
| `pstack/.gitignore` | not copied | repo root has its own `.gitignore` |

## Transforms applied on sync

`scripts/sync-upstream.sh` applies these and nothing else:

1. Delete frontmatter lines `disable-model-invocation: true` in every `skills/*/SKILL.md`. Devin treats the flag as fully uninvocable. The match is anchored to a whole line, so prose mentions are untouched.
2. Frontmatter `name:` normalizations (explicit table in the script):
   - `skills/poteto-mode/SKILL.md`: `Poteto Mode` to `poteto-mode`
   - `skills/make-bot-ui/SKILL.md`: `Make Bot UI` to `make-bot-ui`
   - `skills/benny-setup-benny/SKILL.md`: `setup-benny` to `benny-setup-benny`
   - `skills/benny-triage-issue-reports/SKILL.md`: `triage-issue-reports` to `benny-triage-issue-reports`
   - `skills/benny-reproduce-and-fix-issues/SKILL.md`: `reproduce-and-fix-issues` to `benny-reproduce-and-fix-issues`
   - `agents/comment-sicko.md`: `Comment Sicko` to `comment-sicko`
3. `.devin-plugin/plugin.json` regenerated from the upstream manifest minus the Cursor-only keys above.

## How to sync

```bash
scripts/sync-upstream.sh           # upstream main
scripts/sync-upstream.sh <sha>     # pin to a commit
scripts/sync-upstream.sh v0.16.0   # a tag
```

The script clones upstream to a temp dir, re-copies the mapped files, re-applies the transforms, prints the synced SHA, the `git status` delta, and anything needing human review (name mismatches it did not fix, unmapped upstream paths). It never runs `git config` and never pushes. After running it, update the "Last synced upstream SHA" above and commit.

## Multi-ecosystem intent

The repo root is and stays the Devin plugin (`devin plugins install <owner>/<repo>` installs it directly). Ports to other ecosystems can join under `ports/<target>/`, each a valid plugin for that target, without disturbing the Devin install path:

- `ports/claude/`: a `.claude-plugin` variant
- `ports/codex/`: a Codex variant

A port directory is ignored by Devin, so adding one is additive only. The end state for upstream is a PR to cursor/plugins adding just `.devin-plugin/plugin.json` to `pstack/`, which would make upstream itself installable on Devin.
