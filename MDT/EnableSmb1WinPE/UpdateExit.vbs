' // ***************************************************************************
' // 
' // Copyright (c) Microsoft Corporation.  All rights reserved.
' // 
' // Microsoft Deployment Toolkit Solution Accelerator
' //
' // File:      UpdateExit.vbs
' // 
' // Version:   <VERSION>
' // 
' // Purpose:   Sample "Update Deployment Share" exit script
' // 
' // ***************************************************************************


Option Explicit

Dim oShell, oEnv

' Write out each of the passed-in environment variable values

Set oShell = CreateObject("WScript.Shell")
Set oEnv = oShell.Environment("PROCESS")

WScript.Echo "INSTALLDIR = " & oEnv("INSTALLDIR")
WScript.Echo "DEPLOYROOT = " & oEnv("DEPLOYROOT")
WScript.Echo "PLATFORM = " & oEnv("PLATFORM")
WScript.Echo "ARCHITECTURE = " & oEnv("ARCHITECTURE")
WScript.Echo "TEMPLATE = " & oEnv("TEMPLATE")
WScript.Echo "STAGE = " & oEnv("STAGE")
WScript.Echo "CONTENT = " & oEnv("CONTENT")


' Do any desired WIM customizations (right before the WIM changes are committed)

If oEnv("STAGE") = "WIM" then

	' CONTENT environment variable contains the path to the mounted WIM
	
	
	' // ***************************************************************************
	' // 
	' // Author:    Anton Romanyuk
	' // 
	' // Version:   1.0
	' // 
	' // Purpose:   Apply registry entries to Windows PE boot images.
	' // 
	' //  ------------- DISCLAIMER -------------------------------------------------
	' //  This script code is provided as is with no guarantee or waranty concerning
	' //  the usability or impact on systems.
	' //  ------------- DISCLAIMER -------------------------------------------------
	' //
	' // ***************************************************************************
	
	' // Extra variables
	Dim sCmd, rc, strLog, fso, iErrors 
	
	' The script output will be captured if the return code is greater than zero.  Change this line
	' to say "iErrors = 0" if you don't want to see output in the case of success.  (This means 
	' that return code 1 means success.  MDT doesn't take any action based on the return code, other
	' than logging.)

	iErrors = 1

	Set fso = CreateObject("Scripting.FileSystemObject")

		WScript.Echo "---- Beginning UpdateExit.vbs WIM section ----"
		WScript.Echo "Adding Registry keys to WinPE (UpdateExit.vbs)..."

		'Load SYSTEM registry hive from mounted WinPE WIM (path to CONTENT)
		sCmd = "REG.EXE load HKLM\winpe " & oEnv("CONTENT") & "\Windows\System32\config\SYSTEM"
		WScript.Echo "About to run command: " & sCmd
		rc = oShell.Run(sCmd, 0, True)
		
		WScript.Echo "Return code from command = " & rc
		If RC > 0 then 
			iErrors = iErrors + 1
		End if
		
		' This value enables SMB1 protocol
		
		sCmd = "Reg add " & Chr(34) & "HKLM\winpe\ControlSet001\Services\LanmanServer\Parameters" & Chr(34) & " /v SMB1 /t REG_DWORD /d 1 /f"
		WScript.Echo "About to run command: " & sCmd
		rc = oShell.Run(sCmd, 0, True)
		
		WScript.Echo "Return code from command = " & rc
			
		If RC > 0 then 
			iErrors = iErrors + 1
		End if
		
		sCmd = "Reg unload HKLM\winpe"
		WScript.Echo "About to run command: " & sCmd
		rc = oShell.Run(sCmd, 0, True)
		
		WScript.Echo "Return code from command = " & rc
		If RC > 0 then 
			iErrors = iErrors + 1
		End if

		filetxt.Write(strLog)
		filetxt.Close
		
	WScript.Quit iErrors
	
End if

' Do any desired ISO customizations (right before a new ISO is captured)

If oEnv("STAGE") = "ISO" then

	' CONTENT environment variable contains the path to the directory that
	' will be used to create the ISO.

End if


' Do any steps needed after the ISO has been generated

If oEnv("STAGE") = "POSTISO" then

	' CONTENT environment variable contains the path to the locally-captured
        ' ISO file (after it has been copied to the network).

End if