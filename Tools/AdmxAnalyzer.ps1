<#
.SYNOPSIS
    Compares Group Policy ADML files and generates a color-coded HTML report.

.DESCRIPTION
    This script identifies all changes to policy strings (added, removed, or 
    altered) and presents the findings in a detailed HTML report with 
    color-coding for easy analysis.

.AUTHOR
    
#>

# --- Initialization and Configuration ---
Clear-Host
$ErrorActionPreference = "Stop"

try { Add-Type -AssemblyName System.Web } catch {}

$basePath = "C:\Program Files (x86)\Microsoft Group Policy"
Write-Host "Welcome to the ADML Comparison HTML Report Generator!" -ForegroundColor Cyan
Write-Host "==================================================="
Write-Host

# --- Step 1 & 2: Find Releases and Get User Selection ---
Write-Host "Searching for available Group Policy releases in '$basePath'..."
try {
    if (-not (Test-Path $basePath)) { throw "The directory '$basePath' does not exist." }
    $availableReleases = Get-ChildItem -Path $basePath -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "PolicyDefinitions\en-US")
    } | Sort-Object Name
    if ($availableReleases.Count -lt 2) {
        Write-Host "Error: Fewer than two valid releases were found to compare." -ForegroundColor Red; exit
    }
}
catch {
    Write-Host "Error: Could not find or read the directory '$basePath'." -ForegroundColor Red; exit
}

function Get-UserSelection {
    param([string]$promptMessage, [array]$choices, [array]$excludedIndices = @())
    Write-Host $promptMessage -ForegroundColor Green
    for ($i = 0; $i -lt $choices.Count; $i++) { Write-Host ("[{0}] {1}" -f ($i + 1), $choices[$i].Name) }
    do {
        try {
            $selectionIndex = [int](Read-Host "Please enter the corresponding number") - 1
            if (($selectionIndex -lt 0) -or ($selectionIndex -ge $choices.Count)) { $isValid = $false; Write-Host "Invalid number." -ForegroundColor Yellow }
            elseif ($excludedIndices -contains $selectionIndex) { $isValid = $false; Write-Host "Cannot select the same version twice." -ForegroundColor Yellow }
            else { $isValid = $true }
        }
        catch { $isValid = $false; Write-Host "Invalid input. Please enter a number." -ForegroundColor Yellow }
    } while (-not $isValid)
    return $selectionIndex
}

# Function to parse a single ADML file and return its strings in a hash table
function Get-AdmlStrings($filePath) {
    $stringTable = @{}
    # Check if the file exists before trying to read it
    if (-not (Test-Path $filePath)) {
        return $stringTable # Return an empty table if file not found
    }
    try {
        $xml = [xml](Get-Content -Path $filePath -Raw -Encoding UTF8)
        if ($null -ne $xml.policyDefinitionResources.resources.stringTable.string) {
            $xml.policyDefinitionResources.resources.stringTable.string | ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace($_.id)) {
                    $trimmedId = $_.id.Trim()
                    $stringTable[$trimmedId] = Normalize-Text $_.'#text'
                }
            }
        }
    }
    catch {
        # Catch any other parsing errors silently
    }
    return $stringTable
}

# Function to normalize text by trimming whitespace and standardizing newlines
function Normalize-Text($text) {
    if ($null -eq $text) { return "" }
    return $text.Replace("`r`n", "`n").Replace("`r", "`n").Trim()
}

$sourceIndex = Get-UserSelection -promptMessage "Select the OLDER version (Source) for comparison:" -choices $availableReleases
$referenceIndex = Get-UserSelection -promptMessage "Select the NEWER version (Reference) for comparison:" -choices $availableReleases -excludedIndices @($sourceIndex)

$sourceRelease = $availableReleases[$sourceIndex]
$referenceRelease = $availableReleases[$referenceIndex]
$sourcePath = Join-Path $sourceRelease.FullName "PolicyDefinitions\en-US"
$referencePath = Join-Path $referenceRelease.FullName "PolicyDefinitions\en-US"

Write-Host "`nComparing '$($sourceRelease.Name)' with '$($referenceRelease.Name)'..." -ForegroundColor Cyan
Write-Host "[*] Analyzing files and generating HTML report..."

# --- Create HTML fragments ---
$htmlFragments = @()

