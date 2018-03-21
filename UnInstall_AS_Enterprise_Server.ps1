if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$UNCFilePath=(Get-TargetWorkspace)[-1]

#Verify the NCR Advanced Store Server - Customer Config Overlay package state.
$RegTermTarget="{0E9F1AD6-CB64-41C5-AC3E-FE8FFE906E16}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    "Start-Process MsiExec.exe '/X"+$objRegChildReturn.PSChildName+" /qn' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1

    copy runthis.ps1 $UNCFilePath

    Write-Host "Beginning uninstall of NCR Advanced Store Server - Customer Config Overlay."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "NCR Advanced Store Server - Customer Config Overlay still installed!"; exit 1}else{Write-Host "NCR Advanced Store Server - Customer Config Overlay uninstalled."}
}
else
{
    Write-Host "NCR Advanced Store Server - Customer Config Overlay already not installed."
}


#Verify the NCR EOM-ETS Server package state.
$RegTermTarget="{0E74DEA8-D465-4C94-BBFE-F262AAD29C8A}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    "Start-Process MsiExec.exe '/X"+$objRegChildReturn.PSChildName+" /qn' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "if (test-path 'D:\Program Files (x86)\NCR\WebOffice\'){Remove-Item -Recurse -Force `"D:\Program Files (x86)\NCR\WebOffice\`"}" | Out-File -Append -FilePath runthis.ps1
    "if (test-path 'C:\ProgramData\NCR\'){Remove-Item -Recurse -Force `"C:\ProgramData\NCR\`"}" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 $UNCFilePath

    Write-Host "Beginning uninstall of NCR EOM-ETS Server."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "NCR EOM-ETS Server application still installed!"; exit 1}else{Write-Host "NCR EOM-ETS Server Uninstalled."}
}
else
{
    Write-Host "NCR EOM-ETS Server already not installed."
}


#Verify the NCR Advanced Store Server Suite package state.
$RegTermTarget="{B8AA8190-9A3D-4651-9FD7-27BB267CC9A7}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    "Start-Process MsiExec.exe '/X"+$objRegChildReturn.PSChildName+" /qn' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "if (test-path 'D:\Program Files (x86)\NCR\AdvancedStore\'){Remove-Item -Recurse -Force `"D:\Program Files (x86)\NCR\AdvancedStore\`"}" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 $UNCFilePath

    Write-Host "Beginning uninstall of NCR Advanced Store Server Suite."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "NCR Advanced Store Server Suite still installed!"; exit 1}else{Write-Host "NCR Advanced Store Server Suite Uninstalled."}
}
else
{
    Write-Host "NCR Advanced Store Server Suite already not installed."
}

Remove-PSDrive Y

