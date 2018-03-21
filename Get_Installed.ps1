. "./DSR_AMS/Get-RegChild.ps1"

Function Get-Installed ($RegTermTarget = "")
{
    $objRegChildReturn=Get-RegChild

    if ($objRegChildReturn)
    {
        $DisplayName=Get-ChildItemNameValue ("DisplayName")
    
        $DisplayVersion=Get-ChildItemNameValue ("DisplayVersion")
    
        $sDisplayVersion = ""
        if ($DisplayVersion){$sDisplayVersion = (" version "+$DisplayVersion)}

        return "$DisplayName$sDisplayVersion"
    }
    else
    {
        return ""
    }
}