#!/usr/bin/env pwsh
$ErrorActionPreference='Stop'
try{
  Clear-Host
  Write-Host '=== Installing/Upgrading Git ==='
  if(Get-Command winget -ErrorAction SilentlyContinue){
    $gitArgs=@('install','Git.Git','-e','--accept-package-agreements','--disable-interactivity','--id','Git.Git')
    try{
      Start-Process -FilePath 'winget' -ArgumentList $gitArgs -Wait -NoNewWindow -PassThru | Out-Null
    }catch{ Write-Host "Git install/upgrade failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
  }else{ Write-Host 'winget not found. Install Git manually.'; Exit 2 }
  
  Write-Host '=== pymanager Installation ==='
  $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgr){
    Write-Host 'pymanager not found.'
    $args=@('install','9NQ7512CXL7T','-e','--accept-package-agreements','--disable-interactivity')
    try{
      Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru | Out-Null
    }catch{ Write-Host "winget install failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
    Start-Sleep -Seconds 1
    $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
    if(-not $pymgr){ Write-Host 'pymanager installed but not available in this shell. Start a new shell or sign out/in.' -ForegroundColor Yellow }
  }
  Clear-Host
  Write-Host "`n🎉 pymanager and git setup complete!"
  pymanager
  Exit 0
}catch{ Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red; Exit 1 }
finally{ if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' } }
