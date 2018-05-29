<#
 
************************************************************************************************************************
 
Created:    2017-12-07
Version:    1.0
 
Author:     Anton Romanyuk, Login Consultants Germany GmbH (C) 2017

Purpose:    SAP install wrapper
 
************************************************************************************************************************
 
#>

Param (
	[Parameter(Mandatory = $True)]
	[string]$ini,
	[Parameter(Mandatory = $True)]
	[string]$product
)

# Determine where to do the logging 
$logFile = "C:\temp\$($myInvocation.MyCommand)-$product.log"

# Start the logging 
Start-Transcript $logFile
Write-Output "$($myInvocation.MyCommand) - Logging to $logFile"

# Start Main Code Here
Set-Location $PSScriptRoot
Write-Host "$($myInvocation.MyCommand) - Setting working directory to $PSScriptRoot"

Write-Host "$($myInvocation.MyCommand) - Running setup.exe"
$cmdLine = "-s -r $PSScriptRoot\$ini"
Write-Host "$($myInvocation.MyCommand) - Argument list set to $cmdLine"
$exe = "$PSScriptRoot\setup.exe"

Write-Host "$($myInvocation.MyCommand) - About to execute $exe"
$process = Start-Process $exe -ArgumentList $cmdLine -Wait -PassThru
Write-Host "$($myInvocation.MyCommand) - Exit code:" $process.ExitCode

Stop-Transcript

# Return exit code
Exit $process.ExitCode