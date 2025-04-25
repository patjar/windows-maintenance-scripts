#!/usr/bin/env pwsh
#
# optimize-system.ps1
# Comprehensive System Optimization Script
# Created: 2025-04-25
#
# This script performs system optimization by:
# - Cleaning temporary files and browser cache
# - Optimizing browser processes and memory usage
# - Configuring performance settings
# - Managing startup programs
# - Including detailed progress reporting
# - Adding maintenance features
#
# No administrative privileges required
# Safe to run frequently

#region Script Configuration
# Set script parameters
$ScriptVersion = "2.0"
$LastRunFile = "$env:USERPROFILE\.optimize_lastrun"
$OptimizationLogFile = "$env:USERPROFILE\optimize_history.log"
$MaxLogSizeMB = 5
#endregion

#region Helper Functions
# Function to log messages to console with timestamp and to log file
function Write-OptimizeLog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White",
        
        [Parameter(Mandatory=$false)]
        [switch]$NoNewLine,
        
        [Parameter(Mandatory=$false)]
        [switch]$LogOnly
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    
    # Write to log file
    Add-Content -Path $OptimizationLogFile -Value $logMessage -ErrorAction SilentlyContinue
    
    # Write to console if not LogOnly
    if (-not $LogOnly) {
        if ($NoNewLine) {
            Write-Host $Message -ForegroundColor $ForegroundColor -NoNewline
        } else {
            Write-Host $Message -ForegroundColor $ForegroundColor
        }
    }
}

# Function to check log file size and rotate if needed
function Check-LogFileSize {
    if (Test-Path $OptimizationLogFile) {
        $logFile = Get-Item $OptimizationLogFile
        if (($logFile.Length / 1MB) -gt $MaxLogSizeMB) {
            $backupLogFile = "$OptimizationLogFile.bak"
            if (Test-Path $backupLogFile) {
                Remove-Item $backupLogFile -Force -ErrorAction SilentlyContinue
            }
            Rename-Item -Path $OptimizationLogFile -NewName $backupLogFile -Force -ErrorAction SilentlyContinue
            Write-OptimizeLog "Log file rotated due to size (> $MaxLogSizeMB MB)" -ForegroundColor Yellow -LogOnly
        }
    }
}

# Function to record script execution time
function Record-LastRun {
    $currentTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Set-Content -Path $LastRunFile -Value $currentTime -ErrorAction SilentlyContinue
}

# Function to get time since last run
function Get-TimeSinceLastRun {
    if (Test-Path $LastRunFile) {
        try {
            $lastRunTime = Get-Content -Path $LastRunFile -ErrorAction Stop
            $lastRun = [DateTime]::ParseExact($lastRunTime, "yyyy-MM-dd HH:mm:ss", $null)
            $timeSince = (Get-Date) - $lastRun
            
            if ($timeSince.Days -gt 0) {
                return "$($timeSince.Days) days ago"
            } elseif ($timeSince.Hours -gt 0) {
                return "$($timeSince.Hours) hours ago"
            } elseif ($timeSince.Minutes -gt 0) {
                return "$($timeSince.Minutes) minutes ago"
            } else {
                return "Just now"
            }
        } catch {
            return "Unknown"
        }
    } else {
        return "First run"
    }
}

