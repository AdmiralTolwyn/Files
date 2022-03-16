<#  
.SYNOPSIS  
    Customization script for the Azure Image Builder (AIB) DevOps task which applies best-practices configuration and optimizations for VDI environments. 
.
.DESCRIPTION  
    Customization script to build a WVD Windows 10 multi-session image
    This script configures the Microsoft recommended configuration for a Win10ms image:
        Article:    Prepare and customize a master VHD image 
                    https://docs.microsoft.com/en-us/azure/virtual-desktop/set-up-customize-master-image 
        Article: Install Office on a master VHD image 
                    https://docs.microsoft.com/en-us/azure/virtual-desktop/install-office-on-wvd-master-image
.
NOTES  
    File Name  : Apply-Customizations.ps1
    Author     : Anton Romanyuk
    Version    : v0.2.1
	
	This script is designed to be used in conjunction with the AIB DevOps task. Prerequisites are as follows:

	Azure Key vault contains storage account key which holds software packages. The Azure Key vault is queried as part of the DevOps job.

.
.EXAMPLE
    Run as inline script as part of the AIB task:

	Run the inline PS script as follows:

	$StorageAccountName = "aibstagestor"
	$StorageAccountKey = "$(aibstagestor)"
	$ShareName = "valueadd"

	# Mount the drive
	$secureKey = ConvertTo-SecureString -String "$StorageAccountKey" -AsPlainText -Force
	$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$StorageAccountName", $secureKey
	New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$ShareName" -Credential $credential -Persist -Verbose

    #some other scripts... 

	Invoke-Expression -Command "C:\BuildArtifacts\customizer\Install-BasePkgs.ps1 -LogDir $LogDir" -Verbose
    Invoke-Expression -Command "C:\BuildArtifacts\customizer\Apply-Customizations.ps1 -LogDir $LogDir" -Verbose

    Remove-PSDrive -Name Z -Verbose
    
.DISCLAIMER
	This script is provided 'AS IS' with no warranties, confers no rights and is not supported by the author.
#>

param(
    [parameter(mandatory=$true,position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogDir
)

# Determine where to do the logging 
$tsenv = "Z:"
$logPath = "$tsenv\logs\$LogDir"
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$AppRoot = "c:\temp\apps"
$ScriptName = $MyInvocation.MyCommand

# Create Log folder
$testPath = Test-Path $logPath
If (!$testPath)
{
	New-Item -ItemType Directory -Path $logPath -Force
}

# Create Logfile
Write-Output "$ScriptName - Create Logfile" > $logFile

Function Logit($TextBlock1)
{
	$TimeDate = Get-Date -Format "hh:mm:ss"
    $OutPut = "[$TimeDate] - $ScriptName - **$Section** - $TextBlock1"
    #write output into the console
    Write-Output $OutPut
    #... and log file
	Write-Output $OutPut >> $logFile
}

# based on https://deploymentbunny.com/2015/09/29/powershell-is-kinginvoke-exe-could-help-you-run-exe-using-powershell/
Function Invoke-Exe {
    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$false,position=1)]
        [string]
        $Arguments
    )

    if($Arguments -eq "")
    {
        . Logit "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }else{
        . Logit "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    . Logit "Returncode is $($ReturnFromEXE.ExitCode)"
	If ($($ReturnFromEXE.ExitCode) -eq 0 -or $($ReturnFromEXE.ExitCode) -eq 3010) {
		. Logit "Installation successfully completed."
		Start-Sleep -Seconds 5
	}
    Else {
		Write-Error "An error occured. Exiting..."		
	}
}

$Section = "Initialization"

. Logit '**************************************************************************************************'
. Logit '***                                                                                            ***'
. Logit '*** Script: Apply-Customizations.ps1                                                           ***'
. Logit '***                                                                                            ***'
. Logit '**************************************************************************************************'

$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"

. Logit "Property tsenv is now $tsenv."
. Logit "Property AppRoot is now $AppRoot"
. Logit "Property LogDir is now $LogDir."
. Logit "Property logFile is now $logFile"

