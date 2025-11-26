try{
Clear-Host
Write-Host "=== Engine Installation Script for Windows ===`n"
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $os";Write-Host "Detected architecture: $arch";Write-Host "User home: $userHome`n"

function Run-Exec($exe,$args){
  try{ $out=& $exe @args 2>&1; $ec=$LASTEXITCODE; return @{Ok=$true;Out=$out;Exit=$ec} }catch{ return @{Ok=$false;Out=$_.Exception.Message;Exit=$null} }
}

if(-not (Get-Command winget -ErrorAction SilentlyContinue)){Write-Error "winget not found. Install App Installer or enable winget and re-run script.";Exit 1}

$pymgrCmd=(Get-Command pymanager -ErrorAction SilentlyContinue)?.Name
$pyCmd=(Get-Command py -ErrorAction SilentlyContinue)?.Name

if($pymgrCmd){ Write-Host "PyManager detected as: $pymgrCmd. Skipping PyManager install." }
else{
  Write-Host "PyManager not detected. Attempting winget install (id 9NQ7512CXL7T)..."
  $args=@('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements')
  $r=Run-Exec 'winget' $args
  if(-not $r.Ok -or $r.Exit -ne 0){
    $pymgrCmd=(Get-Command pymanager -ErrorAction SilentlyContinue)?.Name
    if(-not $pymgrCmd){ Write-Warning "winget install failed or returned nonzero. PyManager still not found. Will not open store automatically. To continue, install PyManager manually."; }
    else{ Write-Host "PyManager appears installed after winget." }
  }else{ Start-Sleep -Seconds 1; $pymgrCmd=(Get-Command pymanager -ErrorAction SilentlyContinue)?.Name; if($pymgrCmd){ Write-Host "PyManager installed." } else { Write-Warning "winget reported success but PyManager command not found. You may need to open a new terminal." } }
}

Write-Host "`n=== Python Version Selection ===`n"

$allText=""
if($pymgrCmd){
  $r=Run-Exec $pymgrCmd @('list','--online')
  if($r.Ok){ $allText = ($r.Out -join "`n") }
  else{ Write-Warning "pymanager list failed: $($r.Out). Falling back to python.org listing." }
}
if(-not $allText){
  try{ $resp=Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/'; $allText=$resp.Content }catch{ Write-Warning "Failed to fetch python.org listing: $($_.Exception.Message)"; $allText='' }
}
if(-not $allText){ Write-Error "Could not retrieve Python version list"; Exit 1 }

$regex='3\.\d+\.\d+'
$versions=[System.Text.RegularExpressions.Regex]::Matches($allText,$regex) | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending
if(-not $versions){ Write-Error "No Python versions found"; Exit 1 }

$verObjs=$versions | ForEach-Object {[version]$_} | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){ $k=("{0}.{1}" -f $v.Major,$v.Minor); if(-not $map.ContainsKey($k) -and $v.Major -eq 3 -and $v.Minor -ge 10){ $map[$k]=$v.ToString() } }
if($map.Count -eq 0){ Write-Error "No Python 3.10+ versions found"; Exit 1 }
$latestPerMajor=$map.Values | Sort-Object {[version]$_} -Descending
$LATEST=$latestPerMajor[0]

Write-Host "Latest versions of each Python major release (3.10+):"
"{0,-12} {1,-10}" -f "Version","Status" | Write-Host

$installed=@()
if($pyCmd){
  $r=Run-Exec $pyCmd @('-0p')
  if($r.Ok -and $r.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
}
$r2=Run-Exec 'python' @('--version')
if($r2.Ok -and $r2.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r2.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
$installed = $installed | Sort-Object -Unique -Descending

foreach($v in $latestPerMajor){ $isInstalled = $installed -contains $v; "{0,-12} {1,-10}" -f $v,(if($isInstalled){"INSTALLED"}else{"Available"}) | Write-Host }

Write-Host "`nCurrently installed versions:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  No versions detected via 'py' or 'python' in PATH" }

Write-Host "`nLatest version: $LATEST`n"
$input=Read-Host "Enter the Python version to install or press Enter to use latest ($LATEST)"
if([string]::IsNullOrWhiteSpace($input)){ $SELECTED=$LATEST }else{ $SELECTED=$input }
if(-not ($SELECTED -match '^\s*3\.\d+\.\d+\s*$')){ Write-Warning "Invalid version format. Using latest $LATEST"; $SELECTED=$LATEST }

$installedNow = $installed -contains $SELECTED
if($installedNow){ Write-Host "Python $SELECTED already installed, skipping installation" }
else{
  if($pymgrCmd){
    Write-Host "Installing Python $SELECTED via PyManager..."
    $r=Run-Exec $pymgrCmd @('install',$SELECTED)
    if($r.Ok -and ($r.Exit -eq 0 -or -not $r.Exit)){ Write-Host "Python $SELECTED install attempt finished. Check output above." } else { Write-Warning "Install returned nonzero or failed: $($r.Out)" }
  }else{ Write-Warning "PyManager not available. Cannot install $SELECTED from this script." }
}

[Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User')

Write-Host "`n=== Installation Complete ===`n"
$r3=Run-Exec 'python' @('--version')
Write-Host "Active python: $($r3.Out -join ' ' )"
$cmd=Get-Command python -ErrorAction SilentlyContinue
if($cmd){ Write-Host "Python location: $($cmd.Source)" } else { Write-Host "Python location: Not found" }

Write-Host "`nInstalled Python versions detected:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  None detected" }

Write-Host "`n=== Usage Examples for Python $SELECTED ==="
Write-Host "  List available versions: pymanager list --online  (if PyManager present) or visit https://www.python.org/ftp/python/"
Write-Host "  Install specific version: pymanager install 3.x.x"
Write-Host "  Uninstall version: pymanager uninstall 3.x.x"
Write-Host "  Set user default: [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT','3.x','User')"

Exit 0
}catch{
Write-Error $_.Exception.Message
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