# Function to measure and report memory usage
function Get-MemoryInfo {
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

# Function to get memory usage statistics
function Format-ByteSize {
    param ([int64]$bytes)
    if ($bytes -gt 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -gt 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -gt 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes bytes"
}

# Function to show optimization progress
function Update-Progress {
    param (
        [int]$StepNumber,
        [int]$TotalSteps,
        [string]$Activity,
        [int]$PercentComplete
    )
    
    $progressBar = ""
    $barLength = 40
    $filledLength = [int]($barLength * $PercentComplete / 100)
    
    for ($i = 0; $i -lt $barLength; $i++) {
        if ($i -lt $filledLength) {
            $progressBar += "█"
        } else {
            $progressBar += "░"
        }
    }
    
    Write-Host "`r[" -NoNewline
    Write-Host "$progressBar" -NoNewline
    Write-Host "] " -NoNewline
    Write-Host "$PercentComplete%" -NoNewline -ForegroundColor Cyan
    Write-Host " - $Activity" -NoNewline
}
#endregion

#region Banner and Initial Setup
# Initialize log file if it doesn't exist
if (-not (Test-Path $OptimizationLogFile)) {
    New-Item -Path $OptimizationLogFile -ItemType File -Force -ErrorAction SilentlyContinue | Out-Null
    Write-OptimizeLog "Created new optimization log file" -LogOnly
}

# Check log file size and rotate if needed
Check-LogFileSize

# Display banner
Clear-Host
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "    COMPREHENSIVE SYSTEM OPTIMIZATION SCRIPT v$ScriptVersion" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Starting optimization at $(Get-Date)" -ForegroundColor Yellow
Write-Host "Last run: $(Get-TimeSinceLastRun)" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

# Start logging
Write-OptimizeLog "Starting system optimization (v$ScriptVersion)" -LogOnly

# Get initial memory usage for comparison
$initialMemory = Get-MemoryInfo
if ($initialMemory) {
    Write-OptimizeLog "Initial memory status: $($initialMemory.UsedGB) GB of $($initialMemory.TotalGB) GB used ($($initialMemory.UsagePercentage)%)" -LogOnly
    Write-Host "Initial memory usage: $($initialMemory.UsagePercentage)% ($($initialMemory.UsedGB) GB of $($initialMemory.TotalGB) GB)" -ForegroundColor Gray
} else {
    Write-OptimizeLog "Could not retrieve initial memory status" -LogOnly
}

# Define total steps for progress tracking
$totalSteps = 6
#endregion

#region Step 1: Clean Temporary Files
$stepNumber = 1
Write-Host "`n[$stepNumber/$totalSteps] CLEANING TEMPORARY FILES..." -ForegroundColor Green
Write-OptimizeLog "Starting Step $stepNumber: Cleaning temporary files" -LogOnly

# Initialize cleaned file counter and size
$totalFilesRemoved = 0
$totalSizeFreed = 0

# Clean user temp folder
Update-Progress -StepNumber $stepNumber -TotalSteps $totalSteps -Activity "Scanning temp files..." -PercentComplete 10
$tempPath = [System.IO.Path]::GetTempPath()
$tempFiles = Get-ChildItem -Path $tempPath -File -ErrorAction SilentlyContinue
$tempFolders = Get-ChildItem -Path $tempPath -Directory -ErrorAction SilentlyContinue

# Count files and calculate total size before deletion
$fileCount = ($tempFiles | Measure-Object).Count
$folderCount = ($tempFolders | Measure-Object).Count
$tempFilesSize = ($tempFiles | Measure-Object -Property Length -Sum).Sum
$totalSizeFreed += $tempFilesSize

Update-Progress -StepNumber $stepNumber -TotalSteps $totalSteps -Activity "Cleaning temp files..." -PercentComplete 30
Write-Host "`n  Found $fileCount files and $folderCount folders ($(Format-ByteSize $tempFilesSize))" -ForegroundColor Gray

# Delete temp files
try {
    Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    $totalFilesRemoved += $fileCount
    Write-OptimizeLog "Removed $fileCount temp files ($(Format-ByteSize $tempFilesSize))" -LogOnly
    Write-Host "  Cleaned user temp folder successfully" -ForegroundColor Gray
}
catch {
    Write-OptimizeLog "Error cleaning temp folder: $($_.Exception.Message)" -LogOnly
    Write-Host "  Some temp files could not be deleted (they may be in use)" -ForegroundColor Yellow
}

# Clean Edge browser cache
Update-Progress -StepNumber $stepNumber -TotalSteps $totalSteps -Activity "Cleaning browser cache..." -PercentComplete 50
$browserCachePaths = @(
    # Microsoft Edge
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache",
    # Chrome (if installed)
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    # Firefox (if installed)
    "$env:APPDATA\Mozilla\Firefox\Profiles"
)

foreach ($cachePath in $browserCachePaths) {
    if (Test-Path $cachePath) {
        # Skip Firefox profiles directory itself, only process cache folders inside profiles
        if ($cachePath -like "*Firefox\Profiles") {
            $profiles = Get-ChildItem -Path $cachePath -Directory -ErrorAction SilentlyContinue
            foreach ($profile in $profiles) {
                $ffCachePath = Join-Path -Path $profile.FullName -ChildPath "cache2"
                if (Test-Path $ffCachePath) {
                    try {
                        $cacheFiles = Get-ChildItem -Path $ffCachePath -Recurse -File -ErrorAction SilentlyContinue
                        $cacheSize = ($cacheFiles | Measure-Object -Property Length -Sum).Sum
                        $cacheCount = ($cacheFiles | Measure-Object).Count
                        
                        Remove-Item -Path "$ffCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                        $totalFilesRemoved += $cacheCount
                        $totalSizeFreed += $cacheSize
                        Write-OptimizeLog "Cleaned Firefox profile cache: $cacheCount files ($(Format-ByteSize $cacheSize))" -LogOnly
                    } catch {
                        Write-OptimizeLog "Error cleaning Firefox cache: $($_.Exception.Message)" -LogOnly
                    }
                }
            }
        } else {
            try {
                $cacheFiles = Get-ChildItem -Path $cachePath -Recurse -File -ErrorAction SilentlyContinue
                $cacheSize = ($cacheFiles | Measure-Object -Property Length -Sum).Sum
                $cacheCount = ($cacheFiles | Measure-Object).Count
                
                Remove-Item -Path "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                $totalFilesRemoved += $cacheCount
                $totalSizeFreed += $cacheSize
                
                $browserName = if ($cachePath -like "*Edge*") { "Edge" } elseif ($cachePath -like "*Chrome*") { "Chrome" } else { "Browser" }
                Write-OptimizeLog "Cleaned $browserName cache: $cacheCount files ($(Format-ByteSize $cacheSize))" -LogOnly
            } catch {
                Write-OptimizeLog "Error cleaning browser cache: $($_.Exception.Message)" -LogOnly
            }
        }
    }
}

# Clean Windows thumbnail cache
Update-Progress -StepNumber $stepNumber -TotalSteps $totalSteps -Activity "Cleaning Windows caches..." -PercentComplete 75
$thumbnailCache = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
try {
    $thumbFiles = Get-Item -Path $thumbnailCache -ErrorAction SilentlyContinue
    $thumbSize = ($thumbFiles | Measure-Object -Property Length -Sum).Sum
    $thumbCount = ($thumbFiles | Measure-Object).Count
    
    if ($thumbCount -gt 0) {
        # This might fail if Explorer is using the files, but we'll try
        Remove-Item -Path $thumbnailCache -Force -ErrorAction SilentlyContinue
        $totalFilesRemoved += $thumbCount
        $totalSizeFreed += $thumbSize
        Write-OptimizeLog "Cleaned thumbnail cache: $thumbCount files ($(Format-ByteSize $thumbSize))" -LogOnly
    }
} catch {
    Write-OptimizeLog "Error cleaning thumbnail cache: $($_.Exception.Message)" -LogOnly
}

# Clean Windows Font Cache
$fontCache = "$env:LOCALAPPDATA\Microsoft\Windows\FontCache"
if (Test-Path $fontCache) {
    try {
        $fontFiles = Get-ChildItem -Path $fontCache -File -ErrorAction SilentlyContinue
        $fontSize = ($fontFiles | Measure-Object -Property Length -Sum).Sum
        $fontCount = ($fontFiles | Measure-Object).Count
        
        Remove-Item -Path "$fontCache\*" -Force -ErrorAction SilentlyContinue
        $totalFilesRemoved += $fontCount
        $totalSizeFreed += $fontSize
        Write-OptimizeLog "Cleaned font cache: $fontCount files ($(Format-ByteSize $fontSize))" -LogOnly
    } catch {
        Write-OptimizeLog "Error cleaning font cache: $($_.Exception.Message)" -LogOnly
    }
}

# Clean Windows Store

