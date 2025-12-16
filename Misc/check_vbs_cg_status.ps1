# --- Main Script ---
try {
    # Source for WMI property values:
    # https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity?tabs=security

    # --- Part 0: Prerequisite Check (Hyper-V) ---
    Write-Host "--- Prerequisite Status: Hyper-V ---" -ForegroundColor Yellow
    $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -ErrorAction SilentlyContinue
    if ($hyperVFeature) {
        if ($hyperVFeature.State -ne 'Enabled') {
            Write-Host "[FAIL] Hyper-V feature is not enabled. (State: $($hyperVFeature.State))" -ForegroundColor Red
            Write-Host "       Enabling Hyper-V is required for VBS." -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -WhatIf
        } else {
            Write-Host "[PASS] Hyper-V feature is enabled." -ForegroundColor Green
        }
    }
    else {
        Write-Warning "Could not check the status of the Microsoft-Hyper-V feature. This may require elevated permissions."
    }
    Write-Host ""

    # --- Part 1: Current Status Check ---
    Write-Host "--- VBS and Credential Guard Status ---" -ForegroundColor Yellow

    # Get the Device Guard status from WMI.
    $deviceGuardStatus = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard

    if (-not $deviceGuardStatus) {
        Write-Error "Could not retrieve Device Guard status information from the system."
    }
    else {
        # --- Initialize Status Variables ---
        $isVbsRunning = $false
        $isCgConfigured = $false
        $isMiConfigured = $false
        $isCgRunning = $false
        $isMiRunning = $false

        # --- Perform Checks ---
        if ($deviceGuardStatus.VirtualizationBasedSecurityStatus -eq 2) { $isVbsRunning = $true }
        if ($deviceGuardStatus.SecurityServicesConfigured -contains 1) { $isCgConfigured = $true }
        if ($deviceGuardStatus.SecurityServicesConfigured -contains 2) { $isMiConfigured = $true }
        if ($deviceGuardStatus.SecurityServicesRunning -contains 1) { $isCgRunning = $true }
        if ($deviceGuardStatus.SecurityServicesRunning -contains 2) { $isMiRunning = $true }

        # --- Display Results ---
        if ($isVbsRunning) {
            Write-Host "[PASS] Virtualization-Based Security (VBS) is enabled and running." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Virtualization-Based Security (VBS) is not running." -ForegroundColor Red
            Write-Host "       (Expected Status: 2, Actual: $($deviceGuardStatus.VirtualizationBasedSecurityStatus))"
        }
        if ($isCgConfigured) {
            Write-Host "[PASS] Credential Guard is configured." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Credential Guard is not configured." -ForegroundColor Red
        }if ($isMiConfigured) {
            Write-Host "[PASS] Memory integrity is configured." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Memory integrity is not configured." -ForegroundColor Red
        }
        if ($isCgRunning) {
            Write-Host "[PASS] Credential Guard is running." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Credential Guard is not running." -ForegroundColor Red
        }
        if ($isMiRunning) {
            Write-Host "[PASS] Memory integrity is running." -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Memory integrity is not running." -ForegroundColor Red
        }

        # --- Final Conclusion & Conditional Registry Change ---
        $allChecksPassed = $isVbsRunning -and $isCgConfigured -and $isMiConfigured -and $isCgRunning -and $isMiRunning

        if ($allChecksPassed) {
            Write-Host "`n[SUCCESS] The system is correctly configured with VBS and active Credential Guard/memory integrity." -ForegroundColor Green
        } else {
            Write-Host "`n[FAILURE] The system does not meet the required security configuration." -ForegroundColor Red
            
            # --- Part 2: Registry Configuration Check / Remediation ---
            Write-Host "`n--- Registry Configuration for Credential Guard and memory integrity (without UEFI Lock) ---" -ForegroundColor Yellow

            # Define the required registry settings
            $registrySettings = @(
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
                    Name  = "EnableVirtualizationBasedSecurity"
                    Value = 1
                },
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
                    Name  = "RequirePlatformSecurityFeatures"
                    Value = 3 # Secure Boot and DMA protection
                },
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
                    Name  = "LsaCfgFlags"
                    Value = 2 # Enable Credential Guard without UEFI lock
                },
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
                    Name  = "Locked"
                    Value = 0 
                },
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
                    Name  = "Enabled"
                    Value = 1 # Enable memory integrity...
                },
                [PSCustomObject]@{
                    Path  = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
                    Name  = "Locked"
                    Value = 0 # ... without UEFI lock
                }
            )

            foreach ($setting in $registrySettings) {
                $currentProperty = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue

                if ($null -ne $currentProperty) {
                    $currentValue = $currentProperty.($setting.Name)
                    Write-Host "Checking Registry: '$($setting.Path)'"
                    Write-Host "  - Key: '$($setting.Name)'"
                    Write-Host "  - Current Value: $currentValue"
                    if ($currentValue -ne $setting.Value) {
                        Write-Host "  - Desired Value: $($setting.Value)" -ForegroundColor Cyan
                        Write-Host "  - STATUS: Mismatch." -ForegroundColor Yellow
                        Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -WhatIf
                    } else {
                        Write-Host "  - STATUS: Value is already correctly set." -ForegroundColor Green
                    }
                } else {
                    Write-Host "Checking Registry: '$($setting.Path)'"
                    Write-Host "  - Key: '$($setting.Name)'"
                    Write-Host "  - Current Value: Not Found"
                    Write-Host "  - Desired Value: $($setting.Value)" -ForegroundColor Cyan
                    Write-Host "  - STATUS: Key not found." -ForegroundColor Yellow
                    New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -PropertyType DWord -WhatIf
                }
                Write-Host "" # Add a blank line for readability
            }
            
            Write-Host "A reboot is required for any registry changes to take effect." -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Error "An error occurred while checking the security status: $_"
}

