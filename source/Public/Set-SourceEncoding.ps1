<#
    .SYNOPSIS
        Sets the correct encoding for the given file path.

    .PARAMETER FileInfo
        The file to set the encoding on
#>

function Set-SourceEncoding
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [System.IO.FileInfo]
        $FileInfo
    )

    process
    {
        if ($FileInfo.Extension -eq '.mof')
        {
            $FileInfo | ConvertTo-UTF8
            return
        }
        elseif ($FileInfo)
        {
            $FileInfo | ConvertTo-ASCII
        }
    }
}
