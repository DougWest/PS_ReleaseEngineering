if (-NOT $env:DSR_Web_Server){Write-Host "Required parameter DSR_Web_Server is null!"; exit 1}
if (-NOT $env:DSR_App_Server){Write-Host "Required parameter DSR_App_Server is null!"; exit 1}
if (-NOT $env:DB_Server){Write-Host "Required parameter DB_Server is null!"; exit 1}
if (-NOT $env:IDL_type){Write-Host "Required parameter for file upload type is null!"; exit 1}
if (-NOT $env:orgName){Write-Host "Required parameter for orgName is null!"; exit 1}
if (-NOT $env:SQLUser){Write-Host "Required parameter SQLUser is null!"; exit 1}

. "./DSR_AMS/Create-PSCredential.ps1"

if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:DSR_App_Server} -ErrorAction:SilentlyContinue)){Write-Host "${env:DSR_App_Server}Connection Failure!"; exit 1}
if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:DB_Server} -ErrorAction:SilentlyContinue)){Write-Host "${env:DB_Server} Connection Failure!"; exit 1}

. "./DSR_AMS/Get-TargetWorkspace.ps1"
. "./DSR_AMS/Get-RegChild.ps1"

# Check the target DSR App service status.
Write-Host "Checking the target app service status."
$env:Target_Machine=${env:DSR_App_Server}
$RegTermTarget="{569F15AE-5C62-44B6-96A1-CDEC8ECB1EEB}"

$objRegChildReturn=Get-RegChild

if ($objRegChildReturn)
{
    $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
}

