<#
Author       : Anton Romanyuk
Usage        : Blocks auto update, Installs Winget, Installs Apps.
               Supports -SkipApps and -SkipUserRegistration for Pre-Sysprep provisioning.
               -AppIds array for dynamic app installation.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [switch]$SkipApps = $false,

    [Parameter(Mandatory=$false)]
    [string[]]$AppIds = @(),

    [Parameter(Mandatory=$false)]
    [switch]$SkipUserRegistration = $false
)
#############################################
#      VDI Image Customizer - Winget        #
#############################################

# 1. Initialize Logging
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "*** Starting AVD AIB CUSTOMIZER PHASE: Install Winget & Apps - $((Get-Date).ToUniversalTime()) ***"

# ---------------------------------------------------------------------------
# CONFIGURATION: DEFAULT CUSTOM ARGUMENTS
# ---------------------------------------------------------------------------
# These are used if you provide an ID *without* specifying arguments in the parameter.
$DefaultAppArgs = @{
    "Adobe.Acrobat.Reader.64-bit"  = "DISABLE_ARM_SERVICE_INSTALL=1 DISABLEDESKTOPSHORTCUT=1"
    "Microsoft.VisualStudioCode"   = "/mergetasks=!runcode,!desktopicon,!quicklaunchicon"
}

# ---------------------------------------------------------------------------
# 1.1 EXECUTION CONTEXT VERIFICATION
# ---------------------------------------------------------------------------
Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Verifying Execution Context... ***"

# Identify User
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal   = [Security.Principal.WindowsPrincipal]$currentUser
$isAdmin     = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Identify Paths
$scriptPath  = if ($PSCommandPath) { $PSCommandPath } else { "Running from Memory/Inline" }
$workingDir  = (Get-Location).Path

Write-Host "   -> Current User      : $($currentUser.Name)"
Write-Host "   -> User SID          : $($currentUser.User.Value)"
Write-Host "   -> Is Administrator  : $isAdmin"
Write-Host "   -> Script Location   : $scriptPath"
Write-Host "   -> Working Directory : $workingDir"
Write-Host "----------------------------------------------------------------"

# ---------------------------------------------------------------------------
# 2. ENVIRONMENT HARDENING & LOGGING
# ---------------------------------------------------------------------------
Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Preparing Environment & Blocking Updates... ***"

