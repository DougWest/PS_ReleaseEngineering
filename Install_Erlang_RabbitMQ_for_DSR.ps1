# Parameter "$env:Target_Machine" is the name of the server upon which Erlang and Rabbit are to be deployed and configured.
# Parameter "$env:Rabbit_Server" is the name of the server upon which the RabbitMQ master service is running in the environment.
# Parameter "$env:Target_Env" is the name of the environment in which this job is running - and is used to populate the .erlang.cookie file.
# Parameter "$env:Erlang_Target_Version" is the version of Erlang to install for this job. Mandated to be 19.1.
# Parameter "$env:Rabbit_Target_Version" is the version of RabbitMQ to install for this job. Mandated to be 3.6.5.

# Check parameter settings
if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine was not set!"; exit 1}
if (-NOT $env:Rabbit_Server){Write-Host "Required parameter Rabbit_Server was not set!"; exit 1}
if (-NOT $env:Target_Env){Write-Host "Required parameter Target_Env was not set!"; exit 1}
if (-NOT $env:Erlang_Target_Version){Write-Host "Required parameter Erlang_Target_Version was not set!"; exit 1}
if (-NOT $env:Rabbit_Target_Version){Write-Host "Required parameter Rabbit_Target_Version was not set!"; exit 1}
if (-NOT $env:RabbitAdminUser){Write-Host "Required parameter RabbitAdminUser was not set!"; exit 1}
if (-NOT $env:RabbitAdminPwd){Write-Host "Required parameter RabbitAdminPwd was not set!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

# Check Target_Machine connectivity
if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

$TargetWSPath=(Get-TargetWorkspace)[-1]

$RABBITMQ_BASE="D:\RabbitMQ Server"
if ("17.0" -EQ "${env:Erlang_Target_Version}"){$ERLANG_HOME="D:\Program Files\erl6.0"}
if ("19.1" -EQ "${env:Erlang_Target_Version}"){$ERLANG_HOME="D:\Program Files\erl8.1"}

# Check install status of Erlang
$RegTermTarget = "Erlang*"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
    
    Write-Host "$DisplayName version $DisplayVersion already installed."
}
else
{
    Write-Host "ErlangOTP install beginning."

    # Download Erlang package
    # Download otp_win64
    $FileName = Nexus-DownloadFile -groupId "org.erlang.otp" -artifactId "otp_win64" -versionId ${env:Erlang_Target_Version} -extensionId "exe"

    # set system level variables
    #
    Write-Host "ErlangOTP setting system variables."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {setx /M ERLANG_HOME $using:ERLANG_HOME}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {setx /M RABBITMQ_BASE $using:RABBITMQ_BASE}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {setx /M RABBITMQ_CONFIG_FILE $using:RABBITMQ_BASE"\RabbitMQ"}

    $ERLANG_HOME=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {$env:ERLANG_HOME}
    $ERLANG_HOME
    if ("" -EQ $ERLANG_HOME){echo "ERLANG_HOME not set!"; exit 1}

    # Copy package to Target_Machine
    #
    Write-Host "ErlangOTP package copying to $env:Target_Machine."
    if ("False" -EQ (test-path ${TargetWSPath}\$FileName)){copy $FileName ${TargetWSPath}}

    # Create install script file and copy to Target_Machine
    Write-Host "ErlangOTP install script creation and copy."
    "Start-Process `'$FileName`' `"/S /D=$ERLANG_HOME`" -Wait | Out-File -FilePath d:\temp\output_Erlang.txt" | Out-File -FilePath InstallErlang.ps1
    #"if ('True' -EQ (Test-Path 'C:\Windows\.erlang.cookie')){Copy-Item C:\Windows\.erlang.cookie C:\Users\Jenkins_dev_qa\.erlang.cookie}" | Out-File -Append -FilePath InstallErlang.ps1

    copy InstallErlang.ps1 ${TargetWSPath}

    # Run the script file on the Target_Machine (install the package)
    Write-Host "Invoking the Erlang script on $env:Target_Machine"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\InstallErlang.ps1; echo "Finished running the Erlang script."}

    # Copy the log file back to the workspace.
    Write-Host "ErlangOTP install copying back to workspace and displaying."
    copy "${TargetWSPath}\output_Erlang.txt" .\output_Erlang.txt
    Get-Content .\output_Erlang.txt

    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        Write-Host "ErlangOTP version ${env:Erlang_Target_Version} failed to install."
		exit 1
    }
    
    #
    # install new erlang cookie for clustering
    #
    Write-Host "Erlang create cookies for the environment."
    $Target_Env=$env:Target_Env
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {if (test-path $env:SystemRoot\.erlang.cookie){Remove-Item -force -path $env:SystemRoot\.erlang.cookie}}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {"ERLANGCOOKIEFOR$using:Target_Env" | Out-File -FilePath $env:SystemRoot\.erlang.cookie -NoNewline -Encoding Default}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {if (test-path $env:USERPROFILE\.erlang.cookie){Remove-Item -force -path $env:USERPROFILE\.erlang.cookie}}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {"ERLANGCOOKIEFOR$using:Target_Env" | Out-File -FilePath $env:USERPROFILE\.erlang.cookie -NoNewline -Encoding Default}

    }

# Check install status of RabbitMQ
$RegTermTarget = "RabbitMQ"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
    
    Write-Host "$DisplayName version $DisplayVersionalready installed."
}
else
{
    Write-Host "RabbitMQ install beginning."

    # Download RabbitMQ package
    # Download rabbitmq-server
    $FileName = Nexus-DownloadFile -groupId "com.rabbitmq" -artifactId "rabbitmq-server" -versionId "${env:Rabbit_Target_Version}" -extensionId "exe"

    #
    # Copy package to Target_Machine
    #
    Write-Host "RabbitMQ package copying to $env:Target_Machine."
    if ("False" -EQ (test-path ${TargetWSPath}\$FileName)){copy ${FileName} ${TargetWSPath}}

    Write-Host "RabbitMQ setting system variables."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {setx /M RABBITMQ_BASE $using:RABBITMQ_BASE}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {setx /M RABBITMQ_CONFIG_FILE $using:RABBITMQ_BASE"\RabbitMQ"}

    # Create install script file and copy to Target_Machine
    Write-Host "RabbitMQ install script creation and copy."
    
    ".\$FileName /S /D=$RABBITMQ_BASE\" | Out-File -FilePath InstallRabbitMQ.ps1
    "Start-Sleep -s 10" | Out-File -Append -FilePath InstallRabbitMQ.ps1
    copy InstallRabbitMQ.ps1 ${TargetWSPath}

    # Run the script file on the Target_Machine (install the package)
    Write-Host "Invoking the RabbitMQ script on $env:Target_Machine"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; echo "Running the RabbitMQ script."; .\InstallRabbitMQ.ps1; echo "Finished running the RabbitMQ script."}

    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        Write-Host "RabbitMQ version ${env:Rabbit_Target_Version} failed to install."
    }

    Write-Host "RabbitMQ getting service status."
    $iLimit=0
    While (("False" -EQ (test-path "\\$env:Target_Machine\D$\RabbitMQ Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmqctl.bat")) -AND ($iLimit -NE 10)){Start-Sleep -s 5; $iLimit=$iLimit+1}
    if ("10" -eq $iLimit){"RabbitMQ Server installation has failed!"; exit 1}
    if ("False" -EQ (test-path "\\$env:Target_Machine\D$\RabbitMQ Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmqctl.bat")){"RabbitMQ Server installation has failed!"; exit 1}
    $Rabbit_mqctl_Command="D:\RabbitMQ Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmqctl.bat"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {echo "RABBITMQ_BASE: "$RABBITMQ_BASE; echo "env:RABBITMQ_BASE: "$env:RABBITMQ_BASE; $env:ERLANG_HOME=$using:ERLANG_HOME; &$using:Rabbit_mqctl_Command status}

    $Service_Running=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {Get-Service -DisplayName "RabbitMQ" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}}
    if ("" -eq "$Service_Running") {Write-Host "RabbitMQ not running on $env:Target_Machine!"; Exit 1}
}

# Check install status of RabbitMQ before configuring.
$RegTermTarget = "RabbitMQ"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
    
    Write-Host "RabbitMQ configuration beginning."
    # Enable service and restart
    Write-Host "RabbitMQ enable service and restart."
    $Rabbit_Plugins_Command="D:\RabbitMQ` Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmq-plugins.bat"
    $Rabbit_Service_Command="D:\RabbitMQ` Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmq-service.bat"
    $Rabbit_mqctl_Command="D:\RabbitMQ` Server\rabbitmq_server-${env:Rabbit_Target_Version}\sbin\rabbitmqctl.bat"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_Plugins_Command enable rabbitmq_management}
    copy ${env:WORKSPACE}\DSR_AMS\ldaps.pem ${TargetWSPath}
    copy ${env:WORKSPACE}\DSR_AMS\RabbitMQ.config ${TargetWSPath}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; copy ldaps.pem ${RABBITMQ_BASE}\ldaps.pem}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; copy RabbitMQ.config ${RABBITMQ_BASE}\RabbitMQ.config}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_Plugins_Command enable rabbitmq_auth_backend_ldap}

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_Service_Command stop}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_Service_Command start}

    Write-Host "RabbitMQ service status."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {$env:ERLANG_HOME=$using:ERLANG_HOME; &$using:Rabbit_mqctl_Command status}

    $Service_Running=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {Get-Service -DisplayName "RabbitMQ" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}}
    if ("" -eq "$Service_Running") {Write-Host "RabbitMQ not running on $env:Target_Machine!"; Exit 1}

    # 
    # create rabbit cluster
    #
    Write-Host "RabbitMQ cluster creation."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command stop_app}
    $Rabbit_Server=$env:Rabbit_Server
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command join_cluster rabbit@$using:Rabbit_Server}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command start_app}

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command add_user $env:RabbitAdminUser $env:RabbitAdminPwd}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command set_user_tags $env:RabbitAdminUser administrator}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command set_permissions $env:RabbitAdminUser ".*" ".*" ".*"}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command set_permissions -p REI $env:RabbitAdminUser ".*" ".*" ".*"}

    Write-Host "RabbitMQ service status."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {&$using:Rabbit_mqctl_Command status}

    $Service_Running=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {Get-Service -DisplayName "RabbitMQ" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}}
    if ("" -eq "$Service_Running") {Write-Host "RabbitMQ not running on $env:Target_Machine!"; Exit 1}

}
