try{
Clear-Host
Write-Host "=== Engine Installation Script for Windows ===`n"
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $os";Write-Host "Detected architecture: $arch";Write-Host "User home: $userHome`n"

function Run-Exec($exe,$args){
  try{
    if($args -and $args.Count -gt 0){ $out = & $exe @args 2>&1 } else { $out = & $exe 2>&1 }
    return @{Ok=$true;Out=($out);Exit=$LASTEXITCODE}
  }catch{ return @{Ok=$false;Out=$_.Exception.Message;Exit=$null} }
}

if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ Write-Error "winget not found. Install App Installer or enable winget and re-run script."; Exit 1 }

$g=Get-Command pymanager -ErrorAction SilentlyContinue
$pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
$g2=Get-Command py -ErrorAction SilentlyContinue
$pyCmd=if($g2){ if($g2.Path){ $g2.Path } else { $g2.Name } } else { $null }

if(-not $pymgrCmd){
  Write-Host "PyManager not found. Attempting winget install (id 9NQ7512CXL7T)..." 
  $r=Run-Exec 'winget' @('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements')
  if(-not $r.Ok -or ($r.Exit -ne 0 -and $r.Exit -ne $null)){ Write-Warning "winget install failed or returned nonzero. PyManager may still be unavailable. Install manually if needed." }
  Start-Sleep -Seconds 1
  $g=Get-Command pymanager -ErrorAction SilentlyContinue
  $pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
  if($pymgrCmd){ Write-Host "PyManager detected: $pymgrCmd" } else { Write-Host "PyManager still not detected in this session. You may need to open a new terminal after installation." }
} else { Write-Host "PyManager detected: $pymgrCmd. Skipping install." }

Write-Host "`n=== Python Version Selection ===`n"

$onlineJson=""
if($pyCmd){
  $r=Run-Exec $pyCmd @('list','--online','-f','json')
  if($r.Ok -and $r.Out){ $onlineJson = ($r.Out -join "`n") }
}
if(-not $onlineJson -and $pymgrCmd){
  $r=Run-Exec $pymgrCmd @('list','--online','-f','json')
  if($r.Ok -and $r.Out){ $onlineJson = ($r.Out -join "`n") }
}
if(-not $onlineJson){
  try{ $resp=Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/' -ErrorAction Stop; $text=$resp.Content } catch { $text = $null }
  if($text){ $matches=[System.Text.RegularExpressions.Regex]::Matches($text,'3\.\d+\.\d+') | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending; $online = $matches } else { Write-Error "Could not retrieve Python version list"; Exit 1 }
} else {
  try{ $json = $onlineJson | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }
  if($json -ne $null){
    $online = @()
    foreach($item in $json){
      if($item.tag){ $online += $item.tag } elseif($item.version){ $online += $item.version } else {
        $s = ($item | Select-Object -ExpandProperty name -ErrorAction SilentlyContinue)
        if($s){ $online += $s }
      }
    }
    $online = $online | Where-Object { $_ -match '^3\.\d+\.\d+$' } | Sort-Object -Unique -Descending
  } else { Write-Warning "Failed to parse JSON from py/pymanager; falling back to python.org listing"; $resp=Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/' -ErrorAction Stop; $matches=[System.Text.RegularExpressions.Regex]::Matches($resp.Content,'3\.\d+\.\d+') | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending; $online = $matches }
}

$verObjs = $online | ForEach-Object { try{ [version]$_ } catch { $null } } | Where-Object { $_ -ne $null } | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){ if($v.Major -eq 3 -and $v.Minor -ge 10){ $k=('{0}.{1}' -f $v.Major,$v.Minor); if(-not $map.ContainsKey($k)){ $map[$k]=$v.ToString() } } }
if($map.Count -eq 0){ Write-Error "No Python 3.10+ versions found"; Exit 1 }
$latestPerMajor = $map.Values | Sort-Object {[version]$_} -Descending
$LATEST = $latestPerMajor[0]

Write-Host "Latest versions of each Python major release (3.10+):"
"{0,-14} {1,-12}" -f "Version","Status" | Write-Host

$installed=@()
if($pyCmd){
  $r=Run-Exec $pyCmd @('list','-f','json','--installed')
  if($r.Ok -and $r.Out){
    try{ $instJson = ($r.Out -join "`n") | ConvertFrom-Json -ErrorAction Stop } catch { $instJson = $null }
    if($instJson){ foreach($it in $instJson){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } }
  } else {
    $r2=Run-Exec $pyCmd @('-0p')
    if($r2.Ok -and $r2.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r2.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
  }
}
$rpy=Run-Exec 'python' @('--version')
if($rpy.Ok -and $rpy.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($rpy.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
if($pymgrCmd -and -not $installed){
  $r3=Run-Exec $pymgrCmd @('list','-f','json','--installed')
  if($r3.Ok -and $r3.Out){ try{ $j=($r3.Out -join "`n") | ConvertFrom-Json -ErrorAction Stop } catch { $j=$null }; if($j){ foreach($it in $j){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } } }
}
$installed = $installed | Sort-Object -Unique -Descending

foreach($v in $latestPerMajor){ $isInstalled = $installed -contains $v; "{0,-14} {1,-12}" -f $v,(if($isInstalled){"INSTALLED"}else{"Available"}) | Write-Host }

Write-Host "`nCurrently installed versions:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  No versions detected via 'py','python' or 'pymanager' in PATH" }

Write-Host "`nLatest version: $LATEST`n"
$input=Read-Host "Enter the Python version to install or press Enter to use latest ($LATEST)"
if([string]::IsNullOrWhiteSpace($input)){ $SELECTED=$LATEST } else { $SELECTED=$input }
if(-not ($SELECTED -match '^\s*3\.\d+\.\d+\s*$')){ Write-Warning "Invalid version format. Using latest $LATEST"; $SELECTED=$LATEST }

$installedNow = $installed -contains $SELECTED
if($installedNow){ Write-Host "Python $SELECTED already installed, skipping installation" } else {
  if($pymgrCmd){
    Write-Host "Installing Python $SELECTED via PyManager..."
    $r=Run-Exec $pymgrCmd @('install',$SELECTED)
    if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed or produced no output: $($r.Out)" }
  } elseif($pyCmd){
    Write-Host "Installing Python $SELECTED via py..."
    $r=Run-Exec $pyCmd @('install',$SELECTED)
    if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed: $($r.Out)" }
  } else { Write-Warning "No install manager available to install $SELECTED" }
}

Write-Host "`nSetting Python $SELECTED as user default (best-effort)..."
try{ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User'); Write-Host "Set PYTHON_MANAGER_DEFAULT=$SELECTED (User)" } catch { Write-Warning "Failed to set user env var: $($_.Exception.Message)" }

Write-Host "`n=== Installation Complete ===`n"
$rA=Run-Exec 'python' @('--version')
Write-Host "Active python: " -NoNewline
if($rA.Ok -and $rA.Out){ Write-Host -ForegroundColor Green ($rA.Out -join ' ') } else { Write-Host "Not found" }
$cmd=Get-Command python -ErrorAction SilentlyContinue
if($cmd){ Write-Host "Python location: $($cmd.Path)" } else { Write-Host "Python location: Not found" }
$cmdpip=Get-Command pip -ErrorAction SilentlyContinue
if($cmdpip){ Write-Host "pip location: $($cmdpip.Path)" } else { Write-Host "pip location: Not found" }

Write-Host "`nInstalled Python versions detected:"
if($installed){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  None detected" }

Write-Host "`n=== Usage Examples for Python $SELECTED ==="
Write-Host "  List available versions (online): py list --online -f json"
Write-Host "  List installed versions: py list -f json --installed   or   py -0p"
Write-Host "  Install specific version: py install 3.x.x   or   pymanager install 3.x.x"
Write-Host "  Uninstall version: py uninstall 3.x.x   or   pymanager uninstall 3.x.x"
Write-Host "  Set user default (best-effort): set PYTHON_MANAGER_DEFAULT=$SELECTED in User env vars"
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
