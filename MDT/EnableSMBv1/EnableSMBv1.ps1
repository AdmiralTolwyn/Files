<#

************************************************************************************************************************

Created:    2017-10-10
Version:    1.0

Author:     Anton Romanyuk

Purpose:    Enables SMB1 component

Changelog:
            2017-10-10 - initial release

************************************************************************************************************************

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Host "Logging to $logFile"

# Start Main Code Here

Write-Host "Enabling SMB1 optional feature."
Enable-WindowsOptionalFeature -Online -FeatureName smb1protocol -NoRestart #-WarningAction SilentlyContinue

# Stop logging 
Stop-Transcript 
