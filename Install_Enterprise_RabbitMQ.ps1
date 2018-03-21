# Parameter "$env:Target_Machine" is the name of the server upon which Rabbit is to be deployed and configured.
# Parameter "$env:Rabbit_Server" is the name of the server upon which the RabbitMQ master service is running in the environment.
# Parameter "$env:Rabbit_Target_Version" is the version of RabbitMQ to install for this job.

# Check parameter settings
if ("" -EQ $env:Target_Machine){echo "Parameter Target_Machine was not set!"; exit 1}
if ("" -EQ $env:Rabbit_Server){echo "Parameter Rabbit_Server was not set!"; exit 1}
if ("" -EQ $env:Rabbit_Target_Version){echo "Parameter Rabbit_Target_Version was not set!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

# Check Target_Machine connectivity
if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$TargetWSPath=(Get-TargetWorkspace)[-1]

$RegTermTarget = "RabbitMQ"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
    
    Write-Host "$DisplayName version $DisplayVersion already installed."
}
else
{
    Write-Host "RabbitMQ install beginning."

    # Download rabbitmq-server
    $FileName = Nexus-DownloadFile -groupId "com.rabbitmq" -artifactId "rabbitmq-server" -versionId "${env:Rabbit_Target_Version}" -extensionId "exe"

    # set system level variables
    Write-Host "RabbitMQ setting system variables."
    $RABBITMQ_BASE="D:\RabbitMQ Server"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {setx /M RABBITMQ_BASE "$using:RABBITMQ_BASE"}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {setx /M RABBITMQ_CONFIG_FILE "$using:RABBITMQ_BASE\RabbitMQ"}

    $tRABBITMQ_BASE=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {$env:$RABBITMQ_BASE}
    if ("" -EQ $tRABBITMQ_BASE){echo "RABBITMQ_BASE not set!"; exit 1}

    # Copy package to Target_Machine
    Write-Host "RabbitMQ package copying to $env:Target_Machine."
    if ("False" -EQ (test-path ${TargetWSPath}\$FileName)){copy $FileName ${TargetWSPath}}

    # Create install script file and copy to Target_Machine
    Write-Host "RabbitMQ install script creation and copy."
    "Start-Process $FileName `"/S /D="+'$env:RABBITMQ_BASE'+"`" -Wait | Out-File -FilePath d:\temp\output_RabbitMQ.txt" | Out-File -FilePath InstallRabbitMQ.ps1
    copy InstallRabbitMQ.ps1 ${TargetWSPath}

    # Run the script file on the Target_Machine (install the package)
    Write-Host "Invoking the RabbitMQ script on $env:Target_Machine"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {d:; cd \temp; .\InstallRabbitMQ.ps1}

	# Copy the log file back to the workspace.
    Write-Host "RabbitMQ install copying back to workspace and displaying."
    copy ${TargetWSPath}"\output_RabbitMQ.txt" .\output_RabbitMQ.txt
    Get-Content .\output_RabbitMQ.txt

    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        Write-Host "RabbitMQ version ${env:Rabbit_Target_Version} failed to install."
    }

    $retval=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {d:; cd RabbitMQ\rabbitmq_server-3.6.5\sbin; .\rabbitmqctl.bat status}
    $retval
    $Service_Running=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {Get-Service -DisplayName "RabbitMQ" -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq "Running"}}
    if ("" -eq "$Service_Running") {Write-Host "RabbitMQ not running on $env:Target_Machine!"; Exit 1}
}