<#

************************************************************************************************************************

Created:    2018-12-12
Version:    1.0

Author:     Anton Romanyuk

Purpose:    Script to create language-specific zip archives containing lp.cab + features on demand

************************************************************************************************************************

#>

cls

#---------------------------------------------------------------------------

# Adjust these variables if necessary 

$lan_lis = @("de-de","fr-fr","es-es","el-gr","hu-hu","it-it","nl-nl","pl-pl","pt-pt","ru-ru","sv-se","tr-tr")
$src_dir = $PSScriptRoot 
$dst_dir = $PSScriptRoot + "\LangPacks"

#---------------------------------------------------------------------------

If (Test-Path "$src_dir\metadata") {
    Write-Host "Metadata folder found. Removing..."
    Remove-Item -Path "$src_dir\metadata" -Force -Recurse
}

New-Item -Path $dst_dir -ItemType Directory -Force

ForEach ($lan in $lan_lis) {

        #Construct full path for each language package
        $sub_dir = $src_dir + "\" + $lan

        # Create subfolders
        Write-Host "Creating language code subfolder:" $sub_dir -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path $sub_dir

        #Find language packages and copy them to subfolders
        Write-Host "Copying" $lan "source files to " $sub_dir -ForegroundColor Green
        Get-ChildItem $src_dir  -force | Where-Object {$_.name -like '*LanguageFeatures*' + $lan + '*' -or $_.name -like '*Language-Pack_x64_' + $lan + '.cab'`
             -or $_.name -like '*InternetExplorer*' + $lan + '*'} | Copy-Item -Destination $sub_dir -Force
        
        #Remove Retail-Demo package
        Write-Host "Removing" $lan "RetailDemo package file..." -ForegroundColor Green
        Get-ChildItem $sub_dir  -force | Where-Object {$_.name -like '*RetailDemo*'} | Remove-Item -Force

        #Compress language bits
        Write-Host "Creating archive $lan.zip"
        Compress-Archive -Path $sub_dir -CompressionLevel NoCompression -DestinationPath "$dst_dir\$lan.zip" -Force
} 
