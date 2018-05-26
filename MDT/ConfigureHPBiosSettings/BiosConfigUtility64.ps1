<#
.Synopsis
    Apply HP firmware settings
.DESCRIPTION
    Configures HP BIOS settings
.EXAMPLE
    ConfigureHPBiosSettings.ps1
.NOTES
    Created:	 2018-05-16
    Version:	 1.0
    Author - Anton Romanyuk
    Twitter: @admiraltolwyn
    Blog   : http://www.vacuumbreather.com
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    http://www.vacuumbreather.com
 
************************************************************************************************************************
 
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log"
 
# Start the logging 
Start-Transcript $logFile
Write-Output "Logging to $logFile"
 
# Start Main Code Here
# https://stackoverflow.com/questions/8761888/capturing-standard-out-and-error-with-start-process
Function Execute-Command ($commandTitle, $commandPath, $commandArguments)
{
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $commandPath
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $commandArguments
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    [pscustomobject]@{
        commandTitle = $commandTitle
        stdout = $p.StandardOutput.ReadToEnd()
        stderr = $p.StandardError.ReadToEnd()
        ExitCode = $p.ExitCode  
    }
}

# Get data
$Model = $TSenv.Value("Model")

Write-Host "$($myInvocation.MyCommand) - Setting BIOS password"
$cmdLine  = ' /NewSetupPasswordFile:"' + $PSScriptRoot + '\password.bin"'
Write-Host "Argument list set to $cmdLine"

# Note: Command will fail if there is already a password in place. This is by design.
$log_tmp = Execute-Command -commandTitle "Setting BIOS password" -commandPath  $PSScriptRoot\BiosConfigUtility64.exe -commandArguments $cmdLine

Write-Host $log_tmp

Write-Host "$($myInvocation.MyCommand) - Importing default BIOS settings"

# Make sure we use the right model
$Section = "Check Model"
Switch ($Model){
"HP EliteBook 840 G3"{
$cmdLine  = ' /Set:"' + $PSScriptRoot + '\HPEliteBook840G3.REPSET" /CurSetupPasswordFile:"' + $PSScriptRoot + '\password.bin"'
}
"HP EliteBook 840 G4"{
$cmdLine  = ' /Set:"' + $PSScriptRoot + '\HPEliteBook840G4.REPSET" /CurSetupPasswordFile:"' + $PSScriptRoot + '\password.bin"'
}
"HP EliteBook 840 G5"{
$cmdLine  = ' /Set:"' + $PSScriptRoot + '\HPEliteBook840G5.REPSET" /CurSetupPasswordFile:"' + $PSScriptRoot + '\password.bin"'
}
"HP Z440 Workstation"{
$cmdLine  = ' /Set:"' + $PSScriptRoot + '\HPZ440Workstation.REPSET" /CurSetupPasswordFile:"' + $PSScriptRoot + '\msits.bin"'
}
Default
    {
        Write-Host "$Model is unsupported, exit" 
        Exit 0
    }
}

Write-Host "Argument list set to $cmdLine"

$log_tmp = Execute-Command -commandTitle "Importing default BIOS settings" -commandPath  $PSScriptRoot\BiosConfigUtility64.exe -commandArguments $cmdLine

Write-Host $log_tmp
Write-Host "Import finished"

# Stop logging 
Stop-Transcript