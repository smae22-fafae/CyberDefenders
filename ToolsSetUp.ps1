# Basic CyberDefenders toolkit installer

$ErrorActionPreference = "Stop"

# --- quick admin check (winget/appx usually need elevation) ---

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "Please run this script in an elevated PowerShell (Run as administrator)." -ForegroundColor Yellow
    return
}

# --- winget ---

$wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue

if (-not $wingetCmd) {
    Write-Host "winget not found, trying to enable it..."

    # Windows Sandbox usually runs as WDAGUtilityAccount
    $isSandbox = ($env:USERNAME -eq 'WDAGUtilityAccount')

    if ($isSandbox) {
        # Windows 11 Enterprise Sandbox
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
        Repair-WinGetPackageManager

        # msstore is pointless/noisy in sandbox
        try { winget source remove msstore | Out-Null } catch {}
    } else {
        # Regular Windows 10/11 with App Installer
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
        # leave msstore alone here, some people actually use it
    }

    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
}

if (-not $wingetCmd) {
    Write-Host "winget still not available, aborting." -ForegroundColor Red
    exit 1
}

Write-Host "winget detected: $($wingetCmd.Source)"

$commonWingetArgs = @(
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements",
    "--source", "winget"
)

# --- tools via winget ---

winget install --id Python.Python.3.11           @commonWingetArgs
winget install --id WiresharkFoundation.Wireshark @commonWingetArgs
winget install --id SleuthKit.Autopsy            @commonWingetArgs
winget install --id MHNexus.HxD                  @commonWingetArgs
winget install --id NSA.Ghidra                   @commonWingetArgs
winget install --id GCHQ.CyberChef               @commonWingetArgs
winget install --id RegRipper.RegRipper          @commonWingetArgs
winget install --id OpenWall.John                @commonWingetArgs
winget install --id Velocidex.Velociraptor       @commonWingetArgs

# --- Volatility 3 ---

$python = Get-Command python.exe -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host ""
    Write-Host "python.exe not on PATH in this session." -ForegroundColor Yellow
    Write-Host "Open a new elevated PowerShell and run:" 
    Write-Host "  python -m ensurepip --upgrade"
    Write-Host "  python -m pip install --upgrade pip"
    Write-Host "  python -m pip install volatility3"
    exit 0
}

python -m ensurepip --upgrade
python -m pip install --upgrade pip
python -m pip install volatility3

Write-Host ""
Write-Host "Install complete. Test with: python -m volatility3 -h"

# --- Add Python and vol.exe to PATH ---

# Look for Python 3.11 first (preferred), then fall back to any Python3x installed
$pythonRoot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Python" -Directory |
    Where-Object { $_.Name -match "^Python3" } |
    Sort-Object Name -Descending |
    Select-Object -First 1

if ($pythonRoot) {
    $pythonDir   = $pythonRoot.FullName
    $scriptsDir  = Join-Path $pythonDir "Scripts"
    $pythonExe   = Join-Path $pythonDir "python.exe"
    $volExe      = Join-Path $scriptsDir "vol.exe"

    # Add to PATH for future consoles
    setx PATH "$env:PATH;$pythonDir;$scriptsDir" | Out-Null

    # Also add it in *this* session
    $env:PATH = "$env:PATH;$pythonDir;$scriptsDir"

    Write-Host "Added to PATH:"
    Write-Host "  $pythonDir"
    Write-Host "  $scriptsDir"

    if (Test-Path $volExe) {
        Write-Host "Volatility launcher detected: $volExe"
    } else {
        Write-Host "vol.exe not found in Scripts — but plugins and CLI still work via 'python -m volatility3.cli'."
    }
} else {
    Write-Host "No Python installation found under $env:LOCALAPPDATA\Programs\Python"
}
