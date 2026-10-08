#!/usr/bin/env bash
# sync-upstream.sh [ref]
#
# Resync this repo against upstream https://github.com/cursor/plugins.
# Copies pstack (and the three vendored cursor-team-kit skills) into the
# canonical Devin plugin layout, re-applies the Devin transforms, and
# regenerates .devin-plugin/plugin.json from the upstream manifest.
#
# Usage:
#   scripts/sync-upstream.sh           # sync against upstream main
#   scripts/sync-upstream.sh v0.16.0   # sync against a tag or branch
#   scripts/sync-upstream.sh <sha>     # sync against a commit SHA
#
# Requires: git, sed, python3 (manifest regeneration only).
# Safe to run repeatedly: output is deterministic given the same ref.
# Never runs git config and never pushes; review the diff with git status.

set -euo pipefail

UPSTREAM_REPO="https://github.com/cursor/plugins"
REF="${1:-main}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
SRC="$WORKDIR/upstream"

# ---------------------------------------------------------------------------
# 1. Clone upstream at the requested ref (sparse: only the dirs we need).
# ---------------------------------------------------------------------------
echo "==> Cloning $UPSTREAM_REPO at ref '$REF'"
if ! git clone --quiet --depth 1 --filter=blob:none --sparse \
    --branch "$REF" "$UPSTREAM_REPO" "$SRC" 2>/dev/null; then
  # Ref is not a branch/tag: treat it as a commit SHA.
  git init --quiet "$SRC"
  git -C "$SRC" remote add origin "$UPSTREAM_REPO"
  git -C "$SRC" sparse-checkout init
  git -C "$SRC" fetch --quiet --depth 1 --filter=blob:none origin "$REF"
  git -C "$SRC" checkout --quiet FETCH_HEAD
fi
git -C "$SRC" sparse-checkout set pstack cursor-team-kit/skills

UPSTREAM_SHA="$(git -C "$SRC" rev-parse HEAD)"
echo "==> Upstream SHA: $UPSTREAM_SHA"

PSTACK="$SRC/pstack"
TEAMKIT="$SRC/cursor-team-kit/skills"

# ---------------------------------------------------------------------------
# 2. Copy map: upstream path -> repo path (all verbatim before transforms).
# ---------------------------------------------------------------------------
rm -rf "$ROOT/skills" "$ROOT/agents" "$ROOT/docs" "$ROOT/assets"
mkdir -p "$ROOT/skills" "$ROOT/agents" "$ROOT/docs/benny" "$ROOT/assets"

# pstack skills
cp -R "$PSTACK/skills/." "$ROOT/skills/"