# 2.	File data preparation 
$UploadPath=(Get-TargetWorkspace -driveShare "C$" -pathShare "\ProgramData\NCR\RetailOne\Enterprise\BatchApply\UploadFiles\")[-1]

$ApplyFilePath="${env:WORKSPACE}/ret/batchapplyscriptsforinitialload/"
if ("Taxonomy" -eq $env:IDL_type)
{
  $fileType="taxonomy"
  $SHORT_NAME="Auto_IDL_PS_Ty"
  $batchId = "IDL_Ty_${env:BUILD_NUMBER}"
  $ApplyFileName="add_enterprise_taxonomy.json"
  $UploadFile="add_enterprise_taxonomy_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $fileCount="1"
  $filesList=@(@{"fileOrder"="1";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content $UploadFile
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path -path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
}
elseif ("Roles" -eq $env:IDL_type)
{
  $fileType="user"
  $SHORT_NAME="Auto_IDL_PS_Roles"
  $batchId = "IDL_Roles_${env:BUILD_NUMBER}"
  $ApplyFileName="add_roles_6.x.json"
  $UploadFile="add_roles_6.x_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $fileCount="1"
  $filesList=@(@{"fileOrder"="1";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content $UploadFile
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
}
elseif ("Hierarchy Level" -eq $env:IDL_type)
{
  # Add a check against the app server requirement for PI 3
  if ("6.8.904.7382" -GT $DisplayVersion)
  {
    $fileType="product"
    $SHORT_NAME="Auto_IDL_PS_HyLvl"
    $batchId = "IDL_HyLvl_${env:BUILD_NUMBER}"
    $ApplyFileName="rei-hlvl.json"
    $UploadFile="rei-hlvl_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
    $fileCount="1"
    $filesList=@(@{"fileOrder"="1";"fileName"=$UploadFile;})
    ##
      #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
      if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
      (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
      (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content $UploadFile
      Copy-Item $UploadFile $UploadPath$UploadFile
      if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
    ##
  }
  else
  {
    Write-Host "Hierarchy Levels requires PI 3 or higher!"
    exit 1
  }
}
elseif ("Hierarchy Data" -eq $env:IDL_type)
{
  $fileType="product"
  $SHORT_NAME="Auto_IDL_PS_HyDt"
  $batchId = "IDL_HyDt_${env:BUILD_NUMBER}"
  $ApplyFileName="add_hierarchies_6.x.json"
  $UploadFile="add_hierarchies_6.x_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $fileCount="1"
  $filesList=@(@{"fileOrder"="1";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content $UploadFile
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
}
elseif ("Tax" -eq $env:IDL_type)
{
  $fileType="product"
  $SHORT_NAME="Auto_IDL_PS_Tx"
  $batchId = "IDL_Tx_${env:BUILD_NUMBER}"
  $fileCount="3"
  $ApplyFileName="add_taxtypes_004.x.json"
  $UploadFile="add_taxtypes_004.x_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $filesList=@(@{"fileOrder"="1";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content "$UploadFile"
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
  $ApplyFileName="add_taxclasstaxtypes_004.x.json"
  $UploadFile="add_taxclasstaxtypes_004.x_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $filesList=$filesList+@(@{"fileOrder"="2";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content "1${UploadFile}"
    (Get-Content "1$UploadFile").replace('11', ${env:orgName}) | Set-Content "$UploadFile"
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
  $ApplyFileName="add_taxes_004.x.json"
  $UploadFile="add_taxes_004.x_${SHORT_NAME}_${env:BUILD_NUMBER}.json"
  $filesList=$filesList+@(@{"fileOrder"="3";"fileName"=$UploadFile;})
  ##
    #Invoke-WebRequest -Uri "https://git.rei.com/projects/RET/repos/ncr/raw/Scripts_Tools/BatchApplyScriptsForInitialLoad/${ApplyFileName}?at=refs%2Fheads%2Fmaster" -OutFile ${ApplyFileName}
    if (! (Test-Path ${ApplyFilePath}${ApplyFileName})) {Write-Host "File ${ApplyFileName} failed to download!"; exit 1}
    (Get-Content ${ApplyFilePath}${ApplyFileName}).replace('*placeholder*', $batchId) | Set-Content "0${UploadFile}"
    (Get-Content "0$UploadFile").replace(${ApplyFileName}, $UploadFile) | Set-Content "1$UploadFile"
    (Get-Content "1$UploadFile").replace('11', ${env:orgName}) | Set-Content "$UploadFile"
    Copy-Item $UploadFile $UploadPath$UploadFile
    if (! (Test-Path $UploadPath$UploadFile)) {Write-Host "File $UploadFile failed to copy!"; exit 1}
  ##
}
else
{
  Write-Host "Invalid file upload type!"
  exit 1
}

# 1.	Create Authorization Token for DSR Web API’s

#   This section is necessary to alleviate a problem with safe header parsing
$netAssembly = [Reflection.Assembly]::GetAssembly([System.Net.Configuration.SettingsSection])

if($netAssembly)
{
    $bindingFlags = [Reflection.BindingFlags] "Static,GetProperty,NonPublic"
    $settingsType = $netAssembly.GetType("System.Net.Configuration.SettingsSectionInternal")

    $instance = $settingsType.InvokeMember("Section", $bindingFlags, $null, $null, @())

    if($instance)
    {
        $bindingFlags = "NonPublic","Instance"
        $useUnsafeHeaderParsingField = $settingsType.GetField("useUnsafeHeaderParsing", $bindingFlags)

        if($useUnsafeHeaderParsingField)
        {
          $useUnsafeHeaderParsingField.SetValue($instance, $true)
        }
    }
}

#   This line is needed to ignore SSL trusting
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

#   Now we get to actual code.
#   This first condition checks for a Production environment, then for a Performance environment.
if (('P' -EQ $env:DSR_App_Server[4]) -or (('Q' -EQ $env:DSR_App_Server[4]) -and ('6' -EQ $env:DSR_App_Server[5])))
{
    $baseURI = "https://${env:DSR_Web_Server}.rei.com"
}
else
{
    $baseURI = "https://${env:DSR_Web_Server}.reicorpnet.com"
}
$atURI = "${baseURI}/NCRRetailOne/api/v8/Security/Login"
if (("Roles" -eq $env:IDL_type) -and ($env:WebUser -eq "administrator"))
{
    $atjparams = @{"orgName"="Corporate";"userName"="administrator";"password"="******";} | ConvertTo-Json
}
else
{
    $atjparams = @{"orgName"="Corporate";"userName"="${env:JenkinsUser}";"password"="${env:JenkinsPwd}";} | ConvertTo-Json
}
$AuthTokenFile="${env:DSR_Web_Server}.response.json"
if (Test-Path $AuthTokenFile) {del $AuthTokenFile}

$Response = Invoke-WebRequest -Uri $atURI -Method POST -Body $atjparams -ContentType "application/json" -Outfile $AuthTokenFile

if (Test-Path $AuthTokenFile) {$AuthTokenFileJson=$(Get-Content $AuthTokenFile | ConvertFrom-Json)} else { Write-Host "Authentication Token failure!"; exit 1}

# 3.	Invoke the Batch Apply API
#   This first condition checks for a Production environment, then for a Performance environment.
$baURI = "${baseURI}/NCRRetailOne/api/v7/BatchApply"
$baHeader=@{"authorization"=$AuthTokenFileJson.accessToken.token}
$appDateTime=((Get-Date)+(New-TimeSpan -Minutes -5)).GetDateTimeFormats()[105]
$bajparams =@{"batchId"=$batchId;"applyDateTime"=$appDateTime;"fileCount"=$fileCount;"fileType"=$fileType;"fileFormat"="Application/JSON";"filesList"=$filesList;} | ConvertTo-Json

$StatusCode = (Invoke-WebRequest -Uri $baURI -Method POST -ContentType "application/json" -Headers $baHeader -Body $bajparams -Outfile "BatchApplyResponse.json")

#  4.	Validate the status of batch apply
$DB_Server=$env:DB_Server
$SQLUser=$env:SQLUser
$SQLUserPW=$env:SQLUserPW
$Query="SELECT ApplyStatus FROM CoreDb.dbo.BatchApplyControl where BatchId='$batchId'"
$QueryResponse=""
$endTime=(Get-Date) + (New-TimeSpan -Minutes 20)
While ((($QueryResponse -eq "") -or ($QueryResponse.ApplyStatus -eq "0")) -and ((Get-Date) -lt $endTime))
{
  Start-Sleep -s 15
  $QueryResponse=$(Invoke-Command -Credential $JenkinsCred -Authentication Default -ComputerName $env:DB_Server -ScriptBlock {Invoke-Sqlcmd -ServerInstance "$using:DB_Server" -Username ${using:SQLUser} -Password ${using:SQLUserPW} -Query $using:Query})
  $QueryResponse.ApplyStatus
}

$LogPath = "Y:\ProgramData\NCR\RetailOne\Enterprise\LogFiles\BatchApply"


if ($QueryResponse.ApplyStatus -eq "0")
{
  Write-Host "Job timed out!"
  if (Test-Path $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log)
  {
    Copy-Item $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log Ncr.Retail.BatchApply.Batch-${batchId}.log
	Get-Content Ncr.Retail.BatchApply.Batch-${batchId}.log
  }
  exit 1
}
elseif ($QueryResponse.ApplyStatus -eq "3")
{
  Write-Host "Job failed to apply!"
  if (Test-Path $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log)
  {
    Copy-Item $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log Ncr.Retail.BatchApply.Batch-${batchId}.log
	Get-Content Ncr.Retail.BatchApply.Batch-${batchId}.log
  }
  exit 2
}
elseif ($QueryResponse.ApplyStatus -eq "2")
{
  Write-Host "Job applied successfully!"
  exit 0
}
else
{
  Write-Host "Something went sideways!"
  Write-Host "The ApplyStatus is $QueryResponse.ApplyStatus"
  if (Test-Path $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log)
  {
    Copy-Item $LogPath\Ncr.Retail.BatchApply.Batch-${batchId}.log Ncr.Retail.BatchApply.Batch-${batchId}.log
	Get-Content Ncr.Retail.BatchApply.Batch-${batchId}.log
  }
  exit 3
}

Remove-PSDrive Y

