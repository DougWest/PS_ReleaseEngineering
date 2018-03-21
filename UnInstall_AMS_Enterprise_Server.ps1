if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$RegTermTarget="{AAAAAAAA-BBBB-CCCC-0000-111111199697}"

#Verify the package state.
$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    $TargetWSPath=(Get-TargetWorkspace)[-1]

    "Start-Process MsiExec.exe '/X"+$objRegChildReturn.PSChildName+" /qn /l*v d:\temp\Logix_Uninst.log' -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "if (test-path 'C:\ProgramData\NCR_AMS\'){Remove-Item -Recurse -Force `"C:\ProgramData\NCR_AMS\`"}" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 ${TargetWSPath}

    Write-Host "Beginning uninstall of AMS Enterprise Server."
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    copy "${TargetWSPath}\output0.txt" "."
    copy "${TargetWSPath}\Logix_Uninst.log" "."

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "AMS Enterprise Server still installed!"; exit 1}else{Write-Host "AMS Enterprise Server uninstalled."}
}
else
{
    Write-Host "AMS Enterprise Server already not installed."
}

