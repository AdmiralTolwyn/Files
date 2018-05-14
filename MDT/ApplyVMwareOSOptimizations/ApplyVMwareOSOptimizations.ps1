<#

************************************************************************************************************************

Created:    2017-12-05
Version:    1.0.1

Author:     Anton Romanyuk

Purpose:    Applies VMware OS optimizations

************************************************************************************************************************

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Output "Logging to $logFile"

$exe = $PSScriptRoot + "\VMwareOSOptimizationTool.exe"

# Get Operating System Info
$sOS =Get-WmiObject -class Win32_OperatingSystem

foreach($sProperty in $sOS)
{
   write-host "Following OS version detected:" $sProperty.Caption
   write-host "Following OS architecture detected:" $sProperty.OSArchitecture
   If ($sProperty.Caption -like "Microsoft Windows 10*") {
        Write-Host "Applying Windows_10.xml optimization preset"
        $process = Start-Process $exe -ArgumentList "-o -t Windows_10.xml" -Verbose -Wait
   }
   Else {
        Write-Host "Applying Windows_7.xml optimization preset"
        $process = Start-Process $exe -ArgumentList "-o -t Windows_7.xml" -Verbose -Wait
   }
}

Stop-Transcript

Exit $process.ExitCode