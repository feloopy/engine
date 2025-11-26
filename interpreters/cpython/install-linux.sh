#!/usr/bin/env bash
set -euo pipefail
USER_HOME="${HOME:-$( [ "$(id -u)" -eq 0 ] && echo /root || echo /home/$(whoami) )}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
DETECTED_SHELL="${SHELL:+$(basename "$SHELL")}"
[ -z "$DETECTED_SHELL" ] && [ -r "/proc/$$/cmdline" ] && DETECTED_SHELL="$(tr '\0' ' ' < /proc/$$/cmdline | awk '{print $1}' | awk -F/ '{print $NF}')"
[ -z "$DETECTED_SHELL" ] && DETECTED_SHELL="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' || true)"
DETECTED_SHELL="$(echo "${DETECTED_SHELL:-}" | tr '[:upper:]' '[:lower:]')"
BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; PROFILE="$USER_HOME/.profile"
ZSH_RC="${ZDOTDIR:-$USER_HOME}/.zshrc"; ZSH_PROFILE="${ZDOTDIR:-$USER_HOME}/.zprofile"
FISH_CFG="$XDG_CONFIG_HOME/fish/config.fish"
CI_DETECTED=0
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ -n "${TF_BUILD:-}" ]; then CI_DETECTED=1; fi
INSTALL_PREREQS="${INSTALL_PREREQS:-0}"
WRITE_PROFILES="${WRITE_PROFILES:-1}"
RETRY_COUNT="${RETRY_COUNT:-3}"
PKG_MANAGER=""
if [ "$INSTALL_PREREQS" -eq 1 ] && [ "$CI_DETECTED" -eq 0 ]; then
  if command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then PKG_MANAGER="yum"
  elif command -v pacman >/dev/null 2>&1; then PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null 2>&1; then PKG_MANAGER="zypper"
  fi
fi
install_prereqs(){
  case "$PKG_MANAGER" in
    apt) sudo apt-get update -qq; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential curl git libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev xz-utils tk-dev ;;
    dnf) sudo dnf install -y @development-tools curl git bzip2 bzip2-devel zlib-devel readline-devel sqlite sqlite-devel xz-devel tk-devel libffi-devel ;;
    yum) sudo yum groupinstall -y "Development Tools"; sudo yum install -y curl git bzip2 bzip2-devel zlib-devel readline-devel sqlite sqlite-devel xz-devel tk-devel libffi-devel ;;
    pacman) PACMAN_PKGS=(base-devel curl git bzip2 xz tk libffi); if ! pacman -Q zlib-ng-compat >/dev/null 2>&1; then PACMAN_PKGS+=(zlib); fi; sudo pacman -Syu --noconfirm "${PACMAN_PKGS[@]}" ;;
    zypper) sudo zypper install -y -t pattern devel_C_C++; sudo zypper install -y curl git libopenssl-devel zlib-devel bzip2-devel readline-devel sqlite3-devel xz-devel tk-devel libffi-devel ;;
    *) printf 'No supported package manager detected or installation skipped.\n' >&2 ;;
  esac
}
if [ "$INSTALL_PREREQS" -eq 1 ] && [ "$CI_DETECTED" -eq 0 ]; then install_prereqs; fi
mkdir -p "$PYENV_ROOT/plugins"
clone_with_retries(){ local url="$1"; local dest="$2"; local i=0; while [ $i -lt "$RETRY_COUNT" ]; do if git clone --depth 1 "$url" "$dest" 2>/dev/null; then return 0; fi; i=$((i+1)); sleep $((i*2)); rm -rf "$dest"; done; return 1; }
if [ ! -d "$PYENV_ROOT" ] || [ ! -x "$PYENV_ROOT/bin/pyenv" ]; then
  rm -rf "$PYENV_ROOT"
  if ! clone_with_retries "https://github.com/pyenv/pyenv.git" "$PYENV_ROOT"; then clone_with_retries "https://ghproxy.com/https://github.com/pyenv/pyenv.git" "$PYENV_ROOT" || true; fi