$fileDiff = Compare-Object -ReferenceObject (Get-ChildItem -Path $referencePath -Filter "*.adml") -DifferenceObject (Get-ChildItem -Path $sourcePath -Filter "*.adml") -Property Name -IncludeEqual

# Added Files
($fileDiff | Where-Object { $_.SideIndicator -eq "<=" }).Name | ForEach-Object {
    $fileName = $_
    $filePath = Join-Path $referencePath $fileName
    $strings = Get-AdmlStrings -filePath $filePath
    $fileSpecificChanges = "<table><tr class='row-file-added'><td colspan='4'><strong>This entire file was Added.</strong></td></tr>"
    $fileSpecificChanges += "<tr><th style='width: 8%;'>Status</th><th style='width: 22%;'>String ID</th><th colspan='2'>Value</th></tr>"
    foreach ($key in $strings.Keys | Sort-Object) {
        $newValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($strings[$key]))</pre>"
        $fileSpecificChanges += "<tr class='row-added'><td>Added</td><td><code>$key</code></td><td colspan='2'>$newValue</td></tr>"
    }
    $fileSpecificChanges += "</table>"
    $htmlFragments += "<h2>$fileName</h2>" + $fileSpecificChanges
}

# Removed Files
($fileDiff | Where-Object { $_.SideIndicator -eq "=>" }).Name | ForEach-Object {
    $fileName = $_

    # Check if the filename is not blank before processing
    if (-not [string]::IsNullOrWhiteSpace($fileName)) {
        $filePath = Join-Path $sourcePath $fileName
        $strings = Get-AdmlStrings -filePath $filePath
        $fileSpecificChanges = "<table><tr class='row-file-removed'><td colspan='4'><strong>This entire file was Removed.</strong></td></tr>"
        if ($strings.Count -gt 0) {
            $fileSpecificChanges += "<tr><th style='width: 8%;'>Status</th><th style='width: 22%;'>String ID</th><th colspan='2'>Value</th></tr>"
            foreach ($key in $strings.Keys | Sort-Object) {
                $oldValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($strings[$key]))</pre>"
                $fileSpecificChanges += "<tr class='row-removed'><td>Removed</td><td><code>$key</code></td><td colspan='2'>$oldValue</td></tr>"
            }
        }
        $fileSpecificChanges += "</table>"
        $htmlFragments += "<h2>$fileName</h2>" + $fileSpecificChanges
    }
}

