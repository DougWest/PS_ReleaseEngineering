if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}
if (-NOT $env:DB){Write-Host "Required parameter DB is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Check the target status.
Write-Host "Checking the target service status."
$RegTermTarget="'{569F15AE-5C62-44B6-96A1-CDEC8ECB1EEB}'"
$objRegChildReturn=Get-RegChild
if ($objRegChildReturn)
{
    $TargetWSPath=(Get-TargetWorkspace)[-1]

    $EPWD="YjdB3jBNo4QLrdvzw4/Elw=="

    # Add NCR Data Setup (utility for configuration) (get config from git app config repo)
    #Configure NCR Data Setup
    "D:" | Out-File -FilePath cfgthis.ps1
    "cd `"\Program Files (x86)\NCR\DSREnterprise\Utilities`"" | Out-File -Append -FilePath cfgthis.ps1
    "copy Ncr.Retail.NcrDataSetup.exe.config Ncr.Retail.NcrDataSetup.exe.bak.config2" | Out-File -Append -FilePath cfgthis.ps1
    "(Get-Content Ncr.Retail.NcrDataSetup.exe.bak.config).replace('Qt55JBR9E347x5223wae/g==', '$EPWD') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath cfgthis.ps1
    "(Get-Content Ncr.Retail.NcrDataSetup.exe.config).replace('(local)', '$env:DB') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath cfgthis.ps1
    if ("AD" -EQ $env:EOMParam)
    {
        "(Get-Content Ncr.Retail.NcrDataSetup.exe.config).replace('>SQL<', '>AD<') | Set-Content `"Ncr.Retail.NcrDataSetup.exe.config`"" | Out-File -Append -FilePath cfgthis.ps1
    }
    $CParam='/STRT /HIDE'
    $CParamQ="'"+$CParam+"'"
    "Start-Process '.\Ncr.Retail.NcrDataSetup.exe' $CParamQ -Wait" | Out-File -Append -FilePath cfgthis.ps1

    copy cfgthis.ps1 "${TargetWSPath}\cfgthis.ps1"

    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\cfgthis.ps1; echo Configured.}

    Remove-PSDrive Y
}
else
{
    Write-Host "The DSR Server is not installed on ${env:Target_Machine}."
	exit 1
}
