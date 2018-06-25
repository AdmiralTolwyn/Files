<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.152
	 Created on:   	06.06.2018
	 Created by:   	Anton Romanyuk
	 Filename:     	ApplyWin10Otimizations.ps1
	===========================================================================
	.DESCRIPTION
		Applies Windows 10 enterprise-oriented optimizations and privacy mitigations 
#>

# Configuration
$EnableOneNote = "false" # Set OneNote file association to the desktop app
$OneNotePath = "C:\Program Files (x86)\Microsoft Office\Office16\ONENOTE.EXE" # Set path to OneNote.exe
$EnableRDP = "false"
$DisableOneDrive = "false"
$PreferIPv4OverIPv6 = "false"
$DisableIEFirstRunWizard = "true"
$DisableNewNetworkDialog = "true"
$DisableServices = "true"
$DisableSchTasks = "true"
$ApplyPrivacyMitigations = "true" # Apply privacy mitigations
$InstallLogonScript = "false"

# Determine where to do the logging 
Try
{
	$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
	$logPath = $tsenv.Value("LogPath")
}
Catch
{
	Write-Warning "TS environment not detected. Assuming stand-alone mode."
	$logPath = $env:TEMP
}

$logFile = "$logPath\$($myInvocation.MyCommand).log"

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

# Start Main Code Here
$ScriptName = $MyInvocation.MyCommand.Name

If ($EnableOneNote -eq "true")
{
	# Mount HKCR drive
	. Logit "Setting OneNote file association to the desktop app."
	New-PSDrive -Name "HKCR" -PSProvider "Registry" -Root "HKEY_CLASSES_ROOT"
	New-Item -Path 'HKCR:\onenote-cmd\Shell\Open' -Name 'Command' -Force
	New-ItemProperty -Path "HKCR:\onenote-cmd\Shell\Open\Command" -Name "@" -PropertyType String -Value $OneNotePath -Force
	Remove-PSDrive -Name "HKCR"
}

If ($EnableRDP -eq "true")
{
	. Logit "Enabling RDP..."
	$rdp = Get-WmiObject -Class Win32_TerminalServiceSetting -Namespace root\CIMV2\TerminalServices -Authentication PacketPrivacy
	$tmp_rdp = $rdp.SetAllowTSConnections(1, 1) #first parameter rdp enable, second parameter firewall ports config
	
	If ($tmp_rdp.ReturnValue -eq 0)
	{
		. Logit "Remote Connection settings changed sucessfully"
	}
	Else
	{
		. Logit ("Failed to change Remote Connections setting(s), return code " + $tmp_rdp.ReturnValue)
	}
}

If ($DisableOneDrive -eq "true")
{
	. Logit "Turning off OneDrive..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -PropertyType DWORD -Value '1' -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'PreventNetworkTrafficPreUserSignIn' -PropertyType DWORD -Value '1' -Force
}

If ($PreferIPv4OverIPv6 -eq "true")
{
	# Use 0x20 to prefer IPv4 over IPv6 by changing entries in the prefix policy table. 
	. Logit "Modifying IPv6 bindings to prefer IPv4 over IPv6..."
	New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' -Name 'DisabledComponents' -PropertyType DWORD -Value '32' -Force
}

If ($DisableIEFirstRunWizard -eq "true")
{
	# Disable IE First Run Wizard
	. Logit "Disabling IE First Run Wizard..."
	New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -Name 'Internet Explorer' -Force
	New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer' -Name 'Main' -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main' -Name DisableFirstRunCustomize -PropertyType DWORD -Value '1' -Force
}

# Disable New Network dialog box
If ($DisableNewNetworkDialog -eq "true")
{
	. Logit "Disabling New Network Dialog..."
	New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Network' -Name 'NewNetworkWindowOff' -Force
}

# Disable Services
If ($DisableServices -eq "true")
{
	. Logit "Configuring Services..."
	
	. Logit "Disabling Microsoft Account Sign-in Assistant Service..."
	Set-Service wlidsvc -StartupType Disabled
	
	. Logit "Disabling Windows Error Reporting Service..."
	Set-Service WerSvc -StartupType Disabled
	
	. Logit "Disabling Xbox Live Auth Manager Service..."
	Set-Service XblAuthManager -StartupType Disabled
	
	. Logit "Disabling Xbox Live Game Save Service..."
	Set-Service XblGameSave -StartupType Disabled
	
	. Logit "Disabling Xbox Live Networking Service Service..."
	Set-Service XboxNetApiSvc -StartupType Disabled
	
	. Logit "Disabling Xbox Accessory Management Service..."
	Set-Service XboxGipSvc -StartupType Disabled
}

# Disable Scheduled Tasks
If ($DisableSchTasks -eq "true")
{
	. Logit "Disabling Scheduled Tasks..."
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\StartupAppTask"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Maps\MapsToastTask"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Maps\MapsUpdateTask"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Shell\FamilySafetyMonitor"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\WDI\ResolutionHost"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Autochk\Proxy"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Feedback\Siuf\DmClient"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
	Disable-ScheduledTask -TaskName "\Microsoft\XblGameSave\XblGameSaveTask"
}

