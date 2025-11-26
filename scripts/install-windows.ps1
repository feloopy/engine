try{
Clear-Host
$pymgr = Get-Command pymanager -ErrorAction SilentlyContinue
if(-not $pymgr){ Write-Host "pymanager not found. Install it, for example: winget install --id 9NQ7512CXL7T"; Exit 2 }

Clear-Host
Write-Host "=== Online versions (pymanager list --online '>=3.10') ==="
& pymanager list --online '>=3.10'

Write-Host "`n=== Installed runtimes (pymanager list) ==="
& pymanager list

$prompt = "Enter tag or version to install/set (press Enter to install default latest). Enter 'skip' to go to uninstall mode"
$sel = Read-Host $prompt

if($sel -and $sel.Trim().ToLower() -eq 'skip'){
  Clear-Host
  Write-Host "=== Uninstall mode: installed runtimes ==="
  & pymanager list
  $tag = Read-Host "Enter tag to uninstall (exact tag), or 'all' to purge all managed installs, or press Enter to cancel"
  if([string]::IsNullOrWhiteSpace($tag)){ Write-Host "Uninstall cancelled."; Exit 0 }
  if($tag -ieq 'all'){
    Clear-Host
    $confirm = Read-Host "Confirm purge all managed installs? Type YES to confirm"
    if($confirm -eq 'YES'){ Write-Host "Running: pymanager uninstall --purge -y"; & pymanager uninstall --purge -y } else { Write-Host "Purge cancelled." }
    Exit 0
  } else {
    Clear-Host
    $confirm = Read-Host ("Confirm uninstall tag '" + $tag + "'? [Y/n]")
    if([string]::IsNullOrWhiteSpace($confirm) -or $confirm -match '^[Yy]'){ Write-Host ("Running: pymanager uninstall -y " + $tag); & pymanager uninstall -y $tag } else { Write-Host "Uninstall cancelled." }
    Exit 0
  }
} else {
  $installArg = if([string]::IsNullOrWhiteSpace($sel)){ 'default' } else { $sel }
  Clear-Host
  if($installArg -eq 'default'){ Write-Host "Installing default/latest (pymanager install default)"; & pymanager install default }
  else { Write-Host ("Installing: pymanager install " + $installArg); & pymanager install $installArg }
  Clear-Host
  $setDef = Read-Host "Set PYTHON_MANAGER_DEFAULT to this version/tag? [Y/n]"
  if([string]::IsNullOrWhiteSpace($setDef) -or $setDef -match '^[Yy]'){
    try{ [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$installArg,'User'); Write-Host ("Set PYTHON_MANAGER_DEFAULT=" + $installArg + " (User)") } catch { Write-Warning "Could not set PYTHON_MANAGER_DEFAULT" }
  } else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT" }
  Clear-Host
  Write-Host "=== Active python (via pymanager exec) ==="
  if($installArg -eq 'default'){ & pymanager exec -- -c "import sys;print(sys.version);print(sys.executable)" } else { & pymanager exec -V:$installArg -- -c "import sys;print(sys.version);print(sys.executable)" }
}

Clear-Host
Write-Host "`nUseful pymanager commands:"
Write-Host "  pymanager list"
Write-Host "  pymanager list --online"
Write-Host "  pymanager list --online '>=3.10'"
Write-Host "  pymanager install <TAG or version>"
Write-Host "  pymanager exec -V:<TAG> -- <args>"
Write-Host "  pymanager exec -3.11 -- -m venv .venv"
Write-Host "  pymanager uninstall <TAG>"
Write-Host "  pymanager uninstall --purge -y"
Write-Host "  pymanager help"
Exit 0
}catch{
Write-Error $_.Exception.Message
Exit 1
}finally{
if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
