if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}
if (-NOT $env:CopientWebUser){Write-Host "Required parameter CopientWebUser is null!"; exit 1}
if (-NOT $env:CopientWebPass){Write-Host "Required parameter CopientWebPass is null!"; exit 1}
 
. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Check the target status.
Write-Host "Checking the target service status."
$RegTermTarget="{AAAAAAAA-BBBB-CCCC-0000-111111199697}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
}

if ($DisplayName)
{
    if ($env:Target_Version -EQ $DisplayVersion){Write-Host "Already installed."; exit 0}
}

# Download AMS_Enterprise_Server
$Artifact="Logix"
$ZipFileName = Nexus-DownloadFile

# Deploy the package.
Write-Host "Setting up the deployment."
$UNCFilePath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path -path "${UNCFilePath}\unzipped")){New-Item -path "${UNCFilePath}\unzipped" -type directory}
if ("False" -EQ (test-path -path "$UNCFilePath\$ZipFileName")){copy $ZipFileName "$UNCFilePath\$ZipFileName"}

$INSTALLDIR="`"D:\Copient\`""
$INSTALLDIR_UNC="Y:\Copient"

if ("False" -EQ (test-path -path $INSTALLDIR_UNC)){mkdir $INSTALLDIR_UNC}
if ("True" -EQ (test-path -path "$INSTALLDIR_UNC\unzipped\Logix_*")){Remove-Item "$INSTALLDIR_UNC\unzipped\Logix_*" -Recurse -Force}

"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"Remove-Item unzipped\*.zip" | Out-File -Append -FilePath runthis.ps1
"if (test-path unzipped\Logix_Base){Remove-Item -Recurse -Force unzipped\Logix_Base}" | Out-File -Append -FilePath runthis.ps1
"if (test-path unzipped\Logix_MSI){Remove-Item -Recurse -Force unzipped\Logix_MSI}" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\Logix_MSI" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit.txt){Remove-Item logit.txt}" | Out-File -Append -FilePath runthis.ps1
"Start-Process msiexec '/i Logix.msi /qn SERVER_TYPE=web INSTALL_UE=true INSTALLDIR=$INSTALLDIR WEBUSER=${env:CopientWebUser} WEBPASSWORD=${env:CopientWebPass} WEBPASSWORD2=${env:CopientWebPass} RESET_WEB_PASSWORD=true HOST_HEADER_NAME=`"`" LISTEN_ADDRESS=* PORT_NUMBER=80 LOGIXEX_DATABASE=LogixEX LOGIXEX_SERVER=${env:DB} LOGIXRT_DATABASE=LogixRT LOGIXRT_SERVER=${env:DB} LOGIXWH_DATABASE=LogixWH LOGIXWH_SERVER=${env:DB} LOGIXXS_DATABASE=LogixXS LOGIXXS_SERVER=${env:DB} REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit.txt' -Wait" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 "$UNCFilePath\runthis.ps1"

Write-Host "Deploying the $Artifact package."
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

copy "$UNCFilePath\unzipped\logit.txt" .

Remove-PSDrive Y

#Checking AMS Web Service
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "AMS Web Service not installed on $env:Target_Machine!"
}

$SiteURL="http://$env:Target_Machine/Logix/"

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
