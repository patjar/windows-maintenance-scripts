#!/usr/bin/env pwsh
#
# schedule-maintenance.ps1
# Scheduled Maintenance Configuration Script
# Created: 2025-04-25
#
# This script creates scheduled tasks for system maintenance:
# - Daily optimization task
# - Weekly update check task
# - Uses settings from maintenance-config.json
#
# No administrative privileges required

#region Script Parameters
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "$PSScriptRoot\maintenance-config.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$RemoveTasks
)
#endregion

#region Helper Functions
# Function to read and validate configuration file
function Get-MaintenanceConfig {
    param (
        [string]$Path
    )
    
    try {
        if (-not (Test-Path -Path $Path)) {
            Write-Host "Configuration file not found at $Path" -ForegroundColor Red
            throw "Configuration file not found"
        }
        
        $config = Get-Content -Path $Path -Raw | ConvertFrom-Json
        
        # Check required configuration sections
        if (-not $config.Schedule) {
            Write-Host "Invalid configuration file format. Missing Schedule section." -ForegroundColor Red
            throw "Invalid configuration"
        }
        
        return $config
    }
    catch {
        Write-Host "Error loading configuration: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Function to create a scheduled task
function Register-MaintenanceTask {
    param (
        [string]$TaskName,
        [string]$Description,
        [string]$ScriptPath,
        [string]$Arguments,
        [string]$Trigger,
        [bool]$SkipIfOnBattery,
        [bool]$WakeToRun
    )
    
    try {
        # Check if task already exists
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        
        if ($existingTask -and -not $Force) {
            Write-Host "Task '$TaskName' already exists. Use -Force to replace it." -ForegroundColor Yellow
            return $false
        }
        
        # Remove existing task if -Force is specified
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "Removed existing task '$TaskName'" -ForegroundColor Yellow
        }
        
        # Create the action
        $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument $Arguments -WorkingDirectory $PSScriptRoot
        
        # Create the trigger based on the specified schedule
        $taskTrigger = $null
        
        if ($Trigger -match "(^\d{1,2}:\d{2}$)") { # Daily time format (HH:MM)
            $time = [DateTime]::Parse($Trigger)
            $taskTrigger = New-ScheduledTaskTrigger -Daily -At $time
        }
        elseif ($Trigger -match "(\w+) (\d{1,2}:\d{2})") { # Weekly day and time format
            $day = $Matches[1]
            $time = [DateTime]::Parse($Matches[2])
            
            switch ($day) {
                "Monday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $time }
                "Tuesday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Tuesday -At $time }
                "Wednesday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Wednesday -At $time }
                "Thursday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Thursday -At $time }
                "Friday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At $time }
                "Saturday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At $time }
                "Sunday" { $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $time }
                default {
                    Write-Host "Invalid day specified: $day. Using Sunday." -ForegroundColor Yellow
                    $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At $time
                }
            }
        }
        else {
            Write-Host "Invalid trigger format: $Trigger. Using default (3:00 AM daily)." -ForegroundColor Yellow
            $taskTrigger = New-ScheduledTaskTrigger -Daily -At "3:00 AM"
        }
        
        # Create settings
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:(-not $SkipIfOnBattery) -DontStopIfGoingOnBatteries:(-not $SkipIfOnBattery) -WakeToRun:$WakeToRun
        
        # Get current user for the principal
        $currentUsername = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        # Create principal (run as current user, only when logged in)
        $principal = New-ScheduledTaskPrincipal -UserId $currentUsername -LogonType Interactive -RunLevel Limited
        
        # Register the task
        Register-ScheduledTask -TaskName $TaskName -Description $Description -Action $action -Trigger $taskTrigger -Settings $settings -Principal $principal
        
        Write-Host "Successfully created scheduled task '$TaskName'" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to create task '$TaskName': $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to remove maintenance tasks
function Remove-MaintenanceTasks {
    $tasks = @("SystemMaintenance-Daily", "SystemMaintenance-Weekly")
    
    foreach ($task in $tasks) {
        try {
            $existingTask = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
            
            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $task -Confirm:$false
                Write-Host "Removed scheduled task '$task'" -ForegroundColor Green
            }
            else {
                Write-Host "Task '$task' not found" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Failed to remove task '$task': $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
#endregion

#region Main Script
# Display banner
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "      SYSTEM MAINTENANCE SCHEDULER CONFIGURATION" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Setting up scheduled maintenance tasks" -ForegroundColor Yellow
Write-Host "=====================================================" -ForegroundColor Cyan

# Check if we're just removing tasks
if ($RemoveTasks) {
    Write-Host "Removing existing maintenance tasks..." -ForegroundColor Yellow
    Remove-MaintenanceTasks
    exit 0
}

# Load configuration
Write-Host "Loading configuration from $ConfigPath..." -ForegroundColor Gray
$config = Get-MaintenanceConfig -Path $ConfigPath

# Basic validation
if (-not $config.Schedule.EnableAutoRun) {
    Write-Host "Automatic scheduling is disabled in the configuration file." -ForegroundColor Yellow
    Write-Host "To enable scheduling, set EnableAutoRun to true in the configuration file." -ForegroundColor Yellow
    
    $response = Read-Host "Would you like to enable scheduling anyway? (y/n)"
    if ($response.ToLower() -ne 'y') {
        Write-Host "No scheduled tasks were created." -ForegroundColor Yellow
        exit 0
    }
}

# Get auto-maintain.ps1 full path
$mainScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "auto-maintain.ps1"
if (-not (Test-Path $mainScriptPath)) {
    Write-Host "Warning: Could not find auto-maintain.ps1 in $PSScriptRoot" -ForegroundColor Yellow
    Write-Host "Make sure auto-maintain.ps1 is in the same directory as this script." -ForegroundColor Yellow
    
    $response = Read-Host "Would you like to continue anyway? (y/n)"
    if ($response.ToLower() -ne 'y') {
        Write-Host "No scheduled tasks were created." -ForegroundColor Yellow
        exit 0
    }
}

# Set up daily optimization task
$dailyTime = $config.Schedule.RunDailyAt
$dailyDescription = "Daily system optimization task that cleans temporary files and optimizes browser memory"
$dailyArguments = "-ExecutionPolicy Bypass -NoProfile -File `"$mainScriptPath`" -OptimizeOnly -Silent"

Write-Host "`nSetting up daily optimization task to run at $dailyTime" -ForegroundColor White
$dailyTask = Register-MaintenanceTask -TaskName "SystemMaintenance-Daily" -Description $dailyDescription -ScriptPath $mainScriptPath -Arguments $dailyArguments -Trigger $dailyTime -SkipIfOnBattery $config.Schedule.SkipIfOnBattery -WakeToRun $config.Schedule.WakeToRun

# Set up weekly update check task
$weeklyDay = $config.Schedule.RunWeeklyDay
$weeklyTime = $config.Schedule.RunWeeklyAt
$weeklyTrigger = "$weeklyDay $weeklyTime"
$weeklyDescription = "Weekly system update check that verifies Windows updates and app updates"
$weeklyArguments = "-ExecutionPolicy Bypass -NoProfile -File `"$mainScriptPath`" -UpdateOnly"

Write-Host "`nSetting up weekly update task to run on $weeklyTrigger" -ForegroundColor White
$weeklyTask = Register-MaintenanceTask -TaskName "SystemMaintenance-Weekly" -Description $weeklyDescription -ScriptPath $mainScriptPath -Arguments $weeklyArguments -Trigger $weeklyTrigger -SkipIfOnBattery $config.Schedule.SkipIfOnBattery -WakeToRun $config.Schedule.WakeToRun

# Summary
Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "                SCHEDULER SUMMARY" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

if ($dailyTask) {
    Write-Host "✓ Daily optimization task created successfully" -ForegroundColor Green
    Write-Host "  Will run at: $dailyTime daily" -ForegroundColor White
    Write-Host "  Command: pwsh.exe $dailyArguments" -ForegroundColor Gray
}
else {
    Write-Host "✗ Failed to create daily optimization task" -ForegroundColor Red
}

if ($weeklyTask) {
    Write-Host "`n✓ Weekly update task created successfully" -ForegroundColor Green
    Write-Host "  Will run at: $weeklyTime on $weeklyDay" -ForegroundColor White
    Write-Host "  Command: pwsh.exe $weeklyArguments" -ForegroundColor Gray
}
else {
    Write-Host "`n✗ Failed to create weekly update task" -ForegroundColor Red
}

Write-Host "`nTo manually run tasks, use:" -ForegroundColor White
Write-Host "  Start-ScheduledTask -TaskName SystemMaintenance-Daily" -ForegroundColor Gray
Write-Host "  Start-ScheduledTask -TaskName SystemMaintenance-Weekly" -ForegroundColor Gray

Write-Host "`nTo remove tasks, run:" -ForegroundColor White
Write-Host "  .\schedule-maintenance.ps1 -RemoveTasks" -ForegroundColor Gray

Write-Host "`n=====================================================" -ForegroundColor Cyan
#endregion

