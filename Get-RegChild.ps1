function Get-RegChild_
{
    $ChildScriptBlock=[Scriptblock]::Create("Get-ChildItem -Recurse -Path `"hklm:\$sRegPathBase`" -Include `'$RegTermTarget`' | Where PSPath -NotLike '*InstallShield*'")
    $objRegChild_ = Invoke-Command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock $ChildScriptBlock
    return $objRegChild_
}

function Get-RegChild32
{
    $script:sRegPathBase="SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\"
    $script:sRegistry="Registry32"

    $objRegChild32=Get-RegChild_
    return $objRegChild32
}

function Get-RegChild64
{
    $script:sRegPathBase="SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
    $script:sRegistry="Registry64"

    $objRegChild64=Get-RegChild_
    return $objRegChild64
}

function Get-RegChild
{
    $script:objRegChildReturn = $null
    $objRegChild=Get-RegChild32
    if (!$objRegChild)
    {
        $objRegChild=Get-RegChild64
    }
    return $objRegChild
}

function Get-ChildItemNameValue ($ChildItemName)
{
    if ($objRegChildReturn.PSChildName)
    {
        if ($objRegChildReturn.PSChildName.Count -eq 1)
        {
            $sRegPath=$sRegPathBase+$objRegChildReturn.PSChildName
        }
        else
        {
            $sRegPath=$sRegPathBase+$objRegChildReturn.PSChildName[0]
        }
    }
    else
    {
        $sRegPath=$sRegPathBase+$RegTermTarget
    }
    $sbOpenRegKey=[Scriptblock]::Create("`$objReg=[Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', '$sRegistry'); `$objRegKey=`$objReg.OpenSubKey(`"$sRegPath`"); `$objRegKey.GetValue(`"$ChildItemName`")")
    $ChildItemNameValue = Invoke-Command -Credential $JenkinsCred -Authentication Default -ComputerName $env:Target_Machine -ScriptBlock $sbOpenRegKey
    return $ChildItemNameValue
}
