if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:Target_Version){Write-Host "Required parameter Target_Version is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}
if (-NOT $env:CopientLogixUser){Write-Host "Required parameter CopientLogixUser is null!"; exit 1}
if (-NOT $env:CopientLogixPwd){Write-Host "Required parameter CopientLogixPwd is null!"; exit 1}

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

if (! $DisplayName)
{
    Write-Host "No DSR Enterprise Messaging Server found on ${env:Target_Machine}. Exiting."
    exit 1
}

$UNCFilePath=(Get-TargetWorkspace)[-1]

$INSTALLDIR="D:\Program Files (x86)\NCR\DSREnterprise\"
$INSTALLDIR_UNC="Y:\Program Files (x86)\NCR\DSREnterprise\"

# Configure the Rabbit Service
Write-Host "Configuring the Rabbit Service script."
$ApplyFilePath="${env:WORKSPACE}/ret/ncr_config/Enterprise/AdvancedStore/DepartmentSpecialityRetail/DSR-Msg/"
$ApplyFileName="REIRabbitMQEnterpriseSetup.xml"
if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
Write-Host "Copy $ApplyFileName to ${INSTALLDIR_UNC}Utilities\"
copy "${ApplyFilePath}${ApplyFileName}" "${INSTALLDIR_UNC}Utilities\"

$PSFile="configRabbitMQ.ps1"
"d:" | Out-File -FilePath ${PSFile}
"cd `"${INSTALLDIR}Utilities\`"" | Out-File -Append -FilePath ${PSFile}
"if (-NOT (test-path `$env:USERPROFILE\.erlang.cookie)){Copy-Item `$env:SystemRoot\.erlang.cookie `$env:USERPROFILE\.erlang.cookie}" | Out-File -Append -FilePath ${PSFile}
"copy RabbitMQEnterprisePlugins.xml RabbitMQEnterprisePlugins.bak.xml" | Out-File -Append -FilePath ${PSFile}
"(Get-Content RabbitMQEnterprisePlugins.xml).replace('enable rabbitmq_shovel', 'disable rabbitmq_shovel') | Set-Content `"RabbitMQEnterprisePlugins.xml`"" | Out-File -Append -FilePath ${PSFile}
"(Get-Content RabbitMQEnterprisePlugins.xml).replace('enable rabbitmq_shovel_management', 'disable rabbitmq_shovel_management') | Set-Content `"RabbitMQEnterprisePlugins.xml`"" | Out-File -Append -FilePath ${PSFile}
".\Ncr.Retail.Platform.Setup.RabbitMQ.exe `"RabbitMQEnterprisePlugins.xml`" `"`${env:RABBITMQ_BASE}\rabbitmq_server-3.6.5\sbin`"" | Out-File -Append -FilePath ${PSFile}
# Only on primary cluster server
if ("true" -EQ $env:PrimaryServer)
{
    ".\Ncr.Retail.Platform.Setup.RabbitMQ.exe `"RabbitMQEnterpriseSetup.xml`" `"`${env:RABBITMQ_BASE}\rabbitmq_server-3.6.5\sbin`"" | Out-File -Append -FilePath ${PSFile}
    ".\Ncr.Retail.Platform.Setup.RabbitMQ.exe `"${ApplyFileName}`" `"`${env:RABBITMQ_BASE}\rabbitmq_server-3.6.5\sbin`"" | Out-File -Append -FilePath ${PSFile}
}
copy "${env:WORKSPACE}\ri\ncr\DSR_AMS\exchange.ps1" "${UNCFilePath}"
copy "${env:WORKSPACE}\ri\ncr\DSR_AMS\queue.ps1" "${UNCFilePath}"
copy "${env:WORKSPACE}\ri\ncr\DSR_AMS\bind.ps1" "${UNCFilePath}"
"cd \temp" | Out-File -Append -FilePath ${PSFile}
". .\exchange.ps1" | Out-File -Append -FilePath ${PSFile}
". .\queue.ps1" | Out-File -Append -FilePath ${PSFile}
". .\bind.ps1" | Out-File -Append -FilePath ${PSFile}

