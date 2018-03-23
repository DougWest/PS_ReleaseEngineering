if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$RegTermTarget="AMS Brokers"

#Verify the package state.
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    $TargetWSPath=(Get-TargetWorkspace)[-1]

    "d:" | Out-File -FilePath runthis.ps1
    "cd \temp\" | Out-File -Append -FilePath runthis.ps1
    "Start-Process $FileName '-i silent' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -Append -FilePath runthis.ps1
    "Start-Sleep -s 60" | Out-File -Append -FilePath runthis.ps1
    $ThisDate=$(Get-Date -UFormat "%m_%d_%Y_%H")
    "if (test-path `"C:\Program Files\NCR\AMS Brokers\_AMS Brokers_installation\Logs\AMS_Brokers_Uninstall_${ThisDate}_*.log`"){copy `"C:\Program Files\NCR\AMS Brokers\_AMS Brokers_installation\Logs\AMS_Brokers_Uninstall_${ThisDate}_*.log`" .}" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 ${TargetWSPath}

    Write-Host "Beginning uninstall of AMS Enterprise Broker Server."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    if (test-path "${TargetWSPath}\AMS_Brokers_Uninstall_${ThisDate}_*.log"){copy "${TargetWSPath}\AMS_Brokers_Uninstall_${ThisDate}_*.log" .}

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn){Write-Host "AMS Enterprise Broker Server still installed!"; exit 1}else{Write-Host "AMS Enterprise Broker Server uninstalled."}
}
else
{
    Write-Host "AMS Enterprise Broker Server already not installed."
}
