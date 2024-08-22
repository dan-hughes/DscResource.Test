<#
    .SYNOPSIS
        Converts the given file to UTF8 encoding.

    .PARAMETER FileInfo
        The file to convert.
#>
function ConvertTo-UTF8
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
        $fileContent = Get-Content -Path $FileInfo.FullName -Encoding 'Unicode' -Raw
        [System.IO.File]::WriteAllText($FileInfo.FullName, $fileContent, [System.Text.Encoding]::UTF8)
    }
}
