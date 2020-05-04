# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Resolve-ScriptPath
{
    <#
    .SYNOPSIS
        Resolve path that is local to the script

    .DESCRIPTION
        During script development it is useful to copy-paste function code and call 
        scripts in the local folder. But for reusability in the script files it is 
        best to combine paths with $PsScriptRoot variable that is available only 
        when called from withing a script.

        This function bring good from both of the worlds together. Resolving paths 
        with this function allows to:
        - Copy-paste code from editor. Paths would be resolved relative to 
          current folder.
        - Use $PsScriptRoot when script is being called. Path would be resolved 
          relative to script root folder.

    .PARAMETER Path
        Path to be resolved.

    .EXAMPLE
        Resolve-ScriptPath "Utils.ps1"

        When executed in console on copy-paste it would resolve to '.\Utils.ps1', 
        but when executed from a script that somebody calls it would resolve to 
        'Drive:\Path\To\Script\Folder\Utils.ps1'
    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    $location = if( $myInvocation.PSScriptRoot )
    {
        $myInvocation.PSScriptRoot
    }
    else
    {
        "."
    }

    Join-Path $location $path
}

function Get-FileEncoding
{
    <#
    .SYNOPSIS
        Gets file encoding

    .DESCRIPTION
        Useful if you want to update large volume of files and don't want
        to have regressions comming from encoding changes as a side-effecr.

    .PARAMETER Path
        The path to the file you need get encoding from.

    .EXAMPLE
        Get-FileEncoding main.cpp

        Get encoding that is main.cpp file uses.

    .LINK
        http://franckrichard.blogspot.com/2010/08/powershell-get-encoding-file-type.html

    .NOTES
        Default encoding behaves as ASCII with support of currently used
        windows code page
    #>

    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Path
    )

    function Test-Preamle( $encoding, [byte[]] $filePreamble )
    {
        [byte[]] $preamble = $encoding.GetPreamble()

        if( $filePreamble.Count -lt $preamble.Count )
        {
            return false
        }

        for( $i = 0; $i -lt $preamble.Count; $i += 1 )
        {
            if( $filePreamble[$i] -ne $preamble[$i] )
            {
                return $false
            }
        }

        return $true
    }

    $knownEncodings =
        [Text.Encoding]::BigEndianUnicode,
        [Text.Encoding]::UTF32,
        [Text.Encoding]::UTF8,
        [Text.Encoding]::Unicode, # that's UTF16
        [Text.Encoding]::Default  # must come last

    [byte[]] $byte = Get-Content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $Path

    foreach( $encoding in $knownEncodings )
    {
        if( Test-Preamle $encoding $byte )
        {
            return $encoding
        }
    }

    # Usually Default encoding preamble is empty and we return it, but in case
    # that's not true we assume file without preamble to be UTP7 encoded
    [Text.Encoding]::UTF7
}