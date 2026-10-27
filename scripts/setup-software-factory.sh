#!/usr/bin/env bash
# Pin the Gnoesis SI factory's pieces under $HERMES_HOME/herald-os:
#   EGM (design method), Cloudroom core (local cloud), Cloudroom GUI (internal app).
# Reports whether Grok and a local core are present. Does not install the core
# service or sign anyone in. Safe to re-run.
#
#   scripts/setup-software-factory.sh
#   EGM_REF=<sha> CLOUDROOM_CORE_REF=<sha> CLOUDROOM_GUI_REF=<sha> scripts/setup-software-factory.sh
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
ROOT_DIR="$HERMES_HOME/herald-os"
DEST="$ROOT_DIR/egm"
REPO="https://github.com/GustheTrader/elephant-goldfish-model.git"
# GustheTrader main @ 2026-10-24, the artifact-directory change. Tracks google/elephant-goldfish-model.
REF="${EGM_REF:-3d0b34821ce88ad328b0c9bf0e06d7eb5f1cd669}"
# GustheTrader forks of davidondrej/cloudroom-core and cloudroom-gui, main on 2026-10-14.
CORE_REPO="https://github.com/GustheTrader/cloudroom-core.git"
CORE_REF="${CLOUDROOM_CORE_REF:-d44dd8b9a6d272a5f601b980c00fade202d00d4c}"
CORE_DEST="$ROOT_DIR/cloudroom-core"
GUI_REPO="https://github.com/GustheTrader/cloudroom-gui.git"
GUI_REF="${CLOUDROOM_GUI_REF:-b5efb8d902fd580262a6b0eeaa130f92d8340f4b}"
GUI_DEST="$ROOT_DIR/cloudroom-gui"

mkdir -p "$ROOT_DIR"

# Checkout one commit of a repo. A non-git directory already at the path is left alone.
pin_checkout() {
  local dest="$1" repo="$2" ref="$3"
  if [[ -d "$dest" && ! -d "$dest/.git" ]]; then
    echo "setup-software-factory: $dest exists and is not a git checkout. Move it aside and re-run." >&2
    exit 1
  fi
  if [[ ! -d "$dest/.git" ]]; then
    git init "$dest"
    git -C "$dest" remote add origin "$repo"
  fi
  echo "==> Fetching $repo @ $ref"
  git -C "$dest" fetch --depth 1 origin "$ref"
  git -C "$dest" checkout --detach FETCH_HEAD
}

pin_checkout "$DEST" "$REPO" "$REF"

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
echo "==> EGM checkout: $DEST @ $REF"

pin_checkout "$CORE_DEST" "$CORE_REPO" "$CORE_REF"
test -f "$CORE_DEST/docs/setup.md"
test -f "$CORE_DEST/docs/api.md"
echo "==> Cloudroom core (local cloud): $CORE_DEST @ $CORE_REF"

pin_checkout "$GUI_DEST" "$GUI_REPO" "$GUI_REF"
test -f "$GUI_DEST/gui/README.md"
echo "==> Cloudroom GUI (internal app): $GUI_DEST @ $GUI_REF"

python3 - "$ROOT_DIR/software-factory.json" "$DEST" "$REF" "$REPO" \
  "$BRAINSTORM" "$DRAFT" "$REVIEW" "$RESOLVE" "$DRIFT" \
  "$CORE_DEST" "$CORE_REF" "$CORE_REPO" "$GUI_DEST" "$GUI_REF" "$GUI_REPO" <<'PY'
import json, sys
(path, dest, ref, repo, brainstorm, draft, review, resolve, drift,
 core, core_ref, core_repo, gui, gui_ref, gui_repo) = sys.argv[1:]
with open(path, "w", encoding="utf-8") as fh:
    json.dump({
        "name": "gnoesis",
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
        "cloudroom": {
            "core": {"path": core, "ref": core_ref, "repo": core_repo, "role": "local-cloud"},
            "gui": {"path": gui, "ref": gui_ref, "repo": gui_repo, "role": "internal-app"},
            "modal": {"appName": "bb-sandboxes", "role": "cloud-space"},
        },
    }, fh, indent=2)
    fh.write("\n")
PY

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

ready_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:9840/v1/ready || true)"
case "$ready_code" in
  200) echo "==> Local cloud: core answered ready on 127.0.0.1:9840" ;;
  401|403) echo "==> Local cloud: core is listening on 127.0.0.1:9840 and expects its token" ;;
  *) echo "==> Local cloud: core is not answering on 127.0.0.1:9840" ;;
esac
echo "    Install and connect it from $CORE_DEST/docs/setup.md"
echo "    Open the internal app from $GUI_DEST (build notes in gui/README.md)"

echo "==> Done. In Herald OS, ask Hermes to run the Gnoesis factory."