Write-Host "Copy RabbitMQ config script to ${UNCFilePath}"
copy ${PSFile} "${UNCFilePath}\${PSFile}"

Write-Host "Running Rabbit Service configuration script."
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd "D:\temp\"; . .\${using:PSFile}}

#New EOMData Configuration files.
#Perform only on PrimaryServer
if ("true" -EQ $env:PrimaryServer)
{
    $arrVersions=${env:Target_Version}.Split(".")
    if (([int]"6" -le [int]$arrVersions[0]) -and ([int]"8" -le [int]$arrVersions[1]) -and ([int]"904" -le [int]$arrVersions[2]))
    {
        if ([int]"1217" -le [int]$arrVersions[2])
        {
            $EOMRepo="thirdparty"
            $EOMDataVersion = "6.8-R10-PI5-SP1"
        }
        elseif ([int]"1215" -le [int]$arrVersions[2])
        {
            $EOMRepo="thirdparty"
            $EOMDataVersion = "6.8-R10-PI5"
        }
        elseif ([int]"1008" -le [int]$arrVersions[2])
        {
            $EOMRepo="thirdparty"
            $EOMDataVersion = "6.8-PI4"
        }
        elseif ([int]"904" -le [int]$arrVersions[2])
        {
            $EOMRepo="thirdparty-snapshots"
            $EOMDataVersion = "6.8-PI3"
        }
        else
        {
            Write-Host "EOMData version failure in script!"
            exit 1
        }

        $EOMDataFileName = Nexus-DownloadFile -repositoryId $EOMRepo -artifactId "EOMData" -versionId $EOMDataVersion

        if ("True" -EQ (test-path "$UNCFilePath\unzipped\EOMData")){Remove-Item "$UNCFilePath\unzipped\EOMData" -Recurse -Force}
        if ("False" -EQ (test-path "$UNCFilePath\$EOMDataFileName")){copy "${env:WORKSPACE}\$EOMDataFileName" "$UNCFilePath\$EOMDataFileName"}
        if ("False" -EQ (test-path "$UNCFilePath\unzipped\EOMData")){mkdir "$UNCFilePath\unzipped\EOMData"}
        $PSFile="eomconfig.ps1"
        if ("True" -EQ (test-path "$UNCFilePath\${PSFile}")){Remove-Item "$UNCFilePath\${PSFile}" -Recurse -Force}
        Write-Host "Downloading the EOMData Config Files"
        "Add-Type -assembly `"system.io.compression.filesystem`"" | Out-File -FilePath ${PSFile}
        "d:" | Out-File -Append -FilePath ${PSFile}
        "cd \temp\" | Out-File -Append -FilePath ${PSFile}
        "if (test-path logit.txt){del logit.txt}" | Out-File -Append -FilePath ${PSFile}
        "[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\$EOMDataFileName`", `"d:\temp\unzipped\EOMData\`")" | Out-File -Append -FilePath ${PSFile}
        "cd unzipped\EOMData" | Out-File -Append -FilePath ${PSFile}
        # In POS.ActiveDirUsers.Mapping.xml & Server.ActiveDirUsers.Mapping.xml replace "Administrator,Cashier,Manager,Other,Supervisor" with "APP_EOM_NOP_Admin" and for prod "APP_EOM_PRD_Admin"
        "(Get-Content POS.ActiveDirUsers.Mapping.xml).replace('Administrator,Cashier,Manager,Other,Supervisor', '$env:APP_EOM_Permissions') | Set-Content `"POS.ActiveDirUsers.Mapping.xml`"" | Out-File -Append -FilePath ${PSFile}
        "(Get-Content Server.ActiveDirUsers.Mapping.xml).replace('Administrator,Cashier,Manager,Other,Supervisor', '$env:APP_EOM_Permissions') | Set-Content `"Server.ActiveDirUsers.Mapping.xml`"" | Out-File -Append -FilePath ${PSFile}
        "if (! (test-path 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\DefaultData\')){" | Out-File -Append -FilePath ${PSFile}
        "mkdir 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\DefaultData\'}" | Out-File -Append -FilePath ${PSFile}
        "copy .\* 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\DefaultData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\POS.ActiveDirUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\POS.AssociateUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\Server.ActiveDirUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\Server.AssociateUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\Databases\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\POS.ActiveDirUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\SampleBatch\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\POS.AssociateUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\SampleBatch\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\Server.ActiveDirUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\SampleBatch\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        "copy .\Server.AssociateUsers.Mapping.xml 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\SampleBatch\EOMData\'" | Out-File -Append -FilePath ${PSFile}
        copy ${PSFile} "$UNCFilePath\${PSFile}"

        Write-Host "Running EOMData overlay."
        invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; . .\${using:PSFile}}
    }
    else
    {
        Write-Host "New EOMData configuration is for version PI3 and above"
        # In POS.ActiveDirUsers.Mapping.xml & Server.ActiveDirUsers.Mapping.xml replace "Administrator,Cashier,Manager,Other,Supervisor" with "AP_EOM_NOP_Admin" and for prod "AP_EOM_PRD_Admin"
        $PSFile="eomconfig.ps1"
        if ("True" -EQ (test-path "$UNCFilePath\${PSFile}")){Remove-Item "$UNCFilePath\${PSFile}" -Recurse -Force}
        "d:" | Out-File -FilePath ${PSFile}
        "cd 'd:\Program Files (x86)\NCR\DSREnterprise\Utilities\SampleBatch\EOMData'" | Out-File -Append -FilePath ${PSFile}
        # In POS.ActiveDirUsers.Mapping.xml & Server.ActiveDirUsers.Mapping.xml replace "Administrator,Cashier,Manager,Other,Supervisor" with "APP_EOM_NOP_Admin" and for prod "APP_EOM_PRD_Admin"
        "(Get-Content POS.ActiveDirUsers.Mapping.xml).replace('Administrator,Cashier,Manager,Other,Supervisor', '$env:APP_EOM_Permissions') | Set-Content `"POS.ActiveDirUsers.Mapping.xml`"" | Out-File -Append -FilePath ${PSFile}
        "(Get-Content Server.ActiveDirUsers.Mapping.xml).replace('Administrator,Cashier,Manager,Other,Supervisor', '$env:APP_EOM_Permissions') | Set-Content `"Server.ActiveDirUsers.Mapping.xml`"" | Out-File -Append -FilePath ${PSFile}
        copy ${PSFile} "$UNCFilePath\${PSFile}"

        Write-Host "Running ActiveDirUsers overlay."
        invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; . .\${using:PSFile}}
    }
}

# Add NCR Data Setup (utility for configuration) (get config from git app config repo)
#Configure NCR Data Setup
# Only on primary cluster server
if ("true" -EQ $env:PrimaryServer)
{
    $EPWD="YjdB3jBNo4QLrdvzw4/Elw=="

    $PSFile="cfgNCRDataSetup.ps1"
    "D:" | Out-File -FilePath ${PSFile}
    "cd `"\Program Files (x86)\NCR\DSREnterprise\Utilities`"" | Out-File -Append -FilePath ${PSFile}
    "copy Ncr.Retail.NcrDataSetup.exe.config Ncr.Retail.NcrDataSetup.exe.bak.config" | Out-File -Append -FilePath ${PSFile}
    #      <SQLInstance uiInfo="SQL Server instance">$env:DB</SQLInstance>
    #      <UseWindowsAuthentication>false</UseWindowsAuthentication>
    #      <SqlUserName>$env:CopientLogixUser</SqlUserName>
    #      <SqlPassword>$env:CopientLogixPwd</SqlPassword>
    "(Get-Content Ncr.Retail.NcrDataSetup.exe.config) -replace '<SQLInstance uiInfo=`"SQL Server instance`">.*</SQLInstance>', '<SQLInstance uiInfo=`"SQL Server instance`">$env:DB</SQLInstance>
      <UseWindowsAuthentication>false</UseWindowsAuthentication>
      <SqlUserName>$env:CopientLogixUser</SqlUserName>
      <SqlPassword>$env:CopientLogixPwd</SqlPassword>' | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath ${PSFile}
    #      <AppSQLPwd uiInfo="SQL Server App user login password" uiType="password">$EPWD</AppSQLPwd>
    "(Get-Content Ncr.Retail.NcrDataSetup.exe.config).replace('Qt55JBR9E347x5223wae/g==', '$EPWD') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath ${PSFile}
    if ("AD" -EQ $env:EOMParam)
    {
        "(Get-Content Ncr.Retail.NcrDataSetup.exe.config).replace('>SQL<', '>AD<') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath ${PSFile}
    }
    # Need to rebase the sql drives for the Auto environment.
    $E_DRIVE="E:\"
    $L_DRIVE="L:\"
    if ("WLVBD8DSRA01" -eq ${env:Target_Machine})
    {
        $E_DRIVE="D:\MapDrives\E\"
        $L_DRIVE="D:\MapDrives\L\"
    }

    $E_PATH="${E_DRIVE}SQLDATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\"
    $L_PATH="${L_DRIVE}SQLLogs\"
    "(Get-Content Ncr.Retail.NcrDataSetup.exe.config).replace('<CustomData>', '<CustomData>
      <Database id=`"EOMData`">
        <Setting name=`"dbDataFileName`">${E_PATH}EOMData_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}EOMData_log.ldf</Setting>
      </Database>
      <Database id=`"TrustedCustomer`">
        <Setting name=`"dbDataFileName`">${E_PATH}TrustedCustomer_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}TrustedCustomer_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_EJ`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_EJ_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_EJ_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_Transactions`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_Transactions_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_Transactions_log.ldf</Setting>
      </Database>
      <Database id=`"CoreDb`">
        <Setting name=`"dbDataFileName`">${E_PATH}CoreDb_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}CoreDb_log.ldf</Setting>
      </Database>
      <Database id=`"ProductDb`">
        <Setting name=`"dbDataFileName`">${E_PATH}ProductDb_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}ProductDb_log.ldf</Setting>
      </Database>
      <Database id=`"TransactionLogDb`">
        <Setting name=`"dbDataFileName`">${E_PATH}TransactionLogDb_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}TransactionLogDb_log.ldf</Setting>
      </Database>
      <Database id=`"Associate`">
        <Setting name=`"dbDataFileName`">${E_PATH}Associate_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}Associate_log.ldf</Setting>
      </Database>
      <Database id=`"RTEStoreManagersDesktop`">
        <Setting name=`"dbDataFileName`">${E_PATH}RTEStoreManagersDesktop_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}RTEStoreManagersDesktop_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_FlexWikiSqlStore`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_FlexWikiSqlStore_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_FlexWikiSqlStore_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_LogDB`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_LogDB_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_LogDB_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_Options`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_Options_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_Options_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_Transport`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_Transport_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_Transport_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_Reports`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_Reports_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_Reports_log.ldf</Setting>
      </Database>
      <Database id=`"NCRWO_WebOfficeSE`">
        <Setting name=`"dbDataFileName`">${E_PATH}NCRWO_WebOfficeSE_data.mdf</Setting>
        <Setting name=`"dbLogFileName`">${L_PATH}NCRWO_WebOfficeSE_log.ldf</Setting>
      </Database>') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath ${PSFile}

    $CParam='/STRT /HIDE'
    $CParamQ="'"+$CParam+"'"
    "Start-Process '.\Ncr.Retail.NcrDataSetup.exe' $CParamQ -Wait" | Out-File -Append -FilePath ${PSFile}
    "Get-Content 'NcrDataSetup.out'" | Out-File -Append -FilePath ${PSFile}

    copy ${PSFile} "$UNCFilePath\${PSFile}"

    Write-Host "Running Ncr.Retail.NcrDataSetup"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; . .\${using:PSFile}}
}

Remove-PSDrive Y
