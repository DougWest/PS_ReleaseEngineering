# Parameter "$env:Target_Machine" is the name of the server upon which Erlang is to be deployed and configured.
# Parameter "$env:Target_Env" is the name of the environment in which this job is running - and is used to populate the .erlang.cookie file.
# Parameter "$env:Erlang_Target_Version" is the version of Erlang to install for this job.

# Check parameter settings
if ("" -EQ $env:Target_Machine){echo "Parameter Target_Machine was not set!"; exit 1}
if ("" -EQ $env:Target_Env){echo "Parameter Target_Env was not set!"; exit 1}
if ("" -EQ $env:Erlang_Target_Version){echo "Parameter Erlang_Target_Version was not set!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

# Check Target_Machine connectivity
if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue)){Write-Host "Connection Failure!"; exit 1}

. "./DSR_AMS/Nexus-Download.ps1"
. "./DSR_AMS/Get-RegChild.ps1"
. "./DSR_AMS/Get-TargetWorkspace.ps1"

$RegTermTarget = "Erlang*"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
	
    Write-Host "$DisplayName version $DisplayVersion already installed."
}
else
{
    Write-Host "ErlangOTP install beginning."

    # Download Erlang package
    # Download otp_win64
    $FileName = Nexus-DownloadFile -groupId "org.erlang.otp" -artifactId "otp_win64" -versionId ${env:Erlang_Target_Version} -extensionId "exe"

    # set system level variables
    Write-Host "ErlangOTP setting system variables."
    if ("17.0" -EQ "${env:Erlang_Target_Version}"){$ERLANG_HOME="D:\Program Files\erl6.0"}
    if ("19.1" -EQ "${env:Erlang_Target_Version}"){$ERLANG_HOME="D:\Program Files\erl8.1"}
	invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {setx /M ERLANG_HOME $using:ERLANG_HOME}

    $ERLANG_HOME=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {$env:ERLANG_HOME}
    if ("" -EQ $ERLANG_HOME){echo "ERLANG_HOME not set!"; exit 1}

    $TargetWSPath=(Get-TargetWorkspace)[-1]

    # Copy package to Target_Machine
    Write-Host "ErlangOTP package copying to $env:Target_Machine."
    if ("False" -EQ (test-path ${TargetWSPath}\$FileName)){copy $FileName ${TargetWSPath}}

    # Create install script file and copy to Target_Machine
    Write-Host "ErlangOTP install script creation and copy."
    "Start-Process `'$FileName`' `"/S /D=$ERLANG_HOME`" -Wait | Out-File -FilePath d:\temp\output_Erlang.txt" | Out-File -FilePath InstallErlang.ps1
    "if ('True' -EQ (Test-Path 'C:\Windows\.erlang.cookie')){Copy-Item C:\Windows\.erlang.cookie C:\Users\Jenkins_dev_qa\.erlang.cookie}" | Out-File -Append -FilePath InstallErlang.ps1
    copy InstallErlang.ps1 ${TargetWSPath}

    # Run the script file on the Target_Machine (install the package)
    Write-Host "Invoking the Erlang script on $env:Target_Machine"
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {d:; cd \temp; .\InstallErlang.ps1; echo "Finished running the Erlang script."}

	# Copy the log file back to the workspace.
    Write-Host "ErlangOTP install copying back to workspace and displaying."
    copy ${TargetWSPath}"\output_Erlang.txt" .\output_Erlang.txt
    Get-Content .\output_Erlang.txt

    Remove-PSDrive Y

    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        Write-Host "ErlangOTP version ${env:Erlang_Target_Version} failed to install."
    }
    
    # install new erlang cookie for clustering
    Write-Host "Erlang create cookies for the environment."
	$Target_Env=$env:Target_Env
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {if (test-path $env:SystemRoot\.erlang.cookie){Remove-Item -force -path $env:SystemRoot\.erlang.cookie}}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {"ERLANGCOOKIEFOR$using:Target_Env" | Out-File -FilePath $env:SystemRoot\.erlang.cookie -NoNewline -Encoding Default}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {if (test-path $env:USERPROFILE\.erlang.cookie){Remove-Item -force -path $env:USERPROFILE\.erlang.cookie}}
    invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {"ERLANGCOOKIEFOR$using:Target_Env" | Out-File -FilePath $env:USERPROFILE\.erlang.cookie -NoNewline -Encoding Default}

	$retval=invoke-command -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ScriptBlock {Get-Process | Where-Object {$_.Name -eq 'epmd'}}
    $retval
    #if ($retval){exit 0}else{exit 1}
}