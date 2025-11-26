function _on_exit
    set code $status
    if test $code -ne 0
        printf 'Script exited with error code %d\n' $code >&2
    else
        printf 'Script finished successfully\n'
    end
    if test -t 1
        printf '\nPress Enter to close...'
        read -P '' _dummy
    end
end
trap _on_exit EXIT

clear
printf '=== Engine Installation Script ===\n\n'

if not set -q HOME; or test -z "$HOME"
    if test (id -u) -eq 0
        set -gx USER_HOME /root
    else
        set -gx USER_HOME /home/(whoami)
    end
else 
    set -gx USER_HOME "$HOME"
end

if set -q PYENV_ROOT; and test -n "$PYENV_ROOT"
    set -gx PYENV_ROOT "$PYENV_ROOT"
else
    set -gx PYENV_ROOT "$USER_HOME/.pyenv"
end

set -gx FISH_CFG "$USER_HOME/.config/fish/config.fish"
set -gx BASH_RC "$USER_HOME/.bashrc"
set -gx BASH_PROFILE "$USER_HOME/.bash_profile"
set -gx ZSH_RC "$USER_HOME/.zshrc"
set -gx ZSH_PROFILE "$USER_HOME/.zprofile"

set -l DETECTED_SHELL (basename (string split / $SHELL)[-1])
set -l ARCH (uname -m)

printf 'Detected OS: %s\n' (uname -s)
printf 'Detected architecture: %s\n' $ARCH
printf 'Detected shell: %s\n' $DETECTED_SHELL
printf 'User home: %s\n' $USER_HOME
printf 'Using PYENV_ROOT: %s\n\n' $PYENV_ROOT

set -l OS unknown
set -l PKGS
set -l PM_CMD ""
set -l PM_INSTALL ""

if type -q pacman
    set OS arch
    set PM_CMD pacman
    set PM_INSTALL "sudo pacman -Syu --noconfirm --needed"
    set PKGS base-devel openssl xz tk libffi bzip2 readline sqlite git curl ca-certificates
    if test "$ARCH" = "x86_64"
        set PKGS $PKGS lib32-glibc
    else if test "$ARCH" = "aarch64"
        set PKGS $PKGS arm-none-eabi-gcc
    end
else if type -q apt-get
    set OS debian
    set PM_CMD apt-get
    set PM_INSTALL "sudo apt-get install -y --no-install-recommends"
    set PKGS build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git ca-certificates
    if test "$ARCH" = "x86_64"
        set PKGS $PKGS gcc-multilib
    else if test "$ARCH" = "arm64" -o "$ARCH" = "aarch64"
        set PKGS $PKGS gcc-aarch64-linux-gnu
    end
else if type -q dnf
    set OS fedora
    set PM_CMD dnf
    set PM_INSTALL "sudo dnf install -y"
    set PKGS make gcc zlib-devel bzip2 bzip2-devel openssl-devel readline-devel sqlite-devel libffi-devel xz-devel tk-devel tcl-devel libnsl2-devel git curl ca-certificates
else if type -q yum
    set OS redhat
    set PM_CMD yum
    set PM_INSTALL "sudo yum install -y"
    set PKGS make gcc zlib-devel bzip2 bzip2-devel openssl-devel readline-devel sqlite-devel libffi-devel xz-devel tk-devel tcl-devel git curl ca-certificates
else if type -q zypper
    set OS opensuse
    set PM_CMD zypper
    set PM_INSTALL "sudo zypper install -y"
    set PKGS zlib-devel libffi-devel libopenssl-devel libbz2-devel readline-devel sqlite3-devel xz-devel ncurses-devel tk git curl ca-certificates
else if type -q apk
    set OS alpine
    set PM_CMD apk
    set PM_INSTALL "sudo apk add --no-cache"
    set PKGS build-base zlib-dev bzip2-dev readline-dev sqlite-dev openssl-dev xz-dev libffi-dev ncurses-dev linux-headers git curl ca-certificates
