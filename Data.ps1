# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function ConvertTo-PsObject
{
    <#
    .SYNOPSIS
        Convert a set of variables into a PsObject

    .DESCRIPTION
        Constructs new PsObject from the available variables.
        Simplifies packing of data into one object that Powershell can work with.

        Alias: construct

    .PARAMETER Args
        All parameters are detected dynamically. You should pass here names
        of the variables you'd like to convert into the PsObject.

    .EXAMPLE
        $a = "a_value"
        $b = [int] 5
        $c = "one", "two"
        construct a b c

        Constructs PsObject with properties a, b and c. Values are taken from
        variables $a, $b and $c.
    #>

    $properties = [ordered] @{}

    foreach( $name in $args )
    {
        $local = Get-Variable $name -Scope local -ea Ignore
        if( $local ) { $properties.$name = $local.Value; continue }

        $script = Get-Variable $name -Scope script -ea Ignore
        if( $script ) { $properties.$name = $script.Value; continue }

        $global = Get-Variable $name -Scope global -ea Ignore
        if( $global ) { $properties.$name = $global.Value; continue }

        Write-Warning "Could not resolve variable with name '$name'"
    }

    New-Object -TypeName PSObject -Property $properties
}

function ConvertTo-Hash( [object] $object )
{
    <#
    .SYNOPSIS
        Convert an object into a hash table

    .DESCRIPTION
        This function takes any object, gets all not $false properties and creates
        hash table out of the found properties. This can be useful to pass some
        object through a process boundary or to remove property from an object.

    .PARAMETER Object
        Object to deconstruct into hash table

    .EXAMPLE
        ConvertTo-Hash (ls | select -f 1)

        Get hash table from the first found child item.
    #>

    $hash = [ordered] @{}
    $object |
        foreach{ $psitem.PsObject.Members } |
        where MemberType -match "^(Note)?Property$" |
        foreach Name |
        where{ $object.$psitem } |
        foreach{ $hash[$psitem] = $object.$psitem }
    $hash
}

function Get-Parameter
{
    <#
    .SYNOPSIS
        Get names of all available parameters from input objects

    .DESCRIPTION
        This filter analyses what parameters are present in all objects passed to
        the filter and outputs all unique parameter names.

    .PARAMETER Pattern
        Constrain output only to parameter names that match this pattern.
        By default all parameter names are returned.

    .PARAMETER Single
        Specify this switch if there must be only one parameter that match the
        pattern. If there is no single matching parameter, exception is thrown.

    .EXAMPLE
        Get-ChildItem | Get-Parameter

        List all available parameters from Get-ChildItem command.
        Both file info and directory info parameter names will be listed.

    .EXAMPLE
        Get-Process | Get-Parameter priority

        List all parameters for Process object (returned from Get-Process) that
        contain 'priority' substring in the parameter name.
        'priority' here is a regex.

    .LINK
        Use-Project
        Use-Filter
    #>

    param
    (
        [string] $Pattern = ".*",
        [switch] $Single
    )

    begin { $accumulator = @() }
    process { $accumulator += $psitem }
    end
    {
        if( -not $accumulator )
        {
            return
        }

        # Get properties that match the pattern
        $result = @(
            $accumulator |
                foreach{ $psitem.PsObject.Members } |
                where Name -match $pattern |
                where MemberType -match "Property" |
                foreach Name |
                Get-UniqueUnsorted)

        # Need to return all entries
        if( -not $single ) { return $result }

        # No ambulation with matches
        if( $result.Length -eq 1 ) { return $result[0] }

        # Strict match disambiguation
        if( @($result | where{ $psitem -eq $pattern }).Length -eq 1 ) { return $pattern }

        # Warn user about ambulation
        Write-Warning "Disambiguate '$pattern'`n$($result | Out-String)"
    }
}

function Use-Project
{
    <#
    .SYNOPSIS
        Project several parameters from input objects

    .DESCRIPTION
        This command performs project operation from relational algebra with not
        strict column name matching. It allows to compress data output only to
        the columns you are interested in.

        You are not forced to specify full column names to do so. You only need
        to supply enough info to perform unambiguous column name match. It makes
        working with table-like date more interactive and less time consuming.

        Behavior is very similar to Select-Object with not strict (but unambiguous)
        properties specified.

        Alias: p

    .PARAMETER Args
        Pass as many column name patterns as you like - they would be parsed
        dynamically.

    .EXAMPLE
        Get-ChildItem | Use-Project name len

        Would output Name and Length properties of all child items. Projection
        doesn't require you to specify full property name if you can supply
        unambiguous matching regex pattern.

    .EXAMPLE
        Get-ChildItem | Use-Project name time
        WARNING: Disambiguate 'time'
        CreationTime
        CreationTimeUtc
        LastAccessTime
        LastAccessTimeUtc
        LastWriteTime
        LastWriteTimeUtc

        Would output warning showing that 'time' parameter is ambiguous and there
        are 6 parameter names that match it. You must supply more specific
        parameter name so the match would be unambiguous.

        [The same command via aliases]
        ls | p name time

    .LINK
        Get-Parameter
        Use-Filter
    #>

    begin { $accumulator = @() }
    process { $accumulator += $psitem }
    end
    {
        # Display available parameters if no arguments are specified
        if( $args.Count -eq 0 ) { Write-Warning "What property?`n$($accumulator | Get-Parameter | Out-String)"; return }

        # Resolve all passed parameter names
        $resolved = [string[]] @($args | foreach{ $accumulator | Get-Parameter $psitem -Single } )

        # Output all resolved parameters
        # If there is an unresolved parameter do nothing
        if( $args.Count -eq $resolved.Count ) { $accumulator | Select-Object -Property $resolved }
    }
}

