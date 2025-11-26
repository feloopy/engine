# Universal Installer

One command to setup the FelooPy engine.

## Install

Run this single command in your terminal:

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-linux.sh | bash
```

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-macos.sh | bash
```

### Windows

(Powershell)

```ps
$t=[int](Get-Date -UFormat %s); Invoke-RestMethod "https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1?t=$t" | Invoke-Expression
```
(Command Prompt)

```cmd
powershell -NoProfile -Command "$t=[int](Get-Date -UFormat %s); Invoke-RestMethod \"https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1?t=$t\" | Invoke-Expression"
```