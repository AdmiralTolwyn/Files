<#
Author       : Anton Romanyuk
Usage        : Re-enables Windows Updates & Store Updates.
#>

#############################################
#      AVD CLEANUP - REVERT HARDENING       #
#############################################

Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Starting AVD AIB CLEANUP PHASE: Revert Hardening Settings - $((Get-Date).ToUniversalTime()) ***"

# ---------------------------------------------------------------------------
# 1. REVERT REGISTRY SETTINGS
# ---------------------------------------------------------------------------
Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Reverting Registry Policies... ***"

function Remove-RegPolicy($path, $name, $desc) {
    try {
        if (Test-Path $path) {
            $property = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
            if ($property) {
                Remove-ItemProperty -Path $path -Name $name -Force -ErrorAction Stop
                Write-Host "   -> SUCCESS: Reverted $desc (Deleted '$name' from '$path')" -ForegroundColor Green
            } else {
                Write-Host "   -> INFO: $desc is already reverted (Value '$name' not found)." -ForegroundColor Cyan
            }
        } else {
            Write-Host "   -> INFO: Registry path not found ($path). No action needed." -ForegroundColor Cyan
        }
    } catch {
        Write-Host "   -> ERROR: Failed to revert $desc. Details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# A. Re-enable Windows Auto Updates
# Removes 'NoAutoUpdate' value from HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU
Remove-RegPolicy -path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
                 -name 'NoAutoUpdate' `
                 -desc "Windows Auto Updates"

# B. Re-enable Windows Store Auto Updates
# Removes 'AutoDownload' value from HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore
Remove-RegPolicy -path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' `
                 -name 'AutoDownload' `
                 -desc "Store Auto-Downloads"

# ---------------------------------------------------------------------------
# 2. REVERT SCHEDULED TASKS
# ---------------------------------------------------------------------------
Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Re-enabling Scheduled Tasks... ***"

$task = "\Microsoft\Windows\WindowsUpdate\Scheduled Start"

Write-Host "   -> Enabling Task: $task"
$res = Schtasks.exe /change /enable /tn "$task" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   -> SUCCESS: Task Enabled." -ForegroundColor Green
} else {
    # It might fail if the task doesn't exist or permissions issue, but usually this works
    Write-Host "   -> WARNING: Could not enable task. ($($res | Out-String))" -ForegroundColor Yellow
}

Write-Host "`n*** DONE. ***"

#############
#    END    #
#############