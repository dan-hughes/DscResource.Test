<#
    .SYNOPSIS
        Retrieves all unicode files under the given file path.

    .PARAMETER FilePath
        The root file path to gather the files from.
#>

function Get-UnicodeFilesList
{
    [OutputType([System.IO.FileInfo[]])]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Root
    )

    return Get-TextFilesList -Root $Root | Where-Object { Test-FileInUnicode $_ }
}
