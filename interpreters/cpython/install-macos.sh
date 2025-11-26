#!/usr/bin/env bash
trap_exit(){ code="$1"; if [ "${code:-0}" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n' >&2; fi; if IsInteractive; then printf '\nPress Enter to close...'; read -r _dummy; fi; cleanup; exit "$code"; }
trap 'rc=$?; trap_exit "$rc"' EXIT
set -euo pipefail

cleanup(){ if [ -n "${TMPDIR:-}" ] && [ -d "${TMPDIR:-}" ]; then rm -rf "$TMPDIR" || true; fi; }

IsInteractive(){ if [ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${CI:-}" ]; then return 1; fi; if [ ! -t 1 ]; then return 1; fi; case "${TERM:-}" in dumb|unknown|'') return 1;; esac; return 0; }

USER_HOME="${HOME:-/Users/$(whoami)}"
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"
FISH_CFG="$XDG_CONFIG_HOME/fish/config.fish"; BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; ZSH_RC="${ZDOTDIR:-$USER_HOME}/.zshrc"; ZSH_PROFILE="${ZDOTDIR:-$USER_HOME}/.zprofile"

DETECTED_SHELL=""; if [ -n "${SHELL:-}" ]; then DETECTED_SHELL="$(basename "$SHELL")"; fi
if [ -z "$DETECTED_SHELL" ] && [ -r "/proc/$$/cmdline" ]; then DETECTED_SHELL="$(tr '\0' ' ' < /proc/$$/cmdline | awk '{print $1}' | awk -F/ '{print $NF}')"; fi
if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= 2>/dev/null | awk -F/ '{print $NF}' || true)"; fi
DETECTED_SHELL="$(echo "${DETECTED_SHELL:-}" | tr '[:upper:]' '[:lower:]')"

ARCH="$(uname -m)"; MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
printf 'OS version: %s\narch: %s\nshell: %s\nhome: %s\nPYENV_ROOT: %s\n\n' "$MACOS_VERSION" "$ARCH" "$DETECTED_SHELL" "$USER_HOME" "$PYENV_ROOT"

printf 'Checking for build tools\n'
if ! xcode-select -p >/dev/null 2>&1; then
  if [ -n "${CI:-}" ] || [ ! -t 1 ]; then
    printf 'Command Line Tools not present but running non-interactive. Skipping auto-install. Install CLT manually or run interactively.\n\n'
  else
    printf 'Installing Command Line Tools (interactive)\n'
    xcode-select --install 2>/dev/null || true
    while ! xcode-select -p >/dev/null 2>&1; do printf '.'; sleep 2; done
    printf '\nCommand Line Tools installed\n\n'
  fi
else printf 'Build tools present\n\n'; fi

printf 'Checking for Homebrew\n'
BREW_BIN="$(command -v brew 2>/dev/null || true)"
if [ -z "$BREW_BIN" ]; then
  if [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; fi
  if [ -z "$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; fi
  if [ -z "$BREW_BIN" ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then BREW_BIN=/home/linuxbrew/.linuxbrew/bin/brew; fi
fi

if [ -z "$BREW_BIN" ]; then
  printf 'Installing Homebrew (noninteractive)\n'
  export NONINTERACTIVE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_EMOJI=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then BREW_BIN=/opt/homebrew/bin/brew; eval "$(/opt/homebrew/bin/brew shellenv)"; fi
  if [ -z "$BREW_BIN" ] && [ -x /usr/local/bin/brew ]; then BREW_BIN=/usr/local/bin/brew; eval "$(/usr/local/bin/brew shellenv)"; fi
  if [ -z "$BREW_BIN" ] && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then BREW_BIN=/home/linuxbrew/.linuxbrew/bin/brew; eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"; fi
  BREW_BIN="$(command -v brew 2>/dev/null || true)"
  [ -n "$BREW_BIN" ] && { printf 'eval "$(%s shellenv)"\n' "$BREW_BIN" >> "$USER_HOME/.zprofile"; }
else
  printf 'Homebrew present\nbrew: %s\n' "$BREW_BIN"
fi

printf '\nUpdating Homebrew and packages\n'
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
  label="$1"; shift
  logfile="$TMPDIR/${label//[^a-zA-Z0-9]/_}.log"
  if IsInteractive; then
    printf '%s: starting\n' "$label"
    ( "$@" >"$logfile" 2>&1 ) &
    pid=$!
    spinner='|/-\'
    i=0; start_ts=$(date +%s)
    while kill -0 "$pid" 2>/dev/null; do
      i=$(( (i+1) % 4 ))
      printf '\r[%s] %s ... %s' "${spinner:i:1}" "$label" "$(date -u -r $(( $(date +%s) - start_ts )) -u +%T 2>/dev/null || printf '')"
      sleep 0.12
    done
    wait "$pid"; rc=$?
    printf '\r'
    if [ $rc -ne 0 ]; then
      printf '%s: failed (exit %d)\n' "$label" "$rc" >&2
      printf 'Last 200 lines of log for %s:\n' "$label" >&2
      tail -n 200 "$logfile" >&2 || true
    else
      printf '%s: done\n' "$label"
      if grep -qE '(^==>|^Caveats:|keg-only|Warning:|Caveats)' "$logfile" 2>/dev/null; then
        printf '%s: has caveats\n' "$label" >> "$CAVEAT_FILE"
      fi
    fi
  else
    printf '%s: installing (noninteractive)\n' "$label"
    if "$@" >"$logfile" 2>&1; then
      printf '%s: installed\n' "$label"
      if grep -qE '(^==>|^Caveats:|keg-only|Warning:|Caveats)' "$logfile" 2>/dev/null; then
        printf '%s: has caveats\n' "$label" >> "$CAVEAT_FILE"
      fi
    else
      rc=$?
      printf '%s: failed (exit %d). See log: %s\n' "$label" "$rc" "$logfile" >&2
    fi
  fi
}

for pkg in "${BREW_PACKAGES[@]}"; do
  if command -v brew >/dev/null 2>&1 && brew list "$pkg" >/dev/null 2>&1; then
    printf 'Already installed: %s\n' "$pkg"
  else
    if command -v brew >/dev/null 2>&1; then
      run_with_spinner "$pkg" brew install "$pkg" || true
    fi
  fi
done

LDFLAGS=""; CPPFLAGS=""; PKG_CONFIG_PATH=""
for pkg in openssl readline sqlite3 zlib tcl-tk libffi; do
  prefix="$(brew --prefix "$pkg" 2>/dev/null || true)"
  [ -n "$prefix" ] && { LDFLAGS="$LDFLAGS -L$prefix/lib"; CPPFLAGS="$CPPFLAGS -I$prefix/include"; PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$prefix/lib/pkgconfig"; }
done
export LDFLAGS CPPFLAGS PKG_CONFIG_PATH

mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT" ]; then
  printf 'Cloning pyenv into %s\n' "$PYENV_ROOT"
  git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" || { printf 'Failed to clone pyenv\n' >&2; exit 1; }
fi

export PATH="$PYENV_ROOT/bin:$PATH"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
  printf 'Cloning pyenv-virtualenv\n'
  git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv" || printf 'pyenv-virtualenv clone failed, continuing\n' >&2
fi

_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; [ -z "$file" ] && return 1; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; printf 'Added to %s: %s\n' "$file" "$pattern"; fi; else printf '%s\n' "$line" > "$file"; printf 'Created %s with: %s\n' "$file" "$pattern"; fi }

printf '\nConfiguring shells\n'
case "$DETECTED_SHELL" in
fish)
  mkdir -p "$(dirname "$FISH_CFG")"; touch "$FISH_CFG"
  _add_if_missing "$FISH_CFG" 'set -Ux PYENV_ROOT $HOME/.pyenv' 'set -Ux PYENV_ROOT $HOME/.pyenv'
  _add_if_missing "$FISH_CFG" 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
  _add_if_missing "$FISH_CFG" 'status --is-login; and source (pyenv init --path | psub)' 'status --is-login; and source (pyenv init --path | psub)'
  _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv init - | psub)' 'status --is-interactive; and source (pyenv init - | psub)'
  _add_if_missing "$FISH_CFG" 'status --is-interactive; and source (pyenv virtualenv-init - | psub)' 'status --is-interactive; and source (pyenv virtualenv-init - | psub)'
  ;;
zsh*)
  _add_if_missing "$ZSH_PROFILE" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$ZSH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$ZSH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
  _add_if_missing "$ZSH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$ZSH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
  _add_if_missing "$ZSH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
  ;;
bash*|sh|dash|ksh)
  [ ! -f "$BASH_PROFILE" ] && [ -f "$USER_HOME/.profile" ] && BASH_PROFILE="$USER_HOME/.profile"
  _add_if_missing "$BASH_PROFILE" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$BASH_PROFILE" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$BASH_PROFILE" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
  _add_if_missing "$BASH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$BASH_RC" 'eval "$(pyenv init -)"' 'eval "$(pyenv init -)"'
  _add_if_missing "$BASH_RC" 'eval "$(pyenv virtualenv-init -)"' 'eval "$(pyenv virtualenv-init -)"'
  ;;
*)
  _add_if_missing "$USER_HOME/.profile" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
  _add_if_missing "$USER_HOME/.profile" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
  _add_if_missing "$USER_HOME/.profile" 'eval "$(pyenv init --path)"' 'eval "$(pyenv init --path)"'
  ;;
