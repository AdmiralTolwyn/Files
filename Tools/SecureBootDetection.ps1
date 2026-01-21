<#
.SYNOPSIS
    Retrieves the comprehensive status of Secure Boot Certificate Authority (CA) updates, 
    including real-time update events if a process is InProgress.

.DESCRIPTION
    Scans the Windows System Event Log (1801, 1808) for historical status and checks 
    the Servicing Registry Key for the current deployment state. If the registry state 
    is "InProgress", it queries additional events (1032, 1033, 1795-1798) to report 
    real-time update activity. It also identifies the ID of the single latest event 
    from the in-progress set.

.OUTPUTS
    PSCustomObject
        Contains properties: ConfidenceStatus, UpdateSuccess, LastEvent1801Time, LastEvent1808Time,
        UEFICA2023Status, UEFICA2023Error, UEFICA2023Capable, InProgressEvents, LatestInProgressEventId.
#>
function Get-SecureBootCAUpdateStatus {
    # --------------------------------------------------------------------------------
    # 1. INITIALIZATION AND EVENT DEFINITION
    # --------------------------------------------------------------------------------
    
    # Initialize all output variables with defaults.
    $eventIdsToTrack = @(1801, 1808)
    
    # Event Log Data (Historical/Prerequisite)
    $confidenceStatus = "Not Found"
    $latest1801Time = $null
    $updateSuccess = $false
    $latest1808Time = $null
    
    # Registry Data (Current State)
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing'
    $UEFICA2023Status = "Key Not Found"
    $UEFICA2023Error = $null
    $UEFICA2023Capable = $null
    
    # New: Event Data for In-Progress updates
    $inProgressEvents = @() 
    $latestInProgressEventId = "N/A" # Default: N/A, updated only if status is "InProgress"

    # --------------------------------------------------------------------------------
    # 2. EVENTS RETRIEVAL (Historical Status: 1801, 1808)
    # --------------------------------------------------------------------------------
    
    try {
        $eventFilter = @{ LogName = 'System'; ID = $eventIdsToTrack }
        Write-Host "Querying SYSTEM event log..."
        $recentEvents = Get-WinEvent -FilterHashtable $eventFilter -ErrorAction Stop
        
        # Process Event 1801 (Confidence Check)
        $latest_Event_1801 = $recentEvents | Where-Object {$_.Id -eq 1801} | Sort-Object TimeCreated -Descending | Select-Object -First 1
        if ($latest_Event_1801) {
            $latest1801Time = $latest_Event_1801.TimeCreated
            if ($latest_Event_1801.Message -match '(High Confidence|Needs More Data|Unknown|Paused)') {
                 $confidenceStatus = $matches[1]
            } else {
                 $confidenceStatus = "Format Error"
            }
        } 

        # Process Event 1808 (Success Check)
        $latest_Event_1808 = $recentEvents | Where-Object {$_.Id -eq 1808} | Sort-Object TimeCreated -Descending | Select-Object -First 1
        if ($latest_Event_1808) {
             $latest1808Time = $latest_Event_1808.TimeCreated
             $updateSuccess = $true
        } 
        
    } catch {
        $confidenceStatus = "Error: Event Access Failed ($($_.Exception.Message))"
        Write-Error $confidenceStatus 
    }

    # --------------------------------------------------------------------------------
    # 3. REGISTRY QUERIES (Current Deployment Status)
    # --------------------------------------------------------------------------------

    if (Test-Path $regPath) {
        Write-Host "Querying SecureBoot Servicing Registry Keys..."
        try {
            $UEFICA2023Status = (Get-ItemProperty -Path $regPath -Name UEFICA2023Status -ErrorAction SilentlyContinue).UEFICA2023Status
            if (-not $UEFICA2023Status) { $UEFICA2023Status = "NotStarted (Value Missing)" }

            $UEFICA2023Error = (Get-ItemProperty -Path $regPath -Name UEFICA2023Error -ErrorAction SilentlyContinue).UEFICA2023Error
            if (-not $UEFICA2023Error) { $UEFICA2023Error = 0 }

            $UEFICA2023Capable = (Get-ItemProperty -Path $regPath -Name WindowsUEFICA2023Capable -ErrorAction SilentlyContinue).WindowsUEFICA2023Capable
            if (-not $UEFICA2023Capable) { $UEFICA2023Capable = 0 }

        } catch {
            $UEFICA2023Status = "Error: Registry Read Failed"
            Write-Error "Failed to read properties from $regPath. Error: $($_.Exception.Message)"
        }
    } else {
        $UEFICA2023Status = "NotStarted (Key Not Found)"
        $UEFICA2023Error = 0
        $UEFICA2023Capable = 0
    }

    # --------------------------------------------------------------------------------
    # 4. CONDITIONAL IN-PROGRESS EVENT QUERIES (1032, 1033, 1795, 1796, 1797, 1798)
    # --------------------------------------------------------------------------------
    
    # If the registry status indicates 'InProgress', pull specific events detailing the process.
    if ($UEFICA2023Status -eq "InProgress") {
        Write-Host "Servicing Status is 'InProgress'. Checking for detailed update events..."
        
        # Define the set of Event IDs that track the Secure Boot DB/DBX update process.
        $inProgressEventIds = @(1032, 1033, 1795, 1796, 1797, 1798)
        
        try {
            $inProgressFilter = @{ LogName = 'System'; ID = $inProgressEventIds }
            # Limit the event search to the most recent 100 for a reasonable scope.
            $inProgressLogs = Get-WinEvent -FilterHashtable $inProgressFilter -MaxEvents 100 -ErrorAction Stop
            
            # Sort all found logs by time and select the relevant properties.
            $sortedInProgressLogs = $inProgressLogs | Sort-Object TimeCreated -Descending
            
            # Extract the ID of the single latest in-progress event for quick reference.
            $latestInProgressEventId = $sortedInProgressLogs | Select-Object -First 1 -ExpandProperty Id
            
            # Store all events for detailed analysis in the array.
            $inProgressEvents = $sortedInProgressLogs | Select-Object Id, TimeCreated, Message
            
            Write-Host "Found $($inProgressEvents.Count) relevant in-progress events. Latest ID: $latestInProgressEventId"
            
        } catch {
            $inProgressEvents = @("Error: Could not retrieve in-progress events ($($_.Exception.Message))")
            $latestInProgressEventId = "Error"
            Write-Warning "Failed to retrieve in-progress events. Error: $($_.Exception.Message)"
        }
    }

    # --------------------------------------------------------------------------------
    # 5. RETURN STRUCTURED DATA FOR INVENTORY
    # --------------------------------------------------------------------------------
    
    # Return a structured object for easy consumption by an inventory system.
    return [PSCustomObject]@{
        # Event Log Data (Historical/Prerequisite)
        ConfidenceStatus  = $confidenceStatus
        UpdateSuccess     = $updateSuccess
        LastEvent1801Time = $latest1801Time
        LastEvent1808Time = $latest1808Time
        
        # Registry Servicing Key Data (Current State)
        UEFICA2023Status   = $UEFICA2023Status
        UEFICA2023Error    = $UEFICA2023Error
        UEFICA2023Capable  = $UEFICA2023Capable
        
        # In-Progress Details (Conditional)
        InProgressEvents  = $inProgressEvents
        LatestInProgressEventId = $latestInProgressEventId
    }
}

# --- Implementation Example ---
$InventoryRecord = Get-SecureBootCAUpdateStatus
$InventoryRecord | Select ConfidenceStatus, UpdateSuccess, UEFICA2023Status, UEFICA2023Error, UEFICA2023Capable, LatestInProgressEventId | ft