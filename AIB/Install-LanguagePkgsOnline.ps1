<#
 
************************************************************************************************************************

Created:    2020-11-03
Version:    1.0

Author:     Anton Romanyuk

Purpose:    This script adds language pkgs to an online Windows image 

Notes:      The script will expand all archives and apply language packs plus features on-demand (language bits + IE) 
            and LXPs in recommended order.

Changelog:
 
************************************************************************************************************************
 
#>

param(
    [parameter(mandatory=$true,position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Path,
    [parameter(mandatory=$true,position=1)]
    [ValidateNotNullOrEmpty()]
    [string]
    $LogDir
)

# Determine where to do the logging 
$tsenv = "Z:"
$logPath = "$tsenv\logs\$LogDir"
$logFile = "$logPath\$($myInvocation.MyCommand).log"
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
Function AddWindowsPkg ($PkgPath) {
    If (Test-Path $PkgPath) {
        . Logit "Adding windows package $PkgPath"
        Add-WindowsPackage -PackagePath $PkgPath -Online -NoRestart -IgnoreCheck | Out-Null
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
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
. Logit '*** Script: Install-LanguagePkgsOnline.ps1                                                     ***'
. Logit '***                                                                                            ***'
. Logit '**************************************************************************************************'

$TmpDir = "$env:windir\temp"
$ErrorActionPreference = "Stop"

. Logit "Property TmpDir is now $TmpDir"
. Logit "Property ErrorActionPreference is now $ErrorActionPreference"

# Start Main Code Here
$ScriptName = $MyInvocation.MyCommand
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"

######### OS Config #########

$Section = "Configuration"

# disable real-time monitoring for the duration of the image build
. Logit "Disabling real-time protection."
Set-MpPreference -DisableRealtimeMonitoring $true

# disable appx language cleanup
. Logit 'Disabling "Pre-staged app cleanup" scheduled task.'
Schtasks.exe /change /disable /tn "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup"

# disable language pack cleanup
. Logit 'Enabling BlockCleanupOfUnusedPreinstalledLangPacks policy to prevent unused language packs cleanup.'
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Control Panel' -Name "International" -Force | Out-Null
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Control Panel\International' -Name 'BlockCleanupOfUnusedPreinstalledLangPacks' -Value '1' -PropertyType DWORD -Force | Out-Null

. Logit 'Disabling Automatic Updates'
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value '1' -PropertyType DWORD -Force | Out-Null

. Logit 'Disabling Microsoft Store auto download'
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -Name "WindowsStore" -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -Value '2' -PropertyType DWORD -Force | Out-Null

######### NetFx3 #########

# NOTE: NetFx3 needs to be enabled before installing features on demand!
$Section = "OS Features"

. Logit 'Enabling .NET Framework 3.'

# Get data
$ScratchDir = "C:\Windows\temp"
# determine sources location
$OsBuild = [System.Environment]::OSVersion.Version.Build
. Logit "Property OsBuild is now $OsBuild."
. Logit "Property ScratchDir is now $ScratchDir"

If ($OsBuild -eq "18363") {
    $NetFxSource = "$tsenv\sources\1909\sxs"
    . Logit "Windows 10, version 1909, detected. Property NetFxSource is now $NetFxSource"
}
Else {
    $NetFxSource = "$tsenv\sources\2004\sxs"
    . Logit "Assuming Windows 10, version 20H1/20H2. Property NetFxSource is now $NetFxSource"
}

. Logit "Adding .NET Framework 3.5..."
$exePath = "C:\Windows\System32\dism.exe"
$cmdline = "/Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:$NetFxSource /ScratchDir:$ScratchDir"
Invoke-Exe -Executable $exePath -Arguments $cmdline

######### Language packs #########
# This setting allows you to install trusted line-of-business (LOB) or developer-signed Windows Store apps. 
. Logit "Make sure policy is set."
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "1" -Force | Out-Null

# Get language code subfolders under $Path
$LangPkgs = Get-ChildItem $Path

ForEach ($LangPkg in $LangPkgs) {
    
    $Section = "Staging"
    $LangPkgDir = $LangPkg.FullName

    . Logit "Var LangPkgDir is now $LangPkgDir"
    . Logit "Querying language packages for $($LangPkg.FullName)"

    $CABs = Get-ChildItem -Path $LangPkgDir

     #Install pkgs
    $LangPackPkg     = $CABs | Where-Object {$_.Name -like '*Language-Pack*'}
    $BasicPkg        = $CABs | Where-Object {$_.Name -like '*Basic*'}
    $TextToSpeechPkg = $CABs | Where-Object {$_.Name -like '*-TextToSpeech-*'}
    $SpeechPkg       = $CABs | Where-Object {$_.Name -like '*-Speech-*'}
    $OCRPkg          = $CABs | Where-Object {$_.Name -like '*-OCR-*'}
    $HandwritingPkg  = $CABs | Where-Object {$_.Name -like '*-Handwriting-*'}
    $IEOptionalPkg   = $CABs | Where-Object {$_.Name -like '*-InternetExplorer-*'}
    $NetFx           = $CABs | Where-Object {$_.Name -like '*NetFx3*'}
    $LXP             = $CABs | Where-Object {$_.Name -like '*.appx'}
    
    $Section = "Installation"
    #Language Pack
    If ($($LangPackPkg.FullName)) {
        AddWindowsPkg -PkgPath $LangPackPkg.FullName
    }
    #Basic
    If ($($BasicPkg.FullName)) {
        AddWindowsPkg -PkgPath $BasicPkg.FullName
    }
    #Text-to-speech
    If ($($TextToSpeechPkg.FullName)) {
        AddWindowsPkg -PkgPath $TextToSpeechPkg.FullName
    }
    #Speech recognition
    If ($($SpeechPkg.FullName)) {
        AddWindowsPkg -PkgPath $SpeechPkg.FullName
    }
    #Optical character recognition
    If ($($OCRPkg.FullName)) {
        AddWindowsPkg -PkgPath $OCRPkg.FullName
    }
    #Handwriting recognition
    If ($($HandwritingPkg.FullName)) {
        AddWindowsPkg -PkgPath  $HandwritingPkg.FullName
    }
    #Internet Explorer
    If ($($IEOptionalPkg.FullName)) {
        AddWindowsPkg -PkgPath $IEOptionalPkg.FullName
    }
    #NetFx3
    If ($($NetFx.FullName)) {
        AddWindowsPkg -PkgPath $NetFx.FullName
    }
    #LXP
    If ($LXP) {
        . Logit "Provisioning $($LXP.FullName)..."
        Add-AppxProvisionedPackage -PackagePath $LXP.FullName -LicensePath "$LangPkgDir\License.xml" -Online -Verbose
    }
}

# Reset app sideloading policy to default settings
. Logit "Make sure sideloading policy is set back to default."
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\Appx" -Name "AllowAllTrustedApps" -Value "0" -Force | Out-Null
. Logit "In case of errors, review the DISM log at C:\Windows\Logs\DISM for details."

#Force language display
$Section = "Configuration"
. Logit "Adding new language packs to UserLanguageList."

$OSLanguages = (Get-WmiObject -Class Win32_OperatingSystem -Namespace root\CIMV2).MUILanguages 
$UserLanguageList = Get-WinUserLanguageList 
ForEach($OSLanguage in $OSLanguages){
    $UserLanguageList.Add($OSLanguage)
}
Set-WinUserLanguageList $UserLanguageList -Force

. Logit "EOF"