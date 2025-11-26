try{
Clear-Host
$CHeader='Magenta'; $CInfo='Cyan'; $CPrompt='Yellow'; $CGood='Green'; $CBad='Red'

function Ensure-Pymanager {
  $p = Get-Command pymanager -ErrorAction SilentlyContinue
  if($p){ return $p }
  $w = Get-Command winget -ErrorAction SilentlyContinue
  if(-not $w){ Write-Host "pymanager and winget not found. Please install winget or pymanager and re-run." -ForegroundColor $CBad; Exit 2 }
  Write-Host "pymanager not found. Installing via winget (no prompts)..." -ForegroundColor $CInfo
  & winget install --id 9NQ7512CXL7T -e --accept-source-agreements --accept-package-agreements > $null 2>&1
  Start-Sleep -Seconds 2
  $p = Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $p){ Write-Host "pymanager still not available after winget install." -ForegroundColor $CBad; Exit 2 }
  Write-Host "pymanager installed." -ForegroundColor $CGood
  return $p
}

$pymgr = Ensure-Pymanager

Clear-Host
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
Write-Host "  Python runtimes (online >= 3.10 and installed) — pymanager" -ForegroundColor $CHeader
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader

Write-Host ">>> Online runtimes (filtered >= 3.10):" -ForegroundColor $CInfo
& $pymgr.Path list --online '>=3.10'
Write-Host "`n--------------------------------------------------`n" -ForegroundColor $CInfo
Write-Host ">>> Installed runtimes:" -ForegroundColor $CInfo
& $pymgr.Path list
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader

$promptText = "Enter tag or version to install/set (press Enter = install default/latest, or type 'skip' to uninstall mode):"
Write-Host $promptText -ForegroundColor $CPrompt -NoNewline
$sel = Read-Host ""

if($sel -and $sel.Trim().ToLower() -eq 'skip'){
  Clear-Host
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
  Write-Host "  Uninstall mode — installed runtimes" -ForegroundColor $CHeader
  Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader
  & $pymgr.Path list
  Write-Host "`nEnter tag to uninstall (exact tag), or 'all' to purge all managed installs, or press Enter to cancel." -ForegroundColor $CPrompt -NoNewline
  $tag = Read-Host ""
  if([string]::IsNullOrWhiteSpace($tag)){ Clear-Host; Write-Host "Uninstall cancelled." -ForegroundColor $CInfo; Exit 0 }
  if($tag -ieq 'all'){
    Clear-Host; Write-Host "Purging all managed installs (pymanager uninstall --purge -y)..." -ForegroundColor $CInfo
    & $pymgr.Path uninstall --purge -y
    Clear-Host; Write-Host "Purge requested. Done." -ForegroundColor $CGood; Exit 0
  } else {
    Clear-Host
    Write-Host ("About to uninstall: " + $tag) -ForegroundColor $CPrompt
    $confirm = Read-Host "Type Y to confirm"
    if($confirm -match '^[Yy]$'){ Write-Host ("Running: pymanager uninstall -y " + $tag) -ForegroundColor $CInfo; & $pymgr.Path uninstall -y $tag; Clear-Host; Write-Host "Uninstall requested." -ForegroundColor $CGood } else { Clear-Host; Write-Host "Uninstall cancelled." -ForegroundColor $CInfo }
    Exit 0
  }
}

$installArg = if([string]::IsNullOrWhiteSpace($sel)){ 'default' } else { $sel.Trim() }
Clear-Host
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
if($installArg -eq 'default'){ Write-Host "Installing default/latest runtime (pymanager install default)..." -ForegroundColor $CInfo; & $pymgr.Path install default }
else { Write-Host ("Installing: pymanager install " + $installArg) -ForegroundColor $CInfo; & $pymgr.Path install $installArg }
Write-Host "Installation step completed." -ForegroundColor $CGood

Write-Host "`nWould you like to set PYTHON_MANAGER_DEFAULT to this runtime/tag? [Y/n]" -ForegroundColor $CPrompt -NoNewline
$setDef = Read-Host " "
if([string]::IsNullOrWhiteSpace($setDef) -or $setDef -match '^[Yy]'){
  $verToSet = $null
  if($installArg -ne 'default'){
    $m = [regex]::Match($installArg,'\d+\.\d+\.\d+')
    if($m.Success){ $verToSet = $m.Value } else {
      $m2 = [regex]::Match($installArg,'\d+\.\d+')
      if($m2.Success){ $verToSet = $m2.Value }
    }
  } else {
    Write-Host "You installed the default runtime. Enter a specific version to set (e.g. 3.11.9), or press Enter to skip." -ForegroundColor $CPrompt -NoNewline
    $verPrompt = Read-Host " "
    if(-not [string]::IsNullOrWhiteSpace($verPrompt)){ $verToSet = $verPrompt.Trim() }
  }
  if(-not [string]::IsNullOrWhiteSpace($verToSet)){
    try{ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$verToSet,'User'); Write-Host ("Set PYTHON_MANAGER_DEFAULT=" + $verToSet + " (User)") -ForegroundColor $CGood } catch { Write-Host "Could not set PYTHON_MANAGER_DEFAULT." -ForegroundColor $CBad }
  } else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT." -ForegroundColor $CInfo }
} else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT." -ForegroundColor $CInfo }

Clear-Host
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
Write-Host "  Active python (probe via pymanager exec)" -ForegroundColor $CHeader
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader
if($installArg -eq 'default'){ & $pymgr.Path exec -- -c "import sys;print(sys.version);print(sys.executable)" }
else { & $pymgr.Path exec "-V:$installArg" -- -c "import sys;print(sys.version);print(sys.executable)" }

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
Write-Host "  Useful pymanager commands" -ForegroundColor $CHeader
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader
Write-Host "  List installed runtimes:" -ForegroundColor $CInfo; Write-Host "    pymanager list"
Write-Host "  List online runtimes (>=3.10):" -ForegroundColor $CInfo; Write-Host "    pymanager list --online '>=3.10'"
Write-Host "  Install a runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager install <TAG or version>    e.g. pymanager install 3.11.9"
Write-Host "  Create venv with runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager exec -V:<TAG> -- -m venv .venv"
Write-Host "    pymanager exec -3.11 -- -m venv .venv"
Write-Host "  Uninstall runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager uninstall <TAG>    or    pymanager uninstall --purge -y"
Write-Host "`nDone." -ForegroundColor $CGood

Exit 0
}catch{
Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor $CBad
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
