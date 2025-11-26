param([string]$PythonVersion="")
Set-StrictMode -Version Latest
function Write-ColorOutput{param($Message,$Color="White")Write-Host $Message -ForegroundColor $Color}
function Test-Admin{$id=[Security.Principal.WindowsIdentity]::GetCurrent();(New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Retry{param($ScriptBlock,$Attempts=3,$Delay=5)for($i=1;$i -le $Attempts;$i++){Write-ColorOutput "Attempt $i of $Attempts..." Cyan;try{& $ScriptBlock 2>&1|ForEach-Object{Write-Host $_};return $true}catch{Write-ColorOutput "Error: $($_.Exception.Message)" Red;if($i -lt $Attempts){Write-ColorOutput "Waiting $Delay seconds before retry..." Yellow;Start-Sleep -Seconds $Delay}else{return $false}}}}
function Ensure-WinGet{if(Get-Command winget -ErrorAction SilentlyContinue){Write-ColorOutput "WinGet present" Green;return $true}Write-ColorOutput "WinGet not found" Yellow;return $false}
function Ensure-Dependencies{Write-ColorOutput "Checking dependencies..." Yellow;if(-not(Get-Command git -ErrorAction SilentlyContinue)){Write-ColorOutput "Installing Git..." Yellow;Retry{& winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements}3 10|Out-Null}$env:Path=[System.Environment]::GetEnvironmentVariable("Path","Machine")+";"+[System.Environment]::GetEnvironmentVariable("Path","User")}
function Install-PyenvWin{Write-ColorOutput "Installing pyenv-win..." Yellow;if(Get-Command pyenv -ErrorAction SilentlyContinue){Write-ColorOutput "pyenv already installed" Green;return $true}$pyenvRoot=Join-Path $env:USERPROFILE ".pyenv";$pyenvWinPath=Join-Path $pyenvRoot "pyenv-win";try{if(Test-Path $pyenvWinPath){Remove-Item -Path $pyenvWinPath -Recurse -Force -ErrorAction SilentlyContinue}if(-not(Get-Command git -ErrorAction SilentlyContinue)){Write-ColorOutput "git not found" Red;return $false}if(-not(Retry{& git clone https://github.com/pyenv-win/pyenv-win.git $pyenvWinPath}3 5)){Write-ColorOutput "git clone failed, using zip fallback" Yellow;$zipPath=Join-Path $env:TEMP "pyenv-win.zip";Invoke-WebRequest -Uri 'https://github.com/pyenv-win/pyenv-win/archive/refs/heads/master.zip' -OutFile $zipPath -UseBasicParsing;Expand-Archive -Path $zipPath -DestinationPath $pyenvRoot -Force;Move-Item -Path (Join-Path $pyenvRoot 'pyenv-win-master') -Destination $pyenvWinPath -Force;Remove-Item $zipPath -Force}$userPath=[Environment]::GetEnvironmentVariable("Path","User");$addPath="$pyenvWinPath\bin;$pyenvWinPath\shims";if($userPath -notlike "*$($pyenvWinPath.Replace('\','\\'))*"){[Environment]::SetEnvironmentVariable("Path",($userPath+';'+$addPath).Trim(';'),"User")}[Environment]::SetEnvironmentVariable("PYENV",$pyenvWinPath,"User");[Environment]::SetEnvironmentVariable("PYENV_ROOT",$pyenvWinPath,"User");$env:Path=([Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")).Trim(';');if(Get-Command pyenv -ErrorAction SilentlyContinue){Write-ColorOutput "pyenv-win installed" Green;return $true}else{Write-ColorOutput "pyenv installed but command not immediately available" Yellow;return $true}}catch{Write-ColorOutput "Failed: $($_.Exception.Message)" Red;return $false}}
function Get-AvailablePythonVersions{Write-ColorOutput "Fetching Python versions..." Yellow;$versions=@();try{$pyenvOutput=& pyenv install --list 2>&1;if($LASTEXITCODE -eq 0){$versions=$pyenvOutput|Where-Object{$_ -match '^\s*3\.\d+\.\d+\s*$'}|ForEach-Object{$_.Trim()}}}catch{Write-ColorOutput "pyenv failed" Yellow}if(@($versions).Length -eq 0){try{$response=Invoke-RestMethod -Uri 'https://registry.npmmirror.com/-/binary/python/' -UseBasicParsing -TimeoutSec 30;$versions=$response|Where-Object{$_ -match '^3\.\d+\.\d+/$'}|ForEach-Object{$_.Trim('/')}}catch{Write-ColorOutput "Web API failed" Yellow}}if(@($versions).Length -eq 0){$versions=@("3.12.1","3.11.7","3.10.12","3.9.18","3.8.18")}return $versions|Sort-Object {[version]$_} -Descending}
function Get-LatestMajorVersions{param([string[]]$All)$dict=@{};foreach($version in $All){$p=$version -split '\.';if($p.Count -lt 3){continue}$mm="$($p[0]).$($p[1])";if([int]$p[1] -ge 10){if(-not $dict.ContainsKey($mm)-or[version]$version -gt [version]$dict[$mm]){$dict[$mm]=$version}}}$dict.Values|Sort-Object {[version]$_} -Descending}
function Show-VersionTable{param($Versions,$InstalledVersions)Write-ColorOutput "Latest Python versions (3.10+):" Cyan;Write-Host "┌─────────────┬────────────┐" -ForegroundColor Gray;Write-Host "│ Version     │ Status     │" -ForegroundColor Gray;Write-Host "├─────────────┼────────────┤" -ForegroundColor Gray;foreach($v in $Versions){$status=if($InstalledVersions -contains $v){"INSTALLED"}else{"Available"};$statusColor=if($status -eq "INSTALLED"){"Green"}else{"Yellow"};Write-Host "│ $($v.PadRight(11)) │ " -NoNewline -ForegroundColor Gray;Write-Host "$($status.PadRight(10))" -NoNewline -ForegroundColor $statusColor;Write-Host " │" -ForegroundColor Gray}Write-Host "└─────────────┴────────────┘" -ForegroundColor Gray}

Clear-Host
Write-ColorOutput "=== Python Installation Script ===" Cyan
Write-Host ""
if(-not(Test-Admin)){Write-ColorOutput "Warning: Not running as administrator" Yellow;Write-Host ""}
if(-not(Ensure-WinGet)){Write-ColorOutput "WinGet not available" Yellow}
Ensure-Dependencies
if(-not(Install-PyenvWin)){Write-ColorOutput "pyenv-win installation failed" Red;exit 1}
$env:Path=([Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")).Trim(';')

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
if($installedVersions -contains $selectedVersion){Write-ColorOutput "Already installed" Yellow}else{Write-ColorOutput "Installing..." Yellow;$installStart=Get-Date;if(Retry{& pyenv install $selectedVersion}3 10){$installEnd=Get-Date;$installDuration=($installEnd - $installStart).TotalSeconds;Write-ColorOutput "✅ Installed in $([math]::Round($installDuration))s" Green}else{Write-ColorOutput "❌ Installation failed" Red}}
Write-Host ""
Write-ColorOutput "Setting as global default..." Yellow
try{& pyenv global $selectedVersion 2>&1|Out-Null;& pyenv rehash 2>&1|Out-Null;Write-ColorOutput "Default set" Green}catch{Write-ColorOutput "Failed to set default" Yellow}

Clear-Host
Write-ColorOutput "=== Installation Complete ===" Cyan
Write-Host ""
try{$pythonVersion=& python --version 2>&1;$pythonPath=Get-Command python -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Source;Write-ColorOutput "Active: $pythonVersion" Green;if($pythonPath){Write-Host "Location: $pythonPath"}}catch{Write-ColorOutput "Python info error" Yellow}
Write-Host ""
Write-ColorOutput "Installed versions:" Yellow
try{& pyenv versions 2>$null}catch{Write-Host "  Error"}
Write-Host ""
Write-ColorOutput "=== Usage ===" Cyan
Write-Host "  pyenv install --list"
Write-Host "  pyenv install 3.x.x"  
Write-Host "  pyenv global $selectedVersion"
Write-Host "  python -m venv my-env"
Write-Host "  .\my-env\Scripts\Activate.ps1"
Write-Host ""
Write-ColorOutput "🎉 Python installation completed!" Green
Write-Host "Press Enter to close..." -NoNewline;Read-Host