else
    printf 'No known package manager detected; skipping package install\n'
end

if test -n "$PM_CMD"
    printf 'Installing packages with %s\n' $PM_CMD
    printf 'Packages to install: %s\n' (string join ', ' $PKGS)

    switch $PM_CMD
        case apt-get
            printf 'Updating package database...\n'
            sudo apt-get update
        case dnf yum zypper
            printf 'Updating package database...\n'
            eval sudo $PM_CMD makecache
    end
    
    printf 'Installing packages...\n'
    set -l start_time (date +%s)
    
    if eval $PM_INSTALL $PKGS
        set -l end_time (date +%s)
        set -l duration (math "$end_time - $start_time")
        printf 'Package installation completed successfully in %d seconds\n' $duration
    else
        printf 'Package installation failed or requires interaction; continuing\n' >&2
    end
end

if not test -d "$PYENV_ROOT"
    printf 'Cloning pyenv into %s\n' "$PYENV_ROOT"
    if git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
        printf 'Pyenv cloned successfully\n'
    else
        printf 'Direct clone failed, trying mirror...\n'
        if git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
            printf 'Pyenv cloned successfully from mirror\n'
        else
            printf 'Failed to clone pyenv from all sources\n' >&2
            exit 1
        end
    end
end

set -gx PATH "$PYENV_ROOT/bin" $PATH

mkdir -p "$PYENV_ROOT/plugins"
if not test -d "$PYENV_ROOT/plugins/pyenv-virtualenv"
    printf 'Cloning pyenv-virtualenv\n'
    if git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv"
        printf 'Pyenv-virtualenv cloned successfully\n'
    else
        printf 'Failed to clone pyenv-virtualenv, continuing without it\n' >&2
    end
end

for f in "$FISH_CFG" "$BASH_RC" "$BASH_PROFILE" "$ZSH_RC" "$ZSH_PROFILE"
    if test -n "$f" -a "$f" != ""
        set -l d (dirname "$f")
        if test -n "$d" -a "$d" != ""
            mkdir -p "$d" 2>/dev/null; or printf 'Warning: Could not create directory %s\n' "$d" >&2
        end
        if not test -f "$f"
            touch "$f" 2>/dev/null; or printf 'Warning: Could not create file %s\n' "$f" >&2
        end
    end
end

function _add_if_missing -a file pattern line
    if test -z "$file" -o "$file" = ""
        return 1
    end
    
    if test -f "$file"
        if not grep -Fq -- "$pattern" "$file" 2>/dev/null
            printf '%s\n' "$line" >> "$file"
            printf 'Added to %s: %s\n' "$file" "$pattern"
        end
    else
        printf '%s\n' "$line" > "$file"
        printf 'Created %s with: %s\n' "$file" "$pattern"
    end
end

printf '\nConfiguring shell...\n'

set -l fish_config "$USER_HOME/.config/fish/config.fish"

if test "$DETECTED_SHELL" = "fish"
    printf 'Configuring fish shell...\n'
    mkdir -p (dirname "$fish_config")
    touch "$fish_config"
    
    _add_if_missing "$fish_config" 'set -Ux PYENV_ROOT' 'set -Ux PYENV_ROOT $HOME/.pyenv'
    _add_if_missing "$fish_config" 'fish_user_paths $PYENV_ROOT/bin' 'set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths'
    _add_if_missing "$fish_config" 'pyenv init --path' 'status is-login; and pyenv init --path | source'
    _add_if_missing "$fish_config" 'pyenv init -' 'status is-interactive; and pyenv init - | source'
    _add_if_missing "$fish_config" 'pyenv virtualenv-init -' 'status is-interactive; and pyenv virtualenv-init - | source'