# Privacy and mitigaton settings
# See: https://docs.microsoft.com/en-us/windows/privacy/manage-connections-from-windows-operating-system-components-to-microsoft-services

If ($ApplyPrivacyMitigations -eq "true")
{
	# Disable Cortana
	. Logit "Disabling Cortana..."
	New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\' -Name 'Windows Search' -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -PropertyType DWORD -Value '0' -Force
	
	# Configure Search Options:
	. Logit "Configuring Search Options..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowSearchToUseLocation' -PropertyType DWORD -Value '0' -Force
	# Disallow search and Cortana to use location
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -PropertyType DWORD -Value '0' -Force
	# Do not allow web search
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -PropertyType DWORD -Value '0' -Force
	
	. Logit "Disallowing the user to change sign-in options.."
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device" -Name "Settings" -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings' -Name 'AllowSignInOptions' -PropertyType DWORD -Value '0' -Force
	
	# Disable the Azure AD Sign In button in the settings app
	. Logit "Disabling Azure AD sign-in options.."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings' -Name 'AllowWorkplace' -PropertyType DWORD -Value '0' -Force
	
	. Logit "Disabling the Microsoft Account Sign-In Assistant."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'NoConnectedUser' -PropertyType DWORD -Value '3' -Force
	
	# Disable the MSA Sign In button in the settings app
	. Logit "Disabling MSA sign-in options.."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Settings' -Name 'AllowYourAccount' -PropertyType DWORD -Value '0' -Force
	
	. Logit "Disabling camera usage on user's lock screen..."
	New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "Personalization" -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreenCamera' -PropertyType DWORD -Value '1' -Force
	
	. Logit "Disabling lock screen slideshow..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreenSlideshow' -PropertyType DWORD -Value '1' -Force
	
	# Offline maps
	. Logit "Turning off unsolicited network traffic on the Offline Maps settings page..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps' -Name 'AllowUntriggeredNetworkTrafficOnSettingsPage' -PropertyType DWORD -Value '0' -Force
	. Logit "Turning off Automatic Download and Update of Map Data..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Maps' -Name 'AutoDownloadAndUpdateMapData' -PropertyType DWORD -Value '0' -Force
	
	# Microsoft Edge
	. Logit "Enabling Do Not Track in Microsoft Edge..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main' -Name 'DoNotTrack' -PropertyType DWORD -Value '1' -Force
	
	. Logit "Disallow web content on New Tab page in Microsoft Edge..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\SearchScopes' -Name 'AllowWebContentOnNewTabPage' -PropertyType DWORD -Value '0' -Force
	
	# General stuff
	. Logit "Turning off the advertising ID..."
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Name "AdvertisingInfo" -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -PropertyType DWORD -Value '0' -Force
	
	. Logit "Turning off location..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessLocation' -PropertyType DWORD -Value '0' -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' -Name 'DisableLocation' -PropertyType DWORD -Value '0' -Force
	
	# Stop getting to know me
	. Logit "Turning off automatic learning..."
	New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -PropertyType DWORD -Value '1' -Force
	# Turn off updates to the speech recognition and speech synthesis models
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Preferences' -Name 'ModelDownloadAllowed' -PropertyType DWORD -Value '0' -Force
	
	. Logit "Disallowing Windows apps to access account information..."
	New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\AppPrivacy" -Name "AppPrivacy" -Force
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\AppPrivacy' -Name 'LetAppsAccessAccountInfo' -PropertyType DWORD -Value '2' -Force
	
	. Logit "Disabling all feedback notifications..."
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'DoNotShowFeedbackNotifications' -PropertyType DWORD -Value '1' -Force
	
	. Logit "Disabling telemetry..."
	$OsCaption = (Get-WmiObject -class Win32_OperatingSystem).Caption
	
	If ($OsCaption -like "*Enterprise*" -or $OsCaption -like "*Education*")
	{
		$TelemetryLevel = "0"
		. Logit "Enterprise edition detected. Supported telemetry level: Security."
	}
	Else
	{
		$TelemetryLevel = "1"
		. Logit "Lowest supported telemetry level: Basic."
	}
	New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -PropertyType DWORD -Value $TelemetryLevel -Force
}

# Logon script
If ($InstallLogonScript -eq "true")
{
	. Logit "Copying Logon script to C:\Windows\Scripts"
	If (!(Test-Path "C:\Windows\Scripts"))
	{
		New-Item "C:\Windows\Scripts" -ItemType Directory
	}
	Copy-Item -Path $PSScriptRoot\Logon.ps1 -Destination "C:\Windows\Scripts" -Force
	# load default hive
	Start-Process -FilePath "reg.exe" -ArgumentList "LOAD HKLM\DEFAULT C:\Users\Default\NTUSER.DAT"
	# create RunOnce entries current / new user(s)
	. Logit "Creating RunOnce entries..."
	New-ItemProperty -Path "HKLM:\Default\Software\Microsoft\Windows\CurrentVersion\Runonce" -Name "Logon" -Value "Powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\Scripts\Logon.ps1"
	New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Runonce" -Name "Logon" -Value "Powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Windows\Scripts\Logon.ps1"
	# unload default hive
	Start-Process -FilePath "reg.exe" -ArgumentList "UNLOAD HKLM\DEFAULT"
}