try{
Clear-Host
Write-Host "=== Engine Installation Script for Windows ===`n"
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $os";Write-Host "Detected architecture: $arch";Write-Host "User home: $userHome`n"
if(-not (Get-Command winget -ErrorAction SilentlyContinue)){Write-Error "winget not found. Install App Installer or enable winget and re-run script.";exit 1}
Write-Host "Installing Python Install Manager (PyManager) via winget..."
$wgArgs='install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements'
$proc=Start-Process -FilePath winget -ArgumentList $wgArgs -Wait -NoNewWindow -PassThru
if($proc.ExitCode -ne 0){Write-Warning "winget install returned $($proc.ExitCode). Attempting to open Store page.";Start-Process "ms-windows-store://pdp/?productid=9NQ7512CXL7T"}
Start-Sleep -Seconds 2
if(-not (Get-Command py -ErrorAction SilentlyContinue) -and -not (Get-Command pymanager -ErrorAction SilentlyContinue)){Write-Warning "py or pymanager command not available yet; you may need to open a new terminal. Continuing."}
Write-Host "`n=== Python Version Selection ===`n"
$onlineRaw=& py list --online 2>$null
if(!$onlineRaw){$onlineRaw=& pymanager list --online 2>$null}
$allText=($onlineRaw -join "`n")
$regex='3\.\d+\.\d+'
$versions=Select-String -InputObject $allText -Pattern $regex -AllMatches | ForEach-Object{$_.Matches} | ForEach-Object{$_.Value} | Select-Object -Unique
if(-not $versions){Write-Error "Could not retrieve Python version list";exit 1}
$verObjs=$versions | ForEach-Object {[version]$_} | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){$k=("{0}.{1}" -f $v.Major,$v.Minor);if(-not $map.ContainsKey($k)){$map[$k]=$v.ToString()}}
$latestPerMajor=$map.Values | Sort-Object {[version]$_} -Descending
$LATEST=$latestPerMajor[0]
Write-Host "Latest versions of each Python major release (3.10+):"
"{0,-12} {1,-10}" -f "Version","Status" | Write-Host
foreach($v in $latestPerMajor){$installed=( (& py list 2>$null) -join "`n") -match "\b$([regex]::Escape($v))\b";"{0,-12} {1,-10}" -f $v, (if($installed){"INSTALLED"}else{"Available"}) | Write-Host}
Write-Host "`nCurrently installed versions:"; & py list 2>$null
Write-Host "`nLatest version: $LATEST`n"
$input=Read-Host "Enter the Python version to install or press Enter to use latest ($LATEST)"
if([string]::IsNullOrWhiteSpace($input)){ $SELECTED=$LATEST }else{ $SELECTED=$input }
if(-not ($SELECTED -match '^\s*3\.\d+\.\d+\s*$')){Write-Warning "Invalid version format. Using latest $LATEST";$SELECTED=$LATEST}
$installedNow=( (& py list 2>$null) -join "`n") -match "\b$([regex]::Escape($SELECTED))\b"
if($installedNow){Write-Host "Python $SELECTED already installed, skipping installation"}else{Write-Host "Installing Python $SELECTED (may prompt for elevation)...";& py install $SELECTED}
Write-Host "Setting Python $SELECTED as user default (PYTHON_MANAGER_DEFAULT)..."
[Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User')
Write-Host "`n=== Installation Complete ===`n"
Write-Host "Active python: $(python --version 2>&1)"
$cmd=Get-Command python -ErrorAction SilentlyContinue
if($cmd){Write-Host "Python location: $($cmd.Source)"}else{Write-Host "Python location: Not found"}
Write-Host "`nInstalled Python versions:"; & py list 2>$null
Write-Host "`n=== Usage Examples for Python $SELECTED ==="
Write-Host "  List available versions: py list --online"
Write-Host "  Install specific version: py install 3.x.x"
Write-Host "  Uninstall version: py uninstall 3.x.x"
Write-Host "  Set user default: [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT','3.x','User')"
Write-Host "`nImportant notes: PyManager is the official Windows Python install manager; winget id used: 9NQ7512CXL7T"
Exit 0
}catch{
Write-Error $_.Exception.Message
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){Read-Host 'Press Enter to close...'}
}
