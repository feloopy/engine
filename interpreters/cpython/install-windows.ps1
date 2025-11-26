#!/usr/bin/env pwsh
$ErrorActionPreference='Stop'
function Safe-Clear{ try{ if(-not $env:GITHUB_ACTIONS -and $Host.Name -ne 'ServerRemoteHost'){ Clear-Host } } catch{} }
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
    try{ winget source remove msstore -ErrorAction SilentlyContinue | Out-Null } catch{}
    $gitArgs=@('install','Git.Git','-e','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    try{ Start-Process -FilePath 'winget' -ArgumentList $gitArgs -Wait -NoNewWindow -PassThru | Out-Null } catch{ Write-Host "Git install/upgrade failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
  } else{ Write-Host 'winget not found. Install Git manually.'; Exit 2 }

  Write-Host '=== pymanager Installation ==='
  $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgr){
    Write-Host 'pymanager not found. Installing...'
    $args=@('install','9NQ7512CXL7T','-e','--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
    try{ Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru | Out-Null } catch{ Write-Host "winget install failed: $($_.Exception.Message)" -ForegroundColor Red; Exit 2 }
    Start-Sleep -Seconds 1
    $pymgr=Get-Command pymanager -ErrorAction SilentlyContinue
    if(-not $pymgr){ Write-Host 'pymanager installed but not available in this shell. Start a new shell or sign out/in.' -ForegroundColor Yellow }
  } else{
    Write-Host 'pymanager already present'
  }

  Safe-Clear
  Write-Host "`n🎉 pymanager and git setup complete!"

  if(Is-Interactive){
    if($pymgr){
      Write-Host 'Interactive shell detected. Launching pymanager...'
      try{ pymanager } catch{ Write-Host "Failed to run pymanager: $($_.Exception.Message)" -ForegroundColor Yellow }
    } else{
      Write-Host 'pymanager not found to launch in this interactive shell.' -ForegroundColor Yellow
    }
  } else{
    Write-Host 'Noninteractive session detected. Skipping pymanager invocation.' -ForegroundColor Cyan
    if($pymgr){ Write-Host 'pymanager is installed and can be used from a new interactive shell.' -ForegroundColor Green }
  }

  Exit 0
}catch{ Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red; Exit 1 }
finally{ if(Is-Interactive){ Read-Host 'Press Enter to close...' } }
