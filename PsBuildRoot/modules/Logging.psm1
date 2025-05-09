<#
.SYNOPSIS
    Provides standardized logging functionality for GitecOps modules with optional console output.

.DESCRIPTION
    This module writes timestamped log messages to a designated file inside C:\GitecOps\logs,
    organized by log name (default: "events"). It includes support for logging levels
    (INFO, WARN, ERROR, DEBUG), color-coded console output, and ensures log directories/files exist.

    Can be used standalone or imported into other modules. Optionally integrates with
    FileDirectoryHelper.psm1 to auto-create log files.

.EXAMPLE
    Write-Log -Message "System reboot scheduled" -Level "INFO"
    # Logs the message with a timestamp and outputs to console.

.EXAMPLE
    Set-GitecLogSettings -Name "maintenance" -ConsoleOutput:$false
    # Changes the current log file name and disables console logging.

.EXAMPLE
    Write-Warning "Low disk space on C:"
    # Shortcut for logging at WARN level.

.NOTES
    - Logs are written to C:\GitecOps\logs\<Name>.log.
    - Console output colors are based on log level.
    - Console output can be toggled at runtime using Set-GitecLogSettings.
    - Log rotation or cleanup must be implemented externally if needed.
    - Requires New-GitecFile from FileDirectoryHelper if that module is present.
#>
# Import-Module FileDirectoryHelper -Force -ErrorAction SilentlyContinue


$script:LogName = "events"
$script:EnableConsoleOutput = $true
$script:LogFile = "C:\Program Files\GitecOps\logs\events.log"

function Set-GitecLogSettings {
    [CmdletBinding()]
    param(
        [string]$Name = "events",
        [bool]$ConsoleOutput = $true
    )

    $script:LogName = $Name
    $script:EnableConsoleOutput = $ConsoleOutput
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")][string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formatted = "$timestamp [$Level] $Message"

    # Ensure log file exists
    if (-not (Test-Path $logFile)) {
        $null = New-Item -ItemType File -Path $script:LogFile -Force
    }

    Add-Content -Path $script:LogFile -Value $formatted

    if ($script:EnableConsoleOutput) {
        switch ($Level.ToUpper()) {
            "ERROR" { Write-Host $formatted -ForegroundColor Red }
            "WARN"  { Write-Host $formatted -ForegroundColor Yellow }
            "DEBUG" { Write-Host $formatted -ForegroundColor Cyan }
            default { Write-Host $formatted }
        }
    }
}

function Write-Info    { param([string]$Message) Write-Log -Message $Message -Level "INFO" }
function Write-Warning { param([string]$Message) Write-Log -Message $Message -Level "WARN" }
function Write-Error   { param([string]$Message) Write-Log -Message $Message -Level "ERROR" }
function Write-Debug   { param([string]$Message) Write-Log -Message $Message -Level "DEBUG" }