else if test "$DETECTED_SHELL" = "bash" -o "$DETECTED_SHELL" = "sh"
    printf 'Configuring bash shell...\n'
    _add_if_missing "$BASH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$BASH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$BASH_PROFILE" 'pyenv init --path' 'eval "$(pyenv init --path)"'
    _add_if_missing "$BASH_RC" 'pyenv init -' 'eval "$(pyenv init -)"'
    _add_if_missing "$BASH_RC" 'pyenv virtualenv-init -' 'eval "$(pyenv virtualenv-init -)"'
else if test "$DETECTED_SHELL" = "zsh"
    printf 'Configuring zsh shell...\n'
    _add_if_missing "$ZSH_RC" 'export PYENV_ROOT' 'export PYENV_ROOT="$HOME/.pyenv"'
    _add_if_missing "$ZSH_RC" 'export PATH="$PYENV_ROOT/bin:$PATH"' 'export PATH="$PYENV_ROOT/bin:$PATH"'
    _add_if_missing "$ZSH_PROFILE" 'pyenv init --path' 'eval "$(pyenv init --path)"'
    _add_if_missing "$ZSH_RC" 'pyenv init -' 'eval "$(pyenv init -)"'
    _add_if_missing "$ZSH_RC" 'pyenv virtualenv-init -' 'eval "$(pyenv virtualenv-init -)"'
end

if type -q pyenv
    if status --is-interactive
        pyenv init - | source >/dev/null 2>/dev/null
        pyenv init --path | source >/dev/null 2>/dev/null
        pyenv virtualenv-init - | source >/dev/null 2>/dev/null
    end
end

clear
printf '=== Python Version Selection ===\n\n'

printf 'Fetching available Python versions...\n'
set -l ALL_VERSIONS (pyenv install --list 2>/dev/null | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | string trim)

