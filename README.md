# pstack for Devin

A Devin-native port of [pstack](https://github.com/cursor/plugins/tree/main/pstack), the Cursor plugin by [Lauren Tan](https://x.com/poteto) (poteto). Upstream is MIT licensed; this port keeps the same license and tracks upstream v0.15.15.

> if you want to go fast, go deep first. pstack helps you write less, but higher quality code: rigorous agent workflows you can parallelize with confidence.

## What it contains

- **57 skills** under `skills/`, including:
  - `poteto-mode`, the agent style skill that reads a request, picks a playbook (investigation, bug fix, shipping, autopilot, and more), and runs the other skills as steps
  - 24 `principle-*` skills encoding engineering judgment (attack the premise, fix root causes, prove it works, and so on)
  - workflow skills like `tdd`, `unslop`, `interrogate`, `swarm`, `benchmark-checklist`, and the `benny-*` automation guides
  - `deslop`, `control-cli`, and `control-ui`, vendored verbatim from the sibling [cursor/team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit) plugin (also MIT) so pstack's internal references resolve without a second plugin install
- **2 subagents** under `agents/`: `poteto-agent` and `comment-sicko`
- **Docs** under `docs/`: the pstack guide and the benny automation notes

## Install

### Devin CLI and Devin Desktop

```bash
# From GitHub (this repo is a single plugin at the root)
devin plugins install GetMeElon-Workspace/pstack

# Or a local checkout, for authoring: edits apply live, no update step
git clone https://github.com/GetMeElon-Workspace/pstack.git
devin plugins install --local ./pstack
```

Skills appear as `/pstack:<skill>` slash commands and are also picked up automatically when a skill description matches the task.

### Devin Cloud

In the web app, open your organization's plugin management (Customize) and install from the GitHub repo URL:

```
https://github.com/GetMeElon-Workspace/pstack
```

Because the plugin lives at the repository root, the plain repo URL installs it directly. Tree URLs that pin a subdirectory also work if this plugin is ever moved under a folder, for example `https://github.com/GetMeElon-Workspace/pstack/tree/main/plugins/pstack` (not needed today).

## Get started

1. Run `/pstack:setup-pstack` to pick a reasoning budget and choose models.
2. Use `/pstack:poteto-mode` whenever a task needs rigor.

The [pstack guide](./docs/guide/README.md) walks a first real task end to end: setup, prompting, verification, and overnight runs. Unsure which skill fits? Ask `/pstack:poteto-help`.

## Compatibility notes

This is a faithful port: skills are copied verbatim from upstream plus light edits for Devin. A few upstream assumptions need translating:

- **Subagents are local only.** `agents/` profiles (`poteto-agent`, `comment-sicko`) load in the Devin CLI and Devin Desktop, not in cloud Devin sessions. On cloud, poteto-mode's delegation guidance applies to child sessions instead.
- **poteto-mode scripts need bun.** `skills/poteto-mode/scripts/*.ts` (bootstrap, orch, watch-pr) run under [bun](https://bun.sh). The skill works without them; install bun if you want the scripted orchestration.
- **Cursor built-ins named in skills.** Some skills reference Cursor-only mechanisms: built-in skills like `create-skill`, `drive`, and `AskQuestion`, and `subagent_type`/`Task` tool semantics. On Devin, subagent semantics map to child sessions and plugin subagents; treat mentions of missing built-ins as guidance to follow by hand.
- **cursor-team-kit skills are vendored.** Upstream pstack references `deslop`, `control-cli`, and `control-ui` from the sibling team-kit plugin. They are vendored here verbatim (MIT) so every reference resolves out of the box; `disable-model-invocation` flags were removed so Devin can invoke them.
- **benny skills need an automation.** `benny-setup-benny`, `benny-triage-issue-reports`, and `benny-reproduce-and-fix-issues` describe an upstream automation that does not exist on Devin. They ship as guidance only; wire the equivalent with a Devin automation if you want the behavior.

## Related ports

[michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude) is an older Claude Code port of pstack (v0.9.x era). Its `plugins/pstack` subdirectory can be installed on Devin through the `.claude-plugin` manifest fallback. This repo is a Devin-native port of the latest upstream (v0.15.15) with the canonical `.devin-plugin` layout, vendored dependencies, and a rewritten README.

## Updating from upstream

This repo tracks [cursor/plugins](https://github.com/cursor/plugins) `pstack/`. To resync:

```bash
scripts/sync-upstream.sh           # upstream main, or pass a tag/SHA to pin
```

The script re-copies upstream files, re-applies the Devin transforms (frontmatter flag removal, name normalizations, manifest regeneration), and prints the synced SHA plus a review list. Provenance, the file map, and the transform list live in [UPSTREAM.md](./UPSTREAM.md).

## Ports

The repo root stays the Devin plugin. Variants for other ecosystems (claude, codex) can join under `ports/<target>/` as valid plugins for their own target without changing the Devin install path.

## Upstream and license

Upstream: [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack), MIT, author Lauren Tan. Vendored skills: [cursor/plugins cursor-team-kit](https://github.com/cursor/plugins/tree/main/cursor-team-kit), MIT. See [LICENSE](./LICENSE).
