try{
Clear-Host
$userHome=$env:USERPROFILE
$arch=if($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'x86_64'}elseif($env:PROCESSOR_ARCHITECTURE -eq 'ARM64'){'aarch64'}else{$env:PROCESSOR_ARCHITECTURE}
$os=(Get-CimInstance Win32_OperatingSystem).Caption
Write-Host "=== Engine Installation Script for Windows ===`nDetected OS: $os; Architecture: $arch; Home: $userHome`n"

function Run-Exec($exe,$args,$timeoutSec=15){
  try{
    $p=New-Object System.Diagnostics.Process
    $p.StartInfo.FileName=$exe
    $escaped=@()
    if($args){
      foreach($a in $args){
        $s=[string]$a
        $s=$s -replace '"','\"'
        if($s -match '\s' -or $s -eq ''){ $s = '"' + $s + '"' }
        $escaped += $s
      }
    }
    $p.StartInfo.Arguments = if($escaped){ [string]::Join(' ',$escaped) } else { '' }
    $p.StartInfo.UseShellExecute=$false
    $p.StartInfo.RedirectStandardOutput=$true
    $p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.CreateNoWindow=$true
    if(-not $p.Start()){ return @{Ok=$false;Out='failed to start';Exit=$null} }
    if(-not $p.WaitForExit($timeoutSec*1000)){ try{ $p.Kill() }catch{}; return @{Ok=$false;Out='timed out';Exit=$null} }
    $out=@()
    $so=$p.StandardOutput.ReadToEnd(); $se=$p.StandardError.ReadToEnd()
    if($so){ $out += $so.Split("`n") | ForEach-Object{ $_.TrimEnd("`r") } }
    if($se){ $out += $se.Split("`n") | ForEach-Object{ $_.TrimEnd("`r") } }
    return @{Ok=$true;Out=$out;Exit=$p.ExitCode}
  }catch{ return @{Ok=$false;Out=$_.Exception.Message;Exit=$null} }
}

function Read-Input-Timeout($prompt,$default,$timeoutSec=30){
  try{
    if(-not $Host.UI.RawUI){ return $default }
  }catch{ return $default }
  Write-Host -NoNewline "$prompt"
  $sb=New-Object System.Text.StringBuilder
  $start=[datetime]::UtcNow
  while((( [datetime]::UtcNow)-$start ).TotalSeconds -lt [double]$timeoutSec){
    if([Console]::KeyAvailable){
      $k=[Console]::ReadKey($true)
      if($k.Key -eq 'Enter'){ break }
      if($k.Key -eq 'Backspace'){ if($sb.Length -gt 0){ $sb.Remove($sb.Length-1,1) | Out-Null; [Console]::Write("`b `b") } ; continue }
      $sb.Append($k.KeyChar) | Out-Null; [Console]::Write($k.KeyChar)
    } else { Start-Sleep -Milliseconds 80 }
  }
  [Console]::WriteLine()
  $res=$sb.ToString().Trim()
  if([string]::IsNullOrWhiteSpace($res)){ return $default } else { return $res }
}

function Safe-WebContent($uri,$timeoutSec=15){
  try{ return (Invoke-WebRequest -Uri $uri -TimeoutSec $timeoutSec -ErrorAction Stop).Content } catch { return $null }
}

$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
if(-not $hasWinget){ Write-Warning "winget not found. Script will continue but installing via winget will not be available." }

$g=Get-Command pymanager -ErrorAction SilentlyContinue; $pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null }
$g2=Get-Command py -ErrorAction SilentlyContinue; $pyCmd=if($g2){ if($g2.Path){ $g2.Path } else { $g2.Name } } else { $null }

if(-not $pymgrCmd -and $hasWinget){
  Write-Host "Attempting to install PyManager via winget..."
  $r=Run-Exec 'winget' @('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements') 120
  if($r.Ok){ Start-Sleep -Seconds 1; $g=Get-Command pymanager -ErrorAction SilentlyContinue; $pymgrCmd=if($g){ if($g.Path){ $g.Path } else { $g.Name } } else { $null } }
}