# Common Files 
$commonFiles = $fileDiff | Where-Object { $_.SideIndicator -eq "==" } # filter to prevent processing duplicates
foreach ($file in $commonFiles) {
    $sourceFilePath = Join-Path $sourcePath $file.Name
    $referenceFilePath = Join-Path $referencePath $file.Name
    $fileSpecificChanges = ""

    try {
        $sourceXml = [xml](Get-Content -Path $sourceFilePath -Raw)
        $referenceXml = [xml](Get-Content -Path $referenceFilePath -Raw)

        $sourceStrings = @{}
        $sourceXml.policyDefinitionResources.resources.stringTable.string.ForEach({ 
            # Trim the ID and normalize the text value before storing
            if ($_.id) {
                $trimmedId = $_.id.Trim()
                if ($trimmedId) { # Ensure the ID is not empty after trimming
                    $sourceStrings[$trimmedId] = Normalize-Text $_.'#text'
                }
            }
        })
        
        $referenceStrings = @{}
        $referenceXml.policyDefinitionResources.resources.stringTable.string.ForEach({ 
            # Trim the ID and normalize the text value before storing
            if ($_.id) {
                $trimmedId = $_.id.Trim()
                if ($trimmedId) { # Ensure the ID is not empty after trimming
                    $referenceStrings[$trimmedId] = Normalize-Text $_.'#text'
                }
            }
        })

        # Now, compare the collections of cleaned keys
        $stringDiff = Compare-Object -ReferenceObject ([string[]]$referenceStrings.Keys) -DifferenceObject ([string[]]$sourceStrings.Keys) -IncludeEqual
        
        $addedStrings = $stringDiff | Where-Object { $_.SideIndicator -eq "<=" }
        $removedStrings = $stringDiff | Where-Object { $_.SideIndicator -eq "=>" }
        $commonStrings = $stringDiff | Where-Object { $_.SideIndicator -eq "==" }
        $modifiedStrings = @{}

        foreach ($stringId in $commonStrings.InputObject) {
            # The values in the hashtables are already clean, so a direct comparison is now accurate
            if ($sourceStrings[$stringId] -ne $referenceStrings[$stringId]) {
                # Store the clean, normalized values for the report
                $modifiedStrings[$stringId] = @{ Old = $sourceStrings[$stringId]; New = $referenceStrings[$stringId] }
            }
        }
        # --- END OF LOGIC ---
        
        if ($addedStrings -or $removedStrings -or ($modifiedStrings.Count -gt 0)) {
            $fileSpecificChanges += "<table><tr><th style='width: 8%;'>Status</th><th style='width: 22%;'>String ID</th><th style='width: 35%;'>Old Value</th><th style='width: 35%;'>New Value</th></tr>"
            
            # Sorting each collection before generating HTML **
            if ($addedStrings) {
                ($addedStrings | Sort-Object -Property InputObject).InputObject | ForEach-Object {
                    $newValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($referenceStrings[$_]))</pre>"
                    $fileSpecificChanges += "<tr class='row-added'><td>Added</td><td><code>$_</code></td><td></td><td>$newValue</td></tr>"
                }
            }
            if ($removedStrings) {
                ($removedStrings | Sort-Object -Property InputObject).InputObject | ForEach-Object {
                    $oldValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($sourceStrings[$_]))</pre>"
                    $fileSpecificChanges += "<tr class='row-removed'><td>Removed</td><td><code>$_</code></td><td>$oldValue</td><td></td></tr>"
                }
            }
            if ($modifiedStrings.Count -gt 0) {
                ($modifiedStrings.GetEnumerator() | Sort-Object -Property Name) | ForEach-Object {
                    $oldValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($_.Value.Old))</pre>"
                    $newValue = "<pre>$([System.Web.HttpUtility]::HtmlEncode($_.Value.New))</pre>"
                    $fileSpecificChanges += "<tr class='row-modified'><td>Modified</td><td><code>$($_.Name)</code></td><td>$oldValue</td><td>$newValue</td></tr>"
                }
            }
            $fileSpecificChanges += "</table>"
        }
    }
    catch {
        $fileSpecificChanges += "<table><tr class='row-processing-error'><td colspan='4'><strong>A processing error occurred: $([System.Web.HttpUtility]::HtmlEncode($_.Exception.Message))</strong></td></tr></table>"
    }

    if ($fileSpecificChanges) {
        $htmlFragments += "<h2>$($file.Name)</h2>" + $fileSpecificChanges
    }
}

# --- Generate and Launch the HTML Report ---
if ($htmlFragments.Count -eq 0) {
    Write-Host "No differences were found between the two versions." -ForegroundColor Green
    exit
}

$reportPath = Join-Path $env:TEMP "ADML_Comparison_Report.html"
$htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>ADML Comparison Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 20px; font-size: 14px; background-color: #fdfdfd; }
        h1, h2 { color: #333; }
        h2 { border-bottom: 2px solid #ccc; padding-bottom: 5px; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; margin-top: 15px; table-layout: fixed; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; vertical-align: top; word-wrap: break-word; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .row-added { background-color: #e6ffed; }
        .row-removed { background-color: #ffebe9; }
        .row-modified { background-color: #fff8e1; }
        .row-processing-error, .row-file-removed { background-color: #ffcdd2; font-weight: bold; }
        .row-file-added { background-color: #c8e6c9; font-weight: bold; }
        .summary { margin-bottom: 20px; padding: 15px; border: 1px solid #ddd; background-color: #f9f9f9; border-radius: 5px; }
        code { font-family: Consolas, "Courier New", monospace; font-size: 13px; color: #c7254e; background-color: #f9f2f4; padding: 2px 4px; border-radius: 4px;}
        pre { white-space: pre-wrap; margin: 0; font-family: Consolas, "Courier New", monospace; }
    </style>
</head>
<body>
    <h1>ADML Comparison Report</h1>
    <div class="summary">
        <strong>Source (Old):</strong> $($sourceRelease.Name)<br>
        <strong>Reference (New):</strong> $($referenceRelease.Name)<br>
        <strong>Generated On:</strong> $(Get-Date)
    </div>
"@

$htmlBody = $htmlFragments | Sort-Object | Out-String
$htmlFooter = "</body></html>"
$htmlContent = $htmlHeader + $htmlBody + $htmlFooter

$htmlContent | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "`nReport generated successfully: $reportPath" -ForegroundColor Green
Invoke-Item -Path $reportPath