function Use-Filter
{
    <#
    .SYNOPSIS
        Regex based parameter filter for input objects

    .DESCRIPTION
        Filters pipeline passing through only objects that match specific property
        and value pattern. Allows to quickly explore data and discover property
        names and values.

        Alias: f

    .PARAMETER ParameterPattern
        Regex pattern for a parameter. Only not ambiguous matches are accepted.
        All ambiguities are explained via Warnings. If parameter pattern is omitted,
        all existing property names are shown.

    .PARAMETER ValuePattern
        Regex pattern for a parameter value. Only not ambiguous matches are accepted.
        All ambiguities are explained via Warnings. If value pattern is omitted, all
        existing property values are shown.

    .PARAMETER NoValue
        Specify this switch if you want to filter properties that match property
        pattern but have no value.

    .EXAMPLE
        PS> Get-ChildItem | Use-Filter name
        PS> ls | f name ps1

        Exploring Get-ChildItem output. Output unique values for a property that
        match 'name' pattern. Then specify ps1 files for the name.

    .EXAMPLE
        ls | f len -NoValue

        Filter ls output, find files which don't have Length property set.

    .LINK
        Get-Parameter
        Use-Project
    #>

    param
    (
        [string] $ParameterPattern,
        [string] $ValuePattern,
        [switch] $NoValue
    )

    begin { $accumulator = @() }
    process { $accumulator += $psitem }
    end
    {
        # Display available parameters if no parameter pattern is specified
        if( -not $parameterPattern ) { Write-Warning "What property?`n$($accumulator | Get-Parameter | Out-String)"; return }

        # Resolve parameter name
        $parameter = $accumulator | Get-Parameter $parameterPattern -Single
        if( -not $parameter ) { return }

        # No value special case
        if( $noValue ) { return $accumulator | where{ -not $psitem.$parameter } }

        # Display all values if no value pattern is specified
        if( -not $valuePattern ) { Write-Warning "What value?`n$($accumulator | foreach{ $psitem.$parameter } | Get-UniqueUnsorted | Out-String)"; return }

        # Output object that has matches in property and value
        $accumulator | where{ $psitem.$parameter -match $valuePattern }
    }
}

function Get-Ini
{
    <#
    .SYNOPSIS
        Parse INI file as a hashtable object

    .DESCRIPTION
        Features:
        - Both section and section-less parameters are supported.
        - Comments are supported.
        - Non-literal names are supported.
        - Collapsing of empty sections is supported.

    .PARAMETER Path
        Path to INI file.
        Can't be used at the same time with Content.

    .PARAMETER KeepEmptySections
        Specify this switch if you want to keep empty INI sections in the output.
        By default empty sections are removed.

    .PARAMETER Content
        Content of the INI file.
        Can't be used at the same time with Path.

    .PARAMETER Comment
        Regex that specifies how comments are started in ini file.
        By default: ;

    .EXAMPLE
        Get-Ini Shared.ini

        Parse Shared.ini file.

    .LINK
        Show-Ini
        http://stackoverflow.com/questions/417798/ini-file-parsing-in-powershell
    #>

    param
    (
        [string] $Path,
        [switch] $KeepEmptySections,
        [string[]] $Content,
        [string] $Comment = ";"
    )

    # Parameter validation
    if( $path -and $content )
    {
        throw "It is not possible to specify both -Path and -Content parameters"
    }

    # Initialize
    $section = ""
    $ini = [ordered]@{}
    $ini[$section] = [ordered]@{}
    $content = if( $content )
    {
        $content -split "`r?`n"
    }
    else
    {
        Get-Content $path
    }

    # Parsing
    foreach( $line in $content )
    {
        $withoutComments = ($line -replace "$comment.*").Trim()
        if( $withoutComments.Length -eq 0 ) { continue }

        switch -regex ($withoutComments)
        {
            "^\[([^\]]+)\]\s*$"
            {
                $section = $matches[1].Trim()
                $ini[$section] = [ordered]@{}
            }
            "^([^=]+)\s*=\s*(.*)?\s*$"
            {
                $name, $value = $matches[1..2]
                $ini[$section][$name.Trim()] = $value
            }
            default
            {
                Write-Warning "Unknown sentence '$line' in file '$path'. Skipping the line."
            }
        }
    }

    # Remove empty sections by creating a new object since in
    # ConstrainedMode we can't use methods like $ini.Remove()
    if( -not $KeepEmptySections )
    {
        $newIni = [ordered]@{}
        $ini.keys | where{ $ini[$psitem].Count -gt 0 } | foreach{ $newIni[$psitem] = $ini.$psitem }
        $ini = $newIni
    }

    # Copy entries from no-section if it's possible
    if( $ini[""] -and $ini[""].Keys )
    {
        $withoutSection = @($ini[""].Keys) | where{ @($ini.keys) -notcontains $psitem }
        $withoutSection | foreach{ $ini[$psitem] = $ini[""][$psitem] }
    }

    $ini
}

