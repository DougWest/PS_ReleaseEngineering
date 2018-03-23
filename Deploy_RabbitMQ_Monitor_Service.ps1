if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:RabbitBaseUri){Write-Host "Required parameter RabbitBaseUri is null!"; exit 1}
if (-NOT $env:RabbitUser){Write-Host "Required parameter RabbitUser is null!"; exit 1}
if (-NOT $env:RabbitPwd){Write-Host "Required parameter RabbitPwd is null!"; exit 1}
if (-NOT $env:EnvironmentPrefix){Write-Host "Required parameter EnvironmentPrefix is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

# Download RabbitMQ Monitor Service pom
$Artifact="RabbitMQMonitor"
$ZipFileName = Nexus-DownloadFile -groupId "com.rei.retail.ncr" -versionId "LATEST"

# Deploy the package.
Write-Host "Setting up the deployment."
$TargetWSPath=(Get-TargetWorkspace)[-1]

if ("False" -EQ (test-path -path "${TargetWSPath}\$ZipFileName")){copy $ZipFileName "${TargetWSPath}\$ZipFileName"}

$INSTALLDIR="D:\NCR\RabbitMQMonitor"
$INSTALLDIR_UNC="Y:\NCR\RabbitMQMonitor"
if ("False" -EQ (test-path -path $INSTALLDIR_UNC)){mkdir $INSTALLDIR_UNC}

"Add-Type -assembly `"system.io.compression.filesystem`"" | Out-File -FilePath runthis.ps1
"d:" | Out-File -Append -FilePath runthis.ps1
"cd \temp\" | Out-File -Append -FilePath runthis.ps1
"&`"`${env:Windir}\System32\sc`" query RabbitMQMonitor" | Out-File -Append -FilePath runthis.ps1
"if (`"0`" -eq `$LastExitCode){Write-Host `"RabbitMQ Monitor Services exists.`$LastExitCode`"; `$RabbitMQMonitorServiceExists=`$True; if (&`"`${env:Windir}\System32\sc`" query state= active | &`"`${env:Windir}\System32\find`" `"SERVICE_NAME: RabbitMQMonitor`"){Write-Host `"Stopping service.`"; &`"`${env:Windir}\System32\sc`" stop RabbitMQMonitor}}" | Out-File -Append -FilePath runthis.ps1
"if (test-path `"${INSTALLDIR}\RabbitMQMonitor.exe`"){Rename-Item `"${INSTALLDIR}`" RabbitMQMonitor.${env:BUILD_NUMBER}; New-Item -path `"${INSTALLDIR}`" -type directory}" | Out-File -Append -FilePath runthis.ps1
"[io.compression.zipfile]::ExtractToDirectory(`"d:\temp\${ZipFileName}`", `"${INSTALLDIR}`")" | Out-File -Append -FilePath runthis.ps1
"cd `"${INSTALLDIR}`"" | Out-File -Append -FilePath runthis.ps1
"copy RabbitMQMonitor.exe.config RabbitMQMonitor.exe.config.${env:BUILD_NUMBER}" | Out-File -Append -FilePath runthis.ps1
"`$objPropFile = Get-Content -Path `"RabbitMQMonitor.exe.config`"" | Out-File -Append -FilePath runthis.ps1
"`$objPropFile = ForEach-Object {`$objPropFile -Replace `"^.+rabbitAdminUser.+$`", `"    <add key=```"rabbitAdminUser```" value=```"$env:RabbitUser```"/>`"}" | Out-File -Append -FilePath runthis.ps1
"`$objPropFile = ForEach-Object {`$objPropFile -Replace `"^.+rabbitAdminPassword.+$`", `"    <add key=```"rabbitAdminPassword```" value=```"$env:RabbitPwd```"/>`"}" | Out-File -Append -FilePath runthis.ps1
"`$objPropFile = ForEach-Object {`$objPropFile -Replace `"^.+rabbitBaseUri.+$`", `"    <add key=```"rabbitBaseUri```" value=```"$env:RabbitBaseUri```"/>`"}" | Out-File -Append -FilePath runthis.ps1
"`$objPropFile = ForEach-Object {`$objPropFile -Replace `"^.+environmentPrefix.+$`", `"    <add key=```"environmentPrefix```" value=```"$env:EnvironmentPrefix```"/>`"}" | Out-File -Append -FilePath runthis.ps1
"Set-Content -Path `"RabbitMQMonitor.exe.config`" -Value `$objPropFile" | Out-File -Append -FilePath runthis.ps1
"if (! `$RabbitMQMonitorServiceExists){" | Out-File -Append -FilePath runthis.ps1
"    &`"`${env:Windir}\System32\sc`" create RabbitMQMonitor start=auto binPath=`"`"D:\NCR\RabbitMQMonitor\RabbitMQMonitor.exe`"`"" | Out-File -Append -FilePath runthis.ps1
"    &`"`${env:Windir}\System32\sc`" description RabbitMQMonitor `"Send Rabbit MQ Stats to Graphite`"" | Out-File -Append -FilePath runthis.ps1
"}" | Out-File -Append -FilePath runthis.ps1
"&`"`${env:Windir}\System32\sc`" start RabbitMQMonitor" | Out-File -Append -FilePath runthis.ps1

copy runthis.ps1 "${TargetWSPath}\runthis.ps1"

Write-Host "Deploying the $Artifact package."
invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

Remove-PSDrive Y
