if (-NOT $env:Target_Machine){Write-Host "Required parameter Target_Machine is null!"; exit 1}

. "./DSR_AMS/Get_Installed.ps1"
. "./DSR_AMS/Create-PSCredential.ps1"

"**********"  | Out-File -FilePath Report.txt
if (-NOT (Test-WSMan -Credential $JenkinsCred -Authentication Default -ComputerName ${env:Target_Machine} -ErrorAction:SilentlyContinue))
{
    Write-Host "Connection Failure!"
    "${env:Target_Machine} failed to connect!" | Out-File -FilePath Report.txt
    "  "  | Out-File -FilePath Report.txt -Append
    "**********"  | Out-File -FilePath Report.txt -Append
    exit 1
}

if (Test-Path ".\DSR_AMS"){$FolderPiece=".\DSR_AMS"}else{$FolderPiece="."}

"Installed on "+$env:Target_Machine+":"  | Out-File -FilePath Report.txt -Append
"  "  | Out-File -FilePath Report.txt -Append

$dictPages=@{}
$dictPages.Add("MS Visual C++ 2013 Redist","{7f51bdb9-ee21-49ee-94d6-90afc321780e}")
$dictPages.Add("OpenSSL","OpenSSL*")
$dictPages.Add("Windows 2003 Resource Toolkit","{FA237125-51FF-408C-8BB8-30C2B3DFFF9C}")
$dictPages.Add("PostgreSQL 9.6","PostgreSQL 9.6")
$dictPages.Add("JDK 1.8 8u144 x64","{26A24AE4-039D-4CA4-87B4-2F64180144F0}")
$dictPages.Add("NCR Universal Engine","{AAAAAAAA-BBBB-CCCC-0000-111111108860}")
$dictPages.Add("Erlang OTP","Erlang*")
$dictPages.Add("RabbitMQ","RabbitMQ")
$dictPages.Add("NCR DSR Enterprise Server","{569F15AE-5C62-44B6-96A1-CDEC8ECB1EEB}")
$dictPages.Add("NCR Advanced Store Server Suite","{B8AA8190-9A3D-4651-9FD7-27BB267CC9A7}")
$dictPages.Add("NCR EOM-ETS Server","{0E74DEA8-D465-4C94-BBFE-F262AAD29C8A}")
$dictPages.Add("NCR Advanced Store Server - Customer Config Overlay","{0E9F1AD6-CB64-41C5-AC3E-FE8FFE906E16}")
$dictPages.Add("NCR AMS Server","{AAAAAAAA-BBBB-CCCC-0000-111111199697}")
$dictPages.Add("NCR AMS Broker","AMS Brokers")

foreach ($page in $dictPages.GetEnumerator())
{
    Write-Host "Checking $($page.Name)"
	$sResult=""
	$sResult=(Get-Installed -RegTermTarget $page.Value)
	if ("" -ne $sResult){$sResult | Out-File -FilePath Report.txt -Append}
}

"  "  | Out-File -FilePath Report.txt -Append
"**********"  | Out-File -FilePath Report.txt -Append

Get-Content Report.txt