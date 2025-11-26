#!/usr/bin/env bash
trap_exit(){ code="$1"; if [ "${code:-0}" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n'; fi; if [ -t 1 ]; then printf '\nPress Enter to close...'; read -r _dummy; fi; exit "$code"; }
trap 'rc=$?; trap_exit "$rc"' EXIT
clear
printf '=== Engine Installation Script for macOS ===\n\n'
if [ -z "${HOME:-}" ]; then USER_HOME="/Users/$(whoami)"; else USER_HOME="$HOME"; fi
if [ -n "${PYENV_ROOT:-}" ]; then PYENV_ROOT="$PYENV_ROOT"; else PYENV_ROOT="$USER_HOME/.pyenv"; fi
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
  if [ "$ARCH" = "arm64" ]; then printf 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$USER_HOME/.zprofile"; eval "$(/opt/homebrew/bin/brew shellenv)"; else printf 'eval "$(/usr/local/bin/brew shellenv)"' >> "$USER_HOME/.zprofile"; eval "$(/usr/local/bin/brew shellenv)"; fi
else printf 'Homebrew already installed.\n'; fi
printf '\nUpdating Homebrew and installing required packages...\n'
brew update >/dev/null 2>&1 || true; brew upgrade >/dev/null 2>&1 || true
BREW_PACKAGES="openssl readline sqlite3 xz zlib tcl-tk libffi curl git"
printf 'Installing packages with Homebrew: %s\n' "$BREW_PACKAGES"
start_time=$(date +%s)
if brew install $BREW_PACKAGES; then end_time=$(date +%s); duration=$((end_time-start_time)); printf 'Package installation completed in %d seconds\n' "$duration"; else printf 'Package installation failed; continuing\n' >&2; fi
if [ "$ARCH" = "arm64" ]; then
  LDFLAGS="-L/usr/local/opt/openssl/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/sqlite/lib -L/usr/local/opt/zlib/lib -L/usr/local/opt/tcl-tk/lib -L/opt/homebrew/opt/openssl/lib -L/opt/homebrew/opt/readline/lib -L/opt/homebrew/opt/sqlite/lib -L/opt/homebrew/opt/zlib/lib -L/opt/homebrew/opt/tcl-tk/lib"
  CPPFLAGS="-I/usr/local/opt/openssl/include -I/usr/local/opt/readline/include -I/usr/local/opt/sqlite/include -I/usr/local/opt/zlib/include -I/usr/local/opt/tcl-tk/include -I/opt/homebrew/opt/openssl/include -I/opt/homebrew/opt/readline/include -I/opt/homebrew/opt/sqlite/include -I/opt/homebrew/opt/zlib/include -I/opt/homebrew/opt/tcl-tk/include"
  PKG_CONFIG_PATH="/opt/homebrew/opt/openssl/lib/pkgconfig:/opt/homebrew/opt/readline/lib/pkgconfig:/opt/homebrew/opt/sqlite/lib/pkgconfig:/opt/homebrew/opt/zlib/lib/pkgconfig:/opt/homebrew/opt/tcl-tk/lib/pkgconfig:/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH"
else
  LDFLAGS="-L/usr/local/opt/openssl/lib -L/usr/local/opt/readline/lib -L/usr/local/opt/sqlite/lib -L/usr/local/opt/zlib/lib -L/usr/local/opt/tcl-tk/lib"
  CPPFLAGS="-I/usr/local/opt/openssl/include -I/usr/local/opt/readline/include -I/usr/local/opt/sqlite/include -I/usr/local/opt/zlib/include -I/usr/local/opt/tcl-tk/include"
  PKG_CONFIG_PATH="/usr/local/opt/openssl/lib/pkgconfig:/usr/local/opt/readline/lib/pkgconfig:/usr/local/opt/sqlite/lib/pkgconfig:/usr/local/opt/zlib/lib/pkgconfig:/usr/local/opt/tcl-tk/lib/pkgconfig:$PKG_CONFIG_PATH"
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
printf '=== Python Version Selection ===\n\n'
printf 'Fetching available Python versions...\n'
ALL_VERSIONS="$(pyenv install --list 2>/dev/null | grep -E '^[[:space:]]*3\.[0-9]+\.[0-9]+$' | sed 's/^[[:space:]]*//')"
if [ -z "$ALL_VERSIONS" ]; then printf 'Could not fetch available Python versions\nTrying alternative method...\n'; ALL_VERSIONS="$(curl -s https://registry.npmmirror.com/-/binary/python/ | grep -oE '3\.[0-9]+\.[0-9]+/' | grep -oE '3\.[0-9]+\.[0-9]+' | sort -Vr | uniq | head -20)"; fi
[ -n "$ALL_VERSIONS" ] || { printf 'Error: Could not retrieve Python version list\n' >&2; exit 1; }
MAJOR_VERSIONS="$(printf '%s\n' "$ALL_VERSIONS" | awk -F. '$1==3 && $2>=10{mm=$1"."$2; if(!(mm in latest)||$3>latest[mm]){latest[mm]=$3; versions[mm]=$0}} END{for(i in versions) print versions[i]}' | sort -Vr)"
LATEST="$(printf '%s\n' "$MAJOR_VERSIONS" | head -n1)"
printf 'Latest versions of each Python major release (3.10+):\n'; printf '┌─────────────┬────────────┐\n│ Version     │ Status     │\n├─────────────┼────────────┤\n'
printf '%s\n' "$MAJOR_VERSIONS" | while IFS= read -r v; do if pyenv versions --bare 2>/dev/null | grep -Fxq "$v" >/dev/null 2>&1; then printf '│ %-11s │ %-10s │\n' "$v" "INSTALLED"; else printf '│ %-11s │ %-10s │\n' "$v" "Available"; fi; done
printf '└─────────────┴────────────┘\n\nCurrently installed versions:\n'; pyenv versions 2>/dev/null || printf '  No versions installed yet\n'
printf '\n=== Version Selection ===\n'; printf 'Latest version: \033[1;32m%s\033[0m\n\n' "$LATEST"
printf 'Please enter the Python version you want to install\nPress Enter to use latest (\033[1;32m%s\033[0m) or type another version: ' "$LATEST"
read -r input_line
if [ -n "$input_line" ]; then SELECTED_VERSION="$input_line"; else SELECTED_VERSION="$LATEST"; fi
if ! printf '%s\n' "$SELECTED_VERSION" | grep -Eq '^3\.[0-9]+\.[0-9]+$'; then printf '\nInvalid version format. Using latest: \033[1;32m%s\033[0m\n' "$LATEST"; SELECTED_VERSION="$LATEST"; elif ! printf '%s\n' "$ALL_VERSIONS" | grep -Fxq "$SELECTED_VERSION"; then printf '\nVersion %s not found. Using latest: \033[1;32m%s\033[0m\n' "$SELECTED_VERSION" "$LATEST"; SELECTED_VERSION="$LATEST"; else printf '\nSelected version: \033[1;32m%s\033[0m\n' "$SELECTED_VERSION"; fi
clear
printf '=== Installing Python %s ===\n\n' "$SELECTED_VERSION"
if pyenv versions --bare 2>/dev/null | grep -Fxq "$SELECTED_VERSION" >/dev/null 2>&1; then printf 'Python %s already installed, skipping\n' "$SELECTED_VERSION"; else printf 'Installing Python %s (this may take several minutes)...\n' "$SELECTED_VERSION"; install_start=$(date +%s); if pyenv install "$SELECTED_VERSION"; then install_end=$(date +%s); printf '✅ Python %s installed in %d seconds\n' "$SELECTED_VERSION" $((install_end-install_start)); else printf '❌ Python %s installation failed\n' "$SELECTED_VERSION" >&2; printf 'Continuing...\n'; fi; fi
printf 'Setting Python %s as global default...\n' "$SELECTED_VERSION"; pyenv global "$SELECTED_VERSION" >/dev/null 2>&1 || true
clear
printf '=== Installation Complete ===\n\n'; printf 'Active python: \033[1;32m%s\033[0m\n' "$(python --version 2>&1)"; printf 'Python location: %s\n' "$(command -v python || echo 'Not found')"; printf 'pip location: %s\n' "$(command -v pip || echo 'Not found')"
printf '\nInstalled Python versions:\n'; pyenv versions
printf '\n=== Usage Examples for Python %s ===\n' "$SELECTED_VERSION"
printf '  pyenv install --list | grep -E \"^\\\\s*3\\\\.[0-9]+\\\\.[0-9]+$\"\n  pyenv install 3.x.x\n  pyenv global %s\n  pyenv local %s\n  pyenv virtualenv %s my-project-env\n  pyenv activate my-project-env\n  pyenv deactivate\n  pyenv virtualenvs\n' "$SELECTED_VERSION" "$SELECTED_VERSION" "$SELECTED_VERSION"
printf '\n=== Important Notes for macOS ===\n'; printf '• To use pyenv in new sessions, restart or run: exec %s -l\n' "$DETECTED_SHELL"; printf '• System architecture: %s (macOS %s)\n' "$ARCH" "$MACOS_VERSION"; printf '• Package manager: Homebrew\n\n'; printf '🎉 pyenv+cpython installation completed successfully!\n    for macOS! 🐍\n'