if test -z "$ALL_VERSIONS"
    printf 'Could not fetch available Python versions\n' >&2
    printf 'Trying alternative method...\n'
    set ALL_VERSIONS (curl -s https://registry.npmmirror.com/-/binary/python/ | grep -oE '3\.[0-9]+\.[0-9]+/' | grep -oE '3\.[0-9]+\.[0-9]+' | sort -Vr | head -20)
end

if test -z "$ALL_VERSIONS"
    printf 'Error: Could not retrieve Python version list\n' >&2
    exit 1
end

set -l MAJOR_VERSIONS (printf '%s\n' $ALL_VERSIONS | awk -F. '
$1 == "3" && $2 >= 10 {
    major_minor = $1 "." $2
    if (!(major_minor in latest) || $3 > latest[major_minor]) {
        latest[major_minor] = $3
        versions[major_minor] = $0
    }
}
END {
    for (mm in versions) {
        print versions[mm]
    }
}' | sort -Vr)

set -l LATEST (printf '%s\n' $MAJOR_VERSIONS | head -1)

printf 'Latest versions of each Python major release (3.10+):\n'
printf '┌─────────────┬────────────┐\n'
printf '│ Version     │ Status     │\n'
printf '├─────────────┼────────────┤\n'

set -l version_list $MAJOR_VERSIONS
for v in $version_list
    if pyenv versions --bare 2>/dev/null | grep -Fxq $v >/dev/null 2>/dev/null
        printf '│ %-11s │ %-10s │\n' $v "INSTALLED"
    else
        printf '│ %-11s │ %-10s │\n' $v "Available"
    end
end
printf '└─────────────┴────────────┘\n'

printf '\nCurrently installed versions:\n'
pyenv versions 2>/dev/null || printf '  No versions installed yet\n'

printf '\n=== Version Selection ===\n'
printf 'Latest version: \033[1;32m%s\033[0m\n' $LATEST
printf '\nPlease enter the Python version you want to install\n'
printf 'Press Enter to use latest (\033[1;32m%s\033[0m) or type another version: ' $LATEST

set -l SELECTED_VERSION ""
set -l input_line ""
while read -p "echo '> '" -l input_line
    if test -n "$input_line"
        set SELECTED_VERSION "$input_line"
        break
    else
        set SELECTED_VERSION "$LATEST"
        break
    end
end

if test -z "$SELECTED_VERSION"
    set SELECTED_VERSION "$LATEST"
end

if not string match -q -r '^3\.[0-9]+\.[0-9]+$' "$SELECTED_VERSION"
    printf '\nInvalid version format. Please use format: 3.x.x\n' >&2
    printf 'Using latest version instead: \033[1;32m%s\033[0m\n' $LATEST
    set SELECTED_VERSION $LATEST
else if not contains "$SELECTED_VERSION" $ALL_VERSIONS
    printf '\nVersion %s not found in available versions.\n' "$SELECTED_VERSION" >&2
    printf 'Using latest version instead: \033[1;32m%s\033[0m\n' $LATEST
    set SELECTED_VERSION $LATEST
else
    printf '\nSelected version: \033[1;32m%s\033[0m\n' "$SELECTED_VERSION"
end

clear
printf '=== Installing Python %s ===\n\n' "$SELECTED_VERSION"

if pyenv versions --bare 2>/dev/null | grep -Fxq "$SELECTED_VERSION" >/dev/null 2>/dev/null
    printf 'Python %s already installed, skipping installation\n' "$SELECTED_VERSION"
else
    printf 'Installing Python %s (this may take several minutes)...\n' "$SELECTED_VERSION"
    set -l install_start (date +%s)
    
    if pyenv install "$SELECTED_VERSION"
        set -l install_end (date +%s)
        set -l install_duration (math "$install_end - $install_start")
        printf '✅ Python %s installed successfully in %d seconds\n' "$SELECTED_VERSION" $install_duration
    else
        printf '❌ Python %s installation failed\n' "$SELECTED_VERSION" >&2
        printf 'Continuing with existing installations...\n'
    end
end

printf 'Setting Python %s as global default...\n' "$SELECTED_VERSION"
pyenv global "$SELECTED_VERSION" >/dev/null 2>/dev/null

clear
printf '=== Installation Complete ===\n\n'

printf 'Active python: \033[1;32m%s\033[0m\n' (python --version 2>&1)
printf 'Python location: %s\n' (which python)
printf 'pip location: %s\n' (which pip)

printf '\nInstalled Python versions:\n'
pyenv versions

printf '\n=== Usage Examples for Python %s ===\n' "$SELECTED_VERSION"
printf '  📋 List available versions: pyenv install --list | grep -E "^\\\\s*3\\\\.[0-9]+\\\\.[0-9]+$"\n'
printf '  ⬇️  Install specific version: pyenv install 3.x.x\n'
printf '  🌍 Set global version: pyenv global %s\n' "$SELECTED_VERSION"
printf '  📁 Set local version: pyenv local %s\n' "$SELECTED_VERSION"
printf '  🏗️  Create virtualenv: pyenv virtualenv %s my-project-env\n' "$SELECTED_VERSION"
printf '  🔌 Activate virtualenv: pyenv activate my-project-env\n'
printf '  🔌 Deactivate virtualenv: pyenv deactivate\n'
printf '  📋 List virtualenvs: pyenv virtualenvs\n'

printf '\n=== Important Notes ===\n'
printf '• 💡 To use pyenv in new terminal sessions, restart your terminal or run:\n'
printf '    exec %s -l\n' $DETECTED_SHELL
printf '• 📁 Project-specific Python: create .python-version file in project directory\n'
printf '• 🏗️  Virtual environments isolate Python environments for different projects\n'
printf '• 🔧 System architecture: %s (%s)\n' $ARCH (uname -s)
printf '• 📦 Package manager: %s\n' (test -n "$PM_CMD"; and echo $PM_CMD; or echo "None detected")

printf '\n🎉 Installation completed successfully!\n'
printf '   Thank you for using the PyEnv installer! 🐍\n'