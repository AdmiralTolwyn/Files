<#  
.SYNOPSIS  
    Script for the Azure Image Builder (AIB) task which updates built-in appx packages
.
.DESCRIPTION  
    Article:    Update built-in appx packages
                https://docs.microsoft.com/en-us/azure/virtual-desktop/language-packs
.
NOTES  
    File Name  : Update-ProvisionedAppxPackages.ps1
    Author     : Anton Romanyuk
    Version    : v0.2.1
.
.EXAMPLE
    Run as inline script as part of the AIB task.
    Invoke-Expression -Command "C:\BuildArtifacts\customizer\Update-ProvisionedAppxPackages.ps1 -Build 2004" -Verbose
    
.DISCLAIMER
	This script is provided 'AS IS' with no warranties, confers no rights and is not supported by the author.
#>

param(
    [parameter(mandatory=$true,position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Build,
	[parameter(mandatory=$true,position=1)]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogDir
)

Function Logit($TextBlock1)
{
	$TimeDate = Get-Date -Format "hh:mm:ss"
    $OutPut = "[$TimeDate] - $ScriptName - **$Section** - $TextBlock1"
    #write output into the console
    Write-Output $OutPut
    #... and log file
	Write-Output $OutPut >> $logFile
}

Function Update-AppxDependencies
{
	$AppxList = (Get-ChildItem -Path $AppxPath -Recurse) | where-object { $_.FullName -like "*.appx" }
	. Logit "Prerequisites selected for update: $($AppxList.Count)"
	
	. Logit "Updating prerequisites..."
	ForEach ($Appx in $AppxList)
	{
		. Logit "Installing package $($Appx.BaseName) from $($Appx.Directory) directory."
		Try
		{
			Add-AppxProvisionedPackage -Online -PackagePath "$($Appx.FullName)" -SkipLicense | Out-Null
            . Logit "Package $($($Appx.BaseName)) applied successfully."
		}
		Catch
		{
			. Logit "Following exception occured during $($Appx.BaseName) package installation: $($_.Exception.Message -replace "`n", "." -replace "`r", ".")."
		}
	}
}

Function Update-AppxBundle
{
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$AppxBundleName
	)
	
	begin
	{
		$AppxBundleList = (Get-ChildItem -Path $AppxPath -Recurse) | Where-Object { $_.FullName -like "*.appxbundle" }
	}
	process
	{
		$AppxBundle = $_
		
		# Update the provisioned package
		. Logit "Updating provisioned package $_"
		$current = $AppxBundleList | ? { $_.BaseName.StartsWith($AppxBundle) }
		if ($current)
		{
			# Verify we can access the license file
			$LicPath = $current.DirectoryName + "\" + $current.BaseName + ".xml"
			If (Test-Path $LicPath)
			{
				Try
				{
                     . Logit "Installing $($($current.FullName)) and applying $LicPath"
					Add-AppxProvisionedPackage -Online -PackagePath "$($current.FullName)" -LicensePath $LicPath | Out-Null
                    . Logit "Package $($($current.BaseName)) applied successfully."
				}
				Catch
				{
					. Logit "Following exception occured during $($current.BaseName) package installation: $($_.Exception.Message -replace "`n", "." -replace "`r", ".")."
				}
			}
			Else
			{
				. Logit "Unable to find corresponding license file $LicPath"
			}
		}
		Else
		{
			. Logit "Unable to find update package $_ or it is not an appxbundle."
		}
	}
}

# Start main code here

# Determine where to do the logging 
$tsenv = "Z:"
$logPath = "$tsenv\logs\$LogDir"
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$AppxPath = "Z:\sources\$Build\amd64fre"
$ScriptName = $MyInvocation.MyCommand

$Section = "Init"
$ScriptName = $MyInvocation.MyCommand

$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 

# Create Log folder
$testPath = Test-Path $logPath
If (!$testPath)
{
	New-Item -ItemType Directory -Path $logPath -Force
}

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile

. Logit "Running from $RunningFromFolder"

. Logit "Property ScriptName is now $ScriptName"
. Logit "Property tsenv is now $tsenv."
. Logit "Property LogDir is now $LogDir."
. Logit "Property logFile is now $logFile"
. Logit "AppxPath var is now $AppxPath"

# Update inbox apps dependencies
$Section = "AppxDependencies"
Update-AppxDependencies

# Update inbox apps
$Section = "AppxBundle"
$AppxBundleList = (Get-AppxProvisionedPackage -Online).DisplayName
$AppxBundleList | Update-AppxBundle

. Logit "In case of errors, review the DISM log at C:\Windows\Logs\DISM for details."