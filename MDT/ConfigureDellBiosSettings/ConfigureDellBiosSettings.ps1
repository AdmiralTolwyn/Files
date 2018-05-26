<#
.Synopsis
    Apply Dell firmware settings
.DESCRIPTION
    Installs Dell Inc. HAPI64 drivers and configures Dell Inc. BIOS settings
.EXAMPLE
    ConfigureDellBiosSettings.ps1
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
Write-Host "Logging to $logFile"
 
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

Write-Host "$($myInvocation.MyCommand) - Importing default BIOS settings"
$cmdLine  = ' -i -k C-C-T-K -p "hapint64.exe" -q'
Write-Host "$($myInvocation.MyCommand) - Installing Dell HAPI Drivers"
Write-Host "Argument list set to $cmdLine"

$log_tmp = Execute-Command -commandTitle "Installing Dell HAPI Drivers" -commandPath  $PSScriptRoot\hapi\hapint64.exe -commandArguments $cmdLine
Write-Host $log_tmp

Write-Host "$($myInvocation.MyCommand) - Importing default BIOS settings"

#Base64 encoded password. Initial password is set to Pa55w0rd
$EncodedPassword = "UGE1NXcwcmQ="
$DecodedPassword = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($EncodedPassword))

$cmdLine  = ' --setuppwd=' + $DecodedPassword
#Write-Host "Argument list set to $cmdLine"

$log_tmp = Execute-Command -commandTitle "Setting BIOS password" -commandPath  $PSScriptRoot\cctk.exe -commandArguments $cmdLine
Write-Host $log_tmp

$cmdLine  = ' -i settings.cctk --valsetuppwd=' + $DecodedPassword
#Write-Host "Argument list set to $cmdLine"

$log_tmp = Execute-Command -commandTitle "Importing default BIOS settings" -commandPath  $PSScriptRoot\cctk.exe -commandArguments $cmdLine
Write-Host $log_tmp

Write-Host "$($myInvocation.MyCommand) - Import finished"

# Stop logging 
Stop-Transcript