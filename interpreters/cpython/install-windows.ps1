#!/usr/bin/env pwsh
$ErrorActionPreference='Stop'
function Safe-Clear{ $ok=$true; try{ $null=$Host.UI.RawUI }catch{ $ok=$false }; if(-not $env:GITHUB_ACTIONS -and $ok){ Clear-Host } }
function Is-Interactive{
  try{
    if($env:GITHUB_ACTIONS -or $env:CI){ return $false }
    if($Host.Name -eq 'ServerRemoteHost'){ return $false }
    if([Console]::IsInputRedirected -or [Console]::IsOutputRedirected){ return $false }
    return $true
  }catch{ return $false }
}
try{
  Safe-Clear
  Write-Host '=== Installing/Upgrading Git ==='
  if(Get-Command winget -ErrorAction SilentlyContinue){
    $gitArgs=@('install','Git.Git','-e','--accept-package-agreements','--disable-interactivity','--id','Git.Git')
    try{ Start-Process -FilePath 'winget' -ArgumentList $gitArgs -Wait -NoNewWindow -PassThru | Out-Null }catch{ Write-Host "Git install/upgrade failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
  }else{ Write-Host 'winget not found. Install Git manually.'; Exit 2 }
  Write-Host '=== pymanager Installation ==='
  $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgr){
    Write-Host 'pymanager not found.'
    $args=@('install','9NQ7512CXL7T','-e','--accept-package-agreements','--disable-interactivity')
    try{ Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru | Out-Null }catch{ Write-Host "winget install failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
    Start-Sleep -Seconds 1
    $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
    if(-not $pymgr){ Write-Host 'pymanager installed but not available in this shell. Start a new shell or sign out/in.' -ForegroundColor Yellow }
  }
  Safe-Clear
  Write-Host "`n🎉 pymanager and git setup complete!"
  pymanager
  Exit 0
}catch{ Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red; Exit 1 }
finally{ if(Is-Interactive){ Read-Host 'Press Enter to close...' } }
