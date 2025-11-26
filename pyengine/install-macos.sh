#!/usr/bin/env bash
trap_exit(){ code="$1"; if [ "${code:-0}" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n'; fi; if [ -t 1 ]; then printf '\nPress Enter to close...'; read -r _dummy; fi; exit "$code"; }
trap 'rc=$?; trap_exit "$rc"' EXIT
clear
printf '=== pyenv Installation Script for macOS ===\n\n'
USER_HOME="${HOME:-/Users/$(whoami)}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
FISH_CFG="$USER_HOME/.config/fish/config.fish"; BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; ZSH_RC="$USER_HOME/.zshrc"; ZSH_PROFILE="$USER_HOME/.zprofile"
DETECTED_SHELL="$(basename "${SHELL:-}")"; if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= | awk -F/ '{print $NF}')"; fi
ARCH="$(uname -m)"; MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
printf 'Detected macOS: %s\n' "$MACOS_VERSION"; printf 'Detected architecture: %s\n' "$ARCH"; printf 'Detected shell: %s\n' "$DETECTED_SHELL"; printf 'User home: %s\n' "$USER_HOME"; printf 'Using PYENV_ROOT: %s\n\n' "$PYENV_ROOT"
printf 'Checking for Xcode Command Line Tools...\n'
if ! xcode-select -p >/dev/null 2>&1; then
  printf 'Xcode Command Line Tools not found. Installing... A dialog may appear.\n\n'
  xcode-select --install 2>/dev/null || true
  while ! xcode-select -p >/dev/null 2>&1; do printf 'Waiting for Xcode Command Line Tools installation...\n'; sleep 10; done
  printf 'Xcode Command Line Tools installed\n\n'
else printf 'Xcode Command Line Tools already installed.\n\n'; fi
printf 'Checking for Homebrew...\n'
if ! command -v brew >/dev/null 2>&1; then
  printf 'Homebrew not found. Installing Homebrew...\n'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(command -v brew 2>/dev/null || true)"
  if [ -n "$BREW_BIN" ]; then printf 'eval "$(%s shellenv)"\n' "$BREW_BIN" >> "$USER_HOME/.zprofile"; eval "$("$BREW_BIN" shellenv)"; fi
else printf 'Homebrew already installed.\n'; BREW_BIN="$(command -v brew)"; fi
printf '\nUpdating Homebrew and installing required packages...\n'
if command -v brew >/dev/null 2>&1; then brew update >/dev/null 2>&1 || true; brew upgrade >/dev/null 2>&1 || true; fi
BREW_PACKAGES=(openssl readline sqlite3 xz zlib tcl-tk libffi curl git)
printf 'Installing packages with Homebrew: %s\n' "${BREW_PACKAGES[*]}"
start_time=$(date +%s)
if command -v brew >/dev/null 2>&1; then
  if ! brew install "${BREW_PACKAGES[@]}"; then printf 'Package installation failed; continuing\n' >&2; fi
else
  printf 'brew not available, skipping package installation\n'
fi
end_time=$(date +%s); duration=$((end_time-start_time)); printf 'Package installation took %d seconds\n' "$duration"
LDFLAGS=""; CPPFLAGS=""; PKG_CONFIG_PATH=""
if command -v brew >/dev/null 2>&1; then
  for pkg in openssl readline sqlite3 zlib tcl-tk libffi; do
    prefix="$(brew --prefix "$pkg" 2>/dev/null || true)"
    if [ -n "$prefix" ]; then
      LDFLAGS="$LDFLAGS -L$prefix/lib"
      CPPFLAGS="$CPPFLAGS -I$prefix/include"
      PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$prefix/lib/pkgconfig"
    fi
  done
  LDFLAGS="${LDFLAGS## }"; CPPFLAGS="${CPPFLAGS## }"; PKG_CONFIG_PATH="${PKG_CONFIG_PATH#:}"
else
  if [ "$ARCH" = "arm64" ]; then
    LDFLAGS="-L/opt/homebrew/lib -L/usr/local/opt/openssl/lib"
    CPPFLAGS="-I/opt/homebrew/include -I/usr/local/opt/openssl/include"
    PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
  else
    LDFLAGS="-L/usr/local/opt/openssl/lib"
    CPPFLAGS="-I/usr/local/opt/openssl/include"
    PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
  fi
fi
export LDFLAGS CPPFLAGS PKG_CONFIG_PATH
if [ ! -d "$PYENV_ROOT" ]; then
  printf 'Cloning pyenv into %s\n' "$PYENV_ROOT"
  if git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'Pyenv cloned\n'; else printf 'Direct clone failed, trying mirror...\n'; if git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'Pyenv cloned from mirror\n'; else printf 'Failed to clone pyenv\n' >&2; exit 1; fi; fi
fi
export PATH="$PYENV_ROOT/bin:$PATH"
mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then printf 'Cloning pyenv-virtualenv\n'; if git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"; then printf 'pyenv-virtualenv cloned\n'; else printf 'Failed to clone pyenv-virtualenv, continuing\n' >&2; fi; fi
for f in "$FISH_CFG" "$BASH_RC" "$BASH_PROFILE" "$ZSH_RC" "$ZSH_PROFILE"; do
  if [ -n "$f" ]; then d="$(dirname "$f")"; mkdir -p "$d" 2>/dev/null || printf 'Warning: Could not create directory %s\n' "$d" >&2; [ -f "$f" ] || touch "$f" 2>/dev/null || printf 'Warning: Could not create file %s\n' "$f" >&2; fi
done
_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; [ -z "$file" ] && return 1; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; printf 'Added to %s: %s\n' "$file" "$pattern"; fi; else printf '%s\n' "$line" > "$file"; printf 'Created %s with: %s\n' "$file" "$pattern"; fi }
printf '\nConfiguring shell...\n'
fish_config="$USER_HOME/.config/fish/config.fish"
if [ "$DETECTED_SHELL" = "fish" ]; then
  printf 'Configuring fish shell...\n'; mkdir -p "$(dirname "$fish_config")"; touch "$fish_config"
  _add_if_missing "$fish_config" 'set -Ux PYENV_ROOT' 'set -Ux PYENV_ROOT $HOME/.pyenv'
  _add_if_missing "$fish_config" 'fish_user_paths $PYENV_ROOT/bin' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
  _add_if_missing "$fish_config" 'pyenv init --path' 'status is-login; and pyenv init --path | source'
  _add_if_missing "$fish_config" 'pyenv init -' 'status is-interactive; and pyenv init - | source'
  _add_if_missing "$fish_config" 'pyenv virtualenv-init -' 'status is-interactive; and pyenv virtualenv-init - | source'