# benny automation skills land as skills/benny-<name>
for d in "$PSTACK/automations/benny/skills"/*/; do
  [ -d "$d" ] || continue
  cp -R "$d" "$ROOT/skills/benny-$(basename "$d")"
done

# benny automation docs land under docs/benny/
cp "$PSTACK/automations/benny/README.md" "$ROOT/docs/benny/README.md"
cp "$PSTACK/automations/benny/FOR_AGENTS.md" "$ROOT/docs/benny/FOR_AGENTS.md"
cp -R "$PSTACK/automations/benny/templates" "$ROOT/docs/benny/templates"

# vendored cursor-team-kit skills
for s in deslop control-cli control-ui; do
  cp -R "$TEAMKIT/$s" "$ROOT/skills/$s"
done

# agents, docs, license, upstream readme (kept for reference; the repo-root
# README.md is ours and is never overwritten), assets
cp "$PSTACK/agents/"*.md "$ROOT/agents/"
cp -R "$PSTACK/docs/." "$ROOT/docs/"
cp "$PSTACK/LICENSE" "$ROOT/LICENSE"
cp "$PSTACK/README.md" "$ROOT/docs/upstream-README.md"
cp -R "$PSTACK/assets/." "$ROOT/assets/"

# ---------------------------------------------------------------------------
# 3. Mechanical transforms. Explicit table, no magic.
# ---------------------------------------------------------------------------

# 3a. Drop `disable-model-invocation: true` frontmatter lines: Devin treats
# the flag as fully uninvocable. Anchored to a whole-line match so prose
# mentions (e.g. automate-me's guidance bullet) are untouched.
find "$ROOT/skills" -name SKILL.md -print0 | while IFS= read -r -d '' f; do
  sed -E -i.syncbak '/^disable-model-invocation:[[:space:]]*true[[:space:]]*$/d' "$f"
done
find "$ROOT/skills" -name '*.syncbak' -delete

# 3b. Frontmatter name normalizations: file|upstream name|devin name.
# Devin requires the frontmatter name to equal the skill directory (or, for
# flat agents, the filename minus .md).
NAME_TABLE="
skills/poteto-mode/SKILL.md|Poteto Mode|poteto-mode
skills/make-bot-ui/SKILL.md|Make Bot UI|make-bot-ui
skills/benny-setup-benny/SKILL.md|setup-benny|benny-setup-benny
skills/benny-triage-issue-reports/SKILL.md|triage-issue-reports|benny-triage-issue-reports
skills/benny-reproduce-and-fix-issues/SKILL.md|reproduce-and-fix-issues|benny-reproduce-and-fix-issues
agents/comment-sicko.md|Comment Sicko|comment-sicko
"
REVIEW=()
echo "$NAME_TABLE" | while IFS='|' read -r path old new; do
  [ -n "$path" ] || continue
  f="$ROOT/$path"
  if [ ! -f "$f" ]; then
    echo "warn: expected file missing: $path (upstream may have moved it)"
    continue
  fi
  if grep -qE "^name:[[:space:]]*$old[[:space:]]*$" "$f"; then
    sed -E -i.syncbak "s/^name:[[:space:]]*$old[[:space:]]*\$/name: $new/" "$f"
    rm -f "$f.syncbak"
  elif ! grep -qE "^name:[[:space:]]*$new[[:space:]]*$" "$f"; then
    echo "warn: $path has neither name '$old' nor '$new'; check its frontmatter"
  fi
done

# ---------------------------------------------------------------------------
# 4. Regenerate .devin-plugin/plugin.json from the upstream manifest.
# Drops Cursor-only keys; everything else passes through, so upstream
# version/metadata changes propagate automatically.
# ---------------------------------------------------------------------------
python3 - "$PSTACK/.cursor-plugin/plugin.json" "$ROOT/.devin-plugin/plugin.json" <<'PY'
import json, sys
CURSOR_ONLY = {"logo", "category", "tags", "skills", "agents"}
src, dst = sys.argv[1], sys.argv[2]
manifest = {k: v for k, v in json.load(open(src)).items() if k not in CURSOR_ONLY}
# The port keeps its own plugin name; only version/metadata tracks upstream.
manifest["name"] = "pstack-port"
manifest["displayName"] = "pstack-port"
with open(dst, "w") as fh:
    json.dump(manifest, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ROOT/.devin-plugin/plugin.json")"

# ---------------------------------------------------------------------------
# 5. Summary + review signals.
# ---------------------------------------------------------------------------
echo
echo "==> Synced to upstream SHA $UPSTREAM_SHA (version $VERSION)"

for f in "$ROOT"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$f")")"
  name="$(sed -nE 's/^name:[[:space:]]*//p' "$f" | head -1)"
  if [ "$name" != "$dir" ]; then
    REVIEW+=("skill name/dirname mismatch: $dir has name '$name'")
  fi
done
for f in "$ROOT"/agents/*.md; do
  base="$(basename "$f" .md)"
  name="$(sed -nE 's/^name:[[:space:]]*//p' "$f" | head -1)"
  if [ "$name" != "$base" ]; then
    REVIEW+=("agent name/filename mismatch: $base.md has name '$name'")
  fi
done
for p in "$PSTACK"/*; do
  base="$(basename "$p")"
  case "$base" in
    LICENSE|README.md|agents|assets|automations|docs|skills|.gitignore) ;;
    *) REVIEW+=("unmapped upstream path: pstack/$base (decide where it lands)") ;;
  esac
done

if [ "${#REVIEW[@]}" -gt 0 ]; then
  echo "==> Needs human review:"
  printf '    - %s\n' "${REVIEW[@]}"
else
  echo "==> Review signals: none"
fi

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "==> Files changed vs current tree:"
  git -C "$ROOT" status --porcelain || true
fi
echo "==> Done. Review with 'git diff', then commit."
