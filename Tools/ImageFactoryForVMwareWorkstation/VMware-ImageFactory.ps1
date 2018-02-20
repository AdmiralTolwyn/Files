<#
.Synopsis
    VMware Workstation ImageFactory 1.0
.DESCRIPTION
    VMware Workstation ImageFactory 1.0
.EXAMPLE
    VMware-ImageFactory.ps1
.NOTES
    Created:	 2017-07-24
    Updated:     2018-02-05
    Version:	 1.0.1

    Based on ImageFactory v 3.2
    
    Author(s) : 
                Mikael Nystrom (original implementation. http://deploymentbunny.com)
                Anton Romanyuk (VMware Workstation adaptation)

    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.

    This script uses the PsIni module:
    Blog		: http://oliver.lipkau.net/blog/ 
	Source		: https://github.com/lipkau/PsIni
	http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91

    This script uses the vmxtoolkit module:
    Blog		: http://labbuildr.bottnet.de/
    Source		: https://github.com/bottkars/vmxtoolkit
    https://www.powershellgallery.com/packages/vmxtoolkit/4.4.2

    This script uses the PSFTP module:
    Blog		: https://gallery.technet.microsoft.com/scriptcenter/PowerShell-FTP-Client-db6fe0cb
    Source		: https://github.com/chrisdee/Scripts/tree/master/PowerShell/Working/FTP/PSFTP

.LINK
    http://www.deploymentbunny.com
    http://www.vacuumbreather.com
#>

[cmdletbinding(SupportsShouldProcess=$True)]
Param(
    [parameter(mandatory=$false)] 
    [ValidateSet($True,$False)] 
    $UpdateBootImage = $False,

    [parameter(mandatory=$false)] 
    [ValidateSet($True,$False)] 
    $UploadBootImage = $True,

    [parameter(mandatory=$false)] 
    [ValidateSet($True,$False)] 
    $EnableMDTMonitoring = $False,

    [parameter(mandatory=$false)] 
    [ValidateSet($True,$False)] 
    $TestMode = $False
)

#Set start time
$StartTime = Get-Date

Function Get-VIARefTaskSequence
{
    Param(
    $RefTaskSequenceFolder
    )
    $RefTaskSequences = Get-ChildItem $RefTaskSequenceFolder
    Foreach($RefTaskSequence in $RefTaskSequences){
        New-Object PSObject -Property @{ 
        TaskSequenceID = $RefTaskSequence.ID
        Name = $RefTaskSequence.Name
        Comments = $RefTaskSequence.Comments
        Version = $RefTaskSequence.Version
        Enabled = $RefTaskSequence.enable
        LastModified = $RefTaskSequence.LastModifiedTime
        } 
    }
}

Function Update-Log
{
    Param(
    [Parameter(
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0
    )]
    [string]$Data,

    [Parameter(
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0
    )]
    [string]$Solution = $Solution,

    [Parameter(
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=1
    )]
    [validateset('Information','Warning','Error')]
    [string]$Class = "Information"

    )
    $LogString = "$Solution, $Data, $Class, $(Get-Date)"
    $HostString = "$Solution, $Data, $(Get-Date)"
    
    Add-Content -Path $Log -Value $LogString
    switch ($Class)
    {
        'Information'{
            Write-Host $HostString -ForegroundColor Gray
            }
        'Warning'{
            Write-Host $HostString -ForegroundColor Yellow
            }
        'Error'{
            Write-Host $HostString -ForegroundColor Red
            }
        Default {}
    }
}

Function Get-MDTOData{
    <#
    .Synopsis
        Function for getting MDTOdata
    .DESCRIPTION
        Function for getting MDTOdata
    .EXAMPLE
        Get-MDTOData -MDTMonitorServer MDTSERVER01
    .NOTES
        Created:     2016-03-07
        Version:     1.0
 
        Author - Mikael Nystrom
        Twitter: @mikael_nystrom
        Blog   : http://deploymentbunny.com
 
    .LINK
        http://www.deploymentbunny.com
    #>
    Param(
        $MDTMonitorServer
    ) 
    $URL = "http://" + $MDTMonitorServer + ":9801/MDTMonitorData/Computers"
    $Data = Invoke-RestMethod $URL
    foreach($property in ($Data.content.properties) ){
    $Hash =  [ordered]@{ 
        Name = $($property.Name); 
        PercentComplete = $($property.PercentComplete.’#text’); 
        Warnings = $($property.Warnings.’#text’); 
        Errors = $($property.Errors.’#text’); 
        DeploymentStatus = $( 
        Switch($property.DeploymentStatus.’#text’){ 
            1 { "Active/Running"} 
            2 { "Failed"} 
            3 { "Successfully completed"} 
            Default {"Unknown"} 
            }
        );
        StepName = $($property.StepName);
        TotalSteps = $($property.TotalStepS.'#text')
        CurrentStep = $($property.CurrentStep.'#text')
        DartIP = $($property.DartIP);
        DartPort = $($property.DartPort);
        DartTicket = $($property.DartTicket);
        VMHost = $($property.VMHost.'#text');
        VMName = $($property.VMName.'#text');
        LastTime = $($property.LastTime.'#text') -replace "T"," ";
        StartTime = $($property.StartTime.’#text’) -replace "T"," "; 
        EndTime = $($property.EndTime.’#text’) -replace "T"," "; 
        }
        New-Object PSObject -Property $Hash
        }
}

#https://github.com/jootuom/posh-mac/blob/master/Get-RandomMAC.psm1
Function Get-RandomMAC {
	[CmdletBinding()]
	Param(
		[Parameter()]
		[string] $Separator = ":"
	)

	[string]::join($Separator, @(
		# "Locally administered address"
		# any of x2, x6, xa, xe
		"02",
		("{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255)),
		("{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255)),
		("{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255)),
		("{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255)),
		("{0:X2}" -f (Get-Random -Minimum 0 -Maximum 255))
	))
}

#Inititial Settings
Clear-Host
$Log = "C:\Setup\ImageFactoryForVMware\log.txt"
$XMLFile = "$PSScriptRoot\ImageFactory.xml"
$Solution = "IMF32"
$ConfirmPreference = "none"
$MACAddresses = @{}
$PSFTPPath = $PSScriptRoot + "\PSFTP\PSFTP.psm1"
$PSINIPath = $PSScriptRoot + "\PSini\PSini.psm1"
$VMXtoolkitPath = $PSScriptRoot + "\vmxtoolkit\vmxtoolkit.psd1"
$InitScript = $PSScriptRoot + "\vmxtoolkit\vmxtoolkitinit.ps1"
Update-Log -Data "Imagefactory 3.2 (VMware)"
Update-Log -Data "Logfile is $Log"
Update-Log -Data "XMLfile is $XMLfile"

if($TestMode -eq $True){
    Update-Log -Data "Testmode is now $TestMode"
}

#Importing modules
Update-Log -Data "Importing modules"
Import-Module 'C:\Program Files\Microsoft Deployment Toolkit\Bin\MicrosoftDeploymentToolkit.psd1' -ErrorAction Stop -WarningAction Stop
Import-Module $PSINIPath -ErrorAction Stop -WarningAction Stop
# Initialize vmxtoolkit module
Import-Module $VMXtoolkitPath -ErrorAction Stop -WarningAction Stop
Invoke-Expression $InitScript -ErrorAction Stop -WarningAction Stop
# Initialize PSFTP module
Import-Module $PSFTPPath -ErrorAction Stop -WarningAction Stop

#Read Settings from XML
Update-Log -Data "Reading from $XMLFile"
[xml]$Settings = Get-Content $XMLFile -ErrorAction Stop -WarningAction Stop
$FtpUpload = $($Settings.Settings.EnableFTP) 
$EnableCleanup = $($Settings.Settings.EnableCleanup) 

#Verify Connection to DeploymentRoot
Update-Log -Data "Verify Connection to DeploymentRoot"
$Result = Test-Path -Path $Settings.Settings.MDT.DeploymentShare
If($Result -ne $true){Update-Log -Data "Cannot access $($Settings.Settings.MDT.DeploymentShare) , will break";break}

#Verify Connection to OVF share
Update-Log -Data "Verify Connection to OVF share"
$Result = Test-Path -Path $($Settings.Settings.TargetShare)
If($Result -ne $true){Update-Log -Data "Cannot access $($Settings.Settings.TargetShare) , will break";break}
$TargetFolder = Get-Date -Format yyyyMMdd
$OVFShare = "$($Settings.Settings.TargetShare)\$TargetFolder"

#Connect to MDT
Update-Log -Data "Connect to MDT"
$Root = $Settings.Settings.MDT.DeploymentShare
if((Test-Path -Path MDT:) -eq $false){
    $MDTPSDrive = New-PSDrive -Name MDT -PSProvider MDTProvider -Root $Root -ErrorAction Stop
    Update-Log -Data "Connected to $($MDTPSDrive.Root)"
}

#Get MDT Settings
Update-Log -Data "Get MDT Settings"
$MDTSettings = Get-ItemProperty MDT:

#Check if we should update the boot image
Update-Log -Data "Check if we should update the boot image"
If($UpdateBootImage -eq $True){
    #Update boot image
    Update-Log -Data "Updating boot image, please wait"
    Update-MDTDeploymentShare -Path MDT: -ErrorAction Stop
}

#Check if we should use MDTmonitoring
Update-Log -Data "Check if we should use MDTmonitoring"
If($EnableMDTMonitoring -eq $True){
    Update-Log -Data "Using MDT monitoring"
    $MDTServer = $Settings.Settings.MDT.Computername
}

#Verify access to boot image
Update-Log -Data "Verify access to x86 boot image"
$MDTImageX86 = $($Settings.Settings.MDT.DeploymentShare) + "\boot\" + $($MDTSettings.'Boot.x86.LiteTouchISOName')
if((Test-Path -Path $MDTImageX86) -eq $true){Update-Log -Data "Access to $MDTImageX86 is ok"}else{Write-Warning "Could not access $MDTImageX86";BREAK}
Update-Log -Data "Verify access to x64 boot image"
$MDTImageX64 = $($Settings.Settings.MDT.DeploymentShare) + "\boot\" + $($MDTSettings.'Boot.x64.LiteTouchISOName')
if((Test-Path -Path $MDTImageX64) -eq $true){Update-Log -Data "Access to $MDTImageX64 is ok"}else{Write-Warning "Could not access $MDTImageX64";BREAK}

#Get TaskSequences
Update-Log -Data "Get TaskSequences"
$RefTaskSequenceIDs = (Get-VIARefTaskSequence -RefTaskSequenceFolder "MDT:\Task Sequences\$($Settings.Settings.MDT.RefTaskSequenceFolderName)" | where Enabled -EQ $true).TasksequenceID
if($RefTaskSequenceIDs.count -eq 0){
    Update-Log -Data "Sorry, could not find any TaskSequences to work with"
    BREAK
    }
Update-Log -Data "Found $($RefTaskSequenceIDs.count) TaskSequences to work on"

#Get detailed info
Update-Log -Data "Get detailed info about the task sequences"
$Result = Get-VIARefTaskSequence -RefTaskSequenceFolder "MDT:\Task Sequences\$($Settings.Settings.MDT.RefTaskSequenceFolderName)" | where Enabled -EQ $true
foreach($obj in ($Result | Select-Object TaskSequenceID,Name,Version)){
    $data = "$($obj.TaskSequenceID) $($obj.Name) $($obj.Version)"
    Update-Log -Data $data
}

#Upload boot image to VMware host
If($UploadBootImage -eq $True){
    Update-Log -Data "Upload boot image to VMware host"
    $DestinationFolder = $Settings.Settings.VMware.ISOLocation
    Copy-Item -Path $MDTImageX86 -Destination $DestinationFolder -Force
    Copy-Item -Path $MDTImageX64 -Destination $DestinationFolder -Force
}

#Create the VM's on Host
Update-Log -Data "Create the VM's on Host"
Foreach($Ref in $RefTaskSequenceIDs){
    $VMName = $ref
    $VMMemory = [int]$($Settings.Settings.VMware.StartUpRAM) * 1024
    $VMPath = $($Settings.Settings.VMware.VMLocation)
    $VMBootimagex86 = $($Settings.Settings.VMware.ISOLocation) + "\" +  $($MDTImageX86 | Split-Path -Leaf)
    $VMBootimagex64 = $($Settings.Settings.VMware.ISOLocation) + "\" +  $($MDTImageX64 | Split-Path -Leaf)
    $VMVHDSize = [int]$($Settings.Settings.VMware.VHDSize) * 1GB
    $VMVCPU = $($Settings.Settings.VMware.NoCPU)
    $VMConnectionType = $($Settings.Settings.VMware.ConnectionType)
    $VMAdapterType = $($Settings.Settings.VMware.AdapterType)
    $VMAdapterID = $($Settings.Settings.VMware.AdapterID)
    $VMNumberOfMonitors = $($Settings.Settings.VMware.NumberOfMonitors)

    Write-Host "Working on $VMName"
    New-VMX -Type Server2012 -VMXName $Ref -Firmware BIOS -Path $VMPath -ErrorAction Stop | Out-Null

    #Get VM
    $VM = Get-VMX -Path $VMPath -VMXName $Ref
    Write-Host "$VMName is created"
   
    # Set HW version to 11
    Set-VMXHWversion -config $VM.Config -VMXName $VM.VMXname -HWversion 11 -ErrorAction Stop | Out-Null
    Write-Host "$VMName HW version set to 11"

    #Change OS type
    $TSpath = $Settings.Settings.MDT.DeploymentShare + "\Control\$Ref\ts.xml"
    [xml]$ts = Get-Content -Path $TSpath
    $OSGuid = ((($ts.sequence.group | ? name -eq 'Install').step | ? type -eq 'BDD_InstallOS').defaultVarList.variable | ? name -eq 'OSGUID').'#text'
    
    $OSpath = $Settings.Settings.MDT.DeploymentShare + "\Control\OperatingSystems.xml"
    [xml]$os = Get-Content -Path $OSpath
    $OSBuild = ($os.oss.os | ? guid -eq $OSGuid).Build
    $OSPlatform = ($os.oss.os | ? guid -eq $OSGuid).Platform
    $OSFlags = ($os.oss.os | ? guid -eq $OSGuid).Flags

    If ($OSBuild -like "10.*" -and $OSPlatform -eq "x86") {
        Write-Host "Windows 10 x86 detected. Replacing guest OS type..."
        Set-VMXGuestOS -config $VM.Config -VMXName $VM.VMXname -GuestOS windows9
        #(Get-Content -Path $VM.Config).Replace('guestOS = "windows8srv-64"','guestOS = "windows9"') | Set-Content $VM.Config 
    }
    If ($OSBuild -like "10.*" -and $OSPlatform -eq "x64" -and $OSFlags -notlike "SERVER*") {
        Write-Host "Windows 10 x64 detected. Replacing guest OS type..."
        Set-VMXGuestOS -config $VM.Config -VMXName $VM.VMXname -GuestOS windows9-64
        #(Get-Content -Path $VM.Config).Replace('guestOS = "windows8srv-64"','guestOS = "windows9-64"') | Set-Content $VM.Config 
    }
    If ($OSBuild -like "10.*" -and $OSPlatform -eq "x64" -and $OSFlags -like "SERVER*") {
        Write-Host "Windows Server 2016 detected. Replacing guest OS type..."
        Set-VMXGuestOS -config $VM.Config -VMXName $VM.VMXname -GuestOS windows9srv-64
    }
    If ($OSBuild -like "6.1.*" -and $OSPlatform -eq "x86") {
        Write-Host "Windows 7 x86 detected. Replacing guest OS type..."
        Set-VMXGuestOS -config $VM.Config -VMXName $VM.VMXname -GuestOS windows7
        #(Get-Content -Path $VM.Config).Replace('guestOS = "windows8srv-64"','guestOS = "windows7"') | Set-Content $VM.Config 
    }
    If ($OSBuild -like "6.1.*" -and $OSPlatform -eq "x64") {
        Write-Host "Windows 7 x64 detected. Replacing guest OS type..."
        Set-VMXGuestOS -config $VM.Config -VMXName $VM.VMXname -GuestOS windows7-64
        #(Get-Content -Path $VM.Config).Replace('guestOS = "windows8srv-64"','guestOS = "windows7-64"') | Set-Content $VM.Config 
    }

    # Set RAM
    Set-VMXmemory -config $VM.Config -VMXName $VM.VMXname -MemoryMB $VMMemory -ErrorAction Stop
    Write-Host "$VMName RAM set to $VMMemory MB"
        
    #Check if VM HDD exist
    If (Test-Path $VMPath\$Ref\$Ref.vmdk) {
        Write-Host "Removing $VMPath\$Ref\$Ref.vmdk"
        Remove-Item $VMPath\$Ref\$Ref.vmdk -Force -ErrorAction Stop
    }

    #Create empty disk
    $VMDK = New-VMXScsiDisk -NewDiskname $Ref -NewDiskSize $VMVHDSize -Path $VMPath\$Ref -VMXName $Ref -ErrorAction Stop
    Write-Host "$VMPath\$Ref\$Ref.vmdk is created for $VMName"
    
    #Add VHDx
    Add-VMXScsiDisk -config $VM.Config -VMXName $VM.VMXname -LUN 0 -Controller 0 -Diskname $VMDK.Diskname -ErrorAction Stop | Out-Null
    Write-Host "$($VMDK.Path) is attached to $VMName"

    #Set vCPU
    if($VMVCPU -ne "1"){
        Set-VMXprocessor -config $VM.Config -VMXName $VM.VMXname -Processorcount $VMVCPU -ErrorAction Stop | Out-Null
        Write-Host "$VMName has $VMVCPU vCPU"
    }

    #Connect to VMSwitch 
    Set-VMXNetworkAdapter -config $VM.Config -VMXName $VM.VMXname -Adapter $VMAdapterID -AdapterType $VMAdapterType -ConnectionType $VMConnectionType -ErrorAction Stop | Out-Null
    Write-Host "$VMName is connected to $VMAdapterType $VMConnectionType interface"

    #Set MAC address
    $VMMAC = Get-RandomMAC
    Add-Content -Path $VM.Config -Value  ""
    Add-Content -Path $VM.Config -Value ('ethernet0.address = "' + $VMMAC + '"')
    Add-Content -Path $VM.Config -Value 'ethernet0.addressType = "static"'
    Write-Host "$VMAdapterType $VMConnectionType interface on $VMName configured to use static MAC address $VMMAC"

    #Set number of displays
    Add-Content -Path $VM.Config -Value  ""
    Add-Content -Path $VM.Config -Value ('svga.numDisplays = "' + $VMNumberOfMonitors + '"')
    Add-Content -Path $VM.Config -Value ('svga.autodetect = "FALSE"')
    Write-Host "$VMName configured to use $VMNumberOfMonitors monitors"

    #Connect ISO 
    If ($OSPlatform -eq "x86") {
        Write-Host "x86 OS detected."
        Connect-VMXcdromImage -config $VM.Config -VMXName $VM.VMXname -ISOfile $VMBootimagex86 -ErrorAction Stop | Out-Null
        Write-Host "$VMBootimagex86 is attached to $VMName"
    }
    Else {
        Write-Host "x64 OS detected."
        Connect-VMXcdromImage -config $VM.Config -VMXName $VM.VMXname -ISOfile $VMBootimagex64 -ErrorAction Stop | Out-Null
        Write-Host "$VMBootimagex64 is attached to $VMName"
    }

    #Set Display Name
    Set-VMXDisplayName -config $VM.Config -DisplayName $VM.VMXname -ErrorAction Stop | Out-Null
    Write-Host "$VMName display name set to $($VM.VMXname)"
    
    #Set Notes
    Set-VMXAnnotation -config $VM.Config -VMXName $VM.VMXname -Line1 "REFIMAGE" -ErrorAction Stop | Out-Null
    Write-Host "Added REFIMAGE annotation to $VMName"

    #Update the CustomSettings.ini file
    Update-Log -Data "Update the CustomSettings.ini file"

    #Store MAC for the cleanup process
    $MacAddresses.Add("$Ref","$VMMAC")

    $IniFile = "$($Settings.settings.MDT.DeploymentShare)\Control\CustomSettings.ini"
    $CustomSettings = Get-IniContent -FilePath $IniFile -CommentChar ";"

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"OSDComputerName"="$Ref"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"TaskSequenceID"="$Ref"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"BackupFile"="$Ref.wim"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"SkipTaskSequence"="YES"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"SkipApplications"="YES"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"SkipCapture"="YES"}
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate

    if($($Settings.Settings.MDT.SkipCapture) -eq "YES"){
        $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"DoCapture"="NO"}
        Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate
    }
    else{
        $CSIniUpdate = Set-IniContent -FilePath $IniFile -Sections "$VMMAC" -NameValuePairs @{"DoCapture"="YES"}
        Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate
    }
} 

#Start VM's on Host
$ConcurrentRunningVMs = $($Settings.Settings.ConcurrentRunningVMs)
Update-Log -Data "Start VM's on Host"
Update-Log -Data "ConcurrentRunningVMs is set to: $ConcurrentRunningVMs"

#Get the VMs as Objects
$RefVMs = Get-VMX -Path $VMPath
foreach($RefVM in $RefVMs){
    Write-Host "REFVM $($RefVM.VMXName) is deployed at $($refvm.Path)"
}

#Get the VMs as Objects
$RefVMs = Get-VMX -Path $VMPath
ForEach($RefVM in $RefVMs){

    If($($Settings.Settings.NoGui) -eq $True){
        $StartedVM = Start-VMX -config $RefVM.Config -VMXName $RefVM.VMXname -ErrorAction Stop -nogui
    }
    Else {
        $StartedVM = Start-VMX -config $RefVM.Config -VMXName $RefVM.VMXname -ErrorAction Stop
    }

    Write-Host "Starting $($StartedVM.VMXname)"
    Do
        {
        $RunningVMs = $((Get-VMX -Path $VMPath | Where-Object -Property State -EQ -Value "running"))
        foreach($RunningVM in $RunningVMs){
            if($EnableMDTMonitoring -eq $false){
                Write-Output "Currently running VM's : $($RunningVM.VMXName) at $(Get-Date)"
            }
            else{
                Get-MDTOData -MDTMonitorServer $MDTServer | Where-Object -Property Name -EQ -Value $RunningVM.VMXName | Select-Object Name,PercentComplete,Warnings,Errors,DeploymentStatus,StartTime,Lasttime | FT
            }
        }
        Start-Sleep -Seconds "60"
        }
    While(((Get-VMX -Path $VMPath | Where-Object -Property State -EQ -Value "running").State).Count -gt ($ConcurrentRunningVMs - 1))
}

#Wait until they are done
Update-Log -Data "Wait until they are done"

Do{
    $RunningVMs = $((Get-VMX -Path $VMPath | Where-Object -Property State -EQ -Value "running"))
        foreach($RunningVM in $RunningVMs){
            If($EnableMDTMonitoring -eq $false){
                Write-Output "Currently running VM's : $($RunningVM.VMXName) at $(Get-Date)"
            }
            else{
                Get-MDTOData -MDTMonitorServer $MDTServer | Where-Object -Property Name -EQ -Value $RunningVM.VMXName | Select-Object Name,PercentComplete,Warnings,Errors,DeploymentStatus,StartTime,Lasttime | FT
            }
        }
    Start-Sleep -Seconds "60"
}
until(((Get-VMX -Path $VMPath | Where-Object -Property State -EQ -Value "running").State).Count -eq '0')

# Power off VMs
ForEach($RefVM in $RefVMs) {
    Stop-VMX -config $VM.Config -VMXName $VM.VMXname -ErrorAction SilentlyContinue
}

# Disconnect ISO
ForEach($RefVM in $RefVMs) {
    (Get-Content $RefVM.config) -replace 'sata0:1.startConnected = "TRUE"', 'sata0:1.startConnected = "FALSE"' | Set-Content $RefVM.config
    (Get-Content $RefVM.config) -replace 'sata0:1.fileName =.+', 'sata0:1.fileName = ""' | Set-Content $RefVM.config
}

# Export OVF
ForEach($RefVM in $RefVMs){
    Write-Host "Exporting $($RefVM.VMXname) to $OVFShare"
    Start-Process $Global:VMware_OVFTool -ArgumentList """$($RefVM.Config)"" ""$OVFShare""" -Wait -ErrorAction Stop
}

#Cleanup VMs
if($EnableCleanup -eq $True){
    Update-Log -Data "Cleanup VMs"
    Get-Process "vmware"  -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue # close VMware GUI, otherwise remove process will fail
    Start-Sleep 10
    $VMs = Get-VMX -Path $VMPath
    ForEach ($VM in $VMs) {
        Write-Host "Deleting $($VM.VMXname) at $($VM.Path)"
        Remove-VMX -config $VM.config -VMXname $VM.VMXName
    }
}

#Update CustomSettings.ini
Update-Log -Data "Update CustomSettings.ini"
Foreach($Obj in $MacAddresses.Values){
    $CSIniUpdate = Remove-IniEntry -FilePath $IniFile -Sections $Obj
    Out-IniFile -FilePath $IniFile -Force -Encoding ASCII -InputObject $CSIniUpdate
}

#Cleanup MDT Monitoring data
Update-Log -Data "Cleanup MDT Monitoring data"
if($EnableMDTMonitoring -eq $True){
    foreach($RefTaskSequenceID in $RefTaskSequenceIDs){
        Get-MDTMonitorData -Path MDT: | Where-Object -Property Name -EQ -Value $RefTaskSequenceID | Remove-MDTMonitorData -Path MDT:
    }
}

if(!($TestMode -eq $True)){
    #Show the OVF files:
    Update-Log -Data "Show the OVF's"
    Foreach($Ref in $RefTaskSequenceIDs){
        $FullRefPath = $(("$OVFShare\$Ref\$Ref") + ".ovf")
        If((Test-Path -Path $FullRefPath) -eq $true){
            $Item = Get-Item -Path $FullRefPath
            Update-Log -Data "OVF: $($Item.FullName)"
        }
        Else{
            Update-Log -Data "Could not find $FullRefPath, something went wrong, sorry" -Class Warning 
        }
    }
}

#FTP upload
if($FtpUpload -eq $True){
    $FTPUsername = "$($Settings.Settings.FTPUsername)"
    $FTPPassword = "$($Settings.Settings.FTPPassword)"
    $FTPPath = "$($Settings.Settings.FTPPath)"
    $FTPSecurePassword = ConvertTo-SecureString -String $FTPPassword -asPlainText -Force
    $FTPCredential = New-Object System.Management.Automation.PSCredential($FTPUsername,$FTPSecurePassword)

    Write-Host "Connecting to the ftp server $FTPServer ..."
    Set-FTPConnection -Credentials $FTPCredential -Server $FTPServer -Session MySession -UsePassive -ErrorAction Stop
    $Session = Get-FTPConnection -Session MySession -ErrorAction Stop

    Write-Host "Attempting to create target folder..."
    New-FTPItem -Session $Session -Name $(Get-Date -Format yyyymmdd) -Path $FTPPath -ErrorAction Stop

    # set new FTP path
    $FTPPath = $FTPPath + "/" + $(Get-Date -Format yyyymmdd)

    # Get all OVF folders
    $OVFDirs = Get-ChildItem $OVFShare -Directory

    # Upload all detected files
    Update-Log -Data "Starting FTP upload."
    ForEach ($Dir in $OVFDirs) {
        Write-Host "Uploading content of $($Dir.FullName)"
        Get-ChildItem $($Dir.FullName) | ForEach {Add-FTPItem -Session $Session -Path $FTPPath -LocalPath $_.FullName} -ErrorAction Stop
    }
    Update-Log -Data "FTP upload completed."
}

#Final update
$Endtime = Get-Date
Update-Log -Data "The script took $(($Endtime - $StartTime).Days):Days $(($Endtime - $StartTime).Hours):Hours $(($Endtime - $StartTime).Minutes):Minutes to complete."