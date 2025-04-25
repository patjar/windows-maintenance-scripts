#!/usr/bin/env pwsh
#
# check-updates.ps1
# System Update Checker Script
# Created: 2025-04-25
#
# This script helps check for system updates by:
# - Displaying current system version information
# - Showing Edge browser version
# - Listing installed Store apps and their versions
# - Launching update interfaces
#
# No admin privileges required

# Show a banner for the script
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "           SYSTEM UPDATE CHECKER SCRIPT" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Running update check at $(Get-Date)`n" -ForegroundColor Yellow

#region System Version Information
Write-Host "STEP 1: Checking System Version Information..." -ForegroundColor Green

# Get system info
try {
    $computerInfo = Get-ComputerInfo -ErrorAction Stop
    
    # Extract key information
    $osName = $computerInfo.WindowsProductName
    $osVersion = $computerInfo.WindowsVersion
    $osBuild = $computerInfo.OsBuildNumber
    $osArch = $computerInfo.OsArchitecture
    
    # Display system information
    Write-Host "  Operating System: $osName" -ForegroundColor White
    Write-Host "  Version: $osVersion (Build $osBuild)" -ForegroundColor White
    Write-Host "  Architecture: $osArch" -ForegroundColor White
}
catch {
    Write-Host "  Could not retrieve complete system information" -ForegroundColor Yellow
    
    # Fallback to basic WMI
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        Write-Host "  Operating System: $($os.Caption)" -ForegroundColor White
        Write-Host "  Version: $($os.Version)" -ForegroundColor White
    }
    catch {
        Write-Host "  Unable to retrieve system information" -ForegroundColor Red
    }
}
#endregion

#region Edge Browser Version
Write-Host "`nSTEP 2: Checking Microsoft Edge Version..." -ForegroundColor Green

