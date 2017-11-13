<#

************************************************************************************************************************

Created:    2017-11-13
Version:    1.0

Author:     Anton Romanyuk

Purpose:    Imports WiFi profile

************************************************************************************************************************

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Host "Logging to $logFile"

# https://deploymentbunny.com/2015/09/29/powershell-is-kinginvoke-exe-could-help-you-run-exe-using-powershell/
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
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -NoNewWindow -Wait -Passthru
    }else{
        Write-Verbose "Running Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
        $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru
    }
    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"
    Return $ReturnFromEXE.ExitCode
}

#Custom Code Starts--------------------------------------

# Get all Wifi profiles 
$xml = Get-ChildItem $PSScriptRoot | Where-Object {$_.extension -eq ".xml"} 

# Apply wifi profiles
If ($xml) {
   ForEach ($profile in $xml) {
        $cmdline = 'wlan add profile filename="' + $profile.FullName +'" user=all'
        Write-Host "Command line set to" $cmdline
        
        $ExitCode = Invoke-Exe -Executable "C:\Windows\system32\netsh.exe" -Arguments $cmdline
        Write-Host "Exit code from command:" $ExitCode
        If ($ExitCode -ne 0) {
            Write-Warning "An error occured. Exiting.."
            Exit $ExitCode
        }
   }
}
Else {
    Write-Host "No Wifi profiles found. Exiting..."
    Exit 0
}

#Custom Code Ends--------------------------------------

Stop-Transcript
Exit $ExitCode
