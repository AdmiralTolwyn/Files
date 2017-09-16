<#
.Synopsis
    TPM Clear
.DESCRIPTION
    Used to clear TPM ownership using Microsoft APIs
.EXAMPLE
    ResetTPMOwner.ps1
.NOTES
    Created:	 2017-09-16
    Version:	 1.0
    Author - Anton Romanyuk
    Twitter: @admiraltolwyn
    Blog   : http://www.vacuumbreather.com
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.LINK
    http://www.vacuumbreather.com
.NOTES

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Output "Logging to $logFile"
 
# Start Main Code Here
Function ClearTPM {
    Write-Output "The TPM must be cleared before it can be used to help secure the computer."
    Write-Output "Clearing the TPM cancels the TPM ownership and resets it to factory defaults."

    Write-Output "Quering Win32_TPM WMI object..."	
    $oTPM = Get-WmiObject -Class "Win32_Tpm" -Namespace "ROOT\CIMV2\Security\MicrosoftTpm"

    Write-Output "Clearing TPM ownership....."
    $tmp = $oTPM.SetPhysicalPresenceRequest(5)
    If ($tmp.ReturnValue -eq 0) {
	    Write-Output "Successfully cleared the TPM chip. A reboot is required."
        $TSenv.Value("NeedRebootTpmClear") = "YES"
	    Exit 0
    } 
    Else {
	    Write-Warning "Failed to clear TPM ownership. Exiting..."
        Stop-Transcript
	    Exit 0
    }
}

Start-Sleep -Seconds 10
ClearTPM

# Stop logging 
Stop-Transcript