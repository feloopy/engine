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
detect_pkg(){ if command -v apt-get >/dev/null 2>&1; then echo apt; elif command -v dnf >/dev/null 2>&1; then echo dnf; elif command -v yum >/dev/null 2>&1; then echo yum; elif command -v pacman >/dev/null 2>&1; then echo pacman; elif command -v zypper >/dev/null 2>&1; then echo zypper; else echo ""; fi }
PKG_MANAGER="$(detect_pkg)"
install_vscode(){ log "Installing or verifying VS Code"; case "$PKG_MANAGER" in
  apt) run "curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg" || true; sudo install -o root -g root -m 644 /tmp/packages.microsoft.gpg /usr/share/keyrings/packages.microsoft.gpg || true; echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null; sudo apt-get update -qq || true; run "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y code" || true ;;
  dnf|yum) run "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc" || true; sudo sh -c 'printf "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n" > /etc/yum.repos.d/vscode.repo'; if command -v dnf >/dev/null 2>&1; then run "sudo dnf install -y code" || true; else run "sudo yum install -y code" || true; fi ;;
  pacman)
    log "Detected pacman"
    if pacman -Q visual-studio-code-bin >/dev/null 2>&1; then log "Using installed visual-studio-code-bin"; return 0; fi
    if run "sudo pacman -Sy --noconfirm code"; then return 0; fi
    if pacman -Q visual-studio-code-bin >/dev/null 2>&1; then log "Removing conflicting visual-studio-code-bin and retry"; run "sudo pacman -Rns --noconfirm visual-studio-code-bin" || log "Could not remove visual-studio-code-bin"; if run "sudo pacman -Sy --noconfirm code"; then return 0; fi; fi
    if command -v snap >/dev/null 2>&1 && run "sudo snap install --classic code"; then return 0; fi
    if command -v flatpak >/dev/null 2>&1 && run "flatpak install -y flathub com.visualstudio.code"; then return 0; fi
    if command -v yay >/dev/null 2>&1 && run "yay -S --noconfirm visual-studio-code-bin"; then return 0; fi
    if command -v paru >/dev/null 2>&1 && run "paru -S --noconfirm visual-studio-code-bin"; then return 0; fi
    if command -v git >/dev/null 2>&1 && command -v makepkg >/dev/null 2>&1; then tmpdir="$(mktemp -d)"; run "git clone https://aur.archlinux.org/visual-studio-code-bin.git \"$tmpdir\" && cd \"$tmpdir\" && makepkg -si --noconfirm" && rm -rf "$tmpdir" && return 0 || true; fi
    log "Could not auto install VS Code on Arch. Install manually if needed" ;;
  zypper) run "sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc" || true; sudo sh -c 'printf "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n" > /etc/zypp/repos.d/vscode.repo'; run "sudo zypper refresh" || true; run "sudo zypper install -y code" || true ;;
  *) if command -v snap >/dev/null 2>&1 && run "sudo snap install --classic code"; then return 0; fi; if command -v flatpak >/dev/null 2>&1 && run "flatpak install -y flathub com.visualstudio.code"; then return 0; fi; log "No automatic install method for VS Code detected. Install manually: https://code.visualstudio.com/download"; ;;
