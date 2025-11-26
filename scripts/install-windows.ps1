<#
.SYNOPSIS
    Python Environment Manager - A helper script for pymanager (py) on Windows.
.DESCRIPTION
    Provides functions to list, install, and uninstall Python runtimes, as well as create virtual environments.
    This script requires the Python Install Manager to be installed on your system.
.NOTES
    Ensure you have the Python Install Manager installed via Winget or the Microsoft Store.
#>

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Get-PythonInstallManager {
    <#
    .SYNOPSIS
        Checks for the presence of the Python Install Manager (py).
    #>
    if (Get-Command py -ErrorAction SilentlyContinue) {
        Write-ColorOutput "✓ Python Install Manager (py) is available." "Green"
        return $true
    } else {
        Write-ColorOutput "✗ Python Install Manager (py) is not found." "Red"
        Write-ColorOutput "  Please install it via Winget:" "Yellow"
        Write-ColorOutput "  winget install 9NQ7512CXL7T" "Cyan"
        Write-ColorOutput "  Or from the Microsoft Store." "Yellow"
        return $false
    }
}

function Get-AvailablePythonVersions {
    <#
    .SYNOPSIS
        Lists all Python versions available for installation online.
    #>
    Write-ColorOutput "Querying available Python versions online..." "Yellow"
    try {
        & py list --online
    }
    catch {
        Write-ColorOutput "An error occurred while fetching the online list." "Red"
    }
}

function Get-InstalledPythonVersions {
    <#
    .SYNOPSIS
        Lists all Python versions currently installed on your system.
    #>
    Write-ColorOutput "Installed Python Versions:" "Yellow"
    # Using py -0p is the standard command to list installed versions with paths[citation:5]
    & py -0p
}

function Install-PythonVersion {
    <#
    .SYNOPSIS
        Installs a specific version of Python.
    .PARAMETER Version
        The Python version to install (e.g., "3.11", "3.14.0").
    #>
    param([Parameter(Mandatory)] [string]$Version)
    
    Write-ColorOutput "Installing Python $Version..." "Yellow"
    # The core installation command for pymanager[citation:2][citation:5]
    & py install $Version
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Successfully installed Python $Version" "Green"
    } else {
        Write-ColorOutput "✗ Failed to install Python $Version" "Red"
    }
}

function Uninstall-PythonVersion {
    <#
    .SYNOPSIS
        Uninstalls a specific version of Python.
    .PARAMETER Version
        The Python version to uninstall (e.g., "3.11", "3.14.0").
    #>
    param([Parameter(Mandatory)] [string]$Version)
    
    Write-ColorOutput "Uninstalling Python $Version..." "Yellow"
    # The core uninstallation command for pymanager[citation:2]
    & py uninstall $Version
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Successfully uninstalled Python $Version" "Green"
    } else {
        Write-ColorOutput "✗ Failed to uninstall Python $Version" "Red"
    }
}

function New-PythonVenv {
    <#
    .SYNOPSIS
        Creates a Python virtual environment using a pymanager-managed Python version.
    .DESCRIPTION
        This uses the standard 'venv' module, which is the recommended way to create virtual environments[citation:8].
    .PARAMETER VenvPath
        The path where the virtual environment will be created.
    .PARAMETER PythonVersion
        The specific Python version (managed by py) to use for the environment.
    #>
    param(
        [Parameter(Mandatory)] [string]$VenvPath,
        [Parameter(Mandatory)] [string]$PythonVersion
    )
    
    Write-ColorOutput "Creating virtual environment at '$VenvPath' using Python $PythonVersion..." "Yellow"
    
    # Use the py launcher to run the venv module with the specific Python version[citation:8]
    & py -$PythonVersion -m venv $VenvPath
    
    if (Test-Path $VenvPath) {
        Write-ColorOutput "✓ Virtual environment created successfully." "Green"
        Write-ColorOutput "  To activate it, run:" "Cyan"
        Write-ColorOutput "  & `"$VenvPath\Scripts\Activate.ps1`"" "White"
    } else {
        Write-ColorOutput "✗ Failed to create virtual environment." "Red"
    }
}

function Show-PythonHelp {
    <#
    .SYNOPSIS
        Displays help information for the Python Install Manager and common commands.
    #>
    Write-ColorOutput "=== Python Install Manager (pymanager) Help ===" "Cyan"
    Write-ColorOutput "Core py commands demonstrated in this script:" "Yellow"
    Write-Host "  py list --online    " -NoNewline; Write-Host "# List available versions" "Gray"
    Write-Host "  py -0p              " -NoNewline; Write-Host "# List installed versions" "Gray"
    Write-Host "  py install <ver>    " -NoNewline; Write-Host "# Install a version" "Gray"
    Write-Host "  py uninstall <ver>  " -NoNewline; Write-Host "# Uninstall a version" "Gray"
    Write-Host "  py -<ver> -m venv   " -NoNewline; Write-Host "# Create a venv with a specific version" "Gray"
    
    Write-Host ""
    Write-ColorOutput "Example workflow to install Python 3.11 and create a virtual environment:" "Yellow"
    Write-Host "  Install-PythonVersion -Version `"3.11`"" "Cyan"
    Write-Host "  New-PythonVenv -VenvPath `".\my-project-venv`" -PythonVersion `"3.11`"" "Cyan"
}

# Main script execution
Clear-Host
Write-ColorOutput "=== Python Environment Manager ===" "Cyan"

# Check for prerequisites
if (-not (Get-PythonInstallManager)) {
    exit 1
}

Write-Host ""
Write-ColorOutput "Available commands in this session:" "Green"
Write-Host "  Get-AvailablePythonVersions"
Write-Host "  Get-InstalledPythonVersions"  
Write-Host "  Install-PythonVersion -Version <version>"
Write-Host "  Uninstall-PythonVersion -Version <version>"
Write-Host "  New-PythonVenv -VenvPath <path> -PythonVersion <version>"
Write-Host "  Show-PythonHelp"

Write-Host ""
Write-ColorOutput "Run 'Get-InstalledPythonVersions' to see your current Python setup." "Yellow"
Write-ColorOutput "Run 'Get-AvailablePythonVersions' to see what you can install." "Yellow"