function ConvertFrom-Ini
{
    <#
    .SYNOPSIS
        Converts ini strings into Powershell hashtable object

    .DESCRIPTION
        Features:
        - Both section and section-less parameters are supported.
        - Comments are supported.
        - Non-literal names are supported.
        - Collapsing of empty sections is supported.

    .PARAMETER Content
        Content of an INI file.

    .PARAMETER Comment
        Regex that specifies how comments are started in ini file.
        By default: ;

    .PARAMETER KeepEmptySections
        Specify this switch if you want to keep empty INI sections in the output.
        By default empty sections are removed.

    .EXAMPLE
        ConvertFrom-Ini (Get-Content Shared.ini)

        Convert content of Shared.ini file to a hashtable object.

    .LINK
        http://stackoverflow.com/questions/417798/ini-file-parsing-in-powershell
    #>

    param
    (
        [string[]] $Content,
        [string] $Comment = ";",
        [switch] $KeepEmptySections
    )

    # Initialize
    $section = ""
    $ini = [ordered]@{}
    $ini[$section] = [ordered]@{}
    $content = $content -split "`r?`n"

    # Parsing
    foreach( $line in $content )
    {
        $withoutComments = ($line -replace "$comment.*").Trim()
        if( $withoutComments.Length -eq 0 ) { continue }

        switch -regex ($withoutComments)
        {
            "^\[([^\]]+)\]\s*$"
            {
                $section = $matches[1].Trim()
                $ini[$section] = [ordered]@{}
            }
            "^([^=]+)\s*=\s*(.*)?\s*$"
            {
                $name, $value = $matches[1..2]
                $ini[$section][$name.Trim()] = $value
            }
            default
            {
                Write-Warning "Unknown sentence '$line' in file '$path'. Skipping the line."
            }
        }
    }

    # Remove empty sections by creating a new object since in
    # ConstrainedMode we can't use methods like $ini.Remove()
    if( -not $KeepEmptySections )
    {
        $newIni = [ordered]@{}
        $ini.keys | where{ $ini[$psitem].Count -gt 0 } | foreach{ $newIni[$psitem] = $ini.$psitem }
        $ini = $newIni
    }

    # Copy entries from no-section if it's possible
    if( $ini[""] -and $ini[""].Keys )
    {
        $withoutSection = @($ini[""].Keys) | where{ @($ini.keys) -notcontains $psitem }
        $withoutSection | foreach{ $ini[$psitem] = $ini[""][$psitem] }
    }

    $ini
}

function Import-Ini
{
    <#
    .SYNOPSIS
        Imports ini file into Powershell hashtable object

    .DESCRIPTION
        Features:
        - Both section and section-less parameters are supported.
        - Comments are supported.
        - Non-literal names are supported.
        - Collapsing of empty sections is supported.

    .PARAMETER Path
        Path to an existing INI file.

    .PARAMETER Comment
        Regex that specifies how comments are started in ini file.
        By default: ;

    .PARAMETER KeepEmptySections
        Specify this switch if you want to keep empty INI sections in the output.
        By default empty sections are removed.

    .EXAMPLE
        Import-Ini Shared.ini

        Convert content of Shared.ini file to a hashtable object.

    .LINK
        http://stackoverflow.com/questions/417798/ini-file-parsing-in-powershell
    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $psitem -PathType Leaf})]
        [string] $Path,
        [string] $Comment = ";",
        [switch] $KeepEmptySections
    )

    $content = Get-Content $path
    ConvertFrom-Ini $content -Comment:$Comment -KeepEmptySections:$KeepEmptySections
}

function Show-Ini
{
    <#
    .SYNOPSIS
        Print contents of INI parsed file, received from Get-Ini command

    .DESCRIPTION
        Formats INI file in hash table form to make it console-readable.
        You can specify section filter to get only the sections of interest
        at the moment.

    .PARAMETER Ini
        Content of a INI file in hash table form. Usually it is out from
        Get-Ini command.

    .PARAMETER SectionFilter
        Filter that should pass each section in order to be outputted.
        By default all sections are shown.

    .EXAMPLE
        Show-Ini (Get-Ini Shared.ini) machine

        Print all sections of Shared.ini containing 'machine' word.

    .LINK
        Get-Ini
    #>

    param
    (
        [hashtable] $Ini,
        [string] $SectionFilter = ".*"
    )

    foreach( $section in ($ini.Keys | sort | where{ $psitem -match $sectionFilter }) )
    {
        $section
        foreach( $key in $ini[$section].keys )
        {
            "    $($key) = $($ini[$section][$key])"
        }
        ""
    }
}