esac; }
install_vscode
if ! command -v code >/dev/null 2>&1; then log 'Error: "code" CLI not found after install. Ensure VS Code is installed and "code" is on PATH.'; exit 1; fi
exts=(ms-python.python ms-python.vscode-pylance ms-toolsai.jupyter ms-toolsai.jupyter-renderers ms-python.black-formatter ms-python.isort njpwerner.autodocstring ms-vscode-remote.remote-containers VariableExplorer.variable-explorer Google.colab)
install_ext(){ local e="$1" tmpu tmpx rc
  if code --list-extensions | grep -Fxq "$e"; then log "Extension $e already installed"; return 0; fi
  for ((i=1;i<=RETRY_COUNT;i++)); do
    log "Installing extension $e (attempt $i)"
    if code --install-extension "$e" --force >/dev/null 2>&1; then log "Installed $e"; return 0; fi
    rc=$?
    log "Install returned $rc, trying isolated dirs"
    tmpu="$(mktemp -d)" && tmpx="$(mktemp -d)"
    if command -v timeout >/dev/null 2>&1; then timeout 60s code --user-data-dir "$tmpu" --extensions-dir "$tmpx" --install-extension "$e" --force >/dev/null 2>&1 || true; else code --user-data-dir "$tmpu" --extensions-dir "$tmpx" --install-extension "$e" --force >/dev/null 2>&1 || true; fi
    if code --list-extensions --extensions-dir "$tmpx" | grep -Fxq "$e"; then log "Installed $e into isolated dir"; rm -rf "$tmpu" "$tmpx"; return 0; fi
    rm -rf "$tmpu" "$tmpx"
    if [ $i -lt "$RETRY_COUNT" ]; then sleep $((i*i)); else log "Failed to install extension $e after $RETRY_COUNT attempts"; fi
  done
  return 1
}
for e in "${exts[@]}"; do install_ext "$e" || true; done
log "Inspecting pyenv and pyenv-virtualenv environments"
PYENV_ROOT_ACTUAL="$("$PYENV_BIN" root 2>/dev/null || echo "$PYENV_ROOT")"
[ ! -d "$PYENV_ROOT_ACTUAL" ] && log "pyenv root not found at $PYENV_ROOT_ACTUAL" && exit 1
if [ -n "${VIRTUAL_ENV:-}" ] && [ -x "${VIRTUAL_ENV}/bin/python" ]; then INTERP="${VIRTUAL_ENV}/bin/python"; log "Using active VIRTUAL_ENV: $INTERP"
else
  if [ -f ".python-version" ]; then pv="$(<.python-version)"; pv="$(printf '%s' "$pv" | tr -d '[:space:]')"; if [ -n "$pv" ]; then
    if [ -d "$PYENV_ROOT_ACTUAL/versions/$pv" ] && [ -x "$PYENV_ROOT_ACTUAL/versions/$pv/bin/python" ]; then INTERP="$PYENV_ROOT_ACTUAL/versions/$pv/bin/python"; log "Using .python-version => $pv -> $INTERP"; fi
  fi; fi
  if [ -z "${INTERP:-}" ]; then
    if "$PYENV_BIN" virtualenvs --bare >/dev/null 2>&1; then mapfile -t PV < <("$PYENV_BIN" virtualenvs --bare 2>/dev/null)
      proj="$(basename "$(pwd)")"
      for v in "${PV[@]}"; do if [ "$v" = "$proj" ] || [[ "$v" = *"$proj"* ]]; then [ -x "$PYENV_ROOT_ACTUAL/versions/$v/bin/python" ] && INTERP="$PYENV_ROOT_ACTUAL/versions/$v/bin/python" && log "Matched virtualenv $v to project $proj" && break; fi; done
      if [ -z "${INTERP:-}" ] && [ "${#PV[@]}" -gt 0 ]; then for v in "${PV[@]}"; do [ -x "$PYENV_ROOT_ACTUAL/versions/$v/bin/python" ] && INTERP="$PYENV_ROOT_ACTUAL/versions/$v/bin/python" && log "Picked virtualenv $v" && break; done; fi
    fi
  fi
  if [ -z "${INTERP:-}" ]; then
    ACTIVE_VERSION="$("$PYENV_BIN" global --bare 2>/dev/null || true)"
    if [ -z "$ACTIVE_VERSION" ]; then AVAILABLE="$("$PYENV_BIN" versions --bare 2>/dev/null || true)"; ACTIVE_VERSION="$(printf '%s\n' "$AVAILABLE" | grep -v '^system$' | sort -V | tail -n1 || true)"; fi
    if [ -z "$ACTIVE_VERSION" ]; then log "No pyenv versions available."; exit 1; fi
    INTERP="$PYENV_ROOT_ACTUAL/versions/$ACTIVE_VERSION/bin/python"
    [ ! -x "$INTERP" ] && INTERP="$PYENV_ROOT_ACTUAL/shims/python"
    [ ! -x "$INTERP" ] && log "No usable pyenv interpreter found for version $ACTIVE_VERSION" && exit 1
    log "Using global pyenv version $ACTIVE_VERSION -> $INTERP"
  fi
