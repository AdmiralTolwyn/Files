<#
.Synopsis
    Capabilities Uninstaller
.DESCRIPTION
    Removes Feature on Demand apps
.EXAMPLE
    BootManagerCleaner.ps1
.NOTES
    Created:	 2016-10-20
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
    Based on https://blogs.technet.microsoft.com/mniehaus/2017/03/22/removing-contact-support-app/
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$ScriptName = $MyInvocation.MyCommand

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

# Start Main Code Here
$OSDisk = $tsenv.Value("OSDisk")
$ScratchDir = $tsenv.Value("OSDisk") + "\Windows\temp"
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
$ListOfCapabilities = @("App.Support.QuickAssist~~~~0.0.1.0")

. Logit "Running from $RunningFromFolder"
. Logit "Property OSDisk is now $OSDisk"
. Logit "Property ScratchDir is now $ScratchDir"

ForEach ($App in $ListOfCapabilities) {
    . Logit "Removing capability: $App"
    dism.exe /Image:$OSDisk /Remove-Capability /CapabilityName:$App /ScratchDir=$ScratchDir
}


