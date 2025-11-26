# Universal Installer

One command to setup the FelooPy engine.

## Install

Run this single command in your terminal:

### Linux

```bash
bash -c 'curl -fsSL "https://raw.githubusercontent.com/feloopy/engine/$(curl -fsSL -H '\''Accept: application/vnd.github.v3+json'\'' -H '\''User-Agent: curl'\'' https://api.github.com/repos/feloopy/engine 2>/dev/null | sed -nE '\''s/.*\"default_branch\": *\"([^\"]+)\".*/\1/p'\'' || echo main)/interpreters/cpython/install-linux.sh" | bash'
```

### macOS

```bash
bash -c 'curl -fsSL "https://raw.githubusercontent.com/feloopy/engine/$(curl -fsSL -H '\''Accept: application/vnd.github.v3+json'\'' -H '\''User-Agent: curl'\'' https://api.github.com/repos/feloopy/engine 2>/dev/null | sed -nE '\''s/.*\"default_branch\": *\"([^\"]+)\".*/\1/p'\'' || echo main)/interpreters/cpython/install-macos.sh" | bash'
```

### Windows

(Powershell)

```ps
$t=[int](Get-Date -UFormat %s); iex (Invoke-WebRequest "https://raw.githubusercontent.com/feloopy/engine/main/interpreters/cpython/install-windows.ps1?t=$t" -UseBasicParsing).Content
```

(Command Prompt)

```cmd
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[int](Get-Date -UFormat %s); iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/feloopy/engine/main/interpreters/cpython/install-windows.ps1?t=' + $t)"
```