<#
.Synopsis
    GetMuiSettings.ps1
.DESCRIPTION
    Saves current MUI settings into a temp variable and resets UILanguage variable to Windows 10 media value
.EXAMPLE
    GetMuiSettings.ps1
.NOTES
    Created:	 2016-11-21
    Version:	 1.0
    Author - Anton Romanyuk
    Twitter: @admiraltolwyn
    Blog   : http://www.vacuumbreather.com
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    http://www.vacuumbreather.com
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$MuiLanguage = $TSenv.Value("UILanguage")
 
# Start the logging 
Start-Transcript $logFile
Write-Host "Logging to $logFile"
 
# Start Main Code Here

Write-Host "$($myInvocation.MyCommand) - Following UILanguage setting detected:" $MuiLanguage

Write-Host "$($myInvocation.MyCommand) - Saving UI language preference to a temp variable UILanguageTMP..." 
$TSenv.Value("UILanguageTMP") = $MuiLanguage
Write-Host "$($myInvocation.MyCommand) - UILanguage variable reset to en-US" 
$TSenv.Value("UILanguage") = "en-US"

# Stop logging 
Stop-Transcript