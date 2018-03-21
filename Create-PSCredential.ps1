if (-NOT $JenkinsCred)
{
    if (-NOT $env:JenkinsUser){Write-Host "Required parameter JenkinsUser is null!"; exit 1}
    if (-NOT $env:JenkinsPwd){Write-Host "Required parameter JenkinsPwd is null!"; exit 1}

    $SJenkinsPwd = ConvertTo-SecureString "$env:JenkinsPwd" -AsPlainText -Force
    $JenkinsCred = New-Object System.Management.Automation.PSCredential ("$env:JenkinsUser", $SJenkinsPwd)

    if (-NOT $JenkinsCred){Write-Host "Required parameter JenkinsCred is null!"; exit 1}
}
