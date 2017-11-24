<#
.Synopsis
    Reset driver update policy
.DESCRIPTION
    Reset driver update policy
.EXAMPLE
    ResetDriverUpdatePolicy.ps1
.NOTES
    Created:	 2017-11-11
    Version:	 1.0
    Author - Anton Romanyuk
    Twitter: @admiraltolwyn
    Blog   : http://www.vacuumbreather.com
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    http://www.vacuumbreather.com
.NOTES

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Host "Logging to $logFile"

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------

Write-Host "Resetting driver update policy to Microsoft's default value..."
Write-Host "Possible options are: 0 = 'No, let me choose what to do - Never install driver software from Windows Update', 1 = 'Yes, do this automatically (recommended)', 
2 = 'No, let me choose what to do - Install driver software from Windows Update if it is not found on my computer.'"
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 1 -Type DWORD -Force | Out-Null

Stop-Transcript