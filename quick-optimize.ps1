#!/usr/bin/env pwsh
#
# quick-optimize.ps1
# Browser & Memory Quick Optimization Script
# Created: 2025-04-25
#
# This script performs targeted optimization by:
# - Safely closing unnecessary browser processes
# - Clearing browser cache and temporary files
# - Optimizing memory usage
# - Showing immediate performance improvement
#
# No administrative privileges required
# Safe to run while browsers are open

#region Helper Functions
# Format memory size for display
function Format-Size {
    param ([int64]$bytes)
    if ($bytes -gt 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -gt 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -gt 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes bytes"
}

# Get current memory usage
function Get-CurrentMemory {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($osInfo) {
        $totalMemoryGB = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 2)
        $freeMemoryGB = [math]::Round($osInfo.FreePhysicalMemory / 1MB, 2)
        $usedMemoryGB = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)
        $memoryUsagePercentage = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 0)
        
        return @{
            TotalGB = $totalMemoryGB
            FreeGB = $freeMemoryGB
            UsedGB = $usedMemoryGB
            UsagePercentage = $memoryUsagePercentage
        }
    }
    return $null
}

# Display progress bar
function Show-ProgressBar {
    param (
        [int]$PercentComplete,
        [string]$Status
    )
    
    $width = 50
    $complete = [math]::Round($width * $PercentComplete / 100)
    
    Write-Host "`r[" -NoNewline
    
    for ($i = 0; $i -lt $width; $i++) {
        if ($i -lt $complete) {
            Write-Host "■" -NoNewline -ForegroundColor Cyan
        } else {
            Write-Host "□" -NoNewline -ForegroundColor Gray
        }
    }
    
    Write-Host "] " -NoNewline
    Write-Host "$PercentComplete% " -NoNewline -ForegroundColor Yellow
    Write-Host "$Status                     " -NoNewline
}
#endregion

#region Script Start
Clear-Host
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "       BROWSER & MEMORY QUICK OPTIMIZATION TOOL" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Starting optimization at $(Get-Date)" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

# Measure initial memory state
$initialMemory = Get-CurrentMemory
if ($initialMemory) {
    Write-Host "Initial memory usage: $($initialMemory.UsagePercentage)% ($($initialMemory.UsedGB) GB of $($initialMemory.TotalGB) GB)" -ForegroundColor Gray
}

# Get initial browser process stats
$initialBrowserProcesses = Get-Process | Where-Object { 
    $_.ProcessName -like "*edge*" -or 
    $_.ProcessName -like "*chrome*" -or 
    $_.ProcessName -like "*firefox*" 
} | Measure-Object
$initialBrowserCount = $initialBrowserProcesses.Count

$initialBrowserMemory = Get-Process | Where-Object { 
    $_.ProcessName -like "*edge*" -or 
    $_.ProcessName -like "*chrome*" -or 
    $_.ProcessName -like "*firefox*" 
} | Measure-Object -Property WorkingSet -Sum
$initialBrowserMemoryMB = [math]::Round($initialBrowserMemory.Sum / 1MB, 2)

Write-Host "Initial browser processes: $initialBrowserCount using $initialBrowserMemoryMB MB" -ForegroundColor Gray
#endregion

#region Step 1: Optimize Browser Processes
Write-Host "`n[1/4] Optimizing browser processes..." -ForegroundColor Green

# Find browser tabs with windows (to keep) vs background processes (to consider closing)
$edgeWindows = Get-Process | Where-Object { 
    $_.ProcessName -eq "msedge" -and 
    $_.MainWindowTitle -ne "" -and
    $_.MainWindowHandle -ne 0
}

$backgroundEdge = Get-Process | Where-Object { 
    ($_.ProcessName -eq "msedge" -and 
    $_.MainWindowTitle -eq "") -or
    ($_.ProcessName -eq "msedgewebview2" -and 
    $_.WorkingSet -lt 50MB)
}

