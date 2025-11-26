#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'
try{
  Clear-Host
  Write-Host '=== pymanager setup for Windows ==='
  $pymgr = Get-Command pymanager -ErrorAction SilentlyContinue
  if(-not $pymgr){
    Write-Host 'pymanager not found.'
    if(Get-Command winget -ErrorAction SilentlyContinue){
      Write-Host 'Attempting noninteractive install via winget...'
      $args = @('install','9NQ7512CXL7T','-e','--accept-package-agreements','--disable-interactivity')
      try{
        $proc = Start-Process -FilePath 'winget' -ArgumentList $args -Wait -NoNewWindow -PassThru
        if($proc.ExitCode -ne 0){ throw "winget exit code $($proc.ExitCode)" }
      }catch{
        Write-Error "winget install failed: $($_.Exception.Message)"
        Write-Host 'If winget requires elevation, re-run this script in an elevated PowerShell or install pymanager manually.'
        Exit 2
      }
      Start-Sleep -Seconds 1
      $pymgr = Get-Command pymanager -ErrorAction SilentlyContinue
      if(-not $pymgr){
        Write-Warning 'pymanager appears installed but is not yet available in this shell. Start a new shell or sign out/in.'
      }
    }else{
      Write-Host 'winget not found. Install pymanager from the Microsoft Store or from python.org. Example:'
      Write-Host '  winget install 9NQ7512CXL7T -e --accept-package-agreements --disable-interactivity'
      Exit 2
    }
  }
  Clear-Host
  Write-Host "`n🎉 Done!"
  Exit 0
}catch{
  Write-Error $_.Exception.Message
  Exit 1
}finally{
  if($Host.Name -ne 'ServerRemoteHost'){ Read-Host 'Press Enter to close...' }
}
