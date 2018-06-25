<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.152
	 Created on:   	22.06.2018
	 Created by:   	Anton Romanyuk
	 Filename:     	CleanupBeforeUpgrade.ps1
	===========================================================================
	.DESCRIPTION
		Run this script to regain some space after ref. image creation or before
		upgrading your Windows 10 install to the latest version. By default the 
		script will execute cleanup tasks only if you have less than 20 GB of free
   		disk space remaining.
	.PARAMETER
		-UserTmp : clean user temp folders
		-WindowsTmp : clean Windows\temp folder
		-SoftwareDstr : clean Software Distribution folder
		-Force : execute cleanup regardless of the amount of free disk space remaining
#>

Param (
	[switch]$UserTmp,
	[switch]$WindowsTmp,
	[switch]$SoftwareDstr,
	[switch]$Force
)

cls

# Determine where to do the logging 
$logPath = $env:TEMP
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile

Function Logit($TextBlock1)
{
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

$FreeGB = Get-WMIObject Win32_Logicaldisk -filter "deviceid='$($env:SystemDrive)'" | Select @{ Name = "FreeGB"; Expression = { [math]::Round($_.Freespace/1GB, 2) } }

If ($FreeGB.FreeGB -le "20" -or $Force -eq $true)
{
	. Logit "FreeSpaceCheck: 20 GB required. Actual free space detected $($FreeGB.FreeGB) GB."
	
	If ($Force)
	{
		. Logit "Force override switch detected."	
	}
	
	#Cleanup User Temp Folders
	If ($UserTmp)
	{
		. Logit "Making sure that $env:TEMP folders are cleared."
		Get-ChildItem 'C:\Users\*\AppData\Local\Temp\*' -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-7)) } | Remove-Item -Force -Verbose -Recurse -ErrorAction SilentlyContinue
	}
	
	#Cleanup C:\Windows\Temp
	If ($WindowsTmp)
	{
		. Logit "Making sure that temp folder is cleared."
		Get-ChildItem 'C:\Windows\Temp\*' -Recurse -Force -Verbose -ErrorAction SilentlyContinue | Where-Object { ($_.CreationTime -lt $(Get-Date).AddDays(-7)) } | Remove-Item -Force -Verbose -recurse -ErrorAction SilentlyContinue
	}
	
	#Execute DISM.exe /online /Cleanup-Image /RestoreHealth
	
	#Add sagerun:5432 to registy
	. Logit "CleanupTask: Adding reg values for CleanMgr"
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Active Setup Temp Folders" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Active Setup Temp Folders" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Content Indexer Cleaner" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Content Indexer Cleaner" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Device Driver Packages" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Device Driver Packages" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Delivery Optimization Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Delivery Optimization Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Downloaded Program Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Downloaded Program Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Internet Cache Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Internet Cache Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Memory Dump Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Memory Dump Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Offline Pages Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Offline Pages Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Old ChkDsk Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Old ChkDsk Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Previous Installations" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Previous Installations" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Recycle Bin" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Recycle Bin" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "RetailDemo Offline Content" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\RetailDemo Offline Content" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Service Pack Cleanup" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Service Pack Cleanup" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Setup Log Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Setup Log Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "System error memory dump files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error memory dump files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "System error minidump files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\System error minidump files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Temporary Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Temporary Setup Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Setup Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Temporary Sync Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Temporary Sync Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Thumbnail Cache" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Thumbnail Cache" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Upgrade Discarded Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Upgrade Discarded Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Error Reporting Archive Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Archive Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Error Reporting Queue Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting Queue Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Error Reporting System Archive Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Archive Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Error Reporting System Queue Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Error Reporting System Queue Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows ESD installation files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows ESD installation files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Upgrade Log Files" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Upgrade Log Files" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Update Cleanup" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Update Cleanup" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" -Name "Windows Defender" -Force
	New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\Windows Defender" -Name "StateFlags5432" -Value "00000002" -PropertyType "DWORD" -Force
	
	#Execute CleanMgr.exe /sagerun:5432
	. Logit "Running CleanMgr.exe /sagerun:5432"
	. Logit "Waiting for CleanMgr.exe to finish."
	$iRetVal = Start-Process -FilePath "CleanMgr.exe" -ArgumentList "/sagerun:5432" -Wait -PassThru
	
	. Logit "Execute command: CleanMgr exited with exit code $($iRetVal.ExitCode)"
	
	#Cleaning up the SoftwareDistribution folder
	If ($SoftwareDstr)
	{
		. Logit "Cleaning up the SoftwareDistribution folder"
		Start-Process -FilePath "net.exe" -ArgumentList "stop wuauserv" -Wait
		Get-ChildItem -Path "C:\Windows\SoftwareDistribution" -Recurse | Remove-Item -Force -Recurse -Verbose 
		Start-Process -FilePath "net.exe" -ArgumentList "start wuauserv" -Wait
	}
	
	#Remove Update sources
	. Logit "Executing DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase"
	. Logit "Waiting for DISM.exe to finish."
	$iRetVal = Start-Process -FilePath DISM.exe -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -PassThru
	. Logit "Execute command: CleanMgr exited with exit code $($iRetVal.ExitCode)"
}
Else
{
	. Logit "Execute command: FreeSpaceCheck returned exit code 0. Currently available: $($FreeGB.FreeGB) GB. Proceeding to the BatteryCheck step."
}

$FreeGB = Get-WMIObject Win32_Logicaldisk -filter "deviceid='$($env:SystemDrive)'" | Select @{ Name = "FreeGB"; Expression = { [math]::Round($_.Freespace/1GB, 2) } }

If ($FreeGB.FreeGB -le "20")
{
	. Logit "Execute command: FreeSpaceCheck returned exit code 1602. Currently available: $($FreeGB.FreeGB) GB. Required: 20GB. Exiting..."
	Exit 1602
}

# Check if we run on battery power
$PowerOnLine = (Get-WmiObject Win32_Battery).BatteryStatus
. Logit "Detected following number of batteries: $($PowerOnLine.Count)"
foreach ($Battery in $PowerOnLine)
{
	If ($Battery -eq 1)
	{
		. Logit "Execute command: BatteryCheck returned exit code 1603. Battery is discharging. Power source is required. Exiting..."
		Exit 1603
	}	
}

