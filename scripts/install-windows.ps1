try{
Clear-Host
$CHeader = 'Magenta'; $CInfo='Cyan'; $CPrompt='Yellow'; $CGood='Green'; $CBad='Red'
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
Write-Host "  Python Install Helper — pymanager UX" -ForegroundColor $CHeader
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader

$pymgrCmd = Get-Command pymanager -ErrorAction SilentlyContinue
if(-not $pymgrCmd){
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if(-not $winget){
    Write-Host "pymanager and winget not found. Please install winget or pymanager and re-run." -ForegroundColor $CBad
    Exit 2
  }
  Clear-Host
  Write-Host "pymanager not found. Installing via winget (no prompts)..." -ForegroundColor $CInfo
  & winget install --id 9NQ7512CXL7T -e --accept-source-agreements --accept-package-agreements
  Start-Sleep -Milliseconds 1200
  $pymgrCmd = Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgrCmd){ Write-Host "pymanager still not available after winget install." -ForegroundColor $CBad; Exit 2 }
  Write-Host "pymanager installed." -ForegroundColor $CGood
  Start-Sleep -Milliseconds 800
}

Clear-Host
Write-Host "=== Online runtimes (pymanager list --online '>=3.10') ===" -ForegroundColor $CHeader
& $pymgrCmd.Path list --online '>=3.10'

Write-Host "`n(Showing only online versions >= 3.10 by default)" -ForegroundColor $CInfo
Write-Host "`nPress Enter to continue to installed runtimes..." -ForegroundColor $CPrompt -NoNewline
[void] (Read-Host)

Clear-Host
Write-Host "=== Installed runtimes (pymanager list) ===" -ForegroundColor $CHeader
& $pymgrCmd.Path list

Write-Host "`n" -NoNewline
Write-Host "Enter tag or version to install/set" -ForegroundColor $CPrompt -NoNewline
Write-Host " (press Enter = install default/latest, or type 'skip' to uninstall mode): " -ForegroundColor $CPrompt -NoNewline
$sel = Read-Host ""

if($sel -and $sel.Trim().ToLower() -eq 'skip'){
  Clear-Host
  Write-Host "=== Uninstall mode ===" -ForegroundColor $CHeader
  & $pymgrCmd.Path list
  Write-Host "`nEnter tag to uninstall (exact tag), or 'all' to purge all managed installs, or press Enter to cancel." -ForegroundColor $CPrompt -NoNewline
  $tag = Read-Host ""
  if([string]::IsNullOrWhiteSpace($tag)){ Clear-Host; Write-Host "Uninstall cancelled." -ForegroundColor $CInfo; Exit 0 }
  if($tag -ieq 'all'){
    Clear-Host
    Write-Host "Purging all managed installs (pymanager uninstall --purge -y)..." -ForegroundColor $CHeader
    & $pymgrCmd.Path uninstall --purge -y
    Clear-Host
    Write-Host "Purge command executed." -ForegroundColor $CGood
    Exit 0
  } else {
    Clear-Host
    Write-Host ("About to uninstall: " + $tag) -ForegroundColor $CPrompt
    $confirm = Read-Host -Prompt "(type Y to confirm)"
    if($confirm -match '^[Yy]$'){ Write-Host "Running: pymanager uninstall -y $tag" -ForegroundColor $CInfo; & $pymgrCmd.Path uninstall -y $tag; Clear-Host; Write-Host "Uninstall requested." -ForegroundColor $CGood } else { Clear-Host; Write-Host "Uninstall cancelled." -ForegroundColor $CInfo }
    Exit 0
  }
}

$installArg = if([string]::IsNullOrWhiteSpace($sel)){ 'default' } else { $sel.Trim() }
Clear-Host
if($installArg -eq 'default'){ Write-Host "Installing pymanager default / latest runtime..." -ForegroundColor $CHeader; & $pymgrCmd.Path install default }
else { Write-Host ("Installing: pymanager install " + $installArg) -ForegroundColor $CHeader; & $pymgrCmd.Path install $installArg }

Clear-Host
Write-Host "Installation step finished." -ForegroundColor $CGood
Write-Host "Would you like to set PYTHON_MANAGER_DEFAULT to this runtime/tag?" -ForegroundColor $CPrompt -NoNewline
$setDef = Read-Host " (Y/n)"
if([string]::IsNullOrWhiteSpace($setDef) -or $setDef -match '^[Yy]'){
  try{
    $verToSet = $installArg
    if($installArg -eq 'default'){
      Write-Host "You installed the default runtime. Enter a specific version to set or press Enter to skip." -ForegroundColor $CPrompt -NoNewline
      $verPrompt = Read-Host ""
      if(-not [string]::IsNullOrWhiteSpace($verPrompt)){ $verToSet = $verPrompt } else { $verToSet = $null }
    }
    if($verToSet){ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$verToSet,'User'); Write-Host ("Set PYTHON_MANAGER_DEFAULT=" + $verToSet + " (User)") -ForegroundColor $CGood } else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT." -ForegroundColor $CInfo }
  } catch { Write-Host "Could not set PYTHON_MANAGER_DEFAULT." -ForegroundColor $CBad }
} else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT." -ForegroundColor $CInfo }

Clear-Host
Write-Host "=== Active python (probe via pymanager exec) ===" -ForegroundColor $CHeader
if($installArg -eq 'default'){ & $pymgrCmd.Path exec -- -c "import sys;print(sys.version);print(sys.executable)" } else { & $pymgrCmd.Path exec "-V:$installArg" -- -c "import sys;print(sys.version);print(sys.executable)" }

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CHeader
Write-Host " Helpful pymanager commands " -ForegroundColor $CHeader
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor $CHeader
Write-Host "  List installed runtimes:" -ForegroundColor $CInfo; Write-Host "    pymanager list"
Write-Host "  List online runtimes (>=3.10 shown above):" -ForegroundColor $CInfo; Write-Host "    pymanager list --online '>=3.10'"
Write-Host "  Install a runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager install <TAG or version>        e.g. pymanager install 3.11.9"
Write-Host "  Set default runtime (env):" -ForegroundColor $CInfo; Write-Host "    set PYTHON_MANAGER_DEFAULT=<version> in Environment Variables or use the prompt above"
Write-Host "  Create venv with specific runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager exec -V:<TAG> -- -m venv .venv"
Write-Host "    pymanager exec -3.11 -- -m venv .venv"
Write-Host "  Uninstall runtime:" -ForegroundColor $CInfo; Write-Host "    pymanager uninstall <TAG>     or     pymanager uninstall --purge -y"
Write-Host "`nDone." -ForegroundColor $CGood

Exit 0
}catch{
Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor $CBad
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
