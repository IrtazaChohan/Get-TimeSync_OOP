<#
.SYNOPSIS
    Script to check the system's time synchronization status and configured NTP servers.

.DESCRIPTION
    This script uses PowerShell classes to modularize functionality for checking the system's time synchronization status 
    and NTP server configuration. It logs the output to a file and provides detailed information about time sources, 
    synchronization intervals, and other parameters.

.AUTHOR
    Irtaza Chohan

.VERSION
    1.0

.NOTES
    - The script demonstrates the use of PowerShell classes for object-oriented programming (OOP).
    - It utilizes inheritance and encapsulation to structure the code for better maintainability and readability.

#>

# Function to check and start the Windows Time Service
function Start-WindowsTimeService {
    # Ensures the Windows Time Service (w32time) is running
    $service = Get-Service -Name w32time -ErrorAction SilentlyContinue
    if ($service.Status -ne 'Running') {
        Write-Host "Windows Time Service is not running. Attempting to start it..." -ForegroundColor Yellow
        Start-Service -Name w32time
        Write-Host "Windows Time Service started successfully." -ForegroundColor Green
    } else {
        Write-Host "Windows Time Service is already running." -ForegroundColor Green
    }
}

# Define a base class for common properties and methods
class TimeSyncBase {
    [string]$Hostname  # The system hostname
    [string]$ExecutionDate  # The timestamp of the script execution
    [string]$LogFile  # The log file path

    TimeSyncBase([string]$logFile) {
        # Constructor initializes common properties
        $this.Hostname = $env:COMPUTERNAME
        $this.ExecutionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $this.LogFile = $logFile
        $this.Log("----- Time Sync Check Log: $($this.ExecutionDate) -----")
    }

    [void] Log([string]$message) {
        # Logs messages to both the console and a log file
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $logMessage = "$timestamp - $message"
        Write-Host $logMessage
        $logMessage | Out-File -FilePath $this.LogFile -Append
    }
}

# Class to retrieve and process time synchronization details
class TimeSyncDetails : TimeSyncBase {
    [string]$TimeSource = "Unknown"  # The source of time synchronization
    [string]$LastSyncTime = "Unspecified"  # Last successful synchronization time
    [string]$PollInterval = "Unspecified"  # Poll interval for time sync
    [string]$SyncType = "Unspecified"  # Synchronization mode (e.g., NTP)

    TimeSyncDetails([string]$logFile) : base($logFile) {}

    [void] GetTimeSyncDetails() {
        # Retrieves time synchronization details using `w32tm /query /status`
        try {
            $w32tmOutput = w32tm /query /status 2>&1 | Out-String
            $this.Log("DEBUG: Raw w32tm /query /status output: $w32tmOutput")

            # Split output into lines for parsing
            $lines = $w32tmOutput -split "`n"

            # Extract relevant details using regex and string manipulation
            $sourceLine = $lines | Where-Object { $_ -match "^Source:" }
            if ($sourceLine) { $this.TimeSource = $sourceLine -replace "Source:\s*", "" }
            else { $this.Log("WARNING: Could not parse Time Source.") }

            $lastSyncLine = $lines | Where-Object { $_ -match "^Last Successful Sync Time:" }
            if ($lastSyncLine) { $this.LastSyncTime = $lastSyncLine -replace "Last Successful Sync Time:\s*", "" }
            else { $this.Log("WARNING: Could not parse Last Successful Sync Time.") }

            $pollIntervalLine = $lines | Where-Object { $_ -match "^Poll Interval:" }
            if ($pollIntervalLine -match "Poll Interval:\s*(\d+)") {
                $this.PollInterval = "$([math]::Pow(2, [int]$matches[1])) seconds"
            } else { $this.Log("WARNING: Could not parse Poll Interval.") }

            $modeLine = $lines | Where-Object { $_ -match "^Mode:" }
            if ($modeLine) { $this.SyncType = $modeLine -replace "Mode:\s*", "" }
            else { $this.Log("WARNING: Could not parse Sync Type.") }

            # Log parsed details
            $this.Log("Execution Date: $($this.ExecutionDate)")
            $this.Log("Time Source: $($this.TimeSource)")
            $this.Log("Last Sync Time: $($this.LastSyncTime)")
            $this.Log("Poll Interval: $($this.PollInterval)")
            $this.Log("Sync Type: $($this.SyncType)")
        } catch {
            $this.Log("Failed to retrieve time synchronization details: $($_.Exception.Message)")
        }
    }
}

# Class to retrieve and process NTP server configurations
class NtpServerConfig : TimeSyncBase {
    [string[]]$NtpServers  # List of configured NTP servers

    NtpServerConfig([string]$logFile) : base($logFile) {}

    [void] GetNtpServers() {
        # Retrieves configured NTP servers using `w32tm /query /peers`
        try {
            $ntpOutput = w32tm /query /peers 2>&1 | Out-String
            $this.Log("DEBUG: Raw w32tm /query /peers output: $ntpOutput")

            $this.NtpServers = $ntpOutput | Select-String "Peer:" | ForEach-Object {
                ($_ -replace "Peer:\s*", "").Trim()
            }

            if ($this.NtpServers.Count -eq 0) {
                $this.Log("No NTP servers are configured.")
            } else {
                $this.Log("Configured NTP servers: " + ($this.NtpServers -join ", "))
            }
        } catch {
            $this.Log("Failed to retrieve NTP servers: $($_.Exception.Message)")
        }
    }
}

# Main script execution
$logFile = "C:\TimeSyncCheck.log"

# Ensure the Windows Time Service is running
Start-WindowsTimeService

# Create instances of the classes
$timeSyncDetails = [TimeSyncDetails]::new($logFile)
$ntpConfig = [NtpServerConfig]::new($logFile)

# Perform the checks
$ntpConfig.GetNtpServers()
$timeSyncDetails.GetTimeSyncDetails()

Write-Host "Time synchronization check completed."
