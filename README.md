# Windows System Maintenance Scripts

A collection of PowerShell scripts for automated Windows system maintenance and optimization. These scripts help maintain system performance without requiring administrative privileges.

## Overview

This project provides a comprehensive set of PowerShell scripts for routine system maintenance tasks:

- Temporary file cleanup
- Browser cache optimization
- Memory usage optimization
- System update checks
- Scheduled maintenance

The scripts are designed to be safe, non-intrusive, and run without requiring administrative privileges.

## Scripts

### Main Scripts

| Script | Description |
|--------|-------------|
| **schedule-maintenance.ps1** | Creates scheduled tasks for daily optimization and weekly update checks |
| **auto-maintain.ps1** | Main orchestrator script that runs optimization and update routines |
| **optimize-system.ps1** | Comprehensive system optimization utilities |
| **check-updates.ps1** | System and application update checker |
| **quick-optimize.ps1** | Fast optimization for immediate performance improvements |
| **maintenance-config.json** | Configuration settings for all maintenance tasks |

## Installation

1. Clone this repository or download the scripts:
   ```
   git clone https://github.com/patjar/windows-maintenance-scripts.git
   ```

2. Ensure PowerShell 5.1 or newer is installed (included by default in Windows 10 and 11)

3. Set PowerShell execution policy to allow local scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

4. Configure script options by editing `maintenance-config.json`

## Usage

### Setting Up Scheduled Maintenance

To configure automatic scheduled maintenance:

```powershell
.\schedule-maintenance.ps1
```

This will:
- Create a daily optimization task (default: 10 PM)
- Create a weekly update check task (default: Sunday at 8 PM)
- Use settings from maintenance-config.json

### Running Manual Maintenance

For immediate optimization:

```powershell
.\auto-maintain.ps1 -OptimizeOnly
```

For update checks only:

```powershell
.\auto-maintain.ps1 -UpdateOnly
```

For quick system optimization:

```powershell
.\quick-optimize.ps1
```

For manual update checking:

```powershell
.\check-updates.ps1
```

### Advanced Options

The main script supports several flags:

```powershell
.\auto-maintain.ps1 [-Silent] [-UpdateOnly] [-OptimizeOnly] [-ForceRun] [-ConfigPath <path>]
```

## Configuration

The `maintenance-config.json` file contains all configurable options:

### Main Sections:

- **General**: Logging, notifications, and system restore settings
- **Schedule**: Automatic run schedule configuration
- **Optimization**: Cleanup and optimization settings
- **Updates**: Update checking preferences
- **BrowserOptimizations**: Browser-specific optimization settings
- **Advanced**: Performance thresholds and exclusions

Example customizations:

```json
"Schedule": {
  "EnableAutoRun": true,
  "RunDailyAt": "22:00",
  "RunWeeklyDay": "Sunday",
  "RunWeeklyAt": "20:00",
  "SkipIfOnBattery": true
}
```

## Requirements

- Windows 10 or Windows 11
- PowerShell 5.1 or newer
- No administrative privileges required
- Approximately 10MB disk space for scripts and logs

## Important Notes

- **No Administrative Privileges**: All scripts are designed to operate without requiring elevated privileges
- **Safe Operation**: Scripts use non-destructive optimization techniques
- **Battery Awareness**: Scripts can be configured to skip execution when running on battery power
- **Logging**: All actions are logged for review and troubleshooting

## Customization

The scripts can be customized by editing the `maintenance-config.json` file. Most common settings can be adjusted without modifying the scripts themselves.

For more advanced customization, each script is well-documented with comments explaining the functionality.

## License

This project is available under the MIT License. See LICENSE file for details.

