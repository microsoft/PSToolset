# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function Get-Reverse
{
    <#
    .SYNOPSIS
        Reverse a sequence that is piped in

    .EXAMPLE
        1,2,3 | Get-Reverse

        Would output 3 2 1 
    #>

    $array = @($input)
    [array]::Reverse($array)
    $array
}

function Get-Randomized
{
    <#
    .SYNOPSIS
        Randomize a sequence that is piped in

    .EXAMPLE
        1, 2, 3, 4 | Get-Randomized

        Shuffles array elements and outputs array in a random order.
        Each element is outputed only once.
    #>

    $array = [Collections.ArrayList]::New(@($input))

     while( $array )
     {
         $index = Get-Random $array.Count
         $array[$index]
         $array.RemoveAt($index)
     }
}

function Get-Median
{
    <#
    .SYNOPSIS
        Calculate median of numeric array piped in

    .EXAMPLE
        5, 1, 20, 4, 4 | Get-Median

        Would output 4 
    #>

    $sorted = @($input | foreach{ [int] $psitem } | sort)
    if( -not $sorted.Length )
    {
        return
    }

    $middle = $sorted.Length / 2
    $skip = [math]::Ceiling($middle) - 1
    $take = if( $middle % 1 ) { 1 } else { 2 }
    $sorted | select -Skip $skip | select -First $take | measure -Average | foreach Average
}

function Get-UniqueUnsorted
{
    <#
    .SYNOPSIS
        Get unique values from an unsorted array

    .PARAMETER Property
        Property to analyse for uniqueness

    .EXAMPLE
        "a","c","b","b","c","z" | Get-UniqueUnsorted

        Would return unique elements of the input array wihtout changing element order: a, c, b, z

    .EXAMPLE
        "c", "bb", "a" | Get-UniqueUnsorted Length

        Would return unique length elements from the input array in the order of appearance: c, bb

    .NOTES
        [ordered] @{} can't be used here because of this bug in Powershell 4.0:

        $key = 0

        $a = @{}
        $a."key" = "value"
        $a.$key = "another value"
        $a

        Name                           Value
        ----                           -----
        key                            value
        0                              another value

        $a = [ordered] @{}
        $a."key" = "value"
        $a.$key = "another value"
        $a

        Name                           Value
        ----                           -----
        key                            another value
    #>
    param
    (
        [string] $Property
    )

    $list = @($input)

    if( -not $property )
    {
        return [Linq.Enumerable]::ToArray( [Linq.Enumerable]::Distinct( [object[]] $list ) )
    }

    $dictionary = New-Object Collections.Specialized.OrderedDictionary $list.Count
    foreach( $item in $list )
    {
        if( -not $dictionary.Contains($item.$property) )
        {
            $dictionary.Add($item.$property, $item)
        }
    }
    $dictionary.Values
}

function Test-Any( [scriptblock] $Condition = { $psitem -ne $null } )
{
    <#
    .SYNOPSIS
        Test if any element in the piped-in input confirms to the condition

    .DESCRIPTION
        Useful for functional-style code. Returns $true if there is an element
        that confirms to the specified condition. $false if there are no such
        elements.

    .PARAMETER Condition
        Condition to test for each element. $psitem variable can be used.
        By default would return $true for the not null elements.

    .EXAMPLE
        "1", "2" | any{ $psitem -eq "2" }
        True since we have "2" element in the input collection.

    .EXAMPLE
        "1", "2" | any
        True since we have a not null element in the input collection.

    .EXAMPLE
        $notExistingVariable | any
        False since Powershell would create collection with one $null element.

    .EXAMPLE
        $() | any
        False since there is no element in the input collection that is not null.

    .NOTES
        Can't use 'break' for this - we would exit all pipelines, 
        not just the current one
    #>

    begin
    {
        $found = $false
    }
    process
    {
        if( -not $found )
        {
            if( $psitem | where $condition )
            {
                $found = $true
            }
        }
    }
    end
    {
        $found
    }
}

