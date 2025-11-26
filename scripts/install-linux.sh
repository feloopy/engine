#!/usr/bin/env bash
printf '=== pyenv Installation Script for Linux ===\n\n'
trap_exit(){ code=$1
if [ "$code" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n'; fi
if [ -t 1 ]; then printf '\nPress Enter to close...'; read -r _dummy; fi
exit "$code"
}
trap 'trap_exit $?' EXIT
clear
if [ -z "${HOME:-}" ]; then
  if [ "$(id -u)" -eq 0 ]; then USER_HOME=/root; else USER_HOME="/home/$(whoami)"; fi
else USER_HOME="$HOME"
fi
if [ -n "${PYENV_ROOT:-}" ]; then PYENV_ROOT="$PYENV_ROOT"; else PYENV_ROOT="$USER_HOME/.pyenv"; fi
FISH_CFG="$USER_HOME/.config/fish/config.fish"; BASH_RC="$USER_HOME/.bashrc"; BASH_PROFILE="$USER_HOME/.bash_profile"; ZSH_RC="$USER_HOME/.zshrc"; ZSH_PROFILE="$USER_HOME/.zprofile"
DETECTED_SHELL="$(basename "${SHELL:-}")"
if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= | awk -F/ '{print $NF}')" ; fi
ARCH="$(uname -m)"
printf 'Detected OS: %s\n' "$(uname -s)"; printf 'Detected architecture: %s\n' "$ARCH"; printf 'Detected shell: %s\n' "$DETECTED_SHELL"; printf 'User home: %s\n' "$USER_HOME"; printf 'Using PYENV_ROOT: %s\n\n' "$PYENV_ROOT"
OS="unknown"; PKGS=(); PM_CMD=""; PM_INSTALL=""
if command -v pacman >/dev/null 2>&1; then
  OS=arch; PM_CMD=pacman; PM_INSTALL='sudo pacman -Syu --noconfirm --needed'; PKGS=(base-devel openssl xz tk libffi bzip2 readline sqlite git curl ca-certificates)
  if [ "$ARCH" = "x86_64" ]; then PKGS+=(lib32-glibc); elif [ "$ARCH" = "aarch64" ]; then PKGS+=(arm-none-eabi-gcc); fi
elif command -v apt-get >/dev/null 2>&1; then
  OS=debian; PM_CMD=apt-get; PM_INSTALL='sudo apt-get install -y --no-install-recommends'; PKGS=(build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git ca-certificates)
  if [ "$ARCH" = "x86_64" ]; then PKGS+=(gcc-multilib); elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then PKGS+=(gcc-aarch64-linux-gnu); fi
elif command -v dnf >/dev/null 2>&1; then
  OS=fedora; PM_CMD=dnf; PM_INSTALL='sudo dnf install -y'; PKGS=(make gcc zlib-devel bzip2 bzip2-devel openssl-devel readline-devel sqlite-devel libffi-devel xz-devel tk-devel tcl-devel libnsl2-devel git curl ca-certificates)
elif command -v yum >/dev/null 2>&1; then
  OS=redhat; PM_CMD=yum; PM_INSTALL='sudo yum install -y'; PKGS=(make gcc zlib-devel bzip2 bzip2-devel openssl-devel readline-devel sqlite-devel libffi-devel xz-devel tk-devel tcl-devel git curl ca-certificates)
elif command -v zypper >/dev/null 2>&1; then
  OS=opensuse; PM_CMD=zypper; PM_INSTALL='sudo zypper install -y'; PKGS=(zlib-devel libffi-devel libopenssl-devel libbz2-devel readline-devel sqlite3-devel xz-devel ncurses-devel tk git curl ca-certificates)
elif command -v apk >/dev/null 2>&1; then
  OS=alpine; PM_CMD=apk; PM_INSTALL='sudo apk add --no-cache'; PKGS=(build-base zlib-dev bzip2-dev readline-dev sqlite-dev openssl-dev xz-dev libffi-dev ncurses-dev linux-headers git curl ca-certificates)
else
  printf 'No known package manager detected; skipping package install\n'
fi
if [ -n "$PM_CMD" ]; then
  printf 'Installing packages with %s\n' "$PM_CMD"
  printf 'Packages to install: %s\n' "${PKGS[*]}"
  case "$PM_CMD" in
    apt-get) printf 'Updating package database...\n'; sudo apt-get update ;;
    dnf|yum) printf 'Updating package database...\n'; sudo "$PM_CMD" makecache >/dev/null 2>&1 || true ;;
    zypper) printf 'Updating package database...\n'; sudo zypper refresh >/dev/null 2>&1 || true ;;
  esac
  printf 'Installing packages...\n'
  start_time=$(date +%s)
  if eval "$PM_INSTALL ${PKGS[*]}"; then end_time=$(date +%s); duration=$((end_time-start_time)); printf 'Package installation completed successfully in %d seconds\n' "$duration"; else printf 'Package installation failed or requires interaction; continuing\n' >&2; fi
fi
if [ ! -d "$PYENV_ROOT" ]; then
  printf 'Cloning pyenv into %s\n' "$PYENV_ROOT"
  if git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'Pyenv cloned successfully\n'; else
    printf 'Direct clone failed, trying mirror...\n'
    if git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; then printf 'Pyenv cloned successfully from mirror\n'; else printf 'Failed to clone pyenv from all sources\n' >&2; exit 1; fi
  fi
fi
export PATH="$PYENV_ROOT/bin:$PATH"
mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then
  printf 'Cloning pyenv-virtualenv\n'
  if git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"; then printf 'Pyenv-virtualenv cloned successfully\n'; else printf 'Failed to clone pyenv-virtualenv, continuing without it\n' >&2; fi
fi
files=("$FISH_CFG" "$BASH_RC" "$BASH_PROFILE" "$ZSH_RC" "$ZSH_PROFILE")
for f in "${files[@]}"; do
  if [ -n "$f" ]; then d=$(dirname "$f"); if [ -n "$d" ]; then mkdir -p "$d" 2>/dev/null || printf 'Warning: Could not create directory %s\n' "$d" >&2; fi; if [ ! -f "$f" ]; then touch "$f" 2>/dev/null || printf 'Warning: Could not create file %s\n' "$f" >&2; fi; fi
done
_add_if_missing(){ file="$1"; pattern="$2"; line="$3"; if [ -z "$file" ]; then return 1; fi; if [ -f "$file" ]; then if ! grep -Fq -- "$pattern" "$file" 2>/dev/null; then printf '%s\n' "$line" >> "$file"; printf 'Added to %s: %s\n' "$file" "$pattern"; fi else printf '%s\n' "$line" > "$file"; printf 'Created %s with: %s\n' "$file" "$pattern"; fi }
printf '\nConfiguring shell...\n'
fish_config="$USER_HOME/.config/fish/config.fish"
if [ "$DETECTED_SHELL" = "fish" ]; then
  printf 'Configuring fish shell...\n'
  mkdir -p "$(dirname "$fish_config")"
  touch "$fish_config"
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
  if [[ $- == *i* ]]; then pyenv init - | source >/dev/null 2>&1; pyenv init --path | source >/dev/null 2>&1; { command -v pyenv-virtualenv >/dev/null 2>&1 && pyenv virtualenv-init - | source >/dev/null 2>&1; } || true; fi
fi
clear
printf '\n🎉 pyenv installed successfully!'