esac

printf '\nSanitizing environment\n'
if [ -n "${PYENV_ROOT:-}" ]; then oldpy="$PYENV_ROOT/bin"; tmp="$PATH"; IFS=':'; newp=""; for seg in $tmp; do [ "$seg" != "$oldpy" ] && newp="${newp:+$newp:}$seg"; done; unset IFS; PATH="$oldpy${PATH:+:}$newp"; else PATH="$PYENV_ROOT/bin${PATH:+:}$PATH"; fi
hash -r 2>/dev/null || true
export PATH="$PYENV_ROOT/bin:$PATH"

if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
  eval "$("$PYENV_ROOT/bin/pyenv" init --path)" 2>/dev/null || true
  eval "$("$PYENV_ROOT/bin/pyenv" init -)" 2>/dev/null || true
  [ -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ] && eval "$("$PYENV_ROOT/bin/pyenv" virtualenv-init -)" 2>/dev/null || true
else
  printf 'Warning: pyenv binary not found at %s. The clone may have failed or permissions prevent execution.\n' "$PYENV_ROOT/bin/pyenv" >&2
fi

wait 2>/dev/null || true
sync || true
sleep 0.1

if [ -f "$CAVEAT_FILE" ] && [ -s "$CAVEAT_FILE" ]; then
  if IsInteractive; then
    printf '\nBrew caveats summary:\n'
    sed -n '1,200p' "$CAVEAT_FILE"
    printf '\n'
  else
    printf '\nSome brew packages reported caveats. Run interactively to see details or inspect logs in: %s\n' "$TMPDIR" >&2
  fi
fi

printf '\n############################################\n' >&2
printf '🎉 pyenv and pyenv-virtualenv setup complete!\n' >&2
printf '############################################\n\n' >&2

if [ -x "$PYENV_ROOT/bin/pyenv" ]; then
  "$PYENV_ROOT/bin/pyenv" --version || true
  "$PYENV_ROOT/bin/pyenv" root || true
else
  command -v pyenv >/dev/null 2>&1 && pyenv --version || printf 'pyenv not available in this shell\n'
fi
