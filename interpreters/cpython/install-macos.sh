#!/usr/bin/env bash
set -euo pipefail
trap_exit(){ code="$1"; if [ "${code:-0}" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n' >&2; fi; cleanup; if IsInteractive; then printf '\nPress Enter to close...'; read -r _dummy; fi; exit "$code"; }
trap 'rc=$?; trap_exit "$rc"' EXIT

cleanup(){ [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR:-}" ] && rm -rf "$TMPDIR" || true; }

IsInteractive(){ if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${GITLAB_CI:-}" ]; then return 1; fi; [ -t 1 ] || return 1; case "${TERM:-}" in dumb|unknown|'') return 1;; esac; return 0; }

USER_HOME="${HOME:-/Users/$(whoami)}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
FISH_CFG="$XDG_CONFIG_HOME/fish/config.fish"
BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; PROFILE="$USER_HOME/.profile"
ZSH_RC="${ZDOTDIR:-$USER_HOME}/.zshrc"; ZSH_PROFILE="${ZDOTDIR:-$USER_HOME}/.zprofile"
DETECTED_SHELL=""
[ -n "${SHELL:-}" ] && DETECTED_SHELL="$(basename "$SHELL")"
[ -z "$DETECTED_SHELL" ] && [ -r "/proc/$$/cmdline" ] && DETECTED_SHELL="$(tr '\0' ' ' < /proc/$$/cmdline | awk '{print $1}' | awk -F/ '{print $NF}')"
[ -z "$DETECTED_SHELL" ] && DETECTED_SHELL="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' || true)"
DETECTED_SHELL="$(echo "${DETECTED_SHELL:-}" | tr '[:upper:]' '[:lower:]')"

ARCH="$(uname -m)"; MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
printf 'OS version: %s\narch: %s\nshell: %s\nhome: %s\nPYENV_ROOT: %s\n\n' "$MACOS_VERSION" "$ARCH" "$DETECTED_SHELL" "$USER_HOME" "$PYENV_ROOT"

printf 'Checking for Command Line Tools\n'
if ! xcode-select -p >/dev/null 2>&1; then
  if IsInteractive; then
    printf 'Installing Command Line Tools interactively\n'
    xcode-select --install 2>/dev/null || true
    while ! xcode-select -p >/dev/null 2>&1; do printf '.'; sleep 2; done
    printf '\nCommand Line Tools installed\n\n'
  else
    printf 'Attempting noninteractive Command Line Tools install\n'
    TMPFILE="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    sudo mkdir -p /tmp >/dev/null 2>&1 || true
    sudo /bin/sh -c "touch $TMPFILE" >/dev/null 2>&1 || touch "$TMPFILE"
    PROD="$(softwareupdate -l 2>/dev/null | awk -F'*' '/Command Line Tools/ {print $2; exit}' | sed -e 's/^ *//' -e 's/ *$//')"
    if [ -n "$PROD" ]; then
      softwareupdate -i "$PROD" --verbose || printf 'softwareupdate install failed, proceed if CLT installed\n' >&2
    else
      printf 'No Command Line Tools candidate found via softwareupdate. If build tools are missing install them manually.\n' >&2
    fi
    sudo /bin/sh -c "rm -f $TMPFILE" >/dev/null 2>&1 || rm -f "$TMPFILE"
  fi
else
  printf 'Build tools present\n\n'
fi

printf 'Checking for Homebrew\n'
BREW_BIN="$(command -v brew 2>/dev/null || true)"
if [ -z "$BREW_BIN" ]; then
  if [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; fi
  if [ -z "$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; fi
fi
if [ -z "$BREW_BIN" ]; then
  printf 'Installing Homebrew noninteractive\n'
  export NONINTERACTIVE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_EMOJI=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || printf 'Homebrew install script failed\n' >&2
  if [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -z "$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; eval "$(/usr/local/bin/brew shellenv)"; fi
  BREW_BIN="$(command -v brew 2>/dev/null || true)"
  if [ -n "$BREW_BIN" ]; then printf 'eval "$(%s shellenv)" >> %s/.zprofile\n' "$BREW_BIN" "$USER_HOME"; fi
else
  printf 'Homebrew present: %s\n' "$BREW_BIN"
fi

if command -v brew >/dev/null 2>&1; then
  export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_EMOJI=1 CI="${CI:-1}"
  brew update || printf 'brew update failed, continuing\n' >&2
  brew upgrade || printf 'brew upgrade failed, continuing\n' >&2
fi

TMPDIR="$(mktemp -d)"
CAVEAT_FILE="$TMPDIR/brew_caveats.txt"
BREW_PACKAGES=(openssl readline sqlite3 xz zlib tcl-tk libffi curl git)
printf 'Installing Homebrew packages: %s\n' "${BREW_PACKAGES[*]}"

run_with_spinner(){
  label="$1"; shift; logfile="$TMPDIR/${label//[^a-zA-Z0-9]/_}.log"
  if IsInteractive; then
    printf '%s: starting\n' "$label"
    ( "$@" >"$logfile" 2>&1 ) &
    pid=$! spinner='|/-\' i=0 start_ts=$(date +%s)
    while kill -0 "$pid" 2>/dev/null; do i=$(( (i+1) % 4 )); printf '\r[%s] %s ...' "${spinner:i:1}" "$label"; sleep 0.12; done
    wait "$pid"; rc=$?; printf '\r'
    if [ $rc -ne 0 ]; then printf '%s: failed (exit %d)\n' "$label" "$rc" >&2; tail -n 200 "$logfile" >&2 || true
    else printf '%s: done\n' "$label"; if grep -qE '(^==>|^Caveats:|keg-only|Warning:|Caveats)' "$logfile" 2>/dev/null; then printf '%s: has caveats\n' "$label" >> "$CAVEAT_FILE"; fi
  else
    printf '%s: installing (noninteractive)\n' "$label"
    if "$@" >"$logfile" 2>&1; then printf '%s: installed\n' "$label"; if grep -qE '(^==>|^Caveats:|keg-only|Warning:|Caveats)' "$logfile" 2>/dev/null; then printf '%s: has caveats\n' "$label" >> "$CAVEAT_FILE"; fi
    else rc=$?; printf '%s: failed (exit %d). See log: %s\n' "$label" "$rc" "$logfile" >&2; fi
  fi
}

for pkg in "${BREW_PACKAGES[@]}"; do
  if command -v brew >/dev/null 2>&1 && brew list --formula "$pkg" >/dev/null 2>&1; then printf 'Already installed: %s\n' "$pkg"
  else
    if command -v brew >/dev/null 2>&1; then run_with_spinner "$pkg" brew install "$pkg" || true; fi
  fi
done

LDFLAGS=""; CPPFLAGS=""; PKG_CONFIG_PATH=""
for pkg in openssl readline sqlite3 zlib tcl-tk libffi; do prefix="$(brew --prefix "$pkg" 2>/dev/null || true)"; [ -n "$prefix" ] && { LDFLAGS="$LDFLAGS -L$prefix/lib"; CPPFLAGS="$CPPFLAGS -I$prefix/include"; PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$prefix/lib/pkgconfig"; }
done
export LDFLAGS CPPFLAGS PKG_CONFIG_PATH

mkdir -p "$PYENV_ROOT/plugins"
clone_with_retries(){ url="$1"; dest="$2"; tries="${3:-3}"; i=0; while [ $i -lt "$tries" ]; do git clone --depth 1 "$url" "$dest" 2>/dev/null && return 0; i=$((i+1)); sleep $((i*2)); rm -rf "$dest"; done; return 1; }

if [ ! -d "$PYENV_ROOT" ] || [ ! -x "$PYENV_ROOT/bin/pyenv" ]; then
  rm -rf "$PYENV_ROOT"
  clone_with_retries "https://github.com/pyenv/pyenv.git" "$PYENV_ROOT" 3 || clone_with_retries "https://ghproxy.com/https://github.com/pyenv/pyenv.git" "$PYENV_ROOT" 3 || printf 'pyenv clone failed, continuing\n' >&2
fi

export PATH="$PYENV_ROOT/bin:$PATH"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
  clone_with_retries "https://github.com/pyenv/pyenv-virtualenv.git" "$PYENV_ROOT/plugins/pyenv-virtualenv" 3 || printf 'pyenv-virtualenv clone failed, continuing\n' >&2
fi

_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; [ -z "$file" ] && return 1; mkdir -p "$(dirname "$file")"; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; fi; else printf '%s\n' "$line" > "$file"; fi }

case "$DETECTED_SHELL" in
  *fish*) mkdir -p "$(dirname "$FISH_CFG")"; _add_if_missing "$FISH_CFG" 'set -Ux PYENV_ROOT $HOME/.pyenv' 'set -Ux PYENV_ROOT $HOME/.pyenv'; _add_if_missing "$FISH_CFG" 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'; _add_if_missing "$FISH_CFG" 'status --is-login; and source (pyenv init --path | psub)' 'status --is-login; and source (pyenv init --path | psub)'; _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv init - | psub)' 'status --is-interactive; and source (pyenv init - | psub)'; _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv virtualenv-init - | psub)' 'status --is-interactive; and source (pyenv virtualenv-init - | psub)';;
  *zsh*) _add_if_missing "$ZSH_PROFILE" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'; _add_if_missing "$ZSH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'; _add_if_missing "$ZSH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'; _add_if_missing "$ZSH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'; _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'; _add_if_missing "$ZSH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'; _add_if_missing "$ZSH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"';;
  *bash*|*ksh*|*sh*|*dash*) [ ! -f "$BASH_PROFILE" ] && [ -f "$PROFILE" ] && BASH_PROFILE="$PROFILE"; _add_if_missing "$BASH_PROFILE" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'; _add_if_missing "$BASH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'; _add_if_missing "$BASH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'; _add_if_missing "$BASH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'; _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'; _add_if_missing "$BASH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'; _add_if_missing "$BASH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"';;
  *) _add_if_missing "$USER_HOME/.profile" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'; _add_if_missing "$USER_HOME/.profile" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'; _add_if_missing "$USER_HOME/.profile" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"';;
esac

if [ -n "${PYENV_ROOT:-}" ]; then oldpy="$PYENV_ROOT/bin"; tmp="$PATH"; IFS=':'; newp=""; for seg in $tmp; do [ "$seg" != "$oldpy" ] && newp="${newp:+$newp:}$seg"; done; unset IFS; PATH="$oldpy${PATH:+:}$newp"; else PATH="$PYENV_ROOT/bin${PATH:+:}$PATH"; fi
hash -r 2>/dev/null || true
export PATH="$PYENV_ROOT/bin:$PATH"

if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
  set +e
  eval "$("$PYENV_ROOT/bin/pyenv" init --path)" 2>/dev/null || true
  eval "$("$PYENV_ROOT/bin/pyenv" init -)" 2>/dev/null || true
  if [ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ] && [ -x "$PYENV_ROOT/bin/pyenv" ] 2>/dev/null; then eval "$("$PYENV_ROOT/bin/pyenv" virtualenv-init -)" 2>/dev/null || true; fi
  set -e
else
  if command -v pyenv >/dev/null 2>&1; then EXISTING="$(command -v pyenv)"; export PATH="$(dirname "$EXISTING"):$PATH"; printf 'Using existing pyenv from %s\n' "$EXISTING"
  else printf 'Warning: pyenv binary not found at %s. The clone may have failed or permissions prevent execution.\n' "$PYENV_ROOT/bin/pyenv" >&2; fi
fi

wait 2>/dev/null || true
sync || true
sleep 0.1

if [ -f "$CAVEAT_FILE" ] && [ -s "$CAVEAT_FILE" ]; then
  if IsInteractive; then printf '\nBrew caveats summary:\n'; sed -n '1,200p' "$CAVEAT_FILE"; printf '\n'; else printf '\nSome brew packages reported caveats. Run interactively to see details or inspect logs in: %s\n' "$TMPDIR" >&2; fi
fi

printf '🎉 pyenv and pyenv-virtualenv setup complete!\n' >&2

if [ -x "$PYENV_ROOT/bin/pyenv" ]; then "$PYENV_ROOT/bin/pyenv" --version || true; "$PYENV_ROOT/bin/pyenv" root || true
else command -v pyenv >/dev/null 2>&1 && pyenv --version || printf 'pyenv not available in this shell\n'; fi
