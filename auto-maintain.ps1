#!/usr/bin/env pwsh
#
# auto-maintain.ps1
# Comprehensive System Maintenance Script
# Created: 2025-04-25
#
# This script performs system maintenance by:
# - Loading configuration from maintenance-config.json
# - Implementing system optimization
# - Checking for system and application updates
# - Detailed logging and error handling
#
# Can be run manually or scheduled via schedule-maintenance.ps1

#region Script Parameters
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\maintenance-config.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Silent,
    
    [Parameter(Mandatory = $false)]
    [switch]$UpdateOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$OptimizeOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceRun
)
#endregion

#region Script Initialization
# Ensure script can run without administrative privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Get script metadata for logging
$scriptVersion = "1.0.0"
$scriptPath = $MyInvocation.MyCommand.Path
$scriptName = $MyInvocation.MyCommand.Name
$scriptStartTime = Get-Date
$hostname = [System.Net.Dns]::GetHostName()
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue

# Initialize error tracking
$errorCount = 0
$warningCount = 0
$successCount = 0

# Initialize result object
$results = [PSCustomObject]@{
    StartTime = $scriptStartTime
    EndTime = $null
    Duration = $null
    Status = "Running"
    OptimizerResults = @()
    UpdateResults = @()
    Errors = @()
    Warnings = @()
}

# Set default transcript path in case config loading fails
$transcriptPath = Join-Path -Path $env:USERPROFILE -ChildPath "maintenance_logs\$(Get-Date -Format 'yyyy-MM-dd')-maintenance.log"
#endregion

