if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"

# 1. There was a note that these types of shares cannot be made persistent across reboots.
#    Suggest a scheduled task be defined which recreates the share (and perhaps the mount) on startup.
#    Run the scheduled task as NT Authority\System user in order to share the drive across users.
#    https://stackoverflow.com/questions/182750/map-a-network-drive-to-be-used-by-a-service/4763324#4763324
#    
'$A = New-ScheduledTaskAction -Execute "mount" -Argument "-o mtype=hard Z: \\lvaqnfs01.rei.com\export\hanfs\general\qa\pos\ams_share"' | Out-File -FilePath mountthis.ps1
'$T = New-ScheduledTaskTrigger -AtLogon' | Out-File -Append -FilePath mountthis.ps1
'$S = New-ScheduledTaskSettingsSet' | Out-File -Append -FilePath mountthis.ps1
'Register-ScheduledTask -TaskName "AMS_Mount" -Action $A -Trigger $T -Settings $S -RunLevel:Highest -User "System"' | Out-File -Append -FilePath mountthis.ps1
'Enable-ScheduledTask -TaskName "AMS_Mount"' | Out-File -Append -FilePath mountthis.ps1
'Start-ScheduledTask -TaskName "AMS_Mount"' | Out-File -Append -FilePath mountthis.ps1

$TargetWSPath=(Get-TargetWorkspace)[-1]

copy mountthis.ps1 ${TargetWSPath}

invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\mountthis.ps1; echo Finished.}

Remove-PSDrive Y
