<#
Author       : Anton Romanyuk
Usage        : RUN LOCALLY with Entra ID Auth.
               Downloads the payloads for Stub Apps to fix Golden Image provisioning.
#>

$downloadPath = "C:\Temp\AVD_Stubs_Payload"
if (!(Test-Path $downloadPath)) { New-Item -Path $downloadPath -ItemType Directory -Force }

# List of Stub Apps to fix

$stubApps = @(
    @{Id = "9NV2L4XVMCXM";   Name = "Microsoft Photos Legacy"},
    @{Id = "9WZDNCRFJ3PR";   Name = "Windows Clock"},
    @{Id = "9NBLGGH5R558";   Name = "Microsoft To Do"},
    @{Id = "9NMPJ99VJBWV";   Name = "Phone Link"},
    @{Id = "9WZDNCRFHWKN";   Name = "Windows Sound Recorder"},
    @{Id = "XP89DCGQ3K6VLD"; Name = "Dev Home"},
    @{Id = "9NZ6S5PMH67G";   Name = "Power Automate"},
    @{Id = "9NBLGGH4QGHW";   Name = "Microsoft Sticky Notes"},
    @{Id = "9MV0B5HZVK9Z";   Name = "Xbox App"},
    @{Id = "9WZDNCRFJ3Q2";   Name = "MSN Weather"},
    @{Id = "9WZDNCRFHVFW";   Name = "Microsoft News"}
)


Write-Host "*** Starting Stub Payload Download ***" -ForegroundColor Cyan

foreach ($app in $stubApps) {
    Write-Host "`n--- Processing: $($app.Name) ($($app.Id)) ---"
    
    $targetDir = Join-Path $downloadPath $app.Name
    if (!(Test-Path $targetDir)) { New-Item -Path $targetDir -ItemType Directory -Force | Out-Null }

    # Command: Force MSStore, Force x64 to match your image
    $args = "download --id $($app.Id) --download-directory `"$targetDir`" --source msstore --accept-package-agreements --accept-source-agreements --skip-license --architecture x64"
    
    Write-Host "Running Winget..."
    $proc = Start-Process -FilePath "winget.exe" -ArgumentList $args -Wait -NoNewWindow -PassThru
    
    if ($proc.ExitCode -eq 0) {
        Write-Host "SUCCESS: Downloaded to $targetDir" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Failed with code $($proc.ExitCode)" -ForegroundColor Red
    }
}

Write-Host "`n*** DOWNLOAD COMPLETE ***" -ForegroundColor Cyan
Write-Host "Please Zip the folder '$downloadPath' and add it to your Packer File Provisioner."