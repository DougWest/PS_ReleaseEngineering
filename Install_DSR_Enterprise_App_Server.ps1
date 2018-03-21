if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}
if (-NOT $env:RABBIT){Write-Host "Required parameter RABBIT is null!"; exit 1}
if (-NOT $env:SQLUser){Write-Host "Required parameter SQLUser is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Check the target status.
Write-Host "Checking the target service status."
$RegTermTarget="{569F15AE-5C62-44B6-96A1-CDEC8ECB1EEB}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
}

if ($DisplayName)
{
    if ($env:Target_Version -EQ $DisplayVersion){Write-Host "Already installed."; exit 0}
    if (($env:Target_Version -EQ "6.8.707.7052") -AND ($DisplayVersion -NE "6.8.706.7045"))
    {
        Write-Host "$DisplayVersion installed, but 6.8.707.7052 can only upgrade from 6.8.706.7045. Cancelling action."; exit 1
    }
    elseif (($env:Target_Version -EQ "6.8.905.7393") -AND ($DisplayVersion -NE "6.8.904.7382"))
    {
        Write-Host "$DisplayVersion installed, but 6.8.905.7393 can only upgrade from 6.8.904.7382. Cancelling action."; exit 1
    }
    elseif (($env:Target_Version -EQ "6.8.1007.7619"))
    {
        Write-Host "$DisplayVersion installed, but 6.8.1007.7619 can only be installed bare. Cancelling action."; exit 1
    }
}
else
{
    if ($env:Target_Version -EQ "6.8.707.7052")
    {
        #Eventually, functionality should be added to install the base version for this patch and then apply the patch.
        Write-Host "No DSR Enterprise Server installed, but 6.8.707.7052 can only upgrade from 6.8.706.7045. Cancelling action."; exit 1
    }
    elseif ($env:Target_Version -EQ "6.8.905.7393")
    {
        #Eventually, functionality should be added to install the base version for this patch and then apply the patch.
        Write-Host "No DSR Enterprise Server installed, but 6.8.905.7393 can only upgrade from 6.8.904.7382. Cancelling action."; exit 1
    }
}

# Download NCR_DSR_Enterprise_Server.
Write-Host "Downloading the NCR_DSR_Enterprise_Server package."
if (($env:Target_Version -EQ "6.8.707.7052") -or ($env:Target_Version -EQ "6.8.905.7393")){$Artifact="NCR_DSR_Enterprise_Server_Patch"}else{$Artifact="NCR_DSR_Enterprise_Server"}
$ZipFileName = Nexus-DownloadFile

# Deploy the package.
Write-Host "Deploying the NCR_DSR_Enterprise_Server package."
$UNCFilePath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path -path "${UNCFilePath}\unzipped")){New-Item -path "${UNCFilePath}\unzipped" -type directory}
if ("False" -EQ (test-path -path "$UNCFilePath\$ZipFileName")){copy $ZipFileName "$UNCFilePath\$ZipFileName"}

$INSTALLDIR="D:\Program Files (x86)\NCR\DSREnterprise\"
$INSTALLDIR_UNC="Y:\Program Files (x86)\NCR\DSREnterprise\"

if ("False" -EQ (test-path -path $INSTALLDIR_UNC)){mkdir $INSTALLDIR_UNC}

"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"del unzipped\*.ms?" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit.txt){del logit.txt}" | Out-File -Append -FilePath runthis.ps1
if ($DisplayVersion)
{
    "Start-Process msiexec '/p `"NCR DSR Enterprise Server Patch.msp`" /qn REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit.txt' -Wait" | Out-File -Append -FilePath runthis.ps1
}
else
{
    "Start-Process msiexec '/i `"NCR DSR Enterprise Server.msi`" /qn INSTALLDIR=`"${INSTALLDIR}`" INSTALL_APPS=`"1`" INSTALL_CUST=`"`" INSTALL_SAM=`"1`" INSTALL_UTIL=`"`" INSTALL_WEB=`"`" DBSETUPCORE_SERVER=$env:DB DBSETUPCORE_USERNAME=${env:SQLUser} DBSETUPCORE_PASSWORD=${env:SQLUserPW} DBSETUPPRODUCT_SERVER=$env:DB DBSETUPPRODUCT_USERNAME=${env:SQLUser} DBSETUPPRODUCT_PASSWORD=${env:SQLUserPW} DBSETUPTRANSACTION_LOG_SERVER=$env:DB DBSETUPTRANSACTION_LOG_USERNAME=${env:SQLUser} DBSETUPTRANSACTION_LOG_PASSWORD=${env:SQLUserPW} DBSETUPTRANSACTIONS_SERVER=$env:DB DBSETUPTRANSACTIONS_USERNAME=${env:SQLUser} DBSETUPTRANSACTIONS_PASSWORD=${env:SQLUserPW} DBSETUPEJ_SERVER=$env:DB DBSETUPEJ_USERNAME=${env:SQLUser} DBSETUPEJ_PASSWORD=${env:SQLUserPW} DBSETUPEOM_SERVER=$env:DB DBSETUPEOM_USERNAME=${env:SQLUser} DBSETUPEOM_PASSWORD=${env:SQLUserPW} DBSETUPTRUSTEDCUSTOMER_SERVER=$env:DB DBSETUPTRUSTEDCUSTOMER_USERNAME=${env:SQLUser} DBSETUPTRUSTEDCUSTOMER_PASSWORD=${env:SQLUserPW} DBSETUPLOGDB_SERVER=$env:DB DBSETUPLOGDB_USERNAME=${env:SQLUser} DBSETUPLOGDB_PASSWORD=${env:SQLUserPW} RABBITMQSETUP_SERVER=$env:RABBIT REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit.txt' -Wait" | Out-File -Append -FilePath runthis.ps1
}

copy runthis.ps1 "$UNCFilePath\runthis.ps1"

invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

copy "$UNCFilePath\unzipped\logit.txt" .

# Check the target status.
Write-Host "Checking the target status post-install."
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "NCR Enterprise App Service not installed on $env:Target_Machine!"; Exit 1
}

$Service_Running = invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {Get-Service -DisplayName "Ncr.Retail.BatchApply"}

if ($Service_Running)
{
    $Service_Running
    if ("false" -EQ $env:PrimaryServer)
    {
        # Need to stop two services (which ones?) on non-primary DSR App servers.
        #invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {Stop-Service -DisplayName "Ncr.Retail.BatchApply"}
    }
}
else
{
    Write-Host "Ncr.Retail.BatchApply service not installed on $env:Target_Machine!"
    Exit 1
}

restart-computer -Credential $JenkinsCred -Authentication Default -computername $env:Target_Machine -force -wait -for PowerShell

Remove-PSDrive Y

