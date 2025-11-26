#!/usr/bin/env bash
set -euo pipefail
clear
USER_HOME="${HOME:-$( [ "$(id -u)" -eq 0 ] && echo /root || echo /home/$(whoami) )}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
DETECTED_SHELL=""
if [ -n "${SHELL:-}" ]; then DETECTED_SHELL="$(basename "$SHELL")"; fi
if [ -z "$DETECTED_SHELL" ]; then
  if [ -r "/proc/$$/cmdline" ]; then DETECTED_SHELL="$(tr '\0' ' ' < /proc/$$/cmdline | awk '{print $1}' | awk -F/ '{print $NF}')"; fi
fi
if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' || true)"; fi
DETECTED_SHELL="$(echo "${DETECTED_SHELL:-}" | tr '[:upper:]' '[:lower:]')"
BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; PROFILE="$USER_HOME/.profile"
ZSH_RC="${ZDOTDIR:-$USER_HOME}/.zshrc"; ZSH_PROFILE="${ZDOTDIR:-$USER_HOME}/.zprofile"
FISH_CFG="$XDG_CONFIG_HOME/fish/config.fish"
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
printf '\n🎉 pyenv and pyenv-virtualenv setup complete!\n'