function Set-RegKey($path, $name, $value, $desc) {
    try {
        if (!(Test-Path $path)) { 
            New-Item -Path $path -Force | Out-Null
            Write-Host "   -> Created Registry Path: $path" 
        }
        New-ItemProperty -Path $path -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        Write-Host "   -> SUCCESS: $desc ($name = $value)" -ForegroundColor Green
    } catch {
        Write-Host "   -> ERROR: Failed to set $desc. Details: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# A. Block Windows Auto Update (AU)
Set-RegKey -path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
           -name 'NoAutoUpdate' `
           -value '1' `
           -desc "Disable Windows Auto Updates"

# B. Block Windows Store Auto Updates (Crucial for Image Building)
# AutoDownload: 2 = Off, 4 = On.
Set-RegKey -path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' `
           -name 'AutoDownload' `
           -value '2' `
           -desc "Disable Store Auto-Downloads"

# C. Block Language Pack Cleanup (Prevents Sysprep issues)
Set-RegKey -path 'HKLM:\Software\Policies\Microsoft\Control Panel\International' `
           -name 'BlockCleanupOfUnusedPreinstalledLangPacks' `
           -value '1' `
           -desc "Block Language Pack Cleanup"

# D. Enable App Sideloading
Set-RegKey -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
           -name 'AllowAllTrustedApps' `
           -value '1' `
           -desc "Enable Sideloading (AllowAllTrustedApps)"

# E. Disable Scheduled Tasks
Write-Host "   -> Disabling conflicting Scheduled Tasks..."
$tasksToDisable = @(
    "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup", # Kills Appx installs
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start"                # Triggers WU
)

foreach ($task in $tasksToDisable) {
    $res = Schtasks.exe /change /disable /tn "$task" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      -> Task Disabled: $task" -ForegroundColor Green
    } else {
        # Warning only, as task might not exist on some OS versions
        Write-Host "      -> Warning: Could not disable $task. ($($res | Out-String))" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# 3. DOWNLOAD WINGET ASSETS
# ---------------------------------------------------------------------------

# Check Current State (Stub & Version)
Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Checking current DesktopAppInstaller status via WinRT PackageManager... ***"

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    
    $pkgManagerType = [Type]::GetType("Windows.Management.Deployment.PackageManager, Windows.Management.Deployment, ContentType=WindowsRuntime")
    if (-not $pkgManagerType) {
        $pkgManager = [Windows.Management.Deployment.PackageManager,Windows.Management.Deployment,ContentType=WindowsRuntime]::new()
    } else {
        $pkgManager = [Activator]::CreateInstance($pkgManagerType)
    }

    $packages = $pkgManager.FindPackagesForUser("")
    $wingetPkg = $packages | Where-Object { $_.Id.Name -eq "Microsoft.DesktopAppInstaller" } | Select-Object -First 1

    if ($wingetPkg) {
        $v = $wingetPkg.Id.Version
        $currentVersion = "$($v.Major).$($v.Minor).$($v.Build).$($v.Revision)"
        
        if ($wingetPkg.IsStub) {
            Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Status: DETECTED STUB. Version: $currentVersion. Remediation required. ***" -ForegroundColor Yellow
        } else {
            Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Status: Fully Installed. Current Version: $currentVersion. Checking for updates... ***" -ForegroundColor Cyan
        }
    } else {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Status: Not Installed. Proceeding with fresh installation. ***" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Warning: Stub check failed ($($_.Exception.Message)). Proceeding. ***"
}

Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Downloading Winget Assets... ***"
$repoOwner = "microsoft"; $repoName = "winget-cli"
$apiUrl    = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"
$tempDir   = Join-Path $env:TEMP "WingetInstall_$(Get-Random)"

try {
    if (!(Test-Path $tempDir)) { New-Item -Path $tempDir -ItemType Directory -Force | Out-Null }

    Write-Host "   -> Fetching Release Info from GitHub..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent"="PS"; "Accept"="application/vnd.github.v3+json" }
    
    $assets = $response.assets
    $bundle = $assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
    $license = $assets | Where-Object { $_.name -like "*License1.xml" } | Select-Object -First 1
    $deps   = $assets | Where-Object { $_.name -like "*Dependencies.zip" } | Select-Object -First 1

    if (!$bundle) { Throw "No bundle found." }

    function Download-Asset($a, $d) {
        $mb = "{0:N2} MB" -f ($a.size / 1MB)
        Write-Host "   -> Downloading $($a.name) ($mb)..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $a.browser_download_url -OutFile (Join-Path $d $a.name) -UseBasicParsing
    }

    Download-Asset $bundle $tempDir
    $bundlePath = Join-Path $tempDir $bundle.name
    
    $licensePath = $null; if ($license) { Download-Asset $license $tempDir; $licensePath = Join-Path $tempDir $license.name }
    
    $depFilesList = @()
    if ($deps) {
        Download-Asset $deps $tempDir
        $zip = Join-Path $tempDir $deps.name; $dest = Join-Path $tempDir "Deps"
        Expand-Archive $zip $dest -Force
        
        # We explicitly filter for 'x64' to exclude ARM/x86 packages that cause 0x80073D10 errors.
        Write-Host "   -> Filtering Dependencies for x64 architecture..."
        $depFilesList = Get-ChildItem $dest -Recurse -Include "*.appx", "*.msix" | 
                        Where-Object { $_.Name -like "*x64*" } | 
                        Select-Object -ExpandProperty FullName
        
        Write-Host "   -> Found $($depFilesList.Count) valid x64 dependency packages."
    }

    # ---------------------------------------------------------------------------
    # 4. PROVISION WINGET (System Context)
    # ---------------------------------------------------------------------------
    Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Provisioning Winget (System-Wide)... ***"
    
    try {
        # Preparing Parameters for Splatting
        $params = @{
            Online             = $true
            PackagePath        = $bundlePath
            StubPackageOption  = "installfull"
            ErrorAction        = "Stop"
            Verbose            = $true
        }

        if ($licensePath) { $params.Add("LicensePath", $licensePath) } else { $params.Add("/SKipLicense") }
        if ($depFilesList.Count -gt 0) { $params.Add("DependencyPackagePath", $depFilesList) }

        Write-Host "   -> Executing Add-AppxProvisionedPackage with StubPackageOption:installfull..."
        Add-AppxProvisionedPackage @params | Out-Null
        
        Write-Host "   -> SUCCESS: Winget Provisioned System-Wide." -ForegroundColor Green
    }
    catch {
        Write-Host "   -> CRITICAL ERROR: Provisioning Failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }

    # ---------------------------------------------------------------------------
    # 5. VERIFY PROVISIONING
    # ---------------------------------------------------------------------------
    $provCheck = Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -eq "Microsoft.DesktopAppInstaller"}
    if (-not $provCheck) {
        Throw "CRITICAL ERROR: Winget was not found in Provisioned Packages. Sysprep will fail."
    }
    Write-Host "   -> VERIFIED: Winget is provisioned (Version: $($provCheck.Version))." -ForegroundColor Green

    # ---------------------------------------------------------------------------
    # 6. REGISTER FOR CURRENT USER (Conditional)
    # ---------------------------------------------------------------------------
    if ($SkipUserRegistration) {
        Write-Host "`n*** Skipping User Registration (-SkipUserRegistration active) ***" -ForegroundColor Cyan
    } 
    else {
        Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Registering Winget for Current User... ***"
        try {
            if ($depFilesList.Count -gt 0) {
                Add-AppxPackage -Path $bundlePath -DependencyPath $depFilesList -ForceApplicationShutdown -ForceUpdateFromAnyVersion
            } else {
                Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ForceUpdateFromAnyVersion
            }
            Write-Host "   -> User Registration Successful." -ForegroundColor Green
        } catch { 
            Write-Host "   -> Note: User Registration might have happened automatically via Provisioning. ($($_.Exception.Message))" -ForegroundColor Yellow 
        }
    }

} catch {
    Write-Host "*** FATAL ERROR during Setup: $($_.Exception.Message) ***" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# BOOTSTRAP DEFAULT SOURCES (Conditional)
# ---------------------------------------------------------------------------
if (-not $SkipApps -and -not $SkipUserRegistration) {
    try {


        # The default sources are often corrupted in fresh images. We must reset and explicitly add 'winget'.
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Repairing Winget Sources (Fixing 0x8a15000f)... ***"
        try {
            # We download explicitly to temp to avoid network errors during Add-AppxPackage
            $sourceUrl  = "https://cdn.winget.microsoft.com/cache/source.msix"
            $sourcePath = Join-Path $tempDir "source.msix"

            # This pre-seeds the Winget source cache so it doesn't fail trying to sync from internet
            Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Downloading Winget Source MSIX... ***"
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $sourceUrl -OutFile $sourcePath -UseBasicParsing

            Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Installing Winget Source MSIX (Local File)... ***"
            Add-AppxPackage -Path $sourcePath -ForceApplicationShutdown
        }
        catch {
            Write-Host "*** AVD AIB CUSTOMIZER PHASE *** Warning during Source Repair: $($_.Exception.Message) ***" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "*** AVD AIB CUSTOMIZER PHASE *** FATAL ERROR during Bootstrapping: $($_.Exception.Message) ***" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n*** Skipping Source Bootstrap (-SkipApps or -SkipUserRegistration active) ***" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# 7. INSTALL APPLICATIONS (Conditional)
# ---------------------------------------------------------------------------
if ($SkipApps) {
    Write-Host "`n*** Skipping Application Installation (-SkipApps active) ***" -ForegroundColor Cyan
}
elseif ($AppIds.Count -eq 0) {
    Write-Host "`n*** No Apps provided in -AppIds argument. Skipping loop. ***" -ForegroundColor Yellow
}
else {
    Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Starting Application Installation Loop ***"

    # Resolve Winget Path
    $wingetCmd = "winget.exe"
    if (-not (Get-Command $wingetCmd -ErrorAction SilentlyContinue)) {
        $possiblePath = Get-ChildItem -Path "$env:ProgramFiles\WindowsApps" -Filter "winget.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($possiblePath) { $wingetCmd = $possiblePath.FullName }
    }
    Write-Host "   -> Using Winget Binary: $wingetCmd"

    # Source Reset
    # try {
    #    Write-Host "   -> Resetting Sources..."
    #    cmd.exe /c "echo Y | `"$wingetCmd`" source reset --force"
    #} catch {}

    # App Loop
    foreach ($entry in $AppIds)  {
        
        # LOGIC: Parse "ID;OverrideArgs" format
        if ($entry -match ";") {
            $parts = $entry -split ";", 2
            $currentId = $parts[0]
            $currentArgs = $parts[1]
            Write-Host "   -> Installing Package: $currentId (Inline Override: $currentArgs)"
        }
        else {
            $currentId = $entry
            # Check for Default Custom Args in HashTable
            if ($DefaultAppArgs.ContainsKey($currentId)) {
                $currentArgs = $DefaultAppArgs[$currentId]
                Write-Host "   -> Installing Package: $currentId (Default Override: $currentArgs)"
            }
            else {
                $currentArgs = $null
                Write-Host "   -> Installing Package: $currentId"
            }
        }

        # Command arguments breakdown:
        # install                       : Install the package
        # --id                          : Specify the exact ID
        # --exact                       : Ensure no fuzzy matching
        # --accept-package-agreements   : Auto accept EULA
        # --accept-source-agreements    : Auto accept Source agreements
        # --scope machine               : IMPORTANT for VDI - installs for all users (requires installer support)
        # --silent                      : No UI
        # --disable-interactivity       : Prevent popups
        # --source                      : specify winget repo

        # Build Arguments
        $argsList = "install --id $currentId --exact --accept-package-agreements --accept-source-agreements --scope machine --silent --disable-interactivity --source winget"
        
        if (-not [string]::IsNullOrEmpty($currentArgs)) {
            $argsList += " --custom `"$currentArgs`""
        }

        try {
            $proc = Start-Process -FilePath $wingetCmd -ArgumentList $argsList -Wait -NoNewWindow -PassThru
            
            if ($proc.ExitCode -eq 0) { 
                Write-Host "      -> SUCCESS." -ForegroundColor Green 
            } elseif ($proc.ExitCode -eq -1978335189) { 
                Write-Host "      -> ALREADY INSTALLED." -ForegroundColor Yellow 
            } else { 
                Write-Host "      -> FAILED (Code: $($proc.ExitCode))." -ForegroundColor Red 
            }
        } catch {
            Write-Host "      -> Execution Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ---------------------------------------------------------------------------
# 8. CLEANUP SHORTCUTS
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 8. CLEANUP SHORTCUTS (Dynamic Token Matching)
# ---------------------------------------------------------------------------
if (-not $SkipApps) {
    Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Removing Unwanted Desktop Shortcuts... ***"
    
    $desktopPaths = @(
        "C:\Users\Public\Desktop",
        "$env:USERPROFILE\Desktop"
    )

    # 1. STATIC OVERRIDES
    $shortcutsToRemove = @(
        "Adobe Acrobat*",  # Handles Adobe Reader DC
        "*7-Zip*"          # Handles 7-Zip File Manager
    )

    # 2. DYNAMIC TOKEN GENERATION
    $blocklist = @("Microsoft", "Google", "Mozilla", "Adobe", "Corporation", "Software", "x64", "64-bit", "Edition", "GmbH", "Inc", "LLC")

    if ($AppIds.Count -gt 0) {
        Write-Host "   -> Generating cleanup patterns from App IDs..."
        
        foreach ($entry in $AppIds) {
            # Strip arguments (Handle "ID;Args" format)
            $cleanId = ($entry -split ";")[0]
            
            # Use PowerShell -split operator with Regex character class [.-] 
            # This splits by dot OR hyphen safely on PS 5.1
            $tokens = $cleanId -split '[.-]'

            foreach ($token in $tokens) {
                # 1. Skip short tokens (e.g. "7", "v2")
                if ($token.Length -lt 3) { continue }
                
                # 2. Skip Blocklisted words (Safety check)
                if ($token -in $blocklist) { continue }

                # 3. Create Wildcard
                $pattern = "*$token*"

                if ($shortcutsToRemove -notcontains $pattern) {
                    $shortcutsToRemove += $pattern
                    Write-Host "      -> Added dynamic pattern: '$pattern' (Derived from $cleanId)" -ForegroundColor DarkGray
                }
            }
        }
    }

    # 3. EXECUTE REMOVAL
    foreach ($path in $desktopPaths) {
        if (Test-Path $path) {
            Write-Host "   -> Scanning $path..."
            foreach ($pattern in $shortcutsToRemove) {
                # Added -Force to ensure read-only shortcuts are deleted too
                Get-ChildItem -Path $path -Include "$pattern.lnk" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    Write-Host "      -> Removing Shortcut: $($_.Name)" -ForegroundColor Cyan
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 9. SYSPREP CLEANUP
# ---------------------------------------------------------------------------
# If we are in SkipUserRegistration mode, we probably didn't install the user packages, 
# but it's safe to run the cleanup anyway just to be sure.

Write-Host "`n*** AVD AIB CUSTOMIZER PHASE *** Cleaning up User-Context Packages for Sysprep... ***"
try {
    # Remove Source if exists (User context)
    $src = Get-AppxPackage -Name "Microsoft.Winget.Source"
    if ($src) { 
        Remove-AppxPackage -Package $src.PackageFullName -ErrorAction Stop 
        Write-Host "   -> Removed User Package: Microsoft.Winget.Source"
    }
} catch {
    Write-Host "   -> Cleanup Warning: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Cleanup Temp
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }

$stopwatch.Stop()
Write-Host "*** DONE. Time: $($stopwatch.Elapsed) ***"

#############
#    END    #
#############