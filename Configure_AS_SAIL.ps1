if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:Target_SAIL_Version){Write-Host "Required parameter Target_SAIL_Version is null!"; exit 1}
if (-NOT $env:Target_SAILOverlay_Version){Write-Host "Required parameter Target_SAILOverlay_Version is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Download AS_Enterprise_SAIL
$Artifact="SAIL_Scripts"
#$Target_Version is used here!
$ZipFileName = Nexus-DownloadFile

# Download Microsoft Web Deploy Package
$MsiFileName = Nexus-DownloadFile -groupId "com.microsoft" -artifactId "WebDeploy" -versionId "2.10_amd64_en_US" -extensionId "msi"
$SAIL = Nexus-DownloadFile -groupId "com.ncr" -artifactId "SAIL.WebApi" -versionId "$env:Target_SAIL_Version" -extensionId "zip"
if ("CD10" -EQ $env:Target_SAILOverlay_Version)
{
    $SAILOverlay = Nexus-DownloadFile -groupId "com.ncr" -artifactId "SAIL-Overlay-REI" -versionId "$env:Target_SAILOverlay_Version" -extensionId "zip"
}
else
{
    $SAILOverlay = Nexus-DownloadFile -groupId "com.ncr" -artifactId "SAIL-Overlay-AS" -versionId "$env:Target_SAILOverlay_Version" -extensionId "zip"
}

# Deploy the package.
Write-Host "Deploying the $Artifact package."
$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path "${TargetWSPath}\unzipped")){New-Item -path "${TargetWSPath}\unzipped" -type directory}
if ("False" -EQ (test-path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}
if ("False" -EQ (test-path "${TargetWSPath}\$MsiFileName")){copy $MsiFileName "${TargetWSPath}\$MsiFileName"}
if ("False" -EQ (test-path "${TargetWSPath}\$SAIL")){copy $SAIL "${TargetWSPath}\$SAIL"}
if ("False" -EQ (test-path "${TargetWSPath}\$SAILOverlay")){copy $SAILOverlay "${TargetWSPath}\$SAILOverlay"}

# Unzipping and copying the folders and Install MS Web Deploy package
"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit.txt){del logit.txt}" | Out-File -Append -FilePath runthis.ps1
"Start-Process msiexec '/i $MsiFileName /qn ACCEPTEULA=1 REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit.txt' -Wait" | Out-File -Append -FilePath runthis.ps1
"del unzipped\SAIL_Install" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"d:\temp\unzipped\SAIL_Install\SAIL.zip`"){del `"d:\temp\unzipped\SAIL_Install\SAIL.zip`"}" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"d:\temp\unzipped\SAIL_Install\Overlay.zip`"){del `"d:\temp\unzipped\SAIL_Install\Overlay.zip`"}" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"d:\temp\${SAIL}`"){copy `"d:\temp\${SAIL}`" `"d:\temp\unzipped\SAIL_Install\`"}" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"d:\temp\${SAILOverlay}`"){copy `"d:\temp\${SAILOverlay}`" `"d:\temp\unzipped\SAIL_Install\`"}" | Out-File -Append -FilePath runthis.ps1
"Rename-Item -Path `"d:\temp\unzipped\SAIL_Install\${SAIL}`" -newName `"SAIL.zip`"" | Out-File -Append -FilePath runthis.ps1
"Rename-Item -Path `"d:\temp\unzipped\SAIL_Install\${SAILOverlay}`" -newName `"Overlay.zip`"" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\SAIL_Install" | Out-File -Append -FilePath runthis.ps1
copy runthis.ps1 "${TargetWSPath}\runthis.ps1"
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Unzipped.}
copy "${TargetWSPath}\unzipped\logit.txt" .

Remove-PSDrive Y

#Checking Ms Web Deploy
Write-Host "Checking Ms Web Deploy package"
$RegTermTarget="{5134B35A-B559-4762-94A4-FD4918977953}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "Ms Web Deploy package not installed on $env:Target_Machine!"
    Exit 1
}

#  Configuring and Verifying SAIL. Executing Vendor Provided Powershell Script
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp\unzipped\SAIL_Install; .\SAIL_Installer.ps1; echo Finished.}


#SAIL WEB URL
$SiteURL="http://$env:Target_Machine/SAIL"
$request=$null
try {
    $request = Invoke-WebRequest -Uri $SiteURL -ErrorAction SilentlyContinue
    } 
    catch [System.Net.WebException] {
        $request = $_.Exception.Response
    }
    catch {
        Write-Error $_.Exception
        return $null
    }
If ($request.StatusCode -eq "200") { 
    Write-Host "Site $SiteURL is OK!" 
}
Else {
    Write-Host "The Site $SiteURL may be down, please check!"
    Exit 1
}