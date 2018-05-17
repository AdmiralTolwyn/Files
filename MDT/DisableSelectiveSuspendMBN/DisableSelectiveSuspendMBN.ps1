<#

************************************************************************************************************************

Created:    2018-05-16
Version:    1.0

Author:     Anton Romanyuk, Login Consultants Germany GmbH (C) 2018

Purpose:    Used to disable selective suspend on MBN adapters

Changelog:

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
      $OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
      Write-Output $OutPut >> $logFile
}

# Start Main Code Here
$ScriptName = $MyInvocation.MyCommand
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"

Import-Module netadapter

. Logit "Evaluating MBN configuration... "
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -ErrorAction SilentlyContinue | foreach {
$CurrentKey = (Get-ItemProperty -Path $_.PsPath)
if ($CurrentKey.Service -eq "wmbclass") {
        $FriendlyName = $($CurrentKey.FriendlyName)
        . Logit "Mobile broadband adapter detected: " $FriendlyName
        $adapter = Get-NetAdapter | Select-Object Name,InterfaceDescription | Where-Object InterfaceDescription -eq $FriendlyName 
        . Logit "Disabling selective suspend on $($adapter.Name)"
        Disable-NetAdapterPowerManagement -Name $adapter.Name -SelectiveSuspend        
    }
} 