#region Helper Functions
# Function to format file sizes
function Format-FileSize {
    param ([int64]$Size)
    
    if ($Size -gt 1TB) { return "{0:N2} TB" -f ($Size / 1TB) }
    if ($Size -gt 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    if ($Size -gt 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    if ($Size -gt 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
    
    return "$Size bytes"
}

# Function to load and validate the configuration file
function Get-MaintenanceConfig {
    param (
        [string]$Path
    )
    
    try {
        if (-not (Test-Path -Path $Path)) {
            throw "Configuration file not found at $Path"
        }
        
        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
        
        # Expand environment variables in paths
        $config.General.LogPath = $ExecutionContext.InvokeCommand.ExpandString($config.General.LogPath)
        
        # Validate required configuration sections
        if (-not $config.General -or -not $config.Optimization -or -not $config.Updates) {
            throw "Invalid configuration file format. Missing required sections."
        }
        
        return $config
    }
    catch {
        Write-Host "Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# Function to setup logging
function Initialize-MaintenanceLog {
    param (
        [PSCustomObject]$Config
    )
    
    $logFolder = $Config.General.LogPath
    
    # Create log directory if it doesn't exist
    if (-not (Test-Path -Path $logFolder)) {
        New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
    }
    
    # Clean up old logs
    if ($Config.General.MaxLogAgeInDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$Config.General.MaxLogAgeInDays)
        Get-ChildItem -Path $logFolder -Filter "*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # Set log file path
    $logFile = Join-Path -Path $logFolder -ChildPath "$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss')-maintenance.log"
    
    return $logFile
}

# Function to write to log file and console
function Write-MaintenanceLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Error", "Warning", "Success")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] [$Level] $Message"
    
    # Write to transcript (automatically handled by Start-Transcript)
    Write-Output $formattedMessage
    
    # Write to console with color
    if (-not $NoConsole -and -not $Silent) {
        $colors = @{
            Info = "White"
            Error = "Red"
            Warning = "Yellow"
            Success = "Green"
        }
        
        Write-Host $formattedMessage -ForegroundColor $colors[$Level]
    }
    
    # Track errors and warnings
    switch ($Level) {
        "Error" { 
            $script:errorCount++ 
            $script:results.Errors += $Message
        }
        "Warning" { 
            $script:warningCount++ 
            $script:results.Warnings += $Message
        }
        "Success" { $script:successCount++ }
    }
}

# Function to display progress bar
function Show-MaintenanceProgress {
    param (
        [int]$PercentComplete,
        [string]$Status,
        [string]$Activity
    )
    
    if ($Silent) { return }
    
    # Display console progress bar
    $barWidth = 50
    $completeWidth = [math]::Floor($barWidth * ($PercentComplete / 100))
    
    Write-Host "`r[$Activity] " -NoNewline -ForegroundColor Cyan
    Write-Host "[" -NoNewline
    
    # Draw progress bar
    for ($i = 0; $i -lt $barWidth; $i++) {
        if ($i -lt $completeWidth) {
            Write-Host "■" -NoNewline -ForegroundColor Cyan
        }
        else {
            Write-Host "□" -NoNewline -ForegroundColor Gray
        }
    }
    
    Write-Host "] " -NoNewline
    Write-Host "$PercentComplete% " -NoNewline -ForegroundColor Yellow
    Write-Host "$Status" -NoNewline
    
    # Clear the rest of the line
    Write-Host "                                        " -NoNewline
}

# Function to check if system is on battery
function Test-OnBattery {
    try {
        $powerStatus = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        
        if ($powerStatus -and $powerStatus.BatteryStatus -ne $null) {
            # 1 = On Battery, 2 = AC Power
            return $powerStatus.BatteryStatus -eq 1
        }
        
        # Assume desktop if no battery is found
        return $false
    }
    catch {
        # Assume not on battery if there's an error
        return $false
    }
}

# Function to show notifications
function Show-MaintenanceNotification {
    param (
        [string]$Title,
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    if (-not $Config.General.NotificationsEnabled -or $Silent) { return }
    
    try {
        # Use BurntToast module if available
        if (Get-Module -ListAvailable -Name BurntToast) {
            $btSeverity = switch ($Type) {
                "Info" { "Low" }
                "Warning" { "Medium" }
                "Error" { "High" }
            }
            
            New-BurntToastNotification -Text $Title, $Message -Silent -UniqueIdentifier "SystemMaintenance" -ProgressBar $(New-BTProgressBar -Status $Message -Value 1) -Severity $btSeverity
        }
        else {
            # Fallback to Windows notification
            $notifier = New-Object System.Windows.Forms.NotifyIcon
            $notifier.Icon = [System.Drawing.SystemIcons]::Information
            $notifier.BalloonTipTitle = $Title
            $notifier.BalloonTipText = $Message
            $notifier.Visible = $true
            $notifier.ShowBalloonTip(5000)
        }
    }
    catch {
        # If notification fails, just log it
        Write-MaintenanceLog "Failed to show notification: $($_.Exception.Message)" -Level Warning -NoConsole
    }
}

# Function to get current memory usage
function Get-MemoryStatus {
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        
        if ($os) {
            $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
            $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
            $usedMemoryGB = [math]::Round($totalMemoryGB - $freeMemoryGB, 2)
            $memoryUsagePercentage = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 0)
            
            return @{
                TotalGB = $totalMemoryGB
                FreeGB = $freeMemoryGB
                UsedGB = $usedMemoryGB
                UsagePercentage = $memoryUsagePercentage
            }
        }
    }
    catch {
        Write-MaintenanceLog "Failed to get memory status: $($_.Exception.Message)" -Level Warning
    }
    
    return $null
}
#endregion

#region Optimization Functions
# Function to clean temporary files
function Optimize-TempFiles {
    param (
        [PSCustomObject]$Config
    )
    
    Write-MaintenanceLog "Starting temporary files cleanup" -Level Info
    
    $cleanupPaths = @(
        # System temp folders
        [System.IO.Path]::GetTempPath(),
        "$env:USERPROFILE\AppData\Local\Temp",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Temporary Internet Files",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\INetCache",
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\WER",
        
        # Windows update cleanup (non-admin)
        "$env:USERPROFILE\AppData\Local\Microsoft\Windows\SoftwareDistribution\Download"
    )
    
    # Browser cache paths
    $browserPaths = @{
        Edge = @(
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\js",
            "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"
        )
        Chrome = @(
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
            "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\js"
        )
        Firefox = @(
            "$env:APPDATA\Mozilla\Firefox\Profiles"
        )
    }
    
    $totalSizeBefore = 0
    $totalFilesRemoved = 0
    $totalBytesFreed = 0
    
    # Process standard temp paths
    foreach ($path in $cleanupPaths) {
        if (Test-Path $path) {
            try {
                $files = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue
                $pathSize = ($files | Measure-Object -Property Length -Sum).Sum
                $pathFiles = ($files | Measure-Object).Count
                
                $totalSizeBefore += $pathSize
                
                Write-MaintenanceLog "Cleaning $pathFiles files in $path ($(Format-FileSize $pathSize))" -Level Info
                Remove-Item -Path "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
                
                $totalFilesRemoved += $pathFiles
            }
            catch {
                Write-MaintenanceLog "Error cleaning $path : $($_.Exception.Message)" -Level Warning
            }
        }
    }
    
    # Only clean browser cache if enabled
    if ($Config.Optimization.ClearBrowserCache) {
        foreach ($browser in $browserPaths.Keys) {
            foreach ($path in $browserPaths[$browser]) {
                if (Test-Path $path) {
                    try {
                        # Special handling for Firefox profiles
                        if ($path -like "*Firefox\Profiles") {
                            $profiles = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue
                            foreach ($profile in $profiles) {
                                $cachePath = Join-Path -Path $profile.FullName -ChildPath "cache2"
                                
                                if (Test-Path $cachePath) {
                                    $files = Get-ChildItem -Path $cachePath -Recurse -File -ErrorAction SilentlyContinue
                                    $cacheSize = ($files | Measure-Object -Property Length -Sum).Sum
                                    $cacheFiles = ($files | Measure-Object).Count
                                    
                                    $totalSizeBefore += $cacheSize
                                    
                                    Write-MaintenanceLog "Cleaning $cacheFiles files in Firefox cache ($(Format-FileSize $cacheSize))" -Level Info
                                    Remove-Item -Path "$cachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                                    
                                    $totalFilesRemoved += $cacheFiles
                                }
                            }
                        }
                        else {
                            $files = Get-ChildItem -Path

