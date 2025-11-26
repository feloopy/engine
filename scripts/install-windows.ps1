try{
Clear-Host
Write-Host "=== Engine Installation Script for Windows ===`n"
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "Detected OS: $os";Write-Host "Detected architecture: $arch";Write-Host "User home: $userHome`n"

function Run-Exec($exe,$args,$timeoutSec=15){
  try{
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo.FileName = $exe
    $escapedArgs = @()
    if($args){ foreach($a in $args){ if($a -match '\s'){ $escapedArgs += ('"{0}"' -f $a) } else { $escapedArgs += $a } } ; $p.StartInfo.Arguments = [string]::Join(' ',$escapedArgs) } else { $p.StartInfo.Arguments = '' }
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    $p.StartInfo.CreateNoWindow = $true
    $started = $p.Start()
    if(-not $started){ return @{Ok=$false;Out='Failed to start';Exit=$null} }
    if(-not $p.WaitForExit($timeoutSec*1000)){ try{ $p.Kill() }catch{}; return @{Ok=$false;Out='Timed out';Exit=$null} }
    $out = @()
    $so = $p.StandardOutput.ReadToEnd()
    $se = $p.StandardError.ReadToEnd()
    if($so){ $out += $so.Split("`n") | ForEach-Object{ $_.TrimEnd("`r") } }
    if($se){ $out += $se.Split("`n") | ForEach-Object{ $_.TrimEnd("`r") } }
    return @{Ok=$true;Out=$out;Exit=$p.ExitCode}
  }catch{ return @{Ok=$false;Out=$_.Exception.Message;Exit=$null} }
}

function Safe-InvokeWeb($uri,$timeoutSec=15){
  try{ return (Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec $timeoutSec -ErrorAction Stop).Content } catch { return $null }
}

if(-not (Get-Command winget -ErrorAction SilentlyContinue)){ Write-Error "winget not found. Install App Installer or enable winget and re-run script."; Exit 1 }

$g=Get-Command pymanager -ErrorAction SilentlyContinue
$pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
$g2=Get-Command py -ErrorAction SilentlyContinue
$pyCmd=if($g2){ if($g2.Path){ $g2.Path } else { $g2.Name } } else { $null }

if(-not $pymgrCmd){
  Write-Host "PyManager not found. Attempting winget install (id 9NQ7512CXL7T)..." 
  $r=Run-Exec 'winget' @('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements') 20
  if(-not $r.Ok -or ($r.Exit -ne 0 -and $r.Exit -ne $null)){ Write-Warning "winget install failed or returned nonzero. PyManager may still be unavailable. Install manually if needed." }
  Start-Sleep -Seconds 1
  $g=Get-Command pymanager -ErrorAction SilentlyContinue
  $pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
  if($pymgrCmd){ Write-Host "PyManager detected: $pymgrCmd" } else { Write-Host "PyManager still not detected in this session. You may need to open a new terminal after installation." }
} else { Write-Host "PyManager detected: $pymgrCmd. Skipping install." }

Write-Host "`n=== Python Version Selection ===`n"

$online = @()

$r = $null
if($pyCmd){
  $r = Run-Exec $pyCmd @('list','--online','-f','json') 10
  if($r.Ok -and $r.Out){ $onlineJson = ($r.Out -join "`n"); try{ $json = $onlineJson | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }; if($json){ foreach($item in $json){ if($item.tag){ $online += $item.tag } elseif($item.version){ $online += $item.version } elseif($item.name){ $online += $item.name } } } }
}
if(($online.Count -eq 0) -and $pymgrCmd){
  $r = Run-Exec $pymgrCmd @('list','--online','-f','json') 10
  if($r.Ok -and $r.Out){ $onlineJson = ($r.Out -join "`n"); try{ $json = $onlineJson | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }; if($json){ foreach($item in $json){ if($item.tag){ $online += $item.tag } elseif($item.version){ $online += $item.version } elseif($item.name){ $online += $item.name } } } }
}

if($online.Count -eq 0){
  $text = Safe-InvokeWeb 'https://www.python.org/ftp/python/' 15
  if($text){ $matches=[System.Text.RegularExpressions.Regex]::Matches($text,'3\.\d+\.\d+') | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending; $online = $matches }
}

$online = $online | Where-Object { $_ -match '^3\.\d+\.\d+$' } | Sort-Object -Unique -Descending

$verObjs = $online | ForEach-Object { try{ [version]$_ } catch { $null } } | Where-Object { $_ -ne $null } | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){ if($v.Major -eq 3 -and $v.Minor -ge 10){ $k=('{0}.{1}' -f $v.Major,$v.Minor); if(-not $map.ContainsKey($k)){ $map[$k]=$v.ToString() } } }
$latestPerMajor = @()
if($map.Count -gt 0){ $latestPerMajor = $map.Values | Sort-Object {[version]$_} -Descending }
$LATEST = if($latestPerMajor.Count -gt 0){ $latestPerMajor[0] } else { '' }