fi
[ -z "${INTERP:-}" ] && log "No usable pyenv interpreter found" && exit 1
log "Selected interpreter: $INTERP"
if [ "$(uname -s)" = "Darwin" ]; then CFGDIR="$USER_HOME/Library/Application Support/Code/User"; else CFGDIR="${XDG_CONFIG_HOME:-$USER_HOME/.config}/Code/User"; fi
mkdir -p "$CFGDIR"
SETTINGS_FILE="$CFGDIR/settings.json"
NEW_SETTINGS=$(mktemp)
cat > "$NEW_SETTINGS" <<JSON
{"python.defaultInterpreterPath":"$INTERP","python.formatting.provider":"black","[python]":{"editor.defaultFormatter":"ms-python.black-formatter","editor.formatOnSave":true},"editor.codeActionsOnSave":{"source.organizeImports":true},"python.linting.enabled":true,"python.linting.pylintEnabled":true,"python.testing.pytestEnabled":true,"python.languageServer":"Pylance","python.analysis.typeCheckingMode":"basic","python.analysis.extraPaths":["$PYENV_ROOT_ACTUAL/versions"],"files.exclude":{"**/__pycache__":true},"files.autoSave":"afterDelay","files.autoSaveDelay":1000}
JSON
if command -v jq >/dev/null 2>&1 && [ -f "$SETTINGS_FILE" ]; then jq -s '.[0] * .[1]' "$SETTINGS_FILE" "$NEW_SETTINGS" > "${NEW_SETTINGS}.merged" && mv "${NEW_SETTINGS}.merged" "$SETTINGS_FILE" || mv "$NEW_SETTINGS" "$SETTINGS_FILE"; else if [ -f "$SETTINGS_FILE" ]; then cp "$SETTINGS_FILE" "$SETTINGS_FILE".bak || true; mv "$NEW_SETTINGS" "$SETTINGS_FILE"; else mv "$NEW_SETTINGS" "$SETTINGS_FILE"; fi; fi
log "Verifying Jupyter variable explorer availability"
if code --list-extensions | grep -Fxq "ms-toolsai.jupyter"; then log "Jupyter extension present, Variables pane and Data Viewer available"; else log "Jupyter extension missing; install ms-toolsai.jupyter to get Data Viewer/Variables pane"; fi

create_context_menu(){ mkdir -p "$USER_HOME/.local/share/applications" "$USER_HOME/.local/share/nautilus/scripts" "$XDG_CONFIG_HOME"; cat >"$USER_HOME/.local/share/applications/open-with-vscode.desktop" <<'DESK'
[Desktop Entry]
Name=Open with Code
Exec=code --new-window %F
Terminal=false
Type=Application
Icon=visual-studio-code
Categories=Development;IDE;
MimeType=inode/directory;text/plain;application/x-python;application/x-shellscript;application/json;
DESK
chmod 644 "$USER_HOME/.local/share/applications/open-with-vscode.desktop" || true
if command -v update-desktop-database >/dev/null 2>&1; then update-desktop-database "$USER_HOME/.local/share/applications" >/dev/null 2>&1 || true; fi
printf '%s\n' '#!/bin/bash' 'code "$@"' >"$USER_HOME/.local/share/nautilus/scripts/Open With Code" && chmod +x "$USER_HOME/.local/share/nautilus/scripts/Open With Code" || true
for m in inode/directory text/plain application/x-python application/x-shellscript application/json; do if command -v xdg-mime >/dev/null 2>&1; then xdg-mime default open-with-vscode.desktop "$m" >/dev/null 2>&1 || true; fi; done
MIMEFILE="${XDG_CONFIG_HOME:-$USER_HOME/.config}/mimeapps.list"
[ -f "$MIMEFILE" ] || printf '%s\n' '[Default Applications]' '[Added Associations]' >"$MIMEFILE"
if ! grep -Fq 'inode/directory=open-with-vscode.desktop' "$MIMEFILE" 2>/dev/null; then awk '/\[Added Associations\]/{print;print "inode/directory=open-with-vscode.desktop;";next}1' "$MIMEFILE" >"$MIMEFILE.tmp" 2>/dev/null && mv "$MIMEFILE.tmp" "$MIMEFILE" || true; fi
}
create_context_menu || true

log "Done. VS Code configured: interpreter $INTERP, autosave on, extensions installed"
