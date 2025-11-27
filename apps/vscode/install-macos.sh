#!/usr/bin/env bash
set -euo pipefail
RETRY_COUNT="${RETRY_COUNT:-4}"
USER_HOME="${HOME:-$( [ "$(id -u)" -eq 0 ] && echo /root || echo /home/$(whoami) )}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
trap 'rc=$?; printf "%s ERROR exit=%s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$rc" >&2; exit "$rc"' ERR
log(){ printf "%s %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*" >&2; }
if [ ! -x "${PYENV_ROOT}/bin/pyenv" ] && ! command -v pyenv >/dev/null 2>&1; then log "pyenv not found at ${PYENV_ROOT} or on PATH. Install pyenv first."; exit 1; fi
PYENV_BIN="${PYENV_ROOT}/bin/pyenv"; [ ! -x "$PYENV_BIN" ] && PYENV_BIN="$(command -v pyenv || true)"
run(){ local cmd="$*"; local i=1; while [ $i -le "$RETRY_COUNT" ]; do log "RUN: $cmd (attempt $i)"; if eval "$cmd"; then return 0; fi; i=$((i+1)); sleep $((i*i)); done; return 1; }
BREW_PREFIX="$(command -v brew >/dev/null 2>&1 && brew --prefix || true)"
install_vscode(){ log "Installing or verifying VS Code"; if command -v code >/dev/null 2>&1; then log "code CLI already present"; return 0; fi; if command -v brew >/dev/null 2>&1; then run "brew install --cask visual-studio-code" || true; fi; if [ -d "/Applications/Visual Studio Code.app" ]; then binpath="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; targetdir="${BREW_PREFIX:+$BREW_PREFIX/bin:/usr/local/bin}"; if [ -x "$binpath" ]; then if [ -n "$BREW_PREFIX" ] && [ -w "$BREW_PREFIX/bin" ]; then ln -sf "$binpath" "$BREW_PREFIX/bin/code" || true; elif [ -w /usr/local/bin ]; then ln -sf "$binpath" /usr/local/bin/code || true; else mkdir -p "$USER_HOME/bin" && ln -sf "$binpath" "$USER_HOME/bin/code" || true; fi; fi; fi; if command -v code >/dev/null 2>&1; then log "VS Code ready"; else log "VS Code CLI not found after install; ensure '/Applications/Visual Studio Code.app' exists and 'code' is on PATH"; fi; }
install_vscode
if ! command -v code >/dev/null 2>&1; then log 'Error: "code" CLI not found after install. Ensure VS Code is installed and "code" is on PATH.'; exit 1; fi
exts=(ms-python.python ms-python.vscode-pylance ms-toolsai.jupyter ms-toolsai.jupyter-renderers ms-python.black-formatter ms-python.isort njpwerner.autodocstring ms-vscode-remote.remote-containers VariableExplorer.variable-explorer)
install_ext(){ local e="$1" tmpu tmpx rc; if code --list-extensions | grep -Fxq "$e"; then log "Extension $e already installed"; return 0; fi; for ((i=1;i<=RETRY_COUNT;i++)); do log "Installing extension $e (attempt $i)"; if code --install-extension "$e" --force >/dev/null 2>&1; then log "Installed $e"; return 0; fi; rc=$?; log "Install returned $rc, trying isolated dirs"; tmpu="$(mktemp -d)" && tmpx="$(mktemp -d)"; if command -v timeout >/dev/null 2>&1; then timeout 60s code --user-data-dir "$tmpu" --extensions-dir "$tmpx" --install-extension "$e" --force >/dev/null 2>&1 || true; else code --user-data-dir "$tmpu" --extensions-dir "$tmpx" --install-extension "$e" --force >/dev/null 2>&1 || true; fi; if code --list-extensions --extensions-dir "$tmpx" | grep -Fxq "$e"; then log "Installed $e into isolated dir"; rm -rf "$tmpu" "$tmpx"; return 0; fi; rm -rf "$tmpu" "$tmpx"; if [ $i -lt "$RETRY_COUNT" ]; then sleep $((i*i)); else log "Failed to install extension $e after $RETRY_COUNT attempts"; fi; done; return 1; }
for e in "${exts[@]}"; do install_ext "$e" || true; done
log "Inspecting pyenv and pyenv-virtualenv environments"
PYENV_ROOT_ACTUAL="$("$PYENV_BIN" root 2>/dev/null || echo "$PYENV_ROOT")"
[ ! -d "$PYENV_ROOT_ACTUAL" ] && log "pyenv root not found at $PYENV_ROOT_ACTUAL" && exit 1
if [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/python" ]; then INTERP="${VIRTUAL_ENV}/bin/python"; log "Using active VIRTUAL_ENV: $INTERP"
else
  if [ -f ".python-version" ]; then pv="$(<.python-version)"; pv="$(printf '%s' "$pv" | tr -d '[:space:]')"; if [ -n "$pv" ]; then if [ -d "$PYENV_ROOT_ACTUAL/versions/$pv" ] && [ -x "$PYENV_ROOT_ACTUAL/versions/$pv/bin/python" ]; then INTERP="$PYENV_ROOT_ACTUAL/versions/$pv/bin/python"; log "Using .python-version => $pv -> $INTERP"; fi; fi; fi
  if [ -z "${INTERP:-}" ]; then if "$PYENV_BIN" virtualenvs --bare >/dev/null 2>&1; then mapfile -t PV < <("$PYENV_BIN" virtualenvs --bare 2>/dev/null); proj="$(basename "$(pwd)")"; for v in "${PV[@]}"; do if [ "$v" = "$proj" ] || [[ "$v" = *"$proj"* ]]; then [ -x "$PYENV_ROOT_ACTUAL/versions/$v/bin/python" ] && INTERP="$PYENV_ROOT_ACTUAL/versions/$v/bin/python" && log "Matched virtualenv $v to project $proj" && break; fi; done; if [ -z "${INTERP:-}" ] && [ "${#PV[@]}" -gt 0 ]; then for v in "${PV[@]}"; do [ -x "$PYENV_ROOT_ACTUAL/versions/$v/bin/python" ] && INTERP="$PYENV_ROOT_ACTUAL/versions/$v/bin/python" && log "Picked virtualenv $v" && break; done; fi; fi; fi
  if [ -z "${INTERP:-}" ]; then ACTIVE_VERSION="$("$PYENV_BIN" global --bare 2>/dev/null || true)"; if [ -z "$ACTIVE_VERSION" ]; then AVAILABLE="$("$PYENV_BIN" versions --bare 2>/dev/null || true)"; ACTIVE_VERSION="$(printf '%s\n' "$AVAILABLE" | grep -v '^system$' | sort -V | tail -n1 || true)"; fi; if [ -z "$ACTIVE_VERSION" ]; then log "No pyenv versions available."; exit 1; fi; INTERP="$PYENV_ROOT_ACTUAL/versions/$ACTIVE_VERSION/bin/python"; [ ! -x "$INTERP" ] && INTERP="$PYENV_ROOT_ACTUAL/shims/python"; [ ! -x "$INTERP" ] && log "No usable pyenv interpreter found for version $ACTIVE_VERSION" && exit 1; log "Using global pyenv version $ACTIVE_VERSION -> $INTERP"; fi
fi
[ -z "${INTERP:-}" ] && log "No usable pyenv interpreter found" && exit 1
log "Selected interpreter: $INTERP"
CFGDIR="$USER_HOME/Library/Application Support/Code/User"
mkdir -p "$CFGDIR"
SETTINGS_FILE="$CFGDIR/settings.json"
NEW_SETTINGS=$(mktemp)
cat > "$NEW_SETTINGS" <<JSON
{"python.defaultInterpreterPath":"$INTERP","python.formatting.provider":"black","[python]":{"editor.defaultFormatter":"ms-python.black-formatter","editor.formatOnSave":true},"editor.codeActionsOnSave":{"source.organizeImports":true},"python.linting.enabled":true,"python.linting.pylintEnabled":true,"python.testing.pytestEnabled":true,"python.languageServer":"Pylance","python.analysis.typeCheckingMode":"basic","python.analysis.extraPaths":["$PYENV_ROOT_ACTUAL/versions"],"files.exclude":{"**/__pycache__":true},"files.autoSave":"afterDelay","files.autoSaveDelay":1000}
JSON
if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS_FILE" ]; then jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$NEW_SETTINGS" > "${NEW_SETTINGS}.merged" && mv "${NEW_SETTINGS}.merged" "$SETTINGS_FILE" || mv "$NEW_SETTINGS" "$SETTINGS_FILE"; else if [ -f "$SETTINGS_FILE" ]; then cp "$SETTINGS_FILE" "$SETTINGS_FILE".bak || true; mv "$NEW_SETTINGS" "$SETTINGS_FILE"; else mv "$NEW_SETTINGS" "$SETTINGS_FILE"; fi; fi
log "Verifying Jupyter variable explorer availability"
if code --list-extensions | grep -Fxq "ms-toolsai.jupyter"; then log "Jupyter extension present, Variables pane and Data Viewer available"; else log "Jupyter extension missing; install ms-toolsai.jupyter to get Data Viewer/Variables pane"; fi
log "Done. VS Code configured: interpreter $INTERP, autosave on, extensions installed"