. Logit 'Change ErrorActionPreference. Stop the customization if an error occurs...'
$ErrorActionPreference='Stop'

######### Fixes #########
$Section = "Fixes"

#Apply customized hosts files (temp fix DNS resolution issues). Included custom entries for lbbw-ap.bp.prod.bank.lbbw.sko.de and fm-portal.prod.hz.lbbw.sko.de
. Logit 'Applying customized hosts file'
Copy-Item -Path "$tsenv\configuration\Fixes\hosts" -Destination "C:\Windows\System32\drivers\etc" -Verbose -Force

######### Optimizations #########
$Section = "Optimizations"

#Apply customized Start layout
. Logit 'Applying customized start layout xml.'
Copy-Item -Path "$tsenv\configuration\StartLayout\2004\LayoutModification.xml" -Destination "C:\Users\Default\AppData\Local\Microsoft\Windows\Shell" -Verbose -Force

#Copy Redirections.xml
. Logit 'Copying customized FSLogix redirections.xml.'
Copy-Item -Path "$tsenv\configuration\FSLogix\Redirections.xml" -Destination "C:\Program Files\FSLogix" -Verbose -Force

#set up frxrobocopy - https://docs.microsoft.com/en-us/fslogix/fslogix-installed-components-functions-reference#frxrobocopyexe
. Logit 'Copy robocopy.exe to the %Program Files%\FSLogix\Apps folder as frxrobocopy.exe'
Copy-Item -Path "C:\Windows\System32\Robocopy.exe" -Destination "C:\Program Files\FSLogix\Apps\" -Force
Rename-Item -Path "C:\Program Files\FSLogix\Apps\Robocopy.exe" -NewName "frxrobocopy.exe" -Force

#Enable autostart for frxtray.exe
. Logit 'Configuring frxtray.exe to start at sign in for all users.'
New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'frxtray' -Value 'C:\Program Files\FSLogix\Apps\frxtray.exe' -Force | Out-Null

#Apply custom wallpaper
. Logit "Changing the default wallpaper..."
takeown /f C:\Windows\Web\wallpaper\Windows\img0.jpg
takeown /f C:\Windows\Web\Screen\img100.jpg
takeown /f C:\Windows\Web\4K\Wallpaper\Windows\*.*
icacls C:\Windows\Web\wallpaper\Windows\img0.jpg /Grant 'System:(F)'
icacls C:\Windows\Web\Screen\img100.jpg /Grant 'System:(F)'
icacls C:\Windows\Web\4K\Wallpaper\Windows\*.* /Grant 'System:(F)'
icacls C:\Windows\Web\wallpaper\Windows\img0.jpg /Grant 'Administrators:(F)'
icacls C:\Windows\Web\Screen\img100.jpg /Grant 'Administrators:(F)'
icacls C:\Windows\Web\4K\Wallpaper\Windows\*.* /Grant 'Administrators:(F)'
Copy-Item -Path "$tsenv\configuration\Web\" -Destination "C:\Windows\" -Force -Recurse

. Logit 'Applying WVD Optimization Tool.'

# Reset ErrorActionPreference
$ErrorActionPreference='Continue'

Invoke-Expression -Command "C:\BuildArtifacts\customizer\virtual-desktop-optimization-tool\Win10_VirtualDesktop_Optimize.ps1 -WindowsVersion 2004 -Verbose" -Verbose

# Cleanup
# Reset ErrorActionPreference
$ErrorActionPreference='SilentlyContinue' #prevent failure if files are in use...

$Section = "Cleanup"

. Logit 'Deleting temp folder.'
Get-ChildItem -Path 'C:\temp' -Recurse | Remove-Item -Recurse -Force
Remove-Item -Path 'C:\temp' -Force | Out-Null

. Logit 'Deleting buildartifacts folder.'
Get-ChildItem -Path 'C:\buildartifacts' -Recurse | Remove-Item -Recurse -Force
Remove-Item -Path 'C:\buildartifacts' -Force -Recurse

. Logit "Enabling real-time protection."
Set-MpPreference -DisableRealtimeMonitoring $false

. Logit 'EOF'