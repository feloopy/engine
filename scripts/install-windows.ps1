param([string]$PythonVersion="")
Set-StrictMode -Version Latest
function Write-ColorOutput{param($Message,$Color="White")Write-Host $Message -ForegroundColor $Color}
function Test-Admin{$id=[Security.Principal.WindowsIdentity]::GetCurrent();(New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Retry{param($ScriptBlock,$Attempts=3,$Delay=5)for($i=1;$i -le $Attempts;$i++){Write-ColorOutput "Attempt $i of $Attempts..." Cyan;try{& $ScriptBlock 2>&1|ForEach-Object{Write-Host $_};return $true}catch{Write-ColorOutput "Error: $($_.Exception.Message)" Red;if($i -lt $Attempts){Write-ColorOutput "Waiting $Delay seconds before retry..." Yellow;Start-Sleep -Seconds $Delay}else{return $false}}}}
function Ensure-WinGet{if(Get-Command winget -ErrorAction SilentlyContinue){Write-ColorOutput "WinGet present" Green;return $true}Write-ColorOutput "WinGet not found" Yellow;return $false}
function Ensure-Dependencies{Write-ColorOutput "Checking dependencies..." Yellow;if(-not(Get-Command git -ErrorAction SilentlyContinue)){Write-ColorOutput "Installing Git..." Yellow;Retry{& winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements}3 10|Out-Null}$env:Path=[System.Environment]::GetEnvironmentVariable("Path","Machine")+";"+[System.Environment]::GetEnvironmentVariable("Path","User")}
function Install-PyenvWin{Write-ColorOutput "Installing pyenv-win via official installer..." Yellow;if(Get-Command pyenv -ErrorAction SilentlyContinue){Write-ColorOutput "pyenv already installed" Green;return $true}try{$installScript=Join-Path $env:TEMP "install-pyenv-win.ps1";Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1" -OutFile $installScript;& $installScript;Remove-Item $installScript -Force;Write-ColorOutput "pyenv-win installed via official method" Green;return $true}catch{Write-ColorOutput "Official installer failed: $($_.Exception.Message)" Red;return $false}}
function Get-AvailablePythonVersions{Write-ColorOutput "Fetching Python versions via pyenv..." Yellow;try{$versions=& pyenv install -l 2>&1|Where-Object{$_ -match '^\s*3\.\d+\.\d+\s*$'}|ForEach-Object{$_.Trim()};if(@($versions).Length -eq 0){throw "No versions found"}}catch{Write-ColorOutput "pyenv list failed, using fallback list" Yellow;$versions=@("3.12.1","3.11.7","3.10.12","3.9.18","3.8.18")}return $versions|Sort-Object {[version]$_} -Descending}
function Get-LatestMajorVersions{param([string[]]$All)$dict=@{};foreach($version in $All){$p=$version -split '\.';if($p.Count -lt 3){continue}$mm="$($p[0]).$($p[1])";if([int]$p[1] -ge 10){if(-not $dict.ContainsKey($mm)-or[version]$version -gt [version]$dict[$mm]){$dict[$mm]=$version}}}$dict.Values|Sort-Object {[version]$_} -Descending}
function Show-VersionTable{param($Versions,$InstalledVersions)Write-ColorOutput "Latest Python versions (3.10+):" Cyan;Write-Host "┌─────────────┬────────────┐" -ForegroundColor Gray;Write-Host "│ Version     │ Status     │" -ForegroundColor Gray;Write-Host "├─────────────┼────────────┤" -ForegroundColor Gray;foreach($v in $Versions){$status=if($InstalledVersions -contains $v){"INSTALLED"}else{"Available"};$statusColor=if($status -eq "INSTALLED"){"Green"}else{"Yellow"};Write-Host "│ $($v.PadRight(11)) │ " -NoNewline -ForegroundColor Gray;Write-Host "$($status.PadRight(10))" -NoNewline -ForegroundColor $statusColor;Write-Host " │" -ForegroundColor Gray}Write-Host "└─────────────┴────────────┘" -ForegroundColor Gray}

Clear-Host
Write-ColorOutput "=== Python Installation Script (Official pyenv-win) ===" Cyan
Write-Host ""
if(-not(Test-Admin)){Write-ColorOutput "Warning: Not running as administrator" Yellow;Write-Host ""}
if(-not(Ensure-WinGet)){Write-ColorOutput "WinGet not available" Yellow}
Ensure-Dependencies
if(-not(Install-PyenvWin)){Write-ColorOutput "pyenv-win installation failed" Red;exit 1}

Write-ColorOutput "=== Validating Installation ===" Cyan
try{$pyenvVersion=& pyenv --version 2>&1;Write-ColorOutput "✅ $pyenvVersion" Green}catch{Write-ColorOutput "❌ pyenv not found in PATH" Red;Write-ColorOutput "Please restart PowerShell and run the script again" Yellow;exit 1}

Clear-Host
Write-ColorOutput "=== Python Version Selection ===" Cyan
Write-Host ""
$allVersions=@(Get-AvailablePythonVersions)
$installedVersions=@();try{$installedVersions=@(& pyenv versions --bare 2>$null)}catch{}
$majorVersions=@(Get-LatestMajorVersions -All $allVersions)
if(@($majorVersions).Length -eq 0){Write-ColorOutput "No versions detected" Red;exit 1}
$latestVersion=$majorVersions[0]
Show-VersionTable -Versions $majorVersions -InstalledVersions $installedVersions
Write-Host ""
Write-ColorOutput "Installed versions:" Yellow
try{& pyenv versions 2>$null}catch{Write-Host "  None"}
Write-Host ""
Write-ColorOutput "Latest version: $latestVersion" Green
if($PythonVersion){$selectedVersion=$PythonVersion;Write-ColorOutput "Using: $selectedVersion" Yellow}else{Write-ColorOutput "Press Enter for latest ($latestVersion) or type version: " -NoNewline;$userInput=Read-Host;if([string]::IsNullOrWhiteSpace($userInput)){$selectedVersion=$latestVersion;Write-ColorOutput "Using latest: $selectedVersion" Green}else{$selectedVersion=$userInput.Trim();if($selectedVersion -notmatch '^3\.\d+\.\d+$'-or $allVersions -notcontains $selectedVersion){Write-ColorOutput "Invalid version, using: $latestVersion" Yellow;$selectedVersion=$latestVersion}else{Write-ColorOutput "Selected: $selectedVersion" Green}}}

Clear-Host
Write-ColorOutput "=== Installing Python $selectedVersion ===" Cyan
Write-Host ""
if($installedVersions -contains $selectedVersion){Write-ColorOutput "Already installed" Yellow}else{Write-ColorOutput "Installing (this may take several minutes)..." Yellow;$installStart=Get-Date;if(Retry{& pyenv install $selectedVersion -q}3 10){$installEnd=Get-Date;$installDuration=($installEnd - $installStart).TotalSeconds;Write-ColorOutput "✅ Installed in $([math]::Round($installDuration))s" Green}else{Write-ColorOutput "❌ Installation failed" Red}}
Write-Host ""
Write-ColorOutput "Setting as global default..." Yellow
try{& pyenv global $selectedVersion 2>&1|Out-Null;& pyenv rehash 2>&1|Out-Null;Write-ColorOutput "Default set" Green}catch{Write-ColorOutput "Failed to set default" Yellow}

Clear-Host
Write-ColorOutput "=== Installation Complete ===" Cyan
Write-Host ""
Write-ColorOutput "Validation:" Yellow
try{$currentVersion=& pyenv version 2>&1;Write-ColorOutput "Current: $currentVersion" Green}catch{Write-ColorOutput "Version check failed" Yellow}
try{$pythonPath=& python -c "import sys; print(sys.executable)" 2>&1;Write-ColorOutput "Python executable: $pythonPath" Green}catch{Write-ColorOutput "Python validation failed" Yellow}
Write-Host ""
Write-ColorOutput "=== Available Commands ===" Cyan
Write-Host "  pyenv commands     - List all available pyenv commands"
Write-Host "  pyenv install -l   - List available Python versions"
Write-Host "  pyenv versions     - List installed versions"
Write-Host "  pyenv local x.x.x  - Set local version"
Write-Host "  pyenv global x.x.x - Set global version"
Write-Host "  pyenv rehash       - Update shims after install"
Write-Host ""
Write-ColorOutput "=== Important Notes ===" Cyan
Write-Host "• If Python commands don't work, RESTART POWERSHELL"
Write-Host "• Disable Python app aliases in: Start > 'Manage App Execution Aliases'"
Write-Host "• Check PATH contains: %USERPROFILE%\.pyenv\pyenv-win\bin and \shims"
Write-Host ""
Write-ColorOutput "🎉 Python $selectedVersion installation completed!" Green
Write-Host "Press Enter to close..." -NoNewline;Read-Host