function Test-All( [scriptblock] $Condition = { $psitem -ne $null } )
{
    <#
    .SYNOPSIS
        Test if all elements in the piped-in input confirm to the condition

    .DESCRIPTION
        Useful for functional-style code. Returns $true if all elements in the
        piped-in input confirm to the specified condition. $false if there is
        at least one element that doesn't confirm.

    .PARAMETER Condition
        Condition to test for each element. $psitem variable can be used.
        By default would return $true for the not null elements.

    .EXAMPLE
        "1", "2" | all{ $psitem -eq "2" }
        False since we have "1" element that doesn't equal to "2".

    .EXAMPLE
        "1", "2" | all
        True since all elements are not null.

    .EXAMPLE
        $notExistingVariable | all
        False since Powershell would create collection with one $null element.

    .EXAMPLE
        @() | all
        True since there is no element in the unput collection that contradicts 
        the not-null condition.

    .NOTES
        Can't use 'break' for this - we would exit all pipelines, 
        not just the current one
    #>

    begin
    {
        $scannedMatched = $true
    }
    process
    {
        if( $scannedMatched )
        {
            if( -not ($psitem | where $condition) )
            {
                $scannedMatched = $false
            }
        }
    }
    end
    {
        $scannedMatched
    }
}

function Get-First( [scriptblock] $Condition = { $psitem -ne $null } )
{
    <#
    .SYNOPSIS
        Returns first element in the piped-in input that confirms to the condition

    .DESCRIPTION
        Useful for functional-style code. Returns first found element that confirms 
        to the specified condition. Nothing is returned when there are no such 
        elements.

    .PARAMETER Condition
        Condition to test for each element. $psitem variable can be used.
        By default would return $true for the not null elements.

    .EXAMPLE
        "1", "23", "4" | first{ $psitem.Length -gt 1 }
        "1", "2" | first
        $notExisting | first

        First check returns "23" since length of this string is greater then 1.
        Second check returns "1" since it is first not null element.
        Third check returns nothing since Powershell would create collection with 
        one $null element.

    .NOTES
        There is a way how to make it faster. See the response from Jason Shirk:

        I don’t think we expose a clean way to do that.  Select-Object –First will 
        stop a pipeline cleanly, but it does so with an exception type that we don’t 
        make public.

        Here is an example of how you could implement Find-First combining proxies 
        and Select-Object – I’ll admit it’s not obvious but it is efficient:

        function Find-First
        {
        [CmdletBinding()]
        param(
            [Parameter(ValueFromPipeline=$true)]
            [psobject]
            ${InputObject},

            [Parameter(Mandatory=$true, Position=0)]
            [scriptblock]
            ${FilterScript})

        begin
        {
            try {
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Where-Object', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters | Select-Object -First 1 }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
            } catch {
                throw
            }
        }

        process { try {$steppablePipeline.Process($_)} catch {throw} }
        end { try {$steppablePipeline.End()} catch {throw} }
        }
    #>

    begin
    {
        # NOTE: Can't use 'break' for this - we would exit all pipelines, 
        # not just the current one
        $resultKnown = $false
    }
    process
    {
        if( -not $resultKnown )
        {
            if( $psitem | where $condition )
            {
                $psitem
                $resultKnown = $true
            }
        }
    }
}

function Get-Last( [scriptblock] $Condition = { $psitem -ne $null } )
{
    <#
    .SYNOPSIS
        Returns last element in the piped-in input that confirms to the condition

    .DESCRIPTION
        Useful for functional-style code. Returns last found element that confirms 
        to the specified condition. Nothing is returned when there are no such 
        elements.

    .PARAMETER Condition
        Condition to test for each element. $psitem variable can be used.
        By default would return $true for the not null elements.

    .EXAMPLE
        "1", "23", "42", "2" | last{ $psitem.Length -gt 1 }
        "1", "2" | last
        $notExisting | last

        First check returns "42" since this is last element with length greater 
        then 1. Second check returns "2" since it is last not null element.
        Third check returns nothing since Powershell would create collection 
        with one $null element.
    #>

    begin
    {
        $lastMatched = $null
    }
    process
    {
        if( $psitem | where $condition )
        {
            $lastMatched = $psitem
        }
    }
    end
    {
        if( $lastMatched )
        {
            $lastMatched
        }
    }
}

function Get-Separation( [scriptblock] $condition )
{
    <#
    .SYNOPSIS
        Separate collection into two based on some condition

    .DESCRIPTION
        Useful for functional-style code. Returns two collections:
        - first one stores input elements that tested True in condition
        - second one stores input element that tested False in condition

        The separation is implemented fast and uses hash tables inside.

    .PARAMETER Condition
        Scriptblock that seperates elements in the input collection.

    .EXAMPLE
        $large, $small = ls | separate {$_.Length -gt 10kb}

        Seperates files in the folder into two categories - large ones
        that are bigger than 10kb and smaller ones.
    #>

    $separated = $input | group $condition -AsHashTable
    @($separated[$true]), @($separated[$false])
}