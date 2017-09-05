<#
 
************************************************************************************************************************
 
Created:    2017-09-05
Version:    1.0

Author:     Anton Romanyuk

Purpose:    Installs .NET framework 3.5 in Windows PE

Changelog:
            2017-09-05 - initial release
 
************************************************************************************************************************
 
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Create Logfile
Write-Output "Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $Section - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

# Start Main Code Here

$ScriptName = $MyInvocation.MyCommand

# Get data
$Section = "Initialization"
$OSDisk = $tsenv.Value("OSDisk")
$ScratchDir = $tsenv.Value("OSDisk") + "\Windows\temp"
$NetFxSource = $tsenv.Value("SourcePath") + "\sources\sxs"
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"
. Logit "Property OSDisk is now $OSDisk"
. Logit "Property ScratchDir is now $ScratchDir"
. Logit "Property NetFxSource is now $NetFxSource"

$Section = "Installation"
. Logit "Adding .NET Framework 3.5...."
dism.exe /Image:$OSDisk /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:$NetFxSource /ScratchDir:$ScratchDir