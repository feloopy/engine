Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RetryCount = [int]($env:RETRY_COUNT -as [int] -or 4)
$UserProfile = $env:USERPROFILE
function Log($m){ [Console]::Error.WriteLine("{0} {1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"), $m) }
function Run-Command([string]$cmd){ for($i=1;$i -le $RetryCount;$i++){ Log "RUN: $cmd (attempt $i)"; try{ Invoke-Expression $cmd; return } catch{ if($i -lt $RetryCount){ Start-Sleep -Seconds ($i*$i) } else { throw } } } }
$pymanagerCmd = Get-Command pymanager -ErrorAction SilentlyContinue
$pyCmd = Get-Command py -ErrorAction SilentlyContinue
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if(-not $pymanagerCmd -and -not $pyCmd -and -not $pythonCmd){ Log "pymanager/py/python not found. Install Python Install Manager or python"; Exit 1 }
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
$winget = Get-Command winget -ErrorAction SilentlyContinue
if(-not $codeCmd){
  if($winget){ Run-Command "winget install -e --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent" } 
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
    "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd"
  )
  foreach($p in $candidates){ if(Test-Path $p){ $codeCmd = $p; break } }
}
if(-not (Get-Command code -ErrorAction SilentlyContinue) -and -not $codeCmd){ Log '"code" CLI not found after install attempt. Ensure VS Code is installed and "code" is on PATH.'; Exit 1 }
$exts = @('ms-python.python','ms-python.vscode-pylance','ms-toolsai.jupyter','ms-toolsai.jupyter-renderers','ms-python.black-formatter','ms-python.isort','njpwerner.autodocstring','ms-vscode-remote.remote-containers','VariableExplorer.variable-explorer')
function Install-Ext([string]$e){
  $listCmd = "code --list-extensions"
  if(& code --list-extensions | Where-Object { $_ -eq $e }){ Log "Extension $e already installed"; return }
  for($i=1;$i -le $RetryCount;$i++){
    Log "Installing extension $e (attempt $i)"
    try{ & code --install-extension $e --force *> $null; Log "Installed $e"; return } catch {
      Log "Install returned error, trying isolated dirs"
      $tmpu = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()))
      $tmpx = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()))
      try{
        $cmd = "code --user-data-dir `"$($tmpu.FullName)`" --extensions-dir `"$($tmpx.FullName)`" --install-extension $e --force"
        Invoke-Expression $cmd
        if((& code --list-extensions --extensions-dir $tmpx.FullName) -contains $e){ Log "Installed $e into isolated dir"; Remove-Item -Recurse -Force $tmpu,$tmpx; return }
      } catch{}
      Remove-Item -Recurse -Force $tmpu,$tmpx -ErrorAction SilentlyContinue
      if($i -lt $RetryCount){ Start-Sleep -Seconds ($i*$i) } else { Log "Failed to install extension $e after $RetryCount attempts" }
    }
  }
  throw "Failed to install extension $e"
}
foreach($e in $exts){ try{ Install-Ext $e } catch { Log "Continuing despite extension failure: $e" } }
$interp = $null
if($env:VIRTUAL_ENV -and (Test-Path (Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'))){ $interp = (Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'); Log "Using active VIRTUAL_ENV: $interp" }
else{
  if($pyCmd){
    try{
      $out = & py --list-paths 2>$null
      if(-not $out -or $out.Count -eq 0){ $out = & py --list-paths -V:3 2>$null }
      if($out){
        foreach($line in $out){
          if($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)'){ $interp = $matches[1]; break }
        }
      }
    } catch{}
  }
  if(-not $interp -and $pymanagerCmd){
    try{
      $o = & pymanager list 2>$null
      if($o){
        foreach($line in $o){ if($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)'){ $interp = $matches[1]; break } }
      }
    } catch{}
  }
  if(-not $interp -and $pythonCmd){ $interp = (Get-Command python).Source }
}
if(-not $interp){ Log "No usable Python interpreter found"; Exit 1 }
Log "Selected interpreter: $interp"
$cfgdir = Join-Path $env:APPDATA 'Code\User'
New-Item -ItemType Directory -Force -Path $cfgdir | Out-Null
$settingsFile = Join-Path $cfgdir 'settings.json'
$new = @{
  "python.defaultInterpreterPath" = $interp
  "python.formatting.provider" = "black"
  "[python]" = @{ "editor.defaultFormatter" = "ms-python.black-formatter"; "editor.formatOnSave" = $true }
  "editor.codeActionsOnSave" = @{ "source.organizeImports" = $true }
  "python.linting.enabled" = $true
  "python.linting.pylintEnabled" = $true
  "python.testing.pytestEnabled" = $true
  "python.languageServer" = "Pylance"
  "python.analysis.typeCheckingMode" = "basic"
  "python.analysis.extraPaths" = @((Join-Path $env:LOCALAPPDATA 'Programs\Python') )
  "files.exclude" = @{ "**/__pycache__" = $true }
  "files.autoSave" = "afterDelay"
  "files.autoSaveDelay" = 1000
}
if((Get-Command jq -ErrorAction SilentlyContinue) -and (Test-Path $settingsFile)){
  $tmp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + '.json')
  $new | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $tmp
  Run-Command "jq -s '.[0] * .[1]' `"$settingsFile`" `"$tmp`" > `"$settingsFile.merged`" ; Move-Item -Force `"$settingsFile.merged`" `"$settingsFile`""
  Remove-Item $tmp -ErrorAction SilentlyContinue
} else {
  if(Test-Path $settingsFile){ Copy-Item $settingsFile "$settingsFile.bak" -Force }
  $new | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $settingsFile
}
if(& code --list-extensions | Where-Object { $_ -eq 'ms-toolsai.jupyter' }){ Log "Jupyter extension present, Variables pane and Data Viewer available" } else { Log "Jupyter extension missing; install ms-toolsai.jupyter to get Data Viewer/Variables pane" }
Log "Done. VS Code configured: interpreter $interp, autosave on, extensions attempted"
