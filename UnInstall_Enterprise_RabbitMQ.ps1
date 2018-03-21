if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$RegTermTarget = "RabbitMQ"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")
    
    $TargetWSPath=(Get-TargetWorkspace)[-1]

    "Start-Process `"$FileName`" /S -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "Remove-Item -Recurse -Force D:\RabbitMQ" | Out-File -Append -FilePath runthis.ps1
    "Remove-Item -Recurse -Force $env:APPDATA\RabbitMQ" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 ${TargetWSPath}

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    if (test-path ${TargetWSPath}\output0.txt){copy ${TargetWSPath}\output0.txt .}

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "RabbitMQ still installed!"; exit 1}else{Write-Host "RabbitmQ uninstalled."}

    #Remove the environment variable.
    invoke-command -ComputerName $env:Target_Machine -ScriptBlock {(new-object -com wscript.shell).environment(“system”).remove(“RABBITMQ_CONFIG_FILE”)}
    invoke-command -ComputerName $env:Target_Machine -ScriptBlock {(new-object -com wscript.shell).environment(“system”).remove(“RABBITMQ_BASE”)}
}
else
{
    Write-Host "RabbitMQ already not installed."
}

