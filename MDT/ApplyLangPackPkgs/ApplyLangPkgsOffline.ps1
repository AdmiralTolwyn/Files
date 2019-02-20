<#
 
************************************************************************************************************************

Created:    2018-11-12
Version:    1.0

Author:     Anton Romanyuk, Login Consultants Germany GmbH (C) 2016

Purpose:    This script adds language pkgs to an offline Windows image 

Notes:      Place language pkg ZIPs in the $PSScriptRoot folder. The script will expand all archives and apply language
            packs plus features on demand (language bits + IE) in recommended order.

Changelog:
  
 
************************************************************************************************************************
 
#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"
$OSDisk = $tsenv.Value("OSDisk")
$TmpDir = $OSDisk + "\Windows\temp" 

# Create Logfile
Write-Output "Create Logfile" > $logFile
 
Function Logit($TextBlock1){
	$TimeDate = Get-Date
	$OutPut = "$ScriptName - $TextBlock1 - $TimeDate"
	Write-Output $OutPut >> $logFile
}

Function AddWindowsPkg {
    [CmdletBinding(SupportsShouldProcess=$true)]

    $Executable = "dism.exe"
    $Arguments = "/Image:$OSDisk /Add-Package /PackagePath=$PkgPath /IgnoreCheck /ScratchDir:$TmpDir"
    $SuccessfulReturnCode = 0

    . Logit "Adding windows package $PkgPath"
    . Logit "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
    $DismReturnCode = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    . Logit "Returncode is $($DismReturnCode.ExitCode)"

    If(!($DismReturnCode.ExitCode -eq $SuccessfulReturnCode)) {
            Throw "$Executable failed with exit code $($DismReturnCode.ExitCode)"
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
    $PkgPath = $LangPackPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg –Executable "dism.exe" –Arguments “/Image:$OSDisk /Add-Package /PackagePath=$PkgPath /IgnoreCheck /ScratchDir:$TmpDir” –SuccessfulReturnCode 0
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Basic
    $PkgPath = $BasicPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Text-to-speech
    $PkgPath = $TextToSpeechPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Speech recognition
    $PkgPath = $SpeechPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Optical character recognition
    $PkgPath = $OCRPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Handwriting recognition
    $PkgPath = $HandwritingPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }
    #Internet Explorer
    $PkgPath = $IEOptionalPkg.FullName
    If ($PkgPath) {
        AddWindowsPkg
    }
    Else {
        . Logit "Windows package $PkgPath not found."
    }

    #cleanup
    . Logit "Removing $LangPkgDir"
    Remove-Item -Path $LangPkgDir -Force -Recurse
}