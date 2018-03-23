if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:Target_UE_Version){Write-Host "Required parameter Target_UE_Version is null!"; exit 1}
if (-NOT $env:LOGIX_WEB_SERVER){Write-Host "Required parameter LOGIX_WEB_SERVER is null!"; exit 1}
if (-NOT $env:DB_SERVER){Write-Host "Required parameter DB_SERVER is null!"; exit 1}
if (-NOT $env:LOGIX_APP_SERVER){Write-Host "Required parameter LOGIX_APP_SERVER is null!"; exit 1}
if (-NOT $env:CopientLogixUser){Write-Host "Required parameter CopientLogixUser is null!"; exit 1}
if (-NOT $env:CopientLogixPwd){Write-Host "Required parameter CopientLogixPwd is null!"; exit 1}
if (-NOT $env:RabbitMQUser){Write-Host "Required parameter RabbitMQUser is null!"; exit 1}
if (-NOT $env:RabbitMQPwd){Write-Host "Required parameter RabbitMQPwd is null!"; exit 1}
if (-NOT $env:NCRPostgresUser){Write-Host "Required parameter NCRPostgresUser is null!"; exit 1}
if (-NOT $env:NCRPostgresPwd){Write-Host "Required parameter NCRPostgresPwd is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# As an effect of this next call, Y: gets mapped.
$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("6.3.0.113406_win" -EQ ${env:Target_Version})
{
# Prereqs for AMS 6.3.0
#* Windows Server 2012 R2 

# Check the install state for the prerequisite packages
#* Microsoft Visual C++ 2010 Redistributable Package (x86) (vcredist_x86.exe) (https://www.microsoft.com/en-us/download/details.aspx?id=5555)
#    HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{196BB40D-1578-3D01-B289-BEFC77A11A1E}
#      DisplayName
#      DisplayVersion
#      UninstallString
#*** OR ***
#* Microsoft Visual C++ 2013 Redistributable Package (x64) (vcredist.exe) (https://www.microsoft.com/en-us/download/details.aspx?id=5555)
#    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{7f51bdb9-ee21-49ee-94d6-90afc321780e}
#      DisplayName
#      DisplayVersion
#      UninstallString
#* OpenSSL 1.0.1h or higher, 32-bit (Win32 OpenSSL v1.0.2k) (http://slproweb.com/products/Win32OpenSSL.html )
#    HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OpenSSL*
#      DisplayName
#      DisplayVersion
#      UninstallString
#* Windows 2003 Resource Toolkit (rktools.exe) (https://www.microsoft.com/en-us/download/details.aspx?id=17657)
#    HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{FA237125-51FF-408C-8BB8-30C2B3DFFF9C}
#      DisplayName
#      DisplayVersion
#      UninstallString
#* PostgreSQL 9.6 (32–bit or 64–bit depending on the PromoDataUtl utility bit version) (https://www.enterprisedb.com/downloads/postgres-postgresql-downloads ) 
#    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PostgreSQL 9.6
#    HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PostgreSQL 9.6
#      DisplayName
#      DisplayVersion
#      UninstallString
#* Java Development Kit (JDK) 1.8 Windows (32–bit or 64–bit) (jdk-8u144-windows-x64.exe)
#    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{26A24AE4-039D-4CA4-87B4-2F64180144F0}
#      DisplayName
#      DisplayVersion
#      UninstallString 
# Headers:        MS Visual C++ 2013 Redist              OpenSSL  Windows 2003 Resource Toolkit          PostgreSQL 9.6 JDK 1.8 8u144 x64
$Target_Packages="{7f51bdb9-ee21-49ee-94d6-90afc321780e},OpenSSL*,{FA237125-51FF-408C-8BB8-30C2B3DFFF9C},PostgreSQL 9.6,{26A24AE4-039D-4CA4-87B4-2F64180144F0}"
#* WildFly 10.1.0 Final
# D:\wildfly-10.1.0.Final\*
# Can test WildFly admin console at http://localhost:9990/console/
$Wildfly_Version="wildfly-10.1.0.Final"
}
elseif ("6.1.2-P1.99738_win" -EQ ${env:Target_Version})
{
# Headers:        MS Visual C++ 2010 Redist                OpenSSL                Windows 2003 Resource Toolkit            PostgreSQL 9.6   JDK 1.8 8u144 x64
$Target_Packages=""
#* WildFly 10.0.0 Final
# D:\wildfly-10.0.0.Final\*
# Can test WildFly admin console at http://localhost:9990/console/
$Wildfly_Version="wildfly-10.0.0.Final"
}

Write-Host "Checking the target prerequisite's statii."
$arrTarget_Packages=$Target_Packages.Split(",")
foreach ($RegTermTarget in $arrTarget_Packages)
{
    Write-Host "Checking $RegTermTarget"
    $objRegChildReturn=Get-RegChild
    
    if ($objRegChildReturn)
    {
        $DisplayName=Get-ChildItemNameValue ("DisplayName")

        $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

        Write-Host "Prerequisite $DisplayName version $DisplayVersion is installed."
    }
    else
    {
        Write-Host "Prerequisite for $RegTermTarget is NOT installed! Aborting job."
        exit 1
    }
}

# Disk path check section
Write-Host "Checking WildFly."
if (Test-Path "Y:\${Wildfly_Version}\LICENSE.txt")
{
    Write-Host "${Wildfly_Version} path exists."
    $WildflyPath="D:\\${Wildfly_Version}"
}
else
{
    Write-Host "${Wildfly_Version} path does NOT exist! Aborting job."
    exit 1
}

# Check the target status for the Universal Engine
#* NCR Universal Engine,{AAAAAAAA-BBBB-CCCC-0000-111111108860}
#    HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{AAAAAAAA-BBBB-CCCC-0000-111111108860}
#      DisplayName
#      DisplayVersion
#      UninstallString
$RegTermTarget="{AAAAAAAA-BBBB-CCCC-0000-111111108860}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    if ($env:Target_UE_Version -EQ $DisplayVersion){Write-Host "$DisplayName $DisplayVersion already installed."}
}
else
{
    # Download the NCR Universal Engine package
    
    $Artifact="NCR_Universal_Engine"
    $ZipFileName = Nexus-DownloadFile -versionId $env:Target_UE_Version
    
    # Deploy the package.
    Write-Host "Deploying the $Artifact package."

    if ("False" -EQ (test-path -path "${TargetWSPath}\unzipped")){New-Item -path "${TargetWSPath}\unzipped" -type directory}
    if ("False" -EQ (test-path -path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}

    "Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
    "d:" | Out-File -Append -FilePath runthis.ps1
    "cd \temp\" | Out-File -Append -FilePath runthis.ps1
    "if (test-path `"unzipped\NCR_Universal_Engine.msi`"){del unzipped\NCR_Universal_Engine.msi}" | Out-File -Append -FilePath runthis.ps1
    "[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
    "Start-Sleep -s 5" | Out-File -Append -FilePath runthis.ps1
    "cd unzipped\" | Out-File -Append -FilePath runthis.ps1
    "Write-Host 'Beginning the install.'" | Out-File -Append -FilePath runthis.ps1
    "Start-Process msiexec '/i `"NCR_Universal_Engine.msi`" INSTALLDIR=`"D:\Program Files\NCR\AMS\`" ADDLOCAL=`"PromoDataUtl`" IOINSTALL=`"true`" SKIPIOINSTALL=`"true`" DBINSTALL=`"true`" SKIPDBINSTALL=`"true`" ENTCOMMINSTALL=`"true`" SKIPENTCOMMINSTALL=`"true`" PROMODATAUTLINSTALL=`"true`" SKIPPROMODATAUTLINSTALL=`"false`" UEDBUSER=$env:NCRPostgresUser NCRDBPASSWORD=$env:NCRPostgresPwd /qn REBOOT=ReallySuppress /l*v d:\temp\unzipped\logitUE.txt' -Wait" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 "${TargetWSPath}\runthis.ps1"

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    if (test-path "${TargetWSPath}\unzipped\logitUE.txt"){copy "${TargetWSPath}\unzipped\logitUE.txt" .}

    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        $DisplayName=Get-ChildItemNameValue ("DisplayName")

        $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

        Write-Host "$DisplayName version $DisplayVersion is installed on $env:Target_Machine."
    }
    else
    {
        Write-Host "Universal Engine not installed on $env:Target_Machine!"
        exit 1
    }
}

# Check the target status.
Write-Host "Checking the target service status."
$RegTermTarget="AMS Brokers"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")

    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")

    if ($env:Target_Version -EQ $DisplayVersion){Write-Host "Already installed."; exit 0}
}

# Download AMS_Brokers_Server
$Artifact="AMS_Brokers"
$ZipFileName = Nexus-DownloadFile

# Deploy the package.
Write-Host "Deploying the $Artifact package."

if ("False" -EQ (test-path -path "${TargetWSPath}\unzipped")){New-Item -path "${TargetWSPath}\unzipped" -type directory}
if ("False" -EQ (test-path -path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}

$Target_Machine_MAC=(invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {get-wmiobject -class "Win32_NetworkAdapterConfiguration" | Where{$_.IpEnabled -Match "True"}}).MACAddress

# Massage the properties file.
copy .\DSR_AMS\AMS_Broker_installer.properties .

$objPropFile = Get-Content -Path "AMS_Broker_installer.properties"
$objPropFile = ForEach-Object {$objPropFile -Replace "= <Hostname of the machine>", "=$env:Target_Machine"}
#$objPropFile = ForEach-Object {$objPropFile -Replace "127.0.0.1", "=$env:Target_Machine"}
$objPropFile = ForEach-Object {$objPropFile -Replace "= <Hostname of DB server>", "=$env:DB_Server"}
$objPropFile = ForEach-Object {$objPropFile -Replace "= <Hostname of Logix web server>", "=$env:LOGIX_WEB_SERVER"}
$objPropFile = ForEach-Object {$objPropFile -Replace "= <Hostname of Logix App server>", "=$env:LOGIX_APP_SERVER"}
$objPropFile = ForEach-Object {$objPropFile -Replace "= <MAC Address>", "=$Target_Machine_MAC"}
$objPropFile = ForEach-Object {$objPropFile -Replace "^WILDFLY_PATH=.+$", "WILDFLY_PATH=$WildflyPath"}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CHOSEN_INSTALL_SET=.+$", ("CHOSEN_INSTALL_SET=CUSTOM")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CHOSEN_INSTALL_FEATURE_LIST=.+$", ("CHOSEN_INSTALL_FEATURE_LIST=PDU,PromBrok,CustBrok")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^DOWNLOAD_FOLDER_PATH=.+$", ("DOWNLOAD_FOLDER_PATH=\\\\${env:Target_Machine}\\service-in")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^SERVICE_IN_FOLDER_PATH=.+$", ("SERVICE_IN_FOLDER_PATH=\\\\${env:Target_Machine}\\service-in")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^LOGIX_STUB_FOLDER_PATH=.+$", ("LOGIX_STUB_FOLDER_PATH=\\\\${env:Target_Machine}\\service-in")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^OFFER_DROP_PATH=.+$", ("OFFER_DROP_PATH=\\\\${env:Target_Machine}\\service-in")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^DIRECTORY_CACHE_PATH=.+$", ("DIRECTORY_CACHE_PATH=\\\\${env:Target_Machine}\\logix-stub")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXRT_USERNAME=.+$", ("CB_LOGIXRT_USERNAME=${env:CopientLogixUser}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXRT_PASSWORD=.+$", ("CB_LOGIXRT_PASSWORD=${env:CopientLogixPwd}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXXS_USERNAME=.+$", ("CB_LOGIXXS_USERNAME=${env:CopientLogixUser}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXXS_PASSWORD=.+$", ("CB_LOGIXXS_PASSWORD=${env:CopientLogixPwd}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXEX_USERNAME=.+$", ("CB_LOGIXEX_USERNAME=${env:CopientLogixUser}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^CB_LOGIXEX_PASSWORD=.+$", ("CB_LOGIXEX_PASSWORD=${env:CopientLogixPwd}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^RABBITMQ_USERNAME=.+$", ("RABBITMQ_USERNAME=${env:RabbitMQUser}")}
$objPropFile = ForEach-Object {$objPropFile -Replace "^RABBITMQ_PASSWORD=.+$", ("RABBITMQ_PASSWORD=${env:RabbitMQPwd}")}
#$objPropFile = ForEach-Object {$objPropFile -Replace "^something=.+$", ("something=value")}
Set-Content -Path "AMS_Broker_installer.properties" -Value $objPropFile

if (test-path "${TargetWSPath}\AMS_Broker_installer.properties"){del "${TargetWSPath}\AMS_Broker_installer.properties"}
copy ".\AMS_Broker_installer.properties" "${TargetWSPath}\AMS_Broker_installer.properties"

"Add-Type -assembly `“system.io.compression.filesystem`”" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"del unzipped\*.exe" | Out-File -Append -FilePath runthis.ps1
"del unzipped\*.properties" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$ZipFileName`", `"d:\temp\unzipped\`")" | Out-File -Append -FilePath runthis.ps1
"cd unzipped\" | Out-File -Append -FilePath runthis.ps1
"move ..\AMS_Broker_installer.properties ." | Out-File -Append -FilePath runthis.ps1
".\AMS_Brokers_Setup.exe -i silent -f .\AMS_Broker_installer.properties; Write-Host `"Installation finished.`"" | Out-File -Append -FilePath runthis.ps1
"Start-Sleep -s 60" | Out-File -Append -FilePath runthis.ps1
$ThisDate=$(Get-Date -UFormat "%m_%d_%Y_%H")
"if (test-path `"C:\Program Files\NCR\AMS Brokers\_AMS Brokers_installation\Logs\AMS_Brokers_Install_${ThisDate}_*.log`"){copy `"C:\Program Files\NCR\AMS Brokers\_AMS Brokers_installation\Logs\AMS_Brokers_Install_${ThisDate}_*.log`" .}" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 "${TargetWSPath}\runthis.ps1"

invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

if (test-path "${TargetWSPath}\unzipped\AMS_Brokers_Install_${ThisDate}_*.log"){copy "${TargetWSPath}\unzipped\AMS_Brokers_Install_${ThisDate}_*.log" .}

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
    Write-Host "AMS Broker Service not installed on $env:Target_Machine!"
    exit 1
}