elif [ "$DETECTED_SHELL" = "bash" ] || [ "$DETECTED_SHELL" = "sh" ]; then
  printf 'Configuring bash shell...\n'
  _add_if_missing "$BASH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$BASH_PROFILE" 'pyenv init --path' 'eval "$(pyenv init --path)"'
  _add_if_missing "$BASH_RC" 'pyenv init -' 'eval "$(pyenv init -)"'
  _add_if_missing "$BASH_RC" 'pyenv virtualenv-init -' 'eval "$(pyenv virtualenv-init -)"'
elif [ "$DETECTED_SHELL" = "zsh" ]; then
  printf 'Configuring zsh shell...\n'
  _add_if_missing "$ZSH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$ZSH_PROFILE" 'pyenv init --path' 'eval "$(pyenv init --path)"'
  _add_if_missing "$ZSH_RC" 'pyenv init -' 'eval "$(pyenv init -)"'
  _add_if_missing "$ZSH_RC" 'pyenv virtualenv-init -' 'eval "$(pyenv virtualenv-init -)"'
fi
if command -v pyenv >/dev/null 2>&1; then
  case "$-" in *i*) eval "$(pyenv init --path)" 2>/dev/null || true; eval "$(pyenv init -)" 2>/dev/null || true; command -v pyenv-virtualenv >/dev/null 2>&1 && eval "$(pyenv virtualenv-init -)" 2>/dev/null || true ;; esac
fi
clear
printf '\n🎉 Done!\n'
pyenv