Write-Host "`n=== Python Version Selection ===`n"
$online=@()
if($pyCmd){ $r=Run-Exec $pyCmd @('list','--online','-f','json') 10; if($r.Ok -and $r.Out){ try{ $j=($r.Out -join "`n")|ConvertFrom-Json -ErrorAction Stop } catch{ $j=$null }; if($j){ foreach($it in $j){ if($it.tag){ $online += $it.tag } elseif($it.version){ $online += $it.version } elseif($it.name){ $online += $it.name } } } } }
if($online.Count -eq 0 -and $pymgrCmd){ $r=Run-Exec $pymgrCmd @('list','--online','-f','json') 10; if($r.Ok -and $r.Out){ try{ $j=($r.Out -join "`n")|ConvertFrom-Json -ErrorAction Stop } catch{ $j=$null }; if($j){ foreach($it in $j){ if($it.tag){ $online += $it.tag } elseif($it.version){ $online += $it.version } elseif($it.name){ $online += $it.name } } } } }
if($online.Count -eq 0){ $t=Safe-WebContent 'https://www.python.org/ftp/python/' 12; if($t){ $online=[System.Text.RegularExpressions.Regex]::Matches($t,'3\.\d+\.\d+') | ForEach-Object{$_.Value} | Sort-Object -Unique -Descending } }

$online = $online | Where-Object { $_ -match '^3\.\d+\.\d+$' } | Sort-Object -Unique -Descending
$verObjs = $online | ForEach-Object { try{ [version]$_ } catch { $null } } | Where-Object { $_ -ne $null } | Sort-Object -Descending
$map=@{}
foreach($v in $verObjs){ if($v.Major -eq 3 -and $v.Minor -ge 10){ $k=('{0}.{1}' -f $v.Major,$v.Minor); if(-not $map.ContainsKey($k)){ $map[$k]=$v.ToString() } } }
$latestPerMajor = @(); if($map.Count -gt 0){ $latestPerMajor = $map.Values | Sort-Object {[version]$_} -Descending }
$LATEST = if($latestPerMajor.Count -gt 0){ $latestPerMajor[0] } else { '' }

$installed=@()
if($pyCmd){ $r=Run-Exec $pyCmd @('list','-f','json','--installed') 8; if($r.Ok -and $r.Out){ try{ $inst=($r.Out -join "`n")|ConvertFrom-Json -ErrorAction Stop } catch{ $inst=$null }; if($inst){ foreach($it in $inst){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } } } else { $r2=Run-Exec $pyCmd @('-0p') 6; if($r2.Ok -and $r2.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($r2.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) } } }
$rpy=Run-Exec 'python' @('--version') 4; if($rpy.Ok -and $rpy.Out){ $installed += ([System.Text.RegularExpressions.Regex]::Matches(($rpy.Out -join "`n"),'\d+\.\d+\.\d+') | ForEach-Object{$_.Value}) }
if($pymgrCmd -and -not $installed){ $r3=Run-Exec $pymgrCmd @('list','-f','json','--installed') 8; if($r3.Ok -and $r3.Out){ try{ $j=($r3.Out -join "`n")|ConvertFrom-Json -ErrorAction Stop } catch{ $j=$null }; if($j){ foreach($it in $j){ if($it.tag){ $installed += $it.tag } elseif($it.version){ $installed += $it.version } } } } }
$installed = $installed | Sort-Object -Unique -Descending

if($latestPerMajor.Count -gt 0){ Write-Host "Latest (3.10+):"; "{0,-14} {1,-12}" -f "Version","Status" | Write-Host; foreach($v in $latestPerMajor){ $isInstalled=$installed -contains $v; "{0,-14} {1,-12}" -f $v,(if($isInstalled){"INSTALLED"}else{"Available"}) | Write-Host } } else { Write-Host "No online latest versions discovered" }