$installed=@()
if($pyCmd){
  $r=Run-Exec $pyCmd @('list','-f','json','--installed') 8
  if($r.Ok -and $r.Out){
    try{ $instJson = ($r.Out -join "`n") | ConvertFrom-Json -ErrorAction Stop } catch { $instJson = $null }
    if($instJson){ foreach($it in $instJson){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } }
  } else {
    $r2=Run-Exec $pyCmd @('-0p') 6
    if($r2.Ok -and $r2.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r2.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
  }
}
$rpy=Run-Exec 'python' @('--version') 4
if($rpy.Ok -and $rpy.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($rpy.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
if($pymgrCmd -and -not $installed){
  $r3=Run-Exec $pymgrCmd @('list','-f','json','--installed') 8
  if($r3.Ok -and $r3.Out){ try{ $j=($r3.Out -join "`n") | ConvertFrom-Json -ErrorAction Stop } catch { $j=$null }; if($j){ foreach($it in $j){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } } }
}
$installed = $installed | Sort-Object -Unique -Descending

if($latestPerMajor.Count -gt 0){
  Write-Host "Latest versions of each Python major release (3.10+):"
  "{0,-14} {1,-12}" -f "Version","Status" | Write-Host
  foreach($v in $latestPerMajor){ $isInstalled = $installed -contains $v; "{0,-14} {1,-12}" -f $v,(if($isInstalled){"INSTALLED"}else{"Available"}) | Write-Host }
} else {
  Write-Host "No online latest versions discovered"
}

Write-Host "`nCurrently installed versions:"
if($installed -and $installed.Count -gt 0){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  No versions detected via 'py','python' or 'pymanager' in PATH" }

$menu = @()
if($online.Count -gt 0){ $menu += $online[0..([math]::Min(4,$online.Count-1))] }
if($installed.Count -gt 0){ foreach($i in $installed){ if(-not ($menu -contains $i)){ $menu += $i } } }
if($menu.Count -eq 0){ $fallbacks = @('3.11.6','3.10.12'); foreach($f in $fallbacks){ if(-not ($menu -contains $f)){ $menu += $f } } }

Write-Host "`nSelect a Python version to install from the list below or press Enter to accept default:"
for($i=0;$i -lt $menu.Count;$i++){ Write-Host ("  [{0}] {1}" -f ($i+1), $menu[$i]) }
$defaultIndex = 0
$defaultVersion = if($LATEST){ $LATEST } elseif($installed.Count -gt 0){ $installed[0] } else { $menu[$defaultIndex] }

$selected = $null
try{
  if($Host.Name -eq 'ServerRemoteHost' -or -not $Host.UI.RawUI){
    $selected = $defaultVersion
    Write-Host "`nNoninteractive session detected. Using default: $selected"
  } else {
    $inp = Read-Host "Enter number or version (default $defaultVersion) [timeout 30s]"
    if([string]::IsNullOrWhiteSpace($inp)){ $selected = $defaultVersion } else {
      if($inp -match '^\d+$'){ $ni=[int]$inp-1; if($ni -ge 0 -and $ni -lt $menu.Count){ $selected = $menu[$ni] } else { $selected = $inp } } else { $selected = $inp }
    }
  }
}catch{ $selected = $defaultVersion; Write-Host "`nInput failed, using default: $selected" }

if(-not $selected){ $selected = $defaultVersion }

if(-not ($selected -match '^\s*3\.\d+\.\d+\s*$')){ Write-Warning "Invalid version format. Using default $defaultVersion"; $selected = $defaultVersion }
$SELECTED = $selected.Trim()

$installedNow = $installed -contains $SELECTED
if($installedNow){ Write-Host "Python $SELECTED already installed, skipping installation" } else {
  if($pymgrCmd){
    Write-Host "Installing Python $SELECTED via PyManager..."
    $r=Run-Exec $pymgrCmd @('install',$SELECTED) 300
    if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed or timed out: $($r.Out)" }
  } elseif($pyCmd){
    Write-Host "Installing Python $SELECTED via py..."
    $r=Run-Exec $pyCmd @('install',$SELECTED) 300
    if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed or timed out: $($r.Out)" }
  } else { Write-Warning "No install manager available to install $SELECTED" }
}

if($SELECTED){
  Write-Host "`nSetting Python $SELECTED as user default (best-effort)..."
  try{ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User'); Write-Host "Set PYTHON_MANAGER_DEFAULT=$SELECTED (User)" } catch { Write-Warning "Failed to set user env var: $($_.Exception.Message)" }
} else { Write-Warning "Skipping setting default because no selection was determined." }

Write-Host "`n=== Installation Complete ===`n"
$rA=Run-Exec 'python' @('--version') 4
Write-Host "Active python: " -NoNewline
if($rA.Ok -and $rA.Out){ Write-Host -ForegroundColor Green ($rA.Out -join ' ') } else { Write-Host "Not found" }
$cmd=Get-Command python -ErrorAction SilentlyContinue
if($cmd){ Write-Host "Python location: $($cmd.Path)" } else { Write-Host "Python location: Not found" }
$cmdpip=Get-Command pip -ErrorAction SilentlyContinue
if($cmdpip){ Write-Host "pip location: $($cmdpip.Path)" } else { Write-Host "pip location: Not found" }

Write-Host "`nInstalled Python versions detected:"
if($installed -and $installed.Count -gt 0){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  None detected" }

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
