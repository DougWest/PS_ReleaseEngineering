if (-NOT ${env:Target_Machine}){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"

$TargetWSPath=(Get-TargetWorkspace)[-1]

if (test-path "${TargetWSPath}\SQL_Output.txt"){Remove-Item -path "${TargetWSPath}\SQL_Output.txt"}

"d:" | Out-File -FilePath runsql.ps1
"cd \temp\" | Out-File -Append -FilePath runsql.ps1

# Need to rebase the sql drives for the Auto environment.
$E_DRIVE="E:\"
$L_DRIVE="L:\"
if ("WLVBD8DSRA01" -eq ${env:Target_Machine})
{
    $E_DRIVE="D:\MapDrives\E\"
    $L_DRIVE="D:\MapDrives\L\"
    (Get-Content ..\..\ret\ncr-db-server\AMS_DB_login_creation.sql).replace('E:\', ${E_DRIVE}) | Set-Content "..\..\ret\ncr-db-server\AMS_DB_login_creation.sql"
    (Get-Content ..\..\ret\ncr-db-server\AMS_DB_login_creation.sql).replace('L:\', ${L_DRIVE}) | Set-Content "..\..\ret\ncr-db-server\AMS_DB_login_creation.sql"
}

$E_PATH="${E_DRIVE}SQLDATA\MSSQL12.MSSQLSERVER\MSSQL\DATA\"
"if (test-path ${E_DRIVE}){" | Out-File -Append -FilePath runsql.ps1
"if (! (test-path $E_PATH)){mkdir $E_PATH}" | Out-File -Append -FilePath runsql.ps1
"if (! (test-path $E_PATH)){Write-Host `"Jenkins_dev_qa does not have rights to create $E_PATH!`"; exit 1}" | Out-File -Append -FilePath runsql.ps1
"Write-Host `"$E_PATH exists.`"" | Out-File -Append -FilePath runsql.ps1
"}else{" | Out-File -Append -FilePath runsql.ps1
"Write-Host '${E_DRIVE} does not exist! Aborting.'; exit 1}" | Out-File -Append -FilePath runsql.ps1
$L_PATH="${L_DRIVE}SQLLogs\"
"if ( test-path ${L_DRIVE}){" | Out-File -Append -FilePath runsql.ps1
"if (! (test-path $L_PATH)){mkdir $L_PATH}" | Out-File -Append -FilePath runsql.ps1
"if (! (test-path $L_PATH)){Write-Host `"Jenkins_dev_qa does not have rights to create $L_PATH!`"; exit 1}" | Out-File -Append -FilePath runsql.ps1
"Write-Host `"$L_PATH exists.`"" | Out-File -Append -FilePath runsql.ps1
"}else{" | Out-File -Append -FilePath runsql.ps1
"Write-Host '${L_DRIVE} does not exist! Aborting.'; exit 1}" | Out-File -Append -FilePath runsql.ps1

"sqlcmd -U $env:SQLUser -P $env:SQLUserPW -S ${env:Target_Machine} -i AMS_DB_login_creation.sql > SQL_Output.txt" | Out-File -Append -FilePath runsql.ps1

Copy-Item runsql.ps1 "${TargetWSPath}\runsql.ps1"
Copy-Item ..\..\ret\ncr-db-server\AMS_DB_login_creation.sql "${TargetWSPath}\AMS_DB_login_creation.sql"

# Run the target script.
Write-Host "Run the target script."
$ThisExitCode=(invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {d:; cd \temp; .\runsql.ps1; return $LastExitCode})[-1]

Write-Host "Test for and copy back and output the SQL Output file."
if (test-path "${TargetWSPath}\SQL_Output.txt")
{
    Copy-Item "${TargetWSPath}\SQL_Output.txt" .
    # Write the target output
    Write-Host "Writing the target output."
    Get-Content -path SQL_Output.txt
}
else
{
    Write-Host "SQL_Output.txt file did not exist!"
}

Remove-PSDrive Y

if ("0" -NE $ThisExitCode){Write-Host "The target script exited with `"$ThisExitCode`""; exit $ThisExitCode}
