#!/usr/bin/env bash
trap_exit(){ code=$1
if [ "$code" -ne 0 ]; then printf 'Script exited with error code %d\n' "$code" >&2; else printf 'Script finished successfully\n'; fi
if [ -t 1 ]; then printf '\nPress Enter to close...'; read -r _dummy; fi
exit "$code"
}
trap 'trap_exit $?' EXIT
clear
printf '=== pyenv Manager CLI ===\n\n'
if [ -z "${HOME:-}" ]; then if [ "$(id -u)" -eq 0 ]; then USER_HOME=/root; else USER_HOME="/home/$(whoami)"; fi; else USER_HOME="$HOME"; fi
PYENV_ROOT="${PYENV_ROOT:-$USER_HOME/.pyenv}"
export PYENV_ROOT
export PATH="$PYENV_ROOT/bin:$PATH"
DETECTED_SHELL="$(basename "${SHELL:-}")"; if [ -z "$DETECTED_SHELL" ]; then DETECTED_SHELL="$(ps -p $$ -o comm= | awk -F/ '{print $NF}')" ; fi
ARCH="$(uname -m)"
printf 'Detected OS: %s\n' "$(uname -s)"; printf 'Arch: %s\n' "$ARCH"; printf 'Shell: %s\n' "$DETECTED_SHELL"; printf 'PYENV_ROOT: %s\n\n' "$PYENV_ROOT"
install_prereqs(){
OS=""
if command -v apt-get >/dev/null 2>&1; then OS=debian; sudo apt-get update; sudo apt-get install -y --no-install-recommends build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev git ca-certificates
elif command -v pacman >/dev/null 2>&1; then OS=arch; sudo pacman -Syu --noconfirm --needed base-devel openssl xz tk libffi bzip2 readline sqlite git curl ca-certificates
elif command -v dnf >/dev/null 2>&1; then OS=fedora; sudo dnf install -y make gcc zlib-devel bzip2 openssl-devel readline-devel sqlite-devel libffi-devel xz-devel tk-devel git curl ca-certificates
elif command -v apk >/dev/null 2>&1; then OS=alpine; sudo apk add --no-cache build-base zlib-dev bzip2-dev readline-dev sqlite-dev openssl-dev xz-dev libffi-dev ncurses-dev git curl ca-certificates
fi
}
bootstrap_pyenv(){
if [ ! -d "$PYENV_ROOT" ]; then git clone --depth 1 https://github.com/pyenv/pyenv.git "$PYENV_ROOT" || git clone --depth 1 https://ghproxy.com/https://github.com/pyenv/pyenv.git "$PYENV_ROOT"; fi
mkdir -p "$PYENV_ROOT/plugins"
if [ ! -d "$PYENV_ROOT/plugins/pyenv-virtualenv" ]; then git clone --depth 1 https://github.com/pyenv/pyenv-virtualenv.git "$PYENV_ROOT/plugins/pyenv-virtualenv" 2>/dev/null || true; fi
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv >/dev/null 2>&1; then true; else if [ -f "$PYENV_ROOT/bin/pyenv" ]; then export PATH="$PYENV_ROOT/bin:$PATH"; fi; fi
}
pyenv_available(){ command -v pyenv >/dev/null 2>&1; }
choose_from_list(){ prompt="$1"; shift; arr=("$@"); if [ ${#arr[@]} -eq 0 ]; then printf 'No options\n'; return 1; fi; printf '%s\n' "$prompt"; for i in "${!arr[@]}"; do printf '  %d) %s\n' $((i+1)) "${arr[$i]}"; done; printf 'Select number: '; read -r sel; if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt ${#arr[@]} ]; then printf 'Invalid\n'; return 1; fi; echo "${arr[$((sel-1))]}"; return 0; }
set_pyenv_root(){ printf 'Current PYENV_ROOT: %s\nEnter new PYENV_ROOT or press Enter to keep: ' "$PYENV_ROOT"; read -r new; if [ -n "$new" ]; then PYENV_ROOT="${new/#\~/$HOME}"; export PYENV_ROOT; export PATH="$PYENV_ROOT/bin:$PATH"; mkdir -p "$PYENV_ROOT"; fi; printf 'PYENV_ROOT=%s\n' "$PYENV_ROOT"; }
list_versions(){ pyenv_available || { printf 'pyenv missing\n'; return; }; pyenv versions || true; }
list_available_versions(){
if pyenv_available; then VERS="$(pyenv install --list 2>/dev/null | grep -E '^[[:space:]]*3\.[0-9]+\.[0-9]+' | sed 's/^[[:space:]]*//' | sort -Vr | uniq)"; fi
if [ -z "$VERS" ]; then VERS="$(curl -s https://registry.npmmirror.com/-/binary/python/ | grep -oE '3\.[0-9]+\.[0-9]+' | sort -Vr | uniq)"; fi
mapfile -t VERS_ARR < <(printf '%s\n' "$VERS")
printf '%s\n' "${VERS_ARR[@]}"
}
install_python(){
pyenv_available || { printf 'pyenv not found, bootstrapping\n'; bootstrap_pyenv; }
mapfile -t VERS < <(list_available_versions)
if [ ${#VERS[@]} -eq 0 ]; then printf 'No versions discovered\n'; return; fi
choice=$(choose_from_list 'Choose Python version to install:' "${VERS[@]}") || return
printf 'Optional: custom PYENV_ROOT for this install or press Enter to skip: '; read -r tmp; if [ -n "$tmp" ]; then export PYENV_ROOT="${tmp/#\~/$HOME}"; export PATH="$PYENV_ROOT/bin:$PATH"; fi
if pyenv versions --bare | grep -Fxq "$choice"; then printf '%s already installed\n' "$choice"; else pyenv install "$choice" || { printf 'install failed\n' >&2; return 1; }; fi
printf 'Set as global? (y/N): '; read -r g; if [ "$g" = "y" ] || [ "$g" = "Y" ]; then pyenv global "$choice"; fi
}
uninstall_python(){
pyenv_available || { printf 'pyenv not found\n'; return; }
mapfile -t INST < <(pyenv versions --bare 2>/dev/null)
if [ ${#INST[@]} -eq 0 ]; then printf 'No installed versions\n'; return; fi
choice=$(choose_from_list 'Choose installed Python to remove:' "${INST[@]}") || return
pyenv uninstall -f "$choice" 2>/dev/null || rm -rf "$PYENV_ROOT/versions/$choice"
printf 'Removed %s\n' "$choice"
}
create_venv(){
pyenv_available || { printf 'pyenv not found\n'; return; }
mapfile -t INST < <(pyenv versions --bare 2>/dev/null)
if [ ${#INST[@]} -eq 0 ]; then printf 'No installed Python versions\n'; return; fi
base=$(choose_from_list 'Choose base Python for virtualenv:' "${INST[@]}") || return
printf 'Enter virtualenv name: '; read -r vname; [ -z "$vname" ] && { printf 'Name required\n'; return; }
printf 'Optional: custom PYENV_ROOT for this operation or press Enter: '; read -r tmp; if [ -n "$tmp" ]; then export PYENV_ROOT="${tmp/#\~/$HOME}"; export PATH="$PYENV_ROOT/bin:$PATH"; fi
if command -v pyenv-virtualenv >/dev/null 2>&1; then pyenv virtualenv "$base" "$vname" && printf 'Created virtualenv %s\n' "$vname" || printf 'Failed\n' >&2; else mkdir -p "$PYENV_ROOT/versions/$vname"; "$PYENV_ROOT/versions/$base/bin/python" -m venv "$PYENV_ROOT/versions/$vname" && printf 'Created venv at %s/versions/%s\n' "$PYENV_ROOT" "$vname"; fi
}
delete_venv(){
pyenv_available || { printf 'pyenv not found\n'; return; }
mapfile -t VENV < <(pyenv virtualenvs --bare 2>/dev/null)
if [ ${#VENV[@]} -eq 0 ]; then printf 'No virtualenvs\n'; return; fi
choice=$(choose_from_list 'Choose virtualenv to delete:' "${VENV[@]}") || return
printf 'Confirm delete %s? (y/N): ' "$choice"; read -r c; if [ "$c" = "y" ] || [ "$c" = "Y" ]; then pyenv virtualenv-delete -f "$choice" 2>/dev/null || rm -rf "$PYENV_ROOT/versions/$choice"; printf 'Deleted %s\n' "$choice"; fi
}
list_venvs(){ pyenv_available || { printf 'pyenv not found\n'; return; }; pyenv virtualenvs || printf 'No virtualenvs\n'; }
show_deps_from_pypi(){
pkg="$1"; ver="$2"
if [ -z "$ver" ]; then url="https://pypi.org/pypi/${pkg}/json"; else url="https://pypi.org/pypi/${pkg}/${ver}/json"; fi
json="$(curl -sS "$url" 2>/dev/null)" || { printf 'Failed fetching metadata\n'; return 1; }
deps="$(python - <<PY
import sys,json
try:
 d=json.load(sys.stdin)
 reqs=d.get('info',{}).get('requires_dist') or []
 for r in reqs: print(r)
except Exception as e:
 pass
PY
<<<"$json")"
if [ -z "$deps" ]; then printf 'No requires_dist metadata or package not on PyPI\n'; return 2; fi
printf 'Dependencies for %s %s:\n' "$pkg" "${ver:-latest}"
printf '%s\n' "$deps"
return 0
}
install_package_in_venv(){
pyenv_available || { printf 'pyenv not found\n'; return; }
mapfile -t VENV < <(pyenv virtualenvs --bare 2>/dev/null)
if [ ${#VENV[@]} -eq 0 ]; then printf 'No virtualenvs\n'; return; fi
venv=$(choose_from_list 'Choose virtualenv to install into:' "${VENV[@]}") || return
printf 'Enter package name (example: requests): '; read -r pkg; [ -z "$pkg" ] && { printf 'Package required\n'; return; }
printf 'Enter extras/variant without brackets, comma separated if many or press Enter to skip (example: socks): '; read -r extras
printf 'Enter version or git ref or github url or press Enter for latest: '; read -r ver
spec="$pkg"
if [ -n "$extras" ]; then spec="${spec}[${extras// /}]"; fi
if [ -n "$ver" ]; then
 if [[ "$ver" =~ ^(git\+|https?://|git@|github.com) ]]; then spec="$ver"
 elif [[ "$ver" =~ ^(owner/|.+/.+@) ]]; then spec="git+https://github.com/${ver}"
 elif [[ "$ver" =~ ^gh: ]]; then ref="${ver#gh:}"; spec="git+https://github.com/feloopy/${pkg}.git@${ref}"
 else spec="${spec}==${ver}"
 fi
fi
if [[ "$spec" =~ ^git\+ ]]; then printf 'VCS install spec: %s\n' "$spec"; printf 'Cannot reliably fetch PyPI dependencies for VCS installs\n'; else show_deps_from_pypi "$pkg" "${ver}" ; dep_status=$?; fi
printf '\nProceed to install %s into %s? (y/N): ' "$spec" "$venv"; read -r ok
if [ "$ok" != "y" ] && [ "$ok" != "Y" ]; then printf 'Cancelled\n'; return; fi
PYBIN="$PYENV_ROOT/versions/$venv/bin/python"
PIP="$PYENV_ROOT/versions/$venv/bin/pip"
if [ ! -x "$PIP" ]; then if [ -x "$PYBIN" ]; then "$PYBIN" -m ensurepip --upgrade >/dev/null 2>&1 || true; fi; fi
"$PIP" install "$spec" || { printf 'Install failed\n' >&2; return 1; }
printf 'Installed %s into %s\n' "$spec" "$venv"
}
modify_venv_menu(){
pyenv_available || { printf 'pyenv not found\n'; return; }
mapfile -t VENV < <(pyenv virtualenvs --bare 2>/dev/null)
if [ ${#VENV[@]} -eq 0 ]; then printf 'No virtualenvs\n'; return; fi
v=$(choose_from_list 'Select virtualenv to manage:' "${VENV[@]}") || return
while true; do printf '\nManaging %s\n1) List packages\n2) Install package\n3) Uninstall package\n4) Freeze to requirements.txt\n5) Rename virtualenv\n6) Back\nChoose: ' "$v"; read -r o
pip="$PYENV_ROOT/versions/$v/bin/pip"
case "$o" in
1) "$pip" list || printf 'Failed\n' ;;
2) install_package_in_venv ;;
3) printf 'Enter package names to uninstall (space separated): '; read -r pkgs; [ -n "$pkgs" ] && "$pip" uninstall -y $pkgs || printf 'No packages\n' ;;
4) "$pip" freeze > "$PYENV_ROOT/versions/$v/requirements.txt" && printf 'Wrote requirements.txt\n' ;;
5) printf 'Enter new name: '; read -r new; [ -z "$new" ] && printf 'Name required\n' || { cp -a "$PYENV_ROOT/versions/$v" "$PYENV_ROOT/versions/$new" && rm -rf "$PYENV_ROOT/versions/$v" && printf 'Renamed %s to %s\n' "$v" "$new" && pyenv rehash >/dev/null 2>&1 || true; break; } ;;
6) break ;;
*) printf 'Invalid\n' ;;
esac
done
}
main_menu(){
bootstrap_pyenv
while true; do clear; printf '=== pyenv Manager ===\nPYENV_ROOT: %s\n\n1) Install Python interpreter\n2) Uninstall Python interpreter\n3) Create virtualenv\n4) Delete virtualenv\n5) Manage virtualenv (install packages, list, rename)\n6) List installed Python versions\n7) List virtualenvs\n8) Set/change PYENV_ROOT\n9) Install package into virtualenv (quick)\n0) Exit\nChoose: ' "$PYENV_ROOT"; read -r opt
case "$opt" in
1) install_prereqs; install_python ;;
2) uninstall_python ;;
3) create_venv ;;
4) delete_venv ;;
5) modify_venv_menu ;;
6) list_versions; printf '\nPress Enter to continue...'; read -r _ ;;
7) list_venvs; printf '\nPress Enter to continue...'; read -r _ ;;
8) set_pyenv_root ;;
9) install_package_in_venv ;;
0) printf 'Goodbye\n'; break ;;
*) printf 'Invalid\n'; sleep 1 ;;
esac
done
}
main_menu
clear
printf 'Final pyenv versions:\n'; pyenv versions 2>/dev/null || true
printf '\nDone\n'
