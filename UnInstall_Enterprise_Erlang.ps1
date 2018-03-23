if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

$RegTermTarget = "Erlang*"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    #Uninstall the package.
    $FileName=Get-ChildItemNameValue ("UninstallString")

    $TargetWSPath=(Get-TargetWorkspace)[-1]

    "Start-Process `"$FileName`" /S -Wait | Out-File -FilePath d:\temp\output0.txt" | Out-File -FilePath runthis.ps1
    "if (Get-Process | Where-Object {`$_.Name -eq 'epmd'}){Stop-Process -Name 'epmd' -Force -confirm:`$false}" | Out-File -Append -FilePath runthis.ps1
    "if ((test-path C:\Windows\.erlang.cookie)){Remove-Item -Force C:\Windows\.erlang.cookie}" | Out-File -Append -FilePath runthis.ps1
    "if ((test-path C:\Users\Jenkins_dev_qa\.erlang.cookie)){Remove-Item -Force C:\Users\Jenkins_dev_qa\.erlang.cookie}" | Out-File -Append -FilePath runthis.ps1
    "Remove-Item -Recurse -Force 'D:\Program Files\erl8.1'" | Out-File -Append -FilePath runthis.ps1

    copy runthis.ps1 ${TargetWSPath}

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runthis.ps1; echo Finished.}

    copy "${TargetWSPath}\output0.txt" "."

    Remove-PSDrive Y

    #Verify that the package is uninstalled.
    $objRegChildReturn=Get-RegChild
    if ($objRegChildReturn){Write-Host "Erlang still installed!"; exit 1}else{Write-Host "Erlang uninstalled."}

    #Remove the environment variable.
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {(new-object -com wscript.shell).environment("system").remove("ERLANG_HOME")}
}
else
{
    Write-Host "Erlang already not installed."
}

