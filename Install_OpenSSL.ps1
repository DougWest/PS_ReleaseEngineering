if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

$RegTermTarget="OpenSSL*"
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
}

if ($DisplayName)
{
    if ($env:Target_Version -EQ $DisplayVersion){Write-Host "$DisplayName version $DisplayVersion already installed."; exit 0}
}

# Download OpenSSL
$Artifact="OpenSSL"
$ArtifactFileName = Nexus-DownloadFile -repositoryId "thirdparty" -groupId "com.slproweb" -extensionId "exe"

$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path ${TargetWSPath}${ArtifactFileName})){copy ${ArtifactFileName} ${TargetWSPath}}

"d:" | Out-File -FilePath runthis.ps1
"cd \temp" | Out-File -Append -FilePath runthis.ps1
"Start-Process ${ArtifactFileName} `"/VERYSILENT /SP /LOG=```"D:\temp\OpenSSL_Silent.log```"`" -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 ${TargetWSPath}
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1}
if (test-path ${TargetWSPath}\output0.txt){copy ${TargetWSPath}\output0.txt .}
if (test-path ${TargetWSPath}\OpenSSL_Silent.log){copy ${TargetWSPath}\OpenSSL_Silent.log .}

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "${DisplayName} version ${DisplayVersion} is installed on $env:Target_Machine."
}
else
{
    Write-Host "OpenSSL ${env:Target_Version} is not installed on $env:Target_Machine."
    exit 1
}
