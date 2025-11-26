#!/usr/bin/env bash
trap_exit(){ code="$1"; if [ "${code:-0}" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n'; fi; if [ -t 1 ]; then printf '\nPress Enter to close...'; read -r _dummy; fi; exit "$code"; }
trap 'rc=$?; trap_exit "$rc"' EXIT
clear
printf '=== pyenv Installation ===\n\n'
USER_HOME="${HOME:-/Users/$(whoami)}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
FISH_CFG="$XDG_CONFIG_HOME/fish/config.fish"; BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; ZSH_RC="${ZDOTDIR:-$USER_HOME}/.zshrc"; ZSH_PROFILE="${ZDOTDIR:-$USER_HOME}/.zprofile"
DETECTED_SHELL=""
if [ -n "${SHELL:-}" ]; then DETECTED_SHELL="$(basename "$SHELL")"; fi
if [ -z "$DETECTED_SHELL" ]; then
  if [ -r "/proc/$$/cmdline" ]; then DETECTED_SHELL="$(tr '\0' ' ' < /proc/$$/cmdline | awk '{print $1}' | awk -F/ '{print $NF}')"; fi
fi
if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' || true)"; fi
DETECTED_SHELL="$(echo "${DETECTED_SHELL:-}" | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"; MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
printf 'OS version: %s\n' "$MACOS_VERSION"; printf 'arch: %s\n' "$ARCH"; printf 'shell: %s\n' "$DETECTED_SHELL"; printf 'home: %s\n' "$USER_HOME"; printf 'PYENV_ROOT: %s\n\n' "$PYENV_ROOT"
printf 'Checking for build tools\n'
if ! xcode-select -p >/dev/null 2>&1; then
  printf 'Installing Command Line Tools\n'
  xcode-select --install 2>/dev/null || true
  while ! xcode-select -p >/dev/null 2>&1; do printf '.'; sleep 2; done
  printf '\nCommand Line Tools installed\n\n'
else printf 'Build tools present\n\n'; fi
printf 'Checking for Homebrew\n'
if ! command -v brew >/dev/null 2>&1; then
  printf 'Installing Homebrew\n'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(command -v brew 2>/dev/null || true)"
  if [ -n "$BREW_BIN" ]; then printf 'eval "$(%s shellenv)"' "$BREW_BIN" >> "$USER_HOME/.zprofile"; eval "$("$BREW_BIN" shellenv)"; fi
else printf 'Homebrew present\n'; BREW_BIN="$(command -v brew)"; fi
printf '\nUpdating Homebrew and packages\n'
if command -v brew >/dev/null 2>&1; then brew update >/dev/null 2>&1 || true; brew upgrade >/dev/null 2>&1 || true; fi
BREW_PACKAGES=(openssl readline sqlite3 xz zlib tcl-tk libffi curl git)
printf 'Installing: %s\n' "${BREW_PACKAGES[*]}"
start_time=$(date +%s)
if command -v brew >/dev/null 2>&1; then
  if ! brew install "${BREW_PACKAGES[@]}"; then printf 'Some packages failed to install, continuing\n' >&2; fi
else
  printf 'brew not available, skipping package install\n'
fi
end_time=$(date +%s); duration=$((end_time-start_time)); printf 'Package install time: %d seconds\n' "$duration"
LDFLAGS=""; CPPFLAGS=""; PKG_CONFIG_PATH=""
if command -v brew >/dev/null 2>&1; then
  for pkg in openssl readline sqlite3 zlib tcl-tk libffi; do
    prefix="$(brew --prefix "$pkg" 2>/dev/null || true)"
    if [ -n "$prefix" ]; then LDFLAGS="$LDFLAGS -L$prefix/lib"; CPPFLAGS="$CPPFLAGS -I$prefix/include"; PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$prefix/lib/pkgconfig"; fi
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
mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT" ]; then
  printf 'Cloning pyenv into %s\n' "$PYENV_ROOT"
  if git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'pyenv cloned\n'; else printf 'Clone failed, trying mirror\n'; if git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'pyenv cloned from mirror\n'; else printf 'Failed to clone pyenv\n' >&2; exit 1; fi; fi
fi
export PATH="$PYENV_ROOT/bin:$PATH"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then printf 'Cloning pyenv-virtualenv\n'; if git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"; then printf 'pyenv-virtualenv cloned\n'; else printf 'pyenv-virtualenv clone failed, continuing\n' >&2; fi; fi
for f in "$FISH_CFG" "$BASH_RC" "$BASH_PROFILE" "$ZSH_RC" "$ZSH_PROFILE"; do
  if [ -n "$f" ]; then d="$(dirname "$f")"; mkdir -p "$d" 2>/dev/null || printf 'Warning: could not create %s\n' "$d" >&2; [ -f "$f" ] || touch "$f" 2>/dev/null || printf 'Warning: could not create %s\n' "$f" >&2; fi
done
_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; [ -z "$file" ] && return 1; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; printf 'Added to %s: %s\n' "$file" "$pattern"; fi; else printf '%s\n' "$line" > "$file"; printf 'Created %s with: %s\n' "$file" "$pattern"; fi }
printf '\nConfiguring shells\n'
fish_config="$FISH_CFG"
if [ "$DETECTED_SHELL" = "fish" ]; then
  printf 'Configuring fish\n'; mkdir -p "$(dirname "$fish_config")"; touch "$fish_config"
  _add_if_missing "$fish_config" 'set -Ux PYENV_ROOT' 'set -Ux PYENV_ROOT $HOME/.pyenv'
  _add_if_missing "$fish_config" 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
  _add_if_missing "$fish_config" 'pyenv init --path' 'status is-login; and pyenv init --path | source'
  _add_if_missing "$fish_config" 'pyenv init -' 'status is-interactive; and pyenv init - | source'
  _add_if_missing "$fish_config" 'pyenv virtualenv-init -' 'status is-interactive; and pyenv virtualenv-init - | source'
elif [ "$DETECTED_SHELL" = "bash" ] || [ "$DETECTED_SHELL" = "sh" ] || [ "$DETECTED_SHELL" = "dash" ] || [ "$DETECTED_SHELL" = "ksh" ]; then
  printf 'Configuring bash/sh\n'
  profile_to_use="$BASH_PROFILE"
  if [ ! -f "$profile_to_use" ] && [ -f "$USER_HOME/.profile" ]; then profile_to_use="$USER_HOME/.profile"; fi
  _add_if_missing "$profile_to_use" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$profile_to_use" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$profile_to_use" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
  _add_if_missing "$BASH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$BASH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
  _add_if_missing "$BASH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
elif [ "$DETECTED_SHELL" = "zsh" ]; then
  printf 'Configuring zsh\n'
  _add_if_missing "$ZSH_PROFILE" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$ZSH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$ZSH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
  _add_if_missing "$ZSH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$ZSH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
  _add_if_missing "$ZSH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
else
  printf 'Unknown shell, updating .profile\n'
  _add_if_missing "$USER_HOME/.profile" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$USER_HOME/.profile" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$USER_HOME/.profile" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
fi
printf '\nSanitizing environment\n'
if [ -n "${PYENV_ROOT:-}" ]; then
  oldpy="$PYENV_ROOT/bin"
  tmp="$PATH"
  IFS=':'; newp=""; for seg in $tmp; do if [ "$seg" != "$oldpy" ]; then newp="${newp:+$newp:}$seg"; fi; done; unset IFS; PATH="$oldpy${PATH:+:}$newp"
else
  PATH="$PYENV_ROOT/bin${PATH:+:}$PATH"
fi
hash -r 2>/dev/null || true
export PATH
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)" 2>/dev/null || true
eval "$(pyenv init -)" 2>/dev/null || true
[ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ] && eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
clear
printf '\n🎉 pyenv and pyenv-virtualenv setup complete!\n'
