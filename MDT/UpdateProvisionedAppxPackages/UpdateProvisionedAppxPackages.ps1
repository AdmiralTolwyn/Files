<#

************************************************************************************************************************

Created:    2018-06-04
Version:    1.0.1

Author:     Anton Romanyuk, Login Consultants Germany GmbH (C) 2018

Purpose:    Update inbox apps in an offline environment

Usage:		https://www.vacuumbreather.com/index.php/blog/item/74-localizing-inbox-apps-during-osd

Changelog:	1.0.1 - Code cleanup

************************************************************************************************************************

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
$logPath = $tsenv.Value("LogPath")
$logPath = "c:\temp"
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$ScriptName = $MyInvocation.MyCommand

# Create Log folder
$testPath = Test-Path $logPath
If (!$testPath)
{
	New-Item -ItemType Directory -Path $logPath
}

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile

Function Logit($TextBlock1)
{
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

Function Get-AppxBundleList
{
	begin
	{
		# Look for a appxbundle list
		$AppxBundleXmlList = "$PSScriptRoot\$($ScriptName.Substring(0, $ScriptName.IndexOf("."))).xml"
		if (Test-Path -Path $AppxBundleXmlList)
		{
			# Read the list
			. Logit "Reading list of apps from $AppxBundleXmlList"
			$AppxBundleList = Get-Content $AppxBundleXmlList
		}
		else
		{
			$AppxBundleList = @()
			
			# Build appxbundle packages list if it does not exist in the script's folder
			. Logit "Building list of appx bundles."
			
			(Get-ChildItem -Path $AppxPath -Recurse) | Where-Object { $_.FullName -like "*.appxbundle" } | % { $list += $_.BaseName.Substring(0, $_.BaseName.IndexOf("_")) }
			
			$AppxBundleXmlList = "$logPath\$($ScriptName.Substring(0, $ScriptName.IndexOf("."))).xml"
			$AppxBundleList | Set-Content $AppxBundleXmlList
			. Logit "Wrote list of apps to $logDir\$($ScriptName.Substring(0, $ScriptName.IndexOf("."))).xml, edit and place in the same folder as the script to use that list for future script executions"
		}
		
		. Logit "Apps selected for update: $($AppxBundleList.Count)"
	}
	
	process
	{
		$AppxBundleList
	}
	
}

Function Update-AppxDependencies
{
	$AppxList = (Get-ChildItem -Path $AppxPath -Recurse) | where-object { $_.FullName -like "*.appx" }
	. Logit "Prerequisites selected for update: $($AppxList.Count)"
	
	$AppxList = (Get-ChildItem -Path $AppxPath -Recurse) | where-object { $_.FullName -like "*.appx" }
	
	. Logit "Updating prerequisites..."
	ForEach ($Appx in $AppxList)
	{
		. Logit "Installing package $($Appx.BaseName) from $($Appx.Directory) directory."
		Try
		{
			Add-AppxProvisionedPackage -Online -PackagePath "$($Appx.FullName)" -SkipLicense
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
					Add-AppxProvisionedPackage -Online -PackagePath "$($current.FullName)" -LicensePath $LicPath
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
			. Logit "Unable to find update package $_"
		}
	}
}

# Start main code here
$ScriptName = $MyInvocation.MyCommand.Name

# Specifies whether non-Microsoft Store apps are allowed.
# This setting allows you to install trusted line-of-business (LOB) or developer-signed Windows Store apps. 
. Logit "Make sure policy is set."
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "1" -Force | Out-Null

. Logit "Build the base command line"
# Determine where to check
If ((gwmi win32_operatingsystem | select osarchitecture).osarchitecture -eq "64-bit")
{
	#64 bit apps
	$AppxPath = "$PSScriptRoot\amd64fre"
}
Else
{
	$AppxPath = "$PSScriptRoot\x86fre"
}

# Update inbox apps dependencies
Update-AppxDependencies
# Update inbox apps
Get-AppxBundleList | Update-AppxBundle

# Reset app sideloading policy to default settings
. Logit "Make sure sideloading policy is set back to default."
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "0" -Force | Out-Null
. Logit "In case of errors, review the DISM log at C:\Windows\Logs\DISM for details."