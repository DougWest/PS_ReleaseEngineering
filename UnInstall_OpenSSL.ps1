if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$RegTermTarget = "OpenSSL*"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")
    
    $TargetWSPath=(Get-TargetWorkspace)[-1]

    "Start-Process $FileName `"/SILENT /LOG=```"D:\temp\OpenSSL_Silent_Un.log```"`"-Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1

    copy runthis.ps1 ${TargetWSPath}

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    if (test-path ${TargetWSPath}\output0.txt){copy ${TargetWSPath}\output0.txt .}
    if (test-path ${TargetWSPath}\OpenSSL_Silent_Un.log){copy ${TargetWSPath}\OpenSSL_Silent_Un.log .}

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "OpenSSL is still installed!"; exit 1}else{Write-Host "OpenSSL uninstalled."}
}
else
{
    Write-Host "OpenSSL is already not installed."
}

