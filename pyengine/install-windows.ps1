#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
try{
  Clear-Host
  Write-Host '=== pymanager Installation ==='
  $pymgr = Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgr){
    Write-Host 'pymanager not found.'
    if(Get-Command winget -ErrorAction SilentlyContinue){
      Write-Host 'Installing via winget...'
      $args = @('install','9NQ7512CXL7T','-e','--accept-package-agreements','--disable-interactivity')
      try{
        $proc = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru
        if($proc.ExitCode -ne 0){ throw "winget exit code $($proc.ExitCode)" }
      }catch{
        Write-Host "winget install failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host 'Run this script in an elevated PowerShell or install pymanager manually.'
        Exit 2
      }
      Start-Sleep -Seconds 1
      $pymgr = Get-Command pymanager -ErrorAction SilentlyContinue
      if(-not $pymgr){
        Write-Host 'pymanager appears installed but not available in this shell. Start a new shell or sign out/in.' -ForegroundColor Yellow
      }
    }else{
      Write-Host 'winget not found. Install pymanager manually. Example:' 
      Write-Host '  winget install 9NQ7512CXL7T -e --accept-package-agreements --disable-interactivity'
      Exit 2
    }
  }
  Clear-Host
  Write-Host "`n🎉 pymanager setup complete!" 
  pymanager
  Exit 0
}catch{
  Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
  Exit 1
}finally{
  if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