fi
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
  rm -rf "$PYENV_ROOT/plugins/pyenv-virtualenv"
  clone_with_retries "https://github.com/pyenv/pyenv-virtualenv.git" "$PYENV_ROOT/plugins/pyenv-virtualenv" || true
fi
if [ -d "$PYENV_ROOT" ]; then
  if [ -f "$PYENV_ROOT/bin/pyenv" ]; then chmod +x "$PYENV_ROOT/bin/pyenv" 2>/dev/null || true; fi
  if [ ! -x "$PYENV_ROOT/bin/pyenv" ] && command -v pyenv >/dev/null 2>&1; then
    EXISTING_PYENV_PATH="$(command -v pyenv)"
    EXISTING_ROOT="$(pyenv root 2>/dev/null || true)"
    if [ -n "$EXISTING_ROOT" ]; then PYENV_ROOT="${PYENV_ROOT:-$EXISTING_ROOT}"; fi
  fi
fi
_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; [ -z "$file" ] && return 1; mkdir -p "$(dirname "$file")"; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; fi; else printf '%s\n' "$line" > "$file"; fi }
case "$DETECTED_SHELL" in
  *fish*)
    mkdir -p "$(dirname "$FISH_CFG")"
    _add_if_missing "$FISH_CFG" 'set -Ux PYENV_ROOT $HOME/.pyenv' 'set -Ux PYENV_ROOT $HOME/.pyenv'
    _add_if_missing "$FISH_CFG" 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
    _add_if_missing "$FISH_CFG" 'status --is-login; and source (pyenv init --path | psub)' 'status --is-login; and source (pyenv init --path | psub)'
    _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv init - | psub)' 'status --is-interactive; and source (pyenv init - | psub)'
    _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv virtualenv-init - | psub)' 'status --is-interactive; and source (pyenv virtualenv-init - | psub)'
    ;;
  *zsh*)
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_RC" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$ZSH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
    ;;
  *bash*|*ksh*|*sh*|*dash*)
    if [ ! -f "$BASH_PROFILE" ] && [ -f "$PROFILE" ]; then BASH_PROFILE="$PROFILE"; fi
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_RC" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$BASH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
    ;;
  *)
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    [ "$WRITE_PROFILES" -eq 1 ] && _add_if_missing "$PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    ;;
esac
export PATH="$PYENV_ROOT/bin:$PATH"
if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
  set +e
  eval "$("$PYENV_ROOT/bin/pyenv" init --path)" 2>/dev/null || true
  eval "$("$PYENV_ROOT/bin/pyenv" init -)" 2>/dev/null || true
  if [ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
    if "$PYENV_ROOT/bin/pyenv" virtualenv-init - >/dev/null 2>&1; then eval "$("$PYENV_ROOT/bin/pyenv" virtualenv-init -)" 2>/dev/null || true; fi
  fi
  set -e
else
  if command -v pyenv >/dev/null 2>&1; then
    EXISTING="$(command -v pyenv)"
    export PATH="$(dirname "$EXISTING"):$PATH"
  else
    printf 'Warning: pyenv binary not found at %s. Clone may have failed or permissions prevent execution.\n' "$PYENV_ROOT/bin/pyenv" >&2
  fi
fi
hash -r 2>/dev/null || true
if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
  "$PYENV_ROOT/bin/pyenv" --version || true
  "$PYENV_ROOT/bin/pyenv" root || true
else
  command -v pyenv >/dev/null 2>&1 && pyenv --version || printf 'pyenv not available in this shell\n'
fi
if [ "$CI_DETECTED" -eq 1 ] && [ -n "${GITHUB_ENV:-}" ]; then
  printf 'PYENV_ROOT=%s\n' "$PYENV_ROOT" >> "$GITHUB_ENV"
  printf 'PATH=%s:$PATH\n' "$PYENV_ROOT/bin" >> "$GITHUB_ENV"
fi
printf '\n🎉 pyenv and pyenv-virtualenv setup complete!\n'
