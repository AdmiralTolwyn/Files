<#=========================================================================================
Files:     SetBitLockerPin.ps1

Summary:
This script is intended to set BDE PIN in standard user context.

Official verison of Oliver Kieselbach
https://github.com/okieselbach/Intune/blob/master/Win32/SetBitLockerPin

Version	    Date		Author				Description
-------------------------------------------------------------------------------------------
    1.0     2023-10-09
            2023-10-15	Anton Romanyuk		Script created

-------------------------------------------------------------------------------------------
DISCLAIMER:

This Sample Code is provided for the purpose of illustration only and is not intended to 
be used in a production environment.

THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED AS IS
WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.

ALL CODE MUST BE TESTED BY ANY RECIPIENTS.

=========================================================================================
EXAMPLE: 
powershell.exe -file SetBitLockerPin.ps1
=========================================================================================#>


#Description: Writes a message including Timestamp and Severity to a log file
#Function Data:
#   Name:           Write-Log
#   Parameters:     LogFile, Classification, Level, Message
#   Returns:        None
Function Write-Log 
{
    <#
        .SYNOPSIS
        Write Log File

        .DESCRIPTION
        Writes a message including Timestamp and Severity to a log file.

        .PARAMETER Classification
        Specifies the Classification of the Message.
        Possible Values: IMPORTANT, INFO, DEBUG

        .PARAMETER Level
        Specifies the Severity of the Message.
        Possible Values: INFO, WARN, ERROR, FATAL, DEBUG, TRACE

        .PARAMETER LogFile
        Specifies the LogFile Path

        .PARAMETER Message
        Specifies the Message

        .EXAMPLE
        Write-Log -Message "Text" -Classification INFO

        .EXAMPLE
        Write-Log -Message "Text" -Classification INFO -LogFile "%Temp%\Logfile.log"
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [string]
        $LogFile = $LogFilePath,

        [Parameter(Mandatory=$False)]
        [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG","TRACE")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory=$True)]
        [string]
        $Message
    )

    #Internal Declarations and Definition Updates
    $Stamp        = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $HeaderString = "Timestamp".PadRight(22, ' ') + "Level".PadRight(10, ' ') + "Message".PadRight(60,' ')
    $LineString   = $Stamp.PadRight(22, ' ') + $Level.PadRight(10, ' ') + $Message.PadRight(60,' ')

    #Verify if Log File already exists
    If(Test-Path $LogFile) 
    {
        #Writing to Log File
        Add-Content -Path $LogFile -Value $LineString
    }
    Else 
    {
        #Writing to Log File including Header Line
        Add-Content -Path $LogFile -Value $HeaderString
        Add-Content -Path $LogFile -Value $LineString
    }

    #Writing to Debug Window
    if($DebugMode)
    {
        Write-Host $LineString
    }
}


#Description: Set BitLocker PIN for pre-boot authentication
#Function Data:
#   Name:           Invoke-SetBitLockerPin
#   Parameters:     none
#   Returns:        Boolean
#                   True  = Success
#                   False = Failure
Function Invoke-SetBitLockerPin
{
    <#
        .SYNOPSIS
        Set BitLocker PIN for pre-boot authentication

        .DESCRIPTION
        Set BitLocker PIN for pre-boot authentication

        .EXAMPLE
        Invoke-SetBitLockerPin
    #>

    #Set the action preference
    $ProgressPreference = 'SilentlyContinue'  

    Write-Log -Level INFO -Message "[INFO] Setting the BitLocker PIN for pre-boot authentication"  

    try {
		Write-Log -Level INFO -Message "[INFO] Starting ServiceUI.exe"
        .\ServiceUI.exe -process:Explorer.exe "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -WindowStyle Hidden -Ex bypass -file "$PSScriptRoot\Popup.ps1"
        $exitCode = $LASTEXITCODE
        
        #ASR rules can block the write access to public documents so we use a writeable path for users and system
        #check with sysinternals tool: accesschk.exe users -wus c:\windows\*
        #"c:\windows\tracing" should be fine as temp storage
        $pathPINFile = $(Join-Path -Path "$env:SystemRoot\tracing" -ChildPath "168ba6df825678e4da1a.tmp")

        #Alternativly use public documents, but keep in mind the ASR rules!
        #$pathPINFile = $(Join-Path -Path $([Environment]::GetFolderPath("CommonDocuments")) -ChildPath "168ba6df825678e4da1a.tmp")
        Write-Log -Level INFO -Message "[INFO] Setting var pathPINFile to $pathPINFile"

        Write-Log -Level INFO -Message "[INFO] Exit code of ServiceUI: $exitCode"
    
        If ($exitCode -eq 0 -And (Test-Path -Path $pathPINFile)) { 
            Write-Log -Level INFO -Message "[INFO] Found a PIN file at $pathPINFile"
            $encodedText = Get-Content -Path $pathPINFile 
            if ($encodedText.Length -gt 0) {
                
                Write-Log -Level INFO -Message "[INFO] PIN file is not empty. Trying to decrypt the PIN."

                #using DPAPI with a random generated shared 256-bit key to decrypt the PIN
                $key = (43,155,164,59,21,127,28,43,81,18,198,145,127,51,72,55,39,23,228,166,146,237,41,131,176,14,4,67,230,81,212,214)
                $secure = ConvertTo-SecureString $encodedText -Key $key

                #code for PS7+
                #$PIN = ConvertFrom-SecureString -SecureString $secure -AsPlainText

                #code for PS5
                $PIN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

                #REMOVE AFTER TESTING!!!!
                Write-Log -Level INFO -Message "[INFO] Decrypted PIN: $PIN"

                try {
					Write-Log -Level INFO -Message "[INFO] Adding BitLocker key protector with PIN"
                    Add-BitLockerKeyProtector -MountPoint $env:SystemDrive -Pin $(ConvertTo-SecureString $PIN -AsPlainText -Force) -TpmAndPinProtector
					#Write-Log -Level INFO -Message "[INFO] BitLocker key protector added successfully"
																									  
                } catch {
                    Write-Log -Level ERROR -Message "[ERROR] Failed to add BitLocker key protector: $($_.Exception.Message)"
                }
            }
        }
        else
        {
            Write-Log -Level ERROR -Message "[ERROR] Unable to locate $pathPINFile"

            #Error Handling
            $ExitCode = $ERROR_USER_CANCELLED
            Write-Log -Level INFO -Message "[INFO] -> Exit code: $ExitCode"		
            exit $ExitCode
        }
        
    } catch {
        Write-Error "[ERROR] $($_.Exception.Message)"
        Write-Log -Level INFO -Message "[INFO] -> Invoke-SetBitLockerPin function returned non-zero exit code. Remapping to ERROR_UNKNOWN"	
        
        #Error Handling
        $ExitCode = $ERROR_UNKNOWN 

        #Cleanup
        Write-Log -Level INFO -Message "[INFO] Running cleanup on $pathPINFile"
        Remove-Item -Path $pathPINFile -Force -ErrorAction SilentlyContinue
        Write-Log -Level INFO -Message "[INFO] -> Exit code: $ExitCode"													
        exit $ExitCode
    } 
    
    #Cleanup
    Write-Log -Level INFO -Message "[INFO] Running cleanup against $pathPINFile"
    Remove-Item -Path $pathPINFile -Force -ErrorAction SilentlyContinue
    #Exit Success
    return $true
}

