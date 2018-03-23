if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:NCRPostgresUser){Write-Host "Required parameter NCRPostgresUser is null!"; exit 1}
if (-NOT $env:NCRPostgresPwd){Write-Host "Required parameter NCRPostgresPwd is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

$Target_Short_Version=$Target_Version.SubString(0,3)

$RegTermTarget="PostgreSQL ${Target_Short_Version}"
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

# Download PostGreSql
$Artifact="postgresql"
$ZipFileName = Nexus-DownloadFile -repositoryId "thirdparty" -groupId "org.postgresql" -classifierId "x64" -extensionId "exe"

$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path ${TargetWSPath}${ZipFileName})){copy ${ZipFileName} ${TargetWSPath}}

"d:" | Out-File -FilePath runthis.ps1
"cd \temp" | Out-File -Append -FilePath runthis.ps1
"Start-Process ${ZipFileName} `"--mode unattended --unattendedmodeui none --prefix ```"D:\Program Files\PostgreSQL\${Target_Short_Version}```" --superaccount $env:NCRPostgresUser --superpassword $env:NCRPostgresPwd --serverport 5432 --disable-stackbuilder yes`" -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"C:\Users\Jenkins_dev_qa\AppData\Local\Temp\install-postgresql.log`"){copy `"C:\Users\Jenkins_dev_qa\AppData\Local\Temp\install-postgresql.log`" .}" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 ${TargetWSPath}
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1}
if (test-path ${TargetWSPath}\output0.txt){copy ${TargetWSPath}\output0.txt .}
if (test-path ${TargetWSPath}\install-postgresql.log){copy ${TargetWSPath}\install-postgresql.log .}

invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {[Environment]::SetEnvironmentVariable( "Path", "$env:Path;D:\Program Files\PostgreSQL\${Target_Short_Version}\bin;%JAVA_HOME%\bin", [System.EnvironmentVariableTarget]::Machine )}

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "${DisplayName} version ${DisplayVersion} is installed on $env:Target_Machine."
}
else
{
    Write-Host "PostgreSQL ${env:Target_Version} is not installed on $env:Target_Machine."
    exit 1
}
