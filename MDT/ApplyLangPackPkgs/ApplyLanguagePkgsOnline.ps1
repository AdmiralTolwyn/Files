<#
 
************************************************************************************************************************

Created:    2018-12-12
Version:    1.0

Author:     Anton Romanyuk

Purpose:    This script adds language pkgs to an online Windows image 

Notes:      Place language pkg ZIPs in the $PSScriptRoot folder. The script will expand all archives and apply language
            packs plus features on demand (language bits + IE) in recommended order.

Changelog:
 
************************************************************************************************************************
 
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$TmpDir = "$env:windir\temp" 

$ErrorActionPreference = "Stop"

# Create Logfile
Write-Output "Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

Function AddWindowsPkg ($PkgPath) {
    If (Test-Path $PkgPath) {
        . Logit "Adding windows package $PkgPath"
        Add-WindowsPackage -PackagePath $PkgPath -Online -NoRestart -IgnoreCheck
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
}

# Start Main Code Here
$ScriptName = $MyInvocation.MyCommand
$RunningFromFolder = $MyInvocation.MyCommand.Path | Split-Path -Parent 
. Logit "Running from $RunningFromFolder"

$LangPkgs = Get-ChildItem $PSScriptRoot -Filter '*.zip'
ForEach ($LangPkg in $LangPkgs) {
    $LangPkgDir = $TmpDir +"\" + $($LangPkg.Basename)

    #unzip language pkgs into the temp folder
    . Logit "Extracting $LangPkg to $LangPkgDir..."
    Expand-Archive -Path $LangPkg.FullName -DestinationPath $TmpDir -Force

    . Logit "Querying language packages for $($LangPkg.Basename)"
    $CABs = Get-ChildItem -Path $LangPkgDir

    #Install pkgs
    $LangPackPkg     = $CABs | Where-Object {$_.Name -like '*Language-Pack*'}
    $BasicPkg        = $CABs | Where-Object {$_.Name -like '*Basic*'}
    $TextToSpeechPkg = $CABs | Where-Object {$_.Name -like '*-TextToSpeech-*'}
    $SpeechPkg       = $CABs | Where-Object {$_.Name -like '*-Speech-*'}
    $OCRPkg          = $CABs | Where-Object {$_.Name -like '*-OCR-*'}
    $HandwritingPkg  = $CABs | Where-Object {$_.Name -like '*-Handwriting-*'}
    $IEOptionalPkg   = $CABs | Where-Object {$_.Name -like '*-InternetExplorer-*'}
    
    #Language Pack
    AddWindowsPkg -PkgPath $LangPackPkg.FullName
    #Basic
    AddWindowsPkg -PkgPath $BasicPkg.FullName
    #Text-to-speech
    AddWindowsPkg -PkgPath $TextToSpeechPkg.FullName
    #Speech recognition
    AddWindowsPkg -PkgPath $SpeechPkg.FullName
    #Optical character recognition
    AddWindowsPkg -PkgPath $OCRPkg.FullName
    #Handwriting recognition
    AddWindowsPkg -PkgPath  $HandwritingPkg.FullName
    #Internet Explorer
    AddWindowsPkg -PkgPath $IEOptionalPkg.FullName

    #cleanup
    . Logit "Removing $LangPkgDir"
    Remove-Item -Path $LangPkgDir -Force -Recurse
}