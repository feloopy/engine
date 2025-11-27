Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$RetryCount=4
if($env:RETRY_COUNT){ $tmp=0; if([int]::TryParse($env:RETRY_COUNT,[ref]$tmp)){ $RetryCount=[int]$env:RETRY_COUNT }}
$UserProfile=$env:USERPROFILE
function Log($m){ [Console]::Error.WriteLine((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')+' '+$m) }
function Run-Command([string]$cmd){ for($i=1;$i -le $RetryCount;$i++){ Log "RUN: $cmd (attempt $i)"; try{ Invoke-Expression $cmd; return } catch { if($i -lt $RetryCount){ Start-Sleep -Seconds ($i*$i) } else { throw } } } }
$pymanagerCmd = Get-Command pymanager -ErrorAction SilentlyContinue
$pyCmd = Get-Command py -ErrorAction SilentlyContinue
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if(-not $pymanagerCmd -and -not $pyCmd -and -not $pythonCmd){ Log "pymanager/py/python not found. Install Python Install Manager or python"; Exit 1 }
$codeCmd = Get-Command code -ErrorAction SilentlyContinue
$winget = Get-Command winget -ErrorAction SilentlyContinue
if(-not $codeCmd){
  if($winget){ Run-Command "winget install -e --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent" }
  $candidates=@("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd","$env:ProgramFiles\Microsoft VS Code\bin\code.cmd","$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd")
  foreach($p in $candidates){ if(Test-Path $p){ $codeCmd = Get-Command $p -ErrorAction SilentlyContinue; break } }
}
if(-not $codeCmd){ Log '"code" CLI not found after install attempt. Ensure VS Code is installed and "code" is on PATH.'; Exit 1 }
$CodeExe = if($codeCmd.CommandType -eq 'Application' -or $codeCmd.CommandType -eq 'ExternalScript'){ $codeCmd.Source } else { 'code' }
$codePathFull = $null
try{ if($CodeExe -and (Test-Path $CodeExe)){ $codePathFull = (Get-Item $CodeExe).FullName }
elseif($codeCmd -and $codeCmd.Path){ $codePathFull = $codeCmd.Path }
else{
  $cand=@("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe","$env:ProgramFiles\Microsoft VS Code\Code.exe","$env:ProgramFiles(x86)\Microsoft VS Code\Code.exe","$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")
  foreach($cp in $cand){ if(Test-Path $cp){ $codePathFull=$cp; break } }
  if(-not $codePathFull){ $g = Get-Command code -ErrorAction SilentlyContinue; if($g){ $codePathFull = $g.Source } }
}
} catch { $codePathFull = $null }

$exts=@('ms-python.python','ms-python.vscode-pylance','ms-toolsai.jupyter','ms-toolsai.jupyter-renderers','ms-python.black-formatter','ms-python.isort','njpwerner.autodocstring','ms-vscode-remote.remote-containers','VariableExplorer.variable-explorer','Google.colab')
function Install-Ext([string]$e){
  if(& $CodeExe --list-extensions 2>$null | Where-Object { $_ -eq $e }){ Log "Extension $e already installed"; return }
  for($i=1;$i -le $RetryCount;$i++){ Log "Installing extension $e (attempt $i)"; try{ & $CodeExe --install-extension $e --force *> $null; Log "Installed $e"; return } catch { Log "Install returned error, trying isolated dirs"; $tmpu=New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())) ; $tmpx=New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())); try{ & $CodeExe --user-data-dir $tmpu.FullName --extensions-dir $tmpx.FullName --install-extension $e --force; if((& $CodeExe --list-extensions --extensions-dir $tmpx.FullName) -contains $e){ Log "Installed $e into isolated dir"; Remove-Item -Recurse -Force $tmpu,$tmpx; return } } catch{}; Remove-Item -Recurse -Force $tmpu,$tmpx -ErrorAction SilentlyContinue; if($i -lt $RetryCount){ Start-Sleep -Seconds ($i*$i) } else { Log "Failed to install extension $e after $RetryCount attempts" } } }
  throw "Failed to install extension $e"
}
if($IsWindows -and $codePathFull){
  try{
    $regEntries=@(
      @{Key='HKCU:\Software\Classes\Directory\shell\OpenInVSCode';Cmd="`"$codePathFull`" `"%V`""},
      @{Key='HKCU:\Software\Classes\Directory\Background\shell\OpenInVSCode';Cmd="`"$codePathFull`" `"%V`""},
      @{Key='HKCU:\Software\Classes\*\shell\OpenInVSCode';Cmd="`"$codePathFull`" `"%1`""}
    )
    foreach($r in $regEntries){
      New-Item -Path $r.Key -Force -Value 'Open in VS Code' | Out-Null
      New-Item -Path (Join-Path $r.Key 'command') -Force -Value $r.Cmd | Out-Null
      Log "Added context menu entry at $($r.Key)"
    }
  } catch { Log "Failed to add Explorer context menu entries: $_" }
} else { Log "Skipping context menu registration because not Windows or Code path unresolved" }

foreach($e in $exts){ try{ Install-Ext $e } catch { Log "Continuing despite extension failure: $e" } }
Log "Inspecting pyenv and pyenv-virtualenv environments"
$interp=$null
if($env:VIRTUAL_ENV -and (Test-Path (Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'))){ $interp=(Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'); Log "Using active VIRTUAL_ENV: $interp" }
else{
  if($pyCmd){ try{ $out=& py --list-paths 2>$null; if(-not $out -or $out.Count -eq 0){ $out=& py --list-paths -V:3 2>$null } if($out){ foreach($line in $out){ if($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)'){ $interp=$matches[1]; break } } } } catch{} }
  if(-not $interp -and $pymanagerCmd){ try{ $o=& pymanager list 2>$null; if($o){ foreach($line in $o){ if($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)'){ $interp=$matches[1]; break } } } } catch{} }
  if(-not $interp -and $pythonCmd){ $interp=(Get-Command python).Source }
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
  "python.analysis.extraPaths" = @((Join-Path $env:LOCALAPPDATA 'Programs\Python'))
  "files.exclude" = @{ "**/__pycache__" = $true }
  "files.autoSave" = "afterDelay"
  "files.autoSaveDelay" = 1000
}
if((Get-Command jq -ErrorAction SilentlyContinue) -and (Test-Path $settingsFile)){
  $tmp=Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()+'.json'); $new | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $tmp
  Run-Command "jq -s '.[0] * .[1]' `"$settingsFile`" `"$tmp`" > `"$settingsFile.merged`" ; Move-Item -Force `"$settingsFile.merged`" `"$settingsFile`""
  Remove-Item $tmp -ErrorAction SilentlyContinue
} else { if(Test-Path $settingsFile){ Copy-Item $settingsFile "$settingsFile.bak" -Force } $new | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $settingsFile }
if(& $CodeExe --list-extensions 2>$null | Where-Object { $_ -eq 'ms-toolsai.jupyter' }){ Log "Jupyter extension present, Variables pane and Data Viewer available" } else { Log "Jupyter extension missing; install ms-toolsai.jupyter to get Data Viewer/Variables pane" }
Log "Done. VS Code configured: interpreter $interp, autosave on, extensions attempted"
