if (-NOT $env:Target_Machine){echo "Parameter Target_Machine was not set!"; exit 1}
if (-NOT $env:Test_Group){$env:Test_Group="p1"}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"

$TargetWSPath=(Get-TargetWorkspace -driveShare "temp" -pathShare "")[-1]

if ("False" -EQ (test-path -Path "${TargetWSPath}\Run_Register_Test")){New-Item -path "${TargetWSPath}\Run_Register_Test" -type directory}
if ("False" -EQ (test-path -Path "${TargetWSPath}\Run_Register_Test")){Write-Host "Jenkins does not have rights to create ${TargetWSPath}\Run_Register_Test!"; exit 1}

Write-Host "Cleaning the workspace on $env:Target_Machine."
if (test-path -Path "${TargetWSPath}\Run_Register_Test\ncr-register-tests\"){del "${TargetWSPath}\Run_Register_Test\ncr-register-tests\" -Force -Recurse}
Write-Host "Workspace cleaning finished on $env:Target_Machine."

Write-Host "Creating the workspace on $env:Target_Machine."
if (test-path -path ".\ret\ncr-register-tests\"){Copy-Item -Path ".\ret\ncr-register-tests\" -Destination "${TargetWSPath}\Run_Register_Test\" -Recurse -Container}
Write-Host "Workspace creation finished on $env:Target_Machine."

$sCompileCommand="c:; cd \temp\Run_Register_Test\ncr-register-tests\; mvn clean install `-DskipTests; `$LASTEXITCODE"
$sCompileCommand
$sbCompileCommand=[Scriptblock]::Create($sCompileCommand)
$sbCompileCommand
$sCompileResult=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock $sbCompileCommand
$sCompileResult

"C:" | Out-File -FilePath testthis.ps1
"cd `"\temp\Run_Register_Test\ncr-register-tests\ncr-register-test\`"" | Out-File -Append -FilePath testthis.ps1
"Write-Host 'Running mvn test.'" | Out-File -Append -FilePath testthis.ps1
if ($env:Test_Test)
{"`$sTestResult=mvn test `-Dtest=`"$env:Test_Test`" `-Dprotocol=http `-Ddomain=$env:Target_Machine `-Dport=18080 `-Dbrowser=chrome" | Out-File -Append -FilePath testthis.ps1}
else
{"`$sTestResult=mvn test `-Dgroups=`"$env:Test_Group`" `-Dprotocol=http `-Ddomain=$env:Target_Machine `-Dport=18080 `-Dbrowser=chrome" | Out-File -Append -FilePath testthis.ps1}
"`$sMvn_LastExitCode=`$LASTEXITCODE" | Out-File -Append -FilePath testthis.ps1
"Write-Host `"Exit code is `$sMvn_LastExitCode`"" | Out-File -Append -FilePath testthis.ps1
"Write-Host (`$sTestResult `-join [Environment]::NewLine)" | Out-File -Append -FilePath testthis.ps1
"return `$sMvn_LastExitCode" | Out-File -Append -FilePath testthis.ps1

copy testthis.ps1 "${TargetWSPath}\Run_Register_Test\testthis.ps1"

Write-Host "Invoking Test Command."
$sMvn_LastExitCode=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock {c:; cd \temp\Run_Register_Test; .\testthis.ps1}

if (test-path -path "${TargetWSPath}\Run_Register_Test\ncr-register-tests\ncr-register-test\target\surefire-reports\testng-results.xml")
{
    Copy-Item "${TargetWSPath}\Run_Register_Test\ncr-register-tests\ncr-register-test\target\surefire-reports\testng-results.xml" .
} else {
    Write-Host "Test run results log not found."
}

Remove-PSDrive Y

Return $sMvn_LastExitCode

