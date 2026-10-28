# Gnoesis factory on Zo Computer

[Zo Computer](https://zo.computer) is a remote Linux server you control from the browser or
from Cursor via Zo MCP tools. It is a supported **Linux desk** for the Gnoesis software factory:
Hermes, Cloudroom core, the Cloudroom internal app in a browser, Modal sandboxes, and (with a
graphical session) Herald OS or Gnoesisorca. Read [SOFTWARE-FACTORY.md](SOFTWARE-FACTORY.md) for
the full factory map; this page is Zo-specific setup and day-to-day use.

Zo is **not** the same machine as a Cursor Cloud Agent VM. Run the commands here **on your Zo
server** (Zo `bash` / SSH / the Zo terminal), not on an ephemeral cloud-agent pod unless you
cloned Herald OS there on purpose.

## What Zo is good for

| Factory piece | On Zo | Notes |
| --- | --- | --- |
| Hermes + factory gates (CLI) | Yes | `hermes` chat after bootstrap; skill `software-factory` |
| Pinned EGM / Cloudroom / Gnoesisorca | Yes | `scripts/setup-software-factory.sh` → `~/.hermes/herald-os/` |
| Cloudroom core (local cloud) | Yes | Often already installed; listens on `127.0.0.1:9840` |
| Cloudroom internal app (browser) | Yes | `pnpm dev` under the pinned `cloudroom-gui/gui` checkout, or an existing Zo Cloudroom stack |
| Modal (`bb-sandboxes`) | Yes | `modal` CLI + app plugin settings; token never in git |
| Grok desk builder | Yes | `npm install -g @xai-official/grok` then `grok login` |
| Herald OS (Electron) | Sometimes | Needs Zo’s graphical session; same as Linux desktop in [LINUX.md](LINUX.md) |
| Gnoesisorca RSI lab | Sometimes | `pnpm dev` in the pinned checkout (Node 24) or Orca AppImage if you install it |

Many Zo accounts already have **`~/.hermes`** (Hermes config, plugins, auth). The factory adds
trees under **`~/.hermes/herald-os/`** and writes **`software-factory.json`** there. It does not
replace your existing Hermes profile.

## One-time setup

Use a stable checkout path under your Zo workspace (example: `/home/workspace/Projects/Herald-OS`).
Adjust if your workspace root differs.

```bash
# 1) Clone Herald OS
git clone https://github.com/GustheTrader/Herald-OS.git /home/workspace/Projects/Herald-OS
cd /home/workspace/Projects/Herald-OS

# 2) Bootstrap Hermes bridge (safe to re-run after pulls)
npm run bootstrap

# 3) Pin factory repos (EGM, Cloudroom core, Cloudroom GUI, Gnoesisorca)
#    HERMES_HOME defaults to ~/.hermes; set explicitly if Hermes lives elsewhere.
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}" scripts/setup-software-factory.sh

# 4) Grok Build CLI (desk builder)
npm install -g @xai-official/grok
grok login

# 5) Modal CLI (optional until you use cloud sandboxes)
pip install modal
modal token set   # writes ~/.modal.toml; also paste id/secret in Cloudroom plugin settings
```

After step 3, confirm:

```bash
test -f "$HERMES_HOME/herald-os/software-factory.json" && echo OK
ls "$HERMES_HOME/herald-os"
```

Bootstrap links **`herald-os-bridge`** into `$HERMES_HOME/plugins` and enables the **`herald_os`**
toolset. Ensure **`hermes`** is on your PATH (often `~/.local/bin/hermes`):

```bash
export PATH="$HOME/.local/bin:$PATH"
hermes plugins list | grep herald-os-bridge
```

## Cloudroom on Zo

**Core.** A healthy core on Zo usually answers `http://127.0.0.1:9840/v1/ready` with **401** or
**403** (listening, token required) or **200** when fully ready. The token lives in
`/etc/cloudroom/core.env` as `CLOUDROOM_TOKEN` — do not paste it into chat, commits, or docs.

**Internal app.** The factory skill points at the **pinned** GUI checkout:

`$HERMES_HOME/herald-os/cloudroom-gui`

You may also have a separate working copy (for example under `Projects/cloudroom-gui` with
`zo-data/`). That copy is fine for day-to-day Cloudroom on Zo; Hermes follows
`software-factory.json` unless you explicitly work in the other tree. To dev the pinned app:

```bash
cd "$HERMES_HOME/herald-os/cloudroom-gui/gui"
pnpm install
pnpm dev
```

Open the `http://127.0.0.1:<port>/` URL from the dev banner in Zo’s browser (or your published
Zo site if you front the app that way). You still need a one-time **cloudroom.dev** sign-in when
the UI asks. For Modal sandboxes, set app name **`bb-sandboxes`** in Settings → Plugins → Modal
sandbox and complete **Cloudroom Connect** pairing if sandbox create requires it.

If the center panel is empty, check the **host daemon** port printed by `pnpm dev` (often
`27490`) is listening and restart the host-daemon task if it stopped — same as on bare Linux in
[SOFTWARE-FACTORY.md](SOFTWARE-FACTORY.md).

## Run the factory

**Hermes CLI (typical on Zo):**

```bash
export PATH="$HOME/.local/bin:$PATH"
hermes
```

Ask to **run the Gnoesis factory** and name the feature. Hermes uses the `software-factory`
skill and the EGM skills under `$HERMES_HOME/herald-os/egm`.

**Herald OS Electron (optional):**

```bash
cd /home/workspace/Projects/Herald-OS
npm run dev
```

Requires Zo’s graphical environment. Factory gates work the same; the desk is Electron instead
of terminal-only Hermes.

**RSI lab (Gnoesisorca):** read `$HERMES_HOME/herald-os/gnoesisorca/.github/CONTRIBUTING.md`
before `pnpm install` and `pnpm dev`. Start a fleet only when you intend to spend agent
subscriptions; merges stay human-approved.

## Refresh pins after upstream changes

From your Herald OS checkout:

```bash
git pull
npm run bootstrap          # if bridge or lock changed
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}" scripts/setup-software-factory.sh
```

Override commits with `EGM_REF`, `CLOUDROOM_CORE_REF`, `CLOUDROOM_GUI_REF`, and
`GNOESISORCA_REF` when you mean to test a different pin.

## Cursor + Zo MCP

When a Cursor agent should act **on Zo**, it must use **Zo MCP tools** (`bash`, `read_file`,
`write_file`, …), not the cloud-agent VM shell. The setup commands in this doc are the same;
only the execution environment changes.

Do not ask agents to print **`~/.modal.toml`**, **`/etc/cloudroom/core.env`**, Zo
**`.zo_secrets`**, or Cloudroom **`zo-data/auth.json`**.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `skills/egm_brainstorm/SKILL.md` missing | Re-run `setup-software-factory.sh` |
| `hermes: command not found` | `export PATH="$HOME/.local/bin:$PATH"` or open a new shell after bootstrap |
| Core not listening on 9840 | Install or start core from `$HERMES_HOME/herald-os/cloudroom-core/docs/setup.md` |
| Grok build fails | `grok login` → `~/.grok/auth.json` (separate from Hermes xAI login) |
| Modal sandbox fails | `~/.modal.toml`, plugin token, app `bb-sandboxes`, Connect pairing |
| Blank Cloudroom panel | Host daemon port up; browser sign-in; restart `pnpm dev` stack |

## Related docs

| Doc | Purpose |
| --- | --- |
| [SOFTWARE-FACTORY.md](SOFTWARE-FACTORY.md) | Factory roles, gates, Mac/Linux/Windows |
| [SYSTEM-BRIDGE.md](SYSTEM-BRIDGE.md) | Herald OS tools Hermes uses on the machine |
| [LINUX.md](LINUX.md) | Full Herald OS Linux desktop (VM / niri) |
