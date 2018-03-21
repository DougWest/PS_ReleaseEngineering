if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

#Verify the DSR Enterprise Server package state.
$RegTermTarget="{569F15AE-5C62-44B6-96A1-CDEC8ECB1EEB}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    $UNCFilePath=(Get-TargetWorkspace)[-1]

    "Start-Process MsiExec.exe '/X"+$objRegChildReturn.PSChildName+" /qn' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "if (test-path 'D:\Program Files (x86)\NCR\DSREnterprise\'){Remove-Item -Recurse -Force `"D:\Program Files (x86)\NCR\DSREnterprise\`"}" | Out-File -Append -FilePath runthis.ps1
    "if (test-path 'C:\ProgramData\NCR\DSREnterprise\'){Remove-Item -Recurse -Force `"C:\ProgramData\NCR\DSREnterprise\`"}" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 $UNCFilePath

    Write-Host "Beginning uninstall of DSR Enterprise Server."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "DSR Enterprise Server still installed!"; exit 1}else{Write-Host "DSR Enterprise Server uninstalled."}

    #Verify that the service has been stopped.
    $Service_Running = (Get-Service -ComputerName $env:Target_Machine -DisplayName "Ncr.Retail.BatchApply" -ErrorAction SilentlyContinue)
    if ($Service_Running){Write-Host "Ncr.Retail.BatchApply service not uninstalled on $env:Target_Machine!"; exit 1}
}
else
{
    Write-Host "DSR Enterprise Server already not installed."
}

