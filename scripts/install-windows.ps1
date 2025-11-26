param([string]$PythonVersion="")
Set-StrictMode -Version Latest
function Write-ColorOutput{param($M,$C="White")Write-Host $M -ForegroundColor $C}
function Test-Admin{$id=[Security.Principal.WindowsIdentity]::GetCurrent();(New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Retry{param($ScriptBlock,$Attempts=3,$Delay=5)for($i=1;$i -le $Attempts;$i++){Write-ColorOutput "Attempt $i of $Attempts..." Cyan;try{& $ScriptBlock 2>&1|ForEach-Object{Write-Host $_};return $true}catch{Write-ColorOutput "Error: $($_.Exception.Message)" Red;if($i -lt $Attempts){Write-ColorOutput "Waiting $Delay seconds before retry..." Yellow;Start-Sleep -Seconds $Delay}else{return $false}}}}
function Ensure-WinGet{if(Get-Command winget -ErrorAction SilentlyContinue){Write-ColorOutput "WinGet present" Green;return $true}Write-ColorOutput "WinGet not found" Yellow;return $false}
function Install-PyManager{Write-ColorOutput "Installing Python Install Manager via winget (user scope)..." Yellow;if(Get-Command py -ErrorAction SilentlyContinue){Write-ColorOutput "py launcher detected" Green;return $true}if(-not(Ensure-WinGet)){Write-ColorOutput "winget missing, cannot install pymanager" Red;return $false}return Retry{& winget install --id 9NQ7512CXL7T -e --scope user --accept-package-agreements --accept-source-agreements}3 10}
function Validate-Py{try{$out=& py --version 2>&1;Write-ColorOutput "py: $out" Green;return $true}catch{Write-ColorOutput "py not responding" Red;return $false}}
function Get-AvailablePythonVersions{Write-ColorOutput "Querying available Python versions..." Yellow;try{$o=& py list --online 2>&1;$v=($o|ForEach-Object{if($_ -match '(\d+\.\d+\.\d+)'){ $matches[1]}})|Where-Object{$_ -match '^3\.\d+\.\d+$'};if(@($v).Length -eq 0){throw "no versions"};return $v|Sort-Object {[version]$_} -Descending}catch{Write-ColorOutput "Fallback list used" Yellow;return @("3.13.0","3.12.1","3.11.7","3.10.12","3.9.18")}}
function Get-InstalledPythonVersions{Write-ColorOutput "Listing installed runtimes..." Yellow;try{$o=& py list 2>&1;($o|ForEach-Object{if($_ -match '(\d+\.\d+\.\d+)'){ $matches[1]}})|Where-Object{$_ -match '^3\.\d+\.\d+$'}catch{Write-ColorOutput "Could not list installed runtimes" Yellow;@()}}
function Show-VersionTable{param($Versions,$Installed)Write-ColorOutput "Latest Python versions:" Cyan;Write-Host "┌─────────────┬────────────┐" -ForegroundColor Gray;Write-Host "│ Version     │ Status     │" -ForegroundColor Gray;Write-Host "├─────────────┼────────────┤" -ForegroundColor Gray;foreach($v in $Versions){$status=if($Installed -contains $v){"INSTALLED"}else{"Available"};$c=if($status -eq "INSTALLED"){"Green"}else{"Yellow"};Write-Host "│ $($v.PadRight(11)) │ " -NoNewline -ForegroundColor Gray;Write-Host "$($status.PadRight(10))" -NoNewline -ForegroundColor $c;Write-Host " │" -ForegroundColor Gray}Write-Host "└─────────────┴────────────┘" -ForegroundColor Gray}
function Get-PythonExecutable{param($Version)try{if($Version){$exe=& py -$Version -c "import sys;print(sys.executable)" 2>$null;return $exe}else{return (Get-Command python -ErrorAction SilentlyContinue).Source}}catch{return $null}}
function New-PyVenv{param([string]$Path="venv",[string]$PythonVer="")if(Test-Path $Path){Write-ColorOutput "Path exists: $Path" Yellow;return $false}if($PythonVer){$exe=Get-PythonExecutable -Version $PythonVer;if(-not $exe){Write-ColorOutput "Requested Python $PythonVer not found" Red;return $false};Write-ColorOutput "Creating venv at $Path using $PythonVer" Yellow;& $exe -m venv $Path}else{Write-ColorOutput "Creating venv at $Path using default python" Yellow;& python -m venv $Path}if(Test-Path $Path){Write-ColorOutput "Venv created: $Path" Green;return $true}else{Write-ColorOutput "Venv creation failed" Red;return $false}}
function Remove-PyVenv{param([string]$Path="venv",[switch]$Force)if(-not(Test-Path $Path)){Write-ColorOutput "Venv not found: $Path" Yellow;return $false}if(-not($Force)){Write-ColorOutput "Removing venv $Path in 3 seconds. Press Ctrl-C to cancel" Yellow;Start-Sleep -Seconds 3}try{Remove-Item -LiteralPath $Path -Recurse -Force;Write-ColorOutput "Removed: $Path" Green;return $true}catch{Write-ColorOutput "Remove failed: $($_.Exception.Message)" Red;return $false}}
function Activate-Venv{param([string]$Path="venv")$act=Join-Path $Path "Scripts\Activate.ps1";if(-not(Test-Path $act)){Write-ColorOutput "Activation script not found at $act" Red;return $false};. $act;Write-ColorOutput "Activated venv: $Path" Green;return $true}
function Find-PyVenvs{param([string]$Root=(Get-Location).Path)[System.Collections.ArrayList]$list=@();Get-ChildItem -Path $Root -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue|ForEach-Object{if(Test-Path (Join-Path $_.FullName "pyvenv.cfg")){$list.Add($_.FullName)|Out-Null}};return $list}
function Show-Help{Write-ColorOutput "Helper commands" Cyan;Write-Host "  New-PyVenv -Path <dir> -PythonVer <3.11.4>" ;Write-Host "  Remove-PyVenv -Path <dir> -Force" ;Write-Host "  Activate-Venv -Path <dir>" ;Write-Host "  Get-PythonExecutable -Version <3.11>" ;Write-Host "  Get-AvailablePythonVersions" ;Write-Host "  Get-InstalledPythonVersions" ;Write-Host "  Find-PyVenvs -Root <path>"}
Clear-Host
Write-ColorOutput "=== Python Install Manager (pymanager) + venv helpers ===" Cyan
if(-not(Test-Admin)){Write-ColorOutput "Not running as admin. winget user scope will be used" Yellow}
if(-not(Ensure-WinGet)){Write-ColorOutput "winget missing. Script will try but may fail" Yellow}
if(-not(Install-PyManager)){Write-ColorOutput "pymanager install failed" Red;exit 1}
if(-not(Validate-Py)){Write-ColorOutput "py validation failed after install" Red;exit 1}
$all=(Get-AvailablePythonVersions)
$installed=(Get-InstalledPythonVersions)
$major=(Get-InstalledPythonVersions)
$latest=$all[0]
if($PythonVersion){$selected=$PythonVersion}else{Write-ColorOutput "Press Enter for latest ($latest) or type version: " -NoNewline;$i=Read-Host;if([string]::IsNullOrWhiteSpace($i)){$selected=$latest}else{$selected=$i.Trim();if($all -notcontains $selected){Write-ColorOutput "Unknown version requested, using latest $latest" Yellow;$selected=$latest}}}
Write-ColorOutput "Installing $selected" Cyan
if($installed -contains $selected){Write-ColorOutput "Already installed: $selected" Yellow}else{if(-not(Retry{& py install $selected}3 20)){Write-ColorOutput "Install failed" Red;exit 1}}
try{$parts=$selected -split '\.';$mm="$($parts[0]).$($parts[1])";[Environment]::SetEnvironmentVariable("PY_PYTHON",$mm,"User");Write-ColorOutput "Set PY_PYTHON=$mm for user" Green}catch{Write-ColorOutput "Could not set PY_PYTHON" Yellow}
Clear-Host
Write-ColorOutput "=== Validation ===" Cyan
try{$pv=& py -$mm --version 2>&1;Write-ColorOutput "py selected: $pv" Green}catch{Write-ColorOutput "py selected version check failed" Yellow}
try{$exe=Get-PythonExecutable -Version $mm;if($exe){Write-ColorOutput "Python executable: $exe" Green}else{Write-ColorOutput "python executable not found in PATH" Yellow}}catch{Write-ColorOutput "Validation error" Yellow}
Write-Host ""
Show-Help
Write-Host ""
Write-ColorOutput "🎉 Python $selected installation completed!" Green
Write-ColorOutput "Press Enter to close..." -NoNewline;Read-Host
