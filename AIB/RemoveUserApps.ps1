<#
Author       : Anton Romanyuk (Logic based on Michael Niehaus)
Usage        : Removes apps installed for the user but not provisioned for the device to avoid Sysprep failures.
#>

#############################################
#         Remove Non-Provisioned Apps       #
#############################################

# 1. Initialize Logging and Timing
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "***Starting AVD AIB CUSTOMIZER PHASE: Remove User Apps (Sysprep Prep) - $((Get-Date).ToUniversalTime()) "

try {
    # 2. Get Provisioned Packages (The "Allow" list)
    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Retrieving list of Provisioned (System-wide) Packages... ***"
    $provisioned = Get-AppxProvisionedPackage -Online
    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Found $($provisioned.Count) provisioned packages. ***"

    # 3. Removal Loop
    # We loop twice to handle dependencies.
    $removedCount = 0

    for ($i = 1; $i -le 2; $i++) {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Starting Removal Loop $i of 2... ***"
        
        # Get current user packages, filtering out System-signature apps
        $userPackages = Get-AppxPackage | Where-Object { $_.SignatureKind -ne 'System' }

        foreach ($app in $userPackages) {
            # Check if this user app exists in the Provisioned list (matching Name and Version)
            $isProvisioned = $provisioned | Where-Object { $_.DisplayName -eq $app.Name -and $_.Version -eq $app.Version }

            if ($null -eq $isProvisioned) {
                Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Cleanup: Removing non-provisioned app: $($app.Name) ($($app.Version)) ... ***" -ForegroundColor Yellow
                
                try {
                    Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
                    $removedCount++
                    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Success: $($app.Name) removed. ***"
                }
                catch {
                    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Warning: Failed to remove $($app.Name). Details: $($_.Exception.Message) ***"
                }
            }
        }
    }

    if ($removedCount -eq 0) {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Status: System is clean. No non-provisioned user apps found. ***" -ForegroundColor Green
    } else {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Status: Cleanup complete. Removed $removedCount apps. ***" -ForegroundColor Green
    }

}
catch {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** ERROR: Script failed unexpectedly *** : [$($_.Exception.Message)]"
    exit 1
}

$stopwatch.Stop()
Write-Host "*** Ending AVD AIB CUSTOMIZER PHASE: Remove User Apps (Sysprep Prep) - Time taken: $($stopwatch.Elapsed) "

#############
#    END    #
#############