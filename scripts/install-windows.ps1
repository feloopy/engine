try{
Clear-Host
function Run-Exec{ param($exe,$args,$timeoutSec=120)
  $p=New-Object System.Diagnostics.Process
  $p.StartInfo.FileName=$exe
  $p.StartInfo.Arguments = if($args -is [array]){ [string]::Join(' ',$args) } else { [string]$args }
  $p.StartInfo.UseShellExecute=$false; $p.StartInfo.RedirectStandardOutput=$true; $p.StartInfo.RedirectStandardError=$true; $p.StartInfo.CreateNoWindow=$true
  if(-not $p.Start()){ return @{Ok=$false;Exit=$null} }
  if(-not $p.WaitForExit([int]($timeoutSec*1000))){ try{ $p.Kill() } catch{}; return @{Ok=$false;Exit=$null} }
  return @{Ok=$true;Exit=$p.ExitCode}
}

$pymgrCmd = Get-Command pymanager -ErrorAction SilentlyContinue
if(-not $pymgrCmd){
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if(-not $winget){ Write-Error "pymanager missing and winget not available. Install one of them and re-run."; Exit 2 }
  Clear-Host
  Write-Host "pymanager not found. Installing via winget (no prompts)..."
  $r = Run-Exec 'winget' @('install','--id','9NQ7512CXL7T','-e','--accept-source-agreements','--accept-package-agreements') 300
  Start-Sleep -Seconds 2
  $pymgrCmd = Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgrCmd){ Write-Error "pymanager still not found after winget install. Aborting."; Exit 2 }
}

Clear-Host
Write-Host "=== Online versions (pymanager list --online '>=3.10') ==="
& pymanager list --online '>=3.10'

Write-Host "`nPress Enter to continue to installed runtimes..."
Read-Host | Out-Null

Clear-Host
Write-Host "=== Installed runtimes (pymanager list) ==="
& pymanager list

$prompt = "Enter tag or version to install/set (press Enter to install default latest). Enter 'skip' to go to uninstall mode"
$sel = Read-Host $prompt

if($sel -and $sel.Trim().ToLower() -eq 'skip'){
  Clear-Host
  Write-Host "=== Uninstall mode: installed runtimes ==="
  & pymanager list
  $tag = Read-Host "Enter tag to uninstall (exact tag), or 'all' to purge all managed installs, or press Enter to cancel"
  if([string]::IsNullOrWhiteSpace($tag)){ Clear-Host; Write-Host "Uninstall cancelled."; Exit 0 }
  if($tag -ieq 'all'){
    Clear-Host
    Write-Host "Running: pymanager uninstall --purge -y"
    & pymanager uninstall --purge -y
    Clear-Host
    Write-Host "Purge requested. Done."
    Exit 0
  } else {
    Clear-Host
    $confirm = Read-Host ("Confirm uninstall tag '" + $tag + "'? [Y/n]")
    if([string]::IsNullOrWhiteSpace($confirm) -or $confirm -match '^[Yy]'){ Write-Host ("Running: pymanager uninstall -y " + $tag); & pymanager uninstall -y $tag; Clear-Host; Write-Host "Uninstall requested. Done." } else { Clear-Host; Write-Host "Uninstall cancelled." }
    Exit 0
  }
} else {
  $installArg = if([string]::IsNullOrWhiteSpace($sel)){ 'default' } else { $sel }
  Clear-Host
  if($installArg -eq 'default'){ Write-Host "Installing default/latest (pymanager install default)"; & pymanager install default } else { Write-Host ("Installing: pymanager install " + $installArg); & pymanager install $installArg }
  Clear-Host
  $setDef = Read-Host "Set PYTHON_MANAGER_DEFAULT to this version/tag? [Y/n]"
  if([string]::IsNullOrWhiteSpace($setDef) -or $setDef -match '^[Yy]'){
    try{
      $verToSet = $installArg
      if($installArg -eq 'default'){ $verToSet = Read-Host "Enter version to set as PYTHON_MANAGER_DEFAULT (or press Enter to skip)"; if([string]::IsNullOrWhiteSpace($verToSet)){ Write-Host 'Skipping setting PYTHON_MANAGER_DEFAULT' } else { [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$verToSet,'User'); Write-Host ("Set PYTHON_MANAGER_DEFAULT=" + $verToSet + " (User)") } }
      else { [Environment]::SetEnvironmentVariable('PYTHON_MANAGER_DEFAULT',$verToSet,'User'); Write-Host ("Set PYTHON_MANAGER_DEFAULT=" + $verToSet + " (User)") }
    } catch { Write-Warning "Could not set PYTHON_MANAGER_DEFAULT" }
  } else { Write-Host "Skipping setting PYTHON_MANAGER_DEFAULT" }
  Clear-Host
  Write-Host "=== Active python (via pymanager exec) ==="
  if($installArg -eq 'default'){ & pymanager exec -- -c "import sys;print(sys.version);print(sys.executable)" } else { & pymanager exec -V:$installArg -- -c "import sys;print(sys.version);print(sys.executable)" }
}

Clear-Host
Write-Host "Useful pymanager commands:"
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
