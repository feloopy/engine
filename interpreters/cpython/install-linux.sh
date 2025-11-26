#!/usr/bin/env bash
set -euo pipefail
clear

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

PKG_MANAGER=""
if command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt";
elif command -v dnf >/dev/null 2>&1; then PKG_MANAGER="dnf";
elif command -v yum >/dev/null 2>&1; then PKG_MANAGER="yum";
elif command -v pacman >/dev/null 2>&1; then PKG_MANAGER="pacman";
elif command -v zypper >/dev/null 2>&1; then PKG_MANAGER="zypper";
fi

printf 'Detected package manager: %s\n' "$PKG_MANAGER"

install_prereqs(){
  case "$PKG_MANAGER" in
    apt)
      sudo apt-get update -qq
      sudo apt-get install -y build-essential curl git libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev xz-utils tk-dev
      ;;
    dnf)
      sudo dnf install -y @development-tools curl git bzip2 bzip2-devel zlib-devel readline-devel sqlite sqlite-devel xz-devel tk-devel libffi-devel
      ;;
    yum)
      sudo yum groupinstall -y "Development Tools"
      sudo yum install -y curl git bzip2 bzip2-devel zlib-devel readline-devel sqlite sqlite-devel xz-devel tk-devel libffi-devel
      ;;
    pacman)
      PACMAN_PKGS=(base-devel curl git bzip2 xz tk libffi)
      # Avoid zlib conflict on CachyOS/Arch derivatives
      if ! pacman -Q zlib-ng-compat >/dev/null 2>&1; then
        PACMAN_PKGS+=(zlib)
      fi
      sudo pacman -Syu --noconfirm "${PACMAN_PKGS[@]}"
      ;;
    zypper)
      sudo zypper install -y -t pattern devel_C_C++
      sudo zypper install -y curl git libopenssl-devel zlib-devel bzip2-devel readline-devel sqlite3-devel xz-devel tk-devel libffi-devel
      ;;
    *)
      printf 'No known package manager detected. Please install build tools manually.\n' >&2
      ;;
  esac
}

install_prereqs

mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT" ]; then
  git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" || git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT" || true
fi
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv" || true; fi

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
    _add_if_missing "$ZSH_PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$ZSH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$ZSH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    _add_if_missing "$ZSH_RC" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$ZSH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
    _add_if_missing "$ZSH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
    ;;
  *bash*|*ksh*|*sh*|*dash*)
    if [ ! -f "$BASH_PROFILE" ] && [ -f "$PROFILE" ]; then BASH_PROFILE="$PROFILE"; fi
    _add_if_missing "$BASH_PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$BASH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$BASH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    _add_if_missing "$BASH_RC" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$BASH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
    _add_if_missing "$BASH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
    ;;
  *)
    _add_if_missing "$PROFILE" 'export PYENV_ROOT="$HOME/.pyenv"' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
    ;;
esac

hash -r 2>/dev/null || true
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)" 2>/dev/null || true
eval "$(pyenv init -)" 2>/dev/null || true
[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ] && eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
clear
printf '\n🎉 pyenv and pyenv-virtualenv setup complete!\n'
pyenv