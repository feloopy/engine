try{
Clear-Host
Write-Host "=== Engine Installation Script for Windows ===`n"
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $os";Write-Host "Detected architecture: $arch";Write-Host "User home: $userHome`n"

function Run-Exec($cmd,$args){
  try{ $out = if($args){ & $cmd @args 2>&1 } else { & $cmd 2>&1 }; return @{Ok=$true;Out=$out;Exit=$LASTEXITCODE} } catch { return @{Ok=$false;Out=$_.Exception.Message;Exit=$null} }
}

if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ Write-Error "winget not found. Install App Installer or enable winget and re-run script."; Exit 1 }

$g=Get-Command pymanager -ErrorAction SilentlyContinue
$pymgrCmd = if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
$g2=Get-Command py -ErrorAction SilentlyContinue
$pyCmd = if($g2){ if($g2.Path){ $g2.Path } else { $g2.Name } } else { $null }

if($pymgrCmd){ Write-Host "PyManager detected: $pymgrCmd. Skipping winget install." } else {
  Write-Host "PyManager not found. Attempting winget install (id 9NQ7512CXL7T)..."
  $r=Run-Exec 'winget' @('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements')
  if(-not $r.Ok -or ($r.Exit -ne 0 -and $r.Exit -ne $null)){ Write-Warning "winget install failed or returned nonzero. PyManager may still be unavailable." } else { Start-Sleep -Seconds 1; $g=Get-Command pymanager -ErrorAction SilentlyContinue; $pymgrCmd = if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }; if($pymgrCmd){ Write-Host "PyManager installed: $pymgrCmd" } else { Write-Warning "winget reported success but pymanager command not found in this session." } }
}

Write-Host "`n=== Python Version Selection ===`n"

$allText=""
if($pymgrCmd){
  $r=Run-Exec $pymgrCmd @('list','--online')
  if($r.Ok -and $r.Out){ $allText = ($r.Out -join "`n") }
}
if(-not $allText){
  try{ $resp=Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/' -ErrorAction Stop; $allText=$resp.Content } catch { Write-Warning "Failed to fetch python.org listing: $($_.Exception.Message)"; $allText='' }
}
if(-not $allText){ Write-Error "Could not retrieve Python version list"; Exit 1 }

$regex='3\.\d+\.\d+'
$matches=[System.Text.RegularExpressions.Regex]::Matches($allText,$regex) | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending
if(-not $matches){ Write-Error "No Python versions found"; Exit 1 }

$verObjs = $matches | ForEach-Object { try{ [version]$_ } catch { $null } } | Where-Object { $_ -ne $null } | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){ if($v.Major -eq 3 -and $v.Minor -ge 10){ $k=('{0}.{1}' -f $v.Major,$v.Minor); if(-not $map.ContainsKey($k)){ $map[$k]=$v.ToString() } } }
if($map.Count -eq 0){ Write-Error "No Python 3.10+ versions found"; Exit 1 }
$latestPerMajor = $map.Values | Sort-Object {[version]$_} -Descending
$LATEST = $latestPerMajor[0]

Write-Host "Latest versions of each Python major release (3.10+):"
"{0,-12} {1,-10}" -f "Version","Status" | Write-Host

$installed=@()
if($pyCmd){
  $r=Run-Exec $pyCmd @('-0')
  if($r.Ok -and $r.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
}
$r2=Run-Exec 'python' @('--version')
if($r2.Ok -and $r2.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r2.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
if($pymgrCmd){
  $r3=Run-Exec $pymgrCmd @('list','--installed')
  if($r3.Ok -and $r3.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r3.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
}
$installed = $installed | Sort-Object -Unique -Descending

foreach($v in $latestPerMajor){ $isInstalled = $installed -contains $v; "{0,-12} {1,-10}" -f $v,(if($isInstalled){"INSTALLED"}else{"Available"}) | Write-Host }

Write-Host "`nCurrently installed versions:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  No versions detected via 'py', 'python' or PyManager" }

Write-Host "`nLatest version: $LATEST`n"
$input=Read-Host "Enter the Python version to install or press Enter to use latest ($LATEST)"
if([string]::IsNullOrWhiteSpace($input)){ $SELECTED=$LATEST } else { $SELECTED=$input }
if(-not ($SELECTED -match '^\s*3\.\d+\.\d+\s*$')){ Write-Warning "Invalid version format. Using latest $LATEST"; $SELECTED=$LATEST }

$installedNow = $installed -contains $SELECTED
if($installedNow){ Write-Host "Python $SELECTED already installed, skipping installation" } else {
  if($pymgrCmd){ Write-Host "Installing Python $SELECTED via PyManager..."; $r=Run-Exec $pymgrCmd @('install',$SELECTED); if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed: $($r.Out)" } } else { Write-Warning "PyManager not available. Cannot install $SELECTED from this script." }
}

Write-Host "`nSetting Python $SELECTED as user default..."
[Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User')
Write-Host "`n=== Installation Complete ===`n"
$rA=Run-Exec 'python' @('--version')
Write-Host "Active python: " -NoNewline; if($rA.Ok -and $rA.Out){ Write-Host -ForegroundColor Green ($rA.Out -join ' ') } else { Write-Host "Not found" }
$cmd=Get-Command python -ErrorAction SilentlyContinue
if($cmd){ Write-Host "Python location: $($cmd.Path)"} else { Write-Host "Python location: Not found" }
$cmdpip=Get-Command pip -ErrorAction SilentlyContinue
if($cmdpip){ Write-Host "pip location: $($cmdpip.Path)"} else { Write-Host "pip location: Not found" }

Write-Host "`nInstalled Python versions detected:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  None detected" }

Write-Host "`n=== Usage Examples for Python $SELECTED ==="
Write-Host "  List available versions: pymanager list --online   or visit https://www.python.org/ftp/python/"
Write-Host "  Install specific version: pymanager install 3.x.x"
Write-Host "  Uninstall version: pymanager uninstall 3.x.x"
Write-Host "  Set user default: [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT','3.x','User')"
Write-Host "`n=== Important Notes ==="
Write-Host "  To use new commands in this session open a new terminal"
Write-Host "  System architecture: $arch"
Write-Host "  Package manager: winget"
Exit 0
}catch{
Write-Error $_.Exception.Message
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
