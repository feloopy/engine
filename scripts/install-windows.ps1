param([string]$PythonVersion="")
Set-StrictMode -Version Latest
function Write-ColorOutput{param($Message,$Color="White");Write-Host $Message -ForegroundColor $Color}
function Test-Admin{ $id=[Security.Principal.WindowsIdentity]::GetCurrent(); (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Retry{ param($ScriptBlock,$Attempts=3,$Delay=5) for($i=1;$i -le $Attempts;$i++){ Write-ColorOutput "Attempt $i of $Attempts..." Cyan; try{ & $ScriptBlock 2>&1 | ForEach-Object{ Write-Host $_ } ; return $true } catch { Write-ColorOutput "Error: $($_.Exception.Message)" Red; if($i -lt $Attempts){ Write-ColorOutput "Waiting $Delay seconds before retry..." Yellow; Start-Sleep -Seconds $Delay } else { return $false } } } }
function Ensure-WinGet{ if (Get-Command winget -ErrorAction SilentlyContinue){ Write-ColorOutput "WinGet present" Green; return $true } Write-ColorOutput "WinGet not found. Attempting to ensure App Installer present..." Yellow; try{ $app=Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue; if(-not $app){ Write-ColorOutput "Please install 'App Installer' from Microsoft Store or enable the Windows Package Manager. Exiting." Red; return $false } else { Write-ColorOutput "App Installer present" Green; return $true } } catch { Write-ColorOutput "Could not verify App Installer: $($_.Exception.Message)" Red; return $false } }
function Ensure-Dependencies{
  Write-ColorOutput "Installing required dependencies with winget..." Yellow
  if(-not (Retry { & winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements } 3 10)){ Write-ColorOutput "Git install via winget failed or was interactive" Yellow }
  $vsId="Microsoft.VisualStudio.2022.BuildTools"
  $vsOverride="--quiet --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22000"
  if(-not (Retry { & winget install --id $vsId -e --accept-package-agreements --accept-source-agreements --override $vsOverride } 2 30)){ Write-ColorOutput "Visual Studio Build Tools install via winget failed or requires user interaction" Yellow }
  if(-not (Get-Command cl -ErrorAction SilentlyContinue)){ Write-ColorOutput "C/C++ build tools may be missing; builds can fail without them" Yellow }
}
function Install-PyenvWin{
  Write-ColorOutput "Installing pyenv-win..." Yellow
  if (Get-Command pyenv -ErrorAction SilentlyContinue){ Write-ColorOutput "pyenv already installed" Green; return $true }
  $pyenvRoot=Join-Path $env:USERPROFILE ".pyenv"
  $pyenvWinPath=Join-Path $pyenvRoot "pyenv-win"
  try{
    if(Test-Path $pyenvWinPath){ Remove-Item -Path $pyenvWinPath -Recurse -Force -ErrorAction SilentlyContinue }
    if(-not (Get-Command git -ErrorAction SilentlyContinue)){ Write-ColorOutput "git not found in PATH after winget install; trying to continue" Yellow }
    if(-not (Retry { & git clone https://github.com/pyenv-win/pyenv-win.git $pyenvWinPath } 2 5)){ Write-ColorOutput "git clone failed, attempting zip fallback" Yellow; try{ $zipPath = Join-Path $env:TEMP "pyenv-win.zip"; (New-Object System.Net.WebClient).DownloadFile('https://github.com/pyenv-win/pyenv-win/archive/refs/heads/master.zip',$zipPath); Expand-Archive -Path $zipPath -DestinationPath $pyenvRoot -Force; Move-Item -Path (Join-Path $pyenvRoot 'pyenv-win-master') -Destination $pyenvWinPath -Force } catch { Write-ColorOutput "Zip fallback failed: $($_.Exception.Message)" Red; return $false } }
    $userPath=[Environment]::GetEnvironmentVariable("Path","User")
    $addPath="$($pyenvWinPath)\bin;$($pyenvWinPath)\shims"
    if ($userPath -notlike "*$($pyenvWinPath.Replace('\','\\'))*"){ [Environment]::SetEnvironmentVariable("Path", ($userPath + ';' + $addPath).Trim(';'), "User") }
    [Environment]::SetEnvironmentVariable("PYENV", $pyenvWinPath, "User"); [Environment]::SetEnvironmentVariable("PYENV_ROOT", $pyenvWinPath, "User"); [Environment]::SetEnvironmentVariable("PYENV_HOME", $pyenvWinPath, "User")
    $env:Path = ([Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")).Trim(';')
    if (Get-Command pyenv -ErrorAction SilentlyContinue){ Write-ColorOutput "pyenv-win installed successfully" Green; return $true } else { Write-ColorOutput "pyenv-win appears installed but command not available in this session. Restart PowerShell or run: $env:USERPROFILE\.pyenv\pyenv-win\shims\pyenv.exe" Yellow; return $true }
  } catch { Write-ColorOutput "Failed to install pyenv-win: $($_.Exception.Message)" Red; return $false }
}
function Get-AvailablePythonVersions{
  Write-ColorOutput "Fetching available Python versions..." Yellow
  try{ $v = & pyenv install --list 2>&1 } catch { $v = $null }
  if(-not $v){ try{ $v = (Invoke-RestMethod -Uri 'https://registry.npmmirror.com/-/binary/python/' -UseBasicParsing 2>&1) -as [string] } catch { $v = $null } }
  if(-not $v){ Write-ColorOutput "Could not fetch versions" Red; return @() }
  $out = $v -split "`n" | ForEach-Object{ $_.Trim() } | Where-Object{ $_ -match '^3\.\d+\.\d+$' } | Sort-Object -Unique -Descending
  ,$out
}
function Get-LatestMajorVersions{ param([string[]]$All) $dict=@{}; foreach($version in $All){ $p=$version -split '\.'; if($p.Count -lt 3){ continue } $mm="$($p[0]).$($p[1])"; if([int]$p[1] -ge 10){ if(-not $dict.ContainsKey($mm) -or [version]$version -gt [version]$dict[$mm]){ $dict[$mm]=$version } } } $dict.Values | Sort-Object {[version]$_} -Descending }
function Show-VersionTable{ param($Versions,$InstalledVersions) Write-ColorOutput "Latest versions of each Python major release (3.10+):" Cyan; Write-Host "┌─────────────┬────────────┐" -ForegroundColor Gray; Write-Host "│ Version     │ Status     │" -ForegroundColor Gray; Write-Host "├─────────────┼────────────┤" -ForegroundColor Gray; foreach($v in $Versions){ $status = if ($InstalledVersions -contains $v) { "INSTALLED" } else { "Available" }; $statusColor = if ($status -eq "INSTALLED") { "Green" } else { "Yellow" }; Write-Host "│ $($v.PadRight(11)) │ " -NoNewline -ForegroundColor Gray; Write-Host "$($status.PadRight(10))" -NoNewline -ForegroundColor $statusColor; Write-Host " │" -ForegroundColor Gray }; Write-Host "└─────────────┴────────────┘" -ForegroundColor Gray }
Clear-Host
Write-ColorOutput "=== Engine Installation Script for Windows (winget) ===" Cyan
Write-Host ""
Write-ColorOutput "System Information:" "Yellow"
Write-Host "  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Host "  Architecture: $env:PROCESSOR_ARCHITECTURE"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "  User: $env:USERNAME"
Write-Host ""
if (-not (Test-Admin)){ Write-ColorOutput "Warning: Not running as administrator. Some installations might require elevated privileges." "Yellow"; Write-Host "" }
if (-not (Ensure-WinGet)){ Write-ColorOutput "WinGet/App Installer required. Please install App Installer from Microsoft Store and retry." Red; exit 1 }
Ensure-Dependencies
if (-not (Install-PyenvWin)){ Write-ColorOutput "Failed to install pyenv-win. Exiting." Red; exit 1 }
$env:Path = ([Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")).Trim(';')
Clear-Host
Write-ColorOutput "=== Python Version Selection ===" "Cyan"
Write-Host ""
$allVersions = @(Get-AvailablePythonVersions)
if ($allVersions.Count -eq 0){ Write-ColorOutput "No Python versions available. Please check your internet connection or pyenv" "Red"; exit 1 }
$installedVersions=@(); try{ $installedVersions = @(pyenv versions --bare 2>&1) } catch {}
$majorVersions = @(Get-LatestMajorVersions -All $allVersions)
if ($majorVersions.Count -eq 0){ Write-ColorOutput "No major versions detected (3.10+). Exiting." Red; exit 1 }
$latestVersion = $majorVersions[0]
Show-VersionTable -Versions $majorVersions -InstalledVersions $installedVersions
Write-Host ""
Write-ColorOutput "Currently installed versions:" "Yellow"
try{ pyenv versions } catch { Write-Host "  No versions installed yet" }
Write-Host ""
Write-ColorOutput "=== Version Selection ===" "Cyan"
Write-ColorOutput "Latest version: $latestVersion" "Green"
Write-Host ""
if ($PythonVersion){ $selectedVersion = $PythonVersion; Write-ColorOutput "Using command line specified version: $selectedVersion" "Yellow" } else {
  Write-ColorOutput "Enter the Python version to install" "White"
  Write-Host "Press Enter for latest ($latestVersion) or type a version: " -NoNewline -ForegroundColor Gray
  $userInput = Read-Host
  if ([string]::IsNullOrWhiteSpace($userInput)){ $selectedVersion = $latestVersion; Write-ColorOutput "Using latest version: $selectedVersion" "Green" } else {
    $selectedVersion = $userInput.Trim()
    if ($selectedVersion -notmatch '^3\.\d+\.\d+$'){ Write-ColorOutput "Invalid version format. Please use format: 3.x.x" "Red"; Write-ColorOutput "Using latest version instead: $latestVersion" "Yellow"; $selectedVersion = $latestVersion }
    elseif ($allVersions -notcontains $selectedVersion){ Write-ColorOutput "Version $selectedVersion not found in available versions." "Red"; Write-ColorOutput "Using latest version instead: $latestVersion" "Yellow"; $selectedVersion = $latestVersion }
    else { Write-ColorOutput "Selected version: $selectedVersion" "Green" }
  }
}
Clear-Host
Write-ColorOutput "=== Installing Python $selectedVersion ===" "Cyan"
Write-Host ""
if ($installedVersions -contains $selectedVersion){ Write-ColorOutput "Python $selectedVersion already installed, skipping installation" "Yellow" } else {
  Write-ColorOutput "Installing Python $selectedVersion (this may take several minutes). You will see streamed output below..." "Yellow"
  $installStart = Get-Date
  if (Retry { & pyenv install $selectedVersion } 1 10){ $installEnd = Get-Date; $installDuration = ($installEnd - $installStart).TotalSeconds; Write-ColorOutput "✅ Python $selectedVersion installed successfully in $([math]::Round($installDuration)) seconds" "Green" } else { Write-ColorOutput "❌ Python $selectedVersion installation failed" "Red"; Write-ColorOutput "Continuing with existing installations..." "Yellow" }
}
Write-Host ""
Write-ColorOutput "Setting Python $selectedVersion as global default..." "Yellow"
try{ & pyenv global $selectedVersion 2>&1 | ForEach-Object{ Write-Host $_ }; & pyenv rehash 2>&1 | ForEach-Object{ Write-Host $_ }; Write-ColorOutput "Python $selectedVersion set as global default" "Green" } catch { Write-ColorOutput "Failed to set global version: $($_.Exception.Message)" "Red" }
Clear-Host
Write-ColorOutput "=== Installation Complete ===" "Cyan"
Write-Host ""
try{ $pythonVersion = (& python --version 2>&1); $pythonPath = (Get-Command python | Select-Object -ExpandProperty Source) ; $pipPath = (Get-Command pip | Select-Object -ExpandProperty Source); Write-ColorOutput "Active python: $pythonVersion" "Green"; Write-Host "Python location: $pythonPath"; Write-Host "pip location: $pipPath" } catch { Write-ColorOutput "Error getting Python information: $($_.Exception.Message)" "Red" }
Write-Host ""
Write-ColorOutput "Installed Python versions:" "Yellow"
try{ pyenv versions } catch { Write-Host "  Error listing versions" }
Write-Host ""
Write-ColorOutput "=== Usage Examples for Python $selectedVersion ===" "Cyan"
Write-Host "  List available versions: pyenv install --list"
Write-Host "  Install specific version: pyenv install 3.x.x"
Write-Host "  Set global version: pyenv global $selectedVersion"
Write-Host "  Set local version: pyenv local $selectedVersion"
Write-Host "  Create virtualenv: python -m venv my-project-env"
Write-Host "  Activate virtualenv: .\\my-project-env\\Scripts\\Activate.ps1"
Write-Host "  Deactivate virtualenv: deactivate"
Write-Host "  Install package: pip install package-name"
Write-Host ""
Write-ColorOutput "=== Important Notes for Windows ===" "Cyan"
Write-Host "• You may need to restart PowerShell or your terminal to see pyenv commands"
Write-Host "• Or run: . `$PROFILE` to reload your profile"
Write-Host "• Project-specific Python: create .python-version file in project directory"
Write-Host "• Use 'python -m venv' for virtual environments on Windows"
Write-Host "• Architecture: $env:PROCESSOR_ARCHITECTURE"
Write-Host "• Package manager: WinGet"
Write-Host "• If you have issues, ensure Visual Studio Build Tools are installed"
Write-Host "• To update pyenv: git -C $env:USERPROFILE\\.pyenv\\pyenv-win pull"
Write-Host ""
Write-ColorOutput "🎉 pyenv+cpython installation completed successfully!" "Green"
Write-ColorOutput "    for Windows! 🐍" "Cyan"
Write-Host ""; Write-Host "Press Enter to close..." -NoNewline; Read-Host
