<#
.Synopsis
    UWP app install wrapper
.DESCRIPTION
    Installs (side-loads) an UWP app package
.EXAMPLE
    Install-ProvisionedAppxPackage.ps1
.NOTES
    Created:	 2017-11-21
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
$logPath = "C:\temp\Logs"
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$ScriptName = $MyInvocation.MyCommand

# Check log path
If (!(Test-Path $logPath)) {
    Write-Output "Log path not found..."
    New-Item -Path $logPath -ItemType Directory -Force
}

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

# Start main code here
. Logit "Make sure policy is set."
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "1" -Force | Out-Null

. Logit "Build the base command line"
# Determine where to check
$AppxBundlePath = $PSScriptRoot + '\AppxBundle'
$AppxBundle = (Get-ChildItem -Path $AppxBundlePath) | where-object {$_.FullName -like "*.AppxBundle"}
$LicensePath = (Get-ChildItem -Path $AppxBundlePath) | where-object {$_.FullName -like "*.xml"}
$DependenciesPath = $AppxBundlePath + "\Dependencies"
$DependenciesList = (Get-ChildItem -Path $DependenciesPath -Recurse) | where-object {$_.FullName -like "*.appx"}
$Dependencies = ""

. Logit "Adding dependencies..."
ForEach ($tmp in $DependenciesList) {
    $Dependencies += " /DependencyPackagePath:" + $tmp.FullName
    }

# Add license
If (!$LicensePath) {
    . Logit "No license file found..."
    $License = " /SkipLicense"
}
Else {
    . Logit "License file found..."
    $License = " /LicensePath:" + $LicensePath.FullName
}

# build command line
$BuildAppxCommand = "/Online /Add-ProvisionedAppxPackage /PackagePath:" + $AppxBundle.FullName + $License + " /NoRestart" + $Dependencies
 
# Launch Command and get return code
. Logit "Installing application $($AppxBundle.Name)"
. Logit "Command line $BuildAppxCommand"
$DISM = Execute-Command -commandTitle "Install AppxProvisionedPackage" -commandPath  DISM.exe -commandArguments $BuildAppxCommand

$ExitCode = $DISM.ExitCode
. Logit "Exit code from command $ExitCode"

Exit $ExitCode