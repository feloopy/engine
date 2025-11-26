<#
.SYNOPSIS
    Python Install Manager with virtual environment helpers
.DESCRIPTION
    Installs Python using Windows Package Manager and provides virtual environment management
.PARAMETER PythonVersion
    Specific Python version to install (e.g., "3.11.4")
#>

param([string]$PythonVersion = "")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Color output helper
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if running as administrator
function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Retry command with backoff
function Invoke-Retry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$Attempts = 3,
        [int]$Delay = 5
    )
    
    for ($i = 1; $i -le $Attempts; $i++) {
        Write-ColorOutput "Attempt $i of $Attempts..." Cyan
        try {
            $result = & $ScriptBlock 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Command failed with exit code $LASTEXITCODE"
            }
            $result | ForEach-Object { Write-Host $_ }
            return $true
        }
        catch {
            Write-ColorOutput "Error: $($_.Exception.Message)" Red
            if ($i -lt $Attempts) {
                Write-ColorOutput "Waiting $Delay seconds before retry..." Yellow
                Start-Sleep -Seconds $Delay
                $Delay = [math]::Min($Delay * 2, 60) # Exponential backoff, max 60 seconds
            }
            else {
                return $false
            }
        }
    }
}

# Check if WinGet is available
function Test-WinGet {
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-ColorOutput "WinGet present" Green
            return $true
        }
        Write-ColorOutput "WinGet not found" Yellow
        return $false
    }
    catch {
        Write-ColorOutput "WinGet check failed: $($_.Exception.Message)" Red
        return $false
    }
}

# Install Python Install Manager
function Install-PyManager {
    Write-ColorOutput "Installing Python Install Manager via winget (user scope)..." Yellow
    
    # Check if py launcher is already available
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Write-ColorOutput "py launcher already available" Green
        return $true
    }
    
    if (-not (Test-WinGet)) {
        Write-ColorOutput "winget missing, cannot install pymanager" Red
        return $false
    }
    
    return Invoke-Retry -ScriptBlock {
        & winget install --id 9NQ7512CXL7T -e --scope user --accept-package-agreements --accept-source-agreements
    } -Attempts 3 -Delay 10
}

# Validate py command functionality
function Test-PyLauncher {
    try {
        $output = & py --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "py launcher: $output" Green
            return $true
        }
        else {
            Write-ColorOutput "py command failed with exit code $LASTEXITCODE" Red
            return $false
        }
    }
    catch {
        Write-ColorOutput "py launcher validation failed: $($_.Exception.Message)" Red
        return $false
    }
}

# Get available Python versions
function Get-AvailablePythonVersions {
    Write-ColorOutput "Querying available Python versions..." Yellow
    try {
        $output = & py list --online 2>&1
        if ($LASTEXITCODE -eq 0) {
            $versions = ($output | ForEach-Object {
                if ($_ -match '(\d+\.\d+\.\d+)') {
                    $matches[1]
                }
            }) | Where-Object { $_ -match '^3\.\d+\.\d+$' }
            
            if ($versions.Count -gt 0) {
                return $versions | Sort-Object { [version]$_ } -Descending
            }
        }
        throw "No versions found or command failed"
    }
    catch {
        Write-ColorOutput "Using fallback version list" Yellow
        return @("3.13.0", "3.12.1", "3.11.7", "3.10.12", "3.9.18")
    }
}

# Get installed Python versions
function Get-InstalledPythonVersions {
    Write-ColorOutput "Listing installed Python versions..." Yellow
    try {
        $output = & py list 2>&1
        if ($LASTEXITCODE -eq 0) {
            $versions = ($output | ForEach-Object {
                if ($_ -match '(\d+\.\d+\.\d+)') {
                    $matches[1]
                }
            }) | Where-Object { $_ -match '^3\.\d+\.\d+$' }
            return $versions
        }
        return @()
    }
    catch {
        Write-ColorOutput "Could not list installed versions: $($_.Exception.Message)" Yellow
        return @()
    }
}

# Display version table
function Show-VersionTable {
    param(
        [array]$Versions,
        [array]$Installed
    )
    
    Write-ColorOutput "Available Python versions:" Cyan
    Write-Host "┌─────────────┬────────────┐" -ForegroundColor Gray
    Write-Host "│ Version     │ Status     │" -ForegroundColor Gray
    Write-Host "├─────────────┼────────────┤" -ForegroundColor Gray
    
    foreach ($version in $Versions) {
        $status = if ($Installed -contains $version) { "INSTALLED" } else { "Available" }
        $color = if ($status -eq "INSTALLED") { "Green" } else { "Yellow" }
        
        Write-Host "│ $($version.PadRight(11)) │ " -NoNewline -ForegroundColor Gray
        Write-Host "$($status.PadRight(10))" -NoNewline -ForegroundColor $color
        Write-Host " │" -ForegroundColor Gray
    }
    
    Write-Host "└─────────────┴────────────┘" -ForegroundColor Gray
}