#Description: Remove Tpm protector if both Tpm and TpmPin are present
#Function Data:
#   Name:           Invoke-TpmProtectorCleanup
#   Parameters:     none
#   Returns:        Boolean
#                   True  = Success
#                   False = Failure
Function Invoke-TpmProtectorCleanup {
    try {
        # Get BitLocker volume information
        $volume = Get-BitLockerVolume -MountPoint "C:"
        Write-Log -Level INFO -Message "[INFO] BitLocker volume information retrieved."

        # Check if both TPM and TpmPin protectors are added
        if (($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }) -and ($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' })) {
            Write-Log -Level INFO -Message "[INFO] TPM and TpmPin protectors found."

            # Get the ID of the TPM protector
            $tpmProtectorId = ($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }).KeyProtectorID

            # Remove the TPM protector
            Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $tpmProtectorId
            Write-Log -Level INFO -Message "[INFO] TPM protector removed."
        }
        else {
            Write-Log -Level INFO -Message "[INFO] TPM or TpmPin protectors not found."
        }
    }
    catch {
        # Write the error to the log
        Write-Log -Level ERROR -Message "[INFO]  $($_.Exception.Message)"
    }
}


##################################################################################################################
####                                    P R O G R A M    P A R A M E T E R S                                  ####
##################################################################################################################

#Debug Mode
$DebugMode               = [Boolean]$true

#Log File
$LogFilePath             = [System.Environment]::ExpandEnvironmentVariables("%SYSTEMDRIVE%\Windows\debug\SetBitLockerPin.log")

#Error and Exit Codes
$ERROR_SUCCESS                               = 0
$ERROR_UNKNOWN                               = 1
$ERROR_USER_CANCELLED                        = 1602

##################################################################################################################
####                                 P R O G R A M    S E Q U E N C E   C O D E                               ####
##################################################################################################################

#Program Start
$Starttime = Get-Date
$ExitCode  = $ERROR_SUCCESS

#Debug Output of Program Start
Write-Log -Level INFO -Message "##################################################################################################################"
Write-Log -Level INFO -Message "####                            P R O G R A M    S E Q U E N C E   S T A R T                                  ####"
Write-Log -Level INFO -Message "##################################################################################################################"
Write-Log -Level INFO -Message "[INFO] Configuration Parameters"
Write-Log -Level INFO -Message "[INFO] -> Debug Mode                : $($DebugMode)"
Write-Log -Level INFO -Message "[INFO] -> Log File Path             : $($LogFilePath)"
Write-Log -Level INFO -Message "[INFO] -> ERROR_SUCCESS             : $($ERROR_SUCCESS)"
Write-Log -Level INFO -Message "[INFO] -> ERROR_UNKNOWN             : $($ERROR_UNKNOWN)"
Write-Log -Level INFO -Message "[INFO] -> ERROR_USER_CANCELLED      : $($ERROR_USER_CANCELLED)"

#Get Details of OS
$OSVersion = (Get-CimInstance Win32_OperatingSystem).Version
$OSBuildNumber = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Log -Level INFO -Message "[INFO] Current Operating System"
Write-Log -Level INFO -Message "[INFO] -> Version  : $($OSVersion)"
Write-Log -Level INFO -Message "[INFO] -> Build    : $($OSBuildNumber)"

# Set BDE pre-boot PIN
Invoke-SetBitLockerPin
# Remove Tpm protector if both Tpm and TpmPin are present
Invoke-TpmProtectorCleanup

##################################################################################################################
####                                           P R O G R A M   E N D                                           ###
##################################################################################################################

#Program End
$Endtime = Get-Date
$Duration = $Endtime - $Starttime
Write-Log -Level INFO -Message "[INFO] Program Sequene End [Duration: $Duration]" 


##################################################################################################################
####                                           E X I T  C O D E S                                              ###
##################################################################################################################
<#
    0    = ERROR_SUCCESS
    1    = ERROR_UNKNOWN
#>

Write-Log -Level INFO -Message "[INFO] -> Exit code: $ExitCode"
exit $ExitCode
