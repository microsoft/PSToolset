# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

filter Use-Parse
{
    <#
    .SYNOPSIS
        Parse incoming text to find relevant pieces in it

    .DESCRIPTION
        Parses incoming stream of strings and matches each string to a regex
        pattern. The regex pattern must define regex groups that are used to
        capture extracted text. The extracted text is stored in output object
        that is constructed dynamically. Each regex group match would be stored
        in that object as string property with name defined by $args unbound
        parameters. If no unbound parameter is specified, the first group match
        is returned.

    .PARAMETER Pattern
        Regex used in matching. Regex groups are used to define significant
        pieces of text that are extracted from incoming stream.

    .PARAMETER Args
        The $args array (the unbound command parameters) contain names of
        properties that would be used to capture each regex group match.
        Each property would be populated with corresponding regex group match
        value in the order of their definition.

        If no args are passed, the first regex group match value is returned
        as result.

    .PARAMETER Enforce
        Specify this flag if all passed object must match the regex pattern.
        If mismatch is found, an exception is thrown.
        By default: not set, all not matching elements would be silently skipped.

    .EXAMPLE
        "Info string ABC encoded in text CDE" | parse "string (.+) encoded in text (.+)$" First Second

        Parses string and extracts object with string properties First = "ABC" and Second = "CDE"

    .EXAMPLE
        "line 1", "line 2", "line three" | parse "line (\d+)"

        Parses incoming array of strings and extracts numeric line numbers.
        Last line that contain mismatched text is ignored.

    .EXAMPLE
        "line 1", "line 2", "line three" | parse "line (\d+)" -Enforce

        Parses incoming array of strings and extracts numeric line numbers.
        Last line that contain mismatched text throws an exception.
    #>

    param
    (
        [string] $Pattern = $(throw "You must specify the pattern"),
        [switch] $Enforce
    )

    if( $psitem -notmatch $pattern )
    {
        # Process not matching elements
        if( $enforce )
        {
            throw "Failed to parse: $($psitem)"
        }
        else
        {
            return
        }
    }

    if( -not $args )
    {
        return $matches[ 1 ]
    }

    $bag = @{}

    for( $i = 0; $i -lt $args.Count; $i += 1 )
    {
        $bag[$args[$i]] = $matches[$i + 1]
    }

    New-Object PsObject -Property $bag | select $args
}

function Use-Default
{
    <#
    .SYNOPSIS
        Define default value if input is null, false or missing

    .EXAMPLE
        "test" | default "UNKNOWN"
        1,2,2 | default "UNKNOWN"
        $false | default "UNKNOWN"
        $null | default "UNKNOWN"
        $null | select -f 1 | default "null"
        $head | parse "^([\d-]+\s[\d:]+)z" | foreach{ Get-Date -date $psitem } | default ([datetime]::MaxValue)
    #>

    param
    (
        $unsetValue = $null
    )

    begin
    {
        $noElements = $true
    }
    process
    {
        $noElements = $false
        if( $psitem ) { $psitem } else { $unsetValue }
    }
    end
    {
        if( $noElements ) { $unsetValue }
    }
}

filter Format-Template( [string] $Template = $(throw "Template is mandatory") )
{
    <#
    .SYNOPSIS
        Render text template

    .DESCRIPTION
        This function is used to render text from templates and variables that
        store template-specific information. When {property_name} text is
        encountered in the template, the function would try to resolve it via:
        - property of the piped in variables with the same name 'property_name'.
        - Powershell variable with the same name 'property_name'. Out-String would
          be used in that case.

        If multiple objects are piped in, the rendered text would be rendered for
        each object separately.

        That allows to conveniently generate text from data.

    .PARAMETER Template
        Template string to be used. Any occurrence of {property_name} would be
        tried to be resolved. If the property can't be resolved, it is left as
        it is in the template.

    .EXAMPLE
        $podXml = $edge | Format-Template @'
                <Pod name="{PodName}" rack="{RackFloor}" type="{PodType}" location="{City}">
            {PowerRendered}
            {ServerRendered}
                </Pod>
        '@

        Template used here would use both properties from $edge collection objects
        (PodName,RackFloor, PodType,City that are specific to a concrete Edge) and
        from already rendered text (PowerRendered, ServerRendered).

    .LINK
        Get-UnresolvedTemplateItem
    #>

    $values = $psitem
    $keys = Get-UnresolvedTemplateItem $template
    $lastFrameVariables = (Get-PSCallStack)[1].GetFrameVariables()
    $result = $template

    foreach( $name in $keys )
    {
        $value = $values.$name
        if( -not $value )
        {
            $value = if( $lastFrameVariables.ContainsKey($name) )
            {
                $lastFrameVariables[$name].Value
            }
            else
            {
                Get-Variable $name -ValueOnly -ea Ignore
            }
            $value = $value | Out-String | foreach TrimEnd
        }
        if( -not $value )
        {
            continue
        }
        $result = $result.Replace("{" + $name + "}", $value)
    }

    $result
}

function Get-UnresolvedTemplateItem( [string] $Template = $(throw "Template is mandatory") )
{
    <#
    .SYNOPSIS
        Find template items that were not resolved yet

    .PARAMETER Template
        Template string to be used. Any occurrence of {property_name} would be
        tried to be resolved. If the property can't be resolved, it is left as
        it is in the template.

    .EXAMPLE
        Get-UnresolvedTemplateItem "{templateItem} is an unresolved template item"

        Finds that 'templateItem' is an unresolved template item.

    .LINK
        Format-Template
    #>

    [regex]::Matches($template, "\{([^}]+)\}") | foreach{ $psitem.Groups[1].Value }
}