# Get Python executable path
function Get-PythonExecutable {
    param([string]$Version)
    
    try {
        if ($Version) {
            $executable = & py -$Version -c "import sys; print(sys.executable)" 2>$null
            if ($LASTEXITCODE -eq 0 -and $executable) {
                return $executable.Trim()
            }
        }
        else {
            $python = Get-Command python -ErrorAction SilentlyContinue
            if ($python) {
                return $python.Source
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

# Create virtual environment
function New-PyVenv {
    param(
        [string]$Path = "venv",
        [string]$PythonVer = ""
    )
    
    if (Test-Path $Path) {
        Write-ColorOutput "Virtual environment path already exists: $Path" Yellow
        return $false
    }
    
    try {
        if ($PythonVer) {
            $executable = Get-PythonExecutable -Version $PythonVer
            if (-not $executable) {
                Write-ColorOutput "Requested Python version $PythonVer not found" Red
                return $false
            }
            Write-ColorOutput "Creating virtual environment at '$Path' using Python $PythonVer" Yellow
            & $executable -m venv $Path
        }
        else {
            Write-ColorOutput "Creating virtual environment at '$Path' using default Python" Yellow
            & python -m venv $Path
        }
        
        if (Test-Path $Path) {
            Write-ColorOutput "Virtual environment created successfully: $Path" Green
            return $true
        }
        else {
            Write-ColorOutput "Virtual environment creation failed" Red
            return $false
        }
    }
    catch {
        Write-ColorOutput "Virtual environment creation error: $($_.Exception.Message)" Red
        return $false
    }
}

# Remove virtual environment
function Remove-PyVenv {
    param(
        [string]$Path = "venv",
        [switch]$Force
    )
    
    if (-not (Test-Path $Path)) {
        Write-ColorOutput "Virtual environment not found: $Path" Yellow
        return $false
    }
    
    try {
        if (-not $Force) {
            Write-ColorOutput "Removing virtual environment '$Path' in 3 seconds. Press Ctrl+C to cancel..." Yellow
            for ($i = 3; $i -gt 0; $i--) {
                Write-Host "$i..." -NoNewline
                Start-Sleep -Seconds 1
            }
            Write-Host ""
        }
        
        Remove-Item -LiteralPath $Path -Recurse -Force
        Write-ColorOutput "Virtual environment removed: $Path" Green
        return $true
    }
    catch {
        Write-ColorOutput "Failed to remove virtual environment: $($_.Exception.Message)" Red
        return $false
    }
}

# Activate virtual environment
function Activate-Venv {
    param([string]$Path = "venv")
    
    $activateScript = Join-Path $Path "Scripts\Activate.ps1"
    if (-not (Test-Path $activateScript)) {
        # Try for Unix-like environments
        $activateScript = Join-Path $Path "bin\Activate.ps1"
        if (-not (Test-Path $activateScript)) {
            Write-ColorOutput "Activation script not found at: $Path" Red
            return $false
        }
    }
    
    try {
        . $activateScript
        Write-ColorOutput "Activated virtual environment: $Path" Green
        return $true
    }
    catch {
        Write-ColorOutput "Failed to activate virtual environment: $($_.Exception.Message)" Red
        return $false
    }
}

# Find virtual environments
function Find-PyVenvs {
    param([string]$Root = (Get-Location).Path)
    
    $venvList = [System.Collections.ArrayList]@()
    try {
        Get-ChildItem -Path $Root -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
            if (Test-Path (Join-Path $_.FullName "pyvenv.cfg")) {
                $venvList.Add($_.FullName) | Out-Null
            }
        }
    }
    catch {
        Write-ColorOutput "Error searching for virtual environments: $($_.Exception.Message)" Yellow
    }
    
    return $venvList
}

# Display help
function Show-Help {
    Write-ColorOutput "Virtual Environment Helper Commands:" Cyan
    Write-Host ""
    Write-Host "  New-PyVenv -Path <dir> -PythonVer <version>`t# Create new virtual environment"
    Write-Host "  Remove-PyVenv -Path <dir> [-Force]`t`t`t# Remove virtual environment"
    Write-Host "  Activate-Venv -Path <dir>`t`t`t`t`t# Activate virtual environment"
    Write-Host "  Get-PythonExecutable -Version <version>`t`t# Get Python executable path"
    Write-Host "  Get-AvailablePythonVersions`t`t`t`t# List available Python versions"
    Write-Host "  Get-InstalledPythonVersions`t`t`t`t# List installed Python versions"
    Write-Host "  Find-PyVenvs -Root <path>`t`t`t`t`t# Find virtual environments"
    Write-Host ""
}

# Main execution
try {
    Clear-Host
    Write-ColorOutput "=== Python Install Manager + Virtual Environment Helpers ===" Cyan
    
    # Check privileges
    if (-not (Test-Admin)) {
        Write-ColorOutput "Running without administrator privileges. Using user scope for installations." Yellow
    }
    
    # Check WinGet
    if (-not (Test-WinGet)) {
        Write-ColorOutput "Warning: WinGet not available. Some functionality may be limited." Yellow
    }
    
    # Install Python Install Manager
    Write-ColorOutput "Setting up Python Install Manager..." Cyan
    if (-not (Install-PyManager)) {
        Write-ColorOutput "Failed to install Python Install Manager" Red
        exit 1
    }
    
    # Validate py launcher
    if (-not (Test-PyLauncher)) {
        Write-ColorOutput "Python launcher validation failed" Red
        exit 1
    }
    
    # Get version information
    $availableVersions = Get-AvailablePythonVersions
    $installedVersions = Get-InstalledPythonVersions
    
    # Determine version to install
    if ($PythonVersion) {
        $selectedVersion = $PythonVersion.Trim()
        if ($availableVersions -notcontains $selectedVersion) {
            Write-ColorOutput "Requested version '$selectedVersion' not in available list. Using latest." Yellow
            $selectedVersion = $availableVersions[0]
        }
    }
    else {
        # Show available versions and prompt
        Show-VersionTable -Versions $availableVersions -Installed $installedVersions
        Write-Host ""
        $userInput = Read-Host "Enter Python version to install (press Enter for latest $($availableVersions[0]))"
        
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $selectedVersion = $availableVersions[0]
        }
        else {
            $selectedVersion = $userInput.Trim()
            if ($availableVersions -notcontains $selectedVersion) {
                Write-ColorOutput "Version '$selectedVersion' not found. Using latest $($availableVersions[0])" Yellow
                $selectedVersion = $availableVersions[0]
            }
        }
    }
    
    Write-ColorOutput "Selected Python version: $selectedVersion" Cyan
    
    # Install Python if not already installed
    if ($installedVersions -contains $selectedVersion) {
        Write-ColorOutput "Python $selectedVersion is already installed" Green
    }
    else {
        Write-ColorOutput "Installing Python $selectedVersion..." Yellow
        if (-not (Invoke-Retry -ScriptBlock { & py install $selectedVersion } -Attempts 3 -Delay 20)) {
            Write-ColorOutput "Failed to install Python $selectedVersion" Red
            exit 1
        }
    }
    
    # Set PY_PYTHON environment variable
    try {
        $versionParts = $selectedVersion -split '\.'
        $majorMinor = "$($versionParts[0]).$($versionParts[1])"
        [Environment]::SetEnvironmentVariable("PY_PYTHON", $majorMinor, "User")
        Write-ColorOutput "Set PY_PYTHON=$majorMinor for user environment" Green
    }
    catch {
        Write-ColorOutput "Note: Could not set PY_PYTHON environment variable" Yellow
    }
    
    # Validation
    Clear-Host
    Write-ColorOutput "=== Installation Validation ===" Cyan
    
    # Test the installed Python
    try {
        $versionOutput = & py -$majorMinor --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Python version: $versionOutput" Green
        }
        else {
            Write-ColorOutput "Warning: Could not verify Python version" Yellow
        }
    }
    catch {
        Write-ColorOutput "Warning: Python version check failed" Yellow
    }
    
    # Get Python executable path
    $pythonExecutable = Get-PythonExecutable -Version $majorMinor
    if ($pythonExecutable) {
        Write-ColorOutput "Python executable: $pythonExecutable" Green
    }
    else {
        Write-ColorOutput "Warning: Could not locate Python executable" Yellow
    }
    
    Write-Host ""
    Show-Help
    Write-Host ""
    
    Write-ColorOutput "✅ Python $selectedVersion setup completed successfully!" Green
    Write-ColorOutput "Virtual environment helper functions are now available in this session." Cyan
    Write-Host ""
    
    # Optional: Wait for user input before closing
    if ($Host.Name -eq "ConsoleHost") {
        Write-ColorOutput "Press Enter to close..." -NoNewline
        $null = Read-Host
    }
}
catch {
    Write-ColorOutput "Fatal error: $($_.Exception.Message)" Red
    Write-ColorOutput "Stack trace: $($_.ScriptStackTrace)" Red
    exit 1
}