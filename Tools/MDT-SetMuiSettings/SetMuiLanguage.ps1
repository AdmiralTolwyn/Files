<#
.Synopsis
    SetMuiSettings.ps1
.DESCRIPTION
    This script applies the Language Settings options in Windows 10 using an on-the-fly generated xml answer file.
.EXAMPLE
    SetMuiSettings.ps1
.NOTES
    Created:	 2016-11-15
    Version:	 1.0
    Author - Anton Romanyuk
    Twitter: @admiraltolwyn
    Blog   : http://www.vacuumbreather.com
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    http://www.vacuumbreather.com
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Create Logfile
Write-Output "Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $Section - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

# Start Main Code Here

$ScriptName = $MyInvocation.MyCommand
$Section = "Main"

# Get data
$Section = "Get data"
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"

$MUILanguage = $TSenv.Value("UILanguageTMP")

. Logit "Following target UILanguage detected: $MUILanguage"

#Generate XML
. Logit "Generating MUI.xml file..."

$xml = @()
$xml = '<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">
 
<!-- user list --> 
    <gs:UserList>
        <gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/> 
    </gs:UserList>
 
    <gs:MUILanguagePreferences>
        <gs:MUILanguage Value="' + $MUILanguage + '"/>
        <gs:MUIFallback Value="en-US"/>
    </gs:MUILanguagePreferences>
 
 </gs:GlobalizationServices>'

$xml | Out-File "C:\temp\MUI.xml"

#Apply MUI settings
$ErrorActionPreference = 'SilentlyContinue' 
. Logit "Applying MUI settings ... "
C:\Windows\System32\control.exe "intl.cpl,,/f:""c:\temp\MUI.xml""" | Out-Null

Exit 0