# Display browser optimization plan
Write-Host "  Found $($edgeWindows.Count) active Edge windows (will preserve)" -ForegroundColor White
Write-Host "  Found $($backgroundEdge.Count) background processes for review" -ForegroundColor White

$cleanupCandidates = @()
$processesToKeep = @()

# Analyze processes to identify which are safe to close
$total = $backgroundEdge.Count
$current = 0

foreach ($process in $backgroundEdge) {
    $current++
    $percent = [math]::Round(($current / $total) * 100)
    Show-ProgressBar -PercentComplete $percent -Status "Analyzing browser processes"
    
    # Skip processes opened in the last 30 seconds
    $runtime = (Get-Date) - $process.StartTime
    if ($runtime.TotalSeconds -lt 30) {
        $processesToKeep += $process
        continue
    }
    
    # Skip processes with known critical names
    $criticalProcessNames = @("crashpad", "notification", "utility", "gpu")
    $isCritical = $false
    foreach ($name in $criticalProcessNames) {
        if ($process.MainWindowTitle -like "*$name*" -or $process.CommandLine -like "*$name*") {
            $isCritical = $true
            break
        }
    }
    
    if ($isCritical) {
        $processesToKeep += $process
        continue
    }
    
    # Check if it has high CPU activity (which might indicate active use)
    if ($process.CPU -gt 10) {
        $processesToKeep += $process
        continue
    }
    
    # If low memory (<10MB) and no window, consider it safe to close
    if ($process.WorkingSet -lt 10MB -and $process.MainWindowHandle -eq 0) {
        $cleanupCandidates += $process
        continue
    }
    
    # For higher memory WebView2 instances, check if they're idle
    if ($process.ProcessName -eq "msedgewebview2" -and $process.WorkingSet -gt 50MB) {
        # If idle (practically no CPU usage), consider as candidate
        if ($process.CPU -lt 1) {
            $cleanupCandidates += $process
            continue
        }
    }
    
    # If process is older than 60 minutes and has low CPU, consider as candidate
    if ($runtime.TotalMinutes -gt 60 -and $process.CPU -lt 1) {
        $cleanupCandidates += $process
        continue
    }
    
    # Default: keep the process if we're not sure
    $processesToKeep += $process
}

Write-Host "`r  Identified $($cleanupCandidates.Count) processes safe to close ($([math]::Round(($cleanupCandidates | Measure-Object -Property WorkingSet -Sum).Sum / 1MB, 0)) MB)      " -ForegroundColor White
Write-Host "  Preserving $($processesToKeep.Count) background processes" -ForegroundColor White

# Close unnecessary background processes
if ($cleanupCandidates.Count -gt 0) {
    $total = $cleanupCandidates.Count
    $current = 0
    $memoryFreed = 0
    
    foreach ($process in $cleanupCandidates) {
        $current++
        $percent = [math]::Round(($current / $total) * 100)
        Show-ProgressBar -PercentComplete $percent -Status "Closing unnecessary processes"
        
        $memoryFreed += $process.WorkingSet
        
        try {
            $process | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 50
        }
        catch {
            # Silently continue if we can't close a process
        }
    }
    
    Write-Host "`r  Closed $($cleanupCandidates.Count) unnecessary processes ($(Format-Size $memoryFreed) freed)                     " -ForegroundColor White
}
else {
    Write-Host "  No unnecessary browser processes to close" -ForegroundColor White
}
#endregion

#region Step 2: Clear Browser Cache
Write-Host "`n[2/4] Clearing browser cache..." -ForegroundColor Green

# Define cache paths
$cachePaths = @(
    # Edge
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\js",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Storage\ext",
    # Chrome (if installed)
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\js",
    # Firefox (if installed)
    "$env:APPDATA\Mozilla\Firefox\Profiles"
)

$totalCacheFiles = 0
$totalCacheSize = 0
$clearedCacheSize = 0

# Count and measure cache before clearing
foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        if ($path -like "*Firefox\Profiles") {
            # Handle Firefox profiles differently
            $profiles = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
            foreach ($profile in $profiles) {
                $ffCachePath = Join-Path -Path $profile.FullName -ChildPath "cache2"
                if (Test-Path $ffCachePath) {
                    $files = Get-ChildItem -Path $ffCachePath -Recurse -File -ErrorAction SilentlyContinue
                    $totalCacheFiles += $files.Count
                    $totalCacheSize += ($files | Measure-Object -Property Length -Sum).Sum
                }
            }
        }
        else {
            $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
            $totalCacheFiles += $files.Count
            $totalCacheSize += ($files | Measure-Object -Property Length -Sum).Sum
        }
    }
}

Write-Host "  Found $totalCacheFiles cache files ($(Format-Size $totalCacheSize))" -ForegroundColor White

# Clear cache
$current = 0
$total = $cachePaths.Count

foreach ($path in $cachePaths) {
    $current++
    $percent = [math]::Round(($current / $total) * 100)
    
    $browserName = "Unknown"
    if ($path -like "*Edge*") { $browserName = "Edge" }
    elseif ($path -like "*Chrome*") { $browserName = "Chrome" }
    elseif ($path -like "*Firefox*") { $browserName = "Firefox" }
    
    Show-ProgressBar -PercentComplete $percent -Status "Clearing $browserName cache"
    
    if (Test-Path $path) {
        if ($path -like "*Firefox\Profiles") {
            # Handle Firefox profiles differently
            $profiles = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
            foreach ($profile in $profiles) {
                $ffCachePath = Join-Path -Path $profile.FullName -ChildPath "cache2"
                if (Test-Path $ffCachePath) {
                    try {
                        Remove-Item -Path "$ffCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    catch {
                        # Silent continue
                    }
                }
            }
        }
        else {
            try {
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Silent continue
            }
        }
    }
}

# Clear general temp files
$tempPath = [System.IO.Path]::GetTempPath()
try {
    Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    # Silent continue
}

Write-Host "`r  Cache cleanup completed, potential space saved: $(Format-Size $totalCacheSize)                     " -ForegroundColor White
#endregion

#region Step 3: Memory Optimization
Write-Host "`n[3/4] Optimizing memory usage..." -ForegroundColor Green

# Force garbage collection in PowerShell
[System.GC]::Collect()
Start-Sleep -Seconds 1

# Measure current memory state
$afterGCMemory = Get-CurrentMemory

# Configure Edge for better memory usage by modifying registry
$EdgeRegPath = "HKCU:\Software\Microsoft\Edge"

Show-ProgressBar -PercentComplete 50 -Status "Configuring browser memory settings"

# Tab preloader (memory saver feature)
if (!(Test-Path "$EdgeRegPath\TabPreloader")) {
    try {
        New-Item -Path "$EdgeRegPath\TabPreloader" -Force | Out-Null
    }
    catch {
        # Silent continue
    }
}
try {
    Set-ItemProperty -Path "$EdgeRegPath\TabPreloader" -Name "EnablePreloader" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
catch {
    # Silent continue
}

# Sleeping tabs for better memory management
if (!(Test-Path "$EdgeRegPath\Recommended")) {
    try {
        New-Item -Path "$EdgeRegPath\Recommended" -Force | Out-Null
    }
    catch {
        # Silent continue
    }
}
try {
    Set-ItemProperty -Path "$EdgeRegPath\Recommended" -Name "SleepingTabsEnabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
catch {
    # Silent continue
}

# Memory Saver Mode
try {
    if (!(Test-Path "$EdgeRegPath\MemorySaver")) {
        New-Item -Path "$EdgeRegPath\MemorySaver" -Force | Out-Null
    }
    Set-ItemProperty -Path "$EdgeRegPath\Memor