Write-Host "`nInstalled versions:"; if($installed.Count -gt 0){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  none detected" }

$menu=@()
if($online.Count -gt 0){ $menu += $online[0..([math]::Min(4,$online.Count-1))] }
if($installed.Count -gt 0){ foreach($i in $installed){ if(-not ($menu -contains $i)){ $menu += $i } } }
if($menu.Count -eq 0){ $menu += @('3.11.6','3.10.12') }

Write-Host "`nChoose a version or press Enter for default:"
for($i=0;$i -lt $menu.Count;$i++){ Write-Host ("  [{0}] {1}" -f ($i+1), $menu[$i]) }
$defaultVersion = if($LATEST){ $LATEST } elseif($installed.Count -gt 0){ $installed[0] } else { $menu[0] }
$inp = Read-Input-Timeout "Enter number or version (default $defaultVersion): " $defaultVersion 30
if($inp -match '^\d+$'){ $idx=[int]$inp-1; if($idx -ge 0 -and $idx -lt $menu.Count){ $sel=$menu[$idx] } else { $sel=$defaultVersion } } else { $sel = if([string]::IsNullOrWhiteSpace($inp)){$defaultVersion}else{$inp} }
if(-not ($sel -match '^\s*3\.\d+\.\d+\s*$')){ Write-Warning "Bad format. Using $defaultVersion"; $sel=$defaultVersion }
$SELECTED=$sel.Trim()

if($installed -contains $SELECTED){ Write-Host "Python $SELECTED already installed; skipping install" } else {
  if($pymgrCmd){ Write-Host "Installing $SELECTED via PyManager..."; $r=Run-Exec $pymgrCmd @('install',$SELECTED) 600; if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed: $($r.Out)" } }
  elseif($pyCmd){ Write-Host "Installing $SELECTED via py..."; $r=Run-Exec $pyCmd @('install',$SELECTED) 600; if($r.Ok){ Write-Host "Install output:`n$($r.Out -join "`n")" } else { Write-Warning "Install failed: $($r.Out)" } }
  elseif($hasWinget){ Write-Host "Attempting winget install of Microsoft.Python.$($SELECTED.Split('.')[1])..."; $pkg = "Python.Python.$($SELECTED.Split('.')[1])"; $r=Run-Exec 'winget' @('install','--id',$pkg,'-e','--accept-source-agreements','--accept-package-agreements') 600; if(-not $r.Ok){ Write-Warning "winget install failed or package id not available" } }
  else { Write-Warning "No installer available to install $SELECTED on this system" }
}

if($SELECTED){ try{ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$SELECTED,'User'); Write-Host "Set PYTHON_MANAGER_DEFAULT=$SELECTED (User)" } catch{ Write-Warning "Could not set user env var" } }

Write-Host "`n=== Summary ==="
$rA=Run-Exec 'python' @('--version') 4; Write-Host "Active python:" -NoNewline; if($rA.Ok -and $rA.Out){ Write-Host -ForegroundColor Green ($rA.Out -join ' ') } else { Write-Host " Not found" }
$cmd=Get-Command python -ErrorAction SilentlyContinue; if($cmd){ Write-Host "Python location: $($cmd.Path)" } else { Write-Host "Python location: Not found" }
$cmdpip=Get-Command pip -ErrorAction SilentlyContinue; if($cmdpip){ Write-Host "pip location: $($cmdpip.Path)" } else { Write-Host "pip location: Not found" }
Write-Host "`nDetected installed versions:"; if($installed.Count -gt 0){ $installed | ForEach-Object{ Write-Host "  $_" } } else { Write-Host "  None detected" }
Write-Host "`nTo apply environment changes open a new terminal.`n"

Exit 0
}catch{
Write-Error $_.Exception.Message
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
