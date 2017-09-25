<#
.Synopsis
    Duplicate Firmware Objects Cleanup Script
.DESCRIPTION
    Removes Duplicate "Windows Boot Manager" Firmware Objects in BCD and NVRAM
.EXAMPLE
    BootManagerCleaner.ps1
.NOTES
    Created:	 2016-05-16
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
    Based on the technique described here: http://stackoverflow.com/questions/16903460/bcdedit-bcdstore-and-powershell 

	The following example showcases output that contains duplicate firmware entries:

	Start-Manager für Firmware
	--------------------------
	Bezeichner              {fwbootmgr}
	displayorder            {bootmgr}
							{83222746-075c-11e6-b382-64006a688434}
							{83222757-075c-11e6-b382-64006a688434}
							{83222755-075c-11e6-b382-64006a688434}
							{83222754-075c-11e6-b382-64006a688434}
							{83222753-075c-11e6-b382-64006a688434}
							{83222752-075c-11e6-b382-64006a688434}
							{83222751-075c-11e6-b382-64006a688434}
							{83222750-075c-11e6-b382-64006a688434}
							{8322274f-075c-11e6-b382-64006a688434}
							{8322274e-075c-11e6-b382-64006a688434}
							{8322274d-075c-11e6-b382-64006a688434}
							{8322274c-075c-11e6-b382-64006a688434}
							{8322274b-075c-11e6-b382-64006a688434}
							{8322274a-075c-11e6-b382-64006a688434}
							{83222741-075c-11e6-b382-64006a688434}
							{83222742-075c-11e6-b382-64006a688434}
							{83222743-075c-11e6-b382-64006a688434}
							{83222744-075c-11e6-b382-64006a688434}
							{83222745-075c-11e6-b382-64006a688434}
							{83222747-075c-11e6-b382-64006a688434}
							{83222748-075c-11e6-b382-64006a688434}
							{83222749-075c-11e6-b382-64006a688434}
	timeout                 2

	Windows-Start-Manager
	---------------------
	Bezeichner              {bootmgr}
	device                  partition=\Device\HarddiskVolume1
	path                    \EFI\Microsoft\Boot\bootmgfw.efi
	description             Windows Boot Manager
	locale                  de-DE
	inherit                 {globalsettings}
	badmemoryaccess         Yes
	default                 {current}
	resumeobject            {8322273f-075c-11e6-b382-64006a688434}
	displayorder            {current}
	toolsdisplayorder       {memdiag}
	timeout                 30

	Firmwareanwendung (101fffff)
	----------------------------
	Bezeichner              {83222741-075c-11e6-b382-64006a688434}
	description             Windows Boot Manager
	badmemoryaccess         Yes

	Firmwareanwendung (101fffff)
	----------------------------
	Bezeichner              {83222742-075c-11e6-b382-64006a688434}
	description             Windows Boot Manager
	badmemoryaccess         Yes

	Firmwareanwendung (101fffff)
	----------------------------
	Bezeichner              {83222748-075c-11e6-b382-64006a688434}
	description             Onboard NIC(IPV4)
	badmemoryaccess         Yes

#>

# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath")  
$logFile = "$logPath\$($myInvocation.MyCommand).log"

# Start the logging 
Start-Transcript $logFile
Write-Host "Logging to $logFile"
 
# Start Main Code Here

$orphaned_guids = @()

Write-Host "$($myInvocation.MyCommand) - Enumerating the firmware namespace objects in the system BCD store."
Write-Host "$($myInvocation.MyCommand) - Executing bcdedit /enum firmware"

# Grab 3 lines preceding badmemoryaccess entry using a ForEach-Object loop
$bcd_store =  invoke-expression "bcdedit /enum firmware" | Select-String "badmemoryaccess" -Context 3,0

Write-Host "$($myInvocation.MyCommand) - Processing the list of GUID entries on the computer."

ForEach ($firmware in $bcd_store) {
	# Clean up entries using string replacement. 
	# The regular expressions '^identifier +' & '^description +' match a (sub)string starting with the word "identifier" / "description" followed by one or more spaces, which is replaced with the empty string
    $desc = $firmware.Context.Precontext[2] -replace '^description +'
    $guid = $firmware.Context.Precontext[1] -replace '^identifier +'
    $identifier = $firmware.Context.Precontext[0]

    Write-Host "$($myInvocation.MyCommand) - Found following entry."
    Write-Host "$($myInvocation.MyCommand) - Description: $desc"
    Write-Host "$($myInvocation.MyCommand) - GUID: $guid"

	# So now we only need to find invalid boot records.
	# Assume following: description contains "Windows Boot Manager" and the first line of the chunk -eq "----------------------------"
	# This will remove valid "Windows Boot Manager" entry from the array as well as other entries such as NICv4 and NICv6
    If ($identifier -eq "----------------------------" -and $desc -eq "Windows Boot Manager") {
		Write-Host "$($myInvocation.MyCommand) - Following orphaned GUID detected: $guid"
        $orphaned_guids += $guid
    }
}

Write-Host "$($myInvocation.MyCommand) - Prepairing to remove all duplicate entries from the BCD store."

#  remove all duplicate entries from the bcdstore
ForEach ($entry in $orphaned_guids) {
	Write-Host "$($myInvocation.MyCommand) - Following GUID will be removed $entry"
    $cmdline = 'bcdedit /delete $entry'
	Write-Host "$($myInvocation.MyCommand) - Executing $cmdline"
    invoke-expression $cmdline
}

Write-Host "$($myInvocation.MyCommand) - You can use use the bcdedit /enum firmware command to verify that all duplicate firmware entries have been removed."

# Stop logging 
Stop-Transcript