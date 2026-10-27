#!/usr/bin/env bash
# Put the Elephant-Goldfish Model where Herald OS's software-factory skill reads it,
# and report whether the Grok Build CLI is installed and signed in.
# Safe to re-run. Does not enable Grok to write code; the skill does that after a spec is approved.
#
#   scripts/setup-software-factory.sh
#   EGM_REF=<sha> scripts/setup-software-factory.sh
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
DEST="$HERMES_HOME/herald-os/egm"
REPO="https://github.com/GustheTrader/elephant-goldfish-model.git"
# GustheTrader main @ 2026-10-24, the artifact-directory change. Tracks google/elephant-goldfish-model.
REF="${EGM_REF:-3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669}"

mkdir -p "$HERMES_HOME/herald-os"

if [[ -d "$DEST" && ! -d "$DEST/.git" ]]; then
  echo "setup-software-factory: $DEST exists and is not a git checkout. Move it aside and re-run." >&2
  exit 1
fi

if [[ ! -d "$DEST/.git" ]]; then
  git init "$DEST"
  git -C "$DEST" remote add origin "$REPO"
fi

echo "==> Fetching EGM $REF"
git -C "$DEST" fetch --depth 1 origin "$REF"
git -C "$DEST" checkout --detach FETCH_HEAD

# GustheTrader's tree uses skill directories with underscores. Google's tree uses hyphens.
# Accept either, and record the paths the skill should open.
resolve_skill() {
  local underscored="$DEST/skills/$1/SKILL.md"
  local hyphenated="$DEST/skills/$2/SKILL.md"
  if [[ -f "$underscored" ]]; then
    echo "$underscored"
  elif [[ -f "$hyphenated" ]]; then
    echo "$hyphenated"
  else
    echo "setup-software-factory: missing skills/$1 or skills/$2" >&2
    exit 1
  fi
}
BRAINSTORM="$(resolve_skill egm_brainstorm egm-brainstorm)"
DRAFT="$(resolve_skill egm_draft egm-draft)"
REVIEW="$(resolve_skill egm_review egm-review)"
RESOLVE="$(resolve_skill egm_resolve egm-resolve)"
DRIFT="$(resolve_skill egm_drift_report egm-drift-report)"
test -f "$DEST/agents/synthesizer.md"
test -f "$DEST/agents/implementation_readiness.md"

python3 - "$HERMES_HOME/herald-os/software-factory.json" "$DEST" "$REF" "$REPO" \
  "$BRAINSTORM" "$DRAFT" "$REVIEW" "$RESOLVE" "$DRIFT" <<'PY'
import json, sys
path, dest, ref, repo, brainstorm, draft, review, resolve, drift = sys.argv[1:]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({
        "egm": dest,
        "ref": ref,
        "repo": repo,
        "skills": {
            "brainstorm": brainstorm,
            "draft": draft,
            "review": review,
            "resolve": resolve,
            "drift": drift,
        },
    }, fh, indent=2)
    fh.write("\n")
PY

echo "==> EGM checkout: $DEST @ $REF"

if command -v grok >/dev/null 2>&1; then
  echo "==> grok: $(command -v grok)"
else
  echo "==> grok CLI is not on PATH."
  echo "    npm install -g @xai-official/grok"
fi

if [[ -f "$HOME/.grok/auth.json" ]]; then
  echo "==> grok auth: ~/.grok/auth.json"
else
  echo "==> grok auth: not found. Sign in once with: grok login"
  echo "    (SuperGrok or X Premium+. Hermes's own xAI login is a different token.)"
fi

echo "==> Done. In Herald OS, ask Hermes to run the software factory."
