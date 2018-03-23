if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}
if (-NOT $env:CopientSVCUser){Write-Host "Required parameter CopientSVCUser is null!"; exit 1}
if (-NOT $env:CopientSVCPass){Write-Host "Required parameter CopientSVCPass is null!"; exit 1}
if (-NOT $env:CopientSERVICEUser){Write-Host "Required parameter CopientSERVICEUser is null!"; exit 1}
if (-NOT $env:CopientSERVICEPass){Write-Host "Required parameter CopientSERVICEPass is null!"; exit 1}

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
$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path -path "${TargetWSPath}\unzipped")){New-Item -path "${TargetWSPath}\unzipped" -type directory}
if ("False" -EQ (test-path -path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}

$INSTALLDIR="`"D:\Copient\`""
$INSTALLDIR_UNC="Y:\Copient"

if ("False" -EQ (test-path -path $INSTALLDIR_UNC)){mkdir $INSTALLDIR_UNC}
if ("True" -EQ (test-path -path "$INSTALLDIR_UNC\unzipped\Logix_*")){Remove-Item "$INSTALLDIR_UNC\unzipped\Logix_*" -Recurse -Force}

"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"Remove-Item unzipped\*.zip" | Out-File -Append -FilePath runthis.ps1
"if (test-path unzipped\Logix){Remove-Item -Recurse -Force unzipped\Logix}" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\Logix`")" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\Logix\Logix_MSI" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit.txt){Remove-Item logit.txt}" | Out-File -Append -FilePath runthis.ps1
"Start-Process msiexec '/i Logix.msi /qn SERVER_TYPE=application INSTALL_UE=true INSTALLDIR=$INSTALLDIR AGENTUSER=${env:CopientSVCUser} AGENTPASSWORD=${env:CopientSVCPass} AGENTPASSWORD2=${env:CopientSVCPass} RESET_AGENT_PASSWORD=true AUTOSTART_AGENTS=true START_AGENTS_NOW=true WEBSERVICESUSER=${env:CopientSERVICEUser} WEBSERVICESPASSWORD=${env:CopientSERVICEPass} WEBSERVICESPASSWORD2=${env:CopientSERVICEPass} RESET_WEBSERVICES_PASSWORD=true WEBSERVICE_HOST_HEADER_NAME=`"`" WEBSERVICE_LISTEN_ADDRESS=* WEBSERVICE_PORT_NUMBER=8071 LOGIXEX_DATABASE=LogixEX LOGIXEX_SERVER=${env:DB} LOGIXRT_DATABASE=LogixRT LOGIXRT_SERVER=${env:DB} LOGIXWH_DATABASE=LogixWH LOGIXWH_SERVER=${env:DB} LOGIXXS_DATABASE=LogixXS LOGIXXS_SERVER=${env:DB} REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit.txt' -Wait" | Out-File -Append -FilePath runthis.ps1
"setx /M PMDATABASE `"PrefManRT`"" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 "${TargetWSPath}\runthis.ps1"

Write-Host "Deploying the $Artifact package."
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

copy "${TargetWSPath}\unzipped\logit.txt" .

Remove-PSDrive Y

#Checking AMS App Service
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "AMS App Service not installed on $env:Target_Machine!"
}