# Get Edge version from registry
try {
    $edgeVersion = (Get-ItemProperty 'HKCU:\Software\Microsoft\Edge\BLBeacon' -ErrorAction Stop).version
    Write-Host "  Microsoft Edge Version: $edgeVersion" -ForegroundColor White
    
    # Compare with known latest version (this would need regular updates)
    $latestKnownVersion = "136.0.0.0" # Example latest version
    if ([version]$edgeVersion -lt [version]$latestKnownVersion) {
        Write-Host "  Update may be available for Edge" -ForegroundColor Yellow
    }
    else {
        Write-Host "  Edge appears to be up to date" -ForegroundColor Green
    }
}
catch {
    Write-Host "  Could not determine Edge version from registry" -ForegroundColor Yellow
    
    # Alternative detection method
    try {
        $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        if (!(Test-Path $edgePath)) {
            $edgePath = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        }
        
        if (Test-Path $edgePath) {
            $edgeVersion = (Get-Item $edgePath).VersionInfo.ProductVersion
            Write-Host "  Microsoft Edge Version: $edgeVersion (from executable)" -ForegroundColor White
        }
        else {
            Write-Host "  Could not locate Edge executable" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  Unable to determine Edge version" -ForegroundColor Red
    }
}
#endregion

#region Store Apps Information
Write-Host "`nSTEP 3: Listing Key Microsoft Store Apps..." -ForegroundColor Green

# Define list of important apps to check
$keyApps = @(
    "Microsoft.WindowsStore",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.WindowsCalculator",
    "Microsoft.Windows.Photos"
)

# Get all Store apps
try {
    # Get all Store apps
    $storeApps = Get-AppxPackage -ErrorAction Stop
    
    # Filter for key apps
    $keyStoreApps = $storeApps | Where-Object { $appName = $_.Name; $keyApps | Where-Object { $appName -like "$_*" } }
    
    if ($keyStoreApps.Count -gt 0) {
        Write-Host "  Found $($keyStoreApps.Count) key Microsoft Store apps:" -ForegroundColor White
        $keyStoreApps | ForEach-Object {
            Write-Host "    $($_.Name) (Version: $($_.Version))" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  No key Microsoft Store apps found" -ForegroundColor Yellow
    }
    
    # Check Microsoft Store specifically
    $msStore = $storeApps | Where-Object { $_.Name -eq "Microsoft.WindowsStore" }
    if ($msStore) {
        Write-Host "`n  Microsoft Store Version: $($msStore.Version)" -ForegroundColor White
    }
}
catch {
    Write-Host "  Error retrieving Store apps information: $($_.Exception.Message)" -ForegroundColor Red
}
#endregion

#region Update Launchers
Write-Host "`nSTEP 4: Preparing Update Interfaces..." -ForegroundColor Green

Write-Host "  The following update interfaces will be launched:" -ForegroundColor White
Write-Host "    1. Windows Update" -ForegroundColor Gray
Write-Host "    2. Microsoft Store Updates" -ForegroundColor Gray
Write-Host "    3. Microsoft Edge Update" -ForegroundColor Gray

$launchUpdates = $false
$response = Read-Host "`n  Would you like to launch these update interfaces now? (y/n)"

if ($response.ToLower() -eq "y") {
    $launchUpdates = $true
}

if ($launchUpdates) {
    Write-Host "`n  Launching update interfaces..." -ForegroundColor Green
    
    # Launch Windows Update
    try {
        Start-Process "ms-settings:windowsupdate" -ErrorAction Stop
        Write-Host "    ✓ Windows Update settings opened" -ForegroundColor Green
    }
    catch {
        Write-Host "    ✗ Could not open Windows Update settings" -ForegroundColor Red
    }
    
    # Wait before launching next window
    Start-Sleep -Seconds 1
    
    # Launch Microsoft Store Updates
    try {
        Start-Process "ms-windows-store://downloadsandupdates" -ErrorAction Stop
        Write-Host "    ✓ Microsoft Store Updates opened" -ForegroundColor Green
    }
    catch {
        Write-Host "    ✗ Could not open Microsoft Store Updates" -ForegroundColor Red
    }
    
    # Wait before launching next window
    Start-Sleep -Seconds 1
    
    # Launch Edge Update
    try {
        Start-Process "microsoft-edge://settings/help" -ErrorAction Stop
        Write-Host "    ✓ Microsoft Edge Update page opened" -ForegroundColor Green
    }
    catch {
        Write-Host "    ✗ Could not open Microsoft Edge Update page" -ForegroundColor Red
    }
}
#endregion

#region Update Instructions
Write-Host "`nSTEP 5: Update Instructions" -ForegroundColor Green

Write-Host "`n  Follow these steps in each update window:" -ForegroundColor White
Write-Host "`n  Windows Update:" -ForegroundColor Cyan
Write-Host "    1. Click 'Check for updates'" -ForegroundColor Gray
Write-Host "    2. If updates are found, click 'Download' or 'Install now'" -ForegroundColor Gray
Write-Host "    3. Follow any prompts for restart if required" -ForegroundColor Gray

Write-Host "`n  Microsoft Store:" -ForegroundColor Cyan
Write-Host "    1. Click 'Get updates' to check for app updates" -ForegroundColor Gray
Write-Host "    2. Wait for all updates to install" -ForegroundColor Gray
Write-Host "    3. Restart apps after updating if needed" -ForegroundColor Gray

Write-Host "`n  Microsoft Edge:" -ForegroundColor Cyan
Write-Host "    1. Edge will automatically check for updates" -ForegroundColor Gray
Write-Host "    2. If an update is available, click 'Restart'" -ForegroundColor Gray
Write-Host "    3. You may need to close and reopen Edge after updating" -ForegroundColor Gray
#endregion

#region Summary
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "               UPDATE CHECK COMPLETE" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Run this script periodically to keep your system up to date" -ForegroundColor White
Write-Host "Next recommended check: $(([DateTime]::Now).AddDays(7).ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan
#endregion

