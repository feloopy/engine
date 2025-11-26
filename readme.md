# Universal Installer

One command to setup the FelooPy engine.

## Install

Run this single command in your terminal:

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-linux-all.sh | bash
```

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-macos-all.sh | bash
```

### Windows

```ps
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1" | Invoke-Expression
```

```cmd
powershell -Command "irm https://raw.githubusercontent.com/feloopy/engine/main/scripts/install-windows.ps1 | iex"
```