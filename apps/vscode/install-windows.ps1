Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RetryCount = 4
if ($env:RETRY_COUNT) { $tmp = 0; if ([int]::TryParse($env:RETRY_COUNT, [ref]$tmp)) { $RetryCount = [int]$env:RETRY_COUNT } }
$ScriptSucceeded = $true
function Log($m){ [Console]::Error.WriteLine((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')+' '+$m) }
function Invoke-ProcessWithTimeout([string]$exe,[string[]]$argList,[int]$timeoutSec){
    $outFile = Join-Path $env:TEMP ([guid]::NewGuid().ToString()+'.out')
    $errFile = Join-Path $env:TEMP ([guid]::NewGuid().ToString()+'.err')
    try{
        $psi = Start-Process -FilePath $exe -ArgumentList $argList -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru -ErrorAction Stop
        $waitMs = [int]($timeoutSec * 1000)
        $exited = $false
        try{ $exited = $psi.WaitForExit($waitMs) } catch{}
        if (-not $exited) {
            try{ $psi.Kill() } catch{}
            return @{
                Success = $false
                ExitCode = -1
                StdOut = (if (Test-Path $outFile) { Get-Content $outFile -Raw } else { '' })
                StdErr = (if (Test-Path $errFile) { Get-Content $errFile -Raw } else { '' })
                TimedOut = $true
            }
        } else {
            $ec = if ($psi.HasExited) { $psi.ExitCode } else { 0 }
            return @{
                Success = $true
                ExitCode = $ec
                StdOut = (if (Test-Path $outFile) { Get-Content $outFile -Raw } else { '' })
                StdErr = (if (Test-Path $errFile) { Get-Content $errFile -Raw } else { '' })
                TimedOut = $false
            }
        }
    } catch {
        return @{
            Success = $false
            ExitCode = -2
            StdOut = ''
            StdErr = $_.ToString()
            TimedOut = $false
        }
    } finally {
        Remove-Item -ErrorAction SilentlyContinue $outFile,$errFile
    }
}
function Run-Command([string]$cmd,[int]$timeoutSec=120){
    for ($i = 1; $i -le $RetryCount; $i++) {
        Log "RUN: $cmd (attempt $i)"
        try{
            $r = Invoke-ProcessWithTimeout 'powershell.exe' @('-NoProfile','-NonInteractive','-Command',$cmd) $timeoutSec
            if ($r.Success) { return @{ Success = $true; Output = $r.StdOut } }
            else { throw $r }
        } catch {
            Log "Command error: $_"
            if ($i -lt $RetryCount) { Start-Sleep -Seconds ([int]($i * $i)) } else { Log "Command failed after $RetryCount attempts: $cmd"; return @{ Success = $false; Output = $_ } }
        }
    }
}
function Try-RunExe([string]$exe,[string[]]$argList,[int]$timeoutSec=30){
    try{
        if (-not $exe) { return @{ Success = $false; Msg = "No executable specified" } }
        $res = Invoke-ProcessWithTimeout $exe $argList $timeoutSec
        if ($res.Success) { return @{ Success = $true; Out = $res.StdOut; Err = $res.StdErr; Code = $res.ExitCode } }
        else { return @{ Success = $false; Out = $res.StdOut; Err = $res.StdErr; TimedOut = $res.TimedOut; Code = $res.ExitCode } }
    } catch { return @{ Success = $false; Err = $_.ToString() } }
}
function Resolve-CodeExe([string]$Path){
    if (-not $Path) { return $null }
    try{
        if ((Test-Path $Path -PathType Leaf) -and ($Path -like '*.exe')) { return (Get-Item $Path).FullName }
        if ((Test-Path $Path -PathType Leaf) -and ($Path -like '*.cmd')) {
            $parent = Split-Path $Path -Parent
            $cand = Join-Path $parent '..\Code.exe'
            $cand = (Resolve-Path $cand -ErrorAction SilentlyContinue)
            if ($cand) { return (Get-Item $cand).FullName }
            $cand = Join-Path (Split-Path $parent -Parent) 'Code.exe'
            if (Test-Path $cand) { return (Get-Item $cand).FullName }
        }
        $known = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe","$env:ProgramFiles\Microsoft VS Code\Code.exe","$env:ProgramFiles(x86)\Microsoft VS Code\Code.exe")
        foreach ($k in $known) { if (Test-Path $k) { return (Get-Item $k).FullName } }
        $g = Get-Command code -ErrorAction SilentlyContinue
        if ($g -and (Test-Path $g.Source)) { return (Get-Item $g.Source).FullName }
    } catch {}
    return $null
}
function Install-Ext([string]$e){
    try{
        if (-not $CodeExe) { Log "Skipping install of $e because code CLI unresolved"; return $false }
        $res = Try-RunExe $CodeExe @('--list-extensions') 20
        $installedList = if ($res.Success -and $res.Out) { $res.Out -split "`r?`n" } else { @() }
        if ($installedList -contains $e) { Log "Extension $e already installed"; return $true }
        for ($i = 1; $i -le $RetryCount; $i++){
            Log "Installing extension $e (attempt $i)"
            $r = Try-RunExe $CodeExe @('--install-extension',$e,'--force') 60
            if ($r.Success) {
                Start-Sleep -Milliseconds 500
                $v = Try-RunExe $CodeExe @('--list-extensions') 20
                $vList = if ($v.Success -and $v.Out) { $v.Out -split "`r?`n" } else { @() }
                if ($vList -contains $e) { Log "Installed $e"; return $true }
            }
            Log "Install attempt failed for $e. Trying isolated dirs"
            $tmpu = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
            $tmpx = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Force -Path $tmpu | Out-Null
            New-Item -ItemType Directory -Force -Path $tmpx | Out-Null
            $r2 = Try-RunExe $CodeExe @('--user-data-dir',$tmpu,'--extensions-dir',$tmpx,'--install-extension',$e,'--force') 60
            if ($r2.Success) {
                $v2 = Try-RunExe $CodeExe @('--list-extensions','--extensions-dir',$tmpx) 20
                $v2List = if ($v2.Success -and $v2.Out) { $v2.Out -split "`r?`n" } else { @() }
                if ($v2List -contains $e) { Log "Installed $e into isolated dir"; Remove-Item -Recurse -Force $tmpu,$tmpx -ErrorAction SilentlyContinue; return $true }
            }
            Remove-Item -Recurse -Force $tmpu,$tmpx -ErrorAction SilentlyContinue
            if ($i -lt $RetryCount) { Start-Sleep -Seconds ([int]($i * $i)) } else { Log "Failed to install extension $e after $RetryCount attempts" }
        }
        return $false
    } catch { Log "Install-Ext unexpected error: $_"; return $false }
}
function Add-VSCode-ContextMenu([string]$CodePath){
 if(-not $CodePath){ Log "Add-VSCode-ContextMenu: no code path supplied, skipping"; return }
 $exe = Resolve-CodeExe -Path $CodePath
 if(-not $exe){ Log "Add-VSCode-ContextMenu: Code.exe could not be resolved from $CodePath; skipping"; return }
 $exeName=(Split-Path $exe -Leaf)
 $searchNames=@('OpenWithCode','OpenWith','OpenWith_Code','VSCode','VisualStudioCode','Open with Code')
 $roots=@('HKCU:\Software\Classes','HKCR:')
 $parentsToCheck=@('Directory\shell','Directory\Background\shell','*\shell')
 Log "Add-VSCode-ContextMenu: scanning registry for existing entries"
 $foundAny=$false
 foreach($root in $roots){
  foreach($p in $parentsToCheck){
   $parentKey = Join-Path $root $p
   Log "Checking parent key: $parentKey"
   if(-not (Test-Path $parentKey)){ Log "Parent key not present: $parentKey"; continue }
   foreach($n in $searchNames){
    $candKey = Join-Path $parentKey $n
    if(-not (Test-Path $candKey)){ continue }
    Log "Inspecting candidate key: $candKey"
    try{
     $cmdKey = Join-Path $candKey 'command'
     $cmdVal = (Get-ItemProperty -Path $cmdKey -ErrorAction SilentlyContinue).'(default)'
     if($cmdVal -and ($cmdVal -like "*$exeName*" -or $cmdVal -like "*$exe*")){ Log "Matching command found in $candKey"; $foundAny=$true; break }
     $def = (Get-ItemProperty -Path $candKey -ErrorAction SilentlyContinue).'(default)'
     if($def -and ($def -match '(?i)open.*code|visual\s*studio\s*code|vscode')){ Log "Matching display name found in $candKey"; $foundAny=$true; break }
    } catch { Log "Error inspecting $_" }
   }
   if($foundAny){ Log "Context menu entry already exists under $parentKey, skipping further scanning"; break }
  }
  if($foundAny){ break }
 }
 if($foundAny){ Log "Context menu registration found existing entries; skipping creation"; return }
 Log "No existing context menu entries found; creating entries"
 $createParents=@('HKCU:\Software\Classes\Directory\shell','HKCU:\Software\Classes\Directory\Background\shell','HKCU:\Software\Classes\*\shell','HKCR:\Directory\shell','HKCR:\Directory\Background\shell','HKCR:\*\shell')
 foreach($p in $createParents){
  try{
   Log "Ensuring parent path: $p"
   if(-not (Test-Path $p)){ New-Item -Path $p -Force | Out-Null; Log "Created parent path: $p" }
   $newName='OpenWithCode'
   $newKey = Join-Path $p $newName
   if(Test-Path $newKey){ $newName = 'OpenWithCode-'+([guid]::NewGuid().ToString()); $newKey = Join-Path $p $newName; Log "Name collision, using $newName" }
   New-Item -Path $newKey -Force -Value 'Open with Code' | Out-Null
   New-ItemProperty -Path $newKey -Name 'Icon' -Value "$exe,0" -PropertyType String -Force | Out-Null
   $cmdKey = Join-Path $newKey 'command'
   $arg = if($p -match 'Background'){ '%V' } elseif($p -match '\*\shell'){ '%1' } else { '%1' }
   $cmdValue = "`"$exe`" `"$arg`""
   if($arg -eq '%V'){ $cmdValue = "`"$exe`" `"%V`"" }
   New-Item -Path $cmdKey -Force -Value $cmdValue | Out-Null
   Log "Added context menu entry at $newKey"
  } catch { Log "Failed to add entry under: $_" }
 }
 Log "Context menu registration completed"
}
try{
    $pymanagerCmd = Get-Command pymanager -ErrorAction SilentlyContinue
    $pyCmd = Get-Command py -ErrorAction SilentlyContinue
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pymanagerCmd -and -not $pyCmd -and -not $pythonCmd) { Log "pymanager/py/python not found. Some python-specific config may be skipped"; $ScriptSucceeded = $false }
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $codeCmd -and $winget) {
        $r = Run-Command "winget install -e --id Microsoft.VisualStudioCode --accept-package-agreements --accept-source-agreements --silent" 300
        if (-not $r.Success) { Log "winget install reported failure or timed out"; $ScriptSucceeded = $false }
    }
    $candidates = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd","$env:ProgramFiles\Microsoft VS Code\bin\code.cmd","$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd")
    foreach ($p in $candidates) { if (Test-Path $p) { $codeCmd = Get-Command $p -ErrorAction SilentlyContinue; break } }
    if (-not $codeCmd) { Log '"code" CLI not found after install attempt. Extensions and context menu steps may be skipped'; $ScriptSucceeded = $false }
    $CodeExe = if ($codeCmd -and ($codeCmd.CommandType -eq 'Application' -or $codeCmd.CommandType -eq 'ExternalScript')) { $codeCmd.Source } elseif ($codeCmd) { 'code' } else { $null }
    $codePathFull = $null
    try{
        if ($CodeExe -and (Test-Path $CodeExe)) { $codePathFull = (Get-Item $CodeExe).FullName }
        elseif ($codeCmd -and $codeCmd.Path) { $codePathFull = $codeCmd.Path }
        else {
            $cand = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe","$env:ProgramFiles\Microsoft VS Code\Code.exe","$env:ProgramFiles(x86)\Microsoft VS Code\Code.exe","$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")
            foreach ($cp in $cand) { if (Test-Path $cp) { $codePathFull = $cp; break } }
            if (-not $codePathFull) { $g = Get-Command code -ErrorAction SilentlyContinue; if ($g) { $codePathFull = $g.Source } }
        }
    } catch { $codePathFull = $null }
    $exts = @('ms-python.python','ms-python.vscode-pylance','ms-toolsai.jupyter','ms-toolsai.jupyter-renderers','ms-python.black-formatter','ms-python.isort','njpwerner.autodocstring','ms-vscode-remote.remote-containers','VariableExplorer.variable-explorer','Google.colab')
    if ($codePathFull) { Add-VSCode-ContextMenu -CodePath $codePathFull } else { Log "Skipping context menu registration because Code path unresolved" }
    foreach ($e in $exts) { $ok = Install-Ext $e; if (-not $ok) { Log "Continuing despite extension failure: $e"; $ScriptSucceeded = $false } }
    Log "Inspecting pyenv and pyenv-virtualenv environments"
    $interp = $null
    if ($env:VIRTUAL_ENV -and (Test-Path (Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'))) { $interp = (Join-Path $env:VIRTUAL_ENV 'Scripts\python.exe'); Log "Using active VIRTUAL_ENV: $interp" } else {
        if ($pyCmd) {
            try{
                $r = Try-RunExe $pyCmd.Source @('--list-paths') 10
                if ((-not $r.Success) -or (-not $r.Out)) { $r = Try-RunExe $pyCmd.Source @('--list-paths','-V:3') 10 }
                if ($r.Success -and $r.Out) { foreach ($line in ($r.Out -split "`r?`n")) { if ($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)') { $interp = $matches[1]; break } } }
            } catch{}
        }
        if (-not $interp -and $pymanagerCmd) {
            try{
                $o = Try-RunExe $pymanagerCmd.Source @('list') 10
                if ($o.Success -and $o.Out) { foreach ($line in ($o.Out -split "`r?`n")) { if ($line -match '([A-Za-z]:\\.*?python(?:w)?\.exe)') { $interp = $matches[1]; break } } }
            } catch{}
        }
        if (-not $interp -and $pythonCmd) { try{ $interp = (Get-Command python).Source } catch{} }
    }
    if (-not $interp) { Log "No usable Python interpreter found; some settings will use a generic python path"; $ScriptSucceeded = $false } else { Log "Selected interpreter: $interp" }
    $cfgdir = Join-Path $env:APPDATA 'Code\User'
    try{ New-Item -ItemType Directory -Force -Path $cfgdir | Out-Null } catch { Log "Failed to ensure config dir: $_"; $ScriptSucceeded = $false }
    $settingsFile = Join-Path $cfgdir 'settings.json'
    $new = @{
        "python.defaultInterpreterPath" = ($interp -or 'python')
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
    try{
        if ((Get-Command jq -ErrorAction SilentlyContinue) -and (Test-Path $settingsFile)) {
            $tmp = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()+'.json')
            $new | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $tmp
            if (-not (Run-Command "jq -s '.[0] * .[1]' `"$settingsFile`" `"$tmp`" > `"$settingsFile.merged`" ; Move-Item -Force `"$settingsFile.merged`" `"$settingsFile`"" ).Success) { Log "jq merge failed"; $ScriptSucceeded = $false }
            Remove-Item $tmp -ErrorAction SilentlyContinue
        } else {
            if (Test-Path $settingsFile) { Copy-Item $settingsFile "$settingsFile.bak" -Force -ErrorAction SilentlyContinue }
            $tmp2 = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString()+'.json')
            $new | ConvertTo-Json -Depth 10 | Out-File -Encoding utf8 $tmp2
            try { Move-Item -Force $tmp2 $settingsFile } catch { try { Copy-Item -Force $tmp2 $settingsFile; Remove-Item $tmp2 -ErrorAction SilentlyContinue } catch { Log "Failed to write settings.json: $_"; $ScriptSucceeded = $false } }
        }
    } catch { Log "Settings write error: $_"; $ScriptSucceeded = $false }
    try{
        $jup = if ($CodeExe) { (Try-RunExe $CodeExe @('--list-extensions') 20).Out } else { $null }
        if ($jup -and ($jup -split "`r?`n" | Where-Object { $_.Trim() -eq 'ms-toolsai.jupyter' })) { Log "Jupyter extension present, Variables pane and Data Viewer available" } else { Log "Jupyter extension missing; install ms-toolsai.jupyter to get Data Viewer/Variables pane" }
    } catch { Log "Could not list extensions to verify jupyter presence: $_"; $ScriptSucceeded = $false }
} catch { Log "Unexpected fatal error: $_"; $ScriptSucceeded = $false }
if ($ScriptSucceeded) { Log "Done. VS Code configured (best-effort)."; exit 0 } else { Log "Done with issues. Check logs above for errors."; exit 2 }
