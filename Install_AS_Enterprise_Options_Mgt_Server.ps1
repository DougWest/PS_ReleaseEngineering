if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}
if (-NOT $env:WEBOFFICEID){Write-Host "Required parameter WEBOFFICEID is null!"; exit 1}
if (-NOT $env:RABBIT){Write-Host "Required parameter RABBIT is null!"; exit 1}
if (-NOT $env:SQLUser){Write-Host "Required parameter SQLUser is null!"; exit 1}
if (-NOT $env:SQLUserPW){Write-Host "Required parameter SQLUserPW is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Check the target status.
Write-Host "Checking the target service status."
$RegTermTarget="{B8AA8190-9A3D-4651-9FD7-27BB267CC9A7}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
}

if ($DisplayName)
{
    if ($env:Target_Version -EQ $DisplayVersion){Write-Host "Already installed."; exit 0}
    if ($env:Target_Version -NE $DisplayVersion){Write-Host "Version $DisplayVersion installed. Upgrade not allowed."; exit 1}
}

# Download NCR_AS_Enterprise_Server
$Artifact="NCR_AS_Server"
$ZipFileName = Nexus-DownloadFile

# Deploy the package.
Write-Host "Setting up the deployment."
$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path -path "${TargetWSPath}\unzipped")){New-Item -path "${TargetWSPath}\unzipped" -type directory}
if ("False" -EQ (test-path -path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}

# 6.8.602.2907 has a bug which forces an install to the "C:\Program File s(x86)\NCR\" path.
if ("6.8.602.2907" -EQ $env:Target_Version)
{
    $INSTALLDIR="C:\Program Files (x86)\NCR\"
}
else
{
    $INSTALLDIR="D:\Program Files (x86)\NCR\"
}
$INSTALLDIRQ="`""+$INSTALLDIR+"`""

"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"Remove-Item unzipped\*.ms?" | Out-File -Append -FilePath runthis.ps1
"Remove-Item unzipped\*.exe" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit.txt){Remove-Item logit.txt}" | Out-File -Append -FilePath runthis.ps1
"if (test-path logit2.txt){Remove-Item logit2.txt}" | Out-File -Append -FilePath runthis.ps1
if ("6.8.602.2907" -EQ $env:Target_Version)
{
    "Start-Process '.\NCR AS Server Suite.exe' '/S /v/qn /v`"SERVERTYPE=EOM`" /v`"REBOOT=ReallySuppress`" /v`"INSTALLDIR=\`"C:\Program Files (x86)\NCR\`"`" /v`"/l*v \`"d:\temp\unzipped\logit.txt\`"`"' -Wait" | Out-File -Append -FilePath runthis.ps1
}
else
{
    "Start-Process '.\NCR AS Server Suite.exe' '/S /v/qn /v`"SERVERTYPE=EOM`" /v`"REBOOT=ReallySuppress`" /v`"INSTALLDIR=\`"D:\Program Files (x86)\NCR\`"`" /v`"/l*v \`"d:\temp\unzipped\logit.txt\`"`"' -Wait" | Out-File -Append -FilePath runthis.ps1
}
"Start-Process msiexec '/i `"NCR Advanced Store Server - Customer Config Overlay.msi`" /qn INSTALLDIR=$INSTALLDIRQ WO_UNIQUE_ID=$env:WEBOFFICEID ENTERPRISESERVER=$env:DB SQLDBUSER=${env:SQLUser} SQLDBPASSWORD=${env:SQLUserPW} HTTPS_REDIRECT=false REBOOT=ReallySuppress /l*v d:\temp\unzipped\logit2.txt' -Wait" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 "${TargetWSPath}\runthis.ps1"

Write-Host "Deploying the $Artifact package."
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

copy "${TargetWSPath}\unzipped\logit.txt" .
copy "${TargetWSPath}\unzipped\logit2.txt" .

#Checking NCR Advanced Store Server Suite
Write-Host "Checking NCR Advanced Store Server Suite"
$RegTermTarget="{B8AA8190-9A3D-4651-9FD7-27BB267CC9A7}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "NCR Advanced Store Server Suite not installed on $env:Target_Machine!"; $ASSS="1"
}

#Checking NCR EOM-ETS Server
Write-Host "Checking NCR EOM-ETS Server"
$RegTermTarget="{0E74DEA8-D465-4C94-BBFE-F262AAD29C8A}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "NCR EOM-ETS Server not installed on $env:Target_Machine!"; $EES="1"
}

#Checking NCR Advanced Store Server - Customer Config Overlay
Write-Host "Checking NCR Advanced Store Server - Customer Config Overlay"
$RegTermTarget="{0E9F1AD6-CB64-41C5-AC3E-FE8FFE906E16}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
}
else
{
    Write-Host "NCR Advanced Store Server Suite - Customer Config Overlay not installed on $env:Target_Machine!"; $ASSSCCO="1"
}

if ("1" -EQ $ASSS){exit 1}
if ("1" -EQ $EES){exit 1}
if ("1" -EQ $ASSSCCO){exit 1}

if ("true" -EQ $env:RunSetup)
{
    #Configure Admin Console.
    Write-Host "Configure EOM Admin Console"
    #"Start-Process '.\AdministrationConsole.exe' '' -Wait" | Out-File -Append -FilePath cfgthis.ps1
    # Auto Starting the Remaining Services 
    "c:" | Out-File -FilePath cfgAdm.ps1
    "cd `"\ProgramData\NCR\AdvancedStore\Server\`"" | Out-File -Append -FilePath cfgAdm.ps1
    "copy store_state store_state.bak" | Out-File -Append -FilePath cfgAdm.ps1
    "(Get-Content store_state.bak).replace('6=Unknown', '6=Unknown
    [POST_BASE]
    ENABLED=YES') | Set-Content `"store_state`"" | Out-File -Append -FilePath cfgAdm.ps1
    "Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\NCRASServiceMonitor -Name Start -Value '2'" | Out-File -Append -FilePath cfgAdm.ps1
    copy cfgAdm.ps1 "${TargetWSPath}\cfgAdm.ps1"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\cfgAdm.ps1; echo "Configured Admin Console"}

    #Configure EOM
    Write-Host "Configure EOM"
    $EPWD="||~BY100000000000cMRuX6fdrTyMp6z9BM0ndA=="

    "c:" | Out-File -FilePath cfgthis.ps1
    "cd `"\ProgramData\NCR\AdvancedStore\Server\Install`"" | Out-File -Append -FilePath cfgthis.ps1
    "copy InstallSettings.xml InstallSettings.bak.xml" | Out-File -Append -FilePath cfgthis.ps1
    "(Get-Content InstallSettings.bak.xml).replace('||~BY10000000000014cjym/xliuV7PrfJpVQhw==', '$EPWD') | Set-Content `"InstallSettings.xml`"" | Out-File -Append -FilePath cfgthis.ps1
    if ("6.8.602.2907" -EQ $env:Target_Version)
    {
      "c:" | Out-File -Append -FilePath cfgthis.ps1
    }
    else
    {
      "d:" | Out-File -Append -FilePath cfgthis.ps1
    }
    "cd `"\Program Files (x86)\NCR\AdvancedStore\Bin`"" | Out-File -Append -FilePath cfgthis.ps1
    $CParam='/STRT /HIDE'
    $CParamQ="'"+$CParam+"'"
    "Start-Process '.\ASDataSetup.exe' $CParamQ -Wait" | Out-File -Append -FilePath cfgthis.ps1
    copy cfgthis.ps1 "${TargetWSPath}\cfgthis.ps1"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\cfgthis.ps1; echo "Configured-EOM"}

    #EOM Rabbit Server host configuration.
    $Rabbit="<TARGET_HOST>${env:RABBIT}</TARGET_HOST>"
    "c:" | Out-File -FilePath cfgRab.ps1
    "cd `"\ProgramData\NCR\AdvancedStore\Server\ServerParams\Default\`"" | Out-File -Append -FilePath cfgRab.ps1
    "copy EOMHostCfg.xml EOMHostCfg.bak.xml" | Out-File -Append -FilePath cfgRab.ps1
    "(Get-Content EOMHostCfg.bak.xml).replace('<TARGET_HOST>localhost</TARGET_HOST>', '$Rabbit') | Set-Content `"EOMHostCfg.xml`"" | Out-File -Append -FilePath cfgRab.ps1
    copy cfgRab.ps1 "${TargetWSPath}\cfgRab.ps1"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\cfgRab.ps1; echo "Configured EOM Rabbit host server."}
}

Remove-PSDrive Y

restart-computer -Credential $JenkinsCred -Authentication Default -computername $env:Target_Machine -force -wait -for PowerShell

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}
