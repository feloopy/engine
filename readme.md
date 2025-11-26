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
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1" | Invoke-Expression
```
(Command Prompt)

```cmd
powershell -Command "irm https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1 | iex"
```