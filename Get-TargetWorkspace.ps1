Function Get-TargetWorkspace ($driveShare = "D$", $pathShare = "\temp")
{
$PSDDrive = "\\${env:Target_Machine}\${driveShare}"
$TargetRootPath = "Y:${pathShare}"

if (Net Use | Select-String "${env:Target_Machine}")
{
    net use \\$env:Target_Machine\${driveShare} /delete
}
New-PSDrive -Name Y -PSProvider filesystem -Root "${PSDDrive}" -Credential ${JenkinsCred} -Scope Global

if ("False" -EQ (test-path ${TargetRootPath}))
{
    New-Item -path ${TargetRootPath} -type directory
    if ("False" -EQ (test-path ${TargetRootPath}))
	{
	    Write-Host "Jenkins does not have rights to create ${TargetRootPath}!"
		exit 1
	}
}

return ${TargetRootPath}
}