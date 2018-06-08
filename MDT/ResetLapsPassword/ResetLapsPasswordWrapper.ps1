<#
 
************************************************************************************************************************
 
Created:    2018-06-06
Version:    1.0.0
 
Author:     Anton Romanyuk, Login Consultants Germany GmbH (C) 2018

Purpose:    Reset LAPS password PSExec wrapper
 
************************************************************************************************************************
 
#>

# Determine where to do the logging 
Try {
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
    $logPath = $tsenv.Value("LogPath") 
}
Catch {
    Write-Warning "TS environment not detected. Assuming stand-alone mode."
    $logPath = $env:TEMP
}

$logFile = "$logPath\$($myInvocation.MyCommand).log"
 
# Create Logfile
Write-Output "Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

# Start Main Code Here

$ScriptName = $MyInvocation.MyCommand.Name

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

# Pre-Stage
. Logit "Copying ResetLapsPassword.ps1 to C:\MININT\SMSOSD ..."
$ScriptPath = $PSScriptRoot + "\ResetLapsPassword.ps1"
If (!(Test-Path "C:\MININT\SMSOSD")) {
    New-Item -Path "C:\MININT\SMSOSD" -ItemType Directory -Force
}
Copy-Item -Path $ScriptPath -Destination "C:\MININT\SMSOSD\ResetLapsPassword.ps1" -Force

# https://blogs.msdn.microsoft.com/laps/2015/05/06/laps-and-machine-reinstalls/
. Logit "$($myInvocation.MyCommand) - Making sure that LAPS password expires immediately."
$cmdLine  = '-accepteula -i -s -h PowerShell.exe -ExecutionPolicy Bypass -Command C:\MININT\SMSOSD\ResetLapsPassword.ps1"'
. Logit "Argument list set to $cmdLine"

if ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
{
	. Logit "OS architecture: 64-bit."
	$PSExec = "PSexec64.exe"
}
else
{
	. Logit "OS architecture: 32-bit."
	$PSExec = "PSexec.exe"
}

$log_tmp = Execute-Command -commandTitle "Reset LAPS Password Expiration Date" -commandPath $PSScriptRoot\$PSExec -commandArguments $cmdLine
. Logit $log_tmp

# Cleanup
. Logit "Performing cleanup."
. Logit "Removing ResetLapsPassword.ps1 ..."
Remove-Item -Path "C:\MININT\SMSOSD\ResetLapsPassword.ps1" -Force -ErrorAction SilentlyContinue