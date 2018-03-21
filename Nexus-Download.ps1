function Nexus-DownloadFile ($repositoryId, $groupId = "com.ncr", $artifactId=$Artifact, $versionId=$env:Target_Version, $classifierId, $extensionId="zip")
{
    # This function requires the environment variables: $env:Target_Version, & $Artifact
    # The environment variable $env:D2D is optional and used when downloading and deploying a D2D package.

    if (-NOT $repositoryId)
    {
        if ("com.ncr" -EQ $groupId)
        {
            if ("True" -EQ $env:D2D)
                {$repositoryId="thirdparty-snapshots"}
            else
                {$repositoryId="thirdparty"}
        }
        elseif (("org.erlang.otp" -EQ $groupId) -or ("com.rabbitmq" -EQ $groupId) -or ("com.microsoft" -EQ $groupId) -or ("org.postgresql" -EQ $groupId))
        {$repositoryId="thirdparty"}
        else
        {$repositoryId="releases"}
    }
    
    $WebClient = new-object System.Net.WebClient
    $NexusURL = "http://mvnrepos.rei.com/service/local/artifact/maven/redirect"

    # If the request is to download the LATEST version of the package, then get the pom of LATEST and pull out the version number from that pom file.
    if ("LATEST" -eq ${versionId})
    {
        $WebClient.DownloadFile("${NexusURL}?r=${repositoryId}&g=${groupId}&a=${artifactId}&v=${versionId}&e=pom","${env:WORKSPACE}\\${artifactId}.pom")
        foreach ($line in Get-Content ${env:WORKSPACE}\\${artifactId}.pom)
        {
            $line=$line.trim()
            if ($line -match ".+/version.+")
            {
                $versionId=$line.SubString(9,$line.length-19)
                #echo $thisVersion
            }
        }
    }
    
    $ArtifactFileName="${artifactId}-${versionId}.${extensionId}"
    $ArtifactFullPathName="${env:WORKSPACE}\${ArtifactFileName}"
    if (-NOT (Test-Path ${ArtifactFullPathName}))
    {
        Write-Host "Downloading the ${ArtifactFileName} package."

        if ("" -EQ ${classifierId})
        {
            $WebClient.DownloadFile("${NexusURL}?r=${repositoryId}&g=${groupId}&a=${artifactId}&v=${versionId}&e=${extensionId}",${ArtifactFullPathName})
		}
        else
        {
            $WebClient.DownloadFile("${NexusURL}?r=${repositoryId}&g=${groupId}&a=${artifactId}&v=${versionId}&c=${classifierId}&e=${extensionId}",${ArtifactFullPathName})
        }

        $iLimit=0
        While ((-NOT (Test-Path ${ArtifactFullPathName})) -AND ($iLimit -NE 10)){Start-Sleep -s 5; $iLimit=$iLimit+1}
        if (("10" -eq $iLimit) -and (-NOT (Test-Path ${ArtifactFullPathName})))
        {
            Write-Host "${artifactId} version $env:Target_Version failed to download from ${NexusURL}?r=${repositoryId}&g=${groupId}&a=${artifactId}&v=${versionId}&e=${extensionId}"
            exit 1
        }
    }
    return ${ArtifactFileName}
}
