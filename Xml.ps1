# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

function New-XName
{
    <#
    .SYNOPSIS
        Create XName object with specified name

    .EXAMPLE
        xname some_xname
    #>

    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    [Xml.Linq.XName] $name
}

function New-XAttribute
{
    <#
    .SYNOPSIS
        Create XAttribute object with specified name and value

    .EXAMPLE
        ls | xelem "Files" `
            {xattr Name $psitem.Name},
            {xattr Length $psitem.Length},
    #>

    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [string] $Value
    )

    New-Object Xml.Linq.XAttribute $name, $value
}

function New-Xmlns
{
    <#
    .SYNOPSIS
        Create Xmlns object with specified namespace and value

    .EXAMPLE
        "Some", "Collection" | xelem "Element" `
            {xmlns xsd "http://www.w3.org/2001/XMLSchema"},
            {xmlns xsi "http://www.w3.org/2001/XMLSchema-instance"}
    #>

    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Namespace,
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    New-XAttribute ([Xml.Linq.XNamespace]::Xmlns + $namespace) $value
}

function New-XComment
{
    <#
    .SYNOPSIS
        Create XComment object with specified value

    .EXAMPLE
        ls | xelem "File" `
            {xcomm " Length: $($psitem.Length) "},
            {xcomm " BaseName: $($psitem.BaseName) "}
    #>

    param
    (
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    [Xml.Linq.XComment] $value
}

filter New-XElement
{
    <#
    .SYNOPSIS
        Create XElement object and attach specified via
        script blocks other XObjects in a hierarchcal form

    .EXAMPLE
        $psitem | xelem "Acls" `
            {xmlns xsd "http://www.w3.org/2001/XMLSchema"},
            {xmlns xsi "http://www.w3.org/2001/XMLSchema-instance"},
            {xattr Version "latest"},
            {xcomm " Syntax: $($psitem.Syntax)"},
            {xcomm " Devices: $($psitem.Devices.Name -join ';') "},
            {xcomm " Clusters: $($psitem.Clusters -join ';') "},
            {$psitem | xelem "AccessControlList" `
                {xattr Device $psitem.Sku},
                {xattr Firmware $psitem.Firmware},
                {$psitem | xelem "AclGroup" `
                    {xattr Name "Global"},
                    {xattr Type "AccessList"},
                    {$psitem.Policies | xelem "Policy" `
                        {xattr Name $psitem.Name},
                        {$psitem.Rules | xelem Rule}
                    }
                }
            }
    #>

    param
    (
        [string] $Name,
        [scriptblock[]] $Scripts = {$psitem}
    )

    $rendered = $psitem
    $arguments = , (xname $name) + @($scripts | foreach{ $script = $psitem; $rendered | foreach $script })
    New-Object Xml.Linq.XElement